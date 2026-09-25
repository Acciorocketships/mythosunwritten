class_name FabricSolidVoidPlan
extends RefCounted

## Resource-free classification of the compact core's coupled walk/air/mass
## boundary. Every exposed side of the public surface is an obligation; only a
## substantial building or market owner can close it. The procedural embedder
## ranks and rejects candidates from this record instead of decorating a route
## and hoping that nearby buildings happen to form a maze.
var stable_id: StringName
## A street this many walk cells wide (4.5 m) can still read as an alley held
## between two built edges; anything wider is a plaza or promenade.
const MAX_ALLEY_SPAN_CELLS := 3

var boundary_obligations: Array[Dictionary] = []
var alley_bounded_cell_count := 0
var alley_eligible_cell_count := 0
var unbounded_obligations: Array[Dictionary] = []
var building_base_bands: Array[int] = []
var building_roof_bands: Array[int] = []
var neighboring_half_level_pairs: Array[Dictionary] = []
var core_bounds := AABB()
var _surface_cells: Dictionary = {}
var _sealed := false


func _init(p_stable_id: StringName) -> void:
	stable_id = p_stable_id


func seal(realm: SectionalPublicRealmPlan,
		fabric_plan: SettlementFabricPlan) -> bool:
	if _sealed or stable_id.is_empty() or realm == null \
			or not realm.is_sealed() or fabric_plan == null \
			or realm.air_realm != PublicRealmNode.AirRealm.EXTERIOR:
		return false
	var surfaces := realm.surface_claims()
	_surface_cells = surfaces.duplicate()
	var solids := fabric_plan.transformed_cells(&"solid")
	var inhabited := fabric_plan.transformed_cells(&"inhabited")
	var occluders := fabric_plan.transformed_cells(&"occluder")
	if surfaces.is_empty():
		return false
	_build_boundary_obligations(surfaces, solids, inhabited, occluders,
		fabric_plan)
	_build_height_bands(fabric_plan)
	_build_core_bounds(surfaces, solids, inhabited)
	_sealed = not boundary_obligations.is_empty()
	return _sealed


func validate() -> bool:
	if not _sealed or stable_id.is_empty() or boundary_obligations.is_empty() \
			or not core_bounds.has_volume():
		return false
	var open_count := 0
	for obligation: Dictionary in boundary_obligations:
		if not bool(obligation.bounded):
			open_count += 1
	return open_count == unbounded_obligations.size()


func is_sealed() -> bool:
	return _sealed


func has_surface_cell(cell: Vector3i) -> bool:
	return _surface_cells.has(cell)


func audit() -> Dictionary:
	var bounded_count := boundary_obligations.size() \
		- unbounded_obligations.size()
	return {
		"boundary_obligation_count": boundary_obligations.size(),
		"bounded_boundary_count": bounded_count,
		"unbounded_route_side_count": unbounded_obligations.size(),
		"solid_void_frontage_ratio": float(bounded_count) \
			/ float(maxi(1, boundary_obligations.size())),
		"alley_bounded_cell_count": alley_bounded_cell_count,
		"alley_bounded_walk_ratio": float(alley_bounded_cell_count) \
			/ float(maxi(1, alley_eligible_cell_count)),
		"building_base_band_count": building_base_bands.size(),
		"building_roof_band_count": building_roof_bands.size(),
		"half_level_neighbor_pair_count": neighboring_half_level_pairs.size(),
		"staggered_band_span_cells": 0 if building_base_bands.is_empty() \
			or building_roof_bands.is_empty() else building_roof_bands.back() \
			- building_base_bands.front(),
		"solid_void_core_width_cells": ceili(core_bounds.size.x \
			/ FabricRecipe.CELL_SIZE),
		"solid_void_core_depth_cells": ceili(core_bounds.size.z \
			/ FabricRecipe.CELL_SIZE),
	}


func _build_boundary_obligations(surfaces: Dictionary, solids: Dictionary,
		inhabited: Dictionary, occluders: Dictionary,
		fabric_plan: SettlementFabricPlan) -> void:
	for cell_value: Variant in surfaces:
		var cell := cell_value as Vector3i
		var surface_record := surfaces[cell] as Dictionary
		var node_value := fabric_plan.public_realm.node(StringName(
			surface_record.get("owner", "")))
		# The landing must remain an entrance from the surrounding world. Every
		# other public episode contributes construction opportunities, including a
		# court: at least one of its obligations must become an inhabited address or
		# the terminal is merely an ornamental deck. Guards may remain on the sides
		# the bounded search cannot occupy.
		if node_value == null or node_value.is_landing:
			continue
		for side: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			if _has_public_neighbor(surfaces, cell, side):
				continue
			var owner := _boundary_owner(cell + side, solids, inhabited,
				occluders)
			var boundary_kind := &"open"
			if not owner.is_empty():
				var owner_unit := fabric_plan.unit(owner)
				if owner_unit != null:
					var owner_recipe := fabric_plan.recipe(owner_unit.recipe_id)
					if owner_recipe.has_tag(&"room"):
						boundary_kind = &"building"
					elif owner_recipe.has_tag(&"market"):
						boundary_kind = &"market"
			var obligation := {
				"surface_cell": cell,
				"side": side,
				"owner": owner,
				"boundary_kind": boundary_kind,
				"bounded": boundary_kind != &"open",
			}
			boundary_obligations.append(obligation)
			if boundary_kind == &"open":
				unbounded_obligations.append(obligation)
	# The reviewed alley character is a per-cell fact: a walk cell reads as
	# negative space between buildings when, along one axis, the street runs
	# only a few cells wide and BOTH far edges carry real built boundaries.
	# A side the street merely continues through indefinitely, or an open rim,
	# is not a held flank — a one-sided promenade is not an alley.
	alley_bounded_cell_count = 0
	alley_eligible_cell_count = 0
	var built_boundaries: Dictionary = {}
	var obligated_cells: Dictionary = {}
	for obligation: Dictionary in boundary_obligations:
		obligated_cells[obligation.surface_cell as Vector3i] = true
		if bool(obligation.bounded):
			built_boundaries["%s/%s" % [obligation.surface_cell,
				obligation.side]] = true
	for cell_value: Variant in obligated_cells:
		var cell := cell_value as Vector3i
		alley_eligible_cell_count += 1
		var alley := false
		for axis: Array in [[Vector3i.LEFT, Vector3i.RIGHT],
				[Vector3i.FORWARD, Vector3i.BACK]]:
			var crossed := 0
			var held := true
			for direction: Vector3i in axis:
				var edge := cell
				while crossed <= MAX_ALLEY_SPAN_CELLS \
						and _surface_cells.has(edge + direction):
					edge += direction
					crossed += 1
				if crossed > MAX_ALLEY_SPAN_CELLS \
						or not built_boundaries.has("%s/%s" % [edge,
							direction]):
					held = false
					break
			if held:
				alley = true
				break
		alley_bounded_cell_count += int(alley)
	boundary_obligations.sort_custom(_obligation_less)
	unbounded_obligations.sort_custom(_obligation_less)


func _build_height_bands(fabric_plan: SettlementFabricPlan) -> void:
	var base_set: Dictionary = {}
	var roof_set: Dictionary = {}
	var room_records: Array[Dictionary] = []
	for unit_value: FabricUnit in fabric_plan.units:
		var recipe_value := fabric_plan.recipe(unit_value.recipe_id)
		if not recipe_value.has_tag(&"room"):
			continue
		var minimum_y := 2147483647
		var maximum_y := -2147483648
		for local_cell: Vector3i in recipe_value.occluder_cells:
			var cell := FabricRecipe.transform_cell(local_cell,
				unit_value.lattice_origin, unit_value.yaw_quarters)
			minimum_y = mini(minimum_y, cell.y)
			maximum_y = maxi(maximum_y, cell.y)
		if minimum_y == 2147483647:
			continue
		base_set[minimum_y] = true
		roof_set[maximum_y + 1] = true
		room_records.append({
			"id": unit_value.stable_id,
			"base": minimum_y,
			"bounds": unit_value.bounds,
		})
	building_base_bands.assign(base_set.keys())
	building_roof_bands.assign(roof_set.keys())
	building_base_bands.sort()
	building_roof_bands.sort()
	for first_index in room_records.size():
		for second_index in range(first_index + 1, room_records.size()):
			var first := room_records[first_index] as Dictionary
			var second := room_records[second_index] as Dictionary
			if absi(int(first.base) - int(second.base)) != 1 \
					or not _xz_bounds_are_neighbors(first.bounds as AABB,
						second.bounds as AABB):
				continue
			neighboring_half_level_pairs.append({
				"a": first.id,
				"b": second.id,
			})
	neighboring_half_level_pairs.sort_custom(func(a: Dictionary,
			b: Dictionary) -> bool:
		return "%s/%s" % [a.a, a.b] < "%s/%s" % [b.a, b.b])


func _build_core_bounds(surfaces: Dictionary, solids: Dictionary,
		inhabited: Dictionary) -> void:
	var cells: Dictionary = {}
	for source: Dictionary in [surfaces, solids, inhabited]:
		for cell_value: Variant in source:
			cells[cell_value as Vector3i] = true
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for cell_value: Variant in cells:
		var center := Vector3(cell_value as Vector3i) * FabricRecipe.CELL_SIZE
		minimum = minimum.min(center - Vector3.ONE * FabricRecipe.CELL_SIZE * 0.5)
		maximum = maximum.max(center + Vector3.ONE * FabricRecipe.CELL_SIZE * 0.5)
	core_bounds = AABB(minimum, maximum - minimum)


static func _has_public_neighbor(surfaces: Dictionary, cell: Vector3i,
		side: Vector3i) -> bool:
	for delta_y in [-1, 0, 1]:
		if surfaces.has(cell + side + Vector3i.UP * delta_y):
			return true
	return false


static func _boundary_owner(neighbor: Vector3i, solids: Dictionary,
		inhabited: Dictionary, occluders: Dictionary) -> StringName:
	for cell: Vector3i in [neighbor, neighbor + Vector3i.UP]:
		# Occluders are the reviewed eye-level boundary fact. A market canopy or
		# timber facade may be intentionally porous in hard collision while still
		# closing the street wall; using solids alone made four-post stalls vanish
		# from the very metric they were authored to satisfy.
		if occluders.has(cell):
			return StringName(occluders[cell])
		if inhabited.has(cell):
			return StringName(inhabited[cell])
		if solids.has(cell):
			return StringName(solids[cell])
	return &""


static func _xz_bounds_are_neighbors(a: AABB, b: AABB) -> bool:
	var a_rect := Rect2(Vector2(a.position.x, a.position.z),
		Vector2(a.size.x, a.size.z)).grow(FabricRecipe.CELL_SIZE)
	var b_rect := Rect2(Vector2(b.position.x, b.position.z),
		Vector2(b.size.x, b.size.z))
	return a_rect.intersects(b_rect, true)


static func _obligation_less(a: Dictionary, b: Dictionary) -> bool:
	var a_cell := a.surface_cell as Vector3i
	var b_cell := b.surface_cell as Vector3i
	if a_cell.y != b_cell.y:
		return a_cell.y < b_cell.y
	if a_cell.z != b_cell.z:
		return a_cell.z < b_cell.z
	if a_cell.x != b_cell.x:
		return a_cell.x < b_cell.x
	var a_side := a.side as Vector3i
	var b_side := b.side as Vector3i
	return "%d:%d" % [a_side.x, a_side.z] < "%d:%d" % [b_side.x, b_side.z]
