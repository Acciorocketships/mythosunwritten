// Terrain category overlay (debug, F9). A screen-space decal: every opaque
// pixel is reprojected to world space and coloured by the terrain field's
// own classification, so the view shows what the field decided under the
// terrain mesh, the slope sheet and rocks alike.
//
// Per cell the data texture holds (surface height, graded flag). The shader
// repeats TerrainSurfaceField's kernel (edge controls, slope-connected corner
// controls, smootherstep quadrant patch) to colour each edge band by its
// category and to measure how far the rendered surface deviates from that
// kernel (the slope envelope, bedrock, rocks, cuts).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D cells : filter_nearest, repeat_disable;
uniform ivec2 origin_cell;
uniform int cells_size = 64;
uniform float tile = 24.0;
uniform float storey_height = 4.0;
uniform float strength = 0.6;

const vec3 C_FLAT = vec3(0.55, 0.55, 0.55);
const vec3 C_LEVEL = vec3(0.15, 0.45, 1.0);   // same storey, 1-3 m level step
const vec3 C_SLOPE = vec3(0.1, 0.85, 0.2);    // one storey
const vec3 C_CLIFF = vec3(1.0, 0.1, 0.1);     // two or more storeys: wall
const vec3 C_RAISED = vec3(1.0, 0.1, 0.9);    // rendered above the kernel (envelope, rocks)
const vec3 C_CUT = vec3(0.0, 0.9, 0.9);       // rendered below the kernel (cuts, recesses)
const vec3 C_GRADED = vec3(0.95, 0.85, 0.2);  // town / road grade

vec2 data(ivec2 c) {
	ivec2 t = c - origin_cell;
	if (t.x < 0 || t.y < 0 || t.x >= cells_size || t.y >= cells_size) {
		return vec2(-1e6, 0.0);
	}
	return texelFetch(cells, t, 0).rg;
}
float hgt(ivec2 c) { return data(c).r; }
int storey(ivec2 c) { return int(floor(hgt(c) / storey_height + 1e-4)); }
bool cliff_edge(ivec2 a, ivec2 d) { return abs(storey(a) - storey(a + d)) >= 2; }

float corner_control(ivec2 c, int sx, int sz, float h) {
	ivec2 ring[4] = ivec2[4](c, c + ivec2(sx, 0), c + ivec2(sx, sz), c + ivec2(0, sz));
	bool linked[4];
	for (int i = 0; i < 4; i++) {
		linked[i] = !cliff_edge(ring[i], ring[(i + 1) % 4] - ring[i]);
	}
	float corner = h;
	for (int k = 1; k < 4; k++) {
		if (!linked[k - 1]) break;
		corner = min(corner, hgt(ring[k]));
	}
	for (int k = 3; k > 0; k--) {
		if (!linked[k]) break;
		corner = min(corner, hgt(ring[k]));
	}
	return corner;
}

// Edge-midpoint control: a slope edge takes the pairwise minimum, a cliff
// edge keeps the owner's own height (TerrainSurfaceField._edge_control).
float edge_control(ivec2 c, ivec2 d, float h) {
	if (!cliff_edge(c, d)) return min(h, hgt(c + d));
	return h;
}

float smootherstep01(float x) {
	x = clamp(x, 0.0, 1.0);
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
}

vec3 edge_colour(ivec2 c, ivec2 d, float h) {
	float hn = hgt(c + d);
	int ds = abs(storey(c) - storey(c + d));
	if (ds >= 2) return C_CLIFF;
	if (ds == 1) return C_SLOPE;
	if (abs(h - hn) > 0.01) return C_LEVEL;
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
	ivec2 c = ivec2(round(p.xz / tile));
	vec2 own = data(c);
	if (own.r < -1e5) discard;
	float h = own.r;
	vec2 l = p.xz - vec2(c) * tile;
	ivec2 sgn = ivec2(l.x >= 0.0 ? 1 : -1, l.y >= 0.0 ? 1 : -1);
	float half_tile = tile * 0.5;
	float a = smootherstep01(abs(l.x) / half_tile);
	float b = smootherstep01(abs(l.y) / half_tile);
	float ex = edge_control(c, ivec2(sgn.x, 0), h);
	float ez = edge_control(c, ivec2(0, sgn.y), h);
	float corner = corner_control(c, sgn.x, sgn.y, h);
	float kernel = mix(mix(h, ex, a), mix(ez, corner, a), b);
	vec3 col_x = edge_colour(c, ivec2(sgn.x, 0), h);
	vec3 col_z = edge_colour(c, ivec2(0, sgn.y), h);
	// Bands: each edge's colour fills the part of the quadrant whose height
	// that edge controls (smootherstep weight); the plateau centre stays grey.
	float bx = smoothstep(0.3, 0.55, abs(l.x) / half_tile);
	float bz = smoothstep(0.3, 0.55, abs(l.y) / half_tile);
	// The stronger edge owns the colour (a thin blend at the quadrant
	// diagonal): averaging orange and green read as the grade's yellow.
	vec3 band = mix(col_z, col_x, smoothstep(-0.04, 0.04, bx - bz));
	vec3 col = mix(C_FLAT, band, max(bx, bz));
	float alpha = strength;
	if (own.g > 0.5) {
		// Diagonal stripes: no blend of category colours can imitate them.
		float stripe = step(0.5, fract((p.x + p.z) / 3.0));
		col = mix(col, C_GRADED, 0.45 + 0.4 * stripe);
	} else {
		float dev = p.y - kernel;
		col = mix(col, C_RAISED, smoothstep(0.15, 1.0, dev));
		col = mix(col, C_CUT, smoothstep(0.15, 1.0, -dev));
	}
	// Contours: thin lines every metre (levels), bold every storey.
	float fw = max(fwidth(p.y), 0.002);
	float metre = abs(fract(p.y + 0.5) - 0.5) / fw;
	float st = abs(fract(p.y / storey_height + 0.5) - 0.5) * storey_height / fw;
	col = mix(col, vec3(0.05), (1.0 - smoothstep(0.5, 1.5, metre)) * 0.6);
	col = mix(col, vec3(1.0), 1.0 - smoothstep(1.0, 2.5, st));
	// Cell boundaries.
	vec2 edge_d = half_tile - abs(l);
	float gw = max(fwidth(p.x) + fwidth(p.z), 0.01);
	float grid = min(edge_d.x, edge_d.y) / gw;
	col = mix(col, vec3(0.1, 0.1, 0.1), (1.0 - smoothstep(0.5, 1.5, grid)) * 0.8);
	// Terrain mesh chunk borders (192 m): each chunk meshes its own sheet.
	vec2 chunk_d = (0.5 - abs(fract(p.xz / (tile * 8.0)) - 0.5)) * tile * 8.0;
	float chunk_line = min(chunk_d.x, chunk_d.y) / gw;
	col = mix(col, vec3(0.1, 0.2, 1.0), (1.0 - smoothstep(1.0, 3.0, chunk_line)));
	ALBEDO = col;
	ALPHA = alpha;
}
