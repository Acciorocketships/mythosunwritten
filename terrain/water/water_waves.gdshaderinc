// r3 Task 8 — the SINGLE wave-constants table. water_unified.gdshader's
// vertex() (displacement) and fragment() (shading-detail gradient) both
// #include this file and call the SAME height function below — no wave
// math is duplicated between the two stages. GDScript cannot #include a
// .gdshaderinc, so the CPU mirror (characters/character.gd _swell_offset)
// copies the pond spectrum constants BY NAME (verbatim, see water_wave_h's
// own comment below) — keep the two in sync.
//
// r3 Task 13 (owner rewrite, 2026-07-11 verbatim): "the scroll motion
// should not have any white in it, it should be entirely clear. the only
// thing that will make it visible is changes in refraction ... also the
// distortion should slowly morph as it moves." The geometric river trains
// that used to live here (RIVER_K1/K2 vertex displacement, the
// slope-gated train2, the plunge ring — r3 Task 8/9's own deliverable)
// are DELETED wholesale: they vertex-displaced the 3 m mesh lattice at
// wavelengths (1.8/3.3 m) below its Nyquist limit, which is exactly what
// aliased into the maze/moiré pattern the owner rejected (R4-A/R5-A).
// Geometry now carries ONLY the pond swell spectrum below, everywhere
// (river and pond alike, shore-faded exactly as before) — see
// water_unified.gdshader's vertex(). ALL visible river/rapids motion
// moves to the fragment-side refraction-distortion advection instead:
// water_distort_wobble below, called from water_unified.gdshader's
// fragment(), perturbs the refraction offset ONLY (never VERTEX, never
// this file's pond height) — it needs NO character.gd mirror, so the
// float-height CPU mirror lost its river term outright (see
// character.gd's own _swell_offset — the deletion is documented there).
//
// Mirror block (name = value — the copy-paste source for the pond-only
// GDScript mirror; keep this list and the pond `const`s below in sync if
// either ever changes). The distortion constants further down have no
// CPU twin (fragment-only, never touches float height) so they are NOT
// part of this mirror block.
//   (no river constants any more — see r3-task-13-report.md for the
//   deletion inventory)


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


// ---- Refraction-distortion advection (r3 Task 13) -------------------------
// The SOLE carrier of river/rapids motion. ONE code path serves river and
// pond water alike — never an if/else on river-vs-pond — because the two
// terms below are each independently continuous and just fade into one
// another:
//   - `base` is a world-space noise coordinate (same domain, same
//     frequency the pre-Task-13 refraction wobble already sampled) that is
//     ALWAYS defined and ALWAYS continuous, everywhere, regardless of the
//     baked flow frame. This alone carries a pond's own slow drift+morph
//     (nothing about it depends on (s, d, slope)) and is what makes a
//     structural seam impossible: even in the worst case below, this term
//     never tears.
//   - `push` rides the baked curvilinear (s, d) frame (CUSTOM0.xy — arc
//     length downstream / signed cross-channel distance) so a river's
//     advection direction bends with the channel itself instead of fighting
//     a fixed world-space vector (CUSTOM0 carries no such vector — Task
//     6/7). It is weighted by `flow_gate`, a smoothstep on slope using the
//     SAME threshold the pre-Task-13 shading-gradient blend used
//     (river_gate) — i.e. already near 0 for calm reaches well before
//     WaterSkin's own s=d=slope=0 "calm" cutoff at 18 m (_flow_frame_at),
//     so the one case that COULD show a seam (a still-steep reach right at
//     that 18 m ring) is the same tolerance this codebase already ships,
//     now bounded to a fade in the smaller PUSH layer only — the base
//     layer under it never interrupts.
//
// TWO-PHASE half-offset blend (phaseA/phaseB, triangle-wave crossfade):
// `push`'s own advection is bounded to one DIST_PERIOD before it wraps
// (mod, not raw TIME) because slope varies along a river — an UNBOUNDED
// advection would shear the pattern apart faster wherever the local slope
// (hence speed) is bigger, the classic flow-map problem. Wrapping hides
// that reset by crossfading two phases offset by half a cycle: each phase's
// blend weight is a triangle wave that troughs to exactly 0 at its OWN
// reset instant (phaseA at t=0/DIST_PERIOD, phaseB exactly half a cycle
// later) and peaks at 1 at its own mid-cycle — so whichever phase is about
// to pop is invisible, and the visible one is never mid-reset.
//
// MORPH: each phase's `base` term ALSO drifts along its own fixed,
// decorrelated velocity (DIST_MORPH_VEL_A / _B — literally the two
// pre-Task-13 wobble scroll vectors, one per phase) — unlike the bounded
// `push` advection, morph is intentionally UNBOUNDED (never wrapped): a
// bounded, wrapped-only motion would still read as a rigid conveyor
// (the same tile sliding, then popping back). Two independently-drifting
// morph velocities mean the pattern the two phases sample keeps changing
// SHAPE, not just position, while it travels (the owner's own "the
// distortion should slowly morph as it moves").
//
// noise_tex is GRAYSCALE: every 2D distortion vector below is built from
// TWO offset samples (a, b), never a single sample's .rg (that would read
// one channel diagonally — see water_unified.gdshader's own uniform
// comment).
const float DIST_FREQ = 0.045;            // world-space base frequency — matches the pre-Task-13 wobble's own scale
const float DIST_DRIFT_SPEED = 0.45;      // pond/calm floor (flow_speed at slope=0) — close to the old wobble's own effective drift rate
const float DIST_FLOW_GAIN = 2.5;         // flow_speed = DIST_DRIFT_SPEED + DIST_FLOW_GAIN*clamp(slope,0,2); ~2.6 m/s at slope=1, matching the deleted RIVER_SPEED1's own scale
const float DIST_FLOW_GATE = 0.05;        // river_slope smoothstep upper bound gating the (s,d) push — same threshold the deleted shading-gradient river_gate used
const float DIST_PERIOD = 10.0;           // seconds per phase cycle before the bounded push-advection wraps
const vec2 DIST_MORPH_VEL_A = vec2(0.021, -0.017);   // phase A's own unbounded morph drift (== the pre-Task-13 wa scroll vector)
const vec2 DIST_MORPH_VEL_B = vec2(-0.019, 0.023);   // phase B's own unbounded morph drift (== the pre-Task-13 wb scroll vector) — decorrelated from A by construction
const vec2 DIST_SAMPLE_OFFSET = vec2(37.7, 11.3);    // 2nd sample's UV offset within a phase, building a 2D vector from the grayscale texture

vec2 water_distort_wobble(sampler2D noise_tex, vec2 world_xz, float s, float d, float slope, float t, float speed_mul) {
	float slope_amp = clamp(slope, 0.0, 2.0);   // slope is UNCLAMPED at the bake (real waterfalls read well past 1.0) — clamp only this local gain input, same discipline the deleted water_river_h used
	float flow_speed = (DIST_DRIFT_SPEED + DIST_FLOW_GAIN * slope_amp) * speed_mul;
	float flow_gate = smoothstep(0.0, DIST_FLOW_GATE, slope);
	vec2 base = world_xz * DIST_FREQ;

	float dist_phase = fract(t / DIST_PERIOD);
	float phaseA_adv = dist_phase * DIST_PERIOD;
	float phaseB_adv = fract(dist_phase + 0.5) * DIST_PERIOD;
	float wA = 1.0 - abs(dist_phase * 2.0 - 1.0);   // triangle wave: 0 at the reset instant, 1 at this phase's own mid-cycle
	float wB = 1.0 - wA;                            // phase B is exactly half a cycle offset, so it peaks when A resets and vice versa

	vec2 uvA = base + t * DIST_MORPH_VEL_A * speed_mul
			+ flow_gate * vec2(s - flow_speed * phaseA_adv, d) * DIST_FREQ;
	vec2 uvB = base + t * DIST_MORPH_VEL_B * speed_mul
			+ flow_gate * vec2(s - flow_speed * phaseB_adv, d) * DIST_FREQ;

	float waA = texture(noise_tex, uvA).r;
	float wbA = texture(noise_tex, uvA + DIST_SAMPLE_OFFSET).r;
	float waB = texture(noise_tex, uvB).r;
	float wbB = texture(noise_tex, uvB + DIST_SAMPLE_OFFSET).r;
	return (vec2(waA, wbA) - 0.5) * wA + (vec2(waB, wbB) - 0.5) * wB;
}
