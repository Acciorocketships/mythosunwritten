shader_type spatial;
render_mode cull_back;
// Generic PBR adapter for native BaseMaterial3D surfaces. Original resources
// remain untouched; the controller restores them when the bubble moves away.
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, hint_default_white;
uniform sampler2D texture_normal : hint_normal;
uniform sampler2D texture_metallic : hint_default_white;
uniform sampler2D texture_roughness : hint_default_white;
uniform sampler2D texture_emission : source_color, hint_default_black;
uniform sampler2D texture_ambient_occlusion : hint_default_white;
uniform vec4 metallic_texture_channel = vec4(1.0,0.0,0.0,0.0);
uniform vec4 roughness_texture_channel = vec4(1.0,0.0,0.0,0.0);
uniform vec4 ao_texture_channel = vec4(1.0,0.0,0.0,0.0);
uniform float metallic = 0.0;
uniform float roughness = 1.0;
uniform float specular = 0.5;
uniform float normal_scale = 1.0;
uniform float ao_light_affect = 0.0;
uniform vec4 emission : source_color = vec4(0.0);
uniform float emission_energy = 1.0;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
uniform bool vertex_color_albedo = false;
uniform bool normal_enabled = false;
uniform bool emission_enabled = false;
uniform bool ao_enabled = false;
void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
}
void fragment() {
	vec4 base = texture(texture_albedo, UV) * albedo;
	if (vertex_color_albedo) { base *= COLOR; }
	ALBEDO = base.rgb;
	METALLIC = metallic * dot(texture(texture_metallic, UV), metallic_texture_channel);
	ROUGHNESS = roughness * dot(texture(texture_roughness, UV), roughness_texture_channel);
	SPECULAR = specular;
	if (normal_enabled) { NORMAL_MAP = texture(texture_normal, UV).rgb; NORMAL_MAP_DEPTH = normal_scale; }
	if (emission_enabled) { EMISSION = (emission.rgb + texture(texture_emission, UV).rgb) * emission_energy; }
	if (ao_enabled) { AO = dot(texture(texture_ambient_occlusion, UV), ao_texture_channel); AO_LIGHT_AFFECT = ao_light_affect; }
}
