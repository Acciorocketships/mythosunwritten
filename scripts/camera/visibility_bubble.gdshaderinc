// Shared material adapter: never changes geometry, physics or authored colour.
uniform vec3 tactical_eye;
uniform vec3 tactical_feet;
uniform float tactical_floor_y = 0.0;
uniform float tactical_radius = 3.8;
uniform float tactical_opacity = 0.12;
uniform float tactical_strength = 0.0;

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
	// Protect the floor in projection, including terrain rising toward the eye.
	// World height alone incorrectly fades a slope just above the player's feet.
	vec3 physical_feet = vec3(tactical_feet.x, tactical_floor_y, tactical_feet.z);
	vec3 ground_ray = normalize(physical_feet - tactical_eye);
	vec3 ground_up = normalize(vec3(0.0, 1.0, 0.0) - ground_ray * ground_ray.y);
	float projected_height = dot(point - physical_feet, ground_up) / max(depth_fraction, 0.001);
	float above_projected_feet = smoothstep(0.08, 0.35, projected_height);
	float front = smoothstep(-0.25, 0.5, along);
	float above_floor = smoothstep(0.12, 0.5, point.y - tactical_floor_y);
	float before_eye = 1.0 - smoothstep(boom_length, boom_length + 0.5, along);
	return side * front * above_floor * above_projected_feet * before_eye;
}

void tactical_cutout(vec3 view_position, vec2 pixel, mat4 inverse_view) {
	// Shadow cameras keep the original material, so a roof still shades its room.
	if (distance(inverse_view[3].xyz, tactical_eye) > 0.1) { return; }
	vec3 point = (inverse_view * vec4(view_position, 1.0)).xyz;
	float fade = tactical_coverage(point) * tactical_strength * (1.0 - tactical_opacity);
	// Stable interleaved pixel coverage gives opacity without alpha sorting or
	// turning an entire batched cliff/town into a transparent draw call.
	float noise = fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
	if (noise < fade) { discard; }
}
