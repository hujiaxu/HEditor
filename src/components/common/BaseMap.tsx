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

const createShader = (height: number, upVector: Cesium.Cartesian3) => {
  const customShader = new Cesium.CustomShader({
    uniforms: {
      u_flattenHeight: {
        type: Cesium.UniformType.FLOAT,
        value: height
      },
      u_upVector: {
        type: Cesium.UniformType.VEC3,
        value: upVector
      }
    },
    varyings: {
      v_selectedColor: Cesium.VaryingType.VEC4
    },
    vertexShaderText: `
    void vertexMain(VertexInput vsInput, inout czm_modelVertexOutput vsOutput) {
      vec3 normalEC = czm_normal * vsInput.attributes.normalMC;
      vec3 positionMC = vsInput.attributes.positionMC;
      mat3 m = czm_eastNorthUpToEyeCoordinates(positionMC, normalEC);
      vec3 upInEye = m * u_upVector;
      vec4 viewpos = (czm_modelView * vec4(vsInput.attributes.positionMC, 1.0));
      vec3 viewposvec3=viewpos.xyz/viewpos.w;
      vec3 outPos = viewposvec3 + upInEye;
      vsOutput.positionMC = vec4(czm_inverseModelView * vec4(outPos, 1.0)).xyz;
      vsOutput.positionMC.z = 1.0;
    }
      `,
  });

  return customShader
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

      tileset.style = undefined

      const modelMatrix = Cesium.Transforms.eastNorthUpToFixedFrame(tileset.boundingSphere.center)

      const modelMatrixInverse = Cesium.Matrix4.inverse(modelMatrix, new Cesium.Matrix4())

      const posInECEF = Cesium.Matrix4.multiplyByPoint(modelMatrixInverse, tileset.boundingSphere.center, new Cesium.Cartesian3())
      const customShader = createShader(tileset.boundingSphere.center.z, viewer.scene.camera.up)

      tileset.customShader = customShader


      flyToTarget(viewer, tileset);

    };
    cb();
  }, [viewer]);

  return <div id="cesiumContainer" className="w-full h-full"></div>;
};

export default BaseMap;
