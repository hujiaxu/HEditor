// San Francisco Ferry Building photogrammetry model provided by Aerometrex
const viewer = new Cesium.Viewer("cesiumContainer", {
infoBox: false,
orderIndependentTranslucency: false,
terrain: Cesium.Terrain.fromWorldTerrain(),
});

viewer.clock.currentTime = Cesium.JulianDate.fromIso8601(
"2021-11-09T20:27:37.016064475348684937Z"
);

const scene = viewer.scene;

// Fly to a nice overview of the city.
viewer.camera.flyTo({
destination: new Cesium.Cartesian3(
-2703640.80485846,
-4261161.990345464,
3887439.511104276
),
orientation: new Cesium.HeadingPitchRoll(
0.22426651143535548,
-0.2624145362506527,
0.000006972977223185239
),
duration: 0,
});

let tileset;
try {
tileset = await Cesium.Cesium3DTileset.fromIonAssetId(2333904);

const translation = new Cesium.Cartesian3(
-1.398521324920626,
0.7823052871729486,
0.7015244410592609
);
tileset.modelMatrix = Cesium.Matrix4.fromTranslation(translation);

tileset.maximumScreenSpaceError = 8.0;
scene.pickTranslucentDepth = true;
scene.light.intensity = 7.0;

viewer.scene.primitives.add(tileset);
} catch (error) {
console.log(`Error loading tileset: ${error}`);
}

// Styles =============================================================================

const classificationStyle = new Cesium.Cesium3DTileStyle({
color: "color(${color})",
});

const translucentWindowsStyle = new Cesium.Cesium3DTileStyle({
color: {
conditions: [["${component} === 'Windows'", "color('gray', 0.7)"]],
},
});

// Shaders ============================================================================

// Dummy shader that sets the UNLIT lighting mode. For use with the classification style
const emptyFragmentShader =
"void fragmentMain(FragmentInput fsInput, inout czm_modelMaterial material) {}";
const unlitShader = new Cesium.CustomShader({
lightingModel: Cesium.LightingModel.UNLIT,
fragmentShaderText: emptyFragmentShader,
});

const materialShader = new Cesium.CustomShader({
varyings: {
v_normalMC: Cesium.VaryingType.VEC3,
},
uniforms: {
u_texture: {
value: new Cesium.TextureUniform({
url: 'https://seopic.699pic.com/photo/40250/3918.jpg_wh1200.jpg'
}),
type: Cesium.UniformType.SAMPLER_2D
}
},
vertexShaderText: `          void vertexMain(VertexInput vsInput, inout czm_modelVertexOutput vsOutput) {
            v_normalMC = vsInput.attributes.normalMC;
          }
       `,
fragmentShaderText: `
void fragmentMain(FragmentInput fsInput, inout czm_modelMaterial material) {
vec3 positionMC = fsInput.attributes.positionMC;

            float width = 10.0;
            float height = 10.0;

            vec3 rgb = vec3(1.0, 1.0, 1.0);

            if (dot(vec3(0.0, 1.0, 0.0), v_normalMC) > 0.95) {
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
        `
      })

const NOTHING_SELECTED = 12;
const selectFeatureShader = new Cesium.CustomShader({
varyings: {
v_normalMC: Cesium.VaryingType.VEC3,
},
uniforms: {
u_texture: {
value: new Cesium.TextureUniform({
url: 'https://seopic.699pic.com/photo/40250/3637.jpg_wh1200.jpg'
}),
type: Cesium.UniformType.SAMPLER_2D
}
},
vertexShaderText: `          void vertexMain(VertexInput vsInput, inout czm_modelVertexOutput vsOutput) {
            v_normalMC = vsInput.attributes.normalMC;
          }
       `,
fragmentShaderText: `
void fragmentMain(FragmentInput fsInput, inout czm_modelMaterial material) {
vec3 positionMC = fsInput.attributes.positionMC;

            float width = 10.0;
            float height = 10.0;

            vec3 rgb = vec3(1.0, 1.0, 1.0);

            if (dot(vec3(0.0, 1.0, 0.0), v_normalMC) > 0.95) {
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
        `
      })

const multipleFeatureIdsShader = new Cesium.CustomShader({
varyings: {
v_normalMC: Cesium.VaryingType.VEC3,
},
uniforms: {
u_texture: {
value: new Cesium.TextureUniform({
url: 'https://seopic.699pic.com/photo/40108/1832.jpg_wh1200.jpg'
}),
type: Cesium.UniformType.SAMPLER_2D
}
},
vertexShaderText: `          void vertexMain(VertexInput vsInput, inout czm_modelVertexOutput vsOutput) {
            v_normalMC = vsInput.attributes.normalMC;
          }
       `,
fragmentShaderText: `
void fragmentMain(FragmentInput fsInput, inout czm_modelMaterial material) {
vec3 positionMC = fsInput.attributes.positionMC;

            float width = 10.0;
            float height = 10.0;

            vec3 rgb = vec3(1.0, 1.0, 1.0);

            if (dot(vec3(0.0, 1.0, 0.0), v_normalMC) > 0.95) {
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
        `
      })

// Demo Functions =====================================================================

function defaults() {
tileset.style = undefined;
tileset.customShader = unlitShader;
tileset.colorBlendMode = Cesium.Cesium3DTileColorBlendMode.HIGHLIGHT;
tileset.colorBlendAmount = 0.5;
tileset.featureIdLabel = 0;
}

const showPhotogrammetry = defaults;

function showClassification() {
defaults();
tileset.style = classificationStyle;
tileset.colorBlendMode = Cesium.Cesium3DTileColorBlendMode.MIX;
}

function showAlternativeClassification() {
showClassification();
// This dataset has a second feature ID texture.
tileset.featureIdLabel = 1;
}

function translucentWindows() {
defaults();
tileset.style = translucentWindowsStyle;
}

function pbrMaterials() {
defaults();
tileset.customShader = materialShader;
}

function goldenTouch() {
defaults();
tileset.customShader = selectFeatureShader;
}

function multipleFeatureIds() {
defaults();
tileset.customShader = multipleFeatureIdsShader;
}

// Pick Handlers ======================================================================

// HTML overlay for showing feature name on mouseover
const nameOverlay = document.createElement("div");
viewer.container.appendChild(nameOverlay);
nameOverlay.className = "backdrop";
nameOverlay.style.display = "none";
nameOverlay.style.position = "absolute";
nameOverlay.style.bottom = "0";
nameOverlay.style.left = "0";
nameOverlay.style["pointer-events"] = "none";
nameOverlay.style.padding = "4px";
nameOverlay.style.backgroundColor = "black";
nameOverlay.style.whiteSpace = "pre-line";
nameOverlay.style.fontSize = "12px";

let enablePicking = true;
const handler = new Cesium.ScreenSpaceEventHandler(viewer.scene.canvas);
handler.setInputAction(function (movement) {
if (enablePicking) {
const pickedObject = viewer.scene.pick(movement.endPosition);
if (pickedObject instanceof Cesium.Cesium3DTileFeature) {
nameOverlay.style.display = "block";
nameOverlay.style.bottom = `${
        viewer.canvas.clientHeight - movement.endPosition.y
      }px`;
nameOverlay.style.left = `${movement.endPosition.x}px`;
const component = pickedObject.getProperty("component");
const message = `Component: ${component}\nFeature ID: ${pickedObject.featureId}`;
nameOverlay.textContent = message;
} else {
nameOverlay.style.display = "none";
}
} else {
nameOverlay.style.display = "none";
}
}, Cesium.ScreenSpaceEventType.MOUSE_MOVE);

const clickHandler = new Cesium.ScreenSpaceEventHandler(scene.canvas);
handler.setInputAction(function (movement) {
if (enablePicking) {
const pickedObject = scene.pick(movement.position);
if (
Cesium.defined(pickedObject) &&
Cesium.defined(pickedObject.featureId)
) {
selectFeatureShader.setUniform(
"u_selectedFeature",
pickedObject.featureId
);
} else {
selectFeatureShader.setUniform(
"u_selectedFeature",
NOTHING_SELECTED
);
}
}
}, Cesium.ScreenSpaceEventType.LEFT_CLICK);

// UI ============================================================================

Sandcastle.addToggleButton("Enable picking", enablePicking, function (
checked
) {
enablePicking = checked;
});

const demos = [
{
text: "texture1",
onselect: pbrMaterials,
},
{
text: "texture2",
onselect: goldenTouch,
},
{
text: "texture3",
onselect: multipleFeatureIds,
},
];
Sandcastle.addDefaultToolbarMenu(demos);
showClassification();
