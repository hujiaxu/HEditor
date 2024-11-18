#version 300 es
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
precision highp int;
#else
precision mediump float;
precision mediump int;
#define highp mediump
#endif
#define SHADOW_MAP
#define OES_texture_float_linear
#define OES_texture_float
#line 0
layout(location = 0) out vec4 out_FragColor;
struct czm_materialInput
{
  float s;
  vec2 st;
  vec3 str;
  vec3 normalEC;
  mat3 tangentToEyeMatrix;
  vec3 positionToEyeEC;
  float height;
  float slope;
  float aspect;
};
struct czm_material
{
  vec3 diffuse;
  float specular;
  float shininess;
  vec3 normal;
  vec3 emission;
  float alpha;
};
czm_material czm_getDefaultMaterial(czm_materialInput materialInput)
{
  czm_material material;
  material.diffuse = vec3(0.0);
  material.specular = 0.0;
  material.shininess = 1.0;
  material.normal = materialInput.normalEC;
  material.emission = vec3(0.0);
  material.alpha = 1.0;
  return material;
}
#line 0
in vec4 v_pickColor;
#define FLAT
#define FACE_FORWARD
uniform vec2 repeat_1;
uniform sampler2D image_0;
czm_material czm_getMaterial(czm_materialInput materialInput)
{
  czm_material material = czm_getDefaultMaterial(materialInput);
  return material;
}
in vec3 v_positionEC;
in vec3 v_normalEC;
in vec2 v_st;
void czm_shadow_cast_main() {
  vec3 positionToEyeEC = -v_positionEC;
  vec3 normalEC = normalize(v_normalEC);
  #ifdef FACE_FORWARD
  normalEC = faceforward(normalEC, vec3(0.0, 0.0, 1.0), -normalEC);
  #endif
  vec4 textureColor = texture(image_0, vec2(v_st)).rgba;
  out_FragColor = vec4(textureColor.rgb, 1.);
}
#line 0
void main() 
{
  out_FragColor = vec4(1.0);
}
