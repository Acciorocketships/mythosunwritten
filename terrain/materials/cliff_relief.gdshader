shader_type spatial;
#include "res://terrain/materials/ground_style.gdshaderinc"
#include "res://terrain/materials/rock_style.gdshaderinc"
uniform sampler2D ground_palette_texture : source_color;
uniform vec2 grass_uv;
varying vec3 rock_world;
varying float upward;
varying float wall_clearance;
void vertex() {
 rock_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 upward=(MODEL_NORMAL_MATRIX*NORMAL).y;
 wall_clearance=VERTEX.z;
}
void fragment() {
 vec3 turf=ground_style(rock_world.xz,texture(ground_palette_texture,grass_uv).rgb*COLOR.rgb);
 float moss=smoothstep(0.76,0.94,upward)*smoothstep(0.65,1.25,wall_clearance);
 ALBEDO=mix(stone_albedo(vec3(0.25),rock_world),turf,moss);
 ROUGHNESS=1.0;
 SPECULAR=0.0;
}
