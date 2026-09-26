extends GutTest

func test_lot_houses_have_compound_and_changing_floorplates() -> void:
	var kit := SuntailBuildingKit.create()
	var compound := 0
	var stepped := 0
	for seed_value in range(1000, 1032):
		var mass := KitStandaloneHouse.design(kit, 5, 4, 1, seed_value)
		var previous: Dictionary = mass.storeys[0].cells
		for storey: Dictionary in mass.storeys:
			var bounds := BuildingDesigner._bounds(storey.cells)
			if storey.cells.size() < bounds.get_area(): compound += 1
			if not BuildingDesigner._same_cells(previous, storey.cells): stepped += 1
			previous = storey.cells
			for cell: Vector2i in storey.cells:
				assert_true(Rect2i(0, 0, 5, 4).has_point(cell), "room leaves its reserved lot")
	assert_gt(compound, 24, "lot adapter must generate L/T floorplates")
	assert_gt(stepped, 12, "upper floors must vary independently")

func test_all_frontages_keep_a_door_and_connected_rooms() -> void:
	for dir in 4:
		for seed_value in 16:
			var mass := KitStandaloneHouse.design(SuntailBuildingKit.create(), 4, 3, dir, seed_value)
			var ground: Dictionary = mass.storeys[0]
			var doors := 0
			for edge: Vector3i in ground.openings:
				if ground.openings[edge] != BuildingMass.OPENING_DOOR: continue
				doors += 1
				var cell := Vector2i(edge.x, edge.y)
				assert_true(ground.cells.has(cell))
				assert_false(ground.cells.has(cell + BuildingMass.DIRS[edge.z]))
			assert_eq(doors, 1)
			for storey: Dictionary in mass.storeys:
				var seen := {}
				var pending: Array = [storey.cells.keys()[0]]
				while not pending.is_empty():
					var cell: Vector2i = pending.pop_back()
					if seen.has(cell): continue
					seen[cell] = true
					for step: Vector2i in BuildingMass.DIRS:
						if storey.cells.has(cell + step) and not seen.has(cell + step):
							pending.append(cell + step)
				assert_eq(seen.size(), storey.cells.size(), "no detached room")


func test_balconies_and_roof_crowns_have_native_collision() -> void:
	var kit := SuntailBuildingKit.create()
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var stage := Node3D.new()
	add_child_autofree(stage)
	var probes: Array[Dictionary] = []
	for i in 12:
		var mass := KitStandaloneHouse.design(kit, 5, 4, 1, 1000 + i)
		var offset := Vector3(i * 24, 0, 0)
		var payload := EnvironmentInstancePayload.new()
		BuildingKitAssembler.append_to_payload(BuildingKitAssembler.new(kit).assemble(mass),
			Transform3D(Basis.IDENTITY, offset), payload)
		EnvironmentCollisionBuilder.commit(stage, payload, cache, StringName("house%d" % i))
		for deck: Dictionary in mass.decks:
			for cell: Vector2i in deck.cells:
				probes.append({"at": offset + Vector3(cell.x * 2 + 1, deck.band * 1.5, cell.y * 2 + 1),
					"balcony": true})
		var crown: Dictionary = mass.storeys.back()
		for cell: Vector2i in crown.cells:
			probes.append({"at": offset + Vector3(cell.x * 2 + 1,
				(crown.floor_band + 2) * 1.5, cell.y * 2 + 1), "balcony": false})
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := stage.get_world_3d().direct_space_state
	var balconies := 0
	for probe: Dictionary in probes:
		var at: Vector3 = probe.at
		var rise := 0.4 if probe.balcony else 14.0
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			at + Vector3.UP * rise, at - Vector3.UP * 0.2))
		assert_false(hit.is_empty(), "native surface missing at %s" % at)
		if probe.balcony:
			balconies += 1
			if not hit.is_empty(): assert_almost_eq(hit.position.y, at.y + 0.12772, 0.03)
	assert_gt(balconies, 0)


func test_projecting_rooms_have_nearby_bearing_and_soffits() -> void:
	var kit := SuntailBuildingKit.create()
	for seed_value in range(1000, 1020):
		var mass := KitStandaloneHouse.design(kit, 5, 4, 1, seed_value)
		for i in range(1, mass.storeys.size()):
			var lower: Dictionary = mass.storeys[i - 1].cells
			for cell: Vector2i in mass.storeys[i].cells:
				if lower.has(cell): continue
				var supported := false
				for dir: Vector2i in BuildingMass.DIRS:
					supported = supported or lower.has(cell + dir)
				assert_true(supported, "projection must stay within one module of bearing")


func test_cross_gable_ridges_fit_below_their_host_roof() -> void:
	var kit := SuntailBuildingKit.create()
	for seed_value in range(1000, 1020):
		var mass := KitStandaloneHouse.design(kit, 5, 3, 1, seed_value)
		var main: Dictionary = mass.roofs[0]
		var host_rect: Rect2i = main.rect
		var host_depth := host_rect.size.y if main.axis == 0 else host_rect.size.x
		var host_height := float(kit.roof_profile(host_depth).height)
		for roof: Dictionary in mass.roofs:
			if not roof.open_min and not roof.open_max: continue
			var rect: Rect2i = roof.rect
			var depth := rect.size.y if roof.axis == 0 else rect.size.x
			assert_lte(float(kit.roof_profile(depth).height), host_height,
				"joined ridge must not become a fin above its host")


func test_roof_finishes_use_wood_colour_and_board_normals() -> void:
	var shades := {}
	for colour: String in ["red", "blue"]:
		var path := "res://terrain/environment/materials/suntail_village_kit/suntail_roof_roof_1_%s_piece_00_surface_00.tres" % colour
		var material := load(path) as StandardMaterial3D
		assert_not_null(material)
		assert_eq(material.albedo_texture.resource_path,
			"res://terrain/environment/textures/suntail_village_kit/173753758685fa88a5cb.res")
		assert_eq(material.normal_texture.resource_path,
			"res://terrain/environment/textures/suntail_village_kit/19c539ddc9e7ae32cf6b.res")
		assert_gt(material.albedo_color.r, material.albedo_color.g)
		assert_gt(material.albedo_color.g, material.albedo_color.b)
		assert_gte(material.roughness, 0.8)
		shades[material.albedo_color] = true
	assert_eq(shades.size(), 2, "houses retain distinct warm/weathered wood finishes")


func test_narrow_lots_keep_a_low_roof_along_the_long_axis() -> void:
	var kit := SuntailBuildingKit.create()
	for dir in 4:
		for size: Vector2i in [Vector2i(2, 5), Vector2i(6, 2)]:
			var mass := KitStandaloneHouse.design(kit, size.x, size.y, dir, 1001)
			for roof: Dictionary in mass.roofs:
				var rect: Rect2i = roof.rect
				var depth := rect.size.y if roof.axis == 0 else rect.size.x
				assert_lte(depth, 2, "narrow lots must not acquire oversized roof walls")
