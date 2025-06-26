import { useEffect } from "react";
import { Viewer, ScreenSpaceEventHandler, ScreenSpaceEventType, Primitive, Geometry, GeometryAttributes, GeometryAttribute, PrimitiveType, ComponentDatatype, GeometryInstance } from 'HEditor-engine';

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

      // for (const eventName in ScreenSpaceEventType) {
      //   const type = ScreenSpaceEventType[eventName]
      //   handler.setInputAction((event) => {
      //     console.log('event: ' + eventName, event);

      //   }, type)
      // }
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
      // return viewer.draw()
    }
    viewer = new Viewer({
      container: "editor-container",
    })

    const geometry = new Geometry({
      attributes: new GeometryAttributes({
        
        position: new GeometryAttribute({
          componentsPerAttribute: 3,
          componentDatatype: ComponentDatatype.FLOAT,
          values: new Float32Array([
            // Front face
            // v1
            -0.5, -0.5, 0.5,
            // v2
            0.5, -0.5, 0.5,
            // v3
            0.5, 0.5, 0.5,
            // v4
            -0.5, 0.5, 0.5,

            // Back face
            // v5
            -0.5, -0.5, -0.5,
            // v6
            0.5, -0.5, -0.5,
            // v7
            0.5, 0.5, -0.5,
            // v8
            -0.5, 0.5, -0.5,

            // Left face
            -0.5, -0.5, -0.5,
            // v9
            -0.5, -0.5, 0.5,
            // v10
            -0.5, 0.5, 0.5,
            // v11
            -0.5, 0.5, -0.5,

            // Right face
            // v12
            0.5, -0.5, -0.5,
            // v13
            0.5, -0.5, 0.5,
            // v14
            0.5, 0.5, 0.5,
            // v15
            0.5, 0.5, -0.5,

            // Top face
            // v16
            -0.5, 0.5, -0.5,
            // v17
            0.5, 0.5, -0.5,
            // v18
            0.5, 0.5, 0.5,
            // v19
            -0.5, 0.5, 0.5,

            // Bottom face
            // v20
            -0.5, -0.5, -0.5,
            // v21
            0.5, -0.5, -0.5,
            // v22
            0.5, -0.5, 0.5,
            // v23
            -0.5, -0.5, 0.5
          ])
        }),
        color: new GeometryAttribute({
          values: new Float32Array([
            1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0,
            1.0, 0.0, 1.0,

            1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0,
            1.0, 0.0, 1.0,

            1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0,
            1.0, 0.0, 1.0,

            1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0,
            1.0, 0.0, 1.0,

            1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0,
            1.0, 0.0, 1.0,

            1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0,
            1.0, 0.0, 1.0
          ]),
          componentsPerAttribute: 4,
          componentDatatype: ComponentDatatype.FLOAT
        })
      }),
      indices: new Uint16Array([
        // Front face
        4, 5, 6, 4, 6, 7,

        // Back face
        0, 3, 2, 0, 2, 1,

        // Left face
        0, 7, 3, 0, 4, 7,

        // Right face
        1, 2, 6, 1, 6, 5,

        // Top face
        3, 2, 6, 3, 6, 7,

        // Bottom face
        0, 1, 5, 0, 5, 4
      ]),
      primitiveType: PrimitiveType.TRIANGLES
    })
    const geometryInstance = new GeometryInstance({
      geometry: geometry
    })

    const primitive = new Primitive({
      geometryInstances: geometryInstance,
      appearance: undefined
    })

  }, [])

  return (
    <div className="w-full h-full relative" id="editor-container">
      {/* <canvas className="absolute h-full w-full" ref={webgl}></canvas> */}
    </div>
  );
};

export default HEditor;
