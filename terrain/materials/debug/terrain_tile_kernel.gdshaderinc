// GPU port of TerrainTileField's 12 m tile kernel (dual-grid terrain tiles,
// docs/superpowers/specs/2026-09-30-dual-grid-terrain-tiles-design.md), for
// debug views that compare the rendered ground with the field. It must stay a
// line-for-line port of TerrainTileField.eval_params / _layer / _profile /
// _step: tests/test_september28_category_overlay.gd renders it on the GPU and
// compares every sample with the CPU kernel.
//
// Input: `points`, one texel per lattice point (R = surface height, G = town
// graded flag), texel (0, 0) = lattice point `origin_point`. Missing points
// hold a height below -1e5.

uniform sampler2D points : filter_nearest, repeat_disable;
uniform ivec2 origin_point;
uniform int points_size = 128;
uniform float spacing = 12.0;
uniform float storey_height = 4.0;
// TerrainTileField.CliffEnd: 0 = E1 (blend inside the tile), 1 = E2 (full wall
// to the tile centre, then it shortens to nothing over the slope half).
uniform int cliff_end = 1;

const float TILE_NO_DATA = -1e6;

vec2 point_data(ivec2 p) {
	ivec2 t = p - origin_point;
	if (t.x < 0 || t.y < 0 || t.x >= points_size || t.y >= points_size) {
		return vec2(TILE_NO_DATA, 0.0);
	}
	return texelFetch(points, t, 0).rg;
}

float point_height(ivec2 p) { return point_data(p).r; }
bool point_missing(ivec2 p) { return point_height(p) < -1e5; }
int point_storey(ivec2 p) { return int(floor(point_height(p) / storey_height + 1e-4)); }

// TerrainTileField.EdgeCategory of the lattice edge p -> p + d.
const int EDGE_FLAT = 0;
const int EDGE_LEVEL = 1;
const int EDGE_SLOPE = 2;
const int EDGE_CLIFF = 3;

int lattice_edge_category(ivec2 p, ivec2 d) {
	int ds = abs(point_storey(p) - point_storey(p + d));
	if (ds >= 2) return EDGE_CLIFF;
	if (ds == 1) return EDGE_SLOPE;
	if (abs(point_height(p) - point_height(p + d)) > 1e-4) return EDGE_LEVEL;
	return EDGE_FLAT;
}

float lattice_cliff(ivec2 p, ivec2 d) {
	return abs(point_storey(p) - point_storey(p + d)) >= 2 ? 1.0 : 0.0;
}

float tile_smootherstep(float t) {
	t = clamp(t, 0.0, 1.0);
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float tile_step(float t, int side) {
	if (t > 0.5) return 1.0;
	if (t < 0.5) return 0.0;
	return side < 0 ? 0.0 : 1.0;
}

float tile_profile(float t, float k0, float k1, float s, int side) {
	float k;
	if (cliff_end == 0 || k0 == k1) {
		k = mix(k0, k1, s);
	} else if (k0 > k1) {   // cliff at s = 0: full wall to the centre, then it shortens
		k = tile_smootherstep(clamp((0.8 - s) / 0.3, 0.0, 1.0));   // TerrainTileField.CLIFF_END_CLEAR = 0.2
	} else {
		k = tile_smootherstep(clamp((s - 0.2) / 0.3, 0.0, 1.0));
	}
	if (k >= 1.0) return tile_step(t, side);
	if (k <= 0.0) return tile_smootherstep(t);
	return mix(tile_smootherstep(t), tile_step(t, side), k);
}

bool tile_saddle_at(vec4 h, float t) {
	bool b0 = h.x >= t;
	bool b1 = h.y >= t;
	return b0 != b1 && b0 == (h.z >= t) && b1 == (h.w >= t);
}

bool tile_has_saddle_layer(vec4 h) {
	return tile_saddle_at(h, h.x) || tile_saddle_at(h, h.y)
		|| tile_saddle_at(h, h.z) || tile_saddle_at(h, h.w);
}

// cl4 = cliff flags (bottom a-b, right b-c, top d-c, left a-d).
float tile_layer(bool ba, bool bb, bool bc, bool bd, vec4 cl4, float u, float v, ivec2 side) {
	bool xb = ba != bb;
	bool xt = bd != bc;
	bool xl = ba != bd;
	bool xr = bb != bc;
	bool any_slope = (xb && cl4.x < 1.0) || (xt && cl4.z < 1.0)
		|| (xl && cl4.w < 1.0) || (xr && cl4.y < 1.0);
	float idle = any_slope ? 0.0 : 1.0;
	float kb = xb ? cl4.x : idle;
	float kt = xt ? cl4.z : idle;
	float kl = xl ? cl4.w : idle;
	float kr = xr ? cl4.y : idle;
	float pu = tile_profile(u, kb, kt, v, side.x);
	float pv = tile_profile(v, kl, kr, u, side.y);
	float a = ba ? 1.0 : 0.0;
	float b = bb ? 1.0 : 0.0;
	float c = bc ? 1.0 : 0.0;
	float d = bd ? 1.0 : 0.0;
	if (ba == bc && bb == bd && ba != bb) {
		// Saddle: the low diagonal connects, the two high corners are separate bumps.
		if (ba) return max((1.0 - pu) * (1.0 - pv), pu * pv);
		return max(pu * (1.0 - pv), (1.0 - pu) * pv);
	}
	return mix(mix(a, b, pu), mix(d, c, pu), pv);
}

// h = corner heights a(0,0) b(1,0) c(1,1) d(0,1); cl4 as tile_layer.
float tile_eval(vec4 h, vec4 cl4, float u, float v, ivec2 side) {
	float lo = min(min(h.x, h.y), min(h.z, h.w));
	float hi = max(max(h.x, h.y), max(h.z, h.w));
	if (hi - lo <= 0.0) return lo;
	if (cl4.x + cl4.y + cl4.z + cl4.w == 0.0 && !tile_has_saddle_layer(h)) {
		float su = tile_smootherstep(u);
		float sv = tile_smootherstep(v);
		return mix(mix(h.x, h.y, su), mix(h.w, h.z, su), sv);
	}
	float result = lo;
	float prev = lo;
	for (int n = 0; n < 4; n++) {
		float t = 1e30;
		if (h.x > prev && h.x < t) t = h.x;
		if (h.y > prev && h.y < t) t = h.y;
		if (h.z > prev && h.z < t) t = h.z;
		if (h.w > prev && h.w < t) t = h.w;
		if (t == 1e30) break;
		result += (t - prev) * tile_layer(h.x >= t, h.y >= t, h.z >= t, h.w >= t, cl4, u, v, side);
		prev = t;
	}
	return result;
}

// Kernel height at world xz (the tile containing it; a midline resolves by
// the high-side rule, TerrainTileField's side = ZERO). TILE_NO_DATA when a
// corner is outside the loaded window.
float tile_kernel(vec2 xz) {
	ivec2 i = ivec2(floor(xz / spacing));
	vec2 uv = xz / spacing - vec2(i);
	ivec2 pa = i;
	ivec2 pb = i + ivec2(1, 0);
	ivec2 pc = i + ivec2(1, 1);
	ivec2 pd = i + ivec2(0, 1);
	if (point_missing(pa) || point_missing(pb) || point_missing(pc) || point_missing(pd)) {
		return TILE_NO_DATA;
	}
	vec4 h = vec4(point_height(pa), point_height(pb), point_height(pc), point_height(pd));
	vec4 cl4 = vec4(lattice_cliff(pa, ivec2(1, 0)), lattice_cliff(pb, ivec2(0, 1)),
		lattice_cliff(pd, ivec2(1, 0)), lattice_cliff(pa, ivec2(0, 1)));
	return tile_eval(h, cl4, clamp(uv.x, 0.0, 1.0), clamp(uv.y, 0.0, 1.0), ivec2(0));
}
