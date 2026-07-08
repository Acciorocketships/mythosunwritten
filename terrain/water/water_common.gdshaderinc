// Shared stylized-water building blocks (ponds + rivers). Extracted from
// Water.gdshader so both surfaces keep one visual language: rolling world-
// space waves, vertical-depth tinting, animated shore foam.

// TRAVELLING swells: two long waves carry the large rise/fall, three mid
// rollers make the surface visibly bumpy, all at SLOW phase speeds (~0.6-1
// m/s with the default wave_speed) — swells ARE the water's motion (the
// owner: low frequency, high amplitude; anything faster reads as the world
// in fast-forward). Pure function of world position — seamless across chunk
// meshes. The character's _swell_offset mirrors the WHOLE sum exactly on
// CPU (envelopes included): keep in sync.
float water_wave_h(sampler2D noise_tex, vec2 p, float t) {
	// TRAVELLING sines only — every visible term MOVES (the old broad noise
	// drift read as "a swell that is not moving at all"; owner). Two LONG
	// swells (λ~140/205m) carry the large rise and fall; three MID waves
	// (λ~39/27/18m, distinct headings) are the visible rollers that make the
	// surface bumpy inside one screen (owner: "large rising and falling
	// waves... like a true water simulation"). The two big mid waves ride
	// slow TRAVELLING sine envelopes (λ~89m): amplitude varies place to
	// place and moment to moment — randomness via beat patterns, yet exactly
	// CPU-mirrorable (characters/character.gd _swell_offset — KEEP IN SYNC).
	// Mid-wave PERIODS are ~7-9s at a fixed point (t-coeffs ~3 with the
	// default wave_speed): a floating body visibly rises and falls — "the
	// boat should be rocking in the waves" (owner). Slower coefficients made
	// a surface that was bumpy in SPACE but near-static in TIME (48s bob
	// period reads frozen); these stay well under real dispersion (~4-5s),
	// so nothing reads fast-forward.
	float h = 0.9 * sin(dot(p, vec2(0.042, 0.016)) - t * 0.33);
	h += 0.55 * sin(dot(p, vec2(-0.023, 0.037)) - t * 0.26 + 1.7);
	float e1 = 0.75 + 0.45 * sin(dot(p, vec2(0.052, 0.048)) - t * 0.21 + 0.9);
	float e2 = 0.75 + 0.45 * sin(dot(p, vec2(-0.061, 0.036)) - t * 0.24 + 3.4);
	h += 0.5 * e1 * sin(dot(p, vec2(0.118, -0.112)) - t * 2.85 + 2.1);
	h += 0.34 * e2 * sin(dot(p, vec2(-0.15, 0.178)) - t * 3.1 + 4.6);
	h += 0.22 * sin(dot(p, vec2(0.27, 0.208)) - t * 3.45 + 1.3);
	return h * 0.5;
}

// View-space Z of the opaque scene point at screen uv (negative; more
// negative = farther from the camera). Lets the refraction guard reject
// FOREGROUND geometry: offsetting the screen sample onto something nearer
// than the water fragment pastes a ghost copy of it into the water.
float water_view_z(sampler2D depth_tex, vec2 uv, mat4 inv_projection) {
	float depth_raw = texture(depth_tex, uv).r;
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth_raw);
	vec4 v = inv_projection * vec4(ndc, 1.0);
	return v.z / v.w;
}

// Crest-sharpened wave trains advected downstream at `speed` (m/s): sharp
// ridges, flat troughs (1-|sin| profile), two wavelengths (~14m and ~26m),
// decorrelated by world noise so crests never read as parallel bars.
// Roughly zero-mean so the sheet's average level doesn't rise.
float water_chop_h(sampler2D noise_tex, vec2 p, vec2 fdir, float speed, float t) {
	// LONG and slow (λ ~26m / ~48m): the owner reads short crest trains as
	// "mini ripples everywhere" — surface motion must be swells, not chop.
	float along = dot(p, fdir);
	float across = dot(p, vec2(-fdir.y, fdir.x));
	float brk = textureLod(noise_tex, p * 0.03, 0.0).r;
	float w1 = 1.0 - abs(sin((along - t * speed) * 0.24 + across * 0.10 + brk * 4.0));
	float w2 = 1.0 - abs(sin((along - t * speed * 1.30) * 0.13 - across * 0.06 + brk * 2.5));
	return w1 * w1 * 0.65 + w2 * w2 * 0.35 - 0.45;
}

// VERTICAL water depth at this fragment: reconstruct the opaque scene point
// behind it and measure how far below the (displaced) water surface it sits.
float water_depth_world(sampler2D depth_tex, vec2 screen_uv, mat4 inv_projection, mat4 inv_view, float surface_world_y) {
	float depth_raw = texture(depth_tex, screen_uv).r;
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth_raw);
	vec4 scene_view = inv_projection * vec4(ndc, 1.0);
	scene_view.xyz /= scene_view.w;
	vec4 scene_world = inv_view * vec4(scene_view.xyz, 1.0);
	return max(surface_world_y - scene_world.y, 0.0);
}

// Foam lap line at the SHORELINE: a noise-broken band keyed on the baked
// shore proximity (CUSTOM0.y) and pinched by vertical depth so the line hugs
// the true waterline. Depth alone is NOT the trigger — shallow mid-pond
// shelves read depth≈0 everywhere and used to flash as drifting white clouds
// (owner: "weird white stuff that randomly appears").
float water_foam_mask(sampler2D noise_tex, vec2 world_xz, float t, float depth, float shore, float foam_width) {
	float breaks = texture(noise_tex, world_xz * 0.06 + vec2(t * 0.02, -t * 0.016)).r;
	float lap = 1.0 - smoothstep(foam_width * 0.4, foam_width * (0.7 + 0.6 * breaks), depth);
	// TIGHT gate: only the waterline band itself (shore -> 1 within ~25cm of
	// the contour) laps white. A loose gate (0.45) painted every contour-cap
	// dive band and crest cell solid pale — the "detached skirt" shelves the
	// owner keeps circling are exactly those bands lit up by depth≈0 foam.
	float gate = smoothstep(0.8, 1.0, shore);
	return lap * gate * (0.75 + 0.25 * sin(t * 1.6 + breaks * 6.283));
}
