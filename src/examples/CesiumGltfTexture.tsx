import {
  Ion,
  Viewer,
  CustomShader,
  VaryingType,
  TextureUniform,
  UniformType,
  LightingModel,
  ImageryLayer,
  BingMapsImageryProvider,
  Model,
  HeadingPitchRoll,
  Ellipsoid,
  Cartesian3,
  Transforms,
  IonResource,
  CameraEventType,
  PostProcessStage,
  ScreenSpaceEventHandler,
  Color,
  defined,
  ScreenSpaceEventType,
} from "cesium";
import { useEffect } from "react";
import wuding from "./ribbon.png";

const CesiumBuildingTexture = () => {
  Ion.defaultAccessToken =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJqdGkiOiI0YzMxODZlYi1jNDhjLTRjODYtODgxNS01ODliNTU0YmY2NDMiLCJpZCI6Njg3NDIsImlhdCI6MTYzMjgyNzg0NH0.FX-F1srgLf2QorYyapx2VL44TJtgkdwdOAG7tqJmSxY";

  const materialShader = new CustomShader({
    varyings: {
      v_normalMC: VaryingType.VEC3,
    },
    uniforms: {
      u_texture: {
        value: new TextureUniform({
          url: wuding,
        }),
        type: UniformType.SAMPLER_2D,
      },
    },
    vertexShaderText: `
    void vertexMain(VertexInput vsInput, inout czm_modelVertexOutput vsOutput) {
      v_normalMC = vsInput.attributes.normalMC;
    }
  `,
    lightingModel: LightingModel.PBR,
    fragmentShaderText: `
      const int WINDOW = 0;
      const int FRAME = 1;
      const int WALL = 2;
      const int ROOF = 3;
      const int SKYLIGHT = 4;
      const int AIR_CONDITIONER_WHITE = 5;
      const int AIR_CONDITIONER_BLACK = 6;
      const int AIR_CONDITIONER_TALL = 7;
      const int CLOCK = 8;
      const int PILLARS = 9;
      const int STREET_LIGHT = 10;
      const int TRAFFIC_LIGHT = 11;

      void fragmentMain(FragmentInput fsInput, inout czm_modelMaterial material) {
        int featureId = fsInput.featureIds.featureId_0;


        vec3 positionMC = fsInput.attributes.positionMC;

        float width = 10.0;
        float height = 20.0;
        
        vec3 rgb = vec3(1.0, 1.0, 1.0);


        material.roughness = 0.0;
        material.alpha = 1.0;

        if (featureId == 1) {

          float textureX = mod(positionMC.x, width) / width;
          float textureY = mod(positionMC.z, height) / height;
          
          material.diffuse = texture(u_texture, vec2(textureX, textureY)).rgb;
        } else if (featureId == 10) {
          material.diffuse = vec3(1.0, 0.0, 0.0);
        } else if (featureId == 6) {
          material.diffuse = vec3(0.0, 0.0, 1.0);
        } else if (featureId == 4) {
          material.diffuse = vec3(0.5, 0.0, 0.5);
        } else if (featureId == 8) {
          material.diffuse = vec3(0.5, 0.5, 0.5);
        }
      }
      `,
  });
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

      const resource = await IonResource.fromAssetId(2487480);

      try {
        const headingPositionRoll = new HeadingPitchRoll();
        const model = await Model.fromGltfAsync({
          url: resource,
          modelMatrix: Transforms.headingPitchRollToFixedFrame(
            Cartesian3.fromDegrees(0, 0, 100),
            headingPositionRoll,
            Ellipsoid.WGS84
          ),
          customShader: materialShader,
        });

        viewer.scene.primitives.add(model);

        const removeListener = model.readyEvent.addEventListener(() => {
          viewer.camera.flyToBoundingSphere(model.boundingSphere, {
            duration: 0.0,
          });

          removeListener();
        });

        viewer.scene.screenSpaceCameraController.tiltEventTypes = [
          CameraEventType.RIGHT_DRAG,
          CameraEventType.MIDDLE_DRAG,
        ];
        // 旋转
        viewer.scene.screenSpaceCameraController.rotateEventTypes = [
          CameraEventType.LEFT_DRAG,
        ];

        // Shade selected model with highlight.
        const fragmentShaderSource = `
        uniform sampler2D colorTexture;
        in vec2 v_textureCoordinates;
        uniform vec4 highlight;
        void main() {
            vec4 color = texture(colorTexture, v_textureCoordinates);
            if (czm_selected()) {
                vec3 highlighted = highlight.a * highlight.rgb + (1.0 - highlight.a) * color.rgb;
                out_FragColor = vec4(highlighted, 1.0);
            } else { 
                out_FragColor = color;
            }
        }
        `;

        const stage = viewer.scene.postProcessStages.add(
          new PostProcessStage({
            fragmentShader: fragmentShaderSource,
            uniforms: {
              highlight: function () {
                return new Color(1.0, 0.0, 0.0, 0.5);
              },
            },
          })
        );
        stage.selected = [];

        const handler = new ScreenSpaceEventHandler(viewer.scene.canvas);
        handler.setInputAction(
          (movement: ScreenSpaceEventHandler.MotionEvent) => {
            const pickedObject = viewer.scene.pick(movement.endPosition);
            console.log(pickedObject, "pickedObject");
            if (defined(pickedObject)) {
              stage.selected = [pickedObject.primitive];
            } else {
              stage.selected = [];
            }
          },
          ScreenSpaceEventType.MOUSE_MOVE
        );
      } catch (error) {
        console.log(error, "error");
      }
    };
    cb();
  }, []);

  return (
    <div className="w-full h-full relative editor-container">
      <div id="cesiumContainer" className="w-full h-full"></div>
    </div>
  );
};

export default CesiumBuildingTexture;
