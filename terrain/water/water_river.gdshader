// Flowing water for river ribbons. Flow direction comes from the mesh: the
// builder writes the downstream tangent into CUSTOM0.xyz and the local
// steepness into CUSTOM0.w — no baked flow maps (the waterways-net idea,
// GDScript pipeline). Dual-phase scrolling hides the texture reset; steep
// reaches whiten into rapids foam.
// cull_disabled: the player swims and looks up at the surface from below.
shader_type spatial;
render_mode specular_schlick_ggx, depth_draw_always, cull_disabled;

#include "res://terrain/water/water_common.gdshaderinc"

uniform vec3 color_deep : source_color = vec3(0.12, 0.45, 0.55);
uniform vec3 color_shallow : source_color = vec3(0.32, 0.66, 0.69);
uniform vec3 foam_color : source_color = vec3(0.93, 0.97, 1.0);
uniform float foam_width : hint_range(0.0, 3.0) = 0.4;
uniform float depth_fade : hint_range(0.5, 8.0) = 1.8;
uniform float wave_height : hint_range(0.0, 0.6) = 0.06;   // rivers barely swell
uniform float wave_speed : hint_range(0.0, 4.0) = 0.8;
uniform float flow_speed : hint_range(0.0, 12.0) = 3.0;    // metres/second scroll
uniform float roughness : hint_range(0.0, 1.0) = 0.08;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

varying vec3 world_pos;
varying vec3 flow_dir;     // downstream, world space, unit XZ
varying float steepness;   // 0 calm .. 1 waterfall-ish

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	flow_dir = CUSTOM0.xyz;
	steepness = CUSTOM0.w;
	float t = TIME * wave_speed;
	float h = water_wave_h(noise_tex, world_pos.xz, t);
	VERTEX.y += h * wave_height;
	world_pos.y += h * wave_height;
}

void fragment() {
	float t = TIME * wave_speed;
	// Dual-phase flow scroll: two copies of the noise slide downstream half a
	// period apart; a triangle-wave blend swaps them before either visibly
	// resets. Classic no-flow-map river trick.
	vec2 fl = flow_dir.xz * flow_speed;
	float ph = fract(TIME * 0.5);
	vec2 uv = world_pos.xz * 0.09;
	float n1 = texture(noise_tex, uv - fl * ph * 0.09).r;
	float n2 = texture(noise_tex, uv - fl * (ph - 0.5) * 0.09).r;
	float stream = mix(n1, n2, abs(ph * 2.0 - 1.0));
	// Streak the normal along the flow so highlights read as moving water.
	vec3 n = normalize(vec3((stream - 0.5) * 0.35 * flow_dir.x, 1.0, (stream - 0.5) * 0.35 * flow_dir.z));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;

	float depth = water_depth_world(depth_texture, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, world_pos.y);
	float depth_t = clamp(depth / depth_fade, 0.0, 1.0);
	vec3 base = mix(color_shallow, color_deep, depth_t);
	float foam = water_foam_mask(noise_tex, world_pos.xz, t, depth, foam_width);
	// Rapids: steep reaches churn white streaks, scrolled by the stream noise.
	// Noise-gated (not a flat add) so even a waterfall keeps blue between the
	// streaks — a flat 0.55+ add saturated whole mountain ribbons solid white.
	foam += steepness * smoothstep(0.45, 0.75, stream) * 0.8;
	foam = clamp(foam, 0.0, 0.9);
	ALBEDO = mix(base, foam_color, foam);
	ALPHA = max(mix(0.65, 0.9, depth_t), foam * 0.95);
	ROUGHNESS = mix(roughness, 0.5, foam);
	SPECULAR = 0.7;
}
