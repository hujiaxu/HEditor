export enum MapLayerTypeCollection {
  AMap = "AMap",
  Bing = "Bing",
}

export type LayerType =
  | MapLayerTypeCollection.AMap
  | MapLayerTypeCollection.Bing;
