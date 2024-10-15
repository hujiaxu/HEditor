import { defineConfig } from "vite";
import { resolve } from "path";
import react from "@vitejs/plugin-react";
import cesium from "vite-plugin-cesium";
// import glsl from 'vite-plugin-glsl';

function pathResolve(dir: string) {
  return resolve(process.cwd(), ".", dir);
}

export default defineConfig((configEnv) => {
  const isDevelopment = configEnv.mode === "development";

  return {
    plugins: [
      react(),
      cesium(),
      // glsl()
    ],
    server: {
      port: 3000,
      hmr: true
    },
    test: {
      globals: true,
      environment: "happy-dom",
      setupFiles: "./src/infrastructure/tests.setup.ts",
    },
    resolve: {
      alias: [
        {
          find: /\/@\//,
          replacement: pathResolve("src") + "/",
        },
        {
          find: /\/#\//,
          replacement: pathResolve("types") + "/",
        },
      ],
    },
    css: {
      modules: {
        generateScopedName: isDevelopment
          ? "[name]__[local]__[hash:base64:5]"
          : "[hash:base64:5]",
      },
    },
  };
});
