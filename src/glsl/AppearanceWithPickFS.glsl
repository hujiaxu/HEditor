in vec4 v_pickColor;
#define FLAT
#define FACE_FORWARD
uniform vec2 repeat_1;
uniform sampler2D image_0;
czm_material czm_getMaterial(czm_materialInput materialInput) {
  czm_material material = czm_getDefaultMaterial(materialInput);

  vec2 st = materialInput.st;

  vec3 normalEC = materialInput.normalEC;
  vec3 up = vec3(0.0, 1.0, 0.0);
  vec3 normalMC = czm_inverseNormal * normalEC;

            // vec4 diffuse = vec4(0.0, 0.0, 0.0, 1.0);

            // diffuse.rgb = czm_gammaCorrect(texture(image_0, fract(repeat_1 * materialInput.st)).rgb * diffuse.rgb);
            // diffuse.a = texture(image_0, fract(repeat_1 * materialInput.st)).a * diffuse.a;

            // if (dot(normalMC, up) < 0.0) {
            //   diffuse = texture(image_0, st).rgba;
            // }
  vec4 textureColor = texture(image_0, st).rgba;

            // 法线向量
  material.diffuse = textureColor.rgb;
            // material.specular = 1.;
            // material.normal = normal;
  material.alpha = 1.;

  return material;
}

in vec3 v_positionEC;
in vec3 v_normalEC;
in vec2 v_st;

void main() {
  vec3 positionToEyeEC = -v_positionEC;

  vec3 normalEC = normalize(v_normalEC);
#ifdef FACE_FORWARD
  normalEC = faceforward(normalEC, vec3(0.0, 0.0, 1.0), -normalEC);
#endif

  czm_materialInput materialInput;
  materialInput.normalEC = normalEC;
  materialInput.positionToEyeEC = positionToEyeEC;
  materialInput.st = v_st;
  czm_material material = czm_getMaterial(materialInput);

#ifdef FLAT
  out_FragColor = vec4(material.diffuse + material.emission, material.alpha);
#else
  out_FragColor = czm_phong(normalize(positionToEyeEC), material, czm_lightDirectionEC);
#endif
}