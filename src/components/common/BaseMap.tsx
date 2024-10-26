import * as Cesium from "cesium";
import { useEffect, useState } from "react";
import initMap from "/@/hooks/initMap";
import { extractGltfData, flyToTarget, loadCesium3dTileset, loadModel } from "/@/hooks";
import { getModelUrl, getTilesetUrl } from "/@/utils/url";
import React from "react";
import Transformer from 'cesium-transformer';
// import SDK from "/@/sdk";
import { saveAs } from 'file-saver'

const pos = [
  new Cesium.Cartesian3(
    -1834051.9741325895,
    5608007.865243541,
    2414183.3792176084
  ),
  new Cesium.Cartesian3(
    -1834055.844784437,
    5608004.334257179,
    2414188.5648715287
  ),
  new Cesium.Cartesian3(
    -1834061.0465333706,
    5608004.287396963,
    2414184.688053879
  )
]
const createPolygon = (positions?: Cesium.Cartesian3[], color = Cesium.Color.RED) => {

  if (!positions) {
    positions = pos
  }
  const modelMatrix = Cesium.Matrix4.IDENTITY.clone()
  Cesium.Matrix4.multiply(
    modelMatrix,
    Cesium.Matrix4.fromTranslation(new Cesium.Cartesian3(0, 0, 0)),
    modelMatrix
  )
  const polygonInstance = new Cesium.GeometryInstance({
    geometry: new Cesium.PolygonGeometry({
      polygonHierarchy: new Cesium.PolygonHierarchy(positions),
      perPositionHeight: true,
    }),
    attributes: {
      color: Cesium.ColorGeometryInstanceAttribute.fromColor(
        color.withAlpha(0.3),
      ),
    },
    // modelMatrix,
    id: 'polygon',
  });

  const polygonAppearance = new Cesium.MaterialAppearance({
    material:
      Cesium.Material.fromType("Color", {
        color:
          color.withAlpha(0.3) ||
          Cesium.Color.fromCssColorString("#00B20F"),
      }),
  });

  const primitive = new Cesium.Primitive({
    geometryInstances: polygonInstance,
    appearance: polygonAppearance,
    // depthFailAppearance: polygonAppearance,
    releaseGeometryInstances: false,
    // modelMatrix
  });

  return primitive

}


const alignedLength = (value) => {
  const alignValue = 4;
  if (value == 0) {
    return value;
  }
  const multiple = value % alignValue;
  if (multiple === 0) {
    return value;
  }
  return value + (alignValue - multiple);
}

const makeGlb = (glbObject) => {

  var Binary = {
    Magic: 0x46546C67
  };

  const enc = new TextEncoder();
  const jsonBuffer = enc.encode(JSON.stringify(glbObject.json));
  const jsonAlignedLength = alignedLength(jsonBuffer.length);
  let padding;
  if (jsonAlignedLength !== jsonBuffer.length) {

    padding = jsonAlignedLength - jsonBuffer.length;
  }
  const totalSize = 12 + // file header: magic + version + length
    8 + // json chunk header: json length + type
    jsonAlignedLength +
    8 + // bin chunk header: chunk length + type
    glbObject.binChunk.byteLength;
  const finalBuffer = new ArrayBuffer(totalSize);
  const dataView = new DataView(finalBuffer);
  let bufIndex = 0;
  dataView.setUint32(bufIndex, Binary.Magic, true);
  bufIndex += 4;
  dataView.setUint32(bufIndex, 2, true);
  bufIndex += 4;
  dataView.setUint32(bufIndex, totalSize, true);
  bufIndex += 4;
  // JSON
  dataView.setUint32(bufIndex, jsonAlignedLength, true);
  bufIndex += 4;
  dataView.setUint32(bufIndex, 0x4E4F534A, true);
  bufIndex += 4;

  for (var j = 0; j < jsonBuffer.length; j++) {
    dataView.setUint8(bufIndex, jsonBuffer[j]);
    bufIndex++;
  }
  if (padding !== undefined) {
    for (var j = 0; j < padding; j++) {
      dataView.setUint8(bufIndex, 0x20);
      bufIndex++;
    }
  }

  // BIN
  dataView.setUint32(bufIndex, glbObject.binChunk.byteLength, true);
  bufIndex += 4;
  dataView.setUint32(bufIndex, 0x004E4942, true);
  bufIndex += 4;

  const buffer = new Uint8Array(glbObject.binChunk.binBuffer);
  let bufoffset = bufIndex
  var thisbufindex = bufoffset;
  for (var j = 0; j < buffer.byteLength; j++) {
    dataView.setUint8(thisbufindex, buffer[j]);
    thisbufindex++;
  }
  saveAs(new Blob([finalBuffer], { type: 'model/json-binary' }), 'edited-model.glb');

}

const BaseMap = () => {
  const [viewer] = useState<Cesium.Viewer>();
  let transformer: Transformer | undefined = undefined
  // const cachedGeometryInstances: Cesium.GeometryInstance[] = []
  let originGltfData: any
  const elements: Cesium.Primitive[] = []
  const cachedElementsInstance: Cesium.GeometryInstance[] = []
  const deleteInstances: Cesium.GeometryInstance[] = []

  const boundingSphere = Cesium.BoundingSphere.fromPoints(pos)
  const modelMatrix = Cesium.Transforms.eastNorthUpToFixedFrame(boundingSphere.center)
  const modelMatrixInverse = Cesium.Matrix4.inverse(modelMatrix, new Cesium.Matrix4())

  const rotationX = Cesium.Matrix3.fromRotationX(Cesium.Math.toRadians(90))
  const rotationXInverse = Cesium.Matrix3.fromRotationX(Cesium.Math.toRadians(-90))
  const rotationZ = Cesium.Matrix3.fromRotationY(Cesium.Math.toRadians(90))
  const rotationZInverse = Cesium.Matrix3.fromRotationY(Cesium.Math.toRadians(-90))
  useEffect(() => {
    const cb = async () => {
      const viewer = await initMap({
        container: "cesiumContainer",
      });

      if (viewer) {
        // const modelUrl = await getModelUrl('texture_test');
        // const model = await loadModel(viewer, modelUrl, boundingSphere)
        // console.log('model: ', model);

        // viewer.camera.flyToBoundingSphere(boundingSphere, {
        //   duration: 1,
        //   offset: new Cesium.HeadingPitchRange(0, Cesium.Math.toRadians(-30), 60),
        // })

        // return 
        const { primitives, cachedGeometryInstances, originGltf } = await extractGltfData('electric');
        console.log('primitives: ', primitives);
        // console.log('cachedGeometryInstances: ', cachedGeometryInstances);
        // const { primitives, cachedGeometryInstances, originGltf } = await extractGltfData('edited-model', viewer);
        // const { primitives, cachedGeometryInstances, originGltf } = await extractGltfData('texture_test');
        originGltfData = originGltf
        primitives.forEach(primitive => {
          primitive.modelMatrix = modelMatrix.clone()

          Cesium.Matrix4.multiplyByMatrix3(primitive.modelMatrix, rotationX, primitive.modelMatrix)
          Cesium.Matrix4.multiplyByMatrix3(primitive.modelMatrix, rotationZ, primitive.modelMatrix)
          viewer.scene.primitives.add(primitive)
        })

        const pointCollection = new Cesium.PointPrimitiveCollection()
        viewer.scene.primitives.add(pointCollection)

        const handler = new Cesium.ScreenSpaceEventHandler(viewer.scene.canvas);

        let transformer: Transformer | undefined = undefined
        handler.setInputAction(({ position }) => {
          const object = viewer.scene.pick(position);
          const pos = viewer.scene.pickPosition(position)
          if (object && object.primitive instanceof Cesium.Primitive) {
            const primitive = object.primitive as Cesium.Primitive
            const instanceAttributes = primitive.getGeometryInstanceAttributes(object.id as number)
            const pickId = object.id as number
            const pickInstance = (cachedGeometryInstances.flat() as Cesium.GeometryInstance[]).find(instance => instance.id === pickId)
            const isExtiedElement = cachedElementsInstance.findIndex(instance => instance.id === pickId)

            const modelMatrix = isExtiedElement !== -1 ? elements[isExtiedElement].modelMatrix : primitive.modelMatrix.clone()
            if (isExtiedElement === -1) {
              Cesium.Matrix4.multiply(
                modelMatrix,
                pickInstance!.modelMatrix,
                modelMatrix
              )
              pickInstance!.modelMatrix = Cesium.Matrix4.IDENTITY.clone()
            }

            pointCollection.add({
              position: pos,
              color: Cesium.Color.RED,
              pixelSize: 10
            })
            return
            const element = isExtiedElement !== -1 ? elements[isExtiedElement] : new Cesium.Primitive({
              ...primitive,
              geometryInstances: pickInstance,
              asynchronous: false,
              releaseGeometryInstances: false,
              modelMatrix,
            })
            if (isExtiedElement === -1) {
              cachedElementsInstance.push(pickInstance!)
              elements.push(element)
              viewer.scene.primitives.add(element)

              instanceAttributes.show = Cesium.ShowGeometryInstanceAttribute.toValue(false)
            }

            if (transformer) {
              transformer.destory()
              transformer = undefined
            }

            transformer = new Transformer({
              scene: viewer.scene,
              element: element,
              boundingSphere: instanceAttributes.boundingSphere
            })
          } else {

            if (transformer) {
              transformer.destory()
              transformer = undefined
            }
          }
        }, Cesium.ScreenSpaceEventType.LEFT_CLICK);
        handler.setInputAction(({ position }) => {

          const object = viewer.scene.pick(position);
          if (object && object.primitive instanceof Cesium.Primitive) {
            const primitive = object.primitive as Cesium.Primitive
            const pickId = object.id as number
            const instanceAttributes = primitive.getGeometryInstanceAttributes(object.id as number)
            instanceAttributes.show = Cesium.ShowGeometryInstanceAttribute.toValue(false)
            const pickInstance = (cachedGeometryInstances[0].flat() as Cesium.GeometryInstance[]).find(instance => instance.id === pickId)

            deleteInstances.push(pickInstance!)
          }
        }, Cesium.ScreenSpaceEventType.RIGHT_CLICK);

        viewer.camera.flyToBoundingSphere(boundingSphere, {
          duration: 1,
          offset: new Cesium.HeadingPitchRange(0, Cesium.Math.toRadians(-30), 60),
        })

      }
    };
    cb();
  }, [viewer]);


  const saveFile = async () => {
    elements.forEach(element => {
      const matrix = Cesium.Matrix4.IDENTITY.clone()
      Cesium.Matrix4.multiplyByMatrix3(
        matrix,
        rotationZInverse,
        matrix
      )
      Cesium.Matrix4.multiplyByMatrix3(
        matrix,
        rotationXInverse,
        matrix
      )
      Cesium.Matrix4.multiply(
        matrix,
        modelMatrixInverse,
        matrix
      )
      Cesium.Matrix4.multiply(
        matrix,
        element.modelMatrix.clone(),
        matrix
      )
      const id = (element.geometryInstances as Cesium.GeometryInstance).id
      const targetNode = originGltfData.json.nodes.find(node => node.name === id)
      if (targetNode) {
        targetNode.matrix = Cesium.Matrix4.toArray(matrix, [])
      }

    })

    const nodesWithChildren = originGltfData.json.nodes.filter(node => node.children?.length)

    deleteInstances.forEach((instance, idx) => {
      const id = (instance as Cesium.GeometryInstance).id
      const deleteIndex = originGltfData.json.nodes.findIndex(node => node.name === id)
      if (deleteIndex !== -1) {
        (originGltfData.json.nodes as []).splice(deleteIndex, 1)
        for (const node of nodesWithChildren) {
          if (node.children?.includes(deleteIndex + idx)) {
            node.children = node.children?.filter(index => index !== deleteIndex + idx)
          }
          node.children = node.children?.map(index => index < deleteIndex + idx ? index : index - 1)
        }
      }
    })

    makeGlb(originGltfData)
  }

  return <div id="cesiumContainer" className="w-full h-full">
    <button className="absolute top-2 left-2 w-20 z-10 bg-blue-700" onClick={() => saveFile()}>保存文件</button>
  </div>;
};

export default BaseMap;
