// Shared by the terrain, rolled lips and actual grass blades.
global uniform sampler2D biome_ground_a;
global uniform sampler2D biome_ground_b;
global uniform vec2 biome_ground_origin;
global uniform sampler2D biome_ground_color;
float ground_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float ground_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(ground_hash(i), ground_hash(i + vec2(1,0)), f.x),
		mix(ground_hash(i + vec2(0,1)), ground_hash(i + vec2(1,1)), f.x), f.y);
}
vec3 ground_style(vec2 p, vec3 base) {
	vec2 uv = ((p - biome_ground_origin) / 48.0 + 0.5) / 65.0;
	vec4 a = texture(biome_ground_a, uv);
	vec4 b = texture(biome_ground_b, uv);
	vec4 substrate = texture(biome_ground_color, uv);
	base = mix(base, substrate.rgb, substrate.a * 0.88);
	float islands = ground_noise(p * 0.095);
	float grain = ground_noise(p * 1.7);
	float detail = 1.0 - smoothstep(0.035, 0.16, length(fwidth(p)));
	// Broad forest moss and amber exposed earth form beds, not tile stamps.
	vec3 color = base * mix(0.90, 1.08, islands);
	color = mix(color, base * vec3(0.66, 0.84, 0.90), a.r * smoothstep(0.42, 0.74, islands) * 0.65);
	color = mix(color, vec3(0.19, 0.12, 0.08), b.r * smoothstep(0.47, 0.72, islands) * 0.32);
	// Mineral islands are cool lavender/chalk; wet margins carry jade silt.
	color = mix(color, vec3(0.32, 0.35, 0.39), a.g * smoothstep(0.38, 0.72, islands) * 0.62);
	color = mix(color, vec3(0.10, 0.19, 0.20), (a.a + b.g) * smoothstep(0.4, 0.72, islands) * 0.30);
	color *= 1.0 + (grain - 0.5) * 0.16 * detail;
	// Wind-gathered petal litter. Analytic ellipses are antialiased and fade
	// out before becoming distant confetti. Grass reads this same substrate.
	vec2 cell = floor(p * 2.2);
	vec2 local = fract(p * 2.2) - vec2(ground_hash(cell), ground_hash(cell + 17.0));
	float petal = 1.0 - smoothstep(0.055, 0.11, length(local * vec2(1.0, 2.0)));
	float bed = smoothstep(0.35, 0.64, islands);
	color = mix(color, vec3(0.74, 0.37, 0.52), petal * bed * a.b * detail * 0.72);
	// Tiny warm meadow seed heads / fallen amber leaves share the same field.
	color = mix(color, vec3(0.42, 0.27, 0.08), petal * b.r * detail * 0.55);
	return color;
}
