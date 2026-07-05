// Unified water for the whole network — lakes, rivers, and the transition
// between them are ONE material on ONE sheet. Per-vertex CUSTOM0.xyz carries
// the flow vector (zero in still water, downstream elsewhere) and CUSTOM0.w
// the local steepness; flow strength blends still-water swells into
// downstream scrolling, so a river mouth fades into its lake seamlessly.
// No baked flow maps. cull_disabled: the player swims and looks up from below.
shader_type spatial;
render_mode specular_schlick_ggx, depth_draw_always, cull_disabled;

#include "res://terrain/water/water_common.gdshaderinc"

// Pastel sage-teal palette, milky and near-opaque (owner's reference image);
// depth still tints shores lighter and drives the foam lap line.
uniform vec3 color_deep : source_color = vec3(0.30, 0.50, 0.47);
uniform vec3 color_shallow : source_color = vec3(0.56, 0.73, 0.66);
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 0.98);
uniform float foam_width : hint_range(0.0, 3.0) = 0.6;
uniform float depth_fade : hint_range(0.5, 8.0) = 1.8;
uniform float wave_height : hint_range(0.0, 0.6) = 0.15;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.8;
uniform float flow_speed : hint_range(0.0, 12.0) = 3.0;    // metres/second scroll
uniform float roughness : hint_range(0.0, 1.0) = 0.05;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
// Ripple simulation domain (WaterRippleSim feeds these each frame; the far
// default origin keeps the shader inert when no sim is running).
uniform sampler2D ripple_tex : repeat_disable, filter_linear;
uniform vec2 ripple_origin = vec2(1000000.0, 1000000.0);
uniform float ripple_size = 96.0;
uniform float ripple_strength : hint_range(0.0, 20.0) = 8.0;

varying vec3 world_pos;
varying vec3 flow_v;        // downstream, world space; length = flow strength
varying float steep_v;      // 0 calm .. 1 waterfall-ish
varying vec3 still_normal;  // analytic swell normal (still-water half)

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	flow_v = CUSTOM0.xyz;
	steep_v = CUSTOM0.w;
	float fs = clamp(length(flow_v.xz), 0.0, 1.0);
	float t = TIME * wave_speed;
	// Rivers barely swell; lakes roll. Blend by flow strength.
	float amp = wave_height * (1.0 - 0.7 * fs);
	float h = water_wave_h(noise_tex, world_pos.xz, t);
	VERTEX.y += h * amp;
	world_pos.y += h * amp;
	float e = 2.0;
	float hx = water_wave_h(noise_tex, world_pos.xz + vec2(e, 0.0), t);
	float hz = water_wave_h(noise_tex, world_pos.xz + vec2(0.0, e), t);
	still_normal = normalize(vec3((h - hx) * amp / e, 1.0, (h - hz) * amp / e));
}

void fragment() {
	float t = TIME * wave_speed;
	float fs = clamp(length(flow_v.xz), 0.0, 1.0);
	vec2 fdir = fs > 0.001 ? normalize(flow_v.xz) : vec2(0.0);

	// Dual-phase downstream scroll with a SPATIALLY DITHERED phase: each
	// region resets at a different moment, so the reblend never reads as a
	// global "video cut" pulse across the surface.
	vec2 fl = fdir * flow_speed;
	float ph = fract(TIME * 0.5 + texture(noise_tex, world_pos.xz * 0.017).r);
	vec2 uv = world_pos.xz * 0.09;
	float n1 = texture(noise_tex, uv - fl * ph * 0.09).r;
	float n2 = texture(noise_tex, uv - fl * (ph - 0.5) * 0.09).r;
	float stream = mix(n1, n2, abs(ph * 2.0 - 1.0));
	vec3 flow_n = normalize(vec3(
		(stream - 0.5) * 0.35 * fdir.x, 1.0, (stream - 0.5) * 0.35 * fdir.y));
	vec3 n = normalize(mix(still_normal, flow_n, fs));

	// Interactive ripples: sample the wave-sim height gradient inside the
	// player-following domain (swim wakes + ambient droplets), fading at the
	// domain border.
	vec2 ruv = (world_pos.xz - ripple_origin) / ripple_size;
	if (ruv.x > 0.0 && ruv.y > 0.0 && ruv.x < 1.0 && ruv.y < 1.0) {
		float rp = 1.0 / 256.0;
		float hl = texture(ripple_tex, ruv - vec2(rp, 0.0)).r;
		float hr = texture(ripple_tex, ruv + vec2(rp, 0.0)).r;
		float hd = texture(ripple_tex, ruv - vec2(0.0, rp)).r;
		float hu = texture(ripple_tex, ruv + vec2(0.0, rp)).r;
		// Fade wider than the sim's own rest band, so border texels (where
		// shift discontinuities live) never contribute visible normals.
		float edge = smoothstep(0.0, 0.12,
			min(min(ruv.x, 1.0 - ruv.x), min(ruv.y, 1.0 - ruv.y)));
		vec2 grad = vec2(hr - hl, hu - hd) * ripple_strength * edge;
		n = normalize(n + vec3(-grad.x, 0.0, -grad.y));
	}
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;

	float depth = water_depth_world(depth_texture, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, world_pos.y);
	float depth_t = clamp(depth / depth_fade, 0.0, 1.0);
	vec3 base = mix(color_shallow, color_deep, depth_t);
	float foam = water_foam_mask(noise_tex, world_pos.xz, t, depth, foam_width);
	// Rapids: noise-gated white streaks on steep flowing reaches — never a
	// flat add (that saturates whole mountain rivers solid white).
	foam += steep_v * smoothstep(0.45, 0.75, stream) * 0.8 * fs;
	foam = clamp(foam, 0.0, 0.9);
	ALBEDO = mix(base, foam_color, foam);
	// Milky, near-opaque body (reference look) — shores stay a touch clearer.
	ALPHA = max(mix(0.82, 0.96, depth_t), foam * 0.97);
	ROUGHNESS = mix(roughness, 0.5, foam);
	SPECULAR = 0.7;
}
