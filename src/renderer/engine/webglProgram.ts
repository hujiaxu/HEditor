import { Shaders } from "types/renderer";

const getRenderingContext = (canvas: HTMLCanvasElement) => {
  canvas.height = canvas.parentElement!.clientHeight;
  canvas.width = canvas.parentElement!.clientWidth;
  const webgl = canvas.getContext("webgl");

  return webgl;
};

export const createAndLinkProgram = (
  gl: WebGLRenderingContext,
  shaders: Shaders
) => {
  const vsSource = shaders._vertexText;
  const fsShource = shaders._fragmentText;

  const vertexShader = gl.createShader(gl.VERTEX_SHADER);
  if (!vertexShader) {
    throw new Error("Failed to create vertex shader");
  }
  gl.shaderSource(vertexShader, vsSource);
  gl.compileShader(vertexShader);

  const fragmentShader = gl.createShader(gl.FRAGMENT_SHADER);
  if (!fragmentShader) {
    throw new Error("Failed to create fragment shader");
  }
  gl.shaderSource(fragmentShader, fsShource);
  gl.compileShader(fragmentShader);

  const program = gl.createProgram();
  if (!program) {
    throw new Error("Failed to create program");
  }

  gl.attachShader(program, vertexShader);
  gl.attachShader(program, fragmentShader);
  return program;
};

export default getRenderingContext;
