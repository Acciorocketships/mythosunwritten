extends GutTest
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
const CLEARANCE := preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")

func test_sloped_walking_air_follows_surface_and_excludes_guards() -> void:
	var mesh := {"vertices": PackedVector3Array([Vector3.ZERO, Vector3(2, 1, 0),
		Vector3(0, 0, 2), Vector3(0, 3, 0), Vector3(2, 3, 0), Vector3(0, 3, 2)]),
		"normals": PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP,
		Vector3.UP, Vector3.UP, Vector3.UP]),
		"indices": PackedInt32Array([0, 1, 2, 3, 4, 5]),
		"guard_index_ranges": [Vector2i(3, 6)]}
	var volumes := CLEARANCE.from_mesh(mesh, Transform3D.IDENTITY, 2.4)
	assert_eq(volumes.size(), 1, "guard tops must not generate walking air")
	if volumes.size() != 1: return
	assert_true(_inside(volumes[0], Vector3(0.5, 2.64, 0.5)))
	assert_false(_inside(volumes[0], Vector3(0.5, 2.66, 0.5)))
	assert_false(_inside(volumes[0], Vector3(0.5, 0.24, 0.5)))
	assert_false(_inside(volumes[0], Vector3(1.5, 1.5, 1.5)))
	mesh.normals = PackedVector3Array([Vector3.DOWN, Vector3.DOWN, Vector3.DOWN,
		Vector3.UP, Vector3.UP, Vector3.UP])
	assert_true(CLEARANCE.from_mesh(mesh, Transform3D.IDENTITY, 2.4).is_empty(),
		"undersides must not become walking surfaces")

func _inside(volume: Dictionary, point: Vector3) -> bool:
	for plane: Plane in volume.planes:
		if plane.distance_to(point) > 0.0001: return false
	return true

func test_every_finished_stair_tread_has_roof_clearance() -> void:
	var seed_value := 1260018864828801968
	var source := WarrenMazeSitePlanner.plan(seed_value, {},
		WarrenVillageScaleProfile.select(seed_value), &"", false)
	var checked := 0
	var missed := 0
	# Keep the reported stairs even when a new procedural layout moves them.
	for candidate: WarrenMazeSourcePlan in [source,
			FROZEN.read("res://tests/fixtures/october1-photo-roofs-source.txt")]:
		var result := _stair_clearance(candidate)
		checked += int(result.checked)
		missed += int(result.missed)
	assert_gt(checked, 20)
	assert_eq(missed, 0, "roof clearance must follow finished treads, not quantized route bands")

func _stair_clearance(source: WarrenMazeSourcePlan) -> Dictionary:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := FROZEN.spatial(source, program)
	var fabric := spatial.compiled_fabric_cache()
	var kit := SuntailBuildingKit.create()
	var built := KitVillageBuildings.build(spatial, fabric, kit)
	var to_native := KitVillageBuildings.native_to_lattice(kit).affine_inverse()
	var height := TraversalEnvelope.MIN_HEADROOM / VillageWorldScale.VERTICAL_SCALE
	var checked := 0
	var missed := 0
	for mesh: Dictionary in fabric.surface_plan.mesh_payloads:
		if not bool(mesh.get("is_transition", false)): continue
		for i in range(0, mesh.indices.size(), 3):
			var guard := false
			for span: Vector2i in mesh.get("guard_index_ranges", []):
				guard = guard or (i >= span.x and i < span.y)
			if guard or (mesh.normals[mesh.indices[i]] as Vector3).y < 0.5: continue
			var point := Vector3.ZERO
			for k in 3: point += mesh.vertices[mesh.indices[i + k]] / 3.0
			point = to_native * (point + Vector3.UP * (height - 0.03))
			var covered := false
			for volume: Dictionary in built.walls:
				if not bool(volume.get("open", false)): continue
				var inside := true
				for plane: Plane in volume.planes:
					inside = inside and plane.distance_to(point) <= 0.0001
				covered = covered or inside
			checked += 1
			if not covered: missed += 1
	return {"checked":checked,"missed":missed}
