import { getModelUrl } from "/@/utils/url";
import { load } from '@loaders.gl/core';
import { GLBLoader } from '@loaders.gl/gltf';
import * as Cesium from 'cesium'


const parseGlb = async (arrayBuffer) => {
  return new Promise((resolve, reject) => {

    const dataView = new DataView(arrayBuffer);

    // 1. 解析 Header (20 bytes)
    const magic = dataView.getUint32(0, true); // 0x676C5446 ('glTF')
    const version = dataView.getUint32(4, true); // 2
    const totalLength = dataView.getUint32(8, true); // Total file length

    console.log(`GLB Version: ${version}, Total Length: ${totalLength} bytes`);

    const jsonChunkLength = dataView.getUint32(12, true); // Length of JSON chunk
    const jsonChunkType = dataView.getUint32(16, true); // Type 'JSON' (0x4E4F534A)

    if (jsonChunkType !== 0x4E4F534A) {
      reject('The first chunk is not a JSON chunk');
      return;
    }

    const jsonChunkData = new Uint8Array(arrayBuffer, 20, jsonChunkLength);
    const jsonText = new TextDecoder().decode(jsonChunkData);
    const json = JSON.parse(jsonText);

    const binaryChunkHeaderOffset = 20 + jsonChunkLength;
    if (binaryChunkHeaderOffset < totalLength) {
      const binaryChunkLength = dataView.getUint32(binaryChunkHeaderOffset, true);
      const binaryChunkType = dataView.getUint32(binaryChunkHeaderOffset + 4, true); // Type 'BIN' (0x004E4942)

      if (binaryChunkType !== 0x004E4942) {
        reject('The second chunk is not a binary chunk');
        return;
      }

      const binChunk =
      {
        byteLength: binaryChunkLength,
        byteOffset: binaryChunkHeaderOffset + 8,
        type: 'bin',
        arrayBuffer,
        binBuffer: arrayBuffer.slice(binaryChunkHeaderOffset + 8, binaryChunkHeaderOffset + 8 + binaryChunkLength)
      }
      const header = {
        byteLength: totalLength,
        byteOffset: 0,
        hasBinChunk: true
      }

      resolve({ json, binChunk, version, header });

    }
  })
}
const readGlb = async (url: string): Promise<{
  json: any;
  binChunk: any;
  version: number
}> => {
  return new Promise(async (resolve, reject) => {

    const response = await fetch(url);
    const blob = await response.blob();

    const reader = new FileReader();
    reader.onload = async (e) => {
      if (!e.target) return
      const arrayBuffer = e.target.result;
      parseGlb(arrayBuffer)
        .then((res) => {
          resolve(res as any)
        })
        .catch((err) => {
          reject(err)
        })
    };
    reader.readAsArrayBuffer(blob);
  })
}
// 将ArrayBuffer转换为Base64
const arrayBufferToBase64 = (buffer, byteOffset, byteLength) => {
  const bytes = new Uint8Array(buffer, byteOffset, byteLength);
  let binary = '';
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

export const extractGltfData = async (name, viewer: Cesium.Viewer) => {
  // const gltf = JSON.parse(fs.readFileSync(inputFilePath));
  // const { gltf: processedGltf } = await gltfPipeline.processGltf(gltf);

  const modelUrl = await getModelUrl(name)

  const gltf = await readGlb(modelUrl);

  const processedGltf = gltf.json
  console.log('processedGltf: ', processedGltf);
  const accessors = processedGltf.accessors;
  const bufferViews = processedGltf.bufferViews;
  const meshes = processedGltf.meshes;
  const nodes = processedGltf.nodes;
  const binChunk = gltf.binChunk;
  const accessorsData: number[][] = []

  for (let i = 0; i < accessors.length; i++) {
    const accessor = accessors[i];
    const bufferView = bufferViews[accessor.bufferView];

    const binChunkByteOffset = binChunk.byteOffset || 0;
    const binChunkByteLength = binChunk.byteLength || binChunk.byteLength;

    const byteOffset = binChunkByteOffset + (bufferView.byteOffset || 0) + (accessor.byteOffset || 0);
    const byteStride = bufferView.byteStride || getAccessorTypeSize(accessor) * getNumComponents(accessor.type);
    const componentSize = getAccessorTypeSize(accessor);
    const numComponents = getNumComponents(accessor.type);

    const values: number[] = [];

    for (let j = 0; j < accessor.count; j++) {
      const elementOffset = byteOffset + j * byteStride;

      for (let k = 0; k < numComponents; k++) {
        const componentOffset = elementOffset + k * componentSize;

        if (componentOffset + componentSize > binChunkByteOffset + binChunkByteLength) {
          console.error(`Attempt to read outside of the buffer range. Skipping.`);
          break;
        }

        const view = new DataView(binChunk.arrayBuffer, componentOffset, componentSize);

        if (accessor.componentType === 5126) { // FLOAT
          values.push(view.getFloat32(0, true));
        } else if (accessor.componentType === 5123) { // UNSIGNED_SHORT
          values.push(view.getUint16(0, true));
        } else if (accessor.componentType === 5121) { // UNSIGNED_BYTE
          values.push(view.getUint8(0));
        } else {
          console.error(`Unsupported component type: ${accessor.componentType}`);
          break;
        }
      }
    }

    accessorsData[i] = values;
  }

  const extractNodes = loadNodes(nodes, meshes)

  return loadPrimitives(extractNodes, accessorsData, gltf)

}

const setAttributes = (values: any, componentsPerAttribute: number, type: Cesium.ComponentDatatype) => {
  return new Cesium.GeometryAttribute({
    componentDatatype: type,
    componentsPerAttribute: componentsPerAttribute,
    values: values
  })
}

const loadPrimitives = (extractNodes, accessorsData, originGltf) => {

  const primitives: Cesium.Primitive[] = []
  const cachedGeometryInstances: (Cesium.GeometryInstance[])[] = []
  const normalData = [0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]

  for (const extractNode of extractNodes) {
    const attributes = extractNode.attributes
    const indices = new Uint16Array(accessorsData[attributes.indices])
    const position = setAttributes(new Float64Array(accessorsData[attributes.POSITION]), 3, Cesium.ComponentDatatype.DOUBLE) // attributes.POSITION
    const normal = setAttributes(new Float32Array(normalData), 3, Cesium.ComponentDatatype.FLOAT) // attributes.NORMAL
    const translationData = attributes.TRANSLATION instanceof Array ? attributes.TRANSLATION : accessorsData[attributes.TRANSLATION]
    const scaleData = attributes.SCALE instanceof Array ? attributes.SCALE : accessorsData[attributes.SCALE]
    const rotationData = attributes.ROTATION instanceof Array ? attributes.ROTATION : accessorsData[attributes.ROTATION]
    const nodes = extractNode.nodes

    const material = originGltf.json.materials[attributes.material].pbrMetallicRoughness

    const materialColor = material.baseColorFactor ? material.baseColorFactor : [1, 1, 1, 1]

    const baseColor = new Cesium.Color(materialColor[0], materialColor[1], materialColor[2], materialColor[3])
    const metallicColor = Cesium.Color.add(
      Cesium.Color.multiplyByScalar(
        new Cesium.Color(0.04, 0.04, 0.04, 1),
        1.0 - material.metallicFactor,
        new Cesium.Color()
      ),
      Cesium.Color.multiplyByScalar(
        baseColor,
        material.metallicFactor,
        new Cesium.Color()
      ),
      new Cesium.Color()
    )
    const roughnessColor = Cesium.Color.lerp(
      new Cesium.Color(1, 1, 1, 1),
      new Cesium.Color(0.5, 0.5, 0.5, 1),
      material.roughnessFactor,
      new Cesium.Color()
    )
    const finalColor = Cesium.Color.multiply(metallicColor, roughnessColor, new Cesium.Color())
    // console.log('materialColor: ', materialColor);

    // const color = setAttributes(new Uint8Array([

    //   Cesium.Color.floatToByte(c.red),
    //   Cesium.Color.floatToByte(c.green),
    //   Cesium.Color.floatToByte(c.blue),
    //   Cesium.Color.floatToByte(c.alpha)

    // ]), 4, Cesium.ComponentDatatype.UNSIGNED_BYTE)
    // color.normalize = true
    const geometryAttribute: any = {
      position,
      normal,
      // color
    }


    const geometry = new Cesium.Geometry({
      attributes: geometryAttribute,
      indices,
      boundingSphere: Cesium.BoundingSphere.fromVertices(accessorsData[attributes.POSITION]),
      primitiveType: Cesium.PrimitiveType.TRIANGLES,
    })

    const geometryInstances = loadGeometryInstances(geometry, translationData, scaleData, rotationData, nodes, finalColor)

    const primitive = new Cesium.Primitive({
      geometryInstances,
      // appearance: new Cesium.PerInstanceColorAppearance({
      //   flat: true,
      //   renderState: {
      //     depthTest: {
      //       enabled: true
      //     }
      //   }
      // }),
      appearance: new Cesium.MaterialAppearance({
        material: new Cesium.Material({
          fabric: {
            // type: 'Color',
            // type: 'PolylinePulseLink',
            uniforms: {
              u_color: baseColor,
              u_roughnessFactor: material.roughnessFactor,
              u_metallicFactor: material.metallicFactor
            },
            source: `czm_material czm_getMaterial(czm_materialInput materialInput) {
            czm_material material = czm_getDefaultMaterial(materialInput);
            float metalness = clamp(u_metallicFactor, 0.0, 1.0);
            float roughness = clamp(u_roughnessFactor, 0.04, 1.0);
            const vec3 REFLECTANCE_DIELECTRIC = vec3(0.04);
            vec3 f0 = mix(REFLECTANCE_DIELECTRIC, u_color.rgb, metalness);
            // material.specular = f0;

            material.diffuse = mix(u_color.rgb, vec3(0.0), metalness);
        
            // material.roughness = roughness * roughness;
            return material;
          }`
          },

        }),
        // vertexShaderSource: document.getElementById('vertexShaderSource')!.textContent as string,
        // fragmentShaderSource: document.getElementById('fragmentShaderSource')!.textContent as string,

        renderState: {
          depthTest: {
            enabled: true
          }
        }
      }),
      // shadows: Cesium.ShadowMode.CAST_ONLY,
      // releaseGeometryInstances: false,
      asynchronous: false
    })

    primitives.push(primitive)
    cachedGeometryInstances.push(geometryInstances)
  }

  return { primitives, cachedGeometryInstances, originGltf }
}

const linearTransformAroundCenter = (
  matrix: Cesium.Matrix4 | Cesium.Matrix3,
  center: Cesium.Cartesian3,
  result: Cesium.Matrix4
) => {
  const translationToCenter = Cesium.Matrix4.fromTranslation(center.clone())
  const translationBack = Cesium.Matrix4.fromTranslation(
    Cesium.Cartesian3.negate(center, new Cesium.Cartesian3())
  )

  Cesium.Matrix4.multiply(result, translationToCenter, result)
  if (matrix instanceof Cesium.Matrix4) {
    Cesium.Matrix4.multiply(result, matrix.clone(), result)
  } else if (matrix instanceof Cesium.Matrix3) {
    Cesium.Matrix4.multiplyByMatrix3(result, matrix.clone(), result)
  }
  Cesium.Matrix4.multiply(result, translationBack, result)
}

const loadGeometryInstances = (geometry: Cesium.Geometry, translationData, scaleData, rotationData, nodes, color) => {
  const count = translationData.length / 3
  const instances: Cesium.GeometryInstance[] = []

  for (let i = 0; i < count; i++) {
    const translation = new Cesium.Cartesian3(translationData[i * 3], translationData[i * 3 + 1], translationData[i * 3 + 2])
    const translationMatrix = Cesium.Matrix4.fromTranslation(translation)

    const scale = new Cesium.Cartesian3(scaleData[i * 3], scaleData[i * 3 + 1], scaleData[i * 3 + 2])
    const scaleMatrix = Cesium.Matrix4.fromScale(scale)

    const quaternion = new Cesium.Quaternion(rotationData[i * 4], rotationData[i * 4 + 1], rotationData[i * 4 + 2], rotationData[i * 4 + 3])
    const rotationMatrix = Cesium.Matrix3.fromQuaternion(quaternion)

    const modelMatrix = Cesium.Matrix4.IDENTITY.clone()
    Cesium.Matrix4.multiply(modelMatrix, translationMatrix, modelMatrix)
    Cesium.Matrix4.multiplyByMatrix3(modelMatrix, rotationMatrix, modelMatrix)
    Cesium.Matrix4.multiply(modelMatrix, scaleMatrix, modelMatrix)

    const instance = new Cesium.GeometryInstance({
      geometry: geometry,
      modelMatrix,
      id: nodes[i].name,
      attributes: {
        color: Cesium.ColorGeometryInstanceAttribute.fromColor(color),
        show: new Cesium.ShowGeometryInstanceAttribute(true)
      }
    })
    instances.push(instance)
  }


  return instances
}

const loadNodes = (nodes, meshes) => {
  // const primitives: any = []
  // for (let i = 0; i < nodes.length; i++) {
  //   const node = nodes[i];
  //   const meshIndex = node.mesh;
  //   const mesh = meshes[meshIndex];
  //   const attributes = getNodeAttributes(node, mesh);
  //   const primitive = {
  //     name: node.name,
  //     // instanceCount: getInstanceCount(node),
  //     attributes
  //   }
  //   primitives.push(primitive)
  // }
  // return primitives
  const primitives = meshes.map((mesh, meshIndex) => {
    const meshesInNode = nodes.filter(node => node.mesh === meshIndex)
    const name = mesh.name || meshesInNode[0].name
    const attributes = getMeshAttributes(mesh);
    const matrixAttributes = getMatrixAttributes(meshesInNode);
    const primitive = {
      name,
      // instanceCount: getInstanceCount(node),
      attributes: {
        ...attributes,
        ...matrixAttributes
      },
      nodes: meshesInNode
    }

    return primitive
  })

  console.log('primitives: ', primitives);
  return primitives
}

const loadMesh = (mesh) => {

}

const getNodeAttributes = (node, mesh) => {
  let attributes: any = {
    ...mesh.primitives[0].attributes
  }
  attributes.indices = mesh.primitives[0].indices
  attributes.material = mesh.primitives[0].material
  if (getInstanceCount(node)) {
    attributes = {
      ...attributes,
      ...node.extensions.EXT_mesh_gpu_instancing.attributes
    }
  }
  return attributes
}

const getMeshAttributes = (mesh) => {

  let attributes: any = {
    ...mesh.primitives[0].attributes
  }
  attributes.indices = mesh.primitives[0].indices
  attributes.material = mesh.primitives[0].material
  return attributes
}

const getMatrixAttributes = (nodes) => {
  const attributes: {
    TRANSLATION: number[],
    SCALE: number[],
    ROTATION: number[]
  } = {
    TRANSLATION: [],
    SCALE: [],
    ROTATION: []
  }
  const translations: Cesium.Cartesian3[] = []
  const scales: Cesium.Cartesian3[] = []
  const rotations: number[] = []

  for (let i = 0; i < nodes.length; i++) {
    const node = nodes[i];
    const matrix = node.matrix ? Cesium.Matrix4.fromArray(node.matrix) : Cesium.Matrix4.IDENTITY.clone()

    const translation = Cesium.Matrix4.getTranslation(matrix, new Cesium.Cartesian3())
    translations.push(translation)

    const scale = Cesium.Matrix4.getScale(matrix, new Cesium.Cartesian3())
    scales.push(scale)

    const rotation = Cesium.Matrix4.getRotation(matrix, new Cesium.Matrix3())
    const quaternion = Cesium.Quaternion.fromRotationMatrix(rotation)
    rotations.push(
      ...Cesium.Quaternion.pack(quaternion, [])
    )

  }

  attributes.TRANSLATION = Cesium.Cartesian3.packArray(translations, [])
  attributes.SCALE = Cesium.Cartesian3.packArray(scales, [])
  attributes.ROTATION = rotations

  return attributes
}

const getInstanceCount = (node) => {
  if (!node || !node.extensions || !node.extensions.EXT_mesh_gpu_instancing) {
    return 0
  }

  return 1
}
function getAccessorTypeSize(accessor) {
  switch (accessor.componentType) {
    case 5120: return 1; // BYTE
    case 5121: return 1; // UNSIGNED_BYTE
    case 5122: return 2; // SHORT
    case 5123: return 2; // UNSIGNED_SHORT
    case 5125: return 4; // UNSIGNED_INT
    case 5126: return 4; // FLOAT
    default: return 0;
  }
}

function getNumComponents(type) {
  switch (type) {
    case 'SCALAR': return 1;
    case 'VEC2': return 2;
    case 'VEC3': return 3;
    case 'VEC4': return 4;
    case 'MAT2': return 4;
    case 'MAT3': return 9;
    case 'MAT4': return 16;
    default: return 0;
  }
}
