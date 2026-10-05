shader_type spatial;
render_mode cull_disabled;
#include "res://terrain/materials/biome_surface.gdshaderinc"
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 base_color : source_color = vec4(1.0);
varying vec3 instance_tint;
varying vec2 canopy_world;
void vertex() {
	instance_tint = COLOR.rgb;
	canopy_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	vec4 texel = texture(albedo_texture, UV) * base_color;
	float green = smoothstep(0.015, 0.09, texel.g - max(texel.r, texel.b));
	float value = max(texel.r, max(texel.g, texel.b));
	// Hue replacement, not multiplication: pink leaves keep their pink even
	// when the source atlas is green. Bark retains its authored colour.
	vec3 canopy = pow(max(instance_tint, vec3(0.0)), vec3(2.2)) * (0.55 + value * 0.65);
	ALBEDO = mix(texel.rgb, canopy, green);
	vec2 response = biome_surface(canopy_world);
	ROUGHNESS = mix(0.92, 0.70, response.r * green);
	SPECULAR = 0.15;
	BACKLIGHT = canopy * green * max(0.12, response.g);
}
