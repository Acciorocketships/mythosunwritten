// Shared material adapter: never changes geometry, physics or authored colour.
uniform vec3 tactical_eye;
uniform vec3 tactical_feet;
uniform float tactical_floor_y = 0.0;
uniform float tactical_radius = 3.8;
uniform float tactical_opacity = 0.12;
uniform sampler2D tactical_ground_depth : filter_nearest, repeat_disable;
uniform sampler2D tactical_receiver_palette : source_color, filter_nearest;
uniform vec2 tactical_receiver_texel = vec2(1.0);
instance uniform float tactical_strength : instance_index(15) = 0.0;
instance uniform float tactical_shell : instance_index(14) = 0.0;
instance uniform float tactical_native_turf : instance_index(13) = 0.0;
instance uniform float tactical_ground_owner : instance_index(12) = 0.0;

float tactical_coverage(vec3 point) {
	vec3 focus = tactical_feet + vec3(0.0, 1.0, 0.0);
	vec3 boom = tactical_eye - focus;
	float boom_length = length(boom);
	vec3 axis = boom / max(boom_length, 0.001);
	vec3 offset = point - focus;
	float along = dot(offset, axis);
	float radial = length(offset - axis * along);
	// A finite view cone: the neighbourhood is widest at the character and
	// narrows to the camera. A cylinder also catches unrelated foreground.
	float depth_fraction = clamp(1.0 - along / max(boom_length, 0.001), 0.0, 1.0);
	float radius = max(tactical_radius * depth_fraction, 0.001);
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
	float radius = max(tactical_radius * (1.0 - along / boom_length), 0.001);
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
		covered += step(0.001, tactical_receiver_depth(uv + offset));
	}
	return smoothstep(0.5, 1.0, covered / 13.0);
}

void tactical_cutout(vec3 view_position, vec3 view_normal, vec2 pixel, vec2 uv, mat4 inverse_view, bool front_facing, vec2 surface_uv) {
	// Shadow cameras keep the original material, so a roof still shades its room.
	if (distance(inverse_view[3].xyz, tactical_eye) > 0.1) { return; }
	vec3 point = (inverse_view * vec4(view_position, 1.0)).xyz;
	vec3 normal = normalize(mat3(inverse_view) * view_normal);
	float coverage = tactical_coverage(point);
	if (tactical_shell > 0.5) { coverage = tactical_column_coverage(point); }
#ifdef TACTICAL_TERRAIN_MATERIAL
#ifndef TACTICAL_GRASS_ROOT
	// The rear side of a two-sided cliff skirt is still part of the intervening
	// earth, even when it crosses the actor plane. Peel the complete column up
	// to the proven receiver, not just the first side of its shell.
	coverage = tactical_column_coverage(point);
#endif
#endif
	float remaining_opacity = tactical_opacity;
	if (tactical_shell > 0.5) { remaining_opacity = 0.0; }
#ifdef TACTICAL_TERRAIN_MATERIAL
	remaining_opacity = 0.0;
#endif
	float protection = tactical_ground_protection(point, normal);
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
