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
#include "res://terrain/materials/meadow_stone.gdshaderinc"
varying vec3 world_position;
varying vec3 support_normal;
// A slope-attached rock is set into the slope sheet or terrain it meets
// (INSTANCE_CUSTOM: that surface's plane normal xz, plane offset and moss
// grade; COLOR: its lawn tint and rock exposure). At the contact the rock is
// that surface's own colour (owner, September 27 judging: a mossy rock against
// bare bedrock showed a hard seam; at its edges a rock must be the colour of
// the mountain around it), blending into its own over base_blend metres of
// height above the surface plane. Only that contact band: above it the rock
// keeps its stone sides and Meadow grass tops (coordinator review: a wider
// band turned low rocks on a lawn slope into lawn-coloured humps).
varying float contact_height;
varying float support_grade;
uniform float base_blend = .3;
// Over bare stone the grass top layer keeps off the rock's lower edge_fade
// metres (above the base band), so its edges stay the surrounding stone.
uniform float edge_fade = 1.0;
// Meadow's authored rock + terrain-grass top layer. No slope-distance halo.
uniform sampler2D base_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D base_sma : filter_linear_mipmap, repeat_enable;
// Meadow's top-layer rule on the world normal: full grass up to about 50
// degrees from level, none on sides steeper than about 65 degrees.
uniform float top_offset = .4;
uniform float top_contrast = 10.0;
varying vec3 world_normal;
varying vec3 world_tangent;
varying vec3 world_binormal;
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 support_normal=slope_attachment?vec3(INSTANCE_CUSTOM.x,sqrt(max(0.0,1.0-INSTANCE_CUSTOM.x*INSTANCE_CUSTOM.x-INSTANCE_CUSTOM.y*INSTANCE_CUSTOM.y)),INSTANCE_CUSTOM.y):vec3(0,1,0);
 contact_height=slope_attachment?dot(world_position,support_normal)-INSTANCE_CUSTOM.z:1e3;
 support_grade=slope_attachment?INSTANCE_CUSTOM.w:0.0;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 world_tangent=normalize(mat3(MODEL_MATRIX)*TANGENT);
 world_binormal=normalize(mat3(MODEL_MATRIX)*BINORMAL);
}
void fragment(){
 vec3 bn=texture(base_normal,UV).rgb;
 vec3 tangent_n=vec3(bn.xy*2.0-1.0,0.0);
 tangent_n.z=sqrt(max(0.0,1.0-dot(tangent_n.xy,tangent_n.xy)));
 vec3 wn=normalize(world_tangent*tangent_n.x+world_binormal*tangent_n.y+world_normal*tangent_n.z);
 vec3 n=normalize(support_normal);
 // The surface the rock is set into, exactly as the bedrock sheet draws it
 // here: lawn/moss, broken by bare Meadow stone where its rock is exposed.
 // An unattached rock stands on level ground: always turf.
 vec3 lawn=slope_green_grade(world_position,n,COLOR.rgb,28.0*support_grade,support_grade);
 float bare=bedrock_bare(world_position,COLOR.a)*(1.0-bedrock_tread(world_position,n.y));
 vec3 surface=mix(lawn,bedrock_stone(world_position,n),bare);
 // Meadow's grass top layer where that surface grows turf; over bare stone
 // only on the rock's own level treads, and never down at its edges.
 float top=clamp(pow(max(wn.y,0.0)+top_offset,top_contrast),0.0,1.0);
 top=mix(top,bedrock_tread(world_position,wn.y)*smoothstep(base_blend,base_blend+edge_fade,contact_height),bare);
 vec3 rock=mix(meadow_stone(texture(base_albedo,UV).rgb),lawn,top);
 float base=1.0-smoothstep(0.0,base_blend,contact_height);
 ALBEDO=mix(rock,surface,base);
 // Turf and the surrounding surface light like the terrain and sheet do
 // (fully rough, no specular); the stone keeps its authored response. At
 // the contact the rock also takes the surface's lighting normal, as its
 // ground skirt does.
 NORMAL=normalize(mix(NORMAL,(VIEW_MATRIX*vec4(n,0.0)).xyz,base));
 float cover=max(top,base);
 NORMAL_MAP=mix(bn,vec3(.5,.5,1.0),cover);
 ROUGHNESS=mix(clamp(1.0-texture(base_sma,UV).r,.65,1.0),1.0,cover);
 METALLIC=0.0;SPECULAR=mix(.2,0.0,cover);
 AO=mix(texture(base_sma,UV).b,1.0,.5);
}
