shader_type spatial;
// Shared foliage material: KayKit palette texture × per-instance biome tint (MultiMesh COLOR).
uniform sampler2D albedo_tex : source_color;

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb * COLOR.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
