class_name TerrainField
extends RefCounted

## The natural terrain height in metres (spec 2026-10-02 §2, revised after the
## owner's first visual review):
##   H = base + continental + setpieces + features.raise - features.cut
##       + texture relief * (1 - 0.7 setpiece_mask)
## evaluated per blended regime (each applying its own storey-aligned terrace),
## summed with the regime weights from TerrainRegimeField.sample, then passed
## through a soft ceiling under REF_AMPLITUDE.
## - continental: a 1.3-2.6 km undulation (0..CONTINENTAL_M) so whole areas of
##   the map sit higher or lower; faded out round spawn.
## - features: LandformFeatures, the mid-scale structured landforms (hills,
##   peak clusters, ridges, mesas, basins with islands, valleys...).
## include_detail=false is the smooth field rivers trace: everything above
## except fine texture and terraces.

const REF_AMPLITUDE := TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE
const SETPIECE_RELIEF_SUPPRESSION := 0.7
const CONTINENTAL_M := 28.0
## Heights above SOFT_CEILING approach REF_AMPLITUDE asymptotically.
const SOFT_CEILING := 112.0


static func continental_m(seed: int, p: Vector2) -> float:
	var n := 0.65 * ReliefPrimitives.vnoise01(p, seed + 1701, 2600.0) \
		+ 0.35 * ReliefPrimitives.vnoise01(p.rotated(0.9), seed + 1702, 1300.0)
	var spawn_fade := smoothstep(600.0, 1800.0, p.length())
	return CONTINENTAL_M * smoothstep(0.2, 0.8, n) * spawn_fade


static func height_m(p: Vector2, seed: int, include_detail: bool) -> float:
	var sp := LandformSetpieces.sample(seed, p)
	var f := LandformFeatures.sample(seed, p, include_detail)
	var h := TerrainRegimeField.base_m(seed, p) + continental_m(seed, p) + sp.x + f.x - f.y
	var keep := 1.0 - SETPIECE_RELIEF_SUPPRESSION * sp.y
	var out := 0.0
	for pair: Array in TerrainRegimeField.sample(seed, p):
		var region: Dictionary = pair[0]
		var hr := h + RegimeRelief.relief_m(region, p, include_detail) * keep
		out += float(pair[1]) * (_terraced(hr, RegimeRelief.terrace_of(region)) if include_detail else hr)
	return soft_ceiling(out)


static func soft_ceiling(h: float) -> float:
	if h <= SOFT_CEILING:
		return h
	var room := REF_AMPLITUDE - SOFT_CEILING
	return SOFT_CEILING + room * tanh((h - SOFT_CEILING) / room)


static func _terraced(h: float, t: Vector2) -> float:
	return h if t.x <= 0.0 else ReliefPrimitives.terrace(h, t.x, t.y)
