import { getModelUrl } from "/@/utils/url";
import * as Cesium from 'cesium'
import image from './yangguang.png'
import image2 from './zhongqing.png'
import ModelVSShader from '/@/glsl/ModelVS.glsl?raw'
import ModelFSShader from '/@/glsl/ModelFS.glsl?raw'


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

export const extractGltfData = async (name) => {
  // const gltf = JSON.parse(fs.readFileSync(inputFilePath));
  // const { gltf: processedGltf } = await gltfPipeline.processGltf(gltf);

  const modelUrl = await getModelUrl(name)

  // const gltf = await readGlb('https://td-design.gwdenergy.com/design-storage/202409/17260379304961280590760387153920.glb');
  // const gltf = await readGlb('https://image-test.gwdenergy.com/design-storage/202408/17242940676041175487863220211712.glb');
  // const gltf = await readGlb('https://td-design.gwdenergy.com/design-storage/202409/17260469900551283367190711898112.glb');
  // const gltf = await readGlb('https://td-design.gwdenergy.com/design-storage/202409/17260487758731282708363410804736.glb');
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

  console.log('accessorsData: ', accessorsData);
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

  for (const extractNode of extractNodes) {
    const attributes = extractNode.attributes
    const indices = new Uint16Array(accessorsData[attributes.indices])
    const position = setAttributes(new Float64Array(accessorsData[attributes.POSITION]), 3, Cesium.ComponentDatatype.DOUBLE) // attributes.POSITION
    console.log('position: ', new Array(8).fill(1).map((_, index) => [position.values[index * 3], position.values[index * 3 + 1], position.values[index * 3 + 2]]));
    // const normal = setAttributes(new Float32Array(normalData), 3, Cesium.ComponentDatatype.FLOAT) // attributes.NORMAL
    const translationData = attributes.TRANSLATION instanceof Array ? attributes.TRANSLATION : accessorsData[attributes.TRANSLATION]
    const scaleData = attributes.SCALE instanceof Array ? attributes.SCALE : accessorsData[attributes.SCALE]
    const rotationData = attributes.ROTATION instanceof Array ? attributes.ROTATION : accessorsData[attributes.ROTATION]
    const nodes = extractNode.nodes

    const stData = [
      1.0, 1.0,  // 顶点 0
      0.0, 1.0,  // 顶点 1
      0.0, 1.0,  // 顶点 2
      0.0, 0.0,  // 顶点 3
      0.0, 1.0,  // 顶点 4
      1.0, 1.0,  // 顶点 5
      0.0, 0.0,  // 顶点 6
      1.0, 0.0   // 顶点 7
    ];

    const st = setAttributes(new Float32Array(stData), 2, Cesium.ComponentDatatype.FLOAT)
    const geometryAttribute: any = {
      position,
      // normal,
      // color
      st
    }


    let geometry = new Cesium.Geometry({
      attributes: geometryAttribute,
      indices,
      boundingSphere: Cesium.BoundingSphere.fromVertices(accessorsData[attributes.POSITION]),
      primitiveType: Cesium.PrimitiveType.TRIANGLES,
    })
    geometry = Cesium.GeometryPipeline.computeNormal(geometry)
    // geometry = Cesium.GeometryPipeline.computeTangentAndBitangent(geometry)

    const geometryInstances = loadGeometryInstances(geometry, translationData, scaleData, rotationData, nodes)

    const primitive = loadPrimitive(geometryInstances)

    primitives.push(primitive)
    cachedGeometryInstances.push(geometryInstances)
  }

  return { primitives, cachedGeometryInstances, originGltf }
}

const loadPrimitive = (geometryInstances) => {

  const imageHeight = 715
  const imageWidth = 328

  return new Cesium.Primitive({
    geometryInstances,
    appearance: new Cesium.MaterialAppearance({
      translucent: false,
      material: new Cesium.Material({
        // minificationFilter: Cesium.TextureMinificationFilter.NEAREST,
        // magnificationFilter: Cesium.TextureMagnificationFilter.NEAREST,
        fabric: {
          type: 'Image',
          // type: 'PolylinePulseLink',
          uniforms: {
            // u_baseColor: Cesium.Cartesian4.fromArray(materialColor),
            // u_roughness: material.roughnessFactor,
            // u_metallic: material.metallicFactor,
            image,
            // image: image2,
            u_imageSize: new Cesium.Cartesian2(imageWidth, imageHeight),
            // repeat : {
            //   x : 2,
            //   y : 2
            // }
          },
          // components : {
          //   diffuse : 'texture(image, materialInput.st).rgb'
          // }
          // source: `czm_material czm_getMaterial(czm_materialInput materialInput) {
          //   czm_material material = czm_getDefaultMaterial(materialInput);

          //   vec2 st = materialInput.st;


          //   vec4 positionMC = czm_inverseModelView * vec4(materialInput.positionToEyeEC, 1.0);

          //   float textureX = mod(st.x, u_imageSize.x) / u_imageSize.x;
          //   float textureY = mod(st.y, u_imageSize.y) / u_imageSize.y;

          //   vec4 textureColor = texture(image, st).rgba;

          //   float pi = 3.14159;
          //   // 法线向量
          //   vec3 normal = normalize(materialInput.normalEC);
            
          //   material.diffuse = textureColor.rgb;
          //   // material.specular = 1.;
          //   // material.normal = normal;
          //   material.alpha = textureColor.a;


          //   return material;
          // }`
        },

      }),
      vertexShaderSource: ModelVSShader,
      fragmentShaderSource: ModelFSShader,

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

const loadGeometryInstances = (geometry: Cesium.Geometry, translationData, scaleData, rotationData, nodes) => {
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
        // color: Cesium.ColorGeometryInstanceAttribute.fromColor(color),
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
  //     attributes,
  //     nodes
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
