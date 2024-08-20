import * as Cesium from "cesium";
import { useEffect, useState } from "react";
import initMap from "/@/hooks/initMap";
import { extractGltfData, flyToTarget, loadCesium3dTileset, loadModel } from "/@/hooks";
import { getModelUrl, getTilesetUrl } from "/@/utils/url";
import React from "react";
import Transformer from 'cesium-transformer';
import { differenceBy } from 'lodash'
// import SDK from "/@/sdk";

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
    Cesium.Matrix4.fromTranslation(new Cesium.Cartesian3(0, 0, 2)),
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
    modelMatrix,
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
  const elements: Cesium.Primitive[] = []
  const cachedElementsInstance: Cesium.GeometryInstance[] = []
  const deleteInstances: Cesium.GeometryInstance[] = []

  useEffect(() => {
    const cb = async () => {
      const viewer = await initMap({
        container: "cesiumContainer",
      });





      // const polygon = createPolygon()
      if (viewer) {
        // const tilesetUrl = await getTilesetUrl("1217138133700055040");
  
        // const tileset = await loadCesium3dTileset(viewer, tilesetUrl);

        // flyToTarget(viewer, tileset);
        // new Transformer({
        //   scene: viewer.scene,
        //   element: tileset,
        //   boundingSphere: tileset.boundingSphere
        // })
        const boundingSphere = Cesium.BoundingSphere.fromPoints(pos)
        const { primitives, cachedGeometryInstances} = await extractGltfData('modelDraco_100000', viewer);
        primitives.forEach(primitive => {
          primitive.modelMatrix = Cesium.Transforms.eastNorthUpToFixedFrame(boundingSphere.center)
          viewer.scene.primitives.add(primitive)
        })

        const handler = new Cesium.ScreenSpaceEventHandler(viewer.scene.canvas);
        handler.setInputAction(({ position }) => {
          const object = viewer.scene.pick(position);
          if (object && object.primitive instanceof Cesium.Primitive) {
            const primitive = object.primitive as Cesium.Primitive
            const instanceAttributes = primitive.getGeometryInstanceAttributes(object.id as number)
            console.log('instanceAttributes: ',instanceAttributes, instanceAttributes.color, instanceAttributes.boundingSphere);
            const pickId = object.id as number
            const pickInstance = (cachedGeometryInstances[0] as Cesium.GeometryInstance[]).find(instance => instance.id === pickId)
            const isExtiedElement = cachedElementsInstance.findIndex(instance => instance.id === pickId)

            const modelMatrix = isExtiedElement !== -1 ? elements[isExtiedElement].modelMatrix : Cesium.Transforms.eastNorthUpToFixedFrame(boundingSphere.center)
            if (isExtiedElement === -1) {
              Cesium.Matrix4.multiply(
                modelMatrix,
                pickInstance!.modelMatrix,
                modelMatrix
              )
              pickInstance!.modelMatrix = Cesium.Matrix4.IDENTITY.clone()
            }
            // instance.modelMatrix = modelMatrix
            const element = isExtiedElement !== -1 ? elements[isExtiedElement] : new Cesium.Primitive({
              ...primitive,
              geometryInstances: pickInstance,
              asynchronous: false,
              modelMatrix,
            })
            if (isExtiedElement === -1) {
              cachedElementsInstance.push(pickInstance!)
              elements.push(element)
              viewer.scene.primitives.add(element)

              
              // const copyInstances = differenceBy(cachedGeometryInstances[0], [...cachedElementsInstance, ...deleteInstances], 'id');
  
              // const newPrimitive = new Cesium.Primitive({
              //   ...primitive,
              //   asynchronous: false,
              //   geometryInstances: copyInstances,
              // })
              // viewer.scene.primitives.remove(primitive)
              // viewer.scene.primitives.add(newPrimitive)
              instanceAttributes.show = Cesium.ShowGeometryInstanceAttribute.toValue(false)
            }
            

            const elementBoundingSpere = new Cesium.BoundingSphere(Cesium.Matrix4.getTranslation(modelMatrix, new Cesium.Cartesian3()), boundingSphere.radius)
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
          console.log('object: ', object);
          if (object && object.primitive instanceof Cesium.Primitive) {
            const primitive = object.primitive as Cesium.Primitive
            const pickId = object.id as number
            const instanceAttributes = primitive.getGeometryInstanceAttributes(object.id as number)
            console.log('instanceAttributes: ', instanceAttributes.color, instanceAttributes.boundingSphere, instanceAttributes.show);
            instanceAttributes.show = Cesium.ShowGeometryInstanceAttribute.toValue(false)
            const pickInstance = (cachedGeometryInstances[0] as Cesium.GeometryInstance[]).find(instance => instance.id === pickId)
            // const isExtiedElement = cachedElementsInstance.findIndex(instance => instance.id === pickId)

            deleteInstances.push(pickInstance!)
            // if (isExtiedElement !== -1) {
            //   const element = elements[isExtiedElement]
            //   viewer.scene.primitives.remove(element)
            //   if (transformer) {
            //     transformer.destory()
            //     transformer = undefined
            //   }
            // } else {

            //   const copyInstances = differenceBy(cachedGeometryInstances[0], [...cachedElementsInstance, ...deleteInstances], 'id');
  
            //   const newPrimitive = new Cesium.Primitive({
            //     ...primitive,
            //     asynchronous: false,
            //     geometryInstances: copyInstances,
            //   })
            //   viewer.scene.primitives.remove(primitive)
            //   viewer.scene.primitives.add(newPrimitive)
            // }

          }
        }, Cesium.ScreenSpaceEventType.RIGHT_CLICK);
        // const modelUrl = await getModelUrl('modelDraco');
        // const model = await loadModel(viewer, modelUrl, boundingSphere)
        // console.log('model: ', model);

        // model.readyEvent.addEventListener(() => {
          // new Transformer({
          //   scene: viewer.scene,
          //   element: primitives[0],
          //   boundingSphere: boundingSphere
          // })
        // })

        viewer.camera.flyToBoundingSphere(boundingSphere, {
          duration: 1,
          offset: new Cesium.HeadingPitchRange(0, Cesium.Math.toRadians(-30), 60),
        })
        // console.log(transformer)

      }
    };
    cb();
  }, [viewer]);

  return <div id="cesiumContainer" className="w-full h-full"></div>;
};

export default BaseMap;
