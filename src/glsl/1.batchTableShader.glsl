uniform highp sampler2D batchTexture; 
uniform vec4 batchTextureStep; 
vec2 computeSt(float batchId) { 
    float stepX = batchTextureStep.x; 
    float centerX = batchTextureStep.y; 
    float numberOfAttributes = float(4); 
    return vec2(centerX + (batchId * numberOfAttributes * stepX), 0.5); 
} 
