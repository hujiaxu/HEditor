import {
  Ion,
  Viewer,
  CustomShader,
  VaryingType,
  TextureUniform,
  UniformType,
  Cesium3DTileset,
  LightingModel,
  Cesium3DTileColorBlendMode,
  ImageryLayer,
  BingMapsImageryProvider,
} from "cesium";
import { useEffect } from "react";

const CesiumBuildingTexture = () => {
  let tileset: Cesium3DTileset | undefined;
  Ion.defaultAccessToken =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJqdGkiOiI0YzMxODZlYi1jNDhjLTRjODYtODgxNS01ODliNTU0YmY2NDMiLCJpZCI6Njg3NDIsImlhdCI6MTYzMjgyNzg0NH0.FX-F1srgLf2QorYyapx2VL44TJtgkdwdOAG7tqJmSxY";

  useEffect(() => {
    const cb = async () => {
      const viewer = new Viewer("cesiumContainer");

      const bingLayer = await BingMapsImageryProvider.fromUrl(
        "https://dev.virtualearth.net",
        {
          key: "At1kjRSVm-Rj2Hw2y16DQhb2NYcLYvQh4GVt-S1S_f7CG_lBZPvNzkS2m41VomIg",
        }
      );
      const imageryLayers = new ImageryLayer(bingLayer);

      viewer.imageryLayers.add(imageryLayers);

      try {
        const tileset = await Cesium3DTileset.fromIonAssetId(2432898);

        viewer.scene.primitives.add(tileset);
        await viewer.zoomTo(tileset);

        defaultAction();
        tileset.customShader = createShader(
          "https://seopic.699pic.com/photo/40250/3918.jpg_wh1200.jpg"
        );
      } catch (error) {
        console.log(error, "error");
      }
    };
    cb();
  }, []);

  const emptyFragmentShader =
    "void fragmentMain(FragmentInput fsInput, inout czm_modelMaterial material) {}";
  const unlitShader = new CustomShader({
    lightingModel: LightingModel.UNLIT,
    fragmentShaderText: emptyFragmentShader,
  });

  const defaultAction = () => {
    if (tileset) {
      tileset.style = undefined;
      tileset.customShader = unlitShader;
      tileset.colorBlendMode = Cesium3DTileColorBlendMode.HIGHLIGHT;
      tileset.colorBlendAmount = 0.5;
    }
  };

  const createShader = (texture: string) => {
    const customShader = new CustomShader({
      varyings: {
        v_normalMC: VaryingType.VEC3,
      },
      uniforms: {
        u_texture: {
          value: new TextureUniform({
            url: texture,
          }),
          type: UniformType.SAMPLER_2D,
        },
      },
      vertexShaderText: `
        void vertexMain(VertexInput vsInput, inout czm_modelVertexOutput vsOutput) {
          v_normalMC = vsInput.attributes.normalMC;
        }
      `,
      fragmentShaderText: `
        void fragmentMain(FragmentInput fsInput, inout czm_modelMaterial material) {
          
          vec3 positionMC = fsInput.attributes.positionMC;

          float width = 10.0;
          float height = 10.0;
          
          vec3 rgb = vec3(1.0, 1.0, 1.0);

          if (dot(vec3(0.0, 0.0, 1.0), v_normalMC) > 0.95) {
            material.diffuse = rgb;
          } else {

            float textureX = 0.0;
            float dotYAxis = dot(vec3(0.0, 0.0, 1.0), v_normalMC);
            if (dotYAxis > 0.71 || dotYAxis < -0.71) {
              textureX = mod(positionMC.x, width) / width;
            } else {
              textureX = mod(positionMC.z, width) / width;
            }

            float textureY = mod(positionMC.y, height) / height;
            
            rgb = texture(u_texture, vec2(textureX, textureY)).rgb;

            material.diffuse = rgb;
          }
        }
      `,
    });

    return customShader;
  };
  return (
    <div className="w-full h-full relative editor-container">
      <div id="cesiumContainer" className="w-full h-full"></div>
    </div>
  );
};

export default CesiumBuildingTexture;
