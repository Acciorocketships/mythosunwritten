shader_type spatial;
#include "res://terrain/materials/ground_style.gdshaderinc"
#include "res://terrain/materials/rock_style.gdshaderinc"
uniform sampler2D ground_palette_texture : source_color, filter_linear_mipmap_anisotropic;
// Moss: the same lawn-to-moss grade as the cliff sheet (cliff_crag.gdshader,
// CliffRockCrags.apply_moss sets both), a function of steepness alone, so the
// terrain and the sheet laid over it agree wherever either one shows.
uniform vec2 grass_uv;
uniform sampler2D moss_detail : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec3 moss_detail_mean = vec3(1.0);
uniform float moss_detail_strength = 0.0;
uniform float moss_detail_scale = .55;
uniform vec3 moss_shade = vec3(.40,.58,.50);
uniform float moss_blend_height = 4.0;
uniform float moss_secondary = .9;
#include "res://terrain/materials/slope_green.gdshaderinc"
// SlopeProfile.LAWN_STEEPNESS / MOSS_STEEPNESS, CliffRockCrags.SHEET_MOSS_RISE.
uniform float lawn_steepness = .326;
uniform float moss_steepness = .5;
uniform float moss_rise = 28.0;
varying vec3 ground_world;
varying vec3 ground_normal;
void vertex() {
	ground_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ground_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 texel = texture(ground_palette_texture, UV).rgb;
	vec3 base = texel * COLOR.rgb;
	// The palette still identifies turf, path and rock. Texture soil only on
	// turf: authored paths and rock backing never become grass-coloured decals.
	float turf = smoothstep(0.01, 0.07, texel.g - max(texel.r, texel.b));
	float rock = (1.0-turf) * step(texel.r, texel.b) * (1.0-smoothstep(0.10,0.16,max(texel.r,max(texel.g,texel.b))-min(texel.r,min(texel.g,texel.b))));
	vec3 lawn = ground_style(ground_world.xz, base);
	vec3 n = normalize(ground_normal);
	float steep = 1.0 - n.y;
	if (steep > lawn_steepness) {
		// Same grade as CliffRockCrags.mesh_arrays: lawn up to the steepest
		// ordinary slope, moss as the ground steepens toward a cliff.
		float grade = mix(.05, .24, clamp((steep - lawn_steepness) / (moss_steepness - lawn_steepness), 0.0, 1.0));
		lawn = slope_green_grade(ground_world, n, COLOR.rgb, moss_rise * grade, grade);
	}
	ALBEDO = mix(mix(base, stone_albedo(texel,ground_world), rock), lawn, turf);
	vec2 finish = substrate_finish(ground_world.xz, n.y);
	ROUGHNESS = finish.x;
	SPECULAR = finish.y;
}
