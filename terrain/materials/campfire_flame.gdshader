shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

void vertex() {
	// Camera-facing particle cards retain their authored placement scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}

void fragment() {
	float height = 1.0 - UV.y;
	float sway = sin(height * 9.0 + TIME * 5.0) * .12 * height;
	float width = mix(.85,.05,height);
	float silhouette = 1.0 - smoothstep(width * .55,width,abs(UV.x * 2.0 - 1.0 + sway));
	float fade = smoothstep(0.0,.12,height) * (1.0-smoothstep(.75,1.0,height));
	ALBEDO = COLOR.rgb * 1.25;
	ALPHA = COLOR.a * silhouette * fade;
}
