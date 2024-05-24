import * as Cesium from 'cesium';
export const flyToTarget = (viewer, target) => {
    viewer.flyTo(target, {
        offset: new Cesium.HeadingPitchRange(0, Cesium.Math.toRadians(-30), 60),
        duration: 5
    });
};
//# sourceMappingURL=view.js.map