import { DrawElementType, DrawElementTypeCollection } from "/@/type";

export default class DrawPolygon {

  public type: DrawElementType = DrawElementTypeCollection.POLYGON

  public activeKey: string

  constructor(key: string) {
    if (!key) throw new Error('key is not exist')
    this.activeKey = key
  }


  leftDown() {
    
  }

  leftUp() {

  }

  leftClick() {

  }

  leftDoubleClick() {

  }

  mouseMove() {

  }

  rightClick() {

  }
}