import * as Cesium from "cesium";

import nProgress from "nprogress";

import { isMobile } from "/@/utils/device";
import loadLayer from "./layers";
import { InitMapArgs, MapLayerTypeCollection } from "/@/type";

export default async function mapviewInit({
  container,
  layerType = MapLayerTypeCollection.Bing,
  extendConf = {},
}: InitMapArgs) {
  nProgress.start();

  // 设置使用的token
  Cesium.Ion.defaultAccessToken =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJqdGkiOiI0YzMxODZlYi1jNDhjLTRjODYtODgxNS01ODliNTU0YmY2NDMiLCJpZCI6Njg3NDIsImlhdCI6MTYzMjgyNzg0NH0.FX-F1srgLf2QorYyapx2VL44TJtgkdwdOAG7tqJmSxY";

  // 设置查看的默认矩形（当前设置在中国）
  Cesium.Camera.DEFAULT_VIEW_RECTANGLE = Cesium.Rectangle.fromDegrees(
    80,
    22,
    130,
    50
  );
  // 配置参数
  const baseConf = {
    // imageryProvider: false,
    selectionIndicator: false, // 去掉框选
    showRenderLoopErrors: false,
    baseLayerPicker: false, // 基础影响图层选择器
    navigationHelpButton: false, // 导航帮助按钮
    animation: false, // 动画控件
    timeline: false, // 时间控件
    shadows: true, // 显示阴影
    terrainShadows: Cesium.ShadowMode.RECEIVE_ONLY,

    shouldAnimate: true, // 模型动画效果 大气
    // skyBox: false, // 天空盒
    infoBox: false, // 显示 信息框
    fullscreenButton: false, // 是否显示全屏按钮
    homeButton: true, // 是否显示首页按钮
    geocoder: false, // 默认不显示搜索栏地址
    sceneModePicker: false, // 是否显示视角切换按钮
    requestRenderMode: true, //启用请求渲染模式
    scene3DOnly: true, //每个几何实例将只能以3D渲染以节省GPU内存
    sceneMode: 3, //初始场景模式 1 2D模式 2 2D循环模式 3 3D模式  Cesium.SceneMode
  };

  const viewer = new Cesium.Viewer(container, {
    ...baseConf,
    ...extendConf,
  });

  const terrainLayer = new Cesium.EllipsoidTerrainProvider({});
  viewer.scene.terrainProvider = new Cesium.EllipsoidTerrainProvider({});
  window.terrainProvider = terrainLayer;

  viewer.scene.postProcessStages.fxaa.enabled = true;

  viewer.scene.globe.enableLighting = true;

  loadLayer(layerType, viewer);

  viewer.cesiumWidget.screenSpaceEventHandler.removeInputAction(
    Cesium.ScreenSpaceEventType.LEFT_DOUBLE_CLICK
  );

  if (!isMobile()) {
    // 缩放
    viewer.scene.screenSpaceCameraController.zoomEventTypes = [
      Cesium.CameraEventType.WHEEL,
    ];
    // 平移
    viewer.scene.screenSpaceCameraController.tiltEventTypes = [
      Cesium.CameraEventType.RIGHT_DRAG,
      Cesium.CameraEventType.MIDDLE_DRAG,
    ];
    // 旋转
    viewer.scene.screenSpaceCameraController.rotateEventTypes = [
      Cesium.CameraEventType.LEFT_DRAG,
    ];
  }

  viewer.scene.globe.enableLighting = true;
  viewer.scene.globe.depthTestAgainstTerrain = true;

  viewer.clock.shouldAnimate = true;

  const helper = new Cesium.EventHelper();
  helper.add(viewer.scene.globe.tileLoadProgressEvent, (e) => {
    if (e > 10 || e === 0) {
      nProgress.done();
    } else {
      // console.log('地图资源加载中')
    }
  });
  return viewer;
}
