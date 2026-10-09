extends GutTest
## Step-in assembly (spec Amendment 2): a storey stands `offset` (<= 0, native m) inside
## its line on a stepping face; the top storey and the roof never move. Native frame:
## the south face (dir 3) of Rect2i(0, 0, 3, 2) is the line z = 0, inward is +z.
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")


func _house(storeys := 4, door_dir := 1) -> BuildingMass:
	return FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 3, 2), storeys, door_dir)


func _parts(mass: BuildingMass) -> Array[Dictionary]:
	return BuildingKitAssembler.new(SuntailBuildingKit.create()).assemble(mass)


var _catalog: EnvironmentCatalog


func _box(part: Dictionary) -> AABB:
	if _catalog == null:
		_catalog = EnvironmentCatalog.load_default() # building it per call is minutes per test
	return part.transform * _catalog.descriptor(part.asset_id).measured_aabb


## Parts whose role starts with `prefix` and whose box centre lies in the storey whose floor is y0.
func _at(parts: Array, prefix: String, y0: float) -> Array:
	return parts.filter(func(p: Dictionary) -> bool:
		var y := _box(p).get_center().y
		return String(p.role).begins_with(prefix) and y >= y0 - 0.02 and y <= y0 + 2.98)


## Braces of `role` hanging under the storey whose floor is y0.
func _braces(parts: Array, role: StringName, y0: float) -> Array:
	return parts.filter(func(p: Dictionary) -> bool:
		var box := _box(p)
		return p.role == role and box.end.y >= y0 - 0.3 and box.end.y <= y0 + 0.01)


## The default step-in: ground two jetties in, first upper storey one, top two on the line.
func _stepped(kit: BuildingKit, mass: BuildingMass) -> void:
	FIXTURE.write_step_in(mass, kit, 3, [-2.0, -1.0, 0.0, 0.0] as Array[float])


func test_each_storey_wall_stands_its_offset_inside_the_line() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := _house()
	_stepped(kit, mass)
	var expected := [1.0, 0.5, 0.0, 0.0] # south slot centre z in cells (= -offset / 2)
	for index in 4:
		for slot: Dictionary in BuildingKitAssembler.storey_slots(mass.storeys[index]):
			if int(slot.dir) == 3:
				assert_almost_eq(float(slot.centre.y), float(expected[index]), 1e-5, "storey %d" % index)
	for part: Dictionary in _at(_parts(mass), "wall.", 0.0):
		var box := _box(part)
		if box.size.x > box.size.z and box.get_center().z < 3.0:
			assert_almost_eq(box.get_center().z, 2.0, 0.2, "ground south wall two jetties in")


func test_a_ground_door_moves_in_with_its_wall() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := _house(4, 3)
	_stepped(kit, mass)
	var doors := _parts(mass).filter(func(p: Dictionary) -> bool: return String(p.role) == "wall.timber.door")
	assert_eq(doors.size(), 1)
	assert_almost_eq(_box(doors[0]).get_center().z, 2.0, 0.3, "the shopfront door stands in its stepped-in wall")


func test_the_corner_panels_beside_a_stepped_in_run_give_way() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := _house()
	_stepped(kit, mass)
	var parts := _parts(mass)
	# Ground (a whole module in): the east and west corner panels are gone; each side
	# wall starts at the new corner (z 2), where one post stands.
	for part: Dictionary in _at(parts, "wall.", 0.0):
		var box := _box(part)
		if box.size.z > box.size.x:
			# A panel's own edge post covers the corner square: it reaches kit.wall_face past
			# the corner line, exactly as at an unstepped corner (z -0.16).
			assert_true(box.position.z >= 2.0 - kit.wall_face - 0.05, "side panel at z %.2f" % box.position.z)
	assert_eq(_at(parts, "frontage.return.d", 0.0).size(), 0, "a whole-module cut takes no strip")
	for x: float in [0.0, 6.0]:
		var posts := _at(parts, "post.timber", 0.0).filter(func(p: Dictionary) -> bool:
			var c := _box(p).get_center()
			return absf(c.x - x) < 0.3 and absf(c.z - 2.0) < 0.3)
		assert_eq(posts.size(), 1, "one post at the ground's new corner x %.0f" % x)
	# First upper storey (one jetty in): the d100 strip on the inner half of each corner panel.
	var strips := _at(parts, "frontage.return.d100", 3.0)
	assert_eq(strips.size(), 2)
	for strip: Dictionary in strips:
		var box := _box(strip)
		assert_almost_eq(box.position.z, 1.0, 0.03, "the strip starts at the stepped-in face")
		assert_almost_eq(box.end.z, 2.0, 0.03, "and meets the next panel")
		assert_true(box.position.y <= 3.05 and box.end.y >= 5.85, "it spans the storey's height")
	for y0: float in [6.0, 9.0]:
		assert_eq(_at(parts, "frontage.return.d", y0).size(), 0, "the top storeys keep full side walls")


func test_overhang_braces_stand_on_module_joints_never_over_an_opening() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := _house(4, 3) # a ground door on the stepping face (x 2..4)
	_stepped(kit, mass)
	var parts := _parts(mass)
	var faces := {1: [-1.0, -2.0], 2: [0.0, -1.0]} # storey: [its offset, the offset below]
	for index: int in faces:
		var y0 := 3.0 * index
		var braces := _braces(parts, &"bracket.jetty", y0)
		var xs := braces.map(func(p: Dictionary) -> float: return snappedf(_box(p).get_center().x, 0.5))
		xs.sort()
		assert_eq(xs, [0.0, 2.0, 4.0, 6.0], "one brace per module joint under storey %d" % index)
		for brace: Dictionary in braces:
			var box := _box(brace)
			assert_almost_eq(box.end.z, -float(faces[index][1]), 0.1, "it bears on the stepped-in wall below")
			assert_true(box.position.z <= -float(faces[index][0]) + 0.05, "it reaches the overhanging face")
			assert_almost_eq(box.position.y, y0 - 1.0, 0.25, "it drops one jetty")
	assert_eq(_braces(parts, &"bracket.jetty", 9.0).size(), 0, "a held storey adds no overhang")
	assert_eq(parts.filter(func(p: Dictionary) -> bool: return p.role == &"bracket.small").size(), 0)


func test_a_half_step_overhang_takes_small_brackets_on_the_joints() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := _house()
	FIXTURE.write_step_in(mass, kit, 3, [-1.5, -1.0, -0.5, 0.0] as Array[float])
	var parts := _parts(mass)
	assert_eq(parts.filter(func(p: Dictionary) -> bool: return p.role == &"bracket.jetty").size(), 0)
	for index: int in [1, 2, 3]:
		var y0 := 3.0 * index
		var xs := parts.filter(func(p: Dictionary) -> bool:
			var c := _box(p).get_center()
			return p.role == &"bracket.small" and c.y < y0 and c.y > y0 - 1.2).map(
				func(p: Dictionary) -> float: return snappedf(_box(p).get_center().x, 0.5))
		xs.sort()
		assert_eq(xs, [0.0, 2.0, 4.0, 6.0], "storey %d" % index)
	assert_eq(_at(parts, "frontage.return.d050", 0.0).size(), 2, "ground 1.5 in: the 0.5 strips")
	assert_eq(_at(parts, "frontage.return.d150", 6.0).size(), 2, "storey 2 0.5 in: the 1.5 strips")


func test_a_stepped_in_upper_floor_ends_at_its_wall_and_the_ground_floor_stays_whole() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := _house()
	_stepped(kit, mass)
	var parts := _parts(mass)
	var boards := func(role: StringName, y: float) -> Array:
		return parts.filter(func(p: Dictionary) -> bool:
			return p.role == role and absf(_box(p).get_center().y - y) < 0.3)
	assert_eq((boards.call(&"deck.board", 0.0) as Array).size(), 6,
		"the ground keeps every board: the paving under the overhang")
	var upper: Array = boards.call(&"deck.board", 3.0)
	assert_eq(upper.size(), 3, "storey 1 keeps only its back row of boards")
	for board: Dictionary in upper:
		assert_gt(_box(board).get_center().z, 2.0)
	var strips: Array = boards.call(&"frontage.floor.d100", 3.0)
	assert_eq(strips.size(), 3, "the front row keeps its inner half")
	for strip: Dictionary in strips:
		var box := _box(strip)
		assert_almost_eq(box.position.z, 1.0, 0.03, "the floor ends at the stepped-in wall")
		assert_almost_eq(box.end.z, 2.0, 0.03)
	assert_eq((boards.call(&"deck.board", 6.0) as Array).size(), 6, "the storeys on the line are whole")


func test_the_overhang_closes_its_open_sides_once() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := _house()
	_stepped(kit, mass)
	var parts := _parts(mass)
	# Storey 1: its own corner strips' bottom beams close the overhang's sides (no
	# second beam there); storey 2 stands on the line: one return beam per side.
	for y0: float in [3.0, 6.0]:
		var z := 1.5 if y0 == 3.0 else 0.5 # mid-overhang, between the two faces
		var beams := parts.filter(func(p: Dictionary) -> bool:
			var c := _box(p).get_center()
			return p.role == &"frontage.return_beam.d100" and absf(c.y - y0) < 0.3 \
				and absf(c.z - z) < 0.3 and (absf(c.x) < 0.3 or absf(c.x - 6.0) < 0.3))
		assert_eq(beams.size(), 2, "one beam per open side at the floor y %.0f" % y0)


func test_a_wrapped_corner_steps_in_both_faces_with_one_post() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := _house()
	# South: its right (west) end wraps; west: its left (south) end wraps.
	FIXTURE.write_step_in(mass, kit, 3, [-2.0, -1.0, 0.0, 0.0] as Array[float], [&"return", &"wrap"])
	FIXTURE.write_step_in(mass, kit, 2, [-2.0, -1.0, 0.0, 0.0] as Array[float], [&"wrap", &"return"])
	var parts := _parts(mass)
	var near := func(p: Dictionary, x: float, z: float, reach: float) -> bool:
		var c := _box(p).get_center()
		return absf(c.x - x) < reach and absf(c.z - z) < reach
	# Storey 1: each face's corner panel keeps a d100 strip; one post at (1, 1).
	assert_eq(_at(parts, "frontage.return.d100", 3.0).filter(func(p: Dictionary) -> bool:
		return near.call(p, 1.5, 1.5, 0.7)).size(), 2, "one strip on each face at the corner")
	assert_eq(_at(parts, "post.timber", 3.0).filter(func(p: Dictionary) -> bool:
		return near.call(p, 1.0, 1.0, 0.3)).size(), 1, "one post at the stepped-in corner")
	var squares := parts.filter(func(p: Dictionary) -> bool:
		return p.role == &"frontage.corner.d100" and absf(_box(p).get_center().y - 3.0) < 0.3)
	assert_eq(squares.size(), 1, "the corner cell's floor keeps its inner square")
	assert_almost_eq(_box(squares[0]).position.x, 1.0, 0.03)
	assert_almost_eq(_box(squares[0]).position.z, 1.0, 0.03)
	# Ground: both corner panels are gone (a whole module); the post stands at (2, 2).
	assert_eq(_at(parts, "post.timber", 0.0).filter(func(p: Dictionary) -> bool:
		return near.call(p, 2.0, 2.0, 0.3)).size(), 1)
	# No brace where nothing stands below: the outer corner of each overhang.
	assert_eq(_braces(parts, &"bracket.jetty", 3.0).filter(func(p: Dictionary) -> bool:
		var c := _box(p).get_center()
		return c.x < 1.4 and c.z < 1.4).size(), 0, "storey 1's corner overhangs the ground's recess")
	assert_eq(_braces(parts, &"bracket.jetty", 6.0).filter(func(p: Dictionary) -> bool:
		var c := _box(p).get_center()
		return c.x < 0.6 and c.z < 0.6).size(), 0, "storey 2's corner overhangs storey 1's recess")
	assert_eq(parts.filter(func(p: Dictionary) -> bool:
		return String(p.role).begins_with("frontage.return_beam") and absf(_box(p).get_center().y - 6.0) < 0.3 \
			and near.call(p, 0.5, 0.5, 0.6)).size(), 0, "no return beam inside a wrapped corner")


func test_a_buried_end_closes_the_recess_against_the_own_wing() -> void:
	# An L: the body (x 0..2, z 0..1) and a wing (x 3, z -1..1) standing out in front of
	# the body's south face. The body's south run steps in; its east end meets the wing.
	var kit := SuntailBuildingKit.create()
	var mass := BuildingMass.new()
	mass.stable_id = &"kit.fixture.front"
	var cells := BuildingMass.rect_cells(Rect2i(0, 0, 3, 2))
	cells.merge({Vector2i(3, -1): true, Vector2i(3, 0): true, Vector2i(3, 1): true})
	for s in 4:
		mass.add_storey(s * 2, cells.duplicate(), BuildingMass.MATERIAL_TIMBER)
	var run: Array[Vector3i] = []
	for x in 3:
		run.append(BuildingMass.edge_key(Vector2i(x, 0), 3))
	FIXTURE.write_step_in(mass, kit, 3, [-2.0, -1.0, 0.0, 0.0] as Array[float], [&"bury", &"return"], run)
	var parts := _parts(mass)
	for index: int in [0, 1]:
		var depth := 2.0 - float(index)
		var strips := _at(parts, "frontage.return.%s" % BuildingKitAssembler.lean_suffix(depth), 3.0 * index) \
			.filter(func(p: Dictionary) -> bool: return absf(_box(p).get_center().x - 6.0) < 0.3)
		assert_eq(strips.size(), 1, "storey %d: one strip on the wing's line" % index)
		var box := _box(strips[0])
		assert_almost_eq(box.position.z, 0.0, 0.05, "from the lot line")
		assert_almost_eq(box.end.z, depth, 0.05, "to the stepped-in wall")


func test_a_stone_ground_storey_steps_in_a_whole_module_without_a_strip() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := _house()
	mass.storeys[0].material = BuildingMass.MATERIAL_STONE
	_stepped(kit, mass)
	var stone := _at(_parts(mass), "wall.stone.", 0.0)
	assert_gt(stone.size(), 0)
	for part: Dictionary in stone:
		var box := _box(part)
		if box.size.x > box.size.z and box.get_center().z < 3.0:
			assert_almost_eq(box.get_center().z, 2.0, 0.3, "the stone run stands a module in")
		elif box.size.z > box.size.x:
			assert_true(box.position.z >= 2.0 - kit.wall_face - 0.05, "no stone side panel left in the recess")


func test_offsets_of_zero_write_nothing() -> void:
	var kit := SuntailBuildingKit.create()
	var plain := _house()
	var held := _house()
	FIXTURE.write_step_in(held, kit, 3, [0.0, 0.0, 0.0, 0.0] as Array[float])
	assert_eq(str(_parts(held)), str(_parts(plain)))
	for storey: Dictionary in held.storeys:
		for slot: Dictionary in BuildingKitAssembler.storey_slots(storey):
			assert_eq(float(slot.short), 0.0)
			assert_false(bool(slot.get("dropped", false)))
