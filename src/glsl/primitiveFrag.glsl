#version 300 es
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
precision highp int;
#else
precision mediump float;
precision mediump int;
#define highp mediump
#endif
#define OES_texture_float_linear
#define OES_texture_float
#line 0
layout(location = 0) out vec4 out_FragColor;
const float czm_epsilon7 = 0.0000001;
const float czm_infinity = 5906376272000.0;
const vec4 K_HSB2RGB = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
vec3 czm…ghColor, mieColor, opacity;
#ifndef HDR
color.rgb = czm_pbrNeutralTonemapping(color.rgb);
color.rgb = czm_inverseGamma(color.rgb);
#endif
#ifdef COLOR_CORRECT
const bool ignoreBlackPixels = true;
color.rgb = czm_applyHSBShift(color.rgb, u_hsbShift, ignoreBlackPixels);
#endif
if (translucent == 0.0) {
  color.a = mix(color.b, 1.0, color.a) * smoothstep(0.0, 1.0, czm_morphTime);
}
out_FragColor = color;

