extends GutTest
## September 29 town review, photo 11 (Town B = city 1998423929946073270
## compact, world (216,480), seed 2697992464): "a bunch of the same roof at
## the same level, facing in the same direction". Planner lots are one macro
## cell (2x2 modules) or 2x4; built one by one, every square crown ran its
## ridge along X (a fixed tie-break) and side-by-side lots stood as twin
## gables. Adjacent lots now merge into compound buildings and square crowns
## choose their ridge per house. Metric: tests/fixtures/roofline_variety.gd.
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
const AUDIT := preload("res://tests/fixtures/kit_roof_audit.gd")
const VARIETY := preload("res://tests/fixtures/roofline_variety.gd")


func _lot(cells: Rect2i, floors: Array, door_dir: int) -> Dictionary:
	var house := {"cells": [], "storeys": {}, "doors": [], "terrain_band": floors[0],
		"landmark": false}
	for floor: int in floors:
		house.storeys[floor] = BuildingMass.rect_cells(cells)
		for cell: Vector2i in house.storeys[floor]:
			(house.cells as Array).append(Vector3i(cell.x, floor, cell.y))
			(house.cells as Array).append(Vector3i(cell.x, floor + 1, cell.y))
	var at := cells.position
	(house.doors as Array).append({"cell": Vector3i(at.x, floors[0], at.y),
		"direction": Vector3i(BuildingMass.DIRS[door_dir].x, 0, BuildingMass.DIRS[door_dir].y)})
	return house


func _design(house: Dictionary, seed_value: int) -> BuildingMass:
	var mass := BuildingMass.new()
	mass.stable_id = &"kit.test"
	mass.seed = seed_value
	var floors: Array = (house.storeys as Dictionary).keys()
	floors.sort()
	mass.ground_band = int(house.terrain_band)
	for floor: int in floors:
		var storey := mass.add_storey(floor, house.storeys[floor], BuildingMass.MATERIAL_TIMBER)
		if house.has("roof_crowns"):
			storey["roofed"] = (house.roof_crowns as Dictionary).get(floor, {})
	for door: Dictionary in house.doors:
		var cell := door.cell as Vector3i
		var direction := door.direction as Vector3i
		var storey := BuildingDesigner._storey_at(mass, cell.y)
		storey.openings[BuildingMass.edge_key(Vector2i(cell.x, cell.z),
			BuildingMass.DIRS.find(Vector2i(direction.x, direction.z)))] = BuildingMass.OPENING_DOOR
	BuildingDesigner.new(SuntailBuildingKit.create()).articulate(mass,
		{"terrain_storey": 0, "terraced": true})
	return mass


## The fixed tie-break: a square crown always ran its ridge along X.
func test_square_crowns_mix_gable_and_eave_fronts() -> void:
	var gable_front := 0
	var count := 40
	for seed_value in count:
		var mass := _design(_lot(Rect2i(0, 0, 2, 2), [0, 2], 1), seed_value)
		assert_eq(mass.roofs.size(), 1, "one crown roof")
		if int(mass.roofs[0].axis) == 1:
			gable_front += 1
	assert_between(gable_front, count / 4, count * 3 / 4,
		"square houses face the street with both gables and eaves (%d/%d gable-fronted)" % [gable_front, count])


## October owner refinement supersedes the always-one-large-range pin.
## Small joins remain useful, but most broad clusters keep distinct houses.
func test_large_plain_ranges_are_a_seeded_minority_and_preserve_every_lot() -> void:
	var houses := {}
	for k in 3:
		houses[StringName("lot.%d" % k)] = _lot(Rect2i(0, 2 * k, 4, 2), [0], 0)
	var ranges := 0
	for seed_value in 64:
		var merged := KitVillageBuildings.merge_houses(houses,seed_value)
		assert_eq(merged,KitVillageBuildings.merge_houses(houses,seed_value))
		ranges += int(merged.size()==1)
		var cells := {}
		var doors := 0
		for house: Dictionary in merged.values():
			doors += house.doors.size()
			for cell: Vector3i in house.cells:
				assert_false(cells.has(cell),"no duplicate ownership")
				cells[cell] = true
			var mass := _design(house,seed_value)
			assert_gt(mass.roofs.size(),0,"every retained house still gets a complete roof")
		assert_eq(cells.size(),48,"no building mass is discarded")
		assert_eq(doors,3,"every original address survives")
	assert_between(ranges,1,20,"large simple buildings remain possible but uncommon")

func test_corner_cluster_can_keep_an_articulated_compound() -> void:
	var houses := {&"lot.a":_lot(Rect2i(0,0,2,2),[0],0),
		&"lot.b":_lot(Rect2i(2,0,2,2),[0],0),
		&"lot.c":_lot(Rect2i(0,2,2,2),[0],0)}
	var merged := KitVillageBuildings.merge_houses(houses,7)
	assert_eq(merged.size(),1)
	var house: Dictionary = merged.values()[0]
	assert_eq(house.storeys[0].size(),12)
	assert_eq(BuildingDesigner._bounds(house.storeys[0]).get_area(),16,
		"the courtyard notch remains real occupied-footprint geometry")
	var mass := _design(house,7)
	assert_gt(mass.roofs.size(),1,"the L has distinct roof wings")


## A taller lot beside a lower one: one building, each part keeps its own
## pitched roof (the lower crown is not turned into a terrace).
func test_stepped_compound_roofs_every_part() -> void:
	var houses := {&"lot.a": _lot(Rect2i(0, 0, 2, 2), [0, 2], 0),
		&"lot.b": _lot(Rect2i(0, 2, 2, 2), [0], 0)}
	var merged := KitVillageBuildings.merge_houses(houses, 1)
	assert_eq(merged.size(), 1, "the two lots are one building")
	var mass := _design(merged.values()[0], 5)
	var eaves := {}
	for roof: Dictionary in mass.roofs:
		eaves[int(roof.eave_band)] = true
	assert_true(eaves.has(2) and eaves.has(4), "both parts are roofed: %s" % [mass.roofs])
	assert_eq(mass.decks.size(), 0, "no crown became a terrace")


## A lot carrying a building that cannot merge (a bridge-house standing on
## nothing, or a landmark) keeps its identity.
func test_lot_bearing_a_bridge_house_keeps_its_identity() -> void:
	var bridge := _lot(Rect2i(2, 0, 2, 2), [2], 0)
	bridge.terrain_band = 1 << 20
	var houses := {&"lot.a": _lot(Rect2i(0, 0, 2, 2), [0, 2], 0),
		&"lot.b": _lot(Rect2i(0, 2, 2, 2), [0, 2], 0), &"lot.bridge": bridge}
	var merged := KitVillageBuildings.merge_houses(houses, 1)
	assert_true(merged.has(&"lot.a") and not (merged[&"lot.a"] as Dictionary).has("members"),
		"the bridge's bearing lot stands alone")
	assert_true(merged.has(&"lot.bridge"), "the bridge-house stays")


## The photo towns (Town B now rolls a raised citadel with a one-storey
## lower town, so each has only ~15 roofed houses): ridges on both axes
## (0.13 / 0.19 before this review), compound buildings, few twin gables,
## and the roof invariants of September 27 intact.
func test_photo_towns_roofline_variety() -> void:
	var kit := SuntailBuildingKit.create()
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for city: Array in [[1998423929946073270, &"compact"], [1260018864828801968, &"compact"]]:
		var source := WarrenMazeSitePlanner.plan(city[0], {},
			WarrenVillageScaleProfile.for_id(city[1]), &"", false)
		var spatial := FROZEN.spatial(source, program)
		var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), kit)
		var v := VARIETY.measure(built, kit)
		assert_gt(float(v.axis_minority), 0.25, "%s ridges run both ways %s" % [city, v])
		assert_lte(int(v.twins), 3, "%s side-by-side twin gables %s" % [city, v.examples])
		# Town A (the photo-7 town, not photo 11) was re-laid by the edges
		# stream's perimeter lane into detached rim cottages: 20 houses, 3
		# touching pairs, so a merged compound cannot arise there. Its one
		# L-shaped house is a parcel joined by its own back room.
		assert_gt(int(v.compound), 1 if city[0] == 1998423929946073270 else 0,
			"%s compound buildings %s" % [city, v])
		var audit := AUDIT.audit(built, kit)
		for key: String in ["tiny", "open_exposed", "gable_holes", "air_unsupported", "eaves_cut"]:
			assert_eq(int(audit[key]), 0, "%s %s %s" % [city, key, audit.examples])


## A corpus of compact and standard towns on the integrated tree (edges,
## tiers): ridges run both ways (minority axis 0.28 before this review, 0.44
## now), twin gables stay below the review baseline (0.21 of touching pairs;
## 0.18 with lot merging disabled, 0.16 with it), and about a quarter of the
## houses are compound (0.03 without merging).
func test_corpus_roofline_variety() -> void:
	var kit := SuntailBuildingKit.create()
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var pairs := 0
	var twins := 0
	var minority := 0.0
	var houses := 0
	var compound := 0
	var towns := 0
	for city: Array in [[1, &"compact"], [2, &"compact"], [3, &"compact"], [4, &"compact"],
			[2, &"standard"], [3, &"standard"]]:
		var source := WarrenMazeSitePlanner.plan(city[0], {},
			WarrenVillageScaleProfile.for_id(city[1]), &"", false)
		var spatial := FROZEN.spatial(source, program)
		var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), kit)
		var v := VARIETY.measure(built, kit)
		pairs += int(v.pairs)
		twins += int(v.twins)
		minority += float(v.axis_minority)
		houses += int(v.houses)
		compound += int(v.compound)
		towns += 1
	assert_lt(float(twins) / float(pairs), 0.18, "twin share %d/%d" % [twins, pairs])
	# Re-pinned 0.38 -> 0.34 (September 29, stabilize): a maze back room is
	# now its parcel's own room (one kit house, not a twin gable beside its
	# host), so lots become deeper houses whose ridge follows their depth.
	# Measured on this corpus 0.41 -> 0.36; on the 22-town survey minority
	# 0.42 -> 0.39 while twin share fell 0.21 -> 0.15 and same-ridge pairs
	# 0.52 -> 0.45 (before this review: minority 0.26).
	assert_gt(minority / towns, 0.34, "mean minority-axis share %.2f" % [minority / towns])
	assert_gt(float(compound) / float(houses), 0.15, "compound share %d/%d" % [compound, houses])


## A maze back room (and a passage cover) is its parcel's own room: the plot
## planner decided one building. Built as a separate kit house it stood as a
## twin gable against its host (Town A: maze_back.03/04 beside house.007).
func test_back_rooms_belong_to_their_parcel_house() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var source := WarrenMazeSitePlanner.plan(1260018864828801968, {},
		WarrenVillageScaleProfile.for_id(&"compact"), &"", false)
	var spatial := FROZEN.spatial(source, program)
	var back_rooms := 0
	for building: WarrenBuildingVolume in spatial.buildings:
		if String(building.stable_id).begins_with("spatial.maze_back."):
			back_rooms += 1
	assert_gt(back_rooms, 0, "Town A stamps back rooms")
	var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(),
		SuntailBuildingKit.create())
	for mass: BuildingMass in built.masses:
		assert_false(String(mass.stable_id).begins_with("kit.spatial.maze_back."),
			"%s is built as its own house" % mass.stable_id)
