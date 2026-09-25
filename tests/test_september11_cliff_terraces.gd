extends GutTest

class FloodedCliff extends WaterFieldContext:
	func is_wet(_point: Vector2) -> bool: return true
	func has_sources() -> bool: return true
	func coverage() -> Rect2: return Rect2(Vector2(-1000,-1000),Vector2(2000,2000))

class WetHalfPlane extends WaterFieldContext:
	var bounds: Rect2
	func _init(rect: Rect2) -> void: bounds = rect
	func is_wet(point: Vector2) -> bool:
		assert(bounds.has_point(point))
		return point.y > 100.0
	func has_sources() -> bool: return true
	func coverage() -> Rect2: return bounds

func test_wet_foot_exclusion_retains_chunk_independent_ownership() -> void:
	var terraces := preload("res://scripts/terrain/field/CliffTerraces.gd")
	terraces.prepare()
	var plan := HeightfieldPlan.new(17,64,12,"mean",4)
	plan.set_raw_height_override(func(cx: int, _cz: int) -> float: return 16.0 if cx <= 3 else 0.0)
	var region := plan.compute_region(4,4,12)
	var full := terraces.compute(region,0,0,8,99,null,WetHalfPlane.new(Rect2(0,0,192,192).grow(26)))
	var split: Array[Dictionary] = []
	for owner: Vector2i in [Vector2i(0,0),Vector2i(0,4),Vector2i(4,0),Vector2i(4,4)]:
		var water := WetHalfPlane.new(Rect2(Vector2(owner)*24,Vector2(96,96)).grow(26))
		split.append_array(terraces.compute(region,owner.x,owner.y,4,99,null,water).placements)
	assert_gt(full.placements.size(),0)
	assert_eq(split.size(),full.placements.size())
	for placement: Dictionary in full.placements: assert_true(split.has(placement))

func test_detached_worker_produces_identical_native_geometry() -> void:
	var terraces := preload("res://scripts/terrain/field/CliffTerraces.gd")
	terraces.prepare()
	var plan := HeightfieldPlan.new(17,64,12,"mean",4)
	plan.set_raw_height_override(func(cx: int, cz: int) -> float: return 0.0 if cx > 3 and cz > 3 else 16.0)
	var region := plan.compute_region(4,4,12)
	var expected := terraces.compute(region,0,0,8,1)
	var worker := Thread.new()
	assert_eq(worker.start(func() -> Dictionary: return terraces.compute(region,0,0,8,1)),OK)
	assert_eq(var_to_bytes(worker.wait_to_finish()),var_to_bytes(expected))
	var hosts: Dictionary = {}
	var rock_count := 0
	for placement: Dictionary in expected.placements:
		if placement.kind != "rock":
			hosts[placement.id] = placement
			continue
		rock_count += 1
		var host: Dictionary = hosts[String(placement.id).trim_suffix("/rock")]
		var box: AABB = placement.bounds
		var support: AABB = host.bounds
		assert_gte(box.position.x,support.position.x)
		assert_gte(box.position.z,support.position.z)
		assert_lte(box.end.x,support.end.x)
		assert_lte(box.end.z,support.end.z)
		assert_almost_eq(box.position.y,host.top-.03,.0001)
	assert_gt(rock_count,0,"The native rock branch is exercised")
	assert_lt(rock_count,expected.placements.size()/4,"Rock accents remain sparse")

func test_native_columns_do_not_fill_wet_cliff_foot_channels() -> void:
	var plan := HeightfieldPlan.new(17,64,12,"mean",4)
	plan.set_raw_height_override(func(cx: int, _cz: int) -> float: return 16.0 if cx <= 3 else 0.0)
	var mesher := TerrainChunkMesher.new()
	mesher.prepare_resources()
	# Query terrace construction directly; the fake water has no render mesh.
	var terraces := preload("res://scripts/terrain/field/CliffTerraces.gd")
	assert_eq(terraces.compute(plan.compute_region(4,4,8),0,0,8,0,null,FloodedCliff.new()).placements.size(),0)

func test_native_hill_columns_are_available_to_terrain_construction() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for suffix: String in ["2x2x4", "4x2x4", "4x4x4", "8x4x4"]:
		assert_not_null(catalog.descriptor(StringName("kaykit.terrace.%s" % suffix)),
			"The existing native hill %s must participate in cliff construction" % suffix)

func test_retained_native_library_supports_faces_and_both_corner_types() -> void:
	for shape: String in ["face", "outer", "inner"]:
		var plan := HeightfieldPlan.new(17, 64.0, 12, "mean", 4)
		plan.set_raw_height_override(func(cx: int, cz: int) -> float:
			if shape == "face": return 16.0 if cx <= 3 else 0.0
			if shape == "outer": return 16.0 if cx <= 3 and cz <= 3 else 0.0
			return 0.0 if cx > 3 and cz > 3 else 16.0)
		var mesher := TerrainChunkMesher.new()
		mesher.prepare_resources()
		var native := preload("res://scripts/terrain/field/CliffTerraces.gd")
		native.prepare()
		# Retained asset-library coverage; production now uses moss rock forms.
		var terraces := native.compute(plan.compute_region(4,4,8),0,0,8,0)
		assert_gt((terraces.get("placements", []) as Array).size(), 0,
			"Native terrace construction is missing on %s cliffs" % shape)
		var kinds: Dictionary = {}
		for placement: Dictionary in terraces.placements:
			kinds[placement.kind] = true
			if placement.kind == "rock": continue
			assert_almost_eq((placement.transform as Transform3D).basis.determinant(),1.0,.0001,
				"Native columns retain their authored proportions")
			assert_lte((placement.bounds as AABB).position.y,placement.base)
			assert_lte(placement.top,placement.wall_top-.39)
			assert_gte(placement.buried_samples,3)
			assert_gte(placement.exposed_samples,3)
		assert_true(kinds.has(shape),"The actual %s geometry owns an outcrop" % shape)
		assert_gt((terraces.collision_faces as PackedVector3Array).size(),0,
			"Visible native ledges must be physically supported")

func test_terrace_selection_agrees_across_chunk_queries() -> void:
	var terraces := preload("res://scripts/terrain/field/CliffTerraces.gd")
	terraces.prepare()
	var plan := HeightfieldPlan.new(17,64,12,"mean",4)
	plan.set_raw_height_override(func(cx: int, cz: int) -> float:
		return 16.0 if cx <= 3 and cz <= 3 else 0.0)
	var region := plan.compute_region(4,4,12)
	var full := terraces.compute(region,0,0,8,99)
	var split: Array[Dictionary] = []
	for owner: Vector2i in [Vector2i(0,0),Vector2i(0,4),Vector2i(4,0),Vector2i(4,4)]:
		split.append_array(terraces.compute(region,owner.x,owner.y,4,99).placements)
	assert_eq(split.size(),full.placements.size())
	for placement: Dictionary in full.placements:
		assert_true(split.has(placement),"Chunk projection retains exact geometry and owner %s" % placement.id)

func test_terraces_respect_the_complete_public_feature_footprint() -> void:
	var terraces := preload("res://scripts/terrain/field/CliffTerraces.gd")
	terraces.prepare()
	var plan := HeightfieldPlan.new(17,64,12,"mean",4)
	plan.set_raw_height_override(func(cx: int, _cz: int) -> float: return 16.0 if cx <= 3 else 0.0)
	var region := plan.compute_region(4,4,12)
	var clear := FeatureGroundShape.axis_rect(Rect2(Vector2(-1000,-1000),Vector2(2000,2000)))
	var ground := FeatureGroundField.new([], [clear],0.0)
	var features := FeatureContext.new(clear.bounds(),ground,EnvironmentInstancePayload.new())
	assert_gt(terraces.compute(region,0,0,8,99).placements.size(),0)
	assert_eq(terraces.compute(region,0,0,8,99,features).placements.size(),0,
		"Roads and settlement reservations reject the whole outcrop, including its native collision")

func test_retained_native_library_tops_hold_downward_physics_probes() -> void:
	var plan := HeightfieldPlan.new(17,64,12,"mean",4)
	plan.set_raw_height_override(func(cx: int, _cz: int) -> float: return 16.0 if cx <= 3 else 0.0)
	var region := plan.compute_region(4,4,8)
	var mesher := TerrainChunkMesher.new()
	mesher.prepare_resources()
	var native := preload("res://scripts/terrain/field/CliffTerraces.gd")
	native.prepare()
	var data := {"cliff_terraces":native.compute(region,0,0,8,0)}
	var node := native.build(data.cliff_terraces,0)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	collision.name="NativeTerraces"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(data.cliff_terraces.collision_faces)
	collision.shape=shape;body.add_child(collision);node.add_child(body)
	add_child_autofree(node)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var physics := node.get_world_3d().direct_space_state
	var count := 0
	for placement: Dictionary in data.cliff_terraces.placements:
		if placement.kind == "rock": continue
		var box: AABB = placement.bounds
		var checked := false
		for zi in range(1,8):
			for xi in range(1,8):
				if checked: continue
				var point := Vector3(lerpf(box.position.x,box.end.x,float(xi)/8),placement.top,
					lerpf(box.position.z,box.end.z,float(zi)/8))
				if TerrainSurfaceField.surface_y(region,point.x,point.z) > placement.base+.3: continue
				var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*.3,point-Vector3.UP*.5)
				var hit := physics.intersect_ray(query)
				if hit.is_empty(): continue # Rounded native perimeter is outside the flat top.
				assert_almost_eq((hit.position as Vector3).y,placement.top,.1)
				var hit_body := hit.collider as StaticBody3D
				assert_eq((hit_body.shape_owner_get_owner(hit_body.shape_find_owner(hit.shape)) as Node).name,
					&"NativeTerraces","The visible outcrop's own native collision holds the probe")
				checked = true
				count += 1
		assert_true(checked,"Every exposed native terrace offers a solid top")
	assert_gt(count,3)
