shader_type spatial;
render_mode cull_disabled;

global uniform vec2 grass_lod_origin;
global uniform vec2 wind_direction;
global uniform float wind_idle_bend;
global uniform sampler2D wind_gust_texture;
global uniform float wind_gust_scale;
global uniform float wind_gust_speed;
global uniform float wind_gust_bend;
global uniform sampler2D grass_trample_texture;
global uniform sampler2D grass_static_trample_texture;
global uniform vec2 grass_trample_origin;
global uniform float grass_trample_size;
global uniform float grass_trample_epoch;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform bool source_has_texture = false;
// The exact live KayKit palette texture and grass-island UV used by the
// terrain sheet. An optional source texture supplies only restrained value
// variation; its hue never replaces this shared ground palette.
uniform sampler2D ground_palette_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec2 ground_palette_uv = vec2(0.125, 0.125);
uniform float local_base_y = 0.0;
uniform float local_height = 1.0;

const float FULL_RADIUS = 60.0;
const float GRASS_RADIUS = 84.0;
// Distant partial-scale leaves alias into bright moving specks. Keep each
// accepted patch whole, then remove sub-pixel normal and motion detail before
// the spatial prefix removes it.
const float FAR_DETAIL_START = 32.0;
const float FAR_DETAIL_END = 48.0;
const float RECOVERY_SECONDS = 10.0;
const float TRAMPLE_BEND = 1.25;
const float TRAMPLE_DROP = 0.95;
// Structural assets press blades mostly downward. Their small radial bend
// spreads leaf tips out from the base without brushing the whole footprint in
// one arbitrary compass direction.
const float STATIC_BEND = 0.20;
const float STATIC_DROP = 0.98;
const float ARC_DROP = 0.18;
const float NORMAL_UP_BIAS = 0.82;

varying float grass_detail;
varying float blade_height01;
varying float blade_tone;

float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453);
}

float density_at(float distance_to_origin) {
	return 1.0 - smoothstep(FULL_RADIUS, GRASS_RADIUS, distance_to_origin);
}

vec2 world_to_local_tangent(vec2 direction, vec3 tangent_x, vec3 tangent_z) {
	// Instance X/Z axes include both authored yaw and the terrain-normal
	// orientation. Project a horizontal world direction onto that tangent
	// frame; a yaw-only inverse is incorrect once grass follows a slope.
	vec3 world_direction = vec3(direction.x, 0.0, direction.y);
	vec2 local_direction = vec2(dot(world_direction, tangent_x),
		dot(world_direction, tangent_z));
	float local_length = length(local_direction);
	return local_length > 0.0001 ? local_direction / local_length : vec2(1.0, 0.0);
}

void vertex() {
	vec2 world_xz = MODEL_MATRIX[3].xz;
	float lod_distance = distance(world_xz, grass_lod_origin);
	float density = density_at(lod_distance);
	float rank = INSTANCE_CUSTOM.y;
	float dropout = 1.0 - step(density, rank);
	// Population follows the player, but temporal detail follows the camera.
	// An orbit camera can sit tens of metres away from the player; measuring
	// both from the player left screen-distant blades swaying independently.
	float detail_distance = distance(world_xz, CAMERA_POSITION_WORLD.xz);
	grass_detail = 1.0 - smoothstep(FAR_DETAIL_START, FAR_DETAIL_END, detail_distance);
	float height01 = clamp((VERTEX.y - local_base_y) / max(local_height, 0.0001), 0.0, 1.0);
	blade_height01 = height01;
	float weight = height01 * height01;

	vec2 wind_world = normalize(wind_direction + vec2(0.0001, 0.0));
	vec3 tangent_x = normalize(MODEL_MATRIX[0].xyz);
	vec3 tangent_z = normalize(MODEL_MATRIX[2].xyz);
	vec2 wind_local = world_to_local_tangent(wind_world, tangent_x, tangent_z);
	float phase = INSTANCE_CUSTOM.x;
	// Root-anchored variation gives neighbouring blade groups a little value
	// separation without screen-space noise. Fade it with the same detail band
	// as motion so distant grass remains a coherent, temporally stable carpet.
	float root_tone = mix(0.97, 1.03,
		hash21(UV2 * 113.0 + vec2(phase, phase * 1.37)));
	blade_tone = mix(1.0, root_tone, grass_detail);
	float idle = sin(TIME * 1.05 + phase) + 0.22 * sin(TIME * 1.70 + phase * 1.73);
	vec2 gust_uv = (world_xz - wind_world * TIME * wind_gust_speed)
		/ max(wind_gust_scale, 1.0);
	float gust_noise = textureLod(wind_gust_texture, gust_uv, 0.0).r;
	float gust = smoothstep(0.38, 0.88, gust_noise);

	// The merged Collection 5 patch contains 311 separate blades. UV2 stores
	// each blade's stable mesh-local root, preventing one nearby footprint from
	// snapping the entire 2.6 m patch as a rigid tuft.
	vec3 blade_root_world = (MODEL_MATRIX
		* vec4(UV2.x, local_base_y, UV2.y, 1.0)).xyz;
	vec2 trample_xz = blade_root_world.xz;
	float inside = step(grass_trample_origin.x, trample_xz.x)
		* step(grass_trample_origin.y, trample_xz.y)
		* step(trample_xz.x, grass_trample_origin.x + grass_trample_size)
		* step(trample_xz.y, grass_trample_origin.y + grass_trample_size);
	vec2 trample_uv = (trample_xz - grass_trample_origin)
		/ max(grass_trample_size, 0.0001);
	// The 64 m trample window covers only a small fraction of the 84 m ring.
	// Keep the branch coherent and skip that texture read for the far majority
	// of vertices; the default encodes a neutral direction and zero strength.
	vec4 trample = vec4(0.5, 0.5, 0.0, grass_trample_epoch);
	vec4 static_trample = vec4(0.5, 0.5, 0.0, 0.0);
	if (inside > 0.5) {
		trample = textureLod(grass_trample_texture,
			clamp(trample_uv, vec2(0.0), vec2(1.0)), 0.0);
		static_trample = textureLod(grass_static_trample_texture,
			clamp(trample_uv, vec2(0.0), vec2(1.0)), 0.0);
	}
	float age01 = clamp((grass_trample_epoch - trample.a) / RECOVERY_SECONDS, 0.0, 1.0);
	float dynamic_flatten = trample.b * (1.0 - age01 * age01) * inside;
	float static_flatten = static_trample.b * inside;
	float flatten = max(dynamic_flatten, static_flatten);
	vec2 trample_world = trample.rg * 2.0 - 1.0;
	float trample_length = length(trample_world);
	trample_world = trample_length > 0.0001 ? trample_world / trample_length : wind_world;
	vec2 trample_local = world_to_local_tangent(trample_world, tangent_x, tangent_z);
	vec2 static_world = static_trample.rg * 2.0 - 1.0;
	float static_length = length(static_world);
	static_world = static_length > 0.0001 ? static_world / static_length : wind_world;
	vec2 static_local = world_to_local_tangent(static_world, tangent_x, tangent_z);
	vec2 perpendicular = vec2(-trample_local.y, trample_local.x);
	float splay = sin(phase * 2.31) * 0.06;

	float wind_response = 1.0 - flatten;
	vec2 bend = wind_local * (wind_idle_bend * idle * (0.75 + 0.35 * gust)
		+ wind_gust_bend * gust) * wind_response;
	// A fresh footstep owns the visible lateral direction. As it recovers, its
	// contribution continuously fades while the persistent radial asset crush
	// returns; no timer can snap the leaves back to their original direction.
	bend += static_local * STATIC_BEND * static_flatten * (1.0 - dynamic_flatten);
	bend += (trample_local * TRAMPLE_BEND + perpendicular * splay) * dynamic_flatten;
	// Sub-pixel leaves must not move independently in the far field.
	bend *= grass_detail;
	float bend_ratio = length(bend);
	VERTEX.xz += bend * local_height * weight * dropout;
	float vertical_drop = max(STATIC_DROP * static_flatten,
		TRAMPLE_DROP * dynamic_flatten);
	VERTEX.y -= local_height * weight
		* (ARC_DROP * bend_ratio * bend_ratio + vertical_drop) * dropout;

	// The normalized rank gives every density an exact whole-patch prefix.
	// Broad partial scaling made the retained far leaves look like flickering
	// petals; the stable far-detail low pass now hides each discrete removal.
	VERTEX.xz *= dropout;
	VERTEX.y = local_base_y + (VERTEX.y - local_base_y) * dropout;
	// Near blades retain enough authored normal direction to read as geometry.
	// Once that direction is screen-small, converge to the same upward lighting
	// response as the terrain sheet. Keeping even 18% of the angled normals in
	// the far carpet leaves a false shadow band before the population cutoff.
	float normal_up_bias = mix(1.0, NORMAL_UP_BIAS, grass_detail);
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), normal_up_bias));
}

void fragment() {
	// These are physical ribbons, not opaque one-sided leaves. With culling
	// disabled, a back-facing card otherwise keeps the opposite lighting normal
	// and turns half the carpet into a dark stipple. Face the same authored
	// normal toward the lighting hemisphere on both sides.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	// Collection 5 has a flat material rather than an albedo texture: its
	// internal light/dark structure comes from the bent blade normals. Keep the
	// same value response for textured variants without inventing a fake map.
	float texture_detail = 0.5;
	if (source_has_texture) {
		vec3 sampled = texture(albedo_texture, UV).rgb;
		float source_value = dot(sampled, vec3(0.2126, 0.7152, 0.0722));
		texture_detail = smoothstep(0.015, 0.32, source_value);
	}
	// Darker roots ground each clump against the terrain, while restrained warm
	// tips catch the light. This contrast is intentionally wider in linear
	// colour space: the bright meadow tone map otherwise collapses a subtle
	// ramp back into the same flat neon value as the terrain sheet.
	float root_match = 1.0 - smoothstep(0.0, 0.24, blade_height01);
	float lower_gradient = smoothstep(0.0, 0.64, blade_height01);
	float tip_gradient = smoothstep(0.54, 1.0, blade_height01);
	float near_value = mix(1.0, 0.84, lower_gradient);
	near_value = mix(near_value, 1.04, tip_gradient);
	// Distant blades converge to the exact terrain value instead of retaining
	// hundreds of tiny high-contrast tip marks. Darkening this low-pass made
	// the finite grass ring read as a broad shadow in front of the brighter
	// bare terrain beyond it.
	float blade_value = mix(1.0, near_value, grass_detail);
	blade_value = mix(blade_value, 1.0, root_match);
	float variation_amount = grass_detail * (1.0 - root_match);
	blade_value *= mix(1.0,
		mix(0.97, 1.03, texture_detail) * blade_tone, variation_amount);
	vec3 near_tint = mix(vec3(0.96, 0.98, 1.02),
		vec3(1.08, 1.02, 0.78), tip_gradient);
	vec3 far_tint = vec3(1.0);
	vec3 height_tint = mix(far_tint, near_tint, grass_detail);
	height_tint = mix(height_tint, vec3(1.0), root_match);
	vec3 ground_base = textureLod(ground_palette_texture,
		ground_palette_uv, 0.0).rgb;
	ALBEDO = ground_base * COLOR.rgb * height_tint * blade_value;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
