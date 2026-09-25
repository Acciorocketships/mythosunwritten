shader_type spatial;
render_mode cull_disabled;
#include "res://terrain/materials/ground_style.gdshaderinc"
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_palette : source_color;
uniform vec2 grass_uv = vec2(0.0);
uniform vec4 base_color : source_color = vec4(1.0);
varying vec3 instance_tint;
varying vec3 leaf_world;
void vertex() { instance_tint = COLOR.rgb; leaf_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec4 texel = texture(albedo_texture, UV) * base_color;
	float green = smoothstep(0.015, 0.09, texel.g - max(texel.r, texel.b));
	float value = max(texel.r, max(texel.g, texel.b));
	// Use the same native grass swatch and instance tint as ground_surface.
	// Source leaf luminance gives restrained detail; bark retains its colour.
	vec3 canopy = ground_style(leaf_world.xz, texture(grass_palette, grass_uv).rgb * max(instance_tint, vec3(0.0))) * (0.85 + value * 0.30);
	ALBEDO = mix(texel.rgb, canopy, green);
	ALPHA = texel.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 0.92;
	SPECULAR = 0.15;
	BACKLIGHT = canopy * green * 0.12;
}
