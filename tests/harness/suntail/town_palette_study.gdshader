shader_type spatial;
render_mode cull_disabled;
uniform sampler2D source_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D source_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D wood_grain : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 tone : source_color = vec4(1.0);
uniform bool has_normal = false;
uniform bool grain_roof = false;
uniform float relief = 1.0;
void fragment() {
	vec3 source = texture(source_albedo, UV).rgb;
	float value = dot(source, vec3(0.299, 0.587, 0.114));
	// Keep the authored grain, mortar and tile joint pattern. This study
	// changes surface families, never mesh geometry or original texture files.
	float detail = clamp(pow(value, 0.45) * 1.5, 0.12, 1.4);
	if (grain_roof) {
		vec3 grain = texture(wood_grain, UV * 3.0).rgb;
		detail *= mix(0.7, 1.15, clamp(dot(grain,vec3(0.299,0.587,0.114))*2.0,0.0,1.0));
	}
	ALBEDO = tone.rgb * detail;
	ROUGHNESS = 0.86;
	if (has_normal) {
		NORMAL_MAP = texture(source_normal, UV).rgb;
		NORMAL_MAP_DEPTH = relief;
	}
}
