in vec3 position2DHigh;
in vec3 position2DLow;

in vec2 compressedAttributes;
vec2 st;
vec3 normal;

in vec3 position3DHigh;
in vec3 position3DLow;

in float batchId;

out vec3 v_positionEC;
out vec3 v_normalEC;
out vec2 v_st;

uniform highp sampler2D batchTexture;
uniform vec4 batchTextureStep;
vec2 computeSt(float batchId) {
  float stepX = batchTextureStep.x;
  float centerX = batchTextureStep.y;
  float numberOfAttributes = float(4);
  return vec2(centerX + (batchId * numberOfAttributes * stepX), 0.5);
}

vec4 czm_batchTable_color(float batchId) {
  vec2 st = computeSt(batchId);
  st.x += batchTextureStep.x * float(0);
  vec4 textureValue = texture(batchTexture, st);
  vec4 value = textureValue;
  return value;
}
float czm_batchTable_show(float batchId) {
  vec2 st = computeSt(batchId);
  st.x += batchTextureStep.x * float(1);
  vec4 textureValue = texture(batchTexture, st);
  float value = textureValue.x;
  value *= 255.0;
  return value;
}
vec4 czm_batchTable_otherColor(float batchId) {
  vec2 st = computeSt(batchId);
  st.x += batchTextureStep.x * float(2);
  vec4 textureValue = texture(batchTexture, st);
  vec4 value = textureValue;
  return value;
}
vec4 czm_batchTable_pickColor(float batchId) {
  vec2 st = computeSt(batchId);
  st.x += batchTextureStep.x * float(3);
  vec4 textureValue = texture(batchTexture, st);
  vec4 value = textureValue;
  return value;
}

void czm_non_show_main() {
  vec4 p = czm_computePosition();

  v_positionEC = (czm_modelViewRelativeToEye * p).xyz;      // position in eye coordinates
  v_normalEC = czm_normal * normal;                         // normal in eye coordinates
  v_st = st;

  gl_Position = czm_modelViewProjectionRelativeToEye * p;
}

void czm_non_pick_main() {
  czm_non_show_main();
  gl_Position *= czm_batchTable_show(batchId);
}
out vec4 v_pickColor;
void czm_non_compressed_main() {
  czm_non_pick_main();
  v_pickColor = czm_batchTable_pickColor(batchId);
}
void main() {
  st = czm_decompressTextureCoordinates(compressedAttributes.x);
  normal = czm_octDecode(compressedAttributes.y);
  czm_non_compressed_main();
}
vec4 czm_computePosition() {
  vec4 p;
  if(czm_morphTime == 1.0) {
    p = czm_translateRelativeToEye(position3DHigh, position3DLow);
  } else if(czm_morphTime == 0.0) {
    p = czm_translateRelativeToEye(position2DHigh.zxy, position2DLow.zxy);
  } else {
    p = czm_columbusViewMorph(czm_translateRelativeToEye(position2DHigh.zxy, position2DLow.zxy), czm_translateRelativeToEye(position3DHigh, position3DLow), czm_morphTime);
  }
  return p;
}