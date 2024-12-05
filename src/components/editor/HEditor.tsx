import { useEffect } from "react";
import { Viewer, ScreenSpaceEventHandler, ScreenSpaceEventType } from 'HEditor-engine';

const HEditor = () => {
  let viewer: Viewer | undefined = undefined
  // const webgl = useRef<HTMLCanvasElement>(null);
  // if (webgl.current) {
  //   const ctx = webgl.current.getContext("webgl");
  //   console.log(ctx, "ctx");
  // }
  useEffect(() => {
    if (viewer) {
      console.log('viewer: ', viewer);
      const handler = new ScreenSpaceEventHandler(viewer.canvas)

      for (const eventName in ScreenSpaceEventType) {
        const type = ScreenSpaceEventType[eventName]
        handler.setInputAction((event) => {
          console.log('event: ' + eventName, event);

        }, type)
      }
      // handler.setInputAction((event) => {
      //   console.log('event: LEFT_DOWN', event);

      // }, ScreenSpaceEventType.LEFT_DOWN)
      // handler.setInputAction((event) => {
      //   console.log('event: LEFT_UP', event);

      // }, ScreenSpaceEventType.LEFT_UP)
      // handler.setInputAction((event) => {
      //   console.log('event: LEFT_CLICK', event);

      // }, ScreenSpaceEventType.LEFT_CLICK)

      // handler.setInputAction((event) => {
      //   console.log('event: LEFT_DOUBLE_CLICK', event);

      // }, ScreenSpaceEventType.LEFT_DOUBLE_CLICK)
      return viewer.scene.draw()
    }
    viewer = new Viewer({
      container: "editor-container",
    })

  }, [])

  return (
    <div className="w-full h-full relative" id="editor-container">
      {/* <canvas className="absolute h-full w-full" ref={webgl}></canvas> */}
    </div>
  );
};

export default HEditor;
