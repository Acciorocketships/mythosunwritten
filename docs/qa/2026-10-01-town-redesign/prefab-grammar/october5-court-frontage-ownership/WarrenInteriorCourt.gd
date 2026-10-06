extends RefCounted


## Select a supported interior terrace and reserve its inhabited sides before
## the climb. The carver proves a level entrance or rolls back this proposal
## completely. The ordinary court reservation owns the admitted deck.
static func propose(context: Dictionary) -> Dictionary:
	var massif: WarrenMassif = context.massif
	var profile: WarrenVillageScaleProfile = context.profile
	if profile.scaled(WarrenPlotReservations.DECK_MAX) < 9:
		return {}
	var seed_value := int(context.world_seed)
	var empty := WarrenMazeSourcePlan.new(
		seed_value, profile, massif, WarrenExcavation.new(seed_value)
	)
	var blocked := WarrenPlotPlanner.blocked_columns(empty)
	var candidates: Array[Dictionary] = []
	var max_floor := (
		int(context.portal.y) + (profile.route_cell_range.y - int(context.market_cells) - 3) / 2
	)
	for anchor: Vector2i in massif.columns:
		var cells := WarrenPlotReservations._plaza_footprint(empty, anchor, Vector2i(3, 3), blocked)
		if cells.is_empty():
			continue
		var low := maxi(int(context.portal.y) + int(context.span_goal), 2)
		var high := max_floor
		var ring := 1000
		for c: Vector2i in cells:
			low = maxi(low, massif.bearing_at(c))
			high = mini(high, massif.top_at(c))
			ring = mini(ring, massif.ring_depth(c))
		if ring < 3:
			continue
		for floor_band in range(low, high + 1):
			var cost := 0
			var valid := true
			for c: Vector2i in cells:
				if not WarrenPlotReservations._deck_column_ok(empty, c, floor_band, {}, blocked, 6):
					valid = false
					break
				cost += absi(massif.top_at(c) - floor_band)
			if not valid or cost > 27:
				continue
			var houses := WarrenPlotReservations._plaza_house_columns(
				empty, cells, floor_band, {}, blocked
			)
			for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
				var entrance := Vector3i(
					anchor.x + 1 + 2 * direction.x, floor_band, anchor.y + 1 + 2 * direction.y
				)
				var radius := Vector2(entrance.x, entrance.z).distance_to(context.crown)
				if not WarrenMazeCarver._summit_reaches_crown(
					massif, entrance, radius, context.inner_radius
				):
					continue
				if not WarrenPassageLatticeRules.slot_is_borable(
					massif,
					empty.excavation,
					entrance,
					WarrenPassageLatticeRules.HEADROOM_BANDS,
					true
				):
					continue
				var held := houses.duplicate()
				held.erase(Vector2i(entrance.x, entrance.z))
				var sides := 0
				for d: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
					var n := 0
					for c: Vector2i in cells:
						if not cells.has(c + d) and held.has(c + d):
							n += 1
					if n >= 2:
						sides += 1
				if sides < 3:
					continue
				candidates.append(
					{
						"cells": cells,
						"floor": floor_band,
						"entrance": entrance,
						"houses": held,
						"ring": ring,
						"cost": cost,
						"sides": sides,
						"tie": WarrenPassageLatticeRules.hash_key(seed_value, 0xCA71, entrance, 0)
					}
				)
	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if a.floor != b.floor:
				return a.floor < b.floor
			if a.sides != b.sides:
				return a.sides > b.sides
			if a.cost != b.cost:
				return a.cost < b.cost
			return a.tie < b.tie
	)
	if candidates.is_empty():
		return {}
	var site: Dictionary = candidates[0]
	for c: Vector2i in (site.cells as Array) + site.houses.keys():
		for band in range(
			int(site.floor) - 1, int(site.floor) + WarrenMazeSourcePlan.MIN_HOUSE_BANDS
		):
			context.excavation.construction_reservations[Vector3i(c.x, band, c.y)] = true
	return site
