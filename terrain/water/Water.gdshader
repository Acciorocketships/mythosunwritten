// Stylized water — Godot 4 port of the ideas in
// assets/SeaWaterMaterial (Sea Water Base Shader, Godot 3): large smooth
// rolling waves, depth-based shore foam, and depth-tinted transparency.
// UVs are world-space so tiles are seamless.
shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec3 color_deep : source_color = vec3(0.12, 0.45, 0.55);
uniform vec3 color_shallow : source_color = vec3(0.32, 0.66, 0.69);
uniform vec3 foam_color : source_color = vec3(0.93, 0.97, 1.0);
uniform float foam_width : hint_range(0.0, 3.0) = 1.15;
uniform float depth_fade : hint_range(0.5, 8.0) = 2.6;
uniform float wave_height : hint_range(0.0, 0.6) = 0.17;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.8;
uniform float roughness : hint_range(0.0, 1.0) = 0.08;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

varying vec3 world_pos;

// Long-wavelength swells: two crossing directional waves plus a broad noise
// drift. Their interference makes the surface pulse slowly.
float wave_h(vec2 p, float t) {
	float h = sin(p.x * 0.11 + t * 0.9) * cos(p.y * 0.085 + t * 0.66);
	h += 0.7 * sin(dot(p, vec2(0.071, 0.052)) - t * 1.05);
	h += 1.0 * (textureLod(noise_tex, p * 0.0045 + vec2(t * 0.006, -t * 0.0045), 0.0).r - 0.5);
	return h;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float h = wave_h(world_pos.xz, t);
	VERTEX.y += h * wave_height;
	// Smooth normals from the analytic height gradient (wide epsilon keeps
	// the surface rolling, not rippled).
	float e = 2.0;
	float hx = wave_h(world_pos.xz + vec2(e, 0.0), t);
	float hz = wave_h(world_pos.xz + vec2(0.0, e), t);
	NORMAL = normalize(vec3((h - hx) * wave_height / e, 1.0, (h - hz) * wave_height / e));
}

void fragment() {
	// Water depth from the opaque depth buffer (banks and floor).
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float scene_dist = -view.z / view.w;
	float surface_dist = -VERTEX.z;
	float water_depth = max(scene_dist - surface_dist, 0.0);

	float t = TIME * wave_speed;

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
	ALPHA = mix(0.6, 0.9, depth_t);
	ALPHA = max(ALPHA, foam_mask * 0.95);
	ROUGHNESS = mix(roughness, 0.5, foam_mask);
	SPECULAR = 0.7;
}
