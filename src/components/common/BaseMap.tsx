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

const createShader = (height: Cesium.Cartesian3, ECEFToENURTC: Cesium.Matrix4, ENUToENEFRTC: Cesium.Matrix4, inverseModelViewMatrix: Cesium.Matrix4) => {
  const customShader = new Cesium.CustomShader({
    uniforms: {
      u_flattenHeight: {
        type: Cesium.UniformType.VEC3,
        value: height
      },
      u_ECEFToENU_RTC: {
        type: Cesium.UniformType.MAT4,
        value: ECEFToENURTC
      },
      u_ENUToECEF_RTC: {
        type: Cesium.UniformType.MAT4,
        value: ENUToENEFRTC
      },
      u_inverseModelViewMatrix: {
        type: Cesium.UniformType.MAT4,
        value: inverseModelViewMatrix
      }
    },
    varyings: {
      v_selectedColor: Cesium.VaryingType.VEC4
    },
    vertexShaderText: `
    in vec3 position3DHigh;
    in vec3 position3DLow;

    vec4 czm_computePosition() {
      return czm_translateRelativeToEye(position3DHigh.zxy, position3DLow.zxy);
    }
    void vertexMain(VertexInput vsInput, inout czm_modelVertexOutput vsOutput) {
      vec4 p = czm_computePosition();
      vec3 positionMC = vsInput.attributes.positionMC;
      vec4 positionWC = czm_model * vec4(positionMC, 1.0);
      vec4 positionEC = czm_modelView * vec4(positionMC, 1.0);

      vec4 flattenPos = czm_view *  vec4(u_flattenHeight, 1.);
      vec4 positionRelativeToEye = czm_modelViewRelativeToEye * vec4(positionMC, 1.0);

      // vec4 positionENU = u_ECEFToENU * czm_model * vec4(positionMC, 1.0);
      // vec4 flattenPos = vec4(positionENU.xy / positionENU.w, 1., 1.0);
      // vsOutput.positionMC = vec4(czm_inverseModel * u_ENUToECEF * flattenPos).xyz;

      // vec4 positionENURTC = u_ECEFToENU_RTC * positionEC;
      // vec4 flattenPos = vec4(positionENURTC.xy / positionENURTC.w, 1., 1.0);
      // vsOutput.positionMC = vec4(czm_inverseModelView * u_ENUToECEF_RTC * flattenPos).xyz;

      // positionEC.z = flattenPos.z; 
      vsOutput.positionMC = vec4(czm_inverseModelView * positionEC).xyz;

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

      const relativeToCamera = Cesium.Cartesian3.subtract(tileset.boundingSphere.center, viewer.camera.position, new Cesium.Cartesian3());

      const ENUToENEFRTC = Cesium.Transforms.eastNorthUpToFixedFrame(relativeToCamera)
      const ENEFToENURTC = Cesium.Matrix4.inverse(ENUToENEFRTC, new Cesium.Matrix4())

      const ENUToECEF = Cesium.Transforms.eastNorthUpToFixedFrame(tileset.boundingSphere.center)
      const ENUToECEFZero = Cesium.Transforms.eastNorthUpToFixedFrame(Cesium.Cartesian3.ZERO.clone())

      console.log('ENUToECEF: ', Cesium.Matrix4.packArray([ENUToECEF], []), Cesium.Matrix4.packArray([ENUToECEFZero], []));
      const ECEFToENU = Cesium.Matrix4.inverse(ENUToECEF, new Cesium.Matrix4())

      var modelViewMatrix = viewer.camera.viewMatrix;  // 这是相机的视图矩阵
      var inverseModelViewMatrix = Cesium.Matrix4.inverse(modelViewMatrix, new Cesium.Matrix4())
      const customShader = createShader(tileset.boundingSphere.center, ENEFToENURTC, ENUToENEFRTC, inverseModelViewMatrix)

      tileset.customShader = customShader


      flyToTarget(viewer, tileset);

    };
    cb();
  }, [viewer]);

  return <div id="cesiumContainer" className="w-full h-full"></div>;
};

export default BaseMap;
