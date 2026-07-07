// Unified water for the whole network — lakes, rivers, and the transition
// between them are ONE material on ONE sheet. Per-vertex CUSTOM0 carries the
// flow vector in .xz (zero in still water, downstream elsewhere), the baked
// shore proximity in .y (1 at the waterline, 0 inland — feeds the foam lap
// line) and the local steepness in .w; flow strength blends still-water
// swells into downstream scrolling, so a river mouth fades into its lake
// seamlessly. No baked flow maps. cull_disabled: the player swims and looks
// up from below.
shader_type spatial;
render_mode specular_schlick_ggx, depth_draw_always, cull_disabled;

#include "res://terrain/water/water_common.gdshaderinc"

// CLEAR pastel water (owner's reference image): the body is the REFRACTED
// scene tinted by depth — shallow shows the bed through clean green glass,
// deep saturates to a soft teal — and glancing views mirror a LIGHT sky
// tint (the reference's pale reflective sheen), never a dark one. The
// surface itself is SMOOTH: no noise dapple — motion comes entirely from
// the travelling swells and the interactive ripple sim.
uniform vec3 color_deep : source_color = vec3(0.26, 0.55, 0.52);
uniform vec3 color_shallow : source_color = vec3(0.55, 0.82, 0.73);
uniform vec3 color_sky : source_color = vec3(0.76, 0.89, 0.86);
uniform float sky_reflect : hint_range(0.0, 1.0) = 0.42;
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 0.98);
uniform float foam_width : hint_range(0.0, 3.0) = 0.3;
uniform float clarity_depth : hint_range(0.5, 24.0) = 15.0;  // metres to ~deep colour
uniform float refraction_strength : hint_range(0.0, 0.2) = 0.035;
// LOW frequency, HIGH amplitude, SLOW — the swells are the river's motion
// (owner). Speed changes here must be mirrored in character.gd SWELL_SPEED.
uniform float wave_height : hint_range(0.0, 1.5) = 0.85;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.35;
// Calm-reach scroll. Speed lives WHERE THE RIVER IS STEEP (rapids_boost x
// steep_v), never in a global playback rate — a raised base rate reads as
// the whole world running in fast-forward (owner regression report).
uniform float flow_speed : hint_range(0.0, 12.0) = 1.6;    // metres/second scroll
uniform float rapids_boost : hint_range(0.0, 4.0) = 1.2;   // extra scroll at steep_v=1
uniform float chop_height : hint_range(0.0, 0.6) = 0.25;   // travelling crest amplitude
uniform float roughness : hint_range(0.0, 1.0) = 0.02;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
// Ripple simulation domain (WaterRippleSim feeds these each frame; the far
// default origin keeps the shader inert when no sim is running). Swim wakes,
// entry splashes and ambient raindrop rings all live in this texture.
uniform sampler2D ripple_tex : repeat_disable, filter_linear;
uniform vec2 ripple_origin = vec2(1000000.0, 1000000.0);
uniform float ripple_size = 96.0;
uniform float ripple_strength : hint_range(0.0, 20.0) = 8.0;

varying vec3 world_pos;
varying vec3 flow_v;        // downstream, world space; length = flow strength
varying float steep_v;      // 0 calm .. 1 waterfall-ish
varying float shore_v;      // baked shore proximity, 1 at the waterline
varying vec3 still_normal;  // analytic swell+chop normal from the vertex pass

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	flow_v = CUSTOM0.xyz;
	steep_v = CUSTOM0.w;
	shore_v = CUSTOM0.y;
	float fs = clamp(length(flow_v.xz), 0.0, 1.0);
	vec2 fdir = fs > 0.001 ? normalize(flow_v.xz) : vec2(1.0, 0.0);
	float t = TIME * wave_speed;
	float scroll = flow_speed * (1.0 + rapids_boost * steep_v);
	// Flow-visibility gate: shore damping + corner averaging cap mid-channel
	// flow around 0.3-0.5 in NARROW rivers (most rivers), so effects keyed
	// linearly on fs never appear. Saturate by 0.5: real channels read fully
	// flowing, while the fade to zero at shores/lakes is preserved.
	float ff = smoothstep(0.08, 0.5, fs);
	// TRAVELLING SWELLS carry the motion everywhere — slightly deeper on
	// flowing reaches, KILLED at the shoreline so the buried waterline edge
	// and the waterfall crests (shore=1 there) never bob above their banks
	// or detach from the static slabs. Chop (travelling crest geometry) is
	// reserved for genuinely steep reaches and dies with the builder's flow
	// fade at shores.
	// Fade STARTS late (0.45): rivers are entirely shore-adjacent cells
	// (baked shore 0.6) and an early fade flattened all of them — the owner
	// wants big rollers mid-channel. Full kill by 0.9: waterline edges and
	// waterfall crests (shore 1.0) stay pinned to their banks and slabs.
	float amp = wave_height * (1.0 + 0.35 * ff) * (1.0 - smoothstep(0.45, 0.9, shore_v));
	float camp = chop_height * ff * steep_v * 0.6;
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

	// SMOOTH surface: the normal is the analytic swell normal plus the local
	// ripple-sim gradient — no noise dapple (its fine quasi-static lines were
	// exactly what the owner wants gone; "the surface should look smooth").
	vec3 n = still_normal;

	// Interactive ripples: sample the wave-sim height gradient inside the
	// player-following domain (swim wakes, entry splashes, raindrop rings),
	// fading at the domain border.
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
	// in over the first metre (shores don't smear). Reject offsets landing
	// on geometry ABOVE the surface (banks, the player) or NEARER than this
	// fragment (foreground headlands) — both pasted ghost copies of dry
	// things into the water (owner: "ghost image in the water").
	vec2 roff = NORMAL.xy * refraction_strength * clamp(depth, 0.0, 1.0);
	vec2 suv = SCREEN_UV + roff;
	if (water_depth_world(depth_texture, suv, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, world_pos.y) <= 0.0
			|| water_view_z(depth_texture, suv, INV_PROJECTION_MATRIX) > VERTEX.z + 0.05) {
		suv = SCREEN_UV;
	}
	vec3 scene = texture(screen_texture, suv).rgb;
	// Clear body: the refracted scene through a light green-glass tint,
	// saturating toward the soft teal with depth but NEVER fully opaque —
	// the owner wants the near-shore clarity everywhere.
	vec3 body = mix(scene * mix(vec3(1.0), color_shallow, 0.12), color_deep, min(depth_t, 0.88));
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 5.0);
	body = mix(body, color_sky, fres * sky_reflect);
	float foam = water_foam_mask(noise_tex, world_pos.xz, t, depth, shore_v, foam_width);
	// White water only where the river is genuinely waterfall-steep — a soft
	// breathing wash, never streak bands.
	float fs = clamp(length(flow_v.xz), 0.0, 1.0);
	float ff = smoothstep(0.08, 0.5, fs);
	foam += smoothstep(0.75, 1.0, steep_v)
		* (0.25 + 0.2 * sin(TIME * 2.1 + (world_pos.x + world_pos.z) * 0.37)) * ff;
	foam = clamp(foam, 0.0, 0.9);
	ALBEDO = mix(body, foam_color, foam);
	// Clarity comes from REFRACTION, not alpha blending; the ALPHA write
	// keeps the material in the transparent pass (screen texture needs it).
	ALPHA = 1.0;
	ROUGHNESS = mix(roughness, 0.5, foam);
	SPECULAR = mix(0.7, 1.0, fres);
}
