import { useEffect, useRef } from "react";
import getRenderingContext from "renderer/engine/webglProgram";

const HEditor = () => {
  const canvasRef = useRef(null);

  useEffect(() => {
    if (canvasRef.current) {
      const el: HTMLCanvasElement = canvasRef.current;
      const engine = getRenderingContext(el);
      console.log(engine);
    }
  }, [canvasRef?.current]);
  return (
    <div className="relative h-full w-full">
      <canvas
        className="absolute h-full w-full"
        id="canvas"
        ref={canvasRef}
      ></canvas>
    </div>
  );
};

export default HEditor;
