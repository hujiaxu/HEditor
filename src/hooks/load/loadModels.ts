import * as Cesium from "cesium";
import { getHeightByTerrian } from "..";

export const loadCesium3dTileset = async (
  viewer: Cesium.Viewer,
  url: string
) => {
  const tileset = await Cesium.Cesium3DTileset.fromUrl(url);
  tileset.shadows = Cesium.ShadowMode.DISABLED;
  viewer.scene.primitives.add(tileset);

  const boundingSphere = tileset.boundingSphere;
  const cartographic = Cesium.Cartographic.fromCartesian(boundingSphere.center);
  const height = await getHeightByTerrian(viewer, cartographic);
  const surface = Cesium.Cartesian3.fromRadians(
    cartographic.longitude,
    cartographic.latitude,
    cartographic.height
  );
  const offset = Cesium.Cartesian3.fromRadians(
    cartographic.longitude,
    cartographic.latitude,
    height! + 30
  );
  const translation = Cesium.Cartesian3.subtract(
    offset,
    surface,
    new Cesium.Cartesian3()
  );
  tileset.modelMatrix = Cesium.Matrix4.fromTranslation(translation);
  tileset.maximumScreenSpaceError = 2;
  return tileset;
};

export const loadModel = async (
  viewer: Cesium.Viewer,
  url: string,
  boundingSphere: Cesium.BoundingSphere
) => {
  const model = await Cesium.Model.fromGltfAsync({
    url,
    modelMatrix: Cesium.Transforms.eastNorthUpToFixedFrame(
      boundingSphere.center
    ),
  });
  viewer.scene.primitives.add(model);
  return model;
};
