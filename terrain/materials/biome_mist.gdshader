shader_type fog;
#include "res://terrain/materials/visual_clock.gdshaderinc"
uniform sampler2D atmosphere_field : source_color, filter_linear, repeat_disable;
uniform sampler2D ground_field : filter_linear, repeat_disable;
// Numeric data: metres, metres, upper weight, emission. Never colour-convert.
uniform sampler2D mist_shape_field : filter_linear, repeat_disable;
uniform vec2 chunk_origin;
uniform float review_time = -1.0;
uniform float review_density = 1.0;
uniform bool review_legacy_precision = false;
float mist_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float mist_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(mist_hash(cell), mist_hash(cell + vec3(1,0,0)), f.x),
		mix(mist_hash(cell + vec3(0,1,0)), mist_hash(cell + vec3(1,1,0)), f.x), f.y),
		mix(mix(mist_hash(cell + vec3(0,0,1)), mist_hash(cell + vec3(1,0,1)), f.x),
		mix(mist_hash(cell + vec3(0,1,1)), mist_hash(cell + vec3(1,1,1)), f.x), f.y), f.z);
}
void fog() {
	vec2 local = (WORLD_POSITION.xz - chunk_origin) / 192.0;
	vec2 uv = (local * 12.0 + 0.5) / 13.0;
	vec4 atmosphere = texture(atmosphere_field, uv);
	vec4 shape = texture(mist_shape_field, uv);
	float ground = texture(ground_field, uv).r;
	float height = max(0.0, WORLD_POSITION.y - ground);
	float time = review_time >= 0.0 ? review_time : visual_time();
	// One broad octave is enough at froxel resolution; world coordinates keep
	// the drifting pockets continuous across streamed chunk boundaries.
	vec3 drift = WORLD_POSITION * vec3(0.035, 0.065, 0.035) + vec3(time * 0.012, 0, time * 0.006);
	float pockets = mix(0.35, 1.25, smoothstep(0.15, 0.85, mist_noise(drift)));
	float layer = exp(-height / max(shape.r, 0.5))
		+ shape.b * exp(-height / max(shape.g, 0.5));
	DENSITY = atmosphere.a * 0.55 * layer * pockets * review_density;
	if (!review_legacy_precision) {
		// Godot 4.5 discards local density <= .001 before fixed-point packing.
		// Stochastic rounding preserves thin mist in expectation. The engine's
		// froxel jitter/filter/reprojection integrates these tiny spatial samples.
		float units = DENSITY * 512.0;
		DENSITY = floor(units + mist_hash(floor(WORLD_POSITION * 8.0))) / 512.0;
	}
	// A lightly tinted scattering medium lets the sun supply the shaft colour.
	ALBEDO = mix(atmosphere.rgb, vec3(0.8), 0.35);
	EMISSION = atmosphere.rgb * shape.a * (review_legacy_precision ? DENSITY : 1.0);
}
