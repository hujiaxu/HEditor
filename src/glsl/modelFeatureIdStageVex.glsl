void atmosphereStage(ProcessedAttributes attributes) {
  vec3 lightDirection = czm_getDynamicAtmosphereLightDirection(v_positionWC, czm_atmosphereDynamicLighting);
  czm_computeGroundAtmosphereScattering(
    // This assumes the geometry stage came before this.
    v_positionWC,
    lightDirection,
    v_atmosphereRayleighColor,
    v_atmosphereMieColor,
    v_atmosphereOpacity
  );
}

vec4 geometryStage(inout ProcessedAttributes attributes, mat4 modelView, mat3 normal){    
  vec4 computedPosition;    
  // Compute positions in different coordinate systems    
  vec3 positionMC = attributes.positionMC;    
  v_positionMC = positionMC;    
  v_positionEC = (modelView * vec4(positionMC, 1.0)).xyz;    
  #if defined(USE_2D_POSITIONS) || defined(USE_2D_INSTANCING)    
  vec3 position2D = attributes.position2D;    
  vec3 positionEC = (u_modelView2D * vec4(position2D, 1.0)).xyz;    
  computedPosition = czm_projection * vec4(positionEC, 1.0);    
  #else    
  computedPosition = czm_projection * vec4(v_positionEC, 1.0);    
  #endif    
  // Sometimes the custom shader and/or style needs this    
  #if defined(COMPUTE_POSITION_WC_CUSTOM_SHADER) || defined(COMPUTE_POSITION_WC_STYLE) || defined(COMPUTE_POSITION_WC_ATMOSPHERE) || defined(ENABLE_CLIPPING_POLYGONS)    
  // Note that this is a 32-bit position which may result in jitter on small    
  // scales.    
  v_positionWC = (czm_model * vec4(positionMC, 1.0)).xyz;    
  #endif    
  #ifdef HAS_NORMALS    
  v_normalEC = normalize(normal * attributes.normalMC);    
  #endif    
  #ifdef HAS_TANGENTS    
  v_tangentEC = normalize(normal * attributes.tangentMC);    
  #endif    
  #ifdef HAS_BITANGENTS    
  v_bitangentEC = normalize(normal * attributes.bitangentMC);    
  #endif    
  // All other varyings need to be dynamically generated in    
  // GeometryPipelineStage    
  setDynamicVaryings(attributes);    
  return computedPosition;
}


void featureIdStage(out FeatureIds featureIds, ProcessedAttributes attributes) {  initializeFeatureIds(featureIds, attributes);  initializeFeatureIdAliases(featureIds);  setFeatureIdVaryings();}

void metadataStage(  out Metadata metadata,  out MetadataClass metadataClass,  out MetadataStatistics metadataStatistics,  ProcessedAttributes attributes  ){  initializeMetadata(metadata, metadataClass, metadataStatistics, attributes);  setMetadataVaryings();}

