extends GutTest

## Outcroppings must read as partial jetties of their parent building, not as
## small houses glued over a whole facade. The gabled bay may only join a
## parent face wider than itself beneath a warm roof family; everywhere else
## the flat-capped jetty carries the same inhabited overhead cover without its
## own roofline. Both variants wear their parent's wood.

const PROBE_SEEDS := 4

static var _built: WarrenBuiltTownPlan
static var _searched := false


func _town_with_outcrops() -> WarrenBuiltTownPlan:
	if _searched:
		return _built
	_searched = true
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	assert(program != null)
	for world_seed in PROBE_SEEDS:
		var candidate := WarrenBuiltTownSolver.solve(world_seed, program)
		if candidate == null:
			continue
		if _outcrop_units(candidate.fabric).size() > 0:
			_built = candidate
			break
	return _built


func test_probe_seed_produces_an_outcropping_town() -> void:
	assert_not_null(_town_with_outcrops(),
		"no probe seed accepted a town containing an outcropping")


func test_outcrops_are_shallow_projections() -> void:
	## A projection is a bay, not a room: one cell deep, so it can never read
	## as a second small building glued to the facade regardless of the parent
	## face width.
	var built := _town_with_outcrops()
	if built == null:
		return
	var plan := built.fabric
	for unit_value: FabricUnit in _outcrop_units(plan):
		var recipe_value := plan.recipe(unit_value.recipe_id)
		if recipe_value.has_tag(&"corner_wrap_bay"):
			continue
		var depth_rows: Dictionary = {}
		for cell: Vector3i in recipe_value.solid_cells:
			depth_rows[cell.z] = true
		assert_eq(depth_rows.size(), 1,
			("outcrop %s occupies %d cell rows of depth; a bay is one shallow " \
			+ "module") % [unit_value.stable_id, depth_rows.size()])
		assert_lte(recipe_value.local_bounds.end.z, -0.5,
			("outcrop %s protrudes to %.2f m; its visible face belongs at the " \
			+ "single-row plane (-0.75 m plus trim)") % [unit_value.stable_id,
				recipe_value.local_bounds.end.z])


func test_corner_bays_wrap_the_parent_corner_as_overlapping_squares() -> void:
	var built := _town_with_outcrops()
	if built == null:
		return
	var plan := built.fabric
	var seen := 0
	for unit_value: FabricUnit in _outcrop_units(plan):
		var recipe_value := plan.recipe(unit_value.recipe_id)
		if not recipe_value.has_tag(&"corner_wrap_bay"):
			continue
		seen += 1
		var bond := _room_back_bond(unit_value)
		assert_true(String(bond.target_socket).contains(".corner."),
			"corner bay %s must bond an end-of-face socket" \
			% unit_value.stable_id)
		var columns: Dictionary = {}
		for cell: Vector3i in recipe_value.solid_cells:
			columns[Vector2i(cell.x, cell.z)] = true
		assert_eq(columns.size(), 3,
			("corner bay %s occupies %d columns; the outside of two " \
			+ "overlapping squares is an L of three") % [unit_value.stable_id,
				columns.size()])
	if seen == 0:
		pass_test("no corner-wrap bay was admitted for this seed")


func test_bay_roofs_match_the_parent_roof_family() -> void:
	var built := _town_with_outcrops()
	if built == null:
		return
	var plan := built.fabric
	for unit_value: FabricUnit in _outcrop_units(plan):
		var recipe_value := plan.recipe(unit_value.recipe_id)
		var bond := _room_back_bond(unit_value)
		var cool_assets := _cool_stack_roof_assets(plan,
			StringName(bond.target_unit))
		if recipe_value.has_tag(&"warm_roof_bay"):
			assert_eq(cool_assets, PackedStringArray(),
				"warm-roofed bay %s hangs on a cool-roofed stack (%s)" % [
					unit_value.stable_id, ",".join(cool_assets)])
		elif recipe_value.has_tag(&"cool_roof_bay"):
			assert_gt(cool_assets.size(), 0,
				"cool-roofed bay %s hangs on a warm-roofed stack" \
				% unit_value.stable_id)


func test_outcrop_wood_matches_parent_wall_family() -> void:
	var built := _town_with_outcrops()
	if built == null:
		return
	var plan := built.fabric
	var applicable := 0
	for unit_value: FabricUnit in _outcrop_units(plan):
		if not plan.recipe(unit_value.recipe_id).has_tag(&"wood_walled_bay"):
			continue
		applicable += 1
		var bond := _room_back_bond(unit_value)
		var parent_unit := plan.unit(StringName(bond.target_unit))
		if parent_unit == null:
			continue
		var parent_family := _wood_family(parent_unit.recipe_id)
		if parent_family == &"":
			continue
		var bay_family := _wood_family(unit_value.recipe_id)
		assert_eq(bay_family, parent_family,
			("outcrop %s wears %s wood on a %s parent (%s); a projection is " \
			+ "part of its house, not a different building") % [
				unit_value.stable_id, bay_family, parent_family,
				parent_unit.recipe_id])
	if applicable == 0:
		pass_test("this seed's bays are all dormer variants without wood walls")


func test_capped_jetties_stay_roofless_and_capped() -> void:
	var built := _town_with_outcrops()
	if built == null:
		return
	var plan := built.fabric
	for unit_value: FabricUnit in _outcrop_units(plan):
		var recipe_value := plan.recipe(unit_value.recipe_id)
		if not recipe_value.has_tag(&"capped_outcropping"):
			continue
		var has_cap := false
		for placement: Dictionary in recipe_value.placements:
			var asset_text := String(placement.asset_id)
			assert_false(asset_text.contains("roof.compact") \
					or asset_text.contains("roof.window"),
				"a capped jetty owns no roof of its own")
			has_cap = has_cap \
				or StringName(placement.id) == &"cap"
		assert_true(has_cap,
			"a capped jetty closes its top with the reviewed deck module")


func test_corner_wrap_bays_are_roofed_turrets() -> void:
	## A corner oriel seen from above must read as a finished roofed turret,
	## never as an open frame with a bare plank tabletop (review round 5).
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	var checked := 0
	for recipe_value: FabricRecipe in program.recipes():
		if not recipe_value.has_tag(&"corner_wrap_bay"):
			continue
		checked += 1
		var has_compact_roof := false
		for placement: Dictionary in recipe_value.placements:
			var asset_text := String(placement.asset_id)
			assert_false(StringName(placement.id) == &"cap",
				"corner oriel %s still carries a bare deck cap" \
				% recipe_value.recipe_id)
			has_compact_roof = has_compact_roof \
				or asset_text.contains("roof.compact")
		assert_true(has_compact_roof,
			"corner oriel %s owns no compact roof" % recipe_value.recipe_id)
	assert_gt(checked, 0, "no corner-wrap recipes registered")


func test_a_stack_facade_carries_at_most_one_outcropping() -> void:
	## Bays on different faces of one column articulate it; two bays on the
	## SAME face of one column read as a stamped repeat.
	var built := _town_with_outcrops()
	if built == null:
		return
	var plan := built.fabric
	var facades: Dictionary = {}
	for unit_value: FabricUnit in _outcrop_units(plan):
		var bond := _room_back_bond(unit_value)
		var key := "%s|%d" % [_stack_prefix(StringName(bond.target_unit)),
			unit_value.yaw_quarters]
		assert_false(facades.has(key),
			("outcrops %s and %s hang on one facade side %s; repeated " \
			+ "jetties on one face read as a stamp, not articulation") \
			% [facades.get(key), unit_value.stable_id, key])
		facades[key] = unit_value.stable_id


static func _stack_prefix(unit_id: StringName) -> String:
	var id_text := String(unit_id)
	var marker := id_text.find(".base")
	if marker < 0:
		marker = id_text.find(".upper.")
	return id_text.substr(0, marker) if marker >= 0 else id_text


static func _outcrop_units(plan: SettlementFabricPlan) -> Array[FabricUnit]:
	var out: Array[FabricUnit] = []
	for unit_value: FabricUnit in plan.units:
		var recipe_value := plan.recipe(unit_value.recipe_id)
		if recipe_value != null and recipe_value.has_tag(&"outcropping"):
			out.append(unit_value)
	return out


static func _room_back_bond(unit_value: FabricUnit) -> Dictionary:
	for bond: Dictionary in unit_value.socket_bonds:
		if StringName(bond.own_socket) == &"room.back":
			return bond
	return {"target_unit": &"", "target_socket": &""}


static func _face_span(recipe_value: FabricRecipe,
		socket: Dictionary) -> int:
	var facing := socket.facing as Vector3i
	var socket_cell := socket.cell as Vector3i
	var distinct: Dictionary = {}
	var cells: Array[Vector3i] = []
	cells.append_array(recipe_value.solid_cells)
	cells.append_array(recipe_value.headroom_cells)
	for cell: Vector3i in cells:
		if cell.y != socket_cell.y:
			continue
		if facing.x != 0 and cell.x == socket_cell.x:
			distinct[cell.z] = true
		elif facing.z != 0 and cell.z == socket_cell.z:
			distinct[cell.x] = true
	return distinct.size()


static func _wood_family(recipe_id: StringName) -> StringName:
	var text := String(recipe_id)
	if text.contains("blue"):
		return &"blue"
	if text.contains("orange"):
		return &"orange"
	return &""


static func _cool_stack_roof_assets(plan: SettlementFabricPlan,
		parent_unit_id: StringName) -> PackedStringArray:
	var id_text := String(parent_unit_id)
	var marker := id_text.find(".base")
	if marker < 0:
		marker = id_text.find(".upper.")
	var prefix := id_text.substr(0, marker) if marker >= 0 else id_text
	var out := PackedStringArray()
	for candidate: FabricUnit in plan.units:
		if not String(candidate.stable_id).begins_with(prefix + "."):
			continue
		var recipe_value := plan.recipe(candidate.recipe_id)
		if recipe_value == null or not recipe_value.has_tag(&"roof"):
			continue
		for placement: Dictionary in recipe_value.placements:
			var asset_text := String(placement.asset_id)
			if asset_text.contains(".blue.") and not out.has(asset_text):
				out.append(asset_text)
	return out
