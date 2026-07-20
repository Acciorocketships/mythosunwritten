shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 green_target : source_color = vec3(1.0, 0.28, 0.70);

void fragment() {
	vec4 sampled = texture(albedo_texture, UV);
	// Remap only foliage-like green texels. Brown bark and neutral atlas
	// regions remain authored; per-instance biome tint still multiplies the
	// resolved base colour through COLOR.
	if (sampled.g > sampled.r * 1.08 && sampled.g > sampled.b * 1.08) {
		float value = max(sampled.r, max(sampled.g, sampled.b));
		sampled.rgb = green_target * value;
	}
	ALBEDO = sampled.rgb * COLOR.rgb;
	ALPHA = sampled.a * COLOR.a;
	ROUGHNESS = 0.8;
}
