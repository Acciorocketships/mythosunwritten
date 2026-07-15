// Damped wave-equation ripple sim (RG = height, velocity, 0.5-centred).
// Two SubViewports ping-pong this shader (WaterRippleSim.gd); `shift_texels`
// re-centres the domain as the player moves so rings stay world-anchored.
// Technique after CBerry22's Godot water ripple simulation.
shader_type canvas_item;

uniform sampler2D prev_tex : repeat_disable, filter_linear;
uniform vec2 tex_size = vec2(256.0);
uniform vec2 shift_texels = vec2(0.0);
uniform sampler2D flow_tex : repeat_disable, filter_linear;
uniform float flow_dt = 0.016;
uniform float domain_size = 96.0;
// Slow propagation: rings that race outward read as fast-forward footage
// (owner). wave_c is the sim's c² — 0.16 ≈ 0.6 texel/frame ring speed.
uniform float damping : hint_range(0.9, 1.0) = 0.986;
uniform float wave_c : hint_range(0.0, 0.6) = 0.16;
// Impulses: xy = uv, z = strength (0 = unused), w = radius in uv.
uniform vec4 drop_a = vec4(-1.0, -1.0, 0.0, 0.01);
uniform vec4 drop_b = vec4(-1.0, -1.0, 0.0, 0.01);
uniform vec4 drop_c = vec4(-1.0, -1.0, 0.0, 0.01);
// First frames after startup output pure rest state: the viewport's initial
// BLACK texture decodes as a -0.5 bias everywhere, and every domain shift
// against a biased interior spawns a coherent straight wavefront (the long
// horizontal ripples on player movement).
uniform bool reset = false;

// Out-of-domain reads return REST STATE: after a domain shift, border texels
// would otherwise clamp-sample the old edge and drag it inward as long
// straight axis-aligned wavefronts whenever the player moves.
vec2 state_at(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec2(0.0);
	}
	return texture(tex, uv).rg - vec2(0.5);
}

void fragment() {
	// NOTE: 'return' is not allowed in fragment(); use if/else.
	if (reset) {
		COLOR = vec4(0.5, 0.5, 0.0, 1.0);
	} else {
	vec2 px = 1.0 / tex_size;
	vec2 current = texture(flow_tex, UV).rg;
	// Semi-Lagrangian backtrace: the ripple state is carried by the same
	// current that transports the persistent wave packets.
	vec2 uv = UV + shift_texels * px - current * flow_dt / domain_size;
	vec2 hv = state_at(prev_tex, uv);
	float lap = state_at(prev_tex, uv + vec2(px.x, 0.0)).x
		+ state_at(prev_tex, uv - vec2(px.x, 0.0)).x
		+ state_at(prev_tex, uv + vec2(0.0, px.y)).x
		+ state_at(prev_tex, uv - vec2(0.0, px.y)).x
		- 4.0 * hv.x;
	float v = (hv.y + wave_c * lap) * damping;
	float h = (hv.x + v) * damping;
	vec4 drops[3] = vec4[3](drop_a, drop_b, drop_c);
	for (int i = 0; i < 3; i++) {
		if (drops[i].z != 0.0) {
			float d = distance(UV, drops[i].xy);
			float impulse = drops[i].z * exp(-d * d / max(drops[i].w * drops[i].w, 0.000001));
			h += impulse;
		}
	}
	// GENTLE absorption toward the border. Hard zeroing was itself a wave
	// source: in a MOVING domain the damping gradient sweeps across the
	// field and chops it, radiating straight wavefronts along a line at
	// fixed distance from the player. A few percent per frame over a wide
	// band absorbs outgoing rings without exciting new ones; the water
	// shader's fade hides the outermost band anyway.
	float border = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float absorb = 1.0 - 0.06 * (1.0 - smoothstep(0.0, 0.15, border));
	h *= absorb;
	v *= absorb;
	// Bounded height gives WaterSkin a hard worst-case trough for bed cover.
	h = clamp(h, -0.5, 0.5);
	v = clamp(v, -0.5, 0.5);
	COLOR = vec4(h + 0.5, v + 0.5, 0.0, 1.0);
	}
}
