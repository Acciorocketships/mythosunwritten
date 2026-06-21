# scripts/terrain/tools/SlopeVariantLayout.gd
# Maps each cliff variant's edge/corner exposure to a NxN grid of slope
# components. Derived from the original terrain/scenes/Cliff*.tscn geometry.
class_name SlopeVariantLayout
extends RefCounted

# Grid cell centers. The slope band is exactly one cell wide, so this is tied to
# the component mesh size in SlopeMeshGenerator (12u cells -> a 2x2 grid / 50%
# band). layout() is index-generic for any N, but changing N here also requires
# re-dimensioning those component meshes — it is N=2 by construction.
const CENTERS := [-6.0, 6.0]   # cell centers at +/-6 (12u cells, 24u tile)
# edges: set of {"front","back","left","right"}; corners: set of {"FL","FR","BL","BR"}
const VARIANT_MASKS := {
	"CliffSide":              {"edges": ["front"], "inner": []},
	"CliffCorner":           {"edges": ["front", "left"], "inner": []},
	"CliffLine":             {"edges": ["front", "back"], "inner": []},
	"CliffPeninsula":        {"edges": ["front", "left", "back"], "inner": []},
	"CliffIsland":           {"edges": ["front", "back", "left", "right"], "inner": []},
	"CliffInCorner":         {"edges": [], "inner": ["FL"]},
	"CliffInCornerDiag":     {"edges": [], "inner": ["FL", "BR"]},
	"CliffInCornerSide":     {"edges": [], "inner": ["FL", "BL"]},
	"CliffInCornerThree":    {"edges": [], "inner": ["FL", "BL", "BR"]},
	"CliffInCornerAll":      {"edges": [], "inner": ["FL", "FR", "BL", "BR"]},
	"CliffInCornerEdge1":    {"edges": ["back"], "inner": ["FL"]},
	"CliffInCornerEdge2":    {"edges": ["right"], "inner": ["FL"]},
	"CliffInCornerEdgeBoth": {"edges": ["back", "right"], "inner": ["FL"]},
	"CliffInCornerSideEdge": {"edges": ["right"], "inner": ["FL", "BL"]},
}

# Stacked variant -> (base variant, component to swap, stacked component).
const STACKED_VARIANTS := {
	"CliffCornerStacked": {"base": "CliffCorner", "from": "outer", "to": "outer_stacked"},
	"CliffInCornerStacked": {"base": "CliffInCorner", "from": "inner", "to": "inner_stacked"},
}

# Layout for a stacked variant: the base layout with the target component swapped.
static func stacked_layout(name: String) -> Array:
	var spec: Dictionary = STACKED_VARIANTS[name]
	# Safe to mutate in place: layout() builds fresh cell dicts each call (no caching).
	var cells := layout(spec.base)
	for cell in cells:
		if cell.component == spec.from:
			cell.component = spec.to
	return cells

const EDGE_ANGLE := {"front": 0.0, "left": 90.0, "back": 180.0, "right": 270.0}
const CORNER_ANGLE := {"FL": 0.0, "BL": 90.0, "BR": 180.0, "FR": 270.0}

# col (x index) 0=left,last=right ; row (z index) 0=front,last=back
static func _corner_of(col: int, row: int, last: int) -> String:
	if col == 0 and row == 0: return "FL"
	if col == last and row == 0: return "FR"
	if col == 0 and row == last: return "BL"
	if col == last and row == last: return "BR"
	return ""

static func _edges_touching(col: int, row: int, last: int) -> Array:
	var e := []
	if row == 0: e.append("front")
	if row == last: e.append("back")
	if col == 0: e.append("left")
	if col == last: e.append("right")
	return e

static func layout(name: String) -> Array:
	var mask: Dictionary = VARIANT_MASKS[name]
	var slope_edges: Array = mask.edges
	var inner_corners: Array = mask.inner
	var n: int = CENTERS.size()
	var last: int = n - 1
	var cells := []
	for row in n:
		for col in n:
			var x: float = CENTERS[col]
			var z: float = CENTERS[row]
			var corner := _corner_of(col, row, last)
			var touching := _edges_touching(col, row, last)
			var slope_touch := []
			for e in touching:
				if e in slope_edges:
					slope_touch.append(e)
			var comp := "top"
			var ang := 0.0
			# Branch order assumes an inner corner never coincides with a slope
			# edge on the same cell (true for all 14 variants). If that ever
			# changes, the inner-corner case below would be shadowed by "edge".
			if corner != "" and slope_touch.size() == 2:
				comp = "outer"
				ang = CORNER_ANGLE[corner]
			elif slope_touch.size() >= 1:
				comp = "edge"
				ang = EDGE_ANGLE[slope_touch[0]]
			elif corner != "" and corner in inner_corners:
				comp = "inner"
				ang = CORNER_ANGLE[corner]
			cells.append({"component": comp, "angle_deg": ang, "x": x, "z": z})
	return cells
