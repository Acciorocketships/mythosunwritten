shader_type spatial;
render_mode cull_disabled;
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap_anisotropic;
void fragment() {
	vec4 leaf = texture(leaf_tex, UV);
	ALBEDO = vec3(.07, .16, .021) * (.55 + .65 * leaf.r);
	ROUGHNESS = .9;
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = .45;
	BACKLIGHT = vec3(.04, .08, .009);
}
