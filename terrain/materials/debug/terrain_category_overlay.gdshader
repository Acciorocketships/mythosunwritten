// Terrain category overlay (debug, F9). A screen-space decal: every opaque
// pixel is reprojected to world space and coloured by the terrain field's
// own classification, so the view shows what the field decided under the
// terrain mesh, the slope sheet and rocks alike.
//
// Per 12 m lattice point the data texture holds (surface height, graded
// flag). terrain_tile_kernel.gdshaderinc is the GPU port of TerrainTileField.
// Each 12 m TILE (the square between four points) is filled by its type, the
// strongest category among its four edges (flat < level < slope < cliff; a
// tile mixing a cliff edge with a slope or level edge is a cliff END), and
// every lattice edge is drawn as a line in its own category. Where the
// rendered surface leaves the tile kernel (the cliff sheet, bedrock, rocks,
// cuts) it is hatched, so the tile colour stays readable underneath.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

#include "res://terrain/materials/debug/terrain_tile_kernel.gdshaderinc"

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float strength = 0.6;
// Lattice points per terrain chunk side (TerrainChunkMesher.POINTS_PER_CHUNK).
uniform float chunk_points = 16.0;

const vec3 C_FLAT = vec3(0.55, 0.55, 0.55);
const vec3 C_LEVEL = vec3(0.15, 0.45, 1.0);   // same storey, 1 m level step
const vec3 C_SLOPE = vec3(0.1, 0.85, 0.2);    // one storey
const vec3 C_CLIFF = vec3(1.0, 0.1, 0.1);     // two or more storeys: wall
const vec3 C_CLIFF_END = vec3(0.55, 0.2, 0.05); // brown: a cliff edge and a slope/level edge in one tile
const vec3 C_RAISED = vec3(1.0, 0.1, 0.9);    // rendered above the kernel (cliff sheet, rocks)
const vec3 C_CUT = vec3(0.0, 0.9, 0.9);       // rendered below the kernel (cuts, recesses)
const vec3 C_GRADED = vec3(0.95, 0.85, 0.2);  // town / road grade
const vec3 C_WALL_LINE = vec3(1.0, 0.75, 0.55);

vec3 category_colour(int category) {
	if (category == EDGE_CLIFF) return C_CLIFF;
	if (category == EDGE_SLOPE) return C_SLOPE;
	if (category == EDGE_LEVEL) return C_LEVEL;
	return C_FLAT;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).x;
	if (depth <= 0.0) discard;   // sky (reverse z)
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	vec3 p = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	float kernel = tile_kernel(p.xz);
	if (kernel < -1e5) discard;
	ivec2 tile = ivec2(floor(p.xz / spacing));
	int eb = lattice_edge_category(tile, ivec2(1, 0));
	int et = lattice_edge_category(tile + ivec2(0, 1), ivec2(1, 0));
	int el = lattice_edge_category(tile, ivec2(0, 1));
	int er = lattice_edge_category(tile + ivec2(1, 0), ivec2(0, 1));
	int strongest = max(max(eb, et), max(el, er));
	bool end = strongest == EDGE_CLIFF && (eb == EDGE_SLOPE || et == EDGE_SLOPE || el == EDGE_SLOPE
		|| er == EDGE_SLOPE || eb == EDGE_LEVEL || et == EDGE_LEVEL || el == EDGE_LEVEL || er == EDGE_LEVEL);
	vec3 col = end ? C_CLIFF_END : category_colour(strongest);
	float alpha = strength;
	float gw = max(fwidth(p.x) + fwidth(p.z), 0.01);
	ivec2 owner = ivec2(floor(p.xz / spacing + 0.5));
	if (point_data(owner).g > 0.5) {
		// Diagonal stripes: no blend of category colours can imitate them.
		float stripe = step(0.5, fract((p.x + p.z) / 3.0));
		col = mix(col, C_GRADED, 0.45 + 0.4 * stripe);
	} else {
		// Hatched the other way, so the tile type stays visible underneath.
		float dev = p.y - kernel;
		float hatch = step(0.45, fract((p.x - p.z) / 1.5));
		col = mix(col, C_RAISED, smoothstep(0.15, 1.0, dev) * (0.35 + 0.6 * hatch));
		col = mix(col, C_CUT, smoothstep(0.15, 1.0, -dev) * (0.35 + 0.6 * hatch));
	}
	// Contours: thin lines every metre (levels), bold every storey.
	float fw = max(fwidth(p.y), 0.002);
	float metre = abs(fract(p.y + 0.5) - 0.5) / fw;
	float st = abs(fract(p.y / storey_height + 0.5) - 0.5) * storey_height / fw;
	col = mix(col, vec3(0.05), (1.0 - smoothstep(0.5, 1.5, metre)) * 0.6);
	col = mix(col, vec3(1.0), 1.0 - smoothstep(1.0, 2.5, st));
	// Lattice edges (the tile grid, x, z = 12 i): each edge drawn in its own
	// category, darkened.
	vec2 lattice_d = abs(fract(p.xz / spacing + 0.5) - 0.5) * spacing;
	int along_z = lattice_edge_category(ivec2(int(round(p.x / spacing)), tile.y), ivec2(0, 1));
	int along_x = lattice_edge_category(ivec2(tile.x, int(round(p.z / spacing))), ivec2(1, 0));
	vec3 line_col = category_colour(lattice_d.x < lattice_d.y ? along_z : along_x) * 0.55;
	float grid = min(lattice_d.x, lattice_d.y) / gw;
	col = mix(col, line_col, 1.0 - smoothstep(1.5, 3.0, grid));
	// Wall lines: the dual-cell borders (x, z = 12 i + 6) where walls stand.
	vec2 wall_d = abs(fract(p.xz / spacing) - 0.5) * spacing;
	float wall_line = min(wall_d.x, wall_d.y) / gw;
	col = mix(col, C_WALL_LINE, (1.0 - smoothstep(0.5, 1.5, wall_line)) * 0.35);
	// Terrain mesh chunk borders (192 m): each chunk meshes its own sheet.
	float chunk = spacing * chunk_points;
	vec2 chunk_d = (0.5 - abs(fract(p.xz / chunk) - 0.5)) * chunk;
	float chunk_line = min(chunk_d.x, chunk_d.y) / gw;
	col = mix(col, vec3(0.1, 0.2, 1.0), (1.0 - smoothstep(1.0, 3.0, chunk_line)));
	ALBEDO = col;
	ALPHA = alpha;
}
