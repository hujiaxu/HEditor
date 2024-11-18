#version 300 es
#ifdef GL_FRAGMENT_PRECISION_HIGH    
precision highp float;
precision highp int;
#else    
precision mediump float;
precision mediump int;    
#define highp mediump
#endif
#define HAS_MODEL_COLOR
#define USE_IBL_LIGHTING
#define USE_SUN_LUMINANCE
#define HAS_ATMOSPHERE
#define COMPUTE_POSITION_WC_ATMOSPHERE
#define HAS_TEXCOORD_0
#define USE_METALLIC_ROUGHNESS
#define HAS_BASE_COLOR_TEXTURE
#define TEXCOORD_BASE_COLOR v_texCoord_0
#define HAS_METALLIC_FACTOR
#define HAS_ROUGHNESS_FACTOR
#define LIGHTING_UNLIT
#define USE_SHADOW_DEPTH_TEXTURE
#define OES_texture_float_linear
#define OES_texture_float
#line 0
layout(location = 0) out vec4 out_FragColor;
const float czm_infinity = 5906376272000.0;
struct czm_ray {
  vec3 origin;
  vec3 direction;
};
struct czm_raySegment {
  float start;
  float stop;
};
const czm_raySegment czm_emptyRaySegment = czm_raySegment(-czm_infinity, -czm_infinity);
const czm_raySegment czm_fullRaySegment = czm_raySegment(0.0, czm_infinity);
vec4 czm_textureCube(samplerCube sampler, vec3 p) {
  #if __VERSION__ == 300    
  return texture(sampler, p);
  #else      
  return textureCube(sampler, p);
  #endif
}
float czm_unpackDepth(vec4 packedDepth) {
  return dot(packedDepth, vec4(1.0, 1.0 / 255.0, 1.0 / 65025.0, 1.0 / 16581375.0));
}
const float czm_epsilon7 = 0.0000001;
uniform vec3 czm_atmosphereRayleighCoefficient;
uniform vec3 czm_atmosphereMieCoefficient;
uniform float czm_atmosphereMieScaleHeight;
uniform float czm_atmosphereRayleighScaleHeight;
float czm_approximateTanh(float x) {

  float x2 = x * x;
  return max(-1.0, min(1.0, x * (27.0 + x2) / (27.0 + 9.0 * x2)));
}
czm_raySegment czm_raySphereIntersectionInterval(czm_ray ray, vec3 center, float radius) {
  vec3 o = ray.origin;
  vec3 d = ray.direction;
  vec3 oc = o - center;
  float a = dot(d, d);
  float b = 2.0 * dot(d, oc);
  float c = dot(oc, oc) - (radius * radius);
  float det = (b * b) - (4.0 * a * c);
  if(det < 0.0) {
    return czm_emptyRaySegment;
  }
  float sqrtDet = sqrt(det);
  float t0 = (-b - sqrtDet) / (2.0 * a);
  float t1 = (-b + sqrtDet) / (2.0 * a);
  czm_raySegment result = czm_raySegment(t0, t1);
  return result;
}

float czm_sampleShadowMap(highp samplerCube shadowMap, vec3 d) {

  return czm_unpackDepth(czm_textureCube(shadowMap, d));
}
float czm_sampleShadowMap(highp sampler2D shadowMap, vec2 uv) {
  #ifdef USE_SHADOW_DEPTH_TEXTURE    
  return texture(shadowMap, uv).r;
  #else    
  return czm_unpackDepth(texture(shadowMap, uv));
  #endif
}
float czm_shadowDepthCompare(samplerCube shadowMap, vec3 uv, float depth) {
  return step(depth, czm_sampleShadowMap(shadowMap, uv));
}
float czm_shadowDepthCompare(sampler2D shadowMap, vec2 uv, float depth) {
  return step(depth, czm_sampleShadowMap(shadowMap, uv));
}
struct czm_shadowParameters {
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
uniform float czm_gamma;
float czm_maximumComponent(vec2 v) {
  return max(v.x, v.y);
}
float czm_maximumComponent(vec3 v) {
  return max(max(v.x, v.y), v.z);
}
float czm_maximumComponent(vec4 v) {
  return max(max(max(v.x, v.y), v.z), v.w);
}
struct czm_modelMaterial {
  vec4 baseColor;
  vec3 diffuse;
  float alpha;
  vec3 specular;
  float roughness;
  vec3 normalEC;
  float occlusion;
  vec3 emissive;
  #ifdef USE_SPECULAR    
  float specularWeight;
  #endif
  #ifdef USE_ANISOTROPY    
  vec3 anisotropicT;
  vec3 anisotropicB;
  float anisotropyStrength;
  #endif
  #ifdef USE_CLEARCOAT    
  float clearcoatFactor;
  float clearcoatRoughness;
  vec3 clearcoatNormal;    
  #endif
};
const float czm_pi = 3.141592653589793;
uniform float czm_atmosphereLightIntensity;
uniform float czm_atmosphereMieAnisotropy;
uniform vec3 czm_viewerPositionWC;
const vec4 K_HSB2RGB = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
vec3 czm_HSBToRGB(vec3 hsb) {
vec3 p = abs(fract(hsb.xxx + K_HSB2RGB.xyz) * 6.0 - K_HSB2RGB.www);
  return hsb.z * mix(K_HSB2RGB.xxx, clamp(p - K_HSB2RGB.xxx, 0.0, 1.0), hsb.y);
}
const vec4 K_RGB2HSB = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
vec3 czm_RGBToHSB(vec3 rgb) {
vec4 p = mix(vec4(rgb.bg, K_RGB2HSB.wz), vec4(rgb.gb, K_RGB2HSB.xy), step(rgb.b, rgb.g));
vec4 q = mix(vec4(p.xyw, rgb.r), vec4(rgb.r, p.yzx), step(p.x, rgb.r));
float d = q.x - min(q.w, q.y);
  return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + czm_epsilon7)), d / (q.x + czm_epsilon7), q.x);
}
void czm_computeScattering(
  czm_ray primaryRay, 
  float primaryRayLength, 
  vec3 lightDirection, 
  float atmosphereInnerRadius, 
  out vec3 rayleighColor, 
  out vec3 mieColor, 
  out float opacity
) {
  const float ATMOSPHERE_THICKNESS = 111e3;
  const int PRIMARY_STEPS_MAX = 16;
  const int LIGHT_STEPS_MAX = 4;
  rayleighColor = vec3(0.0);
  mieColor = vec3(0.0);
  opacity = 0.0;
  float atmosphereOuterRadius = atmosphereInnerRadius + ATMOSPHERE_THICKNESS;
  vec3 origin = vec3(0.0);
  czm_raySegment primaryRayAtmosphereIntersect = czm_raySphereIntersectionInterval(primaryRay, origin, atmosphereOuterRadius);
  if(primaryRayAtmosphereIntersect == czm_emptyRaySegment) {
    rayleighColor = vec3(1.0, 0.0, 1.0);
    return;
  }
  float x = 1e-7f * primaryRayAtmosphereIntersect.stop / length(primaryRayLength);
  float w_stop_gt_lprl = 0.5f * (1.0 + czm_approximateTanh(x));
  float start_0 = primaryRayAtmosphereIntersect.start;
  primaryRayAtmosphereIntersect.start = max(primaryRayAtmosphereIntersect.start, 0.0);
  primaryRayAtmosphereIntersect.stop = min(primaryRayAtmosphereIntersect.stop, length(primaryRayLength));
  float x_o_a = start_0 - ATMOSPHERE_THICKNESS;
  float w_inside_atmosphere = 1.0 - 0.5f * (1.0 + czm_approximateTanh(x_o_a));
  int PRIMARY_STEPS = PRIMARY_STEPS_MAX - int(w_inside_atmosphere * 12.0);
  int LIGHT_STEPS = LIGHT_STEPS_MAX - int(w_inside_atmosphere * 2.0);
  float rayPositionLength = primaryRayAtmosphereIntersect.start;
  float totalRayLength = primaryRayAtmosphereIntersect.stop - rayPositionLength;
  float rayStepLengthIncrease = w_inside_atmosphere * ((1.0 - w_stop_gt_lprl) * totalRayLength / (float(PRIMARY_STEPS * (PRIMARY_STEPS + 1)) / 2.0));
  float rayStepLength = max(1.0 - w_inside_atmosphere, w_stop_gt_lprl) * totalRayLength / max(7.0 * w_inside_atmosphere, float(PRIMARY_STEPS));
  vec3 rayleighAccumulation = vec3(0.0);
  vec3 mieAccumulation = vec3(0.0);
  vec2 opticalDepth = vec2(0.0);
  vec2 heightScale = vec2(czm_atmosphereRayleighScaleHeight, czm_atmosphereMieScaleHeight);
  for(int i = 0; i < PRIMARY_STEPS_MAX; ++i) {
    if(i >= PRIMARY_STEPS) {
      break;
    }
    vec3 samplePosition = primaryRay.origin + primaryRay.direction * (rayPositionLength + rayStepLength);
    float sampleHeight = length(samplePosition) - atmosphereInnerRadius;
    vec2 sampleDensity = exp(-sampleHeight / heightScale) * rayStepLength;
    opticalDepth += sampleDensity;
    czm_ray lightRay = czm_ray(samplePosition, lightDirection);
    czm_raySegment lightRayAtmosphereIntersect = czm_raySphereIntersectionInterval(lightRay, origin, atmosphereOuterRadius);
    float lightStepLength = lightRayAtmosphereIntersect.stop / float(LIGHT_STEPS);
    float lightPositionLength = 0.0;
    vec2 lightOpticalDepth = vec2(0.0);
    for(int j = 0; j < LIGHT_STEPS_MAX; ++j) {
      if(j >= LIGHT_STEPS) {
        break;
      }
      vec3 lightPosition = samplePosition + lightDirection * (lightPositionLength + lightStepLength * 0.5f);
      float lightHeight = length(lightPosition) - atmosphereInnerRadius;
      lightOpticalDepth += exp(-lightHeight / heightScale) * lightStepLength;
      lightPositionLength += lightStepLength;
    }
    vec3 attenuation = exp(-((czm_atmosphereMieCoefficient * (opticalDepth.y + lightOpticalDepth.y)) + (czm_atmosphereRayleighCoefficient * (opticalDepth.x + lightOpticalDepth.x))));
    rayleighAccumulation += sampleDensity.x * attenuation;
    mieAccumulation += sampleDensity.y * attenuation;
    rayPositionLength += (rayStepLength += rayStepLengthIncrease);
  }
  rayleighColor = czm_atmosphereRayleighCoefficient * rayleighAccumulation;
  mieColor = czm_atmosphereMieCoefficient * mieAccumulation;
  opacity = length(exp(-((czm_atmosphereMieCoefficient * opticalDepth.y) + (czm_atmosphereRayleighCoefficient * opticalDepth.x))));
}
uniform vec3 czm_sunDirectionWC;
uniform vec3 czm_lightDirectionWC;
uniform float czm_fogDensity;
float czm_private_shadowVisibility(float visibility, float nDotL, float normalShadingSmooth, float darkness) {
  #ifdef USE_NORMAL_SHADING
  #ifdef USE_NORMAL_SHADING_SMOOTH    
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
float czm_shadowVisibility(samplerCube shadowMap, czm_shadowParameters shadowParameters) {
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
float czm_shadowVisibility(sampler2D shadowMap, czm_shadowParameters shadowParameters) {
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
  float visibility = 
    (czm_shadowDepthCompare(shadowMap, uv, depth) + 
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
mat4 czm_cascadeMatrix(vec4 weights) {
return shadowMap_cascadeMatrices[0] * weights.x +
  shadowMap_cascadeMatrices[1] * weights.y +
  shadowMap_cascadeMatrices[2] * weights.z +
  shadowMap_cascadeMatrices[3] * weights.w;
}
uniform vec4 shadowMap_cascadeSplits[2];

vec4 czm_cascadeWeights(float depthEye) {
vec4 near = step(shadowMap_cascadeSplits[0], vec4(depthEye));
vec4 far = step(depthEye, shadowMap_cascadeSplits[1]);
return near * far;
}
vec3 czm_linearToSrgb(vec3 linearIn) {
  return pow(linearIn, vec3(1.0 / 2.2f));
}
vec4 czm_linearToSrgb(vec4 linearIn) {
  vec3 srgbOut = pow(linearIn.rgb, vec3(1.0 / 2.2f));
  return vec4(srgbOut, linearIn.a);
}

vec3 czm_gammaCorrect(vec3 color) {
  #ifdef HDR    
  color = pow(color, vec3(czm_gamma));
  #endif    
  return color;
}
vec4 czm_gammaCorrect(vec4 color) {
  #ifdef HDR    
  color.rgb = pow(color.rgb, vec3(czm_gamma));
  #endif    
  return color;
}

vec3 lambertianDiffuse(vec3 diffuseColor){    
  return diffuseColor / czm_pi; 
}

vec3 fresnelSchlick2(vec3 f0, vec3 f90, float VdotH) {    
  float versine = 1.0 - VdotH;        
  float versineSquared = versine * versine;    
  return f0 + (f90 - f0) * versineSquared * versineSquared * versine;
}

#ifdef USE_ANISOTROPY
float smithVisibilityGGX_anisotropic(float roughness, float tangentialRoughness, vec3 lightDirection, vec3 viewDirection){    
  vec3 roughnessScale = vec3(tangentialRoughness, roughness, 1.0);    
  float GGXV = lightDirection.z * length(roughnessScale * viewDirection);    
  float GGXL = viewDirection.z * length(roughnessScale * lightDirection);    
  float v = 0.5 / (GGXV + GGXL);    
  return clamp(v, 0.0, 1.0);
}

float GGX_anisotropic(float roughness, float tangentialRoughness, vec3 halfwayDirection){    
  float roughnessSquared = roughness * tangentialRoughness;    
  vec3 f = halfwayDirection * vec3(roughness, tangentialRoughness, roughnessSquared);    
  float w2 = roughnessSquared / dot(f, f);    
  return roughnessSquared * w2 * w2 / czm_pi;
}
#endif

float smithVisibilityGGX(float alphaRoughness, float NdotL, float NdotV){    
  float alphaRoughnessSq = alphaRoughness * alphaRoughness;    
  float GGXV = NdotL * sqrt(NdotV * NdotV * (1.0 - alphaRoughnessSq) + alphaRoughnessSq);    
  float GGXL = NdotV * sqrt(NdotL * NdotL * (1.0 - alphaRoughnessSq) + alphaRoughnessSq);    
  float GGX = GGXV + GGXL;    
  if (GGX > 0.0)    {        return 0.5 / GGX;    }    
  return 0.0;
}

float GGX(float roughness, float NdotH){    
  float roughnessSquared = roughness * roughness;    
  float f = (NdotH * roughnessSquared - NdotH) * NdotH + 1.0;    
  return roughnessSquared / (czm_pi * f * f);
}
float computeDirectSpecularStrength(vec3 normal, vec3 lightDirection, vec3 viewDirection, vec3 halfwayDirection, float roughness){    
  float NdotL = dot(normal, lightDirection);    
  float NdotV = abs(dot(normal, viewDirection));    
  float G = smithVisibilityGGX(roughness, NdotL, NdotV);    
  float NdotH = clamp(dot(normal, halfwayDirection), 0.0, 1.0);    
  float D = GGX(roughness, NdotH);    
  return G * D;
}

vec3 czm_pbrLighting(vec3 viewDirectionEC, vec3 normalEC, vec3 lightDirectionEC, czm_modelMaterial material){    
  vec3 halfwayDirectionEC = normalize(viewDirectionEC + lightDirectionEC);    
  float VdotH = clamp(dot(viewDirectionEC, halfwayDirectionEC), 0.0, 1.0);    
  float NdotL = clamp(dot(normalEC, lightDirectionEC), 0.001, 1.0);    
  vec3 f0 = material.specular;    
  float reflectance = czm_maximumComponent(f0);            
  vec3 f90 = vec3(clamp(reflectance * 25.0, 0.0, 1.0));    
  vec3 F = fresnelSchlick2(f0, f90, VdotH);    
  #if defined(USE_SPECULAR)        
  F *= material.specularWeight;    
  #endif    
  float alpha = material.roughness;    
  #ifdef USE_ANISOTROPY        
  mat3 tbn = mat3(material.anisotropicT, material.anisotropicB, normalEC);        
  vec3 lightDirection = lightDirectionEC * tbn;        
  vec3 viewDirection = viewDirectionEC * tbn;        
  vec3 halfwayDirection = halfwayDirectionEC * tbn;        
  float anisotropyStrength = material.anisotropyStrength;        
  float tangentialRoughness = mix(alpha, 1.0, anisotropyStrength * anisotropyStrength);        
  float G = smithVisibilityGGX_anisotropic(alpha, tangentialRoughness, lightDirection, viewDirection);        
  float D = GGX_anisotropic(alpha, tangentialRoughness, halfwayDirection);        
  vec3 specularContribution = F * G * D;    
  #else        
  float specularStrength = computeDirectSpecularStrength(normalEC, lightDirectionEC, viewDirectionEC, halfwayDirectionEC, alpha);        
  vec3 specularContribution = F * specularStrength;    
  #endif    
  vec3 diffuseColor = material.diffuse;        
  vec3 diffuseContribution = (1.0 - F) * lambertianDiffuse(diffuseColor);        
  return (diffuseContribution + specularContribution) * NdotL;
}

uniform vec3 czm_lightDirectionEC;
uniform vec3 czm_lightColorHdr;
bool czm_backFacing(){        
  return gl_FrontFacing == false;
}
const float czm_epsilon3 = 0.001;

vec4 czm_computeAtmosphereColor(    
  vec3 positionWC,    
  vec3 lightDirection,    
  vec3 rayleighColor,    
  vec3 mieColor,    
  float opacity
) {        
  vec3 cameraToPositionWC = positionWC - czm_viewerPositionWC;    
  vec3 cameraToPositionWCDirection = normalize(cameraToPositionWC);    
  float cosAngle = dot(cameraToPositionWCDirection, lightDirection);    
  float cosAngleSq = cosAngle * cosAngle;    
  float G = czm_atmosphereMieAnisotropy;    
  float GSq = G * G;        
  float rayleighPhase = 3.0 / (50.2654824574) * (1.0 + cosAngleSq);        
  float miePhase = 3.0 / (25.1327412287) * ((1.0 - GSq) * (cosAngleSq + 1.0)) / (pow(1.0 + GSq - 2.0 * cosAngle * G, 1.5) * (2.0 + GSq));        
  vec3 rayleigh = rayleighPhase * rayleighColor;    
  vec3 mie = miePhase * mieColor;    
  vec3 color = (rayleigh + mie) * czm_atmosphereLightIntensity;    
  return vec4(color, opacity);
}

uniform vec3 czm_atmosphereHsbShift;
vec3 czm_applyHSBShift(vec3 rgb, vec3 hsbShift, bool ignoreBlackPixels) {        
  vec3 hsb = czm_RGBToHSB(rgb);            
  hsb.x += hsbShift.x;     
  hsb.y = clamp(hsb.y + hsbShift.y, 0.0, 1.0);                     
  if (ignoreBlackPixels) {        
    hsb.z = hsb.z > czm_epsilon7 ? hsb.z + hsbShift.z : 0.0;    
  } else {        
    hsb.z = hsb.z + hsbShift.z;    
  }    
  hsb.z = clamp(hsb.z, 0.0, 1.0);        
  return czm_HSBToRGB(hsb);
}

void czm_computeGroundAtmosphereScattering(vec3 positionWC, vec3 lightDirection, out vec3 rayleighColor, out vec3 mieColor, out float opacity) {    
  vec3 cameraToPositionWC = positionWC - czm_viewerPositionWC;    
  vec3 cameraToPositionWCDirection = normalize(cameraToPositionWC);    
  czm_ray primaryRay = czm_ray(czm_viewerPositionWC, cameraToPositionWCDirection);    
  float atmosphereInnerRadius = length(positionWC);    
  czm_computeScattering(        
    primaryRay,        
    length(cameraToPositionWC),        
    lightDirection,        
    atmosphereInnerRadius,        
    rayleighColor,        
    mieColor,        
    opacity    
  );
}

vec3 czm_getDynamicAtmosphereLightDirection(vec3 positionWC, float lightEnum) {    
  const float NONE = 0.0;    
  const float SCENE_LIGHT = 1.0;    
  const float SUNLIGHT = 2.0;    
  vec3 lightDirection =        
    positionWC * float(lightEnum == NONE) +        
    czm_lightDirectionWC * float(lightEnum == SCENE_LIGHT) +        
    czm_sunDirectionWC * float(lightEnum == SUNLIGHT);    
  return normalize(lightDirection);
}

vec3 czm_fog(float distanceToCamera, vec3 color, vec3 fogColor){    
  float scalar = distanceToCamera * czm_fogDensity;    
  float fog = 1.0 - exp(-(scalar * scalar));    
  return mix(color, fogColor, fog);
}

vec3 czm_fog(float distanceToCamera, vec3 color, vec3 fogColor, float fogModifierConstant){    float scalar = distanceToCamera * czm_fogDensity;    float fog = 1.0 - exp(-((fogModifierConstant * scalar + fogModifierConstant) * (scalar * (1.0 + fogModifierConstant))));    return mix(color, fogColor, fog);}

vec3 czm_inverseGamma(vec3 color) {    return pow(color, vec3(1.0 / czm_gamma));}

vec3 czm_acesTonemapping(vec3 color) {    float g = 0.985;    float a = 0.065;    float b = 0.0001;    float c = 0.433;    float d = 0.238;    color = (color * (color + a) - b) / (color * (g * color + c) + d);    color = clamp(color, 0.0, 1.0);    return color;}

uniform float czm_fogMinimumBrightness;
uniform float czm_atmosphereDynamicLighting;
uniform mat4 czm_model;
uniform vec2 czm_specularEnvironmentMapSize;
uniform sampler2D czm_specularEnvironmentMaps;
uniform float czm_specularEnvironmentMapsMaximumLOD;
vec3 czm_sampleOctahedralProjectionWithFiltering(sampler2D projectedMap, vec2 textureSize, vec3 direction, float lod){    
  direction /= dot(vec3(1.0), abs(direction));    
  vec2 rev = abs(direction.zx) - vec2(1.0);    
  vec2 neg = vec2(direction.x < 0.0 ? rev.x : -rev.x,                    
  direction.z < 0.0 ? rev.y : -rev.y);    
  vec2 uv = direction.y < 0.0 ? neg : direction.xz;    
  vec2 coord = 0.5 * uv + vec2(0.5);    
  vec2 pixel = 1.0 / textureSize;    
  if (lod > 0.0)    {                
    float scale = 1.0 / pow(2.0, lod);        
    float offset = ((textureSize.y + 1.0) / textureSize.x);        
    coord.x *= offset;        coord *= scale;        
    coord.x += offset + pixel.x;        
    coord.y += (1.0 - (1.0 / pow(2.0, lod - 1.0))) + pixel.y * (lod - 1.0) * 2.0;    
  }    else    {        coord.x *= (textureSize.y / textureSize.x);    }        
  #ifndef OES_texture_float_linear        
  vec3 color1 = texture(projectedMap, coord + vec2(0.0, pixel.y)).rgb;        
  vec3 color2 = texture(projectedMap, coord + vec2(pixel.x, 0.0)).rgb;        
  vec3 color3 = texture(projectedMap, coord + pixel).rgb;       
  vec3 color4 = texture(projectedMap, coord).rgb;        
  vec2 texturePosition = coord * textureSize;        
  float fu = fract(texturePosition.x);        
  float fv = fract(texturePosition.y);        
  vec3 average1 = mix(color4, color2, fu);        
  vec3 average2 = mix(color1, color3, fu);        
  vec3 color = mix(average1, average2, fv);    
  #else        
  vec3 color = texture(projectedMap, coord).rgb;    
  #endif    
  return color;
}

vec3 czm_sampleOctahedralProjection(sampler2D projectedMap, vec2 textureSize, vec3 direction, float lod, float maxLod) {    float currentLod = floor(lod + 0.5);    float nextLod = min(currentLod + 1.0, maxLod);    vec3 colorCurrentLod = czm_sampleOctahedralProjectionWithFiltering(projectedMap, textureSize, direction, currentLod);    vec3 colorNextLod = czm_sampleOctahedralProjectionWithFiltering(projectedMap, textureSize, direction, nextLod);    return mix(colorNextLod, colorCurrentLod, nextLod - lod);}

uniform vec3 czm_sphericalHarmonicCoefficients[9];
vec3 czm_sphericalHarmonics(vec3 normal, vec3 coefficients[9]){    vec3 L00 = coefficients[0];    vec3 L1_1 = coefficients[1];    vec3 L10 = coefficients[2];    vec3 L11 = coefficients[3];    vec3 L2_2 = coefficients[4];    vec3 L2_1 = coefficients[5];    vec3 L20 = coefficients[6];    vec3 L21 = coefficients[7];    vec3 L22 = coefficients[8];    float x = normal.x;    float y = normal.y;    float z = normal.z;    return          L00        + L1_1 * y        + L10 * z        + L11 * x        + L2_2 * (y * x)        + L2_1 * (y * z)        + L20 * (3.0 * z * z - 1.0)        + L21 * (z * x)        + L22 * (x * x - y * y);}

vec3 czm_srgbToLinear(vec3 srgbIn){    return pow(srgbIn, vec3(2.2));}
vec4 czm_srgbToLinear(vec4 srgbIn) {    vec3 linearOut = pow(srgbIn.rgb, vec3(2.2));    return vec4(linearOut, srgbIn.a);}
uniform sampler2D czm_brdfLut;
uniform mat4 czm_inverseView;
uniform mat3 czm_inverseViewRotation;
uniform samplerCube czm_environmentMap;
uniform mat3 czm_temeToPseudoFixed;
uniform vec3 czm_ellipsoidRadii;
#line 0
uniform vec4 model_color;
uniform float model_colorBlend;
uniform vec2 model_iblFactor;
uniform mat3 model_iblReferenceFrameMatrix;
uniform float model_luminanceAtZenith;
uniform bool u_isInFog;
uniform sampler2D u_baseColorTexture;
uniform float u_metallicFactor;
uniform float u_roughnessFactor;
uniform vec4 czm_pickColor;
in vec3 v_atmosphereRayleighColor;
in vec3 v_atmosphereMieColor;
in float v_atmosphereOpacity;
in vec3 v_positionWC;
in vec3 v_positionEC;
in vec3 v_positionMC;
in vec2 v_texCoord_0;

struct ProcessedAttributes{    vec3 positionWC;    vec3 positionEC;    vec3 positionMC;    vec2 texCoord_0;};
struct SelectedFeature{    float _empty;};
struct FeatureIds{    float _empty;};
struct Metadata{    float _empty;};
struct MetadataClass{    float _empty;};
struct MetadataStatistics{    float _empty;};
void setDynamicVaryings(inout ProcessedAttributes attributes){    attributes.texCoord_0 = v_texCoord_0;}
void initializeFeatureIds(out FeatureIds featureIds, ProcessedAttributes attributes){}
void initializeFeatureIdAliases(inout FeatureIds featureIds){}
void initializeMetadata(out Metadata metadata, out MetadataClass metadataClass, out MetadataStatistics metadataStatistics, ProcessedAttributes attributes){}

void modelColorStage(inout czm_modelMaterial material){    
  material.diffuse = mix(material.diffuse, model_color.rgb, model_colorBlend);    
  float highlight = ceil(model_colorBlend);    
  material.diffuse *= mix(model_color.rgb, vec3(1.0), highlight);    
  material.alpha *= model_color.a;
}

vec3 getProceduralSkyMetrics(vec3 positionWC, vec3 reflectionWC){        
  float horizonDotNadir = 1.0 - min(1.0, czm_ellipsoidRadii.x / length(positionWC));    
  float reflectionDotNadir = dot(reflectionWC, normalize(positionWC));    
  float atmosphereHeight = 0.05;    
  float smoothstepHeight = smoothstep(0.0, atmosphereHeight, horizonDotNadir);    
  return vec3(horizonDotNadir, reflectionDotNadir, smoothstepHeight);
}

vec3 getProceduralDiffuseIrradiance(vec3 skyMetrics){    
  vec3 blueSkyDiffuseColor = vec3(0.7, 0.85, 0.9);     
  float diffuseIrradianceFromEarth = (1.0 - skyMetrics.x) * (skyMetrics.y * 0.25 + 0.75) * skyMetrics.z;      
  float diffuseIrradianceFromSky = (1.0 - skyMetrics.z) * (1.0 - (skyMetrics.y * 0.25 + 0.25));    
  return blueSkyDiffuseColor * clamp(diffuseIrradianceFromEarth + diffuseIrradianceFromSky, 0.0, 1.0);
}

vec3 getProceduralSpecularIrradiance(vec3 reflectionWC, vec3 skyMetrics, float roughness){        
  reflectionWC.x = -reflectionWC.x;    
  reflectionWC = -normalize(czm_temeToPseudoFixed * reflectionWC);    
  reflectionWC.x = -reflectionWC.x;    
  float inverseRoughness = 1.04 - roughness;    
  inverseRoughness *= inverseRoughness;    
  vec3 sceneSkyBox = czm_textureCube(czm_environmentMap, reflectionWC).rgb * inverseRoughness;        
  vec3 belowHorizonColor = mix(vec3(0.1, 0.15, 0.25), vec3(0.4, 0.7, 0.9), skyMetrics.z);    
  vec3 nadirColor = belowHorizonColor * 0.5;    
  vec3 aboveHorizonColor = mix(vec3(0.9, 1.0, 1.2), belowHorizonColor, roughness * 0.5);    
  vec3 blueSkyColor = mix(vec3(0.18, 0.26, 0.48), aboveHorizonColor, skyMetrics.y * inverseRoughness * 0.5 + 0.75);    
  vec3 zenithColor = mix(blueSkyColor, sceneSkyBox, skyMetrics.z);        
  float blendRegionSize = 0.1 * ((1.0 - inverseRoughness) * 8.0 + 1.1 - skyMetrics.x);    
  float blendRegionOffset = roughness * -1.0;    
  float farAboveHorizon = clamp(skyMetrics.x - blendRegionSize * 0.5 + blendRegionOffset, 1.0e-10 - blendRegionSize, 0.99999);    
  float aroundHorizon = clamp(skyMetrics.x + blendRegionSize * 0.5, 1.0e-10 - blendRegionSize, 0.99999);    
  float farBelowHorizon = clamp(skyMetrics.x + blendRegionSize * 1.5, 1.0e-10 - blendRegionSize, 0.99999);        
  float notDistantRough = (1.0 - skyMetrics.x * roughness * 0.8);    
  vec3 specularIrradiance = mix(zenithColor, aboveHorizonColor, smoothstep(farAboveHorizon, aroundHorizon, skyMetrics.y) * notDistantRough);    
  specularIrradiance = mix(specularIrradiance, belowHorizonColor, smoothstep(aroundHorizon, farBelowHorizon, skyMetrics.y) * inverseRoughness);    
  specularIrradiance = mix(specularIrradiance, nadirColor, smoothstep(farBelowHorizon, 1.0, skyMetrics.y) * inverseRoughness);    
  return specularIrradiance;
}

#ifdef USE_SUN_LUMINANCE
float clampedDot(vec3 x, vec3 y){    
  return clamp(dot(x, y), 0.001, 1.0);
}

float getSunLuminance(vec3 positionWC, vec3 normalEC, vec3 lightDirectionEC){    
  vec3 normalWC = normalize(czm_inverseViewRotation * normalEC);    
  vec3 lightDirectionWC = normalize(czm_inverseViewRotation * lightDirectionEC);    
  vec3 vWC = -normalize(positionWC);        
  float LdotZenith = clampedDot(lightDirectionWC, vWC);    
  float S = acos(LdotZenith);        
  float NdotZenith = clampedDot(normalWC, vWC);        
  float NdotL = clampedDot(normalEC, lightDirectionEC);    
  float gamma = acos(NdotL);    
  float numerator = ((0.91 + 10.0 * exp(-3.0 * gamma) + 0.45 * NdotL * NdotL) * (1.0 - exp(-0.32 / NdotZenith)));    
  float denominator = (0.91 + 10.0 * exp(-3.0 * S) + 0.45 * LdotZenith * LdotZenith) * (1.0 - exp(-0.32));    
  return model_luminanceAtZenith * (numerator / denominator);
}
#endif

vec3 proceduralIBL(    vec3 positionEC,    vec3 normalEC,    vec3 lightDirectionEC,    czm_modelMaterial material) {    
  vec3 viewDirectionEC = -normalize(positionEC);    
  vec3 positionWC = vec3(czm_inverseView * vec4(positionEC, 1.0));    
  vec3 reflectionWC = normalize(czm_inverseViewRotation * normalize(reflect(viewDirectionEC, normalEC)));    
  vec3 skyMetrics = getProceduralSkyMetrics(positionWC, reflectionWC);    
  float roughness = material.roughness;    
  vec3 f0 = material.specular;    
  vec3 specularIrradiance = getProceduralSpecularIrradiance(reflectionWC, skyMetrics, roughness);    
  float NdotV = abs(dot(normalEC, viewDirectionEC)) + 0.001;    
  vec2 brdfLut = texture(czm_brdfLut, vec2(NdotV, roughness)).rg;    
  vec3 specularColor = czm_srgbToLinear(f0 * brdfLut.x + brdfLut.y);    
  vec3 specularContribution = specularIrradiance * specularColor * model_iblFactor.y;    
  #ifdef USE_SPECULAR        
  specularContribution *= material.specularWeight;    
  #endif    
  vec3 diffuseIrradiance = getProceduralDiffuseIrradiance(skyMetrics);    
  vec3 diffuseColor = material.diffuse;    
  vec3 diffuseContribution = diffuseIrradiance * diffuseColor * model_iblFactor.x;    
  vec3 iblColor = specularContribution + diffuseContribution;    
  #ifdef USE_SUN_LUMINANCE        
  iblColor *= getSunLuminance(positionWC, normalEC, lightDirectionEC);    
  #endif    
  return iblColor;
}

#ifdef DIFFUSE_IBL
vec3 computeDiffuseIBL(vec3 cubeDir){    
  #ifdef CUSTOM_SPHERICAL_HARMONICS        
  return czm_sphericalHarmonics(cubeDir, model_sphericalHarmonicCoefficients);     
  #else        
  return czm_sphericalHarmonics(cubeDir, czm_sphericalHarmonicCoefficients);     
  #endif
}
#endif
#ifdef SPECULAR_IBL

vec3 sampleSpecularEnvironment(vec3 cubeDir, float roughness){    
  #ifdef CUSTOM_SPECULAR_IBL        
  float maxLod = model_specularEnvironmentMapsMaximumLOD;        
  float lod = roughness * maxLod;        
  return czm_sampleOctahedralProjection(model_specularEnvironmentMaps, model_specularEnvironmentMapsSize, cubeDir, lod, maxLod);    
  #else        
  float maxLod = czm_specularEnvironmentMapsMaximumLOD;        
  float lod = roughness * maxLod;        
  return czm_sampleOctahedralProjection(czm_specularEnvironmentMaps, czm_specularEnvironmentMapSize, cubeDir, lod, maxLod);    
  #endif
}

vec3 computeSpecularIBL(vec3 cubeDir, float NdotV, float VdotH, vec3 f0, float roughness){    
  float reflectance = czm_maximumComponent(f0);    
  vec3 f90 = vec3(clamp(reflectance * 25.0, 0.0, 1.0));    
  vec3 F = fresnelSchlick2(f0, f90, VdotH);    
  vec2 brdfLut = texture(czm_brdfLut, vec2(NdotV, roughness)).rg;    
  vec3 specularSample = sampleSpecularEnvironment(cubeDir, roughness);    
  return specularSample * (F * brdfLut.x + brdfLut.y);
}

#endif
#if defined(DIFFUSE_IBL) || defined(SPECULAR_IBL)

vec3 textureIBL(    vec3 viewDirectionEC,    vec3 normalEC,    vec3 lightDirectionEC,    czm_modelMaterial material) {        
  vec3 cubeDir = normalize(model_iblReferenceFrameMatrix * normalize(reflect(-viewDirectionEC, normalEC)));    
  #ifdef DIFFUSE_IBL        
  vec3 diffuseContribution = computeDiffuseIBL(cubeDir) * material.diffuse;    
  #else        
  vec3 diffuseContribution = vec3(0.0);     
  #endif    float roughness = material.roughness;    
  #ifdef USE_ANISOTROPY                
  vec3 anisotropyDirection = material.anisotropicB;        
  vec3 anisotropicTangent = cross(anisotropyDirection, viewDirectionEC);        
  vec3 anisotropicNormal = cross(anisotropicTangent, anisotropyDirection);        
  float bendFactor = 1.0 - material.anisotropyStrength * (1.0 - roughness);        
  float bendFactorPow4 = bendFactor * bendFactor * bendFactor * bendFactor;        
  vec3 bentNormal = normalize(mix(anisotropicNormal, normalEC, bendFactorPow4));        
  cubeDir = normalize(model_iblReferenceFrameMatrix * normalize(reflect(-viewDirectionEC, bentNormal)));    
  #endif    
  #ifdef SPECULAR_IBL        
  float NdotV = abs(dot(normalEC, viewDirectionEC)) + 0.001;        
  vec3 halfwayDirectionEC = normalize(viewDirectionEC + lightDirectionEC);        
  float VdotH = clamp(dot(viewDirectionEC, halfwayDirectionEC), 0.0, 1.0);        
  vec3 f0 = material.specular;        
  vec3 specularContribution = computeSpecularIBL(cubeDir, NdotV, VdotH, f0, roughness);    
  #else        
  vec3 specularContribution = vec3(0.0);     
  #endif    
  #ifdef USE_SPECULAR        
  specularContribution *= material.specularWeight;    
  #endif    
  return diffuseContribution + specularContribution;
}
  
#endif
vec2 nearestPointOnEllipseFast(vec2 pos, vec2 radii) {    
  vec2 p = abs(pos);    
  vec2 inverseRadii = 1.0 / radii;    
  vec2 evoluteScale = (radii.x * radii.x - radii.y * radii.y) * vec2(1.0, -1.0) * inverseRadii;                
  vec2 tTrigs = vec2(0.70710678118);    
  vec2 v = radii * tTrigs;        
  vec2 evolute = evoluteScale * tTrigs * tTrigs * tTrigs;        
  vec2 q = normalize(p - evolute) * length(v - evolute);        
  tTrigs = (q + evolute) * inverseRadii;    
  tTrigs = normalize(clamp(tTrigs, 0.0, 1.0));    
  v = radii * tTrigs;    
  return v * sign(pos);
}

vec3 computeEllipsoidPositionWC(vec3 positionMC) {            
  vec3 positionWC = (czm_model * vec4(positionMC, 1.0)).xyz;    
  vec2 positionEllipse = vec2(length(positionWC.xy), positionWC.z);    
  vec2 nearestPoint = nearestPointOnEllipseFast(positionEllipse, czm_ellipsoidRadii.xz);        
  return vec3(nearestPoint.x * normalize(positionWC.xy), nearestPoint.y);
}

void applyFog(inout vec4 color, vec4 groundAtmosphereColor, vec3 lightDirection, float distanceToCamera) {    
  vec3 fogColor = groundAtmosphereColor.rgb;        
  const float NONE = 0.0;    
  if (czm_atmosphereDynamicLighting != NONE) {        
    float darken = clamp(dot(normalize(czm_viewerPositionWC), lightDirection), czm_fogMinimumBrightness, 1.0);        
    fogColor *= darken;    
  }        

  #ifndef HDR        
  fogColor.rgb = czm_acesTonemapping(fogColor.rgb);        
  fogColor.rgb = czm_inverseGamma(fogColor.rgb);    
  #endif            
  const float fogModifier = 0.15;    
  vec3 withFog = czm_fog(distanceToCamera, color.rgb, fogColor, fogModifier);    
  color = vec4(withFog, color.a);
}
void atmosphereStage(inout vec4 color, in ProcessedAttributes attributes) {    
  vec3 rayleighColor;    vec3 mieColor;    float opacity;    vec3 positionWC;    vec3 lightDirection;                    
  if (false) {        
    positionWC = computeEllipsoidPositionWC(attributes.positionMC);        
    lightDirection = czm_getDynamicAtmosphereLightDirection(positionWC, czm_atmosphereDynamicLighting);                
    czm_computeGroundAtmosphereScattering(            
      positionWC,            
      lightDirection,            
      rayleighColor,            
      mieColor,            
      opacity        
    );    
  } else {        
    positionWC = attributes.positionWC;        
    lightDirection = czm_getDynamicAtmosphereLightDirection(positionWC, czm_atmosphereDynamicLighting);        
    rayleighColor = v_atmosphereRayleighColor;        
    mieColor = v_atmosphereMieColor;        
    opacity = v_atmosphereOpacity;    
  }        
  const bool ignoreBlackPixels = true;    
  rayleighColor = czm_applyHSBShift(rayleighColor, czm_atmosphereHsbShift, ignoreBlackPixels);    
  mieColor = czm_applyHSBShift(mieColor, czm_atmosphereHsbShift, ignoreBlackPixels);    
  vec4 groundAtmosphereColor = czm_computeAtmosphereColor(positionWC, lightDirection, rayleighColor, mieColor, opacity);    
  if (u_isInFog) {        
    float distanceToCamera = length(attributes.positionEC);       
    applyFog(color, groundAtmosphereColor, lightDirection, distanceToCamera);    
  } else {            }
}

void geometryStage(out ProcessedAttributes attributes){  
  attributes.positionMC = v_positionMC;  
  attributes.positionEC = v_positionEC;  
  #if defined(COMPUTE_POSITION_WC_CUSTOM_SHADER) || defined(COMPUTE_POSITION_WC_STYLE) || defined(COMPUTE_POSITION_WC_ATMOSPHERE)  
  attributes.positionWC = v_positionWC;  
  #endif  
  #ifdef HAS_NORMALS    
  attributes.normalEC = normalize(v_normalEC);  
  #endif  
  #ifdef HAS_TANGENTS  
  attributes.tangentEC = normalize(v_tangentEC);  
  #endif  
  #ifdef HAS_BITANGENTS  
  attributes.bitangentEC = normalize(v_bitangentEC);  
  #endif    
  setDynamicVaryings(attributes);
}


bool isDefaultStyleColor(vec3 color){    
  return all(greaterThan(color, vec3(1.0 - czm_epsilon3)));
}

vec3 blend(vec3 sourceColor, vec3 styleColor, float styleColorBlend){    
  vec3 blendColor = mix(sourceColor, styleColor, styleColorBlend);    
  vec3 color = isDefaultStyleColor(styleColor.rgb) ? sourceColor : blendColor;    
  return color;
}

vec2 computeTextureTransform(vec2 texCoord, mat3 textureTransform){    
  return vec2(textureTransform * vec3(texCoord, 1.0));
}

#ifdef HAS_NORMAL_TEXTURE
vec2 getNormalTexCoords(){    
  vec2 texCoord = TEXCOORD_NORMAL;    
  #ifdef HAS_NORMAL_TEXTURE_TRANSFORM        
  texCoord = vec2(u_normalTextureTransform * vec3(texCoord, 1.0));   
  #endif    
  return texCoord;
}
#endif

#if defined(HAS_NORMAL_TEXTURE) || defined(HAS_CLEARCOAT_NORMAL_TEXTURE)

vec3 computeTangent(in vec3 position, in vec2 normalTexCoords){    
  vec2 tex_dx = dFdx(normalTexCoords);    
  vec2 tex_dy = dFdy(normalTexCoords);    
  float determinant = tex_dx.x * tex_dy.y - tex_dy.x * tex_dx.y;    
  vec3 tangent = tex_dy.t * dFdx(position) - tex_dx.t * dFdy(position);    
  return tangent / determinant;
}
#endif
#ifdef USE_ANISOTROPY

struct NormalInfo {    vec3 tangent;    vec3 bitangent;    vec3 normal;    vec3 geometryNormal;};
NormalInfo getNormalInfo(ProcessedAttributes attributes){    
  vec3 geometryNormal = attributes.normalEC;    
  #ifdef HAS_NORMAL_TEXTURE        
  vec2 normalTexCoords = getNormalTexCoords();    
  #endif    
  #ifdef HAS_BITANGENTS        
  vec3 tangent = attributes.tangentEC;        
  vec3 bitangent = attributes.bitangentEC;    
  #else         
  vec3 tangent = computeTangent(attributes.positionEC, normalTexCoords);        
  tangent = normalize(tangent - geometryNormal * dot(geometryNormal, tangent));        
  vec3 bitangent = normalize(cross(geometryNormal, tangent));    
  #endif    
  #ifdef HAS_NORMAL_TEXTURE        
  mat3 tbn = mat3(tangent, bitangent, geometryNormal);        
  vec3 normalSample = texture(u_normalTexture, normalTexCoords).rgb;        
  normalSample = 2.0 * normalSample - 1.0;        
  #ifdef HAS_NORMAL_TEXTURE_SCALE            
  normalSample.xy *= u_normalTextureScale;        
  #endif        
  vec3 normal = normalize(tbn * normalSample);    
  #else        
  vec3 normal = geometryNormal;    
  #endif    
  #ifdef HAS_DOUBLE_SIDED_MATERIAL        
  if (czm_backFacing()) {            
    tangent *= -1.0;            
    bitangent *= -1.0;            
    normal *= -1.0;            
    geometryNormal *= -1.0;        
  }    
  #endif    
  NormalInfo normalInfo;    
  normalInfo.tangent = tangent;    
  normalInfo.bitangent = bitangent;    
  normalInfo.normal = normal;    
  normalInfo.geometryNormal = geometryNormal;    
  return normalInfo;
}

#endif

#if defined(HAS_NORMAL_TEXTURE) && !defined(HAS_WIREFRAME)

vec3 getNormalFromTexture(ProcessedAttributes attributes, vec3 geometryNormal){    
  vec2 normalTexCoords = getNormalTexCoords();        
  #ifdef HAS_BITANGENTS        
  vec3 t = attributes.tangentEC;        
  vec3 b = attributes.bitangentEC;    
  #else        
  vec3 t = computeTangent(attributes.positionEC, normalTexCoords);        
  t = normalize(t - geometryNormal * dot(geometryNormal, t));        
  vec3 b = normalize(cross(geometryNormal, t));    
  #endif    
  mat3 tbn = mat3(t, b, geometryNormal);    
  vec3 normalSample = texture(u_normalTexture, normalTexCoords).rgb;    
  normalSample = 2.0 * normalSample - 1.0;    
  #ifdef HAS_NORMAL_TEXTURE_SCALE        
  normalSample.xy *= u_normalTextureScale;    
  #endif    
  return normalize(tbn * normalSample);
}
#endif
#ifdef HAS_CLEARCOAT_NORMAL_TEXTURE
vec3 getClearcoatNormalFromTexture(ProcessedAttributes attributes, vec3 geometryNormal){    
  vec2 normalTexCoords = TEXCOORD_CLEARCOAT_NORMAL;    
  #ifdef HAS_CLEARCOAT_NORMAL_TEXTURE_TRANSFORM        
  normalTexCoords = vec2(u_clearcoatNormalTextureTransform * vec3(normalTexCoords, 1.0));    
  #endif        
  #ifdef HAS_BITANGENTS        
  vec3 t = attributes.tangentEC;        
  vec3 b = attributes.bitangentEC;    
  #else        
  vec3 t = computeTangent(attributes.positionEC, normalTexCoords);        
  t = normalize(t - geometryNormal * dot(geometryNormal, t));        
  vec3 b = normalize(cross(geometryNormal, t));    
  #endif    
  mat3 tbn = mat3(t, b, geometryNormal);    
  vec3 normalSample = texture(u_clearcoatNormalTexture, normalTexCoords).rgb;    
  normalSample = 2.0 * normalSample - 1.0;    
  #ifdef HAS_CLEARCOAT_NORMAL_TEXTURE_SCALE        
  normalSample.xy *= u_clearcoatNormalTextureScale;    
  #endif    
  return normalize(tbn * normalSample);
}

#endif
#ifdef HAS_NORMALS

vec3 computeNormal(ProcessedAttributes attributes){        
  vec3 normal = attributes.normalEC;    
  #if defined(HAS_NORMAL_TEXTURE) && !defined(HAS_WIREFRAME)        
  normal = getNormalFromTexture(attributes, normal);    
  #endif   
  #ifdef HAS_DOUBLE_SIDED_MATERIAL        
  if (czm_backFacing()) {            normal = -normal;        }    
  #endif    
  return normal;
}

#endif

#ifdef HAS_BASE_COLOR_TEXTURE

vec4 getBaseColorFromTexture(){    
  vec2 baseColorTexCoords = TEXCOORD_BASE_COLOR;    
  #ifdef HAS_BASE_COLOR_TEXTURE_TRANSFORM        
  baseColorTexCoords = computeTextureTransform(baseColorTexCoords, u_baseColorTextureTransform);    
  #endif    
  vec4 baseColorWithAlpha = czm_srgbToLinear(texture(u_baseColorTexture, baseColorTexCoords));    
  #ifdef HAS_BASE_COLOR_FACTOR        
  baseColorWithAlpha *= u_baseColorFactor;    
  #endif    
  return baseColorWithAlpha;
}
#endif
#ifdef HAS_EMISSIVE_TEXTURE

vec3 getEmissiveFromTexture(){    
  vec2 emissiveTexCoords = TEXCOORD_EMISSIVE;    
  #ifdef HAS_EMISSIVE_TEXTURE_TRANSFORM        
  emissiveTexCoords = computeTextureTransform(emissiveTexCoords, u_emissiveTextureTransform);    
  #endif    
  vec3 emissive = czm_srgbToLinear(texture(u_emissiveTexture, emissiveTexCoords).rgb);    
  #ifdef HAS_EMISSIVE_FACTOR        
  emissive *= u_emissiveFactor;    
  #endif    
  return emissive;
}
#endif

#if defined(LIGHTING_PBR) && defined(USE_SPECULAR_GLOSSINESS)

void setSpecularGlossiness(inout czm_modelMaterial material){    
  #ifdef HAS_SPECULAR_GLOSSINESS_TEXTURE        
  vec2 specularGlossinessTexCoords = TEXCOORD_SPECULAR_GLOSSINESS;        
  #ifdef HAS_SPECULAR_GLOSSINESS_TEXTURE_TRANSFORM            
  specularGlossinessTexCoords = computeTextureTransform(specularGlossinessTexCoords, u_specularGlossinessTextureTransform);        
  #endif        
  vec4 specularGlossiness = czm_srgbToLinear(texture(u_specularGlossinessTexture, specularGlossinessTexCoords));        
  vec3 specular = specularGlossiness.rgb;        
  float glossiness = specularGlossiness.a;        
  #ifdef HAS_LEGACY_SPECULAR_FACTOR            
  specular *= u_legacySpecularFactor;        
  #endif        
  #ifdef HAS_GLOSSINESS_FACTOR            
  glossiness *= u_glossinessFactor;        
  #endif    
  #else        
  #ifdef HAS_LEGACY_SPECULAR_FACTOR            
  vec3 specular = clamp(u_legacySpecularFactor, vec3(0.0), vec3(1.0));        
  #else            
  vec3 specular = vec3(1.0);        
  #endif        
  #ifdef HAS_GLOSSINESS_FACTOR            
  float glossiness = clamp(u_glossinessFactor, 0.0, 1.0);        
  #else            
  float glossiness = 1.0;        
  #endif    
  #endif    
  #ifdef HAS_DIFFUSE_TEXTURE        
  vec2 diffuseTexCoords = TEXCOORD_DIFFUSE;        
  #ifdef HAS_DIFFUSE_TEXTURE_TRANSFORM            
  diffuseTexCoords = computeTextureTransform(diffuseTexCoords, u_diffuseTextureTransform);        
  #endif        
  vec4 diffuse = czm_srgbToLinear(texture(u_diffuseTexture, diffuseTexCoords));        
  #ifdef HAS_DIFFUSE_FACTOR            
  diffuse *= u_diffuseFactor;        
  #endif    
  #elif defined(HAS_DIFFUSE_FACTOR)        
  vec4 diffuse = clamp(u_diffuseFactor, vec4(0.0), vec4(1.0));    
  #else        
  vec4 diffuse = vec4(1.0);    
  #endif    
  material.diffuse = diffuse.rgb * (1.0 - czm_maximumComponent(specular));            
  material.alpha = diffuse.a;    material.specular = specular;        
  float roughness = 1.0 - glossiness;    material.roughness = roughness * roughness;
}
#elif defined(LIGHTING_PBR)
float setMetallicRoughness(inout czm_modelMaterial material){    
  #ifdef HAS_METALLIC_ROUGHNESS_TEXTURE        
  vec2 metallicRoughnessTexCoords = TEXCOORD_METALLIC_ROUGHNESS;        
  #ifdef HAS_METALLIC_ROUGHNESS_TEXTURE_TRANSFORM            
  metallicRoughnessTexCoords = computeTextureTransform(metallicRoughnessTexCoords, u_metallicRoughnessTextureTransform);        
  #endif        
  vec3 metallicRoughness = texture(u_metallicRoughnessTexture, metallicRoughnessTexCoords).rgb;        
  float metalness = clamp(metallicRoughness.b, 0.0, 1.0);        
  float roughness = clamp(metallicRoughness.g, 0.04, 1.0);        
  #ifdef HAS_METALLIC_FACTOR            
  metalness = clamp(metalness * u_metallicFactor, 0.0, 1.0);        
  #endif        
  
  #ifdef HAS_ROUGHNESS_FACTOR            
  roughness = clamp(roughness * u_roughnessFactor, 0.0, 1.0);        
  #endif    
  #else        
  #ifdef HAS_METALLIC_FACTOR            
  float metalness = clamp(u_metallicFactor, 0.0, 1.0);        
  #else            
  float metalness = 1.0;        
  #endif        
  #ifdef HAS_ROUGHNESS_FACTOR            
  float roughness = clamp(u_roughnessFactor, 0.04, 1.0);        
  #else            
  float roughness = 1.0;        
  #endif    
  
  #endif        
  const vec3 REFLECTANCE_DIELECTRIC = vec3(0.04);    
  vec3 f0 = mix(REFLECTANCE_DIELECTRIC, material.baseColor.rgb, metalness);    
  material.specular = f0;        
  material.diffuse = mix(material.baseColor.rgb, vec3(0.0), metalness);           
  material.roughness = roughness * roughness;    
  return metalness;
}
  
#ifdef USE_SPECULAR
void setSpecular(inout czm_modelMaterial material, in float metalness){    
  #ifdef HAS_SPECULAR_TEXTURE        
  vec2 specularTexCoords = TEXCOORD_SPECULAR;        
  #ifdef HAS_SPECULAR_TEXTURE_TRANSFORM            
  specularTexCoords = computeTextureTransform(specularTexCoords, u_specularTextureTransform);        
  #endif        
  float specularWeight = texture(u_specularTexture, specularTexCoords).a;        
  #ifdef HAS_SPECULAR_FACTOR            
  specularWeight *= u_specularFactor;        
  #endif    
  #else        
  #ifdef HAS_SPECULAR_FACTOR            
  float specularWeight = u_specularFactor;        
  #else            
  float specularWeight = 1.0;        
  #endif    
  #endif    
  #ifdef HAS_SPECULAR_COLOR_TEXTURE        
  vec2 specularColorTexCoords = TEXCOORD_SPECULAR_COLOR;        
  #ifdef HAS_SPECULAR_COLOR_TEXTURE_TRANSFORM            
  specularColorTexCoords = computeTextureTransform(specularColorTexCoords, u_specularColorTextureTransform);        
  #endif        
  vec3 specularColorSample = texture(u_specularColorTexture, specularColorTexCoords).rgb;        
  vec3 specularColorFactor = czm_srgbToLinear(specularColorSample);        
  #ifdef HAS_SPECULAR_COLOR_FACTOR            
  specularColorFactor *= u_specularColorFactor;        
  #endif    
  #else        
  #ifdef HAS_SPECULAR_COLOR_FACTOR            
  vec3 specularColorFactor = u_specularColorFactor;        
  #else            
  vec3 specularColorFactor = vec3(1.0);        
  #endif    
  #endif    
  material.specularWeight = specularWeight;    
  vec3 f0 = material.specular;    
  vec3 dielectricSpecularF0 = min(f0 * specularColorFactor, vec3(1.0));    
  material.specular = mix(dielectricSpecularF0, material.baseColor.rgb, metalness);
}

#endif
#ifdef USE_ANISOTROPY
void setAnisotropy(inout czm_modelMaterial material, in NormalInfo normalInfo){    
  mat2 rotation = mat2(u_anisotropy.xy, -u_anisotropy.y, u_anisotropy.x);    
  float anisotropyStrength = u_anisotropy.z;    
  vec2 direction = vec2(1.0, 0.0);    
  #ifdef HAS_ANISOTROPY_TEXTURE        
  vec2 anisotropyTexCoords = TEXCOORD_ANISOTROPY;        
  #ifdef HAS_ANISOTROPY_TEXTURE_TRANSFORM            
  anisotropyTexCoords = computeTextureTransform(anisotropyTexCoords, u_anisotropyTextureTransform);        
  #endif        
  vec3 anisotropySample = texture(u_anisotropyTexture, anisotropyTexCoords).rgb;        
  direction = anisotropySample.rg * 2.0 - vec2(1.0);        
  anisotropyStrength *= anisotropySample.b;    
  #endif    
  direction = rotation * direction;    
  mat3 tbn = mat3(normalInfo.tangent, normalInfo.bitangent, normalInfo.normal);    
  vec3 anisotropicT = tbn * normalize(vec3(direction, 0.0));    
  vec3 anisotropicB = cross(normalInfo.geometryNormal, anisotropicT);    
  material.anisotropicT = anisotropicT;    
  material.anisotropicB = anisotropicB;    
  material.anisotropyStrength = anisotropyStrength;
}
  
#endif#ifdef USE_CLEARCOAT

void setClearcoat(inout czm_modelMaterial material, in ProcessedAttributes attributes){    
  #ifdef HAS_CLEARCOAT_TEXTURE        
  vec2 clearcoatTexCoords = TEXCOORD_CLEARCOAT;        
  #ifdef HAS_CLEARCOAT_TEXTURE_TRANSFORM            
  clearcoatTexCoords = computeTextureTransform(clearcoatTexCoords, u_clearcoatTextureTransform);        
  #endif        
  float clearcoatFactor = texture(u_clearcoatTexture, clearcoatTexCoords).r;        
  #ifdef HAS_CLEARCOAT_FACTOR            
  clearcoatFactor *= u_clearcoatFactor;        
  #endif    
  #else        
  #ifdef HAS_CLEARCOAT_FACTOR            
  float clearcoatFactor = u_clearcoatFactor;        
  #else                        
  float clearcoatFactor = 0.0;        
  #endif    
  #endif    
  #ifdef HAS_CLEARCOAT_ROUGHNESS_TEXTURE        
  vec2 clearcoatRoughnessTexCoords = TEXCOORD_CLEARCOAT_ROUGHNESS;        
  #ifdef HAS_CLEARCOAT_ROUGHNESS_TEXTURE_TRANSFORM            
  clearcoatRoughnessTexCoords = computeTextureTransform(clearcoatRoughnessTexCoords, u_clearcoatRoughnessTextureTransform);        
  #endif        
  float clearcoatRoughness = texture(u_clearcoatRoughnessTexture, clearcoatRoughnessTexCoords).g;        
  #ifdef HAS_CLEARCOAT_ROUGHNESS_FACTOR            
  clearcoatRoughness *= u_clearcoatRoughnessFactor;        
  #endif   
  #else        
  #ifdef HAS_CLEARCOAT_ROUGHNESS_FACTOR            
  float clearcoatRoughness = u_clearcoatRoughnessFactor;        
  #else            
  float clearcoatRoughness = 0.0;        
  #endif    
  #endif    
  material.clearcoatFactor = clearcoatFactor;            
  material.clearcoatRoughness = clearcoatRoughness * clearcoatRoughness;    
  #ifdef HAS_CLEARCOAT_NORMAL_TEXTURE        
  material.clearcoatNormal = getClearcoatNormalFromTexture(attributes, attributes.normalEC);    
  #else        
  material.clearcoatNormal = attributes.normalEC;    
  #endif
}

#endif
#endif
void materialStage(inout czm_modelMaterial material, ProcessedAttributes attributes, SelectedFeature feature){                            
  vec4 baseColorWithAlpha = vec4(1.0);        
  #ifdef HAS_BASE_COLOR_TEXTURE        
  baseColorWithAlpha = getBaseColorFromTexture();    
  #elif defined(HAS_BASE_COLOR_FACTOR)        
  baseColorWithAlpha = u_baseColorFactor;    
  #endif    
  #ifdef HAS_POINT_CLOUD_COLOR_STYLE        
  baseColorWithAlpha = v_pointCloudColor;    
  #elif defined(HAS_COLOR_0)        
  vec4 color = attributes.color_0;                
  #ifdef HAS_SRGB_COLOR            
  color = czm_srgbToLinear(color);        
  #endif        
  baseColorWithAlpha *= color;    
  #endif    
  material.baseColor = baseColorWithAlpha;    
  #ifdef USE_CPU_STYLING        
  material.baseColor.rgb = blend(baseColorWithAlpha.rgb, feature.color.rgb, model_colorBlend);    
  #endif    
  material.diffuse = baseColorWithAlpha.rgb;    
  material.alpha = baseColorWithAlpha.a;    
  #ifdef HAS_OCCLUSION_TEXTURE        
  vec2 occlusionTexCoords = TEXCOORD_OCCLUSION;        
  #ifdef HAS_OCCLUSION_TEXTURE_TRANSFORM            
  occlusionTexCoords = computeTextureTransform(occlusionTexCoords, u_occlusionTextureTransform);        
  #endif        
  material.occlusion = texture(u_occlusionTexture, occlusionTexCoords).r;    
  #endif    
  #ifdef HAS_EMISSIVE_TEXTURE        
  material.emissive = getEmissiveFromTexture();    
  #elif defined(HAS_EMISSIVE_FACTOR)        
  material.emissive = u_emissiveFactor;    
  #endif    
  #if defined(LIGHTING_PBR) && defined(USE_SPECULAR_GLOSSINESS)        
  setSpecularGlossiness(material);    
  #elif defined(LIGHTING_PBR)        
  float metalness = setMetallicRoughness(material);        
  #ifdef USE_SPECULAR            
  setSpecular(material, metalness);        
  #endif        
  #ifdef USE_ANISOTROPY            
  setAnisotropy(material, normalInfo);        
  #endif        
  #ifdef USE_CLEARCOAT            
  setClearcoat(material, attributes);        
  #endif    
  #endif
}

  
void featureIdStage(out FeatureIds featureIds, ProcessedAttributes attributes) {  
  initializeFeatureIds(featureIds, attributes);  
  initializeFeatureIdAliases(featureIds);
}

void metadataStage(  out Metadata metadata,  out MetadataClass metadataClass,  out MetadataStatistics metadataStatistics,  ProcessedAttributes attributes  ){  
  initializeMetadata(metadata, metadataClass, metadataStatistics, attributes);
}

#ifdef USE_IBL_LIGHTING

vec3 computeIBL(vec3 position, vec3 normal, vec3 lightDirection, vec3 lightColorHdr, czm_modelMaterial material){    
  #if defined(DIFFUSE_IBL) || defined(SPECULAR_IBL)                
  vec3 viewDirection = -normalize(position);        
  vec3 iblColor = textureIBL(viewDirection, normal, lightDirection, material);    
  #else                
  vec3 imageBasedLighting = proceduralIBL(position, normal, lightDirection, material);        
  float maximumComponent = czm_maximumComponent(lightColorHdr);        
  vec3 clampedLightColor = lightColorHdr / max(maximumComponent, 1.0);        
  vec3 iblColor = clampedLightColor * imageBasedLighting;    
  #endif    
  return iblColor * material.occlusion;
}
#endif
#ifdef USE_CLEARCOAT
vec3 addClearcoatReflection(vec3 baseLayerColor, vec3 position, vec3 lightDirection, vec3 lightColorHdr, czm_modelMaterial material){    
  vec3 viewDirection = -normalize(position);    
  vec3 halfwayDirection = normalize(viewDirection + lightDirection);    
  vec3 normal = material.clearcoatNormal;    
  float NdotL = clamp(dot(normal, lightDirection), 0.001, 1.0);        
  vec3 f0 = vec3(0.04);    
  vec3 f90 = vec3(1.0);            
  float NdotV = clamp(dot(normal, viewDirection), 0.0, 1.0);    
  vec3 F = fresnelSchlick2(f0, f90, NdotV);        
  float roughness = material.clearcoatRoughness;    
  float directStrength = computeDirectSpecularStrength(normal, lightDirection, viewDirection, halfwayDirection, roughness);    
  vec3 directReflection = F * directStrength * NdotL;    
  vec3 color = lightColorHdr * directReflection;    
  #ifdef SPECULAR_IBL                
  vec3 cubeDir = normalize(model_iblReferenceFrameMatrix * normalize(reflect(-viewDirection, normal)));        
  vec3 iblColor = computeSpecularIBL(cubeDir, NdotV, NdotV, f0, roughness);        
  color += iblColor * material.occlusion;    
  #elif defined(USE_IBL_LIGHTING)        
  vec3 positionWC = vec3(czm_inverseView * vec4(position, 1.0));        
  vec3 reflectionWC = normalize(czm_inverseViewRotation * normalize(reflect(viewDirection, normal)));        
  vec3 skyMetrics = getProceduralSkyMetrics(positionWC, reflectionWC);        
  vec3 specularIrradiance = getProceduralSpecularIrradiance(reflectionWC, skyMetrics, roughness);        
  vec2 brdfLut = texture(czm_brdfLut, vec2(NdotV, roughness)).rg;        
  vec3 specularColor = czm_srgbToLinear(f0 * brdfLut.x + brdfLut.y);        vec3 iblColor = specularIrradiance * specularColor * model_iblFactor.y;        
  #ifdef USE_SUN_LUMINANCE            
  iblColor *= getSunLuminance(positionWC, normal, lightDirection);        
  #endif        
  float maximumComponent = czm_maximumComponent(lightColorHdr);        
  vec3 clampedLightColor = lightColorHdr / max(maximumComponent, 1.0);        
  color += clampedLightColor* iblColor * material.occlusion;    
  #endif    
  float clearcoatFactor = material.clearcoatFactor;    
  vec3 clearcoatColor = color * clearcoatFactor;        
  return baseLayerColor * (1.0 - clearcoatFactor * F) + clearcoatColor;
}
#endif
#if defined(LIGHTING_PBR) && defined(HAS_NORMALS)

vec3 computePbrLighting(in czm_modelMaterial material, in vec3 position){    
  #ifdef USE_CUSTOM_LIGHT_COLOR        
  vec3 lightColorHdr = model_lightColorHdr;    
  #else        
  vec3 lightColorHdr = czm_lightColorHdr;    
  #endif    
  vec3 viewDirection = -normalize(position);    
  vec3 normal = material.normalEC;    
  vec3 lightDirection = normalize(czm_lightDirectionEC);    
  vec3 directLighting = czm_pbrLighting(viewDirection, normal, lightDirection, material);    
  vec3 directColor = lightColorHdr * directLighting;        
  vec3 color = directColor + material.emissive;    
  #ifdef USE_IBL_LIGHTING        
  color += computeIBL(position, normal, lightDirection, lightColorHdr, material);    
  #endif    
  #ifdef USE_CLEARCOAT        
  color = addClearcoatReflection(color, position, lightDirection, lightColorHdr, material);    
  #endif    
  return color;
}
#endif  


void lightingStage(inout czm_modelMaterial material, ProcessedAttributes attributes){    
  #ifdef LIGHTING_PBR        
  #ifdef HAS_NORMALS            
  vec3 color = computePbrLighting(material, attributes.positionEC);        
  #else            
  vec3 color = material.diffuse * material.occlusion + material.emissive;        
  #endif                                        
  #ifndef HDR            
  color = czm_acesTonemapping(color);        
  #endif    
  #else         
  vec3 color = material.diffuse;    
  #endif    
  #ifdef HAS_POINT_CLOUD_COLOR_STYLE                
  color = czm_gammaCorrect(color);    
  #elif !defined(HDR)                        
  color = czm_linearToSrgb(color);    
  #endif    
  material.diffuse = color
}

czm_modelMaterial defaultModelMaterial(){    
  czm_modelMaterial material;    
  material.diffuse = vec3(0.0);    
  material.specular = vec3(1.0);    
  material.roughness = 1.0;    
  material.occlusion = 1.0;    
  material.normalEC = vec3(0.0, 0.0, 1.0);    
  material.emissive = vec3(0.0);    
  material.alpha = 1.0;    
  return material;
}

vec4 handleAlpha(vec3 color, float alpha){    
  #ifdef ALPHA_MODE_MASK    
  if (alpha < u_alphaCutoff) {        discard;    }    
  #endif    
  return vec4(color, alpha);
}

SelectedFeature selectedFeature;

void czm_shadow_receive_main(){    
  #ifdef HAS_MODEL_SPLITTER    
  modelSplitterStage();    
  #endif    
  czm_modelMaterial material = defaultModelMaterial();    
  ProcessedAttributes attributes;    
  geometryStage(attributes);    
  FeatureIds featureIds;    
  featureIdStage(featureIds, attributes);    
  Metadata metadata;    
  MetadataClass metadataClass;    
  MetadataStatistics metadataStatistics;    
  metadataStage(metadata, metadataClass, metadataStatistics, attributes);    
  #ifdef HAS_SELECTED_FEATURE_ID    
  selectedFeatureIdStage(selectedFeature, featureIds);    
  #endif    
  #ifndef CUSTOM_SHADER_REPLACE_MATERIAL    
  materialStage(material, attributes, selectedFeature);    
  #endif    
  #ifdef HAS_CUSTOM_FRAGMENT_SHADER    
  customShaderStage(material, attributes, featureIds, metadata, metadataClass, metadataStatistics);    
  #endif    
  lightingStage(material, attributes);    
  #ifdef HAS_SELECTED_FEATURE_ID    
  cpuStylingStage(material, selectedFeature);    
  #endif    
  #ifdef HAS_MODEL_COLOR    
  modelColorStage(material);    
  #endif    
  #ifdef HAS_PRIMITIVE_OUTLINE    
  primitiveOutlineStage(material);    
  #endif    
  vec4 color = handleAlpha(material.diffuse, material.alpha);    
  #ifdef HAS_CLIPPING_PLANES    
  modelClippingPlanesStage(color);    
  #endif    
  #ifdef ENABLE_CLIPPING_POLYGONS    
  modelClippingPolygonsStage();    
  #endif    
  #if defined(HAS_SILHOUETTE) && defined(HAS_NORMALS)    
  silhouetteStage(color);    
  #endif    
  #ifdef HAS_ATMOSPHERE    
  atmosphereStage(color, attributes);    
  #endif    
  out_FragColor = color;
}

#line 0
uniform sampler2D shadowMap_texture; 
uniform mat4 shadowMap_matrix; 
uniform vec3 shadowMap_lightDirectionEC; 
uniform vec4 shadowMap_lightPositionEC; 
uniform vec4 shadowMap_normalOffsetScaleDistanceMaxDistanceAndDarkness; 
uniform vec4 shadowMap_texelSizeDepthBiasAndNormalShadingSmooth; 
#ifdef LOG_DEPTH in vec3 v_logPositionEC; 
#endif 
vec4 getPositionEC() {     return vec4(v_positionEC, 1.0); } 
vec3 getNormalEC() {     return vec3(1.0); } 
void applyNormalOffset(inout vec4 positionEC, vec3 normalEC, float nDotL) { } 

void main() {     
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
  if (depth > maxDepth)     {         return;     }         
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