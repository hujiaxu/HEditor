import * as Cesium from "cesium";
import { useEffect, useState } from "react";
import initMap from "/@/hooks/initMap";
import { flyToTarget, loadCesium3dTileset } from "/@/hooks";
import { getTilesetUrl } from "/@/utils/url";
import React from "react";
import Transformer from 'cesium-transformer';
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

  useEffect(() => {
    const cb = async () => {
      const viewer = await initMap({
        container: "cesiumContainer",
      });

      const tilesetUrl = await getTilesetUrl("1217138133700055040");

      const tileset = await loadCesium3dTileset(viewer, tilesetUrl);

      // flyToTarget(viewer, tileset);

      const polygon = createPolygon()
      if (viewer) {
        const element = viewer.scene.primitives.add(polygon)
        const boundingSphere = Cesium.BoundingSphere.fromPoints(pos)

        new Transformer({
          scene: viewer.scene,
          element: tileset,
          boundingSphere: tileset.boundingSphere
        })

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
