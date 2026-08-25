extends GutTest

## The town mountain is inhabited construction, not a thin decorative layer
## over terrain and not a hidden stone substrate.  These tests pin the two
## visual facts that distinguish the current direction from both failed forms:
## a strong centre-to-rim height gradient and facade breaks inside tall stacks.

const StampedGround = preload("res://tests/fixtures/warren_stamped_ground.gd")


func test_flat_ground_still_builds_a_bell_of_inhabited_mass() -> void:
	var ground := StampedGround.flat(WarrenMassifBuilder.RADIUS_CELLS + 1)
	var massif := WarrenMassifBuilder.build(7, ground)
	assert_not_null(massif, WarrenMassifBuilder.last_failure)
	if massif == null:
		return
	# TASK F1 RULING 4. The floor is the size profile's own
	# `minimum_core_bands` -- what `WarrenMassifBuilder._shape_gate_failure`
	# enforces -- not the retired `MIN_CORE_BANDS := 16` this restated.
	assert_gte(massif.core_top_bands,
		WarrenVillageScaleProfile.review_fixture().minimum_core_bands,
		"the centre must carry several inhabited storeys")
	var rim_max := 0
	for column: Vector2i in massif.columns:
		assert_eq(massif.bearing_at(column), massif.base_at(column),
			"inhabited construction must ground to the real terrain")
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
				Vector2i.UP, Vector2i.DOWN]:
			if not massif.has_column(column + direction):
				rim_max = maxi(rim_max, massif.layer_at(column))
	assert_lte(rim_max, WarrenMassifBuilder.MAX_NEIGHBOR_STEP_BANDS,
		"the mountain rim must descend in a low building step")
	assert_gte(massif.core_top_bands - rim_max, 10,
		"centre buildings must stand several storeys above the rim")


func test_a_tall_stack_uses_timber_at_ground_and_breaks_its_facade() -> void:
	var proposal := {
		"stable_id": &"inhabited.massif.style.probe",
		"kind": &"tower",
		"origin": Vector3i.ZERO,
		"yaw_quarters": 0,
		"storeys": 7,
		"route_y": 0,
		"ground_theme": &"blue",
		"storey_themes": [&"blue", &"blue", &"amber", &"amber",
			&"orange", &"orange", &"blue"],
	}
	var components := StaggeredFabricCompiler.proposal_components(proposal)
	assert_eq(StringName(components[0].recipe_id), &"room.tower.base.blue",
		"the ground storey may be timber while retaining terrain bearing")
	var upper_themes: Array[StringName] = []
	for component: Dictionary in components:
		if not String(component.role).begins_with("upper."):
			continue
		var parts := String(component.recipe_id).split(".")
		upper_themes.append(StringName(parts[3]))
	assert_eq(upper_themes,
		[&"blue", &"amber", &"amber", &"orange", &"orange", &"blue"],
		"vertical facade blocks must be visible construction facts")
	var longest_run := 1
	var run := 1
	for index in range(1, upper_themes.size()):
		run = run + 1 if upper_themes[index] == upper_themes[index - 1] else 1
		longest_run = maxi(longest_run, run)
	assert_lte(longest_run, 2,
		"a tall facade may not read as one repeated material slab")


func test_staggered_neighbors_declare_an_inhabited_party_wall() -> void:
	var low := {"kind": &"tower", "origin": Vector3i.ZERO,
		"yaw_quarters": 0, "storeys": 3}
	var high := {"kind": &"tower", "origin": Vector3i(2, 2, 0),
		"yaw_quarters": 0, "storeys": 5}
	assert_true(StaggeredFabricCompiler.inhabited_party_wall_compatible(
		low, high), "overlapping storeys meet on an authored wall plane")
	high["origin"] = Vector3i(4, 2, 0)
	assert_false(StaggeredFabricCompiler.inhabited_party_wall_compatible(
		low, high), "a street-width gap is not a party wall")
	high["origin"] = Vector3i(0, 8, 0)
	assert_true(StaggeredFabricCompiler.inhabited_party_wall_compatible(
		low, high), "a house may bear on the complete stack below it")
	high["origin"] = Vector3i(2, 0, 2)
	assert_true(StaggeredFabricCompiler.proposals_share_corner(low, high),
		"diagonal eaves must select the flush roof vocabulary")


func _courtyard_addressed_perimeter_sides(volume: WarrenVolumePlan) -> int:
	var court: Dictionary = {}
	for cell: Vector3i in volume.courtyard_cells:
		court[cell] = true
	var result := 0
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
			Vector2i.UP]:
		var addressed := false
		for cell: Vector3i in volume.courtyard_cells:
			var neighbor := cell + Vector3i(direction.x, 0, direction.y)
			if court.has(neighbor) or volume.has_walk(neighbor):
				continue
			var complete := true
			for y in range(cell.y, cell.y
					+ WarrenBuildingParcel.STOREY_BANDS
					+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS):
				if not volume.has_mass(Vector3i(neighbor.x, y, neighbor.z)):
					complete = false
					break
			if complete:
				addressed = true
				break
		result += int(addressed)
	return result
