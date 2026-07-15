// Shared ambient swell spectrum. water_unified.gdshader's vertex and
// fragment stages call this same height function; character.gd mirrors it
// for buoyancy. Flow-transported compact wavelets and the interactive ripple
// height are separate textures owned by WaterRippleSim, not procedural noise.


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
