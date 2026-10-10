extends GutTest
## Photo: world 2697992464, player (312.4,20.3,1096.9), hit (319,19,1097).
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
const AUDIT := preload("res://tests/fixtures/kit_roof_audit.gd")
static var _built: Dictionary = {}

func _town() -> Dictionary:
	if _built.is_empty():
		# Freeze the photographed roofs so future procedural layouts cannot
		# make this regression vacuous by replacing them with other houses.
		var source := FROZEN.read("res://tests/fixtures/october1-photo-roofs-source.txt")
		var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
		var spatial := FROZEN.spatial(source, program)
		_built = KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(),
			SuntailBuildingKit.create())
	return _built

func test_photo_roof_ends_do_not_project_into_the_raised_walkway() -> void:
	var built := _town()
	var kit := SuntailBuildingKit.create()
	var ctx := UNION.prepare(built.roofs, built.walls, kit, built.roof_kits)
	var checked := 0
	var intruding := 0
	# The two photographed gables bound the same four-native-metre walk.
	for placement: Dictionary in built.placements:
		var index := int(placement.get("roof_index", -1))
		if index < 0: continue
		var roof: Dictionary = built.roofs[index]
		var left: bool = roof.rect == Rect2i(-2, -4, 4, 2)
		var right: bool = roof.rect == Rect2i(4, -4, 2, 2)
		if not left and not right: continue
		if not ctx.data.has(placement.asset_id): continue
		var realized := UNION.realize(placement, ctx)
		var surfaces: Array = ctx.data[placement.asset_id] if realized.is_empty() else realized.meshes
		for surface: Dictionary in surfaces:
			for vertex: Vector3 in surface.vertices:
				var p: Vector3 = placement.transform * vertex if realized.is_empty() else vertex
				# Test roof skin and trims; gable facade remains intact on its own wall.
				if String(placement.role).begins_with("gable.") or String(placement.role).begins_with("chimney."): continue
				checked += 1
				if (left and p.x > 4.0 + kit.wall_face + 0.001) \
						or (right and p.x < 8.0 - kit.wall_face - 0.001):
					intruding += 1
	assert_gt(checked, 100, "examined the rendered native roofs, not just logical footprints")
	assert_eq(intruding, 0, "roof verges must stop at the facade beside the raised walk")

func test_photo_gables_remain_closed() -> void:
	var result := AUDIT.audit(_town(), SuntailBuildingKit.create())
	assert_eq(int(result.gable_holes), 0, "shorter verges must not open the attic")

func test_verge_fitting_rotates_and_keeps_ground_level_overhangs() -> void:
	var kit := SuntailBuildingKit.create()
	for axis in 2:
		var mass := BuildingMass.new()
		var roof := mass.add_roof(Rect2i(0, 0, 4, 4), axis, 4, &"red")
		var near := Vector3i(-1, 4, 1) if axis == 0 else Vector3i(1, 4, -1)
		var far := Vector3i(4, 0, 1) if axis == 0 else Vector3i(1, 0, 4)
		KitRoofJunctions.fit_public_verges([mass], [near, far], kit)
		assert_eq(float(roof.get("verge_min", -1.0)), kit.wall_face)
		assert_false(roof.has("verge_max"), "a street below the eave retains its roof overhang")

func test_open_branch_keeps_its_host_overlap() -> void:
	var mass := BuildingMass.new()
	var roof := mass.add_roof(Rect2i(0, 0, 4, 4), 0, 4, &"red")
	roof.open_min = true
	roof.extend_min = 2
	KitRoofJunctions.fit_public_verges([mass], [Vector3i(-1, 4, 1)], SuntailBuildingKit.create())
	assert_false(roof.has("verge_min"), "an open branch must remain buried in its host")

func test_trimmed_roof_collision_matches_rendered_faces() -> void:
	var count := 0
	for mesh: Dictionary in (_town().payload as EnvironmentInstancePayload).surface_meshes:
		if not String(mesh.stable_id).contains(".union."): continue
		count += 1
		var faces := PackedVector3Array()
		for index: int in mesh.indices: faces.append(mesh.vertices[index])
		assert_eq(mesh.collision_faces, faces)
	assert_gt(count, 0)
