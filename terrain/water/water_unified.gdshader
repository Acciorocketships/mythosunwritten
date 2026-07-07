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

// CLEAR teal water (owner's reference image): the body is the REFRACTED
// scene tinted by depth — shallow shows the bed through clean green glass,
// deep saturates to a rich teal; the foam lap line hugs the baked shoreline.
uniform vec3 color_deep : source_color = vec3(0.13, 0.46, 0.44);
uniform vec3 color_shallow : source_color = vec3(0.50, 0.78, 0.68);
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 0.98);
uniform float foam_width : hint_range(0.0, 3.0) = 0.5;
uniform float clarity_depth : hint_range(0.5, 12.0) = 6.0;   // metres to ~deep colour
uniform float refraction_strength : hint_range(0.0, 0.2) = 0.05;
uniform float wave_height : hint_range(0.0, 0.6) = 0.28;
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
	// MOVING SWELLS carry the motion everywhere — slightly deeper on flowing
	// reaches, faded near the shoreline so the buried waterline edge never
	// bobs above its bank (rim quads poking over plateau tops read as water
	// plates flashing on dry land). Chop (travelling crest geometry) is
	// reserved for genuinely steep reaches and dies with the builder's flow
	// fade at shores.
	float amp = wave_height * (1.0 + 0.35 * ff) * (1.0 - 0.7 * smoothstep(0.3, 0.9, shore_v));
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
	float fs = clamp(length(flow_v.xz), 0.0, 1.0);
	vec2 fdir = fs > 0.001 ? normalize(flow_v.xz) : vec2(1.0, 0.0);
	float scroll = flow_speed * (1.0 + rapids_boost * steep_v);
	float ff = smoothstep(0.08, 0.5, fs);   // see vertex(): flow-visibility gate

	// Soft isotropic shimmer: a gentle base drift keeps STILL water alive
	// (advecting by flow alone froze every pond's ripple detail solid —
	// owner: "they aren't even moving"), and flow adds downstream advection.
	vec2 drift = (fdir * (0.35 + 0.08 * scroll) * ff + vec2(0.055, -0.042)) * TIME;
	float rn = texture(noise_tex, world_pos.xz * 0.045 - drift).r;
	vec3 n = still_normal;
	n.xz += (rn - 0.5) * 0.10;
	n = normalize(n);
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
	vec3 body = mix(scene * mix(vec3(1.0), color_shallow, 0.35), color_deep, depth_t);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 5.0);
	body = mix(body, color_deep, fres * 0.6);
	float foam = water_foam_mask(noise_tex, world_pos.xz, t, depth, shore_v, foam_width);
	// White water only where the river is genuinely waterfall-steep — a soft
	// breathing wash, never the streak bands (owner: "moving water shouldn't
	// have white streaks in it").
	foam += smoothstep(0.75, 1.0, steep_v) * (0.25 + 0.2 * sin(TIME * 2.1 + rn * 6.0)) * ff;
	foam = clamp(foam, 0.0, 0.9);
	ALBEDO = mix(body, foam_color, foam);
	// Clarity comes from REFRACTION, not alpha blending; the ALPHA write
	// keeps the material in the transparent pass (screen texture needs it).
	ALPHA = 1.0;
	ROUGHNESS = mix(roughness, 0.5, foam);
	SPECULAR = mix(0.7, 1.0, fres);
}
