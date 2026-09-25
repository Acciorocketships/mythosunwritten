extends GutTest
var fabric: SettlementFabricPlan
var skin: Dictionary
var payload: EnvironmentInstancePayload
func before_all() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	fabric = frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/07-platform/current-source.txt"),program).compiled_fabric_cache()
	skin = SettlementFabricAssembler.maze_ground_skin_transaction(fabric)
	payload = SettlementFabricAssembler.payload(fabric)
	payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
func _mesh(id: StringName) -> Dictionary:
	for mesh: Dictionary in payload.surface_meshes:
		if mesh.stable_id == id: return mesh
	return {}
func _hit(mesh: Dictionary, point: Vector3) -> bool:
	if mesh.is_empty(): return false
	var vertices: PackedVector3Array = mesh.vertices
	for index in range(0,mesh.indices.size(),3):
		if Geometry3D.segment_intersects_triangle(point+Vector3.UP,point-Vector3.UP,vertices[mesh.indices[index]],vertices[mesh.indices[index+1]],vertices[mesh.indices[index+2]]) != null: return true
	return false
func test_shared_turf_edges_have_grass_instead_of_internal_timber_borders() -> void:
	var border := _mesh(&"maze-lawn-border")
	var turf := _mesh(&"maze-ground-turf")
	var shared := 0
	for cell: Vector3i in skin.suspended_plaza:
		for direction: Vector3i in SettlementFabricAssembler.FACE_DIRECTIONS:
			if skin.suspended_plaza.has(cell+direction) or not skin.capped_ground.has(cell+direction): continue
			shared += 1
			var point := Vector3(cell)*FabricRecipe.CELL_SIZE+Vector3(direction)*.70
			point.y = float(cell.y+1)*FabricRecipe.CELL_SIZE+SettlementFabricAssembler.GREEN_CAP_LIFT
			assert_false(_hit(border,point),"Shared turf boundary must not carry a visible border: %s %s"%[cell,direction])
			assert_true(_hit(turf,point),"Grass must close the former interior frame strip: %s %s"%[cell,direction])
	assert_gt(shared,4,"Exercise both photographed L-shaped internal boundaries")
func test_exterior_suspended_edges_keep_their_complete_timber_frame() -> void:
	var border := _mesh(&"maze-lawn-border")
	var exterior := 0
	for cell: Vector3i in skin.suspended_plaza:
		for direction: Vector3i in SettlementFabricAssembler.FACE_DIRECTIONS:
			if skin.capped_ground.has(cell+direction): continue
			exterior += 1
			var point := Vector3(cell)*FabricRecipe.CELL_SIZE+Vector3(direction)*.65
			point.y = float(cell.y+1)*FabricRecipe.CELL_SIZE+SettlementFabricAssembler.GREEN_CAP_LIFT
			assert_true(_hit(border,point),"Exterior lawn bed keeps its timber frame: %s %s"%[cell,direction])
	assert_gt(exterior,4)

func test_only_continuous_same_level_turf_suppresses_borders_in_all_directions() -> void:
	var cell := Vector3i(2,3,-1)
	for direction: Vector3i in SettlementFabricAssembler.FACE_DIRECTIONS:
		var suspended := {cell:true}
		var point := Vector3(cell)*FabricRecipe.CELL_SIZE+Vector3(direction)*.65
		point.y = float(cell.y+1)*FabricRecipe.CELL_SIZE+SettlementFabricAssembler.GREEN_CAP_LIFT
		for height in [-1,0,1]:
			var adjacent := {cell+direction+Vector3i.UP*height:true}
			var mesh := SettlementFabricAssembler.suspended_lawn_border(suspended,adjacent)
			assert_eq(_hit(mesh,point),height != 0,"Only same-level joined grass removes the %s border; height=%d"%[direction,height])
