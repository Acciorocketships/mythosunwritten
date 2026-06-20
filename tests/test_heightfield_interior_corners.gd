extends GutTest

# ------------------------------------------------------------
# Interior-corner invariant (reported bug)
# ------------------------------------------------------------
# Claim under test: any cliff tile that has two ORTHOGONAL cliff neighbours at the
# same storey, while the DIAGONAL between those two neighbours is NOT a cliff tile
# at that storey (it drops), must be an interior-corner ("inner-corner") variant.
# A center/side/etc. tile there leaves a visible gap.

const _AMPLITUDE: float = 56.0
const _MAX_STOREYS: int = 12
const _SEED: int = 4242
const _CENTER := Vector2i(0, 0)  # spans the falloff transition: storeys 0..~6 like the report
const _RADIUS: int = 42

# orthogonal cardinal pairs and the diagonal cell between them.
const _CORNERS: Array = [
	[Vector2i(0, -1), Vector2i(1, 0), Vector2i(1, -1)],   # front, right -> frontright
	[Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)],     # back,  right -> backright
	[Vector2i(0, 1), Vector2i(-1, 0), Vector2i(-1, 1)],   # back,  left  -> backleft
	[Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, -1)], # front, left  -> frontleft
]


func test_interior_corners_are_inner_corner_variants() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(_SEED, _AMPLITUDE, _MAX_STOREYS, "mean")
	var region: HeightfieldRegion = plan.compute_region(_CENTER.x, _CENTER.y, _RADIUS)

	# Variant per cell over the inner area.
	var vmap: Dictionary = {}
	for dz in range(-_RADIUS, _RADIUS + 1):
		for dx in range(-_RADIUS, _RADIUS + 1):
			var c := Vector2i(_CENTER.x + dx, _CENTER.y + dz)
			vmap[c] = String(HeightfieldInstantiator.placement_for_cell(region, c.x, c.y)["variant_tag"])

	var pattern_count: int = 0
	var violations: Array = []
	for dz in range(-_RADIUS + 1, _RADIUS):
		for dx in range(-_RADIUS + 1, _RADIUS):
			var b := Vector2i(_CENTER.x + dx, _CENTER.y + dz)
			var sb: int = region.storey_at(b.x, b.y)
			if sb < 1:
				continue  # not a cliff tile
			for corner in _CORNERS:
				var c1: Vector2i = b + corner[0]
				var c2: Vector2i = b + corner[1]
				var d: Vector2i = b + corner[2]
				# Two orthogonal cliff neighbours at B's storey; diagonal drops below it.
				if region.storey_at(c1.x, c1.y) != sb:
					continue
				if region.storey_at(c2.x, c2.y) != sb:
					continue
				if region.storey_at(d.x, d.y) >= sb:
					continue
				pattern_count += 1
				if not String(vmap[b]).contains("inner-corner"):
					violations.append("%s s%d.L%d -> %s (diagonal %s drops)" % [
						b, sb, region.level_at(b.x, b.y), vmap[b], corner[2]])

	gut.p("interior-corner pattern occurrences: %d, violations: %d" % [pattern_count, violations.size()])
	for v in violations.slice(0, 12):
		gut.p("  VIOLATION: " + v)
	assert_gt(pattern_count, 0, "the interior-corner pattern must actually occur in the sampled region")
	assert_eq(violations.size(), 0, "every interior corner is an inner-corner variant")
