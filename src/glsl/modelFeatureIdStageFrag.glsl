void modelColorStage(inout czm_modelMaterial material){    
  material.diffuse = mix(material.diffuse, model_color.rgb, model_colorBlend);    
  float highlight = ceil(model_colorBlend);    
  material.diffuse *= mix(model_color.rgb, vec3(1.0), highlight);    
  material.alpha *= model_color.a;
}

#ifdef DIFFUSE_IBL
vec3 sampleDiffuseEnvironment(vec3 cubeDir){    
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
  float lod = roughness * model_specularEnvironmentMapsMaximumLOD;        
  return czm_textureCube(model_specularEnvironmentMaps, cubeDir, lod).rgb;    
  #else        
  float lod = roughness * czm_specularEnvironmentMapsMaximumLOD;        
  return czm_textureCube(czm_specularEnvironmentMaps, cubeDir, lod).rgb;    
  #endif
}
vec3 computeSpecularIBL(vec3 cubeDir, float NdotV, vec3 f0, float roughness){    
  // see https://bruop.github.io/ibl/ at Single Scattering Results    
  // Roughness dependent fresnel, from Fdez-Aguera    
  vec3 f90 = max(vec3(1.0 - roughness), f0);    
  vec3 F = fresnelSchlick2(f0, f90, NdotV);    
  vec2 brdfLut = texture(czm_brdfLut, vec2(NdotV, roughness)).rg;    
  vec3 specularSample = sampleSpecularEnvironment(cubeDir, roughness);    
  return specularSample * (F * brdfLut.x + brdfLut.y);
}
#endif
#if defined(DIFFUSE_IBL) || defined(SPECULAR_IBL)

/** 
  * Compute the light contributions from environment maps and spherical harmonic coefficients. 
  * See Fdez-Aguera, https://www.jcgt.org/published/0008/01/03/paper.pdf, for explanation 
  * of the single- and multi-scattering terms. 
  * 
  * @param {vec3} viewDirectionEC Unit vector pointing from the fragment to the eye position. 
  * @param {vec3} normalEC The surface normal in eye coordinates. 
  * @param {czm_modelMaterial} The material properties. 
  * @return {vec3} The computed HDR color. 
  */
vec3 textureIBL(vec3 viewDirectionEC, vec3 normalEC, czm_modelMaterial material) {    
  vec3 f0 = material.specular;    
  float roughness = material.roughness;    
  float specularWeight = 1.0;    
  #ifdef USE_SPECULAR        
  specularWeight = material.specularWeight;    
  #endif    
  float NdotV = clamp(dot(normalEC, viewDirectionEC), 0.0, 1.0);    
  // see https://bruop.github.io/ibl/ at Single Scattering Results    
  // Roughness dependent fresnel, from Fdez-Aguera    
  vec3 f90 = max(vec3(1.0 - roughness), f0);    
  vec3 singleScatterFresnel = fresnelSchlick2(f0, f90, NdotV);    
  vec2 brdfLut = texture(czm_brdfLut, vec2(NdotV, roughness)).rg;    
  vec3 FssEss = specularWeight * (singleScatterFresnel * brdfLut.x + brdfLut.y);    
  #ifdef DIFFUSE_IBL        
  vec3 normalMC = normalize(model_iblReferenceFrameMatrix * normalEC);        
  vec3 irradiance = sampleDiffuseEnvironment(normalMC);        
  vec3 averageFresnel = f0 + (1.0 - f0) / 21.0;        
  float Ems = specularWeight * (1.0 - brdfLut.x - brdfLut.y);        
  vec3 FmsEms = FssEss * averageFresnel * Ems / (1.0 - averageFresnel * Ems);        
  vec3 dielectricScattering = (1.0 - FssEss - FmsEms) * material.diffuse;        
  vec3 diffuseContribution = irradiance * (FmsEms + dielectricScattering) * model_iblFactor.x;    
  #else        
  vec3 diffuseContribution = vec3(0.0);    
  #endif    
  #ifdef USE_ANISOTROPY        
  // Bend normal to account for anisotropic distortion of specular reflection        
  vec3 anisotropyDirection = material.anisotropicB;        
  vec3 anisotropicTangent = cross(anisotropyDirection, viewDirectionEC);        
  vec3 anisotropicNormal = cross(anisotropicTangent, anisotropyDirection);        
  float bendFactor = 1.0 - material.anisotropyStrength * (1.0 - roughness);        
  float bendFactorPow4 = bendFactor * bendFactor * bendFactor * bendFactor;        
  vec3 bentNormal = normalize(mix(anisotropicNormal, normalEC, bendFactorPow4));        
  vec3 reflectEC = reflect(-viewDirectionEC, bentNormal);    
  #else        
  vec3 reflectEC = reflect(-viewDirectionEC, normalEC);    
  #endif    
  #ifdef SPECULAR_IBL        
  vec3 reflectMC = normalize(model_iblReferenceFrameMatrix * reflectEC);        
  vec3 radiance = sampleSpecularEnvironment(reflectMC, roughness);        
  vec3 specularContribution = radiance * FssEss * model_iblFactor.y;    
  #else        
  vec3 specularContribution = vec3(0.0);    
  #endif    
  return diffuseContribution + specularContribution;
}
#endif

// robust iterative solution without trig functions
// https://github.com/0xfaded/ellipse_demo/issues/1
// https://stackoverflow.com/questions/22959698/distance-from-given-point-to-given-ellipse
//
// This version uses only a single iteration for best performance. For fog
// rendering, the difference is negligible.
vec2 nearestPointOnEllipseFast(vec2 pos, vec2 radii) {    
  vec2 p = abs(pos);    
  vec2 inverseRadii = 1.0 / radii;    
  vec2 evoluteScale = (radii.x * radii.x - radii.y * radii.y) * vec2(1.0, -1.0) * inverseRadii;    
  // We describe the ellipse parametrically: v = radii * vec2(cos(t), sin(t))    
  // but store the cos and sin of t in a vec2 for efficiency.    
  // Initial guess: t = cos(pi/4)    
  vec2 tTrigs = vec2(0.70710678118);    
  vec2 v = radii * tTrigs;    
  // Find the evolute of the ellipse (center of curvature) at v.    
  vec2 evolute = evoluteScale * tTrigs * tTrigs * tTrigs;    
  // Find the (approximate) intersection of p - evolute with the ellipsoid.    
  vec2 q = normalize(p - evolute) * length(v - evolute);    
  // Update the estimate of t.    
  tTrigs = (q + evolute) * inverseRadii;    
  tTrigs = normalize(clamp(tTrigs, 0.0, 1.0));    
  v = radii * tTrigs;    
  return v * sign(pos);
}
vec3 computeEllipsoidPositionWC(vec3 positionMC) {    
  // Get the world-space position and project onto a meridian plane of    
  // the ellipsoid    
  vec3 positionWC = (czm_model * vec4(positionMC, 1.0)).xyz;    
  vec2 positionEllipse = vec2(length(positionWC.xy), positionWC.z);    
  vec2 nearestPoint = nearestPointOnEllipseFast(positionEllipse, czm_ellipsoidRadii.xz);    
  // Reconstruct a 3D point in world space    
  return vec3(nearestPoint.x * normalize(positionWC.xy), nearestPoint.y);
}
void applyFog(inout vec4 color, vec4 groundAtmosphereColor, vec3 lightDirection, float distanceToCamera) {    
  vec3 fogColor = groundAtmosphereColor.rgb;    
  // If there is dynamic lighting, apply that to the fog.    
  const float NONE = 0.0;    
  if (czm_atmosphereDynamicLighting != NONE) {        
    float darken = clamp(dot(normalize(czm_viewerPositionWC), lightDirection), czm_fogMinimumBrightness, 1.0);        
    fogColor *= darken;    
  }    
  // Tonemap if HDR rendering is disabled    
  #ifndef HDR        
  fogColor.rgb = czm_pbrNeutralTonemapping(fogColor.rgb);        
  fogColor.rgb = czm_inverseGamma(fogColor.rgb);    
  #endif    
  vec3 withFog = czm_fog(distanceToCamera, color.rgb, fogColor, czm_fogVisualDensityScalar);    
  color = vec4(withFog, color.a);
}

void atmosphereStage(inout vec4 color, in ProcessedAttributes attributes) {    
  vec3 rayleighColor;    
  vec3 mieColor;    
  float opacity;    
  vec3 positionWC;    
  vec3 lightDirection;    
  // When the camera is in space, compute the position per-fragment for    
  // more accurate ground atmosphere. All other cases will use    
  //    
  // The if condition will be added in https://github.com/CesiumGS/cesium/issues/11717    
  if (false) {        
    positionWC = computeEllipsoidPositionWC(attributes.positionMC);        
    lightDirection = czm_getDynamicAtmosphereLightDirection(positionWC, czm_atmosphereDynamicLighting);        
    // The fog color is derived from the ground atmosphere color        
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
  //color correct rayleigh and mie colors    
  const bool ignoreBlackPixels = true;    
  rayleighColor = czm_applyHSBShift(rayleighColor, czm_atmosphereHsbShift, ignoreBlackPixels);    
  mieColor = czm_applyHSBShift(mieColor, czm_atmosphereHsbShift, ignoreBlackPixels);    
  vec4 groundAtmosphereColor = czm_computeAtmosphereColor(positionWC, lightDirection, rayleighColor, mieColor, opacity);    
  if (u_isInFog) {        
    float distanceToCamera = length(attributes.positionEC);        
    applyFog(color, groundAtmosphereColor, lightDirection, distanceToCamera);    
  } else {        
    // Ground atmosphere    
  }
}

void geometryStage(out ProcessedAttributes attributes){  
  attributes.positionMC = v_positionMC;  
  attributes.positionEC = v_positionEC;  
  #if defined(COMPUTE_POSITION_WC_CUSTOM_SHADER) || defined(COMPUTE_POSITION_WC_STYLE) || defined(COMPUTE_POSITION_WC_ATMOSPHERE)  
  attributes.positionWC = v_positionWC;  
  #endif  
  #ifdef HAS_NORMALS  
  // renormalize after interpolation  
  attributes.normalEC = normalize(v_normalEC);  
  #endif  
  #ifdef HAS_TANGENTS  
  attributes.tangentEC = normalize(v_tangentEC);  
  #endif  
  #ifdef HAS_BITANGENTS  
  attributes.bitangentEC = normalize(v_bitangentEC);  
  #endif  
  // Everything else is dynamically generated in GeometryPipelineStage  
  setDynamicVaryings(attributes);
}

// If the style color is white, it implies the feature has not been styled.
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
struct NormalInfo {    
  vec3 tangent;    
  vec3 bitangent;    
  vec3 normal;    
  vec3 geometryNormal;
};
NormalInfo getNormalInfo(ProcessedAttributes attributes){    
  vec3 geometryNormal = attributes.normalEC;    
  #ifdef HAS_NORMAL_TEXTURE        
  vec2 normalTexCoords = getNormalTexCoords();    
  #endif    
  #ifdef HAS_BITANGENTS        
  vec3 tangent = attributes.tangentEC;        
  vec3 bitangent = attributes.bitangentEC;    
  #else // Assume HAS_NORMAL_TEXTURE        
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
  // If HAS_BITANGENTS is set, then HAS_TANGENTS is also set    
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
  // If HAS_BITANGENTS is set, then HAS_TANGENTS is also set    
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
  // Geometry normal. This is already normalized    
  vec3 normal = attributes.normalEC;    
  #if defined(HAS_NORMAL_TEXTURE) && !defined(HAS_WIREFRAME)        
  normal = getNormalFromTexture(attributes, normal);    
  #endif    
  #ifdef HAS_DOUBLE_SIDED_MATERIAL        
  if (czm_backFacing()) {           
    normal = -normal;        
  }    
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
  // the specular glossiness extension's alpha overrides anything set    
  // by the base material.    
  material.alpha = diffuse.a;    
  material.specular = specular;    
  // glossiness is the opposite of roughness, but easier for artists to use.    
  material.roughness = 1.0 - glossiness;
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
  float roughness = clamp(metallicRoughness.g, 0.0, 1.0);        
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
  float roughness = clamp(u_roughnessFactor, 0.0, 1.0);        
  #else            
  float roughness = 1.0;        
  #endif    
  #endif    
  // dielectrics use f0 = 0.04, metals use albedo as f0    
  const vec3 REFLECTANCE_DIELECTRIC = vec3(0.04);    
  vec3 f0 = mix(REFLECTANCE_DIELECTRIC, material.baseColor.rgb, metalness);    
  material.specular = f0;    
  // diffuse only applies to dielectrics.    
  material.diffuse = mix(material.baseColor.rgb, vec3(0.0), metalness);    
  // This is perceptual roughness. The square of this value is used for direct lighting    
  material.roughness = roughness;    
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
#endif
#ifdef USE_CLEARCOAT
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
  // PERFORMANCE_IDEA: this case should turn the whole extension off            
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
  // This is perceptual roughness. The square of this value is used for direct lighting    
  material.clearcoatRoughness = clearcoatRoughness;    
  #ifdef HAS_CLEARCOAT_NORMAL_TEXTURE        
  material.clearcoatNormal = getClearcoatNormalFromTexture(attributes, attributes.normalEC);    
  #else        
  material.clearcoatNormal = attributes.normalEC;    
  #endif
}
#endif
#endif
void materialStage(inout czm_modelMaterial material, ProcessedAttributes attributes, SelectedFeature feature){    
  #ifdef USE_ANISOTROPY        
  NormalInfo normalInfo = getNormalInfo(attributes);        
  material.normalEC = normalInfo.normal;    
  #elif defined(HAS_NORMALS)        
  material.normalEC = computeNormal(attributes);    
  #endif    
  vec4 baseColorWithAlpha = vec4(1.0);    
  // Regardless of whether we use PBR, set a base color    
  #ifdef HAS_BASE_COLOR_TEXTURE        
  baseColorWithAlpha = getBaseColorFromTexture();    
  #elif defined(HAS_BASE_COLOR_FACTOR)        
  baseColorWithAlpha = u_baseColorFactor;    
  #endif    
  #ifdef HAS_POINT_CLOUD_COLOR_STYLE        
  baseColorWithAlpha = v_pointCloudColor;    
  #elif defined(HAS_COLOR_0)        
  vec4 color = attributes.color_0;        
  // .pnts files store colors in the sRGB color space        
  #ifdef HAS_SRGB_COLOR            
  color = czm_srgbToLinear(color);        
  #endif        
  baseColorWithAlpha *= color;    
  #endif    
  #ifdef USE_CPU_STYLING        
  baseColorWithAlpha.rgb = blend(baseColorWithAlpha.rgb, feature.color.rgb, model_colorBlend);    
  #endif    
  material.baseColor = baseColorWithAlpha;    
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

void featureIdStage(out FeatureIds featureIds, ProcessedAttributes attributes) {  initializeFeatureIds(featureIds, attributes);  initializeFeatureIdAliases(featureIds);}

void metadataStage(  out Metadata metadata,  out MetadataClass metadataClass,  out MetadataStatistics metadataStatistics,  ProcessedAttributes attributes  ){  
  initializeMetadata(metadata, metadataClass, metadataStatistics, attributes);
}

#ifdef USE_IBL_LIGHTING
vec3 computeIBL(vec3 position, vec3 normal, vec3 lightDirection, vec3 lightColorHdr, czm_modelMaterial material){    
  #if defined(DIFFUSE_IBL) || defined(SPECULAR_IBL)        
  // Environment maps were provided, use them for IBL        
  vec3 viewDirection = -normalize(position);        
  vec3 iblColor = textureIBL(viewDirection, normal, material);        
  return iblColor;    
  #endif        
  return vec3(0.0);
}
#endif
#ifdef USE_CLEARCOAT
vec3 addClearcoatReflection(vec3…    #endif    
  #else // unlit        
  vec3 color = material.diffuse;    
  #endif    
  #ifdef HAS_POINT_CLOUD_COLOR_STYLE        
  // The colors resulting from point cloud styles are adjusted differently.        
  color = czm_gammaCorrect(color);    
  #elif !defined(HDR)        
  // If HDR is not enabled, the frame buffer stores sRGB colors rather than        
  // linear colors so the linear value must be converted.        
  color = czm_linearToSrgb(color);    
  #endif    
  material.diffuse = color;
}
