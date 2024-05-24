import { LayerType } from "./layer";

export interface InitMapArgs {
  container: string;

  layerType?: LayerType;

  extendConf?: any;
}
