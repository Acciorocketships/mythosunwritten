shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color;
uniform vec4 base_color : source_color = vec4(1.0);
global uniform vec3 atmosphere_sun_ray;
global uniform float canopy_shadow_detail;
global uniform sampler2D biome_ground_a;
global uniform vec2 biome_ground_origin;
varying vec3 world_point;
float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	ALPHA = 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	// Economical and non-forest crowns keep solid shadows without evaluating
	// the atlas mask or the procedural gaps.
	if (canopy_shadow_detail > 0.0) {
		vec2 uv = ((world_point.xz - biome_ground_origin) / 48.0 + 0.5) / 65.0;
		float forest = texture(biome_ground_a, uv).r * canopy_shadow_detail;
		if (forest > 0.001) {
			vec3 texel = (texture(albedo_texture, UV) * base_color).rgb;
			float leaf = smoothstep(0.015, 0.09, texel.g - max(texel.r, texel.b));
			vec2 p = (world_point.xz - world_point.y * atmosphere_sun_ray.xz
				/ min(-0.01, atmosphere_sun_ray.y)) * 0.35;
			vec2 cell = floor(p);
			vec2 f = fract(p);
			f = f * f * (3.0 - 2.0 * f);
			float holes = mix(mix(hash21(cell), hash21(cell + vec2(1, 0)), f.x),
				mix(hash21(cell + vec2(0, 1)), hash21(cell + vec2(1, 1)), f.x), f.y);
			ALPHA = 1.0 - leaf * step(mix(1.01, 0.62, forest), holes);
		}
	}
}
