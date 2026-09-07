shader_type fog;
uniform sampler2D atmosphere_field : source_color, filter_linear, repeat_disable;
uniform sampler2D ground_field : filter_linear, repeat_disable;
uniform vec2 chunk_origin;
void fog() {
	vec2 local = (WORLD_POSITION.xz - chunk_origin) / 192.0;
	vec2 uv = (local * 12.0 + 0.5) / 13.0;
	vec4 atmosphere = texture(atmosphere_field, uv);
	float ground = texture(ground_field, uv).r;
	float height = max(0.0, WORLD_POSITION.y - ground);
	// Slow crossed waves are world-space, so neighbouring volumes have no seam.
	float drift = 0.78 + 0.12 * sin(WORLD_POSITION.x * 0.045 + TIME * 0.035)
		+ 0.10 * sin(WORLD_POSITION.z * 0.067 - TIME * 0.025);
	float layer = exp(-height * 0.18);
	DENSITY = atmosphere.a * 0.38 * layer * drift;
	ALBEDO = atmosphere.rgb;
	// Clear air cannot emit light merely because a fog volume contains it.
	EMISSION = atmosphere.rgb * DENSITY * 0.6;
}
