// Waterfall curtain: bands of foam falling fast over the shared water palette.
// UV.y runs crest(0) -> plunge(1); world-x/z noise decorrelates the columns so
// side-by-side falls never read as one repeating sheet.
shader_type spatial;
render_mode specular_schlick_ggx, cull_disabled, depth_draw_always;

uniform vec3 color_deep : source_color = vec3(0.13, 0.46, 0.44);
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 0.98);
uniform float fall_speed : hint_range(0.5, 8.0) = 2.6;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float col = texture(noise_tex, vec2((world_pos.x + world_pos.z) * 0.11, 0.0)).r;
	float fall = texture(noise_tex, vec2((world_pos.x + world_pos.z) * 0.07,
			UV.y * 0.6 - TIME * fall_speed * 0.25 + col)).r;
	float band = smoothstep(0.35, 0.75, fall);
	// Crest and plunge whiten (the lip curls over; the base churns).
	float ends = max(smoothstep(0.25, 0.0, UV.y), smoothstep(0.75, 1.0, UV.y));
	ALBEDO = mix(color_deep, foam_color, clamp(0.35 + 0.6 * band + 0.3 * ends, 0.0, 1.0));
	ALPHA = 0.82 + 0.13 * band;
	ROUGHNESS = 0.35;
}
