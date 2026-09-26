extends GutTest

func _house(seed_value: int) -> BuildingMass:
	var mass := BuildingMass.new()
	mass.seed = seed_value
	for floor in 4:
		mass.add_storey(floor * 2, BuildingMass.rect_cells(Rect2i(0, 0, 7, 4)), BuildingMass.MATERIAL_TIMBER)
	return mass

func test_long_walls_receive_spaced_bays() -> void:
	for seed_value in 12:
		var mass := _house(seed_value)
		BuildingDesigner.new(SuntailBuildingKit.create()).articulate(mass, {})
		for storey: Dictionary in mass.storeys.slice(1):
			var faces := {}
			for edge: Vector3i in storey.openings:
				if storey.openings[edge] != BuildingMass.OPENING_BAY: continue
				faces[edge.z] = true
				for other: Vector3i in storey.openings:
					if edge == other or edge.z != other.z: continue
					if storey.openings[other] == BuildingMass.OPENING_BAY:
						assert_gt(Vector2(edge.x, edge.y).distance_to(Vector2(other.x, other.y)), 1.0,
							"adjacent oriel roofs must leave a plain wall bay between them")
			assert_eq(faces.size(), 4, "every unobstructed substantial upper face has depth")

func test_city_house_has_recessed_balconies_at_multiple_levels() -> void:
	var house := {"storeys": {}, "cells": [], "doors": [], "terrain_band": 0}
	for floor in 4:
		house.storeys[floor * 2] = BuildingMass.rect_cells(Rect2i(0, 0, 7, 4))
	var mass := KitVillageBuildings._mass_for(&"test", house, WarrenSpatialGrid.new(Vector3i.ZERO, Vector3i.ONE), {}, 11, SuntailBuildingKit.create())
	var levels := {}
	var covered := 0
	for deck: Dictionary in mass.decks:
		if deck.band >= 8: continue
		levels[deck.band] = true
		for cell: Vector2i in deck.cells:
			assert_true(mass.cells_at_band(deck.band - 1).has(cell), "loggia floor belongs to the lower room")
			assert_false(mass.cells_at_band(deck.band).has(cell), "balcony is recessed into the room")
			if mass.cells_at_band(deck.band + 2).has(cell): covered += 1
	assert_gte(levels.size(), 2)
	assert_gt(covered, 0, "at least one balcony has a room as its ceiling")

func test_wraparound_outer_corner_is_braced_back_to_real_wall() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-3, 0, -3), Vector3i(8, 12, 8))
	var transaction := grid.begin_transaction(&"house")
	transaction.assign_use([Vector3i(0, 6, 0)], WarrenSpatialGrid.Use.PRIVATE_VOLUME, &"room")
	assert_true(grid.commit_transaction(transaction))
	var deck := {Vector2i(1, 0): true, Vector2i(0, 1): true, Vector2i(1, 1): true}
	var bearing := KitVillageBuildings._balcony_bearing(grid, deck, Vector2i(1, 1), 6)
	assert_false(bearing.is_empty(), "outer L corner needs diagonal wall bearing")
	if not bearing.is_empty(): assert_eq(bearing.wall, Vector2.ONE)

func test_recessed_balconies_have_native_floors_and_capsule_headroom() -> void:
	var masses := preload("res://tests/harness/suntail/gallery_masses.gd").masses("loggias", 8, 11, SuntailBuildingKit.create())
	var kit := SuntailBuildingKit.create()
	var stage := Node3D.new()
	add_child_autofree(stage)
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var probes: Array[Vector3] = []
	for index in masses.size():
		var mass: BuildingMass = masses[index]
		var offset := Vector3(index * 30, 0, 0)
		var payload := EnvironmentInstancePayload.new()
		BuildingKitAssembler.append_to_payload(BuildingKitAssembler.new(kit).assemble(mass), Transform3D(Basis.IDENTITY, offset), payload)
		EnvironmentCollisionBuilder.commit(stage, payload, cache, StringName("loggia%d" % index))
		for deck: Dictionary in mass.decks:
			if deck.band >= mass.top_band(): continue
			for cell: Vector2i in deck.cells:
				probes.append(offset + Vector3(cell.x * 2 + 1, deck.band * 1.5, cell.y * 2 + 1))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := stage.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	# Native kit is rendered at 1.5x in world; match the live player's capsule.
	capsule.radius = 0.39746094 / 1.5
	capsule.height = 2.244 / 1.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.margin = 0.01
	for at: Vector3 in probes:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at - Vector3.UP * 0.2))
		assert_false(hit.is_empty(), "missing balcony floor")
		if hit.is_empty(): continue
		query.transform = Transform3D(Basis.IDENTITY, Vector3(at.x, hit.position.y + capsule.height * 0.5 + 0.03, at.z))
		assert_true(space.intersect_shape(query).is_empty(), "balcony headroom obstructed at %s" % at)
	assert_gt(probes.size(), 24)
