#ifndef BIOME_SURFACE_INCLUDED
#define BIOME_SURFACE_INCLUDED
global uniform sampler2D biome_surface_map;
global uniform vec2 biome_ground_origin;
// RG: dampness and leaf transmission. Numeric linear data, on the same 48m
// lattice as the substrate. Unbound study scenes retain the dry material.
vec2 biome_surface(vec2 world_xz) {
	vec2 uv = ((world_xz - biome_ground_origin) / 48.0 + 0.5) / 65.0;
	vec4 response = texture(biome_surface_map, uv);
	return response.rg * response.a;
}
vec2 substrate_finish(vec2 world_xz, float normal_up) {
	float damp = biome_surface(world_xz).r;
	float patches = 0.75 + 0.25 * sin(world_xz.x * 0.053) * sin(world_xz.y * 0.059);
	damp *= patches * mix(0.5, 1.0, clamp(normal_up, 0.0, 1.0));
	// Broad soft highlights only; dry stone stays matte and recognizably stone.
	return vec2(1.0 - 0.62 * damp, 0.38 * damp);
}
#endif
