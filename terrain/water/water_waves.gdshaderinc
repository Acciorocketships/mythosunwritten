// r3 Task 8 — the SINGLE wave-constants table. water_unified.gdshader's
// vertex() (displacement) and fragment() (shading-detail gradient) both
// #include this file and call the SAME two height functions below — no
// wave math is duplicated between the two stages. GDScript cannot #include
// a .gdshaderinc, so the CPU mirror (characters/character.gd _swell_offset)
// copies these constants BY NAME instead: the pond spectrum is already
// mirrored there (verbatim, see water_wave_h's own comment below); the
// river-train mirror is r3 Task 9's own deliverable, reading the ten names
// listed here.
//
// Mirror block (name = value — the copy-paste source for the GDScript
// mirror; keep this list and the `const` block right below it in sync if
// either ever changes):
//   RIVER_K1            = 1.9
//   RIVER_K2             = 3.4
//   RIVER_SPEED1          = 2.6
//   RIVER_SPEED2           = 3.8
//   RIVER_AMP_BASE          = 0.055
//   RIVER_AMP_SLOPE_GAIN     = 2.4
//   RIVER_CROSS_RAD          = 0.31
//   PLUNGE_RING_K            = 2.2
//   PLUNGE_RING_SPEED        = 3.1
//   PLUNGE_RING_AMP          = 0.10

// River trains (s = CUSTOM0.x, d = CUSTOM0.y, slope = CUSTOM0.z, shore =
// CUSTOM0.w — see WaterSkin._flow_frame_at's own docstring for the bake).
// Values are OWNER-APPROVED (round-3 plan Task 8) — do not retune.
const float RIVER_K1 = 1.9;        // λ≈3.3 m primary train
const float RIVER_K2 = 3.4;        // λ≈1.8 m crossed train (steep only)
const float RIVER_SPEED1 = 2.6;    // m/s downstream
const float RIVER_SPEED2 = 3.8;
const float RIVER_AMP_BASE = 0.055;
const float RIVER_AMP_SLOPE_GAIN = 2.4;   // A = BASE*(1+GAIN*slope)
const float RIVER_CROSS_RAD = 0.31;       // ~18 deg cross angle for train 2
const float PLUNGE_RING_K = 2.2;
const float PLUNGE_RING_SPEED = 3.1;
const float PLUNGE_RING_AMP = 0.10;       // fades away from a steep span (see water_river_h)


// ---- Pond spectrum -------------------------------------------------------
// TRAVELLING swells: two long waves carry the large rise/fall, three mid
// rollers make the surface visibly bumpy, all at SLOW phase speeds (~0.6-1
// m/s with the default wave_speed) — swells ARE the water's motion (the
// owner: low frequency, high amplitude; anything faster reads as the world
// in fast-forward). Pure function of world position — seamless across chunk
// meshes. The character's _swell_offset mirrors the WHOLE sum exactly on
// CPU (envelopes included): keep in sync.
//
// EXISTING five travelling sines, relocated here VERBATIM from the
// pre-Task-8 water_common.gdshaderinc (byte-identical constants and
// formula — owner-approved, not retuned; the unused `noise_tex` parameter
// is kept for the same reason: this function is a straight cut/paste, not a
// rewrite). Two LONG swells (λ~140/205m) carry the large rise and fall;
// three MID waves (λ~39/27/18m, distinct headings) are the visible rollers
// that make the surface bumpy inside one screen. The two big mid waves ride
// slow TRAVELLING sine envelopes (λ~89m): amplitude varies place to place
// and moment to moment — randomness via beat patterns, yet exactly
// CPU-mirrorable (characters/character.gd _swell_offset — KEEP IN SYNC).
float water_wave_h(sampler2D noise_tex, vec2 p, float t) {
	float h = 0.9 * sin(dot(p, vec2(0.042, 0.016)) - t * 0.33);
	h += 0.55 * sin(dot(p, vec2(-0.023, 0.037)) - t * 0.26 + 1.7);
	float e1 = 0.75 + 0.45 * sin(dot(p, vec2(0.052, 0.048)) - t * 0.21 + 0.9);
	float e2 = 0.75 + 0.45 * sin(dot(p, vec2(-0.061, 0.036)) - t * 0.24 + 3.4);
	h += 0.5 * e1 * sin(dot(p, vec2(0.118, -0.112)) - t * 2.85 + 2.1);
	h += 0.34 * e2 * sin(dot(p, vec2(-0.15, 0.178)) - t * 3.1 + 4.6);
	h += 0.22 * sin(dot(p, vec2(0.27, 0.208)) - t * 3.45 + 1.3);
	return h * 0.5;
}


// ---- River trains + plunge rings -----------------------------------------
// A river's downstream motion is two crest-free sine TRAINS advected along
// the channel's own curvilinear (s, d) frame — CUSTOM0 no longer carries a
// flow VECTOR (Task 6/7 replaced the old flow.xyz/steep_v layout), so
// motion direction comes from arc length (s) and cross distance (d)
// instead of a world-space heading. train1 always rides the channel at
// RIVER_AMP_BASE and gains amplitude with slope; train2 is a second,
// ~18-degree-crossed train gated on past FALLS/rapids only (slope in
// [0.15, 0.45]) — a second train everywhere read as "mini-ripples
// everywhere", which is exactly what the owner rejected about the old
// per-cell chop.
//
// river_present is NOT decorative. WaterSkin bakes s=d=slope=0.0 IDENTICALLY
// at every vertex more than RIVER_MAX_DIST(18m) from any trace (its own
// literal "calm" rule — see _flow_frame_at) — every such vertex, pond or
// lake, shares the EXACT same (0, 0, 0) frame. Without a gate, train1's
// slope-independent RIVER_AMP_BASE floor would then evaluate to the SAME
// sin(-RIVER_SPEED1*RIVER_K1*t) at every one of those vertices simultaneously
// (same phase, since s is pinned to the same 0.0 everywhere) — an entire
// lake rising and falling together as one rigid plate instead of staying
// inert. train2 and the plunge ring already self-gate on slope, which
// happens to cover their own pond case too, but river_present is applied
// once to the whole function as a single, explicit safety net rather than
// three separate implicit ones.
//
// Plunge rings: no baked proximity-to-a-steep-span-base stream exists, and
// this task deliberately does NOT add one (a "how far downstream of the
// nearest fall's base" scalar would be a new per-vertex stream — see
// r3-task-8-report.md's own judgment-call note on this exact point).
// Approximated train-based instead: a d-keyed radial-ish ripple gated on
// slope > 0.3 (a plunge pool's own profile slope tapers down from the fall
// above it through this exact band before levelling to a calm reach), so
// the ring reads as "just past a steep drop" without any new geometry.
float water_river_h(float s, float d, float slope, float t) {
	float river_present = smoothstep(0.0, 0.03, abs(s) + abs(d));
	// CUSTOM0.z (slope) is intentionally UNCLAMPED at the bake (WaterSkin —
	// real waterfall reaches read well past 1.0); clamp only the LOCAL
	// amplitude-gain input so one outlier vertex can't spike a train's
	// height far past every other constant's own scale. The named
	// RIVER_* constants themselves are untouched.
	float slope_amp = clamp(slope, 0.0, 2.0);
	float amp = RIVER_AMP_BASE * (1.0 + RIVER_AMP_SLOPE_GAIN * slope_amp);
	float h = amp * sin(RIVER_K1 * s - RIVER_SPEED1 * RIVER_K1 * t);
	float gate2 = smoothstep(0.15, 0.45, slope);
	float phase2 = RIVER_K2 * (s * cos(RIVER_CROSS_RAD) + d * sin(RIVER_CROSS_RAD))
			- RIVER_SPEED2 * RIVER_K2 * t;
	h += gate2 * amp * sin(phase2);
	float ring_gate = smoothstep(0.3, 0.5, slope);
	h += ring_gate * PLUNGE_RING_AMP * sin(PLUNGE_RING_K * abs(d) - PLUNGE_RING_SPEED * t);
	return h * river_present;
}
