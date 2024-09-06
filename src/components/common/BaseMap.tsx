import * as Cesium from "cesium";
import { useEffect, useState } from "react";
import initMap from "/@/hooks/initMap";
import { extractGltfData, flyToTarget, loadCesium3dTileset, loadModel } from "/@/hooks";
import { getModelUrl, getTilesetUrl } from "/@/utils/url";
import React from "react";
import Transformer from 'cesium-transformer';
import { differenceBy } from 'lodash'
// import SDK from "/@/sdk";
import {GLBWriter, GLTFWriter, GLBLoader} from '@loaders.gl/gltf';
import {encodeSync, encode, load} from '@loaders.gl/core';
import {saveAs} from 'file-saver'
import {Document, WebIO} from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import ParseGlbData from "/@/hooks/parse/parseGlbData";

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
        // const modelUrl = await getModelUrl('electric');
        // const model = await loadModel(viewer, modelUrl, boundingSphere)
        // console.log('model: ', model);
        const { primitives, cachedGeometryInstances, originGltf } = await extractGltfData('electric', viewer);
        // console.log('cachedGeometryInstances: ', cachedGeometryInstances);
 
        // const { primitives, cachedGeometryInstances, originGltf } = await extractGltfData('edited-model', viewer);
        originGltfData = originGltf
        primitives.forEach(primitive => {
          primitive.modelMatrix = modelMatrix.clone()

          Cesium.Matrix4.multiplyByMatrix3(primitive.modelMatrix, rotationX, primitive.modelMatrix)
          Cesium.Matrix4.multiplyByMatrix3(primitive.modelMatrix, rotationZ, primitive.modelMatrix)
          viewer.scene.primitives.add(primitive)
        })

        const handler = new Cesium.ScreenSpaceEventHandler(viewer.scene.canvas);
        handler.setInputAction(({ position }) => {
          const object = viewer.scene.pick(position);
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

        // const modelUrl = await getModelUrl('electric');
        

        // new ParseGlbData({
        //   url: modelUrl
        // })
        // const glb = await io.writeBinary(document);
        // console.log('glb: ', glb);
        // saveAs(new Blob([glb]), 'edited-model.glb');

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
      console.log('id: ', id);
      const deleteIndex = originGltfData.json.nodes.findIndex(node => node.name === id)
      console.log('deleteIndex: ', deleteIndex);
      if (deleteIndex !== -1) {
        const deleteNode = (originGltfData.json.nodes as []).splice(deleteIndex, 1)
        console.log('deleteNode: ', deleteNode);
        for (const node of nodesWithChildren) {
          if (node.children?.includes(deleteIndex + idx)) {
            node.children = node.children?.filter(index => index !== deleteIndex + idx)
          }
          node.children = node.children?.map(index => index < deleteIndex + idx ? index : index - 1)
        }
        // nodesWithChildren.forEach(nodeWithChildren => {

        // })
      }
    })

    console.log('originGltfData: ', originGltfData);
    // const arrayBuffer = await encode(originGltfData, GLBWriter, {
    //   glb: originGltfData
    // });
    // saveAs(new Blob([arrayBuffer]), 'edited-model.glb');
 
    // const gltfJson = JSON.stringify(originGltfData.json, null, 2);
    // const gltfBlob = new Blob([gltfJson], {type: 'application/json'});
    // console.log('gltfBlob: ', gltfBlob);
    // saveAs(gltfBlob, 'model.gltf');

    const jsonDocument = {
      json: originGltfData.json,
      resources: {}
    }
    const io = new WebIO();
    const document = await io.readJSON(jsonDocument);
    const glb = await io.writeBinary(document);
    // const glb = await io.readBinary(gltfBlob);
    console.log('glb: ', glb);
    // console.log('originGltfData.json: ', JSON.stringify(originGltfData.json));

    // 将生成的 GLB 文件保存（例如使用 FileSaver.js 保存）
    saveAs(new Blob([glb], {type: 'application/octet-stream'}), 'edited-model.glb');
  }

  return <div id="cesiumContainer" className="w-full h-full">
    <button className="absolute top-2 left-2 w-20 z-10 bg-blue-700" onClick={() => saveFile()}>保存文件</button>
  </div>;
};

export default BaseMap;
