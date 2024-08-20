import { getModelUrl } from "/@/utils/url";
import { load } from '@loaders.gl/core';
import { GLBLoader } from '@loaders.gl/gltf';
import * as Cesium from 'cesium'

// 将ArrayBuffer转换为Base64
function arrayBufferToBase64(buffer, byteOffset, byteLength) {
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
  const gltf = await load(modelUrl, GLBLoader);

  const processedGltf = gltf.json
  console.log('gltf: ', gltf);
  console.log('processedGltf: ', processedGltf);
  const accessors = processedGltf.accessors;
  const bufferViews = processedGltf.bufferViews;
  const meshes = processedGltf.meshes;
  const nodes = processedGltf.nodes;
  const binChunks = gltf.binChunks;

  // const vertexAttributes = {};
  const accessorsData: number[][] = []

  for (let i = 0; i < accessors.length; i++) {
    const accessor = accessors[i];
    const bufferView = bufferViews[accessor.bufferView];
    const bufferIndex = bufferView.buffer;
    const binChunk = binChunks[bufferIndex];


    // 确保我们从正确的 binChunk 中提取数据
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

        // 如果超出当前 binChunk 的范围，跳过不合法的数据
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

  return loadPrimitives(extractNodes, accessorsData, viewer)

}

const setAttributes = (values: any, componentsPerAttribute: number, type: Cesium.ComponentDatatype) => {
  return new Cesium.GeometryAttribute({
    componentDatatype: type,
    componentsPerAttribute: componentsPerAttribute,
    values: values
  })
}


// const customMaterialType = 'MyCustomMaterial'

// // 注册自定义材质
// Cesium.Material..addMaterial(customMaterialType, {
//   fabric: {
//       type: customMaterialType,
//       uniforms: {
//           u_viewProjection: viewer.scene.camera.viewProjectionMatrix
//       },
//       // 自定义着色器代码
//       source: `
//           uniform mat4 u_viewProjection;

//           varying vec3 v_positionEC;
//           varying vec2 v_st;

//           void main() {
//               gl_FragColor = vec4(v_st, 0.5, 1.0);
//           }
//       `
//   }
// });

const loadPrimitives = (extractNodes, accessorsData, viewer) => {

  const primitives: Cesium.Primitive[] = []
  const cachedGeometryInstances: (Cesium.GeometryInstance[])[] = []

  for (const extractNode of extractNodes) {
    const attributes = extractNode.attributes
    const indices = new Uint16Array(accessorsData[attributes.indices])
    const position = setAttributes(new Float64Array(accessorsData[attributes.POSITION]), 3, Cesium.ComponentDatatype.DOUBLE) // attributes.POSITION
    const normal = setAttributes(new Float32Array(accessorsData[attributes.NORMAL]), 3, Cesium.ComponentDatatype.FLOAT) // attributes.NORMAL
    const translationData = accessorsData[attributes.TRANSLATION]

    const geometryAttribute: any = {
      position,
      normal
    }


    const geometry = new Cesium.Geometry({
      attributes: geometryAttribute,
      indices,
      boundingSphere: Cesium.BoundingSphere.fromVertices(accessorsData[attributes.POSITION]),
      primitiveType: Cesium.PrimitiveType.TRIANGLES,
    })

    const geometryInstances = loadGeometryInstances(geometry, translationData)

    const primitive = new Cesium.Primitive({
      geometryInstances,
      appearance: new Cesium.MaterialAppearance({
        material: new Cesium.Material({
          fabric: {
            type: 'Color',
            // type: 'PolylinePulseLink',
            uniforms: {
              color: Cesium.Color.BLUE
            },
            // source: `czm_material czm_getMaterial(czm_materialInput materialInput) {
            //   czm_material material = czm_getDefaultMaterial(materialInput);
            //   material.diffuse = vec3(0.8, 0.2, 0.1);
            //   material.specular = 3.0;
            //   material.shininess = 0.8;
            //   material.alpha = 0.6;
            //   return material;
            // }`
          },
          
        }),
        vertexShaderSource: document.getElementById('vertexShaderSource')!.textContent as string,
        fragmentShaderSource: document.getElementById('fragmentShaderSource')!.textContent as string,
        
        renderState: {
          depthTest: {
            enabled: true
          }
        }
      }),
      shadows: Cesium.ShadowMode.CAST_ONLY,
      // releaseGeometryInstances: false,
      asynchronous: false
    })

    primitives.push(primitive)
    cachedGeometryInstances.push(geometryInstances)
  }

  return { primitives, cachedGeometryInstances }
}

const loadGeometryInstances = (geometry: Cesium.Geometry, translationData) => {
  const count = translationData.length / 3
  const instances: Cesium.GeometryInstance[] = []

  const translationAttribute = new Cesium.GeometryInstanceAttribute({
    componentDatatype: Cesium.ComponentDatatype.FLOAT,
    componentsPerAttribute: 4,
    value: [1.0, 1.0, 1.0, 1.0]
  })
  for (let i = 0; i < count; i++) {
    const translation = new Cesium.Cartesian3(translationData[i * 3], translationData[i * 3 + 1], translationData[i * 3 + 2])
    const translationMatrix = Cesium.Matrix4.fromTranslation(translation)

    // const translationBack = Cesium.Matrix4.fromTranslation(Cesium.Cartesian3.negate(translation, new Cesium.Cartesian3()))
    const rotationX = Cesium.Matrix3.fromRotationX(Cesium.Math.toRadians(90))
    const rotationZ = Cesium.Matrix3.fromRotationY(Cesium.Math.toRadians(90))
    // const rotationMatrix = Cesium.Matrix4.fromRotationTranslation(rotationX)

    const modelMatrix = Cesium.Matrix4.IDENTITY.clone()
    // Cesium.Matrix4.multiply(modelMatrix, rotationMatrix,  modelMatrix)
    Cesium.Matrix4.multiplyByMatrix3(modelMatrix, rotationX, modelMatrix)
    Cesium.Matrix4.multiplyByMatrix3(modelMatrix, rotationZ, modelMatrix)
    Cesium.Matrix4.multiply(modelMatrix, translationMatrix, modelMatrix)
    // Cesium.Matrix4.multiply(modelMatrix, translationBack,  modelMatrix)

    const matrixColumn0 = [modelMatrix[0], modelMatrix[4], modelMatrix[8], modelMatrix[12]];
    const matrixColumn1 = [modelMatrix[1], modelMatrix[5], modelMatrix[9], modelMatrix[13]];
    const matrixColumn2 = [modelMatrix[2], modelMatrix[6], modelMatrix[10], modelMatrix[14]];
    const matrixColumn3 = [modelMatrix[3], modelMatrix[7], modelMatrix[11], modelMatrix[15]];

    const instance = new Cesium.GeometryInstance({
      geometry: geometry,
      modelMatrix,
      id: i,
      attributes: {
        color: Cesium.ColorGeometryInstanceAttribute.fromColor(Cesium.Color.BLUE),
        // translation: Cesium.GeometryInstanceAttribute.fromCartesian3(translation)
        show: new Cesium.ShowGeometryInstanceAttribute(true),
        // 传递每个实例的模型矩阵（拆分成4列向量）
        matrixColumn0: new Cesium.GeometryInstanceAttribute({
          componentDatatype: Cesium.ComponentDatatype.FLOAT,
          componentsPerAttribute: 4,
          value: matrixColumn0
        }),
        matrixColumn1: new Cesium.GeometryInstanceAttribute({
          componentDatatype: Cesium.ComponentDatatype.FLOAT,
          componentsPerAttribute: 4,
          value: matrixColumn1
        }),
        matrixColumn2: new Cesium.GeometryInstanceAttribute({
          componentDatatype: Cesium.ComponentDatatype.FLOAT,
          componentsPerAttribute: 4,
          value: matrixColumn2
        }),
        matrixColumn3: new Cesium.GeometryInstanceAttribute({
          componentDatatype: Cesium.ComponentDatatype.FLOAT,
          componentsPerAttribute: 4,
          value: matrixColumn3
        }),
        translation: translationAttribute,
      }
    })
    instances.push(instance)
  }

  console.log( Cesium.ColorGeometryInstanceAttribute.fromColor(Cesium.Color.BLUE), translationAttribute, new Cesium.ShowGeometryInstanceAttribute(false), new Cesium.DistanceDisplayConditionGeometryInstanceAttribute(100.0, 10000.0));

  return instances
}

const loadNodes = (nodes, meshes) => {
  const primitives: any = []
  for (let i = 0; i < nodes.length; i++) {
    const node = nodes[i];
    const meshIndex = node.mesh;
    const mesh = meshes[meshIndex];
    const attributes = getNodeAttributes(node, mesh);
    const primitive = {
      name: node.name,
      // instanceCount: getInstanceCount(node),
      attributes
    }
    primitives.push(primitive)
  }
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
