// Still water for ponds/lakes: per-chunk flat sheets at each pond's storey-
// aligned level. Same visual family as rivers via water_common.gdshaderinc.
// cull_disabled: the player swims and looks up at the surface from below.
shader_type spatial;
render_mode specular_schlick_ggx, depth_draw_always, cull_disabled;

#include "res://terrain/water/water_common.gdshaderinc"

uniform vec3 color_deep : source_color = vec3(0.12, 0.45, 0.55);
uniform vec3 color_shallow : source_color = vec3(0.32, 0.66, 0.69);
uniform vec3 foam_color : source_color = vec3(0.93, 0.97, 1.0);
uniform float foam_width : hint_range(0.0, 3.0) = 0.7;
uniform float depth_fade : hint_range(0.5, 8.0) = 1.8;
uniform float wave_height : hint_range(0.0, 0.6) = 0.17;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.8;
uniform float roughness : hint_range(0.0, 1.0) = 0.08;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float h = water_wave_h(noise_tex, world_pos.xz, t);
	VERTEX.y += h * wave_height;
	world_pos.y += h * wave_height;
	float e = 2.0;
	float hx = water_wave_h(noise_tex, world_pos.xz + vec2(e, 0.0), t);
	float hz = water_wave_h(noise_tex, world_pos.xz + vec2(0.0, e), t);
	NORMAL = normalize(vec3((h - hx) * wave_height / e, 1.0, (h - hz) * wave_height / e));
}

void fragment() {
	float t = TIME * wave_speed;
	float depth = water_depth_world(depth_texture, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, world_pos.y);
	float depth_t = clamp(depth / depth_fade, 0.0, 1.0);
	vec3 base = mix(color_shallow, color_deep, depth_t);
	float foam = clamp(water_foam_mask(noise_tex, world_pos.xz, t, depth, foam_width), 0.0, 1.0);
	ALBEDO = mix(base, foam_color, foam);
	ALPHA = max(mix(0.6, 0.9, depth_t), foam * 0.95);
	ROUGHNESS = mix(roughness, 0.5, foam);
	SPECULAR = 0.7;
}
