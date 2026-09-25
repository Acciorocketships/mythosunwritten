shader_type spatial;
#include "res://terrain/materials/rock_style.gdshaderinc"

varying vec3 stone_position;
void vertex() {
 stone_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash_stone(vec3 p) {
 p = fract(p * vec3(.1031, .1030, .0973));
 p += dot(p, p.yxz + 33.33);
 return fract((p.x + p.y) * p.z);
}
float weather(vec3 p) {
 vec3 i = floor(p), f = fract(p);
 f = f * f * (3.0 - 2.0 * f);
 return mix(mix(mix(hash_stone(i), hash_stone(i + vec3(1,0,0)), f.x),
                mix(hash_stone(i + vec3(0,1,0)), hash_stone(i + vec3(1,1,0)), f.x), f.y),
            mix(mix(hash_stone(i + vec3(0,0,1)), hash_stone(i + vec3(1,0,1)), f.x),
                mix(hash_stone(i + vec3(0,1,1)), hash_stone(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void fragment() {
 // Restrained irregular mineral mottling. No repeated native wall course texture.
 float broad = weather(stone_position * .8);
 float grain = weather(stone_position * 5.0);
 float pits = abs(weather(stone_position * 2.6) - .48);
 float relief = (.024 * grain + .032 * pits) * COLOR.a;
 vec3 dx = dFdx(VERTEX), dy = dFdy(VERTEX);
 vec3 rx = cross(dy, NORMAL), ry = cross(NORMAL, dx);
 float determinant = dot(dx, rx);
 vec3 gradient = dFdx(relief) * rx + dFdy(relief) * ry;
 if (abs(determinant) > .00000001) {
  NORMAL = normalize(abs(determinant) * NORMAL - sign(determinant) * gradient);
 }
 ALBEDO = stone_albedo(vec3(.25)) * mix(1.0, .90 + .18 * broad + .04 * grain, COLOR.a);
 ROUGHNESS = 1.0;
 SPECULAR = 0.0;
}
