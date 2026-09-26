shader_type spatial;
#include "res://terrain/materials/ground_style.gdshaderinc"
#include "res://terrain/materials/rock_style.gdshaderinc"
uniform sampler2D ground_palette_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec2 grass_uv;
uniform sampler2D moss_detail : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 moss_detail_mean = vec3(1.0);
uniform float moss_detail_strength = 0.0;
uniform float moss_detail_scale = .55;
uniform vec3 moss_shade = vec3(.40,.58,.50);
uniform float moss_blend_height = 4.0;
uniform float moss_secondary = .9;
uniform bool slope_attachment = false;
#include "res://terrain/materials/slope_green.gdshaderinc"
varying vec3 world_position;
varying vec3 support_normal;
// Meadow's authored rock + terrain-grass top layer. No slope-distance halo.
uniform sampler2D base_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D base_sma : filter_linear_mipmap, repeat_enable;
uniform vec3 base_tint = vec3(.5520116,.41788515,.34191445);
uniform float top_offset = .5;
uniform float top_contrast = 10.0;
varying vec3 world_normal;
varying vec3 world_tangent;
varying vec3 world_binormal;
vec3 overlay(vec3 a, vec3 b){return mix(2.0*a*b,1.0-2.0*(1.0-a)*(1.0-b),step(vec3(.5),b));}
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 support_normal=slope_attachment?vec3(INSTANCE_CUSTOM.x,sqrt(max(0.0,1.0-INSTANCE_CUSTOM.x*INSTANCE_CUSTOM.x-INSTANCE_CUSTOM.y*INSTANCE_CUSTOM.y)),INSTANCE_CUSTOM.y):vec3(0,1,0);
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 world_tangent=normalize(mat3(MODEL_MATRIX)*TANGENT);
 world_binormal=normalize(mat3(MODEL_MATRIX)*BINORMAL);
}
void fragment(){
 vec3 bn=texture(base_normal,UV).rgb;
 vec3 tangent_n=vec3(bn.xy*2.0-1.0,0.0);
 tangent_n.z=sqrt(max(0.0,1.0-dot(tangent_n.xy,tangent_n.xy)));
 vec3 wn=normalize(world_tangent*tangent_n.x+world_binormal*tangent_n.y+world_normal*tangent_n.z);
 float cover=clamp(pow(max(wn.y,0.0)+top_offset,top_contrast),0.0,1.0);
 vec3 rock=clamp(overlay(texture(base_albedo,UV).rgb,base_tint),vec3(0),vec3(1));
 ALBEDO=mix(rock,slope_green(world_position,normalize(support_normal),COLOR.rgb,28.0*(1.0-support_normal.y)),cover);
 NORMAL_MAP=mix(bn,vec3(.5,.5,1.0),cover);
 ROUGHNESS=mix(clamp(1.0-texture(base_sma,UV).r,.65,1.0),.95,cover);
 METALLIC=0.0;SPECULAR=.2;
 AO=mix(texture(base_sma,UV).b,1.0,.5);
}
