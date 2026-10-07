shader_type spatial;
// Alpha-card canopy of the painted nature packs (ANGRY MESH Meadow, Polyart
// Farmlands). Their cards carry crown-radial normals, so both faces of a card
// keep that normal: Godot's double-sided flip pointed every back face into the
// crown and split each tree into a lit and a dark shade. The vendor shaders
// also darkened the crown's interior and underside, varied its tint and let
// light through the leaves; one flat albedo colour read as neon.
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float alpha_scissor = 0.3;
// Leaf-surface bounds in mesh space (written by the bake).
uniform vec3 crown_centre = vec3(0.0, 6.0, 0.0);
uniform vec3 crown_half_extents = vec3(4.0);
// Share of saturation kept from the vendor tint.
uniform float saturation = 0.68;
uniform float value_scale = 0.9;
// Albedo deep inside the crown and on downward-facing cards.
uniform float interior = 0.42;
uniform float underside = 0.62;
uniform float translucency = 0.28;
// Card thinning (bake: environment_bake.gd LEAF_LOD_EDGE / LEAF_LOD_KEEP).
// LOD k keeps cards of rank < 2^-k and switches where LEAF_LOD_EDGE * 2^(k-1)
// metres span one pixel; cards shrink away before their LOD drops them.
const float LEAF_LOD_EDGE = 0.08;
uniform float survivor_growth = 0.33;
// The sun's shadow cascades (the only orthographic pass) draw the bake's
// shadow proxy: the eighth of the cards the last leaf LOD keeps, grown.
uniform float shadow_keep = 0.147;
// Shadow cascades wider than this (metres) draw the shadow proxy's opaque
// crown blob (leaf_shadow_blob.gdshader, same width) instead of leaf cards:
// alpha-tested cards in the wide cascades cost a dense forest ~20 ms.
uniform float shadow_card_cascade_width = 30.0;
// Main camera position and metres per pixel per metre of distance (set by
// AtmosphereDirector), so the shadow pass thins exactly like the view.
global uniform vec4 leaf_lod_camera;
varying vec3 instance_tint;
varying float crown_depth;
varying float crown_up;
varying vec3 world_pos;
void vertex() {
	vec3 eye = leaf_lod_camera.xyz;
	float pixel = leaf_lod_camera.w;
	if (pixel <= 0.0) {
		eye = CAMERA_POSITION_WORLD;
		pixel = 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	}
	vec3 card_world = (MODEL_MATRIX * vec4(CUSTOM0.xyz, 1.0)).xyz;
	float metres_per_pixel = distance(eye, card_world) * pixel;
	// Kept share: 1/2 at 0.85 of the first switch edge, halving per octave,
	// so every card a LOD removes has already shrunk to nothing. The last
	// LOD keeps its eighth at any distance.
	float keep = max(0.425 * LEAF_LOD_EDGE / max(metres_per_pixel, 1e-5), 0.125 / 0.85);
	float cascade_kill = 1.0;
	if (PROJECTION_MATRIX[3][3] > 0.5) {
		keep = min(keep, shadow_keep);
		cascade_kill = step(2.0 / PROJECTION_MATRIX[0][0], shadow_card_cascade_width);
	}
	float size = clamp((keep - CUSTOM0.w) / (0.15 * keep), 0.0, 1.0)
		* pow(1.0 / clamp(keep, 0.125, 1.0), survivor_growth);
	VERTEX = CUSTOM0.xyz + (VERTEX - CUSTOM0.xyz) * size * cascade_kill;
	instance_tint = COLOR.rgb;
	crown_up = NORMAL.y;
	crown_depth = length((VERTEX - crown_centre) / max(crown_half_extents, vec3(0.01)));
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void fragment() {
	vec4 texel = texture(albedo_texture, UV);
	vec3 colour = texel.rgb * base_color.rgb * instance_tint * value_scale;
	float grey = dot(colour, vec3(0.2126, 0.7152, 0.0722));
	colour = mix(vec3(grey), colour, saturation);
	// Crown self-shading: outer shell bright, interior and underside dark.
	float shell = smoothstep(0.35, 0.95, crown_depth);
	colour *= mix(interior, 1.0, shell);
	colour *= mix(underside, 1.0, smoothstep(-0.8, 0.5, crown_up));
	// Vendor tint noise: broad warm/cool drift plus finer leaf-cluster value.
	vec2 p = world_pos.xz + world_pos.y * 0.37;
	float broad = value_noise(p * 0.16);
	float fine = value_noise(p * 0.9);
	colour *= mix(vec3(0.88, 0.92, 0.95), vec3(1.06, 1.04, 0.95), broad);
	colour *= mix(0.86, 1.1, fine);
	ALBEDO = colour;
	ALPHA = texel.a * base_color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ROUGHNESS = 0.9;
	SPECULAR = 0.12;
	BACKLIGHT = colour * translucency;
}
