shader_type spatial;
render_mode cull_back;
#include "res://terrain/materials/ground_style.gdshaderinc"
uniform vec3 tactical_eye;
uniform float tactical_floor_y;
uniform float tactical_section_y;
uniform float tactical_terrain_cutaway;
instance uniform float tactical_strength : instance_index(15) = 0.0;
varying vec3 original_world;
varying float upward;

void vertex() {
	original_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	upward = (MODEL_NORMAL_MATRIX * NORMAL).y;
	vec3 section = original_world;
	section.y = tactical_section_y - 0.04;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(section,1.0)).xyz;
	NORMAL = normalize(transpose(mat3(MODEL_MATRIX)) * vec3(0.0,1.0,0.0));
}

void fragment() {
	// Keep shadow cameras, low ground, walls and inactive views untouched.
	if (distance(INV_VIEW_MATRIX[3].xyz,tactical_eye)>0.1 || tactical_strength<0.001
		|| tactical_terrain_cutaway<0.001 || upward<=0.001
		|| original_world.y<=tactical_floor_y+0.15) { discard; }
	// A subdued soil section distinguishes the exposed solid from a walkable
	// turf terrace. The real terrain silhouette occludes it outside the cut.
	float grain = ground_noise(original_world.xz*1.7);
	ALBEDO = mix(vec3(0.20,0.15,0.10),vec3(0.29,0.23,0.16),grain) * COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
