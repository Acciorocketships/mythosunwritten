extends GutTest
const FIXTURE := preload("res://tests/fixtures/growing_house.gd")
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")
const PROJECTIONS := preload("res://scripts/terrain/features/villages/kit/KitRoomProjections.gd")
const BAYS := preload("res://scripts/terrain/features/villages/kit/KitTownFacadeBays.gd")


func test_each_street_storey_leans_one_step_further() -> void:
	var f := FIXTURE.build()
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.25, 0.5, 0.75] as Array[float])
	assert_eq(FIXTURE.leans_on(f.front, 1), [0.0, 0.0, 0.0, 0.0] as Array[float],
		"the back face is not a street and other-face chance is 0")
	for index in range(1, 4):
		var lean := 0.25 * index
		for slot: Dictionary in BuildingKitAssembler.storey_slots(f.front.storeys[index]):
			if int(slot.dir) == 3:
				assert_almost_eq(float(slot.centre.y), -lean / 2.0, 1e-5, "offset in module units")
			else:
				assert_eq(float(slot.wall_offset), 0.0, "other faces stay on the lot line")
	assert_false(f.front.storeys[0].has("wall_offsets"), "the ground storey keeps the lane's width")


func test_cap_floors_to_whole_steps() -> void:
	var f := FIXTURE.build({"storeys": 5, "character": FIXTURE.character({&"growth_max_lean": 0.9})})
	assert_eq(FIXTURE.leans_on(f.front, 3), [0.0, 0.25, 0.5, 0.75, 0.75] as Array[float])
	var g := FIXTURE.build({"storeys": 5, "character": FIXTURE.character({&"growth_max_lean": 1.5}, &"0.5")})
	assert_eq(FIXTURE.leans_on(g.front, 3), [0.0, 0.5, 1.0, 1.5, 1.5] as Array[float])


func test_every_step_is_closed_by_floor_beam_returns_and_brackets() -> void:
	var f := FIXTURE.build()
	var catalog := EnvironmentCatalog.load_default()
	for index in range(1, 4):
		var lean := 0.25 * index
		var base := 0.25 * (index - 1)
		var suffix := BuildingKitAssembler.lean_suffix(lean)
		var y0 := float(f.front.storeys[index].floor_band) * 1.5
		var floors := 0
		var returns := 0
		var beams := 0
		var brackets := 0
		for part: Dictionary in f.parts:
			var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
			if box.position.y < y0 - 1.0 or box.position.y > y0 + 2.9:
				continue
			if part.role == StringName("frontage.floor." + suffix):
				floors += 1
				assert_almost_eq(box.position.z, -lean, 0.001)
				assert_almost_eq(box.end.z, 0.0, 0.001, "the strip meets the original room line")
			elif part.role == StringName("frontage.return." + suffix):
				returns += 1
				assert_almost_eq(box.position.z, -lean, 0.001)
				assert_almost_eq(box.end.z, 0.0, 0.001)
			elif part.role == StringName("frontage.return_beam." + suffix):
				beams += 1
			elif part.role == &"bracket.small" and box.end.y < y0 + 0.01:
				brackets += 1
				assert_almost_eq(box.end.z, 0.15 - base - 0.0727, 0.02,
					"brackets bear on the lower storey's (leaned) face")
		assert_eq(floors, 6, "floor and ceiling strip under each of 3 bays")
		assert_eq(returns, 2, "both side returns closed")
		assert_eq(beams, 4, "two return beams per side")
		assert_eq(brackets, 4, "a bracket at every module joint")


func test_growth_result_lists_each_leaned_storey() -> void:
	var f := FIXTURE.build()
	assert_eq(f.leans.size(), 3)
	for lean: Dictionary in f.leans:
		assert_eq(int(lean.dir), 3)
		assert_true((lean.bounds as AABB).has_volume())
	assert_almost_eq(float(f.result.registry[Vector4i(1, 0, 3, 4)]), 0.5, 1e-6)


## Removing the jetty must not reshuffle the house's other rolls: the jetty
## draw is still made, and the porch-canopy test still draws its 0.9.
func test_growing_house_takes_no_jetty_and_no_flush_canopy_but_keeps_its_rolls() -> void:
	var kit := SuntailBuildingKit.create()
	var jettied := 0
	var flush := 0
	var canopies := 0
	for seed_value in 60:
		var plain := FIXTURE.house(StringName("kit.j%d" % seed_value), Rect2i(0, 0, 4, 3), 3, 3)
		var grown := FIXTURE.house(StringName("kit.j%d" % seed_value), Rect2i(0, 0, 4, 3), 3, 3)
		BuildingDesigner.new(kit).articulate(plain, {"terrain_storey": 0})
		BuildingDesigner.new(kit).articulate(grown, {"terrain_storey": 0, "grows": true})
		assert_false(grown.storeys.any(func(s: Dictionary) -> bool: return bool(s.inset)))
		assert_false(grown.decor.any(func(d: Dictionary) -> bool:
			return d.kind == &"awning" and not bool(d.get("sheltered", false))))
		# Finish and roof design come after the jetty roll in articulate().
		for index in plain.storeys.size():
			assert_eq(grown.storeys[index].tint, plain.storeys[index].tint, "finish roll unchanged")
		assert_eq(grown.roofs, plain.roofs, "roof design unchanged")
		if plain.storeys.any(func(s: Dictionary) -> bool: return bool(s.inset)):
			jettied += 1
			continue
		# Without a jetty to remove, the wall slots are identical, so every facade
		# and dressing roll matches except the flush porch canopy itself.
		flush += 1
		for index in plain.storeys.size():
			assert_eq(grown.storeys[index].openings, plain.storeys[index].openings, "facade rolls unchanged")
		var kept := plain.decor.filter(func(d: Dictionary) -> bool:
			return not (d.kind == &"awning" and not bool(d.get("sheltered", false))))
		canopies += plain.decor.size() - kept.size()
		assert_eq(grown.decor, kept, "dressing rolls unchanged")
	assert_gt(jettied, 0, "some seed jetties the plain house")
	assert_gt(flush, 0, "some seed keeps the plain house flush")
	assert_gt(canopies, 0, "some flush house had a porch canopy to drop")


func test_projections_and_bays_skip_leaning_faces() -> void:
	var none := Callable(FIXTURE, "nothing_solid")
	var anything := func(_o: StringName, _c: Vector2i, _b: int) -> bool: return true
	var catalog := EnvironmentCatalog.load_default()
	var f := FIXTURE.build()
	var masses: Array[BuildingMass] = [f.front]
	var kits := {&"fixture.front": f.kit}
	var projections := PROJECTIONS.fit(masses, kits, f.kit, catalog, [], [], none, anything)
	assert_gt(projections.size(), 0, "the back face still takes a projection")
	for projection: Dictionary in projections:
		assert_ne(int(projection.dir), 3)
		assert_ne(int(projection.dir) % 2, 0, "no perpendicular front on a leaning storey")
	# A five-module house: both long faces are long enough for a bay.
	var wide := FIXTURE.house(&"kit.fixture.front", Rect2i(0, 0, 5, 2), 4, 3)
	wide.add_roof(Rect2i(0, 0, 5, 2), 0, 8, &"red")["union_index"] = 0
	var g := FIXTURE.build({"replace_front": wide})
	assert_eq(FIXTURE.leans_on(g.front, 3), [0.0, 0.25, 0.5, 0.75] as Array[float])
	var wide_masses: Array[BuildingMass] = [g.front]
	var bays := BAYS.fit(wide_masses, kits, g.kit, catalog, [], [], none)
	assert_gt(bays.size(), 0, "the back face still takes bays")
	for bay: Dictionary in bays:
		assert_ne((bay.edge as Vector3i).z, 3)
