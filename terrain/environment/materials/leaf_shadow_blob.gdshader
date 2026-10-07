shader_type spatial;
// Crown stand-in in the painted-leaf shadow proxy. The wide sun cascades
// (wider than painted_leaf's shadow_card_cascade_width) draw this ellipsoid
// instead of alpha-tested leaf cards: discard defeats the GPU's hidden surface
// removal, and a crown of cards is a dozen layers deep where the ellipsoid is
// two, so four cascades of cards cost a dense forest about half its frame.
// Its gaps are cut in sun-projected space, so the front and back faces open
// on the same sun ray and the ground keeps dappled light. Narrow cascades keep
// the cards and skip the blob.
render_mode unshaded, cull_disabled;
uniform float shadow_card_cascade_width = 30.0;
// Share of the crown's shadow left open, and the dapple size (metres).
uniform float gaps = 0.25;
uniform float dapple = 0.9;
global uniform vec3 atmosphere_sun_ray;
varying vec3 world_point;
float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1, 0)), f.x),
		mix(hash21(cell + vec2(0, 1)), hash21(cell + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	float wide_cascade = PROJECTION_MATRIX[3][3] > 0.5
		? step(shadow_card_cascade_width, 2.0 / PROJECTION_MATRIX[0][0]) : 0.0;
	VERTEX *= wide_cascade;
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	ALBEDO = vec3(0.0);
	vec2 p = (world_point.xz - world_point.y * atmosphere_sun_ray.xz
		/ min(-0.01, atmosphere_sun_ray.y)) / dapple;
	float holes = 0.65 * noise(p) + 0.35 * noise(p * 2.3 + 17.0);
	ALPHA = step(gaps, 1.0 - holes);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
