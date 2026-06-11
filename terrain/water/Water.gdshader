shader_type spatial;
render_mode cull_back;

uniform vec3 color_deep : source_color = vec3(0.13, 0.38, 0.56);
uniform vec3 color_shallow : source_color = vec3(0.2, 0.48, 0.65);
uniform float wave_height = 0.07;
uniform float wave_speed = 0.7;

varying float wave;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wave = sin(wp.x * 0.45 + wp.z * 0.2 + TIME * wave_speed)
		* cos(wp.z * 0.38 - wp.x * 0.17 + TIME * wave_speed * 0.8)
		+ 0.5 * sin((wp.x + wp.z) * 0.16 - TIME * wave_speed * 1.4);
	VERTEX.y += wave * wave_height;
}

void fragment() {
	ALBEDO = mix(color_deep, color_shallow, clamp(wave * 0.18 + 0.5, 0.0, 1.0));
	ALPHA = 0.92;
	ROUGHNESS = 0.1;
	SPECULAR = 0.7;
}
