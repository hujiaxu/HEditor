export enum DrawElementTypeCollection {
  POINT = "POINT",
  POLYLINE = "POLYLINE",
  POLYGON = "POLYGON",
  CIRCLE = "CIRCLE",
  TEXT = "TEXT",
  ELLIPSE = "ELLIPSE",
  POLYLINEEDIT = "POLYLINEEDIT",
}

export type DrawElementType = keyof typeof DrawElementTypeCollection
