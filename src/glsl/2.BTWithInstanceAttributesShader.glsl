in vec3 position3DHigh;
in vec3 position3DLow;
in vec3 normal;
in vec2 st;
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
  return vec2(centerX + (batchId * numberOfAttributes * stepX), .5);
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
  value *= 255.;
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

void main() {
  vec4 p = czm_computePosition();

  v_positionEC = (czm_modelViewRelativeToEye * p).xyz;// position in eye coordinates
  v_normalEC = czm_normal * normal;// normal in eye coordinates
  v_st = st;

  gl_Position = czm_modelViewProjectionRelativeToEye * p;
}