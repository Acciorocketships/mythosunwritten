// Unified water for the whole network — lakes, rivers, and the transition
// between them are ONE material on ONE sheet. Per-vertex CUSTOM0.xyz carries
// the flow vector (zero in still water, downstream elsewhere) and CUSTOM0.w
// the local steepness; flow strength blends still-water swells into
// downstream scrolling, so a river mouth fades into its lake seamlessly.
// No baked flow maps. cull_disabled: the player swims and looks up from below.
shader_type spatial;
render_mode specular_schlick_ggx, depth_draw_always, cull_disabled;

#include "res://terrain/water/water_common.gdshaderinc"

// CLEAR teal water (owner's reference image): the body is the REFRACTED
// scene tinted by depth — shallow shows the bed through clean green glass,
// deep saturates to a rich teal; depth still drives the foam lap line.
uniform vec3 color_deep : source_color = vec3(0.13, 0.46, 0.44);
uniform vec3 color_shallow : source_color = vec3(0.50, 0.78, 0.68);
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 0.98);
uniform float foam_width : hint_range(0.0, 3.0) = 0.6;
uniform float clarity_depth : hint_range(0.5, 12.0) = 5.0;   // metres to ~deep colour
uniform float refraction_strength : hint_range(0.0, 0.2) = 0.05;
uniform float wave_height : hint_range(0.0, 0.6) = 0.15;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.8;
// Calm-reach scroll. Speed lives WHERE THE RIVER IS STEEP (rapids_boost x
// steep_v), never in a global playback rate — a raised base rate reads as
// the whole world running in fast-forward (owner regression report).
uniform float flow_speed : hint_range(0.0, 12.0) = 3.0;    // metres/second scroll
uniform float rapids_boost : hint_range(0.0, 4.0) = 1.5;   // extra scroll at steep_v=1
uniform float chop_height : hint_range(0.0, 0.6) = 0.35;   // travelling crest amplitude
uniform float roughness : hint_range(0.0, 1.0) = 0.03;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
// Ripple simulation domain (WaterRippleSim feeds these each frame; the far
// default origin keeps the shader inert when no sim is running).
uniform sampler2D ripple_tex : repeat_disable, filter_linear;
uniform vec2 ripple_origin = vec2(1000000.0, 1000000.0);
uniform float ripple_size = 96.0;
uniform float ripple_strength : hint_range(0.0, 20.0) = 8.0;

varying vec3 world_pos;
varying vec3 flow_v;        // downstream, world space; length = flow strength
varying float steep_v;      // 0 calm .. 1 waterfall-ish
varying vec3 still_normal;  // analytic swell+chop normal from the vertex pass

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	flow_v = CUSTOM0.xyz;
	steep_v = CUSTOM0.w;
	float fs = clamp(length(flow_v.xz), 0.0, 1.0);
	vec2 fdir = fs > 0.001 ? normalize(flow_v.xz) : vec2(1.0, 0.0);
	float t = TIME * wave_speed;
	float scroll = flow_speed * (1.0 + rapids_boost * steep_v);
	// Flow-visibility gate: shore damping + corner averaging cap mid-channel
	// flow around 0.3-0.5 in NARROW rivers (most rivers), so effects keyed
	// linearly on fs never appear. Saturate by 0.5: real channels read fully
	// flowing, while the fade to zero at shores/lakes is preserved.
	float ff = smoothstep(0.08, 0.5, fs);
	// Rivers barely swell; lakes roll. REAL chop (travelling crest geometry)
	// replaces swell as flow rises, and dies with the builder's flow fade at
	// shores — the buried waterline edge never bobs above the banks.
	float amp = wave_height * (1.0 - 0.7 * ff);
	float camp = chop_height * ff * (0.55 + 0.45 * steep_v);
	float e = 2.0;
	float h = water_wave_h(noise_tex, world_pos.xz, t) * amp
		+ water_chop_h(noise_tex, world_pos.xz, fdir, scroll, TIME) * camp;
	float hx = water_wave_h(noise_tex, world_pos.xz + vec2(e, 0.0), t) * amp
		+ water_chop_h(noise_tex, world_pos.xz + vec2(e, 0.0), fdir, scroll, TIME) * camp;
	float hz = water_wave_h(noise_tex, world_pos.xz + vec2(0.0, e), t) * amp
		+ water_chop_h(noise_tex, world_pos.xz + vec2(0.0, e), fdir, scroll, TIME) * camp;
	VERTEX.y += h;
	world_pos.y += h;
	still_normal = normalize(vec3((h - hx) / e, 1.0, (h - hz) / e));
}

void fragment() {
	float t = TIME * wave_speed;
	float fs = clamp(length(flow_v.xz), 0.0, 1.0);
	vec2 fdir = fs > 0.001 ? normalize(flow_v.xz) : vec2(1.0, 0.0);
	float scroll = flow_speed * (1.0 + rapids_boost * steep_v);
	float ff = smoothstep(0.08, 0.5, fs);   // see vertex(): flow-visibility gate

	// Dual-phase downstream scroll with a SPATIALLY DITHERED phase: each
	// region resets at a different moment, so the reblend never reads as a
	// global "video cut" pulse across the surface. Fast water samples in a
	// flow-aligned basis stretched along-flow: ripples elongate into streaks.
	vec2 fuv = vec2(dot(world_pos.xz, fdir), dot(world_pos.xz, vec2(-fdir.y, fdir.x)));
	vec2 uvscale = mix(vec2(0.09), vec2(0.045, 0.13), ff);
	float ph = fract(TIME * 0.5 + texture(noise_tex, world_pos.xz * 0.017).r);
	float n1 = texture(noise_tex, fuv * uvscale - vec2(scroll * ph * uvscale.x, 0.0)).r;
	float n2 = texture(noise_tex, fuv * uvscale - vec2(scroll * (ph - 0.5) * uvscale.x, 0.0)).r;
	float stream = mix(n1, n2, abs(ph * 2.0 - 1.0));
	// Detail perturbation rides ON TOP of the vertex normal (which already
	// carries the chop geometry) instead of replacing it.
	vec3 n = still_normal;
	n.xz += (stream - 0.5) * 0.35 * fdir * ff;
	n = normalize(n);

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
	float depth_t = 1.0 - exp(-depth / clarity_depth);
	// Refraction: offset the screen sample by the view-space normal, fading
	// in over the first metre (shores don't smear). If the offset lands on
	// geometry ABOVE the surface (a bank, the player), fall back to straight —
	// dry things must never bleed into the water body.
	vec2 roff = NORMAL.xy * refraction_strength * clamp(depth, 0.0, 1.0);
	vec2 suv = SCREEN_UV + roff;
	if (water_depth_world(depth_texture, suv, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, world_pos.y) <= 0.0) {
		suv = SCREEN_UV;
	}
	vec3 scene = texture(screen_texture, suv).rgb;
	// Clear body: the refracted scene through a green-glass tint, saturating
	// to the deep teal with depth; fresnel leans glancing views reflective.
	vec3 body = mix(scene * mix(vec3(1.0), color_shallow, 0.45), color_deep, depth_t);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 5.0);
	body = mix(body, color_deep, fres * 0.6);
	float foam = water_foam_mask(noise_tex, world_pos.xz, t, depth, foam_width);
	// Rapids: noise-gated white streaks on steep flowing reaches — never a
	// flat add (that saturates whole mountain rivers solid white).
	foam += steep_v * smoothstep(0.45, 0.75, stream) * 0.8 * ff;
	foam = clamp(foam, 0.0, 0.9);
	ALBEDO = mix(body, foam_color, foam);
	// Clarity comes from REFRACTION, not alpha blending; the ALPHA write
	// keeps the material in the transparent pass (screen texture needs it).
	ALPHA = 1.0;
	ROUGHNESS = mix(roughness, 0.5, foam);
	SPECULAR = mix(0.7, 1.0, fres);
}
