shader_type spatial;
#include "res://terrain/materials/rock_style.gdshaderinc"
uniform bool instance_variation = true;
uniform bool use_texture = true;
uniform sampler2D albedo_texture : source_color;
uniform vec4 source_color_value : source_color = vec4(1.0);
varying vec3 stone_world;
void vertex() { stone_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 ALBEDO=stone_albedo(use_texture ? texture(albedo_texture,UV).rgb*source_color_value.rgb : vec3(0.25),stone_world);
 if (instance_variation) ALBEDO *= clamp(dot(COLOR.rgb,vec3(0.2126,0.7152,0.0722)),0.9,1.1);
 ROUGHNESS=1.0;
 SPECULAR=0.0;
}
