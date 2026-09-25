// Shared material adapter: never changes geometry, physics or authored colour.
uniform vec3 tactical_eye;
uniform vec3 tactical_feet;
uniform float tactical_floor_y = 0.0;
uniform float tactical_radius = 3.8;
uniform float tactical_opacity = 0.12;
uniform sampler2D tactical_ground_depth : filter_nearest, repeat_disable;
uniform sampler2D tactical_front_depth : filter_nearest, repeat_disable;
uniform sampler2D tactical_receiver_palette : source_color, filter_nearest;
uniform vec2 tactical_receiver_texel = vec2(1.0);
instance uniform float tactical_strength : instance_index(15) = 0.0;
instance uniform float tactical_shell : instance_index(14) = 0.0;
instance uniform float tactical_native_turf : instance_index(13) = 0.0;
instance uniform float tactical_ground_owner : instance_index(12) = 0.0;
instance uniform vec3 tactical_parent_z : instance_index(11);
instance uniform vec3 tactical_parent_x : instance_index(10);
instance uniform vec3 tactical_parent_origin : instance_index(9);
instance uniform float tactical_owner_footprints : instance_index(8) = 0.0;
instance uniform vec4 tactical_owner_rect : instance_index(7);
varying flat float tactical_owner_front;
varying flat float tactical_owner_nearest;

float tactical_owner_setup(vec4 footprint) {
	if (tactical_owner_footprints < 0.5) { return 1.0; }
	if (tactical_owner_footprints > 1.5) { footprint = tactical_owner_rect; }
	vec2 direction = tactical_eye.xz - tactical_feet.xz;
	direction /= max(length(direction), 0.001);
	float nearest = -1e20;
	for (int corner = 0; corner < 4; corner++) {
		vec3 point = tactical_parent_origin
			+ tactical_parent_x * ((corner % 2 == 0) ? footprint.x : footprint.z)
			+ tactical_parent_z * ((corner < 2) ? footprint.y : footprint.w);
		nearest = max(nearest, dot(point.xz - tactical_feet.xz, direction));
	}
	// Every surface of the same room makes the same decision. This retains
	// background architecture without exposing the rear wall of a cut room.
	return nearest;
}

vec3 tactical_shell_mask_point(vec3 point, vec2 uv, mat4 inverse_view, mat4 inverse_projection) {
	if (tactical_owner_footprints < 0.5) { return point; }
	vec2 direction = tactical_eye.xz - tactical_feet.xz;
	direction /= max(length(direction), 0.001);
	vec4 ray_view = inverse_projection * vec4(uv * 2.0 - 1.0, 1.0, 1.0);
	vec3 ray = normalize(mat3(inverse_view) * (ray_view.xyz / ray_view.w));
	float slope = dot(ray.xz, direction);
	if (abs(slope) < 0.0001) { return point; }
	// Project every surface of this enclosure onto its camera-facing support
	// plane. The same screen ray then gets exactly the same feather coverage
	// at the front wall, roof and rear wall, even when their depths differ.
	float distance_to_plane = (tactical_owner_nearest
		- dot(tactical_eye.xz - tactical_feet.xz, direction)) / slope;
	return tactical_eye + ray * max(distance_to_plane, 0.0);
}

float tactical_coverage(vec3 point) {
	vec3 focus = tactical_feet + vec3(0.0, 1.0, 0.0);
	vec3 boom = tactical_eye - focus;
	float boom_length = length(boom);
	vec3 axis = boom / max(boom_length, 0.001);
	vec3 offset = point - focus;
	float along = dot(offset, axis);
	float radial = length(offset - axis * along);
	// Keep the neighbourhood's world radius along the foreground segment.
	// Perspective then widens its screen coverage as an obstacle approaches
	// the eye, including the whole viewport when the camera enters a canopy.
	float radius = max(tactical_radius, 0.001);
	float side = 1.0 - smoothstep(radius * 0.72, radius, radial);
	float front = smoothstep(-0.25, 0.5, along);
	float before_eye = 1.0 - smoothstep(boom_length, boom_length + 0.5, along);
	return side * front * before_eye;
}

float tactical_column_coverage(vec3 point) {
	vec3 focus = tactical_feet + vec3(0.0, 1.0, 0.0);
	vec3 boom = tactical_eye - focus;
	float boom_length = max(length(boom), 0.001);
	vec3 axis = boom / boom_length;
	vec3 offset = point - focus;
	float along = dot(offset, axis);
	float radius = max(tactical_radius * max(1.0, 1.0 - along / boom_length), 0.001);
	return (1.0 - smoothstep(radius * 0.72, radius, length(offset - axis * along)))
		* (1.0 - smoothstep(boom_length, boom_length + 0.5, along));
}

float tactical_ground_protection(vec3 point, vec3 normal) {
#ifdef TACTICAL_TERRAIN_MATERIAL
	// Real ground is protected by matching the receiver depth itself. Only
	// grass needs its roots protected separately from its raised blade tips.
#ifdef TACTICAL_GRASS_ROOT
	if (tactical_grass_root.y <= tactical_floor_y + 0.15) { return 1.0; }
#endif
	return 0.0;
#endif

	// Protect actual nearby support surfaces, not a half-plane of the screen.
	// The slope allowance follows rising/descending ground around physical feet;
	// normals keep vertical walls inside the full circular cutout.
	float distance_xz = length(point.xz - tactical_feet.xz);
	float nearby = 1.0 - smoothstep(4.0, 5.0, distance_xz);
	float support_height = 1.0 - smoothstep(0.65 + distance_xz * 0.65,
		0.85 + distance_xz * 0.65, point.y - tactical_floor_y);
	return nearby * support_height * step(0.55, normal.y);
}

float tactical_receiver_depth(vec2 uv) {
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) { return 0.0; }
	vec3 bytes = floor(texture(tactical_ground_depth, uv).rgb * 255.0 + 0.5);
	return dot(bytes, vec3(1.0, 256.0, 65536.0)) * 0.001;
}

float tactical_earth_coverage(vec3 point, vec2 uv, mat4 inverse_view, mat4 inverse_projection) {
	vec3 bytes = floor(texture(tactical_front_depth, uv).rgb * 255.0 + 0.5);
	float depth = dot(bytes, vec3(1.0, 256.0, 65536.0)) * 0.001;
	if (depth <= 0.0) { return 0.0; }
	float receiver_depth = tactical_receiver_depth(uv);
	// When the first ground is itself the retained receiver, its grass and
	// turf must remain together. A wider mask must not shave cover from it.
	if (receiver_depth <= depth + 0.04) { return 0.0; }
	vec4 near_h = inverse_projection * vec4(uv * 2.0 - 1.0, 1.0, 1.0);
	vec4 far_h = inverse_projection * vec4(uv * 2.0 - 1.0, 0.5, 1.0);
	vec3 near_point = near_h.xyz / near_h.w;
	vec3 ray = far_h.xyz / far_h.w - near_point;
	vec3 first_view = near_point + ray * ((-depth - near_point.z) / ray.z);
	vec3 first_world = (inverse_view * vec4(first_view, 1.0)).xyz;
	// All skins of intervening earth use the FIRST actual terrain surface's
	// projected coverage. A deeper reverse skin cannot survive its front cap
	// at the feather. This pass supplies only a mask, never replacement color.
	return tactical_column_coverage(first_world);
}

float tactical_receiver_mask(vec2 uv) {
	// A centre sample is mandatory: filtering must never extend the reveal
	// into a pixel without ground. The surrounding samples feather INWARD.
	if (tactical_receiver_depth(uv) <= 0.0) { return 0.0; }
	// About 1.5% of viewport width, bounded for small diagnostic views.
	float feather_pixels = clamp(0.015 / tactical_receiver_texel.x, 8.0, 32.0);
	vec2 step_uv = tactical_receiver_texel * feather_pixels;
	float covered = 1.0;
	for (int i = 0; i < 12; i++) {
		float angle = float(i) * 0.523598776;
		vec2 offset = vec2(cos(angle), sin(angle)) * step_uv;
		// The viewport border is not a hole in the ground. Clamp the feather
		// taps there; the mandatory centre still rejects every actual void.
		vec2 sample_uv = clamp(uv + offset, tactical_receiver_texel * 0.5,
			vec2(1.0) - tactical_receiver_texel * 0.5);
		covered += step(0.001, tactical_receiver_depth(sample_uv));
	}
	return smoothstep(0.5, 1.0, covered / 13.0);
}

void tactical_cutout(vec3 view_position, vec3 view_normal, vec2 pixel, vec2 uv, mat4 inverse_view, mat4 inverse_projection, bool front_facing, vec2 surface_uv) {
	// Shadow cameras keep the original material, so a roof still shades its room.
	if (distance(inverse_view[3].xyz, tactical_eye) > 0.1) { return; }
	vec3 point = (inverse_view * vec4(view_position, 1.0)).xyz;
	vec3 normal = normalize(mat3(inverse_view) * view_normal);
	float coverage = tactical_coverage(point);
	if (tactical_shell > 0.5) { coverage = tactical_column_coverage(tactical_shell_mask_point(point, uv, inverse_view, inverse_projection)) * tactical_owner_front; }
	if (tactical_ground_owner > 0.5) { coverage = tactical_earth_coverage(point, uv, inverse_view, inverse_projection); }
#ifdef TACTICAL_TERRAIN_MATERIAL
	// The rear side of a two-sided cliff skirt is still part of the intervening
	// earth, even when it crosses the actor plane. Peel the complete column up
	// to the proven receiver, not just the first side of its shell.
	coverage = tactical_earth_coverage(point, uv, inverse_view, inverse_projection);
#endif
	float remaining_opacity = tactical_opacity;
	if (tactical_shell > 0.5) { remaining_opacity = 0.0; }
#ifdef TACTICAL_TERRAIN_MATERIAL
	remaining_opacity = 0.0;
#endif
	float protection = tactical_ground_protection(point, normal);
#ifdef TACTICAL_GRASS_ROOT
	// Tall blades project away from their support pixel. Protect them using
	// the actual root's receiver depth, including raised ground behind a bank.
	vec3 root_view = transpose(mat3(inverse_view)) * (tactical_grass_root - tactical_eye);
	vec4 root_clip = inverse(inverse_projection) * vec4(root_view, 1.0);
	vec2 root_uv = root_clip.xy / root_clip.w * 0.5 + 0.5;
	float root_depth = tactical_receiver_depth(root_uv);
	if (root_depth > 0.0 && abs(root_depth + root_view.z) < 0.20) { protection = 1.0; }
#endif
	if (tactical_shell > 0.5) { protection = 0.0; }
	// Most fragments in a selected batch lie outside the reveal. Avoid
	// receiver texture work for those and for protected ground-cover roots.
	if (coverage * (1.0 - protection) * tactical_strength <= 0.0) { return; }
	float ground_depth = tactical_receiver_depth(uv);
	if (ground_depth <= 0.0 || -view_position.z > ground_depth + 0.01) { return; }
	if (tactical_shell > 1.5 && normal.y > 0.001 && abs(-view_position.z - ground_depth) < 0.04) { return; }
	if (tactical_ground_owner > 0.5) {
		bool upward_ground = normal.y > 0.001;
		if (tactical_native_turf > 0.5) {
			vec3 swatch = texture(tactical_receiver_palette, surface_uv).rgb;
			upward_ground = normal.y >= 0.55 && swatch.g - max(swatch.r, swatch.b) >= 0.01;
		}
		if (upward_ground && abs(-view_position.z - ground_depth) < 0.04) { return; }
	}
	float receiver = tactical_receiver_mask(uv);
	float fade = coverage * (1.0 - protection)
		* tactical_strength * (1.0 - remaining_opacity) * receiver;
	// A cutaway must not expose the inner/back face of a removed shell. Keep
	// ordinary backface behavior where no receiver-backed reveal is possible.
	if (!front_facing && fade > 0.001) { discard; }
	// Stable interleaved pixel coverage gives opacity without alpha sorting or
	// turning an entire batched cliff/town into a transparent draw call.
	float noise = fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
	if (noise < fade) { discard; }
}
