#version 300 es
#define SHADOW_MAP
#define OES_texture_float_linear
#define OES_texture_float
#line 0
uniform vec3 czm_encodedCameraPositionMCLow;
uniform vec3 czm_encodedCameraPositionMCHigh;
float czm_signNotZero(float value) {
  return value >= 0.0f ? 1.0f : -1.0f;
}
vec2 czm_signNotZero(vec2 value) {
  return vec2(czm_signNotZero(value.x), czm_signNotZero(value.y));
}
vec3 czm_signNotZero(vec3 value) {
  return vec3(czm_signNotZero(value.x), czm_signNotZero(value.y), czm_signNotZero(value.z));
}
vec4 czm_signNotZero(vec4 value) {
  return vec4(czm_signNotZero(value.x), czm_signNotZero(value.y), czm_signNotZero(value.z), czm_signNotZero(value.w));
}
vec4 czm_columbusViewMorph(vec4 position2D, vec4 position3D, float time) {
  vec3 p = mix(position2D.xyz, position3D.xyz, time);
  return vec4(p, 1.0f);
}
vec4 czm_translateRelativeToEye(vec3 high, vec3 low) {
  vec3 highDifference = high - czm_encodedCameraPositionMCHigh;
  if(length(highDifference) == 0.0f) {
    highDifference = vec3(0);
  }
  vec3 lowDifference = low - czm_encodedCameraPositionMCLow;
  return vec4(highDifference + lowDifference, 1.0f);
}
uniform float czm_morphTime;
vec3 czm_octDecode(vec2 encoded, float range) {
  if(encoded.x == 0.0f && encoded.y == 0.0f) {
    return vec3(0.0f, 0.0f, 0.0f);
  }
  encoded = encoded / range * 2.0f - 1.0f;
  vec3 v = vec3(encoded.x, encoded.y, 1.0f - abs(encoded.x) - abs(encoded.y));
  if(v.z < 0.0f) {
    v.xy = (1.0f - abs(v.yx)) * czm_signNotZero(v.xy);
  }
  return normalize(v);
}
vec3 czm_octDecode(vec2 encoded) {
  return czm_octDecode(encoded, 255.0f);
}
vec3 czm_octDecode(float encoded) {
  float temp = encoded / 256.0f;
  float x = floor(temp);
  float y = (temp - x) * 256.0f;
  return czm_octDecode(vec2(x, y));
}
void czm_octDecode(vec2 encoded, out vec3 vector1, out vec3 vector2, out vec3 vector3) {
  float temp = encoded.x / 65536.0f;
  float x = floor(temp);
  float encodedFloat1 = (temp - x) * 65536.0f;
  temp = encoded.y / 65536.0f;
  float y = floor(temp);
  float encodedFloat2 = (temp - y) * 65536.0f;
  vector1 = czm_octDecode(encodedFloat1);
  vector2 = czm_octDecode(encodedFloat2);
  vector3 = czm_octDecode(vec2(x, y));
}
vec2 czm_decompressTextureCoordinates(float encoded) {
  float temp = encoded / 4096.0f;
  float xZeroTo4095 = floor(temp);
  float stx = xZeroTo4095 / 4095.0f;
  float sty = (encoded - xZeroTo4095 * 4096.0f) / 4095.0f;
  return vec2(stx, sty);
}
uniform mat4 czm_modelViewProjectionRelativeToEye;
uniform mat3 czm_normal;
uniform mat4 czm_modelViewRelativeToEye;
vec4 czm_computePosition();
#line 0
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
  return vec2(centerX + (batchId * numberOfAttributes * stepX), 0.5f);
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
  value *= 255.0f;
  return value;
}
vec4 czm_batchTable_depthFailColor(float batchId) {
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
  v_positionEC = (czm_modelViewRelativeToEye * p).xyz;
  v_normalEC = czm_normal * normal;
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
  if(czm_morphTime == 1.0f) {
    p = czm_translateRelativeToEye(position3DHigh, position3DLow);
  } else if(czm_morphTime == 0.0f) {
    p = czm_translateRelativeToEye(position2DHigh.zxy, position2DLow.zxy);
  } else {
    p = czm_columbusViewMorph(czm_translateRelativeToEye(position2DHigh.zxy, position2DLow.zxy), czm_translateRelativeToEye(position3DHigh, position3DLow), czm_morphTime);
  }
  return p;
}