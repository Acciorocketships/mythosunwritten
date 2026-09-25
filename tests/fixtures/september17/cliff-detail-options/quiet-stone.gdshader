shader_type spatial;
#include "res://terrain/materials/rock_style.gdshaderinc"
varying vec3 stone_position;
void vertex(){stone_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){ALBEDO=stone_albedo(vec3(.25),stone_position);ROUGHNESS=1.0;SPECULAR=0.0;}
