extends RefCounted

## Frozen f3203d96 dictionary region compiler, independent performance/output oracle.
static func compute_region(plan: HeightfieldPlan, center_cx: int, center_cz: int, radius: int) -> HeightfieldRegion:
	var place_r: int = radius + 1
	var level_r: int = place_r + HeightfieldPlan.LEVELS_PER_STOREY
	var storey_final_r: int = level_r + HeightfieldPlan._CLIFF_SEARCH_MAX
	var storey_outer: int = storey_final_r + plan.max_storeys

	var targets: Dictionary = {}
	for dz in range(-storey_outer, storey_outer + 1):
		for dx in range(-storey_outer, storey_outer + 1):
			var cell: Vector2i = Vector2i(center_cx + dx, center_cz + dz)
			targets[cell] = plan.quantize_storey(plan._sample(cell.x, cell.y)[0])
	var storeys: Dictionary = HeightfieldPlan.clamp_field(targets, plan.max_step)

	var cliff_field: Dictionary = HeightfieldPlan._cliff_distance_field(storeys, HeightfieldPlan._CLIFF_SEARCH_MAX)
	var l0: Dictionary = {}
	# Retain substantial water-carve provenance for cliff-dressing corner
	# ownership. This flag never forces a vertical bank: the ordinary surface
	# classifier owns slopes and cliffs. Reuse the memoized amount here.
	var carved: Dictionary = {}
	for dz in range(-level_r, level_r + 1):
		for dx in range(-level_r, level_r + 1):
			var cell: Vector2i = Vector2i(center_cx + dx, center_cz + dz)
			var s: int = int(storeys[cell])
			var smp: Array = plan._sample(cell.x, cell.y)
			var residual: float = smp[0] - float(s) * HeightfieldPlan.STOREY_HEIGHT
			var detail: int = clampi(plan._round_mode(residual / HeightfieldPlan.LEVEL_HEIGHT), 0, HeightfieldPlan.LEVELS_PER_STOREY - 1)
			var cliff_cap: int = int(cliff_field.get(cell, HeightfieldPlan._NO_CLIFF)) - 1
			if HeightfieldPlan._has_diagonal_cliff(storeys, cell):
				cliff_cap = 0
			l0[cell] = clampi(mini(detail, cliff_cap), 0, HeightfieldPlan.LEVELS_PER_STOREY - 1)
			if smp[1] > 3.0:
				carved[cell] = true

	var levels: Dictionary = HeightfieldPlan._clamp_levels(l0, storeys)
	return HeightfieldRegion.new(storeys, levels, carved, plan)
