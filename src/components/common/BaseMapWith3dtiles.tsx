import * as Cesium from "cesium";
import { useEffect, useState } from "react";
import initMap from "/@/hooks/initMap";
import React from "react";
import Transformer from 'cesium-transformer';
import { getTilesetUrl } from "/@/utils/url";
import { loadCesium3dTileset } from "/@/hooks";
// import SDK from "/@/sdk";


const BaseMapWith3dtiles = () => {
  const [viewer] = useState<Cesium.Viewer>();
  useEffect(() => {
    const cb = async () => {
      const viewer = await initMap({
        container: "cesiumContainer",
      });

      if (viewer) {

        const tilesUrl = await getTilesetUrl('GSY-2025062700002-0');
        const tileset = await loadCesium3dTileset(viewer, tilesUrl);

        const center = tileset?.boundingSphere.center
        if (center) {
            const customShader = new Cesium.CustomShader({
                vertexShaderText: `
                    void vertexMain(VertexInput vsInput, inout czm_modelVertexOutput vsOutput) {
                        vec4 centerModel = czm_inverseModel * vec4(${center.x}, ${center.y}, ${center.z}, 1.0);
                        vsOutput.positionMC.z = centerModel.z;
                    }
                `
            })
            tileset.customShader = customShader
            tileset.debugShowBoundingVolume = true;
tileset.debugColorizeTiles = true;
        }

        let transformer: Transformer | undefined = undefined

        const boundingSphere = new Cesium.BoundingSphere(tileset.boundingSphere.center, 10)
        
        transformer = new Transformer({
          scene: viewer.scene,
          element: tileset,
          boundingSphere: boundingSphere
        })

        viewer.camera.flyToBoundingSphere(tileset.boundingSphere, {
          duration: 1,
          offset: new Cesium.HeadingPitchRange(0, Cesium.Math.toRadians(-30), 60),
        })

        const handler = new Cesium.ScreenSpaceEventHandler(viewer.canvas);
handler.setInputAction(function (movement) {
  // 1. 拾取当前光标下的几何
  const picked = viewer.scene.pick(movement.position);
  if (!Cesium.defined(picked) || !picked.content) return;

  // 2. Cesium3DTileContent.url 就是实际下载的 b3dm 路径
  const url = picked.content.url;   // 绝对或相对 URL
  console.log('这块瓦片来自:', url);
}, Cesium.ScreenSpaceEventType.LEFT_CLICK);


      }
    };
    cb();
  }, [viewer]);


  return <div id="cesiumContainer" className="w-full h-full">
  </div>;
};

export default BaseMapWith3dtiles;
