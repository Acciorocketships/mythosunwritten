extends GutTest

## Outcroppings must read as partial jetties of their parent building, not as
## small houses glued over a whole facade. The gabled bay may only join a
## parent face wider than itself beneath a warm roof family; everywhere else
## the flat-capped jetty carries the same inhabited overhead cover without its
## own roofline. Both variants wear their parent's wood.

const REVIEW_SEED := 166029932451774690
const REVIEW_ATTEMPT := 11
const REVIEW_SOURCE_ID := \
	&"warren.volume.mass.166029932462774723.arcade0.arcade1"
const REVIEW_PARTITION_VARIANT := 0

static var _built: SettlementFabricPlan
static var _searched := false


func _town_with_outcrops() -> SettlementFabricPlan:
	if _searched:
		return _built
	_searched = true
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	if program == null:
		return null
	var profile := WarrenVillageScaleProfile.for_id(
		WarrenVillageScaleProfile.COMPACT)
	var frontier := WarrenTownSolver.mass_first_attempt_frontier(REVIEW_SEED,
		REVIEW_ATTEMPT, {}, profile)
	var ranked := WarrenVolumetricSolver._ranked_precomposition_variants(
		frontier, program)
	for candidate_value: Dictionary in ranked:
		if int(candidate_value.variant) != REVIEW_PARTITION_VARIANT:
			continue
		var source := candidate_value.volume as WarrenVolumePlan
		if source == null or source.stable_id != REVIEW_SOURCE_ID:
			continue
		var spatial := WarrenVolumetricSolver.from_volume(source,
			REVIEW_PARTITION_VARIANT, program, false)
		if spatial == null:
			return null
		_built = WarrenSpatialFabricCompiler.solve(spatial, program)
		break
	return _built


func test_probe_seed_produces_an_outcropping_town() -> void:
	assert_not_null(_town_with_outcrops(),
		"no probe seed accepted a town containing an outcropping")


func test_outcrops_are_shallow_projections() -> void:
	## A projection is a bay, not a room: one cell deep, so it can never read
	## as a second small building glued to the facade regardless of the parent
	## face width.
	var plan := _town_with_outcrops()
	if plan == null:
		return
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
		assert_lte(recipe_value.local_bounds.end.z, 0.25,
			("outcrop %s protrudes to %.2f m; the measured trim must remain " \
			+ "inside one shallow half-depth module") % [unit_value.stable_id,
				recipe_value.local_bounds.end.z])


func test_corner_bays_wrap_the_parent_corner_as_overlapping_squares() -> void:
	var plan := _town_with_outcrops()
	if plan == null:
		return
	var seen := 0
	for unit_value: FabricUnit in _outcrop_units(plan):
		var recipe_value := plan.recipe(unit_value.recipe_id)
		if not recipe_value.has_tag(&"corner_wrap_bay"):
			continue
		seen += 1
		var bond := _room_back_bond(unit_value)
		assert_false(StringName(bond.target_unit).is_empty(),
			"corner bay %s must retain one exact parent-room bond" \
				% unit_value.stable_id)
		assert_false(StringName(bond.target_socket).is_empty(),
			"corner bay %s must retain one exact parent-room socket" \
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
	var plan := _town_with_outcrops()
	if plan == null:
		return
	var applicable := 0
	for unit_value: FabricUnit in _outcrop_units(plan):
		var recipe_value := plan.recipe(unit_value.recipe_id)
		var bond := _room_back_bond(unit_value)
		var cool_assets := _cool_stack_roof_assets(plan,
			StringName(bond.target_unit))
		if recipe_value.has_tag(&"warm_roof_bay"):
			applicable += 1
			assert_eq(cool_assets, PackedStringArray(),
				"warm-roofed bay %s hangs on a cool-roofed stack (%s)" % [
					unit_value.stable_id, ",".join(cool_assets)])
		elif recipe_value.has_tag(&"cool_roof_bay"):
			applicable += 1
			assert_gt(cool_assets.size(), 0,
				"cool-roofed bay %s hangs on a warm-roofed stack" \
				% unit_value.stable_id)
	if applicable == 0:
		pass_test("the reviewed outcrops use neutral inherited roof tags")


func test_outcrop_wood_matches_parent_wall_family() -> void:
	var plan := _town_with_outcrops()
	if plan == null:
		return
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
	var plan := _town_with_outcrops()
	if plan == null:
		return
	var applicable := 0
	for unit_value: FabricUnit in _outcrop_units(plan):
		var recipe_value := plan.recipe(unit_value.recipe_id)
		if not recipe_value.has_tag(&"capped_outcropping"):
			continue
		applicable += 1
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
	if applicable == 0:
		pass_test("the reviewed town uses roofed bays rather than capped jetties")


func test_embedded_oriels_use_composed_partial_height_window_bays() -> void:
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	for recipe_id: StringName in [
		&"outcrop.embedded.blue", &"outcrop.embedded.orange",
		&"outcrop.embedded.amber",
	]:
		var recipe_value := program.recipe(recipe_id)
		assert_not_null(recipe_value, String(recipe_id))
		if recipe_value == null:
			continue
		var required_parts: Dictionary = {
			&"bay.face": false, &"bay.cheek.left": false,
			&"bay.cheek.right": false, &"bay.sill": false,
			&"bay.canopy": false, &"bay.corbel.left": false,
			&"bay.corbel.right": false,
		}
		for placement: Dictionary in recipe_value.placements:
			var placement_id := StringName(placement.id)
			if required_parts.has(placement_id):
				required_parts[placement_id] = true
			assert_false(String(placement.asset_id).contains("roof.window"),
				"a facade bay must not rotate a dormer A-frame onto the wall")
			assert_false(StringName(placement.id) == &"cap",
				"%s must not expose a wooden tabletop above its inhabited bay" \
					% recipe_id)
		assert_true(recipe_value.has_tag(&"partial_height_bay"))
		for part_id: StringName in required_parts:
			assert_true(bool(required_parts[part_id]),
				"%s needs its complete %s construction" % [recipe_id, part_id])
		var face := recipe_value.placements.filter(func(value: Dictionary) -> bool:
			return StringName(value.id) == &"bay.face")[0] as Dictionary
		var face_contract := program.module_program.contract(
			StringName(face.asset_id))
		var placed_face := (face.transform as Transform3D) \
			* face_contract.visual_bounds
		assert_gt(placed_face.size.y, 2.0,
			"the authored plaster/window fields must not be crushed into a cage")
		assert_lt(placed_face.size.y, 2.2,
			"the oriel face must remain distinctly below a full storey")
		var cheek_bounds: Array[AABB] = []
		for cheek_id: StringName in [&"bay.cheek.left", &"bay.cheek.right"]:
			var cheek := recipe_value.placements.filter(
				func(value: Dictionary) -> bool:
					return StringName(value.id) == cheek_id)[0] as Dictionary
			var cheek_contract := program.module_program.contract(
				StringName(cheek.asset_id))
			cheek_bounds.append((cheek.transform as Transform3D) \
				* cheek_contract.visual_bounds)
		assert_lte(cheek_bounds[0].position.z, -0.88,
			"the left return cheek must reach the projected window face")
		assert_lte(cheek_bounds[1].position.z, -0.88,
			"the right return cheek must reach the projected window face")
		assert_gte(cheek_bounds[0].end.z, -0.02,
			"the left return cheek must close back to the parent facade")
		assert_gte(cheek_bounds[1].end.z, -0.02,
			"the right return cheek must close back to the parent facade")


func test_corner_wrap_bays_roof_only_the_exterior_union() -> void:
	## The room-scale diagonal overlap must read as one building. Its roof closes
	## the shifted square with two end-trimmed, opposed low pitches and deliberately
	## shares only the parent's exterior quadrant. A second complete gable would
	## intersect the parent roof and expose the two overlapping source shells.
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	var checked := 0
	for recipe_value: FabricRecipe in program.recipes():
		if not recipe_value.has_tag(&"corner_wrap_bay"):
			continue
		checked += 1
		var pitch_count := 0
		var has_ridge := false
		var seam_zs: Array[float] = []
		var eave_zs: Array[float] = []
		for placement: Dictionary in recipe_value.placements:
			var asset_text := String(placement.asset_id)
			assert_false(asset_text.contains("roof.compact"),
				"corner union %s intersects a second complete gable" \
					% recipe_value.recipe_id)
			pitch_count += int(String(placement.id).begins_with("roof.pitch.") \
				and asset_text.ends_with(".trimmed"))
			if String(placement.id).begins_with("roof.pitch.") \
					and asset_text.ends_with(".trimmed"):
				var contract := program.module_program.contract(
					StringName(placement.asset_id))
				assert_not_null(contract)
				if contract != null:
					var pose := placement.transform as Transform3D
					seam_zs.append((pose * Vector3(0.0, 0.0,
						contract.visual_bounds.position.z)).z)
					eave_zs.append((pose * Vector3(0.0, 0.0,
						contract.visual_bounds.end.z)).z)
			has_ridge = has_ridge \
				or StringName(placement.id) == &"roof.ridge"
			assert_false(String(placement.id).begins_with("roof.cap"),
				"corner union %s still exposes a bare wooden tabletop" \
					% recipe_value.recipe_id)
			assert_false(String(placement.id).begins_with("roof.guard."),
				"an inhabited corner bay roof must not masquerade as a balcony")
		assert_eq(pitch_count, 2,
			"corner union %s needs two clean opposed tiled pitches" \
				% recipe_value.recipe_id)
		assert_eq(seam_zs.size(), 2)
		assert_eq(eave_zs.size(), 2)
		if seam_zs.size() == 2 and eave_zs.size() == 2:
			assert_almost_eq(seam_zs[0], seam_zs[1], 0.001,
				"the two low pitches must touch exactly without overlap or gap")
			assert_lt((eave_zs[0] - seam_zs[0]) \
				* (eave_zs[1] - seam_zs[1]), 0.0,
				"the pitches must fall away from the seam as one convex gable")
		assert_false(has_ridge,
			"a generic 3 m ridge overwhelms the low corner-bay roof")
	assert_gt(checked, 0, "no corner-wrap recipes registered")


func test_a_stack_facade_carries_at_most_one_outcropping() -> void:
	## Bays on different faces of one column articulate it; two bays on the
	## SAME face of one column read as a stamped repeat.
	var plan := _town_with_outcrops()
	if plan == null:
		return
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
