// Persistent compact world-space wavelets. WaterRippleSim transports each
// packet centre through WaterSampler's continuous current field; this pass
// rasterizes their shared height and breaking energy for both water shader
// stages. R = signed height encoded around 0.5, G = breaking energy.
shader_type canvas_item;

uniform sampler2D packet_data : repeat_disable, filter_nearest;
uniform vec2 field_origin = vec2(0.0);
uniform float field_size = 192.0;
uniform int packet_count = 0;

const int MAX_PACKETS = 16;
void fragment() {
	vec2 world_xz = field_origin + UV * field_size;
	float height = 0.0;
	float breaking = 0.0;
	for (int i = 0; i < MAX_PACKETS; i++) {
		if (i >= packet_count) {
			break;
		}
		vec4 a = texelFetch(packet_data, ivec2(i, 0), 0);
		vec4 b = texelFetch(packet_data, ivec2(i, 1), 0);
		vec2 dir = normalize(b.xy);
		vec2 side = vec2(-dir.y, dir.x);
		vec2 rel = world_xz - a.xy;
		float along = dot(rel, dir);
		float across = dot(rel, side);
		float radius = max(b.z, 0.1);
		float cross_radius = radius * 0.62;
		float envelope = exp(-0.5 * (along * along / (radius * radius)
			+ across * across / (cross_radius * cross_radius)));
		// One compact wavelet, not a repeated stripe train. A small vortical
		// phase warp lets the pocket morph as it is transported without losing
		// its persistent world-space identity.
		float warped_along = along + sin(across / radius * 3.14159265 + b.w)
			* a.w * 0.12;
		float warped_across = across + sin(along / radius * 2.1 - b.w * 0.7)
			* a.w * 0.08;
		float carrier_phase = 6.2831853 * warped_along / a.w + b.w;
		float cross_phase = carrier_phase * 0.63
			+ warped_across / (a.w * 0.6) * 3.14159265 - b.w * 0.4;
		// Morlet-style wave particle: a few locally windowed, vortically warped
		// crests. It cannot become either a closed refraction bubble or an
		// infinite streak train because the Gaussian envelope is compact.
		float carrier = (sin(carrier_phase) + 0.28 * sin(cross_phase)) * 0.78;
		height += a.z * carrier * envelope;
		float steepness = abs(cos(carrier_phase)) * 6.2831853 / a.w
			* a.z * envelope;
		breaking += envelope * smoothstep(0.11, 0.22, steepness);
	}
	height = clamp(height, -0.48, 0.48);
	COLOR = vec4(height + 0.5, clamp(breaking, 0.0, 1.0), 0.0, 1.0);
}
