
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