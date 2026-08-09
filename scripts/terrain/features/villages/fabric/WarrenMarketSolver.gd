class_name WarrenMarketSolver
extends RefCounted

## Proposes stocked prefab stalls along genuine terrain-level street boundaries.
## It does not decorate an accepted town after the fact: every returned unit is
## admitted only by rebuilding the complete fabric transaction.
const REQUIRED_MARKETS := 2
## The hard contract remains two so constrained terrain cannot erase an
## otherwise complete town. Exact composition nevertheless keeps admitting
## stocked stalls up to this target, turning spare ground frontage into a
## readable bazaar instead of leaving raw grass beneath the upper maze.
const TARGET_MARKETS := 6
## How many stall families ONE placement may put in front of the admission
## pass -- NOT how wide the pool is.
##
## Every candidate this function emits costs
## WarrenBuiltTownSolver._admit_markets a complete WarrenFabricCompiler.solve,
## whether that candidate is admitted or refused, so the candidate count
## multiplies the whole market pass. Emitting one candidate per family per
## placement made the pool's WIDTH a multiplier on SEARCH: the
## bake wave's 7 -> 20 widening tripled the list (931 -> 2660 on seed 7) and
## added 408 s to a 575 s mass-first detail solve, measured with
## `warren_mass_first_report.gd --stage timing`.
##
## The pool's width does not need to be a multiplier, because it is already a
## CHOICE: `_family` picks each placement's first family from the whole pool as
## a function of its origin and the world seed, so the window slides across all
## twenty entries within one town and shifts again between towns. Bounding the
## walk therefore costs variety nothing and restores the pre-wave candidate
## count exactly -- seven is the width the shipped pool itself had, so no
## placement is offered fewer alternatives than the reviewed code gave it.
const MAX_FAMILIES_PER_PLACEMENT := 7
const MARKET_MINIMUM := Vector3i(-2, 0, -1)
const MARKET_SIZE := Vector3i(4, 3, 2)


static func candidate_specs(program: SettlementFabricProgram,
		plan: SettlementFabricPlan, volume: WarrenVolumePlan,
		world_seed: int, open_core_columns: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if program == null or plan == null or not plan.is_sealed() \
			or plan.solid_void_plan == null or volume == null \
			or not volume.is_sealed():
		return out
	var seen: Dictionary = {}
	var primary_macro_cells: Dictionary = {}
	for primary_cell: Vector3i in volume.primary_itinerary:
		primary_macro_cells[primary_cell] = true
	var ground_streets := plan.surface_plan.cells_for_kind(
		PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET)
	var overhead_columns := _overhead_columns(plan)
	var mass_columns := _non_market_solid_columns(plan)
	var public_cells: Dictionary = {}
	for kind in PublicRealmSurfacePlan.SurfaceKind.size():
		for cell: Vector3i in plan.surface_plan.cells_for_kind(kind):
			public_cells[cell] = true
	for surface: Vector3i in ground_streets:
		var macro_surface := Vector3i(floori(float(surface.x) / 2.0),
			surface.y, floori(float(surface.z) / 2.0))
		var is_arcade := not primary_macro_cells.has(macro_surface)
		var is_undercroft := _is_sheltered_street(surface, overhead_columns)
		for side: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			if _has_public_neighbor(public_cells, surface, side):
				continue
			for placement: Dictionary in _candidate_placements(surface, side):
				var origin := placement.origin as Vector3i
				var yaw := int(placement.yaw_quarters)
				if not _bearing_follows_local_ground(origin, yaw, volume):
					continue
				# A stall is town fabric, not a camp: it must back onto or
				# flank real building mass. This removes the detached tent row
				# along the open approach road.
				if not _backs_onto_mass(origin, yaw, mass_columns):
					continue
				var first_family := _family(origin, world_seed)
				for family_offset in mini(MAX_FAMILIES_PER_PLACEMENT,
						SettlementFabricProgram.MARKET_STALLS.size()):
					var family := posmod(first_family + family_offset,
						SettlementFabricProgram.MARKET_STALLS.size())
					var recipe_id := StringName("market.stall.%02d" % family)
					if program.recipe(recipe_id) == null:
						continue
					var key := "%s/%s/r%d" % [recipe_id, origin, yaw]
					if seen.has(key):
						continue
					seen[key] = true
					var stable_id := StringName(
						"volume.market.%02d.%d.%d.%d.r%d" % [
							family, origin.x, origin.y, origin.z, yaw])
					out.append({
						"stable_id": stable_id,
						"family": family,
						"is_arcade": is_arcade,
						"is_undercroft": is_undercroft,
						"open_core_overlap": _open_core_overlap_count(origin,
							yaw, open_core_columns),
						"spec": SettlementFabricSolver.unit_spec(stable_id,
							recipe_id, origin, yaw),
					})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.open_core_overlap) != int(b.open_core_overlap):
			return int(a.open_core_overlap) > int(b.open_core_overlap)
		if bool(a.is_undercroft) != bool(b.is_undercroft):
			return bool(a.is_undercroft)
		if bool(a.is_arcade) != bool(b.is_arcade):
			return bool(a.is_arcade)
		var a_hash := _seeded_hash(String(a.stable_id), world_seed)
		var b_hash := _seeded_hash(String(b.stable_id), world_seed)
		return a_hash < b_hash if a_hash != b_hash \
			else String(a.stable_id) < String(b.stable_id))
	return out


static func _non_market_solid_columns(plan: SettlementFabricPlan) -> Dictionary:
	var out: Dictionary = {}
	for unit_value: FabricUnit in plan.units:
		if String(unit_value.stable_id).begins_with("volume.market."):
			continue
		var recipe_value := plan.recipe(unit_value.recipe_id)
		if recipe_value == null:
			continue
		for local_cell: Vector3i in recipe_value.solid_cells:
			var cell := FabricRecipe.transform_cell(local_cell,
				unit_value.lattice_origin, unit_value.yaw_quarters)
			var column := Vector2i(cell.x, cell.z)
			if not out.has(column):
				out[column] = [] as Array[int]
			(out[column] as Array[int]).append(cell.y)
	return out


static func _backs_onto_mass(origin: Vector3i, yaw: int,
		mass_columns: Dictionary) -> bool:
	var bounds := _rotated_footprint_bounds(yaw)
	for x in range(origin.x + int(bounds.min_x) - 2,
			origin.x + int(bounds.max_x) + 3):
		for z in range(origin.z + int(bounds.min_z) - 2,
				origin.z + int(bounds.max_z) + 3):
			for level_value: Variant in mass_columns.get(Vector2i(x, z),
					[]) as Array:
				if absi(int(level_value) - origin.y) <= 4:
					return true
	return false


static func _overhead_columns(plan: SettlementFabricPlan) -> Dictionary:
	## Stocked stalls are most useful where the upper town already makes a roof:
	## they turn the sheltered ground interval into a market alley and close a
	## long low sightline without pretending that decoration is structural mass.
	## The occluder cells are authored construction facts from the sealed plan.
	var out: Dictionary = {}
	for cell_value: Variant in plan.transformed_cells(&"occluder"):
		var cell := cell_value as Vector3i
		var column := Vector2i(cell.x, cell.z)
		if not out.has(column):
			out[column] = [] as Array[int]
		(out[column] as Array[int]).append(cell.y)
	return out


static func _is_sheltered_street(surface: Vector3i,
		overhead_columns: Dictionary) -> bool:
	var levels := overhead_columns.get(Vector2i(surface.x, surface.z), []) as Array
	for level_value: Variant in levels:
		var level := int(level_value)
		if level >= surface.y + 2 and level <= surface.y + 9:
			return true
	return false


static func _open_core_overlap_count(origin: Vector3i, yaw: int,
		open_core_columns: Dictionary) -> int:
	if open_core_columns.is_empty():
		return 0
	var touched: Dictionary = {}
	for local_cell: Vector3i in FabricRecipe.box_cells(
			MARKET_MINIMUM, Vector3i(MARKET_SIZE.x, 1, MARKET_SIZE.z)):
		var cell := FabricRecipe.transform_cell(local_cell, origin, yaw)
		var column := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		if open_core_columns.has(column):
			touched[column] = true
	return touched.size()


static func _has_public_neighbor(cells: Dictionary, surface: Vector3i,
		side: Vector3i) -> bool:
	for delta_y in [-1, 0, 1]:
		if cells.has(surface + side + Vector3i.UP * delta_y):
			return true
	return false


static func _candidate_placements(surface: Vector3i,
		side: Vector3i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var yaw := _yaw_toward_route(side)
	var footprint := _rotated_footprint_bounds(yaw)
	for tangent_offset in [-1, 0, -2, 1]:
		var origin := Vector3i(surface.x, surface.y, surface.z)
		if side.x < 0:
			origin.x = surface.x - 1 - int(footprint.max_x)
			origin.z = surface.z - int(footprint.center_z) + tangent_offset
		elif side.x > 0:
			origin.x = surface.x + 1 - int(footprint.min_x)
			origin.z = surface.z - int(footprint.center_z) + tangent_offset
		elif side.z < 0:
			origin.z = surface.z - 1 - int(footprint.max_z)
			origin.x = surface.x - int(footprint.center_x) + tangent_offset
		else:
			origin.z = surface.z + 1 - int(footprint.min_z)
			origin.x = surface.x - int(footprint.center_x) + tangent_offset
		out.append({"origin": origin, "yaw_quarters": yaw})
	return out


static func _bearing_follows_local_ground(origin: Vector3i, yaw: int,
		volume: WarrenVolumePlan) -> bool:
	for local_cell: Vector3i in FabricRecipe.box_cells(
			Vector3i(-2, 0, -1), Vector3i(4, 1, 2)):
		var cell := FabricRecipe.transform_cell(local_cell, origin, yaw)
		var column := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		if not volume.envelope.contains_column(column) \
				or volume.envelope.ground_at(column) != origin.y:
			return false
	return true


static func _rotated_footprint_bounds(yaw: int) -> Dictionary:
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for local_cell: Vector3i in FabricRecipe.box_cells(
			MARKET_MINIMUM, MARKET_SIZE):
		var rotated := FabricRecipe.transform_cell(local_cell, Vector3i.ZERO, yaw)
		minimum.x = mini(minimum.x, rotated.x)
		minimum.y = mini(minimum.y, rotated.z)
		maximum.x = maxi(maximum.x, rotated.x)
		maximum.y = maxi(maximum.y, rotated.z)
	return {
		"min_x": minimum.x,
		"max_x": maximum.x,
		"min_z": minimum.y,
		"max_z": maximum.y,
		"center_x": floori(float(minimum.x + maximum.x) * 0.5),
		"center_z": floori(float(minimum.y + maximum.y) * 0.5),
	}


static func _yaw_toward_route(side: Vector3i) -> int:
	if side.x < 0:
		return 1
	if side.x > 0:
		return 3
	if side.z < 0:
		return 0
	return 2


static func _family(origin: Vector3i, world_seed: int) -> int:
	return posmod(origin.x + origin.z + floori(float(origin.z) / 5.0)
		+ posmod(world_seed, SettlementFabricProgram.MARKET_STALLS.size()),
		SettlementFabricProgram.MARKET_STALLS.size())


static func _seeded_hash(value: String, seed: int) -> int:
	var result := seed ^ 0x2f51a83d
	for byte in value.to_utf8_buffer():
		result = int((result ^ int(byte)) * 16777619) & 0x7fffffff
	return result
