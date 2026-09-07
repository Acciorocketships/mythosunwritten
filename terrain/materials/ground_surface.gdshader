shader_type spatial;
#include "res://terrain/materials/ground_style.gdshaderinc"
uniform sampler2D ground_palette_texture : source_color, filter_linear_mipmap_anisotropic;
varying vec3 ground_world;
void vertex() { ground_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 texel = texture(ground_palette_texture, UV).rgb;
	vec3 base = texel * COLOR.rgb;
	// The palette still identifies turf, path and rock. Texture soil only on
	// turf: authored paths and rock backing never become grass-coloured decals.
	float turf = smoothstep(0.01, 0.07, texel.g - max(texel.r, texel.b));
	ALBEDO = mix(base, ground_style(ground_world.xz, base), turf);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
