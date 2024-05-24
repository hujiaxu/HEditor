import * as Cesium from "cesium";

export const flyToTarget = (viewer: Cesium.Viewer, target) => {
  viewer.flyTo(target, {
    offset: new Cesium.HeadingPitchRange(0, Cesium.Math.toRadians(-30), 60),
    duration: 5,
  });
};
