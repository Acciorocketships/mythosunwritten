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
// Irregular physical-scale fracture cells, elongated vertically and exposed in
// broken patches. The nearest dividing plane produces
// a short, bevelled crevice; no repeated native cliff course is copied.
vec2 stone_joint(vec3 p) {
 vec3 cell=floor(p), local=fract(p);
 float first=100.0;
 vec3 nearest=vec3(0.0);
 for(int z=-1;z<=1;z++) for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
  vec3 offset=vec3(float(x),float(y),float(z));
  vec3 key=cell+offset;
  vec3 seed=offset+.16+.68*vec3(hash_stone(key),hash_stone(key+13.17),hash_stone(key+39.31));
  vec3 delta=seed-local;
  float distance=dot(delta,delta);
  if(distance<first){first=distance;nearest=seed;}
 }
 float edge=100.0;
 for(int z=-1;z<=1;z++) for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
  vec3 offset=vec3(float(x),float(y),float(z));
  vec3 key=cell+offset;
  vec3 seed=offset+.16+.68*vec3(hash_stone(key),hash_stone(key+13.17),hash_stone(key+39.31));
  vec3 between=seed-nearest;
  if(dot(between,between)>.00001) {
   edge=min(edge,dot((seed+nearest)*.5-local,normalize(between)));
  }
 }
 return vec2(edge,first);
}
void fragment() {
 float broad=weather(stone_position*.8);
 float grain=weather(stone_position*5.0);
 vec2 joint=stone_joint(stone_position*vec3(.50,.17,.50));
 float exposure=smoothstep(.37,.62,weather(stone_position*.38+vec3(37.0)));
 float crack=(1.0-smoothstep(.006,.032,joint.x))*exposure;
 float bevel=(1.0-smoothstep(.005,.080,joint.x))*exposure;
 float relief=(.004*grain-.010*bevel)*COLOR.a;
 vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX);
 vec3 rx=cross(dy,NORMAL),ry=cross(NORMAL,dx);
 float determinant=dot(dx,rx);
 vec3 gradient=dFdx(relief)*rx+dFdy(relief)*ry;
 if(abs(determinant)>.00000001) {
  NORMAL=normalize(abs(determinant)*NORMAL-sign(determinant)*gradient);
 }
 ALBEDO=stone_albedo(vec3(.25))*mix(1.0,(.98+.035*broad+.008*grain)*(1.0-.025*crack),COLOR.a);
 ROUGHNESS=1.0;
 SPECULAR=0.0;
}
