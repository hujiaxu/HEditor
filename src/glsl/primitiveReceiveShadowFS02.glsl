#version 300 es
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
precision highp int;
#else
precision mediump float;
precision mediump int;
#define highp mediump
#endif
#define LOG_DEPTH
#define USE_SHADOW_DEPTH_TEXTURE
#define USE_NORMAL_SHADING
#define USE_NORMAL_SHADING_SMOOTH
#define OES_texture_float_linear
#define OES_texture_float
#line 0
layout(location = 0) out vec4 out_FragColor;
vec4 czm_textureCube(samplerCube sampler, vec3 p) {
  #if __VERSION__ == 300
  return texture(sampler, p);
  #else
  return textureCube(sampler, p);
  #endif
}
float czm_unpackDepth(vec4 packedDepth)
{
  return dot(packedDepth, vec4(1.0, 1.0 / 255.0, 1.0 / 65025.0, 1.0 / 16581375.0));
}
float czm_sampleShadowMap(highp samplerCube shadowMap, vec3 d)
{
  return czm_unpackDepth(czm_textureCube(shadowMap, d));
}
float czm_sampleShadowMap(highp sampler2D shadowMap, vec2 uv)
{
  #ifdef USE_SHADOW_DEPTH_TEXTURE
  return texture(shadowMap, uv).r;
  #else
  return czm_unpackDepth(texture(shadowMap, uv));
  #endif
}
float czm_shadowDepthCompare(samplerCube shadowMap, vec3 uv, float depth)
{
  return step(depth, czm_sampleShadowMap(shadowMap, uv));
}
float czm_shadowDepthCompare(sampler2D shadowMap, vec2 uv, float depth)
{
  return step(depth, czm_sampleShadowMap(shadowMap, uv));
}
struct czm_shadowParameters
{
  #ifdef USE_CUBE_MAP_SHADOW
  vec3 texCoords;
  #else
  vec2 texCoords;
  #endif
  float depthBias;
  float depth;
  float nDotL;
  vec2 texelStepSize;
  float normalShadingSmooth;
  float darkness;
};
const float czm_epsilon7 = 0.0000001;
uniform float czm_oneOverLog2FarDepthFromNearPlusOne;
uniform float czm_farDepthFromNearPlusOne;
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
float czm_private_shadowVisibility(float visibility, float nDotL, float normalShadingSmooth, float darkness)
{
  #ifdef USE_NORMAL_SHADING#ifdef USE_NORMAL_SHADING_SMOOTH
  float strength = clamp(nDotL / normalShadingSmooth, 0.0, 1.0);
  #else
  float strength = step(0.0, nDotL);
  #endif
  visibility *= strength;
  #endif
  visibility = max(visibility, darkness);
  return visibility;
}
#ifdef USE_CUBE_MAP_SHADOW
float czm_shadowVisibility(samplerCube shadowMap, czm_shadowParameters shadowParameters)
{
  float depthBias = shadowParameters.depthBias;
  float depth = shadowParameters.depth;
  float nDotL = shadowParameters.nDotL;
  float normalShadingSmooth = shadowParameters.normalShadingSmooth;
  float darkness = shadowParameters.darkness;
  vec3 uvw = shadowParameters.texCoords;
  depth -= depthBias;
  float visibility = czm_shadowDepthCompare(shadowMap, uvw, depth);
  return czm_private_shadowVisibility(visibility, nDotL, normalShadingSmooth, darkness);
}
#else
float czm_shadowVisibility(sampler2D shadowMap, czm_shadowParameters shadowParameters)
{
  float depthBias = shadowParameters.depthBias;
  float depth = shadowParameters.depth;
  float nDotL = shadowParameters.nDotL;
  float normalShadingSmooth = shadowParameters.normalShadingSmooth;
  float darkness = shadowParameters.darkness;
  vec2 uv = shadowParameters.texCoords;
  depth -= depthBias;
  #ifdef USE_SOFT_SHADOWS
  vec2 texelStepSize = shadowParameters.texelStepSize;
  float radius = 1.0;
  float dx0 = -texelStepSize.x * radius;
  float dy0 = -texelStepSize.y * radius;
  float dx1 = texelStepSize.x * radius;
  float dy1 = texelStepSize.y * radius;
  float visibility = (
    czm_shadowDepthCompare(shadowMap, uv, depth) +
    czm_shadowDepthCompare(shadowMap, uv + vec2(dx0, dy0), depth) +
    czm_shadowDepthCompare(shadowMap, uv + vec2(0.0, dy0), depth) +
    czm_shadowDepthCompare(shadowMap, uv + vec2(dx1, dy0), depth) +
    czm_shadowDepthCompare(shadowMap, uv + vec2(dx0, 0.0), depth) +
    czm_shadowDepthCompare(shadowMap, uv + vec2(dx1, 0.0), depth) +
    czm_shadowDepthCompare(shadowMap, uv + vec2(dx0, dy1), depth) +
    czm_shadowDepthCompare(shadowMap, uv + vec2(0.0, dy1), depth) +
    czm_shadowDepthCompare(shadowMap, uv + vec2(dx1, dy1), depth)
  ) * (1.0 / 9.0);
  #else
  float visibility = czm_shadowDepthCompare(shadowMap, uv, depth);
  #endif
  return czm_private_shadowVisibility(visibility, nDotL, normalShadingSmooth, darkness);
}
#endif
uniform mat4 shadowMap_cascadeMatrices[4];
mat4 czm_cascadeMatrix(vec4 weights)
{
  return shadowMap_cascadeMatrices[0] * weights.x +
  shadowMap_cascadeMatrices[1] * weights.y +
  shadowMap_cascadeMatrices[2] * weights.z +
  shadowMap_cascadeMatrices[3] * weights.w;
}
uniform vec4 shadowMap_cascadeSplits[2];
vec4 czm_cascadeWeights(float depthEye)
{
  vec4 near = step(shadowMap_cascadeSplits[0], vec4(depthEye));
  vec4 far = step(depthEye, shadowMap_cascadeSplits[1]);
  return near * far;
}
#ifdef LOG_DEPTH
in float v_depthFromNearPlusOne;
#ifdef POLYGON_OFFSET
uniform vec2 u_polygonOffset;
#endif
#endif
void czm_writeLogDepth(float depth)
{
  #if (defined(LOG_DEPTH) && (__VERSION__ == 300 || defined(GL_EXT_frag_depth)))
  if (depth <= 0.9999999 || depth > czm_farDepthFromNearPlusOne) {
    discard;
  }
  #ifdef POLYGON_OFFSET
  float factor = u_polygonOffset[0];
  float units = u_polygonOffset[1];
  #if (__VERSION__ == 300 || defined(GL_OES_standard_derivatives))
  if (factor != 0.0) {
    float x = dFdx(depth);
    float y = dFdy(depth);
    float m = sqrt(x * x + y * y);
    
    depth += m * factor;
  }
  #endif
  #endif
  gl_FragDepth = log2(depth) * czm_oneOverLog2FarDepthFromNearPlusOne;
  #ifdef POLYGON_OFFSET
  gl_FragDepth += czm_epsilon7 * units;
  #endif
  #endif
}
void czm_writeLogDepth() {
  #ifdef LOG_DEPTH
  czm_writeLogDepth(v_depthFromNearPlusOne);
  #endif
}
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
void czm_log_depth_main() {
  vec3 positionToEyeEC = -v_positionEC;
  vec3 normalEC = normalize(v_normalEC);
  #ifdef FACE_FORWARD
  normalEC = faceforward(normalEC, vec3(0.0, 0.0, 1.0), -normalEC);
  #endif
  vec4 textureColor = texture(image_0, vec2(v_st)).rgba;
  out_FragColor = vec4(textureColor.rgb, 1.);
}
#line 0
void czm_shadow_receive_main() 
{
  czm_log_depth_main(); 
  czm_writeLogDepth();
} 
#line 0
uniform sampler2D shadowMap_texture;
uniform mat4 shadowMap_matrix;
uniform vec3 shadowMap_lightDirectionEC;
uniform vec4 shadowMap_lightPositionEC;
uniform vec4 shadowMap_normalOffsetScaleDistanceMaxDistanceAndDarkness;
uniform vec4 shadowMap_texelSizeDepthBiasAndNormalShadingSmooth;
#ifdef LOG_DEPTH
in vec3 v_logPositionEC;
#endif
vec4 getPositionEC()
{
  return vec4(v_positionEC, 1.0);
}
vec3 getNormalEC() 
{
  return normalize(v_normalEC);
} 
void applyNormalOffset(inout vec4 positionEC, vec3 normalEC, float nDotL)
{
  float normalOffset = shadowMap_normalOffsetScaleDistanceMaxDistanceAndDarkness.x; 
  float normalOffsetScale = 1.0 - nDotL; 
  vec3 offset = normalOffset * normalOffsetScale * normalEC; 
  positionEC.xyz += offset;
}
void main()
{
  czm_shadow_receive_main(); 
  vec4 positionEC = getPositionEC(); 
  vec3 normalEC = getNormalEC(); 
  float depth = -positionEC.z; 
  czm_shadowParameters shadowParameters; 
  shadowParameters.texelStepSize = shadowMap_texelSizeDepthBiasAndNormalShadingSmooth.xy; 
  shadowParameters.depthBias = shadowMap_texelSizeDepthBiasAndNormalShadingSmooth.z; 
  shadowParameters.normalShadingSmooth = shadowMap_texelSizeDepthBiasAndNormalShadingSmooth.w; 
  shadowParameters.darkness = shadowMap_normalOffsetScaleDistanceMaxDistanceAndDarkness.w; 
  float maxDepth = shadowMap_cascadeSplits[1].w;     
  if (depth > maxDepth) {
    return;
  }
  vec4 weights = czm_cascadeWeights(depth);     
  float nDotL = clamp(dot(normalEC, shadowMap_lightDirectionEC), 0.0, 1.0); 
  applyNormalOffset(positionEC, normalEC, nDotL);     
  vec4 shadowPosition = czm_cascadeMatrix(weights) * positionEC;     
  shadowParameters.texCoords = shadowPosition.xy; 
  shadowParameters.depth = shadowPosition.z; 
  shadowParameters.nDotL = nDotL; 
  float visibility = czm_shadowVisibility(shadowMap_texture, shadowParameters);     
  float shadowMapMaximumDistance = shadowMap_normalOffsetScaleDistanceMaxDistanceAndDarkness.z; 
  float fade = max((depth - shadowMapMaximumDistance * 0.8) / (shadowMapMaximumDistance * 0.2), 0.0); 
  visibility = mix(visibility, 1.0, fade); 
  out_FragColor.rgb *= visibility;
} 