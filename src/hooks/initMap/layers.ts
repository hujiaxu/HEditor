import * as Cesium from "cesium";
import { LayerType, MapLayerTypeCollection } from "/@/type";

export const loadAMapLayer = (viewer: Cesium.Viewer) => {
  const gaodeImageryProvider = new Cesium.UrlTemplateImageryProvider({
    url: "http://webrd02.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}",
    minimumLevel: 3,
    maximumLevel: 19,
  });

  viewer.imageryLayers.addImageryProvider(gaodeImageryProvider);
};

export const loadBingMap = async (viewer: Cesium.Viewer) => {
  const bingLayer = await Cesium.BingMapsImageryProvider.fromUrl(
    "https://dev.virtualearth.net",
    {
      key: "At1kjRSVm-Rj2Hw2y16DQhb2NYcLYvQh4GVt-S1S_f7CG_lBZPvNzkS2m41VomIg",
    }
  );
  const imageryLayers = new Cesium.ImageryLayer(bingLayer);

  viewer.imageryLayers.add(imageryLayers);
};

const loadLayer = (type: LayerType, viewer: Cesium.Viewer) => {
  switch (type) {
    case MapLayerTypeCollection.AMap:
      return loadAMapLayer(viewer);
    case MapLayerTypeCollection.Bing:
      return loadBingMap(viewer);
    default:
      return loadAMapLayer(viewer);
  }
};

export default loadLayer;
