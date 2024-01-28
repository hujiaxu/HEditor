const getRenderingContext = (canvas: HTMLCanvasElement) => {
  canvas.height = canvas.parentElement!.clientHeight;
  canvas.width = canvas.parentElement!.clientWidth;
  const webgl = canvas.getContext("webgl");

  return webgl;
};

export default getRenderingContext;
