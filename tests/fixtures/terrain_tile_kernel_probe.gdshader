// Test probe for terrain_tile_kernel.gdshaderinc (the F9 overlay's GPU port of
// TerrainTileField). Each output pixel evaluates the kernel at the world xz of
// its `samples` texel and reports whether it matches the CPU height there.
// Outputs are 0/1 only, so neither colour space nor 8-bit storage matters:
// R = match, G = pixel x parity, B = pixel y parity (a mapping check).
shader_type canvas_item;

#include "res://terrain/materials/debug/terrain_tile_kernel.gdshaderinc"

uniform sampler2D samples : filter_nearest, repeat_disable;   // x, z, CPU height, unused
uniform int probe_size = 64;
uniform float tolerance = 0.01;

void fragment() {
	ivec2 px = clamp(ivec2(floor(UV * float(probe_size))), ivec2(0), ivec2(probe_size - 1));
	vec4 s = texelFetch(samples, px, 0);
	float k = tile_kernel(s.xy);
	COLOR = vec4(abs(k - s.z) < tolerance ? 1.0 : 0.0, float(px.x % 2), float(px.y % 2), 1.0);
}
