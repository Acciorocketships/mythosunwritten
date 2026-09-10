shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec3 glow_color : source_color = vec3(0.33, 0.92, 1.0);
uniform float phase = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float halo = exp(-r * r * 5.5) * (1.0 - smoothstep(0.65, 1.0, r));
	float core = exp(-r * r * 95.0);
	float pulse = 0.88 + 0.12 * sin(TIME * 1.3 + phase);
	ALBEDO = vec3(0.0);
	EMISSION = (glow_color * halo * 1.3 + mix(glow_color, vec3(1.0), 0.75) * core * 5.0) * pulse;
	ALPHA = halo;
}
