extends GutTest

## Outcroppings must read as partial jetties of their parent building, not as
## small houses glued over a whole facade. The gabled bay may only join a
## parent face wider than itself beneath a warm roof family; everywhere else
## the flat-capped jetty carries the same inhabited overhead cover without its
## own roofline. Both variants wear their parent's wood.

## The pinned production village of world seed 2697992464 at settlement cell
## (11,12). TASK F1 SWAPPED THIS FIXTURE'S SUBJECT: it used to name a bore
## attempt, a ranked source id and a partition variant, drive
## `WarrenTownSolver.mass_first_attempt_frontier` +
## `WarrenVolumetricSolver._ranked_precomposition_variants`, and compile the
## selected pair by hand -- three searched identities that no longer exist.
## One-pass generation builds exactly one town per (seed, scale), so the town
## below is simply that solve. Every assertion in this file therefore now
## describes the town production really ships, not the searched one.
const REVIEW_SEED := 6357506428441529412
## MEASURED 2026-08-31 after the canonical maximal-relief pass: this town keeps
## three roofed structural facade bays in addition to the assembler's balanced
## shallow bays/bump-outs. It uses at least one complete 3 m gabled bay. The
## partial-height oriel remains the bounded fallback wherever that larger
## measured envelope cannot fit.
const MEASURED_OUTCROP_BAYS := 3

static var _built: SettlementFabricPlan
static var _solved := false


func _town_with_outcrops() -> SettlementFabricPlan:
	if _solved:
		return _built
	_solved = true
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	if program == null:
		return null
	var profile := WarrenVillageScaleProfile.for_id(
		WarrenVillageScaleProfile.STANDARD)
	var spatial := WarrenVolumetricSolver.solve(REVIEW_SEED, {}, program,
		profile)
	if spatial == null:
		return null
	# The solve already compiled and quality-gated this fabric; reusing it
	# saves a second full compile per suite run. VERIFIED 2026-08-25 that the
	# reuse cannot change what this file measures: cached and fresh compiles of
	# this town agree on unit count (139), on every outcrop unit and recipe,
	# and on every audit key they share. The only difference is that a fresh
	# compile additionally inherits the solve bookkeeping (`maze_stage_ms`,
	# `advisory_shortfalls`, the `production_*` identity keys) that
	# `_solve_maze` stamps onto the plan AFTER the cached compile ran, and
	# nothing here reads those.
	_built = spatial.compiled_fabric_cache()
	if _built == null:
		_built = WarrenSpatialFabricCompiler.solve(spatial, program)
	return _built


func test_the_probe_seed_builds_its_measured_roofed_facade_bays() -> void:
	## TASK F1 FIX 1, finding I4. This used to be
	## `test_probe_seed_produces_an_outcropping_town` and asserted only that
	## the plan was non-null, while its name claimed an outcropping existed.
	## The complete native-width bay is preferred; a partial-height embedded
	## oriel may fill a frontage whose exact neighboring roofs or rooms reject
	## that larger envelope. Both are sealed, roofed construction recipes.
	var plan := _town_with_outcrops()
	assert_not_null(plan, "the review seed no longer builds its town")
	if plan == null:
		return
	var units := _outcrop_units(plan)
	var embedded := 0
	var full_gabled := 0
	for unit_value: FabricUnit in units:
		embedded += int(String(unit_value.recipe_id).begins_with(
			"outcrop.embedded."))
		full_gabled += int(unit_value.recipe_id in [
			&"outcrop.blue", &"outcrop.orange", &"outcrop.amber",
		])
	gut.p("one-pass town: outcrop units=%d full_gabled=%d embedded_oriels=%d"
		% [units.size(), full_gabled, embedded])
	assert_gte(units.size(), MEASURED_OUTCROP_BAYS,
		"the review seed lost outcroppings it used to build")
	assert_gte(full_gabled, 1,
		"an open eligible facade must receive a complete native-width gabled bay")
	assert_eq(embedded + full_gabled, units.size(),
		("every facade bay must be either a complete native-width gabled bay " \
			+ "or its bounded partial-height oriel fallback"))


func test_facade_bays_cannot_fragment_a_partial_roof_campaign() -> void:
	var room := WarrenRoomStamp.new(&"room.roof.probe", &"source.roof.probe",
		&"tower", Vector3i.ZERO, 0, 1, false, false,
		Vector3i(2147483647, 2147483647, 2147483647), Vector3i.ZERO, 0,
		&"source.support", 0)
	assert_true(room.add_private_cells(WarrenRoomStamp.expected_private_cells(
		&"tower", Vector3i.ZERO, 0)))
	var top_cells := room.private_cells.filter(func(cell: Vector3i) -> bool:
		return cell.y == 1) as Array[Vector3i]

	var partial_grid := WarrenSpatialGrid.new(Vector3i(-2, -1, -2),
		Vector3i(5, 4, 5))
	var partial_tx := partial_grid.begin_transaction(&"mass.partial")
	assert_true(partial_tx.assign_use([
		top_cells[0] + Vector3i.UP, top_cells[1] + Vector3i.UP,
	] as Array[Vector3i], WarrenSpatialGrid.Use.PRIVATE_VOLUME,
		&"mass.partial"))
	assert_true(partial_tx.commit())
	assert_true(WarrenSpatialFeatureSolver._room_has_partial_roof_campaign(
		partial_grid, room),
		"a bay must not consume one member of an already partial roof run")
	var building := WarrenBuildingVolume.new(&"building.roof.probe", 0)
	building.room_records = [room] as Array[WarrenRoomStamp]
	var protected_crown := WarrenSpatialFeatureSolver \
		._partial_roof_campaign_crown_cells(partial_grid,
			[building] as Array[WarrenBuildingVolume])
	assert_eq(protected_crown.size(), top_cells.size() - 2,
		"every still-exposed crown cell in the partial campaign is protected")
	assert_true(WarrenSpatialFeatureSolver._cell_sets_overlap({
		top_cells[2] + Vector3i.UP: true,
	}, protected_crown),
		"a bay attached elsewhere may not consume this room's protected crown")
	assert_false(WarrenSpatialFeatureSolver._cell_sets_overlap({
		top_cells[0] + Vector3i.UP: true,
	}, protected_crown),
		"already-covered crown cells are not falsely reserved as roofs")

	var complete_grid := WarrenSpatialGrid.new(Vector3i(-2, -1, -2),
		Vector3i(5, 4, 5))
	assert_false(WarrenSpatialFeatureSolver._room_has_partial_roof_campaign(
		complete_grid, room),
		"a complete eave remains eligible for shallow facade relief")

	var covered_grid := WarrenSpatialGrid.new(Vector3i(-2, -1, -2),
		Vector3i(5, 4, 5))
	var covered_tx := covered_grid.begin_transaction(&"mass.covered")
	var covered_crown: Array[Vector3i] = []
	for cell: Vector3i in top_cells:
		covered_crown.append(cell + Vector3i.UP)
	assert_true(covered_tx.assign_use(covered_crown,
		WarrenSpatialGrid.Use.PRIVATE_VOLUME, &"mass.covered"))
	assert_true(covered_tx.commit())
	assert_false(WarrenSpatialFeatureSolver._room_has_partial_roof_campaign(
		covered_grid, room),
		"a room fully covered by upper mass has no roof run to fragment")


func test_outcrops_are_shallow_projections() -> void:
	## The partial-height oriel stays inside one exterior fine cell. A complete
	## native-width bay deliberately spans the parent seam row plus one exterior
	## row, but may project no farther than that first half-cell from the facade.
	## Neither form is an unconstrained room pasted beyond the building.
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
		if recipe_value.has_tag(&"native_width_gabled_bay"):
			assert_eq(depth_rows.size(), 2,
				("native-width bay %s must own exactly its parent seam row and " \
					+ "one exterior row") % unit_value.stable_id)
			assert_lte(recipe_value.local_bounds.end.z, 0.80,
				("native-width bay %s protrudes to %.2f m; its complete gable " \
					+ "must stay within the first exterior half-cell") % [
					unit_value.stable_id, recipe_value.local_bounds.end.z])
		else:
			assert_true(recipe_value.has_tag(&"embedded_oriel"),
				"the compact fallback must be the sealed embedded-oriel recipe")
			assert_eq(depth_rows.size(), 1,
				("embedded oriel %s occupies %d depth rows; it must remain one " \
					+ "shallow module") % [unit_value.stable_id,
					depth_rows.size()])
			assert_lte(recipe_value.local_bounds.end.z, 0.25,
				("embedded oriel %s protrudes to %.2f m; the measured trim must " \
					+ "remain inside one shallow half-depth module") % [
					unit_value.stable_id, recipe_value.local_bounds.end.z])


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
			&"bay.face": false, &"bay.post.left": false,
			&"bay.post.right": false,
			&"bay.cheek.left": false,
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
		assert_gt(placed_face.size.y, 1.35,
			"the authored plaster/window fields must remain legible")
		assert_lt(placed_face.size.y, 1.45,
			"the oriel face must read as a window, not most of a storey")
		assert_gte(placed_face.position.y, 0.6,
			"the oriel must begin at window height rather than reading as a door")
		assert_lte(placed_face.end.y, 2.2,
			"the oriel must leave visible parent wall above its roof")
		const PARENT_FACADE_Z := -FabricRecipe.CELL_SIZE * 0.5
		assert_gt(placed_face.end.z, 0.10,
			("the oriel window must be the convex outer face; %s still places " \
			+ "it behind the parent facade") % recipe_id)
		assert_gt(placed_face.position.z, PARENT_FACADE_Z,
			("the complete oriel window must sit outside the parent facade; %s " \
				+ "would read as a recessed/concave frame") % recipe_id)
		assert_false(recipe_value.placements.any(
			func(value: Dictionary) -> bool:
				return StringName(value.id) == &"bay.face.right"),
			"the oriel must not squeeze two complete windows into one bay")
		var left_post := recipe_value.placements.filter(
			func(value: Dictionary) -> bool:
				return StringName(value.id) == &"bay.post.left")[0] as Dictionary
		var post := recipe_value.placements.filter(
			func(value: Dictionary) -> bool:
				return StringName(value.id) == &"bay.post.right")[0] as Dictionary
		var post_contract := program.module_program.contract(
			StringName(post.asset_id))
		var placed_post := (post.transform as Transform3D) \
			* post_contract.visual_bounds
		assert_eq(StringName(post.asset_id),
			SettlementFabricProgram.PORTAL_JAMB,
			"the missing terminal timber must be a pure wood jamb")
		assert_between(placed_post.size.x, 0.25, 0.31,
			"the right jamb must match the authored heavy post on the left")
		assert_gt(placed_post.position.x, 0.30,
			"the added terminal timber must close the narrowed panel's right edge")
		var left_contract := program.module_program.contract(
			StringName(left_post.asset_id))
		var placed_left := (left_post.transform as Transform3D) \
			* left_contract.visual_bounds
		assert_almost_eq(placed_left.position.x, -placed_post.end.x, 0.001,
			"the two bay jambs must be exact reflected silhouettes")
		assert_almost_eq(placed_left.size.x, placed_post.size.x, 0.001)
		assert_gt(placed_left.end.x, placed_face.position.x,
			"the left jamb must overlap the scaled authored terminal timber")
		assert_lt(placed_post.position.x, placed_face.end.x,
			"the reflected right jamb must overlap the face instead of widening it")
		var cheek_bounds: Array[AABB] = []
		for cheek_id: StringName in [&"bay.cheek.left", &"bay.cheek.right"]:
			var cheek := recipe_value.placements.filter(
				func(value: Dictionary) -> bool:
					return StringName(value.id) == cheek_id)[0] as Dictionary
			var cheek_contract := program.module_program.contract(
				StringName(cheek.asset_id))
			cheek_bounds.append((cheek.transform as Transform3D) \
				* cheek_contract.visual_bounds)
		assert_lte(cheek_bounds[0].position.z, PARENT_FACADE_Z - 0.02,
			"the left return cheek must overlap the parent facade seam")
		assert_lte(cheek_bounds[1].position.z, PARENT_FACADE_Z - 0.02,
			"the right return cheek must overlap the parent facade seam")
		assert_gte(cheek_bounds[0].end.z, 0.10,
			"the left return cheek must reach the convex window face")
		assert_gte(cheek_bounds[1].end.z, 0.10,
			"the right return cheek must reach the convex window face")
		assert_lt(cheek_bounds[0].size.x, 0.20,
			"the left return must not consume the narrow bay as an oversized jamb")
		assert_lt(cheek_bounds[1].size.x, 0.20,
			"the right return must not consume the narrow bay as an oversized jamb")
		var covered_bounds: Array[AABB] = [placed_face, placed_left, placed_post,
			cheek_bounds[0], cheek_bounds[1]]
		for cover_id: StringName in [&"bay.sill", &"bay.canopy"]:
			var cover := recipe_value.placements.filter(
				func(value: Dictionary) -> bool:
					return StringName(value.id) == cover_id)[0] as Dictionary
			var cover_contract := program.module_program.contract(
				StringName(cover.asset_id))
			var cover_bounds := (cover.transform as Transform3D) \
				* cover_contract.visual_bounds
			for covered: AABB in covered_bounds:
				assert_lte(cover_bounds.position.x, covered.position.x + 0.01,
					"%s must cover the bay's left edge" % cover_id)
				assert_gte(cover_bounds.end.x, covered.end.x - 0.01,
					"%s must cover the bay's right edge" % cover_id)


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
