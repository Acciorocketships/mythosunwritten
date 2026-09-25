shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;
#include "res://tests/fixtures/september13/background_before/visibility_bubble.gdshaderinc"
varying vec3 receiver_world;
varying vec3 receiver_normal;
uniform bool receiver_native_turf = false;
uniform sampler2D receiver_palette : source_color, filter_nearest;
void vertex() {
	receiver_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	receiver_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	// Only the genuine upward surface. The underside of a two-sided apron
	// and the back of a cliff cannot attest that there is ground beyond a hole.
	if (!FRONT_FACING || receiver_normal.y <= 0.001) { discard; }
	if (receiver_native_turf) {
		vec3 swatch = texture(receiver_palette, UV).rgb;
		if (receiver_normal.y < 0.55 || swatch.g - max(swatch.r, swatch.b) < 0.01) { discard; }
	}
	// Peel the foreground part of the candidate cutaway. Depth testing then
	// finds the next real ground, if any; empty pixels remain exactly zero.
	if (tactical_coverage(receiver_world) > 0.001 && receiver_world.y > tactical_floor_y + 0.15) { discard; }
	uint code = uint(clamp(-VERTEX.z * 1000.0, 1.0, 16777215.0));
	vec3 bytes = vec3(float(code & 255u), float((code >> 8u) & 255u), float((code >> 16u) & 255u)) / 255.0;
	ALBEDO = mix(bytes / 12.92, pow((bytes + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), bytes));
}
