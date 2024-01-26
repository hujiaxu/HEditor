import { useRef } from "react";

const HEditor = () => {
  const webgl = useRef<HTMLCanvasElement>(null);
  if (webgl.current) {
    const ctx = webgl.current.getContext("webgl");
    console.log(ctx, "ctx");
  }

  return (
    <div className="w-full h-full relative editor-container">
      <canvas className="absolute h-full w-full" ref={webgl}></canvas>
    </div>
  );
};

export default HEditor;
