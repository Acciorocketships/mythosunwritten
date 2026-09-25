// Shared material adapter: never changes geometry, physics or authored colour.
uniform vec3 tactical_eye;
uniform vec3 tactical_feet;
uniform float tactical_floor_y = 0.0;
uniform float tactical_radius = 3.8;
uniform float tactical_opacity = 0.12;
uniform float tactical_terrain_cutaway = 0.0;
instance uniform float tactical_strength : instance_index(15) = 0.0;

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

float tactical_ground_protection(vec3 point, vec3 normal) {
#ifdef TACTICAL_TERRAIN_MATERIAL
	// Unobstructed terrain stays whole. When real terrain blocks the actor,
	// raised foreground ground may join the contextual cutaway; the floor
	// beneath the actor remains solid throughout the entire corridor.
	vec3 support_point = point;
#ifdef TACTICAL_GRASS_ROOT
	support_point = tactical_grass_root;
#endif
	if (normal.y > 0.001) {
		if (support_point.y <= tactical_floor_y + 0.15) { return 1.0; }
		return 1.0 - tactical_terrain_cutaway;
	}
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

void tactical_cutout(vec3 view_position, vec3 view_normal, vec2 pixel, mat4 inverse_view) {
	// Shadow cameras keep the original material, so a roof still shades its room.
	if (distance(inverse_view[3].xyz, tactical_eye) > 0.1) { return; }
	vec3 point = (inverse_view * vec4(view_position, 1.0)).xyz;
	vec3 normal = normalize(mat3(inverse_view) * view_normal);
	float fade = tactical_coverage(point) * (1.0 - tactical_ground_protection(point, normal))
		* tactical_strength * (1.0 - tactical_opacity);
	// Stable interleaved pixel coverage gives opacity without alpha sorting or
	// turning an entire batched cliff/town into a transparent draw call.
	float noise = fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
	if (noise < fade) { discard; }
}
