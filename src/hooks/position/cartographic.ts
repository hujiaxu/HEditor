import * as Cesium from "cesium";

export const getHeightByTerrian = async (
  viewer: Cesium.Viewer,
  cartographic: Cesium.Cartographic
) => {
  try {
    const pos = Cesium.Cartographic.fromRadians(
      cartographic.longitude,
      cartographic.latitude
    );
    const updatePositions = await Cesium.sampleTerrain(
      viewer.terrainProvider,
      12,
      [pos]
    );
    return updatePositions[0].height || 0;
  } catch (error) {
    console.log("error: ", error);
  }
};
