// Damped wave-equation ripple sim (RG = height, velocity, 0.5-centred).
// Two SubViewports ping-pong this shader (WaterRippleSim.gd); `shift_texels`
// re-centres the domain as the player moves so rings stay world-anchored.
// Technique after CBerry22's Godot water ripple simulation.
shader_type canvas_item;

uniform sampler2D prev_tex : repeat_disable, filter_linear;
uniform vec2 tex_size = vec2(256.0);
uniform vec2 shift_texels = vec2(0.0);
uniform float damping : hint_range(0.9, 1.0) = 0.985;
uniform float wave_c : hint_range(0.0, 0.6) = 0.28;
// Impulses: xy = uv, z = strength (0 = unused), w = radius in uv.
uniform vec4 drop_a = vec4(-1.0, -1.0, 0.0, 0.01);
uniform vec4 drop_b = vec4(-1.0, -1.0, 0.0, 0.01);
uniform vec4 drop_c = vec4(-1.0, -1.0, 0.0, 0.01);

void fragment() {
	vec2 px = 1.0 / tex_size;
	vec2 uv = UV + shift_texels * px;
	vec2 hv = texture(prev_tex, uv).rg - vec2(0.5);
	float lap = (texture(prev_tex, uv + vec2(px.x, 0.0)).r - 0.5)
		+ (texture(prev_tex, uv - vec2(px.x, 0.0)).r - 0.5)
		+ (texture(prev_tex, uv + vec2(0.0, px.y)).r - 0.5)
		+ (texture(prev_tex, uv - vec2(0.0, px.y)).r - 0.5)
		- 4.0 * hv.x;
	float v = (hv.y + wave_c * lap) * damping;
	float h = (hv.x + v) * damping;
	vec4 drops[3] = vec4[3](drop_a, drop_b, drop_c);
	for (int i = 0; i < 3; i++) {
		if (drops[i].z != 0.0) {
			float d = distance(UV, drops[i].xy);
			h += drops[i].z * exp(-d * d / max(drops[i].w * drops[i].w, 0.000001));
		}
	}
	// Hold the border at rest so domain shifts never smear rings.
	float edge = smoothstep(0.0, 0.04, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)));
	h *= edge;
	v *= edge;
	COLOR = vec4(h + 0.5, v + 0.5, 0.0, 1.0);
}
