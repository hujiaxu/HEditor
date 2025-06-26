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
#define OES_texture_float_linear
#define OES_texture_float
#line 0
layout(location = 0) out vec4 out_FragColor;
const float czm_epsilon7 = 0.0000001;
uniform float czm_oneOverLog2FarDepthFromNearPlusOne;
uniform float czm_farDepthFromNearPlusOne;
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
#line 0
void main()
{    
  out_FragColor = vec4(1.0);    
  czm_writeLogDepth();
}