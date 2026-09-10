extends GutTest

var _catalog: EnvironmentCatalog
var _plan: SettlementFabricPlan

func before_all() -> void:
	_catalog = EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(_catalog)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september7-manual-source.txt"),program)
	_plan = spatial.compiled_fabric_cache()

func test_private_floor_owns_the_photographed_retained_cap() -> void:
	var transaction := SettlementFabricAssembler.maze_ground_skin_transaction(_plan)
	assert_false(transaction.shell.exposed.has(Vector4i(-4,3,-5,4)),
		"the bridge-end room floor owns the horizontal face over this retained cell")

func test_retaining_wall_top_cannot_compete_with_the_photographed_floor() -> void:
	var floor_bounds := AABB()
	for placement: Dictionary in _plan.expanded_placements():
		if String(placement.stable_id).ends_with("maze.bridge.00.end.1.lower.part00.room00/floor.0"):
			floor_bounds = placement.bounds
	assert_true(floor_bounds.has_volume(),"exercise the photographed floor")
	var floor_rect := PackedVector2Array([
		Vector2(floor_bounds.position.x,floor_bounds.position.z),Vector2(floor_bounds.end.x,floor_bounds.position.z),
		Vector2(floor_bounds.end.x,floor_bounds.end.z),Vector2(floor_bounds.position.x,floor_bounds.end.z)])
	var payload := SettlementFabricAssembler.terrace_retaining_payload(_plan)
	var overlap := 0.0
	for asset: StringName in payload.batches:
		var batch: Dictionary = payload.batches[asset]
		var visual: EnvironmentVisual = load(_catalog.descriptor(asset).visual_path)
		for index in batch.transforms.size():
			if not String(batch.ids[index]).begins_with("maze-stone/-4/3/-5/"): continue
			for piece: EnvironmentVisualPiece in visual.pieces:
				var pose: Transform3D = batch.transforms[index]*piece.local_transform
				overlap += _coplanar_overlap(pose*piece.mesh.get_faces(),floor_rect,floor_bounds.end.y)
	for mesh: Dictionary in payload.surface_meshes:
		if not String(mesh.stable_id).begins_with("maze-stone/-4/3/-5/"): continue
		var faces := PackedVector3Array()
		for index: int in mesh.indices: faces.append(mesh.vertices[index])
		overlap += _coplanar_overlap(faces,floor_rect,floor_bounds.end.y)
	assert_lt(overlap,0.00001,"neither baked nor regenerated stone triangles may share the floor plane")


func _coplanar_overlap(faces: PackedVector3Array, floor_rect: PackedVector2Array, height: float) -> float:
	var area := 0.0
	for offset in range(0,faces.size(),3):
		var a := faces[offset]
		var b := faces[offset+1]
		var c := faces[offset+2]
		if maxf(absf(a.y-height),maxf(absf(b.y-height),absf(c.y-height)))>0.001: continue
		for polygon: PackedVector2Array in Geometry2D.intersect_polygons(PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)]),floor_rect):
			area += _area(polygon)
	return area

func test_partially_covered_cap_retains_its_exposed_surface_and_collision() -> void:
	var asset := SettlementFabricAssembler.MAZE_STONE_MODULE
	var pose := SettlementFabricAssembler._maze_stone_transform(Vector3i.ZERO,Vector3i.UP,Vector3i.ZERO,true)
	var box: AABB = pose*_plan.asset_wall_interfaces[asset].visual_bounds
	var floor_box := AABB(Vector3(box.position.x,box.end.y-0.1,box.position.z),
		Vector3(box.size.x*0.5,0.1,box.size.z))
	var payload := EnvironmentInstancePayload.new()
	SettlementFabricAssembler._append_floor_owned_masonry(payload,asset,pose,Color.WHITE,&"partial-cap",
		[floor_box],_plan.asset_wall_interfaces,true)
	assert_gt(payload.surface_meshes.size(),0,"the exposed half must remain")
	for mesh: Dictionary in payload.surface_meshes:
		assert_false(mesh.visual_only)
		assert_gt(mesh.collision_faces.size(),0,"the exposed stone still carries a body")
		for vertex: Vector3 in mesh.vertices:
			assert_gte(vertex.x,floor_box.end.x-0.00001,"only the uncovered half keeps stone triangles")


func _area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for i in polygon.size(): area += polygon[i].cross(polygon[(i+1)%polygon.size()])
	return absf(area)*0.5
