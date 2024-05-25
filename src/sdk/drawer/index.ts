import DrawPoint from "./drawPoint"
import DrawPolygon from "./drawPolygon"
import DrawPolyline from "./drawPolyline"
import { DrawElementType, DrawElementTypeCollection } from "/@/type"

export default class Drawer {

  private activeDrawer!: DrawPoint | DrawPolygon | DrawPolyline

  constructor(type: DrawElementType, key: string) {
    if (!type) throw new Error('DrawType is not exist')
    
    this.initDrawer(type, key)
  }

  private initDrawer(type: DrawElementType, key: string) {
    switch (type) {
      case DrawElementTypeCollection.POINT:
        this.activeDrawer = new DrawPoint(key)
        break
      case DrawElementTypeCollection.POLYLINE:
        this.activeDrawer = new DrawPolyline(key)
        break
      case DrawElementTypeCollection.POLYGON:
        this.activeDrawer = new DrawPolygon(key)
        break
      default:
        break
    }
  }

  public leftDown() {
    this.activeDrawer.leftDown()
  }

  public leftUp() {
    this.activeDrawer.leftUp()
  }

  public leftClick() {
    this.activeDrawer.leftClick()
  }

  public leftDoubleClick() {
    this.activeDrawer.leftDoubleClick()
  }

  public mouseMove() {
    this.activeDrawer.mouseMove()
  }

  public rightClick() {
    this.activeDrawer.rightClick()
  }
}

