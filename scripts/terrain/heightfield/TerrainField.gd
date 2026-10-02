class_name TerrainField
extends RefCounted

## The natural terrain height in metres (spec 2026-10-02 §2):
##   H = base + setpieces + relief * (1 - 0.7 setpiece_mask), evaluated per
##   blended regime (each applying its own storey-aligned terrace) and summed
##   with the regime weights from TerrainRegimeField.sample.
## include_detail=false is the smooth field rivers trace: base + setpieces +
## each regime's macro relief (RegimeRelief detail=false), without terraces.

const REF_AMPLITUDE := TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE
const SETPIECE_RELIEF_SUPPRESSION := 0.7


static func height_m(p: Vector2, seed: int, include_detail: bool) -> float:
	var sp := LandformSetpieces.sample(seed, p)
	var h := TerrainRegimeField.base_m(seed, p) + sp.x
	var keep := 1.0 - SETPIECE_RELIEF_SUPPRESSION * sp.y
	var out := 0.0
	for pair: Array in TerrainRegimeField.sample(seed, p):
		var region: Dictionary = pair[0]
		var hr := h + RegimeRelief.relief_m(region, p, include_detail) * keep
		out += float(pair[1]) * (_terraced(hr, RegimeRelief.terrace_of(region)) if include_detail else hr)
	return out


static func _terraced(h: float, t: Vector2) -> float:
	return h if t.x <= 0.0 else ReliefPrimitives.terrace(h, t.x, t.y)
