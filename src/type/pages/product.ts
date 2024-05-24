export enum ProductTypeCollection {
  COLOR_STEEL_TILE_ROOF = "COLOR_STEEL_TILE_ROOF", // 彩钢瓦屋顶
  CONCRETE_ROOF = "CONCRETE_ROOF", // 混凝土屋顶
  SUNCANOPY = "SUNCANOPY", // 阳光棚
  FLOWER_FRAME_SUN_SHED = "FLOWER_FRAME_SUN_SHED", // 花架阳光棚
  PHOTOVOLTAIC_CAR_SHED = "PHOTOVOLTAIC_CAR_SHED", // 光伏车棚
}

export type ProductType = keyof typeof ProductTypeCollection;

export const ProductKeyMap: Record<ProductType, string> = {
  COLOR_STEEL_TILE_ROOF: "彩钢瓦屋顶",
  CONCRETE_ROOF: "混凝土屋顶",
  SUNCANOPY: "阳光棚",
  FLOWER_FRAME_SUN_SHED: "花架阳光棚",
  PHOTOVOLTAIC_CAR_SHED: "光伏车棚",
};
