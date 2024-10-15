in vec4 v_pickColor;
#define FLAT
#define FACE_FORWARD
uniform vec2 repeat_1;
uniform sampler2D image_0;
czm_material czm_getMaterial(czm_materialInput materialInput) {
  czm_material material = czm_getDefaultMaterial(materialInput);
  return material;
}

in vec3 v_positionEC;
in vec3 v_normalEC;
in vec2 v_st;

void main() {
              // 从纹理中采样颜色

  vec4 textureColor = texture(image_0, vec2(v_st)).rgba;

  out_FragColor = vec4(textureColor.rgb, 1.);
}