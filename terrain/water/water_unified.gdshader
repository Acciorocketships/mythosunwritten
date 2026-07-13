// Unified water for the whole network — lakes, rivers, and the transition
// between them are ONE material on ONE sheet. Per-vertex CUSTOM0 (r3 Task
// 6/7's flow-frame bake, see WaterSkin._flow_frame_at) carries a continuous
// curvilinear frame instead of a flow vector: .x = s (arc length downstream
// along the nearest river trace; identically 0 away from any trace), .y = d
// (signed cross-channel distance; identically 0 away from any trace), .z =
// slope (continuous profile slope, unclamped; identically 0 away from any
// trace), .w = shore_dist (distance to the nearest waterline curve point,
// clamped 0..8, valid everywhere regardless of river/pond mode). "Away from
// any trace" covers ponds/lakes AND any river vertex more than 18m from a
// trace — WaterSkin's own literal "calm" rule.
//
// r3 Task 13 (owner rewrite, supersedes Task 8's river trains): geometry
// displaces ONLY the pond swell spectrum now (water_waves.gdshaderinc's
// water_wave_h — long λ, owner-approved, shore-faded) — the geometric
// river trains that used to ride the (s, d, slope) frame are DELETED (they
// vertex-displaced the 3m mesh lattice below its Nyquist limit, aliasing
// into the maze/moiré pattern the owner rejected). ALL river/rapids motion
// now comes from the fragment-side refraction-distortion advection instead
// (water_distort_wobble, same include) — the SOLE carrier of "the water is
// moving": it perturbs the refraction offset ONLY, never ALBEDO and never
// the lighting NORMAL. ZERO albedo whitening anywhere (the owner's hardest
// rule): no foam mask, no steep wash, no streak scroll, no plunge
// whitening. The mesh also carries REAL vertex normals (Task 6: interior
// heightfield slope + meniscus rim curl) — fragment() blends those with the
// pond-spectrum wave motion instead of replacing them outright (the
// previous, now-deleted analytic-only normal ignored the rim curl entirely,
// which is why the meniscus never caught fresnel). No baked flow maps.
// cull_disabled: the player swims and looks up from below.
shader_type spatial;
render_mode specular_schlick_ggx, depth_draw_always, cull_disabled;

#include "res://terrain/water/water_common.gdshaderinc"
#include "res://terrain/water/water_waves.gdshaderinc"

// CLEAR pastel water (owner's reference image): the body is the REFRACTED
// scene tinted by depth — shallow shows the bed through clean green glass,
// deep saturates to a soft teal — and glancing views mirror a LIGHT sky
// tint (the reference's pale reflective sheen), never a dark one. The
// surface itself is SMOOTH: no noise dapple — geometric motion comes from
// the travelling pond swells (water_waves.gdshaderinc) and the interactive
// ripple sim; river/rapids motion (r3 Task 13) comes entirely from the
// refraction-distortion advection in fragment(), never from geometry.
uniform vec3 color_deep : source_color = vec3(0.33, 0.60, 0.55);
uniform vec3 color_shallow : source_color = vec3(0.55, 0.82, 0.73);
uniform vec3 color_sky : source_color = vec3(0.78, 0.90, 0.87);
uniform float sky_reflect : hint_range(0.0, 1.0) = 0.3;   // r3 round-6 clarity: 0.5 washed a milky pale-sky sheen over the body at grazing angles (hid the bed — owner's "make it clearer"); 0.3 lets the refracted bed read through while keeping the soft SoS-style reflection. Live-tuned at the clarity frame (25,8,-1128).
// r3 Task 13 round-6 clarity push (owner references: tropical clear-shallow
// shot + Sea of Solitude re-annotation) — 12.0 -> 18.0: the bed/refracted
// scene must read plainly through the body at ordinary depths, not just the
// shallows.
uniform float clarity_depth : hint_range(0.5, 24.0) = 18.0;   // metres to full deep colour
// CLEAR, not light (owner): the scene shows through with a modest tint
// floor so shallow shelves never read as bare lawn — it's the REFRACTION
// DISTORTION that makes the clear water read as water. Round-6: 0.12 ->
// 0.07 (clarity push — the floor was still reading too opaque against both
// owner references).
uniform float body_floor : hint_range(0.0, 1.0) = 0.07;
// How much the refracted scene tints toward color_shallow even at the very
// shallowest reads (the r3 Task 8 "shallow tint" clarity target) — kept as
// its own uniform (was a hardcoded 0.12 literal pre-Task-8) so the battery
// pass can live-tune it same as every other clarity param. Round-6: 0.10 ->
// 0.06.
uniform float shallow_tint : hint_range(0.0, 1.0) = 0.06;
// 0.11 (R3-B, raised from 0.09 — Task 8 deliberately held this back until
// the guard below was hardened: a stronger offset without the hardening
// would have made the ghost worse, not just more visible).
uniform float refraction_strength : hint_range(0.0, 0.2) = 0.11;
// Animated wobble on the refraction offset only (never the lighting normal):
// the see-through picture visibly swims like the reference, while the
// surface itself stays matte-smooth.
uniform float distort_anim : hint_range(0.0, 0.2) = 0.05;
// LOW frequency, HIGH amplitude, SLOW — the swells are the river's motion
// (owner). Speed changes here must be mirrored in character.gd SWELL_SPEED.
uniform float wave_height : hint_range(0.0, 1.5) = 1.0;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.26;
uniform float wobble_speed : hint_range(0.0, 2.0) = 0.5;
// Not mirror-tight: low roughness focuses the sun (and the wizard's light)
// into a huge white glare blob on the swells (owner's screenshots carry it
// at 0.07 too — soft pastel sheen wants a wider lobe).
uniform float roughness : hint_range(0.0, 1.0) = 0.12;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
// R3-B ghost fix (Task 1 verdict: REFRACTION): filter_nearest here was
// checked against Task 1's mechanism lead (linear filtering interpolating
// across the hat/water depth discontinuity) and confirmed already correct —
// this uniform has carried filter_nearest since the very first refraction
// commit (0dd49e2); depth values were never blended by this sampler. The
// residual ghost lived entirely in the fragment() guard below.
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
varying float river_s;       // CUSTOM0.x — arc length downstream; 0 away from any trace
varying float river_d;       // CUSTOM0.y — signed cross-channel distance; 0 away from any trace
varying float river_slope;   // CUSTOM0.z — continuous profile slope, unclamped; 0 away from any trace
varying float shore_dist;    // CUSTOM0.w — distance to nearest waterline curve point, clamped 0..8

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	river_s = CUSTOM0.x;
	river_d = CUSTOM0.y;
	river_slope = CUSTOM0.z;
	shore_dist = CUSTOM0.w;
	float t = TIME * wave_speed;
	// Pond spectrum, world xz, KILLED at the shoreline over a 4m band so the
	// buried waterline hem never bobs above its bank (same reasoning the
	// pre-Task-8 flow-gated amplitude used to cover, now keyed on the baked
	// shore distance instead of a flow strength that no longer exists).
	// r3 Task 13: this is the ONLY geometric displacement left — the river
	// trains that used to add here are DELETED (see water_waves.gdshaderinc's
	// own header); river motion now lives entirely in fragment()'s
	// refraction-distortion advection, never in VERTEX.
	float shore_fade = smoothstep(0.0, 4.0, shore_dist);
	float h = water_wave_h(noise_tex, world_pos.xz, t) * wave_height * shore_fade;
	VERTEX.y += h;
	world_pos.y += h;
}

void fragment() {
	float t = TIME * wave_speed;

	// Base normal: the REAL mesh normal (Task 6 bake: interior heightfield
	// slope + meniscus rim curl). vertex() never writes NORMAL, so Godot's
	// own normal-matrix transform carries the untouched per-vertex bake
	// straight through — by the time fragment() reads it here it is already
	// in VIEW space. Converted back to world space so the wave/ripple
	// perturbations below (both naturally world-space-ish) can sum into it,
	// then transformed to view space ONCE at the end — letting the mesh
	// normal breathe (instead of being wholesale overwritten by a flat-water
	// analytic normal, the pre-Task-8 bug) is what makes the meniscus rim
	// actually catch light/fresnel.
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);

	// Wave-driven shading detail: a small gradient of the SAME pond-spectrum
	// height function vertex() displaces the surface by (never generic
	// noise), so the shading visibly tracks the travelling swells — this is
	// what reads as "waveform shading" even in a still frame, and it stays
	// correct at any mesh resolution since it is evaluated per-fragment from
	// the closed form, not finite-differenced across coarse vertex spacing.
	// r3 Task 13: the river-train half of this gradient (the old grad_r,
	// cross-faded in by river_slope) is DELETED along with water_river_h
	// itself — geometry (hence this shading gradient) now carries only the
	// pond spectrum everywhere; river motion lives entirely in the
	// refraction-distortion advection below, which never touches NORMAL.
	float ep = 2.0;
	float shore_fade = smoothstep(0.0, 4.0, shore_dist);
	vec2 wp = world_pos.xz;
	float h0p = water_wave_h(noise_tex, wp, t);
	float hxp = water_wave_h(noise_tex, wp + vec2(ep, 0.0), t);
	float hzp = water_wave_h(noise_tex, wp + vec2(0.0, ep), t);
	vec2 grad = vec2(hxp - h0p, hzp - h0p) / ep * wave_height * shore_fade;
	n = normalize(n + vec3(-grad.x, 0.0, -grad.y));

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
		vec2 rgrad = vec2(hr - hl, hu - hd) * ripple_strength * edge;
		n = normalize(n + vec3(-rgrad.x, 0.0, -rgrad.y));
	}
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;

	float depth = water_depth_world(depth_texture, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, world_pos.y);
	// Body fraction: depth ramp OR the body floor — ankle-deep flood shelves
	// must still read as jade water (the grass showed straight through and
	// looked like lawn), while the first ~10cm at the rim stay clear.
	float depth_t = max(1.0 - exp(-depth / clarity_depth),
			body_floor * smoothstep(0.05, 0.55, depth));
	// Refraction wobble: r3 Task 13 — the SOLE carrier of river/rapids
	// motion now (the geometric river trains are deleted; see this shader's
	// own header and water_waves.gdshaderinc's water_distort_wobble for the
	// full two-phase/morph derivation). CUSTOM0's curvilinear (s, d, slope)
	// frame (Task 6/7) advects the distortion sampling along the channel —
	// a world-space flow vector was never baked, but the curvilinear frame
	// does not need one — while a world-space base layer keeps ponds
	// textured and drifting and guarantees the field can never seam where
	// the flow frame fades to its baked "calm" zero. Still perturbs the
	// refraction offset ONLY — never ALBEDO, never NORMAL.
	vec2 wobble = water_distort_wobble(noise_tex, world_pos.xz, river_s, river_d, river_slope, TIME, wobble_speed);
	vec2 roff = (NORMAL.xy * refraction_strength + wobble * distort_anim)
			* clamp(depth * 1.5, 0.0, 1.3) / max(1.0, -VERTEX.z * 0.08);
	vec2 suv = SCREEN_UV + roff;
	// GRADED guard: fade the offset out where it lands on geometry ABOVE the
	// surface (banks, the player) — a binary fallback drew a hard "lens edge"
	// band along every shore (owner's round-5 artifact). That graded ramp is
	// for genuinely BELOW-surface depth fading ONLY (0..0.3m shallow reads);
	// R3-B ghost fix (Task 1 verdict: REFRACTION, see progress.md "RUN 3 —
	// Task 1"): an ABOVE-surface sample must never enter the ramp even
	// fractionally, so test the unclamped signed height explicitly instead
	// of relying on water_depth_world's max(...,0.0) landing exactly on
	// smoothstep's zero (a silhouette-adjacent depth read at the character's
	// edge could nudge that clamped value into a tiny positive "depth" and
	// leak a sliver of them through — the hat ghost).
	float suv_h = water_signed_height_world(depth_texture, suv,
			INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, world_pos.y);
	float ok = suv_h < 0.0 ? 0.0 : smoothstep(0.0, 0.3, suv_h);
	// Foreground geometry (nearer than this fragment) still rejects outright:
	// ghost copies. Margin widened +0.05 -> +0.35 (R3-B): the tight margin
	// only vetoed samples unambiguously nearer than the water, leaving
	// silhouette-adjacent reads (nearer by a few cm, inside the old
	// tolerance) to fall through to the height check above at exactly the
	// pixels most likely to carry ambiguous, AA-softened depth.
	if (water_view_z(depth_texture, suv, INV_PROJECTION_MATRIX) > VERTEX.z + 0.35) {
		ok = 0.0;
	}
	suv = mix(SCREEN_UV, suv, ok);
	vec3 scene = texture(screen_texture, suv).rgb;
	// Clear body: the refracted scene through a light green-glass tint,
	// saturating toward the soft teal with depth but NEVER fully opaque —
	// the owner wants the near-shore clarity everywhere. ZERO whitening:
	// ALBEDO is this body colour and nothing else, at every depth and
	// every slope.
	vec3 body = mix(scene * mix(vec3(1.0), color_shallow, shallow_tint), color_deep, min(depth_t, 0.88));
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 5.0);
	body = mix(body, color_sky, fres * sky_reflect);
	ALBEDO = body;
	// Clarity comes from REFRACTION, not alpha blending; the ALPHA write
	// keeps the material in the transparent pass (screen texture needs it).
	ALPHA = 1.0;
	ROUGHNESS = roughness;
	SPECULAR = mix(0.35, 0.6, fres);
}
