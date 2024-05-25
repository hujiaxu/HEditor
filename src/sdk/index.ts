import * as Cesium from 'cesium'
import { DrawElementType } from '/@/type'
import Drawer from './drawer'

export default class SDK {

  public viewer: Cesium.Viewer

  public drawer: Drawer | undefined

  private handler: Cesium.ScreenSpaceEventHandler

  private onLeftDown: any
  private onLeftUp: any
  private onLeftClick: any
  private onRightClick: any
  private onLeftDoubleClick: any
  private onMouseMove: any

  constructor(viewer: Cesium.Viewer) {

    if (!viewer) throw new Error("viewer is not exist")

    this.viewer = viewer

    this.handler = new Cesium.ScreenSpaceEventHandler(viewer.scene.canvas)

    this.onLeftDown = this.leftDown.bind(this)
    this.onLeftUp = this.leftUp.bind(this)
    this.onLeftClick = this.leftClick.bind(this)
    this.onLeftDoubleClick = this.leftDoubleClick.bind(this)
    this.onMouseMove = this.mouseMove.bind(this)
    this.onRightClick = this.rightClick.bind(this)
    this.registerHandler()
  }

  public startDraw(type: DrawElementType, key: string) {
    this.drawer = new Drawer(type, key)
  }

  private leftDown() {

  }
  private leftUp() {
    
  }
  private leftClick() {

  }

  private leftDoubleClick() {
  }

  private mouseMove() {

  }

  private rightClick() {

  }

  private registerHandler() {
    const handler = this.handler

    handler.setInputAction(this.onLeftDown, Cesium.ScreenSpaceEventType.LEFT_DOWN)
    handler.setInputAction(this.onLeftUp, Cesium.ScreenSpaceEventType.LEFT_UP)
    handler.setInputAction(this.onLeftClick, Cesium.ScreenSpaceEventType.LEFT_CLICK)
    handler.setInputAction(this.onLeftDoubleClick, Cesium.ScreenSpaceEventType.LEFT_DOUBLE_CLICK)
    handler.setInputAction(this.onMouseMove, Cesium.ScreenSpaceEventType.MOUSE_MOVE)
    handler.setInputAction(this.onRightClick, Cesium.ScreenSpaceEventType.RIGHT_CLICK)
  }

  public destroy() {
    const handler = this.handler

    handler.removeInputAction(Cesium.ScreenSpaceEventType.LEFT_DOWN, this.onLeftDown)
    handler.removeInputAction(Cesium.ScreenSpaceEventType.LEFT_UP, this.onLeftUp)
    handler.removeInputAction(Cesium.ScreenSpaceEventType.LEFT_CLICK, this.onLeftClick)
    handler.removeInputAction(Cesium.ScreenSpaceEventType.LEFT_DOUBLE_CLICK, this.onLeftDoubleClick)
    handler.removeInputAction(Cesium.ScreenSpaceEventType.MOUSE_MOVE, this.onMouseMove)
    handler.removeInputAction(Cesium.ScreenSpaceEventType.RIGHT_CLICK, this.onRightClick)
    this.handler.destroy()
  }
}