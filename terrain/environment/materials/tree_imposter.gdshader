shader_type spatial;
// Distant tree imposter: a unit QuadMesh (1 x 1, centred) per MultiMesh
// instance, turned about the instance's vertical axis to face the camera and
// drawn from the baked EnvironmentImposter atlases (imposter_capture.gd).
//
// Atlas contract (EnvironmentImposter): `frames` square views side by side.
// Frame f was captured from azimuth a = TAU * f / frames in the asset's own
// space, the eye at (sin a, 0, cos a) from the vertical axis x = z = 0, so the
// frame's right vector is (cos a, 0, -sin a). A frame covers frame_size metres
// (square) and its bottom edge lies pivot_height above the asset origin, both
// in asset metres before the instance's uniform scale.
// - albedo_atlas: RGB albedo under a white instance tint (sRGB), A coverage.
// - normal_atlas: RGB = n * 0.5 + 0.5 in the frame basis (x = frame right,
//   y = up, z = toward the capture eye); A = linear tint response r.
// Instances are upright: yaw plus uniform scale (DressingField).
// No instance custom data: the cards are never in the camera's visibility bubble.
render_mode cull_disabled, depth_draw_opaque, skip_vertex_transform;

uniform sampler2D albedo_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_atlas : filter_linear_mipmap, repeat_disable;
uniform int frames = 8;
uniform vec2 frame_size = vec2(1.0);
uniform float pivot_height = 0.0;
uniform float alpha_cut = 0.5;
// Mipmapped coverage averages leaf texels with the empty background, so
// alpha-tested crowns thin with distance; alpha grows by this much per mip
// level below the base (0 disables the compensation). 1.0 measured in
// tests/harness/imposter_review.gd: coverage 0.94-0.99 of the meshes' from
// 80 to 300 m (0.25: 0.92-0.96).
uniform float mip_alpha_boost = 1.0;
// Top-down fallback: a vertical card seen from above collapses to a line, so
// it dissolves (screen-space dither) as the camera's elevation above the
// frame centre rises from start to end. Orthographic (sun shadow) passes
// never fade.
uniform float top_fade_start_deg = 60.0;
uniform float top_fade_end_deg = 75.0;
// Matches painted_leaf.gdshader's matte leaves.
uniform float roughness = 0.9;
uniform float specular = 0.12;
uniform float translucency = 0.28;

varying vec2 frame_uv;
varying flat float frame_a;
varying flat float frame_b;
varying flat float blend;
varying flat float fade;
// The near tree's share of the per-instance crossfade (painted_leaf.gdshader):
// the card draws exactly the dither cells the tree leaves.
global uniform vec2 tree_imposter_fade;
varying flat float near_fade;
varying flat vec3 axis_x;
varying flat vec3 axis_z;

// Continuous patches avoid the conspicuous one-pixel dot grid during the
// mesh/card handover. All three tree shaders use the same screen-space mask
// and complementary tests, including bark and alpha-tested Farmlands cards.
float tree_fade_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float tree_fade_mask(vec2 p) {
	p /= 8.0;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(tree_fade_hash(cell), tree_fade_hash(cell + vec2(1.0, 0.0)), f.x),
		mix(tree_fade_hash(cell + vec2(0.0, 1.0)), tree_fade_hash(cell + vec2(1.0)), f.x), f.y);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float scale = length(MODEL_MATRIX[0].xyz);
	axis_x = MODEL_MATRIX[0].xyz / scale;
	axis_z = MODEL_MATRIX[2].xyz / max(length(MODEL_MATRIX[2].xyz), 1e-6);
	vec3 centre = origin + vec3(0.0, (pivot_height + 0.5 * frame_size.y) * scale, 0.0);
	// Toward the viewer: the eye for a perspective camera, the reverse view
	// direction for an orthographic (sun shadow) pass.
	bool ortho = PROJECTION_MATRIX[3][3] > 0.5;
	vec3 to_eye = ortho ? INV_VIEW_MATRIX[2].xyz : CAMERA_POSITION_WORLD - centre;
	vec2 flat_dir = to_eye.xz;
	if (dot(flat_dir, flat_dir) < 1e-8) {
		flat_dir = axis_z.xz;
	}
	flat_dir = normalize(flat_dir);
	// A frame captured from eye direction (sin a, 0, cos a) has right (cos a, 0, -sin a).
	vec3 right = vec3(flat_dir.y, 0.0, -flat_dir.x);
	vec3 world = origin + right * VERTEX.x * frame_size.x * scale
		+ vec3(0.0, (pivot_height + (VERTEX.y + 0.5) * frame_size.y) * scale, 0.0);
	// The camera's azimuth in the instance's own (yawed) space picks two frames.
	vec2 local_dir = vec2(dot(to_eye, axis_x), dot(to_eye, axis_z));
	float az = atan(local_dir.x, local_dir.y);
	float f = fract(az / TAU) * float(frames);
	frame_a = mod(floor(f), float(frames));
	frame_b = mod(frame_a + 1.0, float(frames));
	blend = f - floor(f);
	float elevation = degrees(atan(to_eye.y, length(to_eye.xz)));
	fade = ortho ? 1.0 : 1.0 - smoothstep(top_fade_start_deg, top_fade_end_deg, elevation);
	near_fade = ortho ? 0.0 : 1.0 - smoothstep(tree_imposter_fade.x - tree_imposter_fade.y,
		tree_imposter_fade.x + tree_imposter_fade.y, distance(CAMERA_POSITION_WORLD, origin));
	frame_uv = vec2(VERTEX.x + 0.5, 0.5 - VERTEX.y);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = (VIEW_MATRIX * vec4(flat_dir.x, 0.0, flat_dir.y, 0.0)).xyz;
	TANGENT = (VIEW_MATRIX * vec4(right, 0.0)).xyz;
	BINORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}

vec2 atlas_uv(float frame) {
	return vec2((frame + frame_uv.x) / float(frames), frame_uv.y);
}

// A frame's decoded normal, rotated from its capture basis (azimuth a, in
// asset space) into world space through the instance's yaw.
vec3 frame_normal(vec4 texel, float frame) {
	vec3 n = texel.rgb * 2.0 - 1.0;
	float a = TAU * frame / float(frames);
	vec3 local = n.x * vec3(cos(a), 0.0, -sin(a)) + vec3(0.0, n.y, 0.0) + n.z * vec3(sin(a), 0.0, cos(a));
	return local.x * axis_x + vec3(0.0, local.y, 0.0) + local.z * axis_z;
}

void fragment() {
	// Texture reads and derivatives come before the dither discard: screen
	// derivatives are undefined once a quad's neighbours are discarded.
	vec2 uv_a = atlas_uv(frame_a);
	vec2 uv_b = atlas_uv(frame_b);
	vec4 a = mix(texture(albedo_atlas, uv_a), texture(albedo_atlas, uv_b), blend);
	vec4 na = texture(normal_atlas, uv_a);
	vec4 nb = texture(normal_atlas, uv_b);
	vec2 texel = uv_a * vec2(textureSize(albedo_atlas, 0));
	float lod = 0.5 * log2(max(max(dot(dFdx(texel), dFdx(texel)), dot(dFdy(texel), dFdy(texel))), 1.0));
	float cell = tree_fade_mask(FRAGCOORD.xy);
	if ((fade < 1.0 && fade <= cell) || (near_fade >= 0.001 && near_fade >= cell)) {
		discard;
	}
	// Each frame's normal is rotated by its own capture azimuth before the
	// blend, so a mid-blend normal never mixes two different bases.
	vec3 world_normal = normalize(mix(frame_normal(na, frame_a), frame_normal(nb, frame_b), blend) + vec3(0.0, 1e-4, 0.0));
	float response = mix(na.a, nb.a, blend);
	vec3 colour = a.rgb * mix(vec3(1.0), COLOR.rgb, response);
	ALBEDO = colour;
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	ROUGHNESS = roughness;
	SPECULAR = specular;
	BACKLIGHT = colour * translucency;
	ALPHA = a.a * (1.0 + mip_alpha_boost * lod);
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
}
