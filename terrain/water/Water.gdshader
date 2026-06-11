// Stylized water — Godot 4 port of the ideas in
// assets/SeaWaterMaterial (Sea Water Base Shader, Godot 3): layered
// directional waves with noise detail, depth-based shore foam, and
// depth-tinted transparency. UVs are world-space so tiles are seamless.
shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec3 color_deep : source_color = vec3(0.08, 0.3, 0.5);
uniform vec3 color_shallow : source_color = vec3(0.2, 0.52, 0.65);
uniform vec3 foam_color : source_color = vec3(0.93, 0.96, 1.0);
uniform float foam_width : hint_range(0.0, 3.0) = 1.15;
uniform float depth_fade : hint_range(0.5, 8.0) = 2.6;
uniform float wave_height : hint_range(0.0, 0.5) = 0.09;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.8;
uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.16;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

varying vec3 world_pos;

float wave_h(vec2 p, float t) {
	float h = sin(p.x * 0.31 + t) * cos(p.y * 0.26 + t * 0.83);
	h += 0.6 * sin(dot(p, vec2(0.2, 0.16)) - t * 1.31);
	h += 1.6 * (textureLod(noise_tex, p * 0.015 + vec2(t * 0.011, -t * 0.007), 0.0).r - 0.5);
	return h;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float h = wave_h(world_pos.xz, t);
	VERTEX.y += h * wave_height;
	// Normals from the analytic height gradient.
	float e = 0.6;
	float hx = wave_h(world_pos.xz + vec2(e, 0.0), t);
	float hz = wave_h(world_pos.xz + vec2(0.0, e), t);
	vec3 n = normalize(vec3((h - hx) * wave_height / e, 1.0, (h - hz) * wave_height / e));
	NORMAL = n;
}

void fragment() {
	// Water depth from the opaque depth buffer (banks and floor).
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float scene_dist = -view.z / view.w;
	float surface_dist = -VERTEX.z;
	float water_depth = max(scene_dist - surface_dist, 0.0);

	// Fine ripple normals on top of the vertex waves.
	float t = TIME * wave_speed;
	vec2 nuv = world_pos.xz * 0.035;
	float e = 0.02;
	float r0 = texture(noise_tex, nuv + vec2(t * 0.018, t * 0.011)).r
		+ texture(noise_tex, nuv * 1.7 - vec2(t * 0.013, -t * 0.017)).r;
	float rx = texture(noise_tex, nuv + vec2(e, 0.0) + vec2(t * 0.018, t * 0.011)).r
		+ texture(noise_tex, nuv * 1.7 + vec2(e * 1.7, 0.0) - vec2(t * 0.013, -t * 0.017)).r;
	float rz = texture(noise_tex, nuv + vec2(0.0, e) + vec2(t * 0.018, t * 0.011)).r
		+ texture(noise_tex, nuv * 1.7 + vec2(0.0, e * 1.7) - vec2(t * 0.013, -t * 0.017)).r;
	vec3 ripple = vec3((r0 - rx) / e, 1.0 / max(normal_strength, 0.001), (r0 - rz) / e);
	NORMAL = normalize(mix(NORMAL, normalize((VIEW_MATRIX * vec4(normalize(ripple), 0.0)).xyz), normal_strength));

	// Depth-tinted base color.
	float depth_t = clamp(water_depth / depth_fade, 0.0, 1.0);
	vec3 base = mix(color_shallow, color_deep, depth_t);

	// Shore foam: a noisy band where the water is shallow (bank walls,
	// island edges), animated so it laps against the shore.
	float foam_noise = texture(noise_tex, world_pos.xz * 0.11 + vec2(t * 0.03, -t * 0.022)).r;
	float foam_edge = foam_width * (0.45 + 0.55 * foam_noise);
	float foam_mask = 1.0 - smoothstep(foam_edge * 0.25, foam_edge, water_depth);
	foam_mask *= 0.85 + 0.15 * sin(t * 2.1 + foam_noise * 6.0);

	ALBEDO = mix(base, foam_color, clamp(foam_mask, 0.0, 1.0));
	ALPHA = mix(0.65, 0.94, depth_t);
	ALPHA = max(ALPHA, foam_mask * 0.95);
	ROUGHNESS = mix(roughness, 0.5, foam_mask);
	SPECULAR = 0.7;
}
