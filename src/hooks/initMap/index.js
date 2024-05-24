import * as Cesium from 'cesium';
import nProgress from 'nprogress';
import { isMobile } from '/@/utils/device';
import loadLayer from './layers';
import { MapLayerTypeCollection } from '/@/type';
export default async function mapviewInit({ container, layerType = MapLayerTypeCollection.Bing, extendConf = {}, }) {
    nProgress.start();
    Cesium.Ion.defaultAccessToken =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJqdGkiOiI0YzMxODZlYi1jNDhjLTRjODYtODgxNS01ODliNTU0YmY2NDMiLCJpZCI6Njg3NDIsImlhdCI6MTYzMjgyNzg0NH0.FX-F1srgLf2QorYyapx2VL44TJtgkdwdOAG7tqJmSxY";
    Cesium.Camera.DEFAULT_VIEW_RECTANGLE = Cesium.Rectangle.fromDegrees(80, 22, 130, 50);
    const baseConf = {
        selectionIndicator: false,
        showRenderLoopErrors: false,
        baseLayerPicker: false,
        navigationHelpButton: false,
        animation: false,
        timeline: false,
        shadows: true,
        terrainShadows: Cesium.ShadowMode.RECEIVE_ONLY,
        shouldAnimate: true,
        infoBox: false,
        fullscreenButton: false,
        homeButton: true,
        geocoder: false,
        sceneModePicker: false,
        requestRenderMode: true,
        scene3DOnly: true,
        sceneMode: 3,
    };
    const viewer = new Cesium.Viewer(container, {
        ...baseConf,
        ...extendConf
    });
    const terrainLayer = new Cesium.EllipsoidTerrainProvider({});
    viewer.scene.terrainProvider = new Cesium.EllipsoidTerrainProvider({});
    window.terrainProvider = terrainLayer;
    viewer.scene.postProcessStages.fxaa.enabled = true;
    viewer.scene.globe.enableLighting = true;
    loadLayer(layerType, viewer);
    viewer.cesiumWidget.screenSpaceEventHandler.removeInputAction(Cesium.ScreenSpaceEventType.LEFT_DOUBLE_CLICK);
    if (!isMobile()) {
        viewer.scene.screenSpaceCameraController.zoomEventTypes = [Cesium.CameraEventType.WHEEL];
        viewer.scene.screenSpaceCameraController.tiltEventTypes = [
            Cesium.CameraEventType.RIGHT_DRAG,
            Cesium.CameraEventType.MIDDLE_DRAG,
        ];
        viewer.scene.screenSpaceCameraController.rotateEventTypes = [Cesium.CameraEventType.LEFT_DRAG];
    }
    viewer.scene.globe.enableLighting = true;
    viewer.scene.globe.depthTestAgainstTerrain = true;
    viewer.clock.shouldAnimate = true;
    const helper = new Cesium.EventHelper();
    helper.add(viewer.scene.globe.tileLoadProgressEvent, (e) => {
        if (e > 10 || e === 0) {
            nProgress.done();
        }
        else {
        }
    });
    return viewer;
}
//# sourceMappingURL=index.js.map