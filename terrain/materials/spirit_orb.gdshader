shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 glow_color : source_color = vec4(1.0);
varying vec4 orb_color;
void vertex() {
	orb_color = COLOR * glow_color;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float halo = exp(-r*r*5.5) * (1.0-smoothstep(0.6,1.0,r));
	ALBEDO = orb_color.rgb * 1.25;
	ALPHA = halo * 0.72;
}
