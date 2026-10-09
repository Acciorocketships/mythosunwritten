shader_type spatial;
render_mode cull_back;
// The painted trees' baked StandardMaterial3D (bark, and alpha-tested Farmlands
// cards), rebuilt as a shader so the tree can crossfade to its imposter per
// instance (EnvironmentCommitQueue.crossfade_material). Mirrors the material's
// used features: albedo colour x texture x vertex colour, normal map with
// depth, AO texture (red), roughness (its texture is never set), no metal.
// The bake's StandardMaterial3D object dither cannot do this: in the fragment
// stage MODEL_MATRIX is the MultiMesh node, not the instance.
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale = 1.0;
uniform bool use_ao = false;
uniform sampler2D ao_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float roughness = 1.0;
uniform float alpha_scissor = 0.5;
global uniform vec2 tree_imposter_fade;
// The placement origin in this piece's mesh space (a piece may sit offset).
uniform vec3 imposter_origin_offset = vec3(0.0);
varying flat float near_fade;

// A tree-centred plane gives mesh and card the same mask without attaching
// it to the screen. Camera rotation leaves the sampled world ray unchanged.
varying flat vec3 fade_origin;
float tree_fade_hash(vec2 p) {
 return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float tree_fade_mask(vec3 view_position, mat4 camera_to_world) {
 vec3 eye = camera_to_world[3].xyz;
 vec3 direction = normalize(vec3(eye.x-fade_origin.x, 0.0, eye.z-fade_origin.z));
 vec3 right = vec3(direction.z, 0.0, -direction.x);
 vec3 ray = (camera_to_world * vec4(view_position, 1.0)).xyz - eye;
 float denominator = dot(ray, direction);
 vec3 hit = eye + ray * (dot(fade_origin-eye, direction) / min(denominator, -0.00001));
 vec3 offset = hit-fade_origin;
 vec2 p = vec2(dot(offset,right), offset.y) / 0.45;
 vec2 cell = floor(p);
 vec2 f = fract(p);
 f = f*f*(3.0-2.0*f);
 return mix(mix(tree_fade_hash(cell),tree_fade_hash(cell+vec2(1,0)),f.x),
  mix(tree_fade_hash(cell+vec2(0,1)),tree_fade_hash(cell+vec2(1)),f.x),f.y);
}

void vertex() {
	fade_origin = (MODEL_MATRIX * vec4(imposter_origin_offset, 1.0)).xyz;
	near_fade = 1.0;
	if (PROJECTION_MATRIX[3][3] < 0.5) {
		float d = distance(CAMERA_POSITION_WORLD, (MODEL_MATRIX * vec4(imposter_origin_offset, 1.0)).xyz);
		near_fade = 1.0 - smoothstep(tree_imposter_fade.x - tree_imposter_fade.y,
			tree_imposter_fade.x + tree_imposter_fade.y, d);
	}
}

void fragment() {
	// Vertex colour carries the instance tint (MultiMesh colours multiply it).
	vec4 albedo = albedo_color * texture(albedo_texture, UV);
	albedo.rgb *= COLOR.rgb;
	albedo.a *= COLOR.a;
	ALBEDO = albedo.rgb;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	if (use_ao) {
		AO = texture(ao_texture, UV).r;
	}
	// CUTOUT (EnvironmentCommitQueue derives the alpha-tested, double-sided
	// variant from this text; the camera bubble needs one self-contained file.)
	// Complementary to tree_imposter.gdshader's test on the same cells.
	if (near_fade < 1.0 && (near_fade < 0.001
			|| near_fade < tree_fade_mask(VERTEX, INV_VIEW_MATRIX))) {
		discard;
	}
}
