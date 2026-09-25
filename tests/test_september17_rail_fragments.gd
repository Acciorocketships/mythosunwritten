extends GutTest
const BUILDER = preload("res://scripts/terrain/features/villages/fabric/WarrenTransitionSurfaceBuilder.gd")

func test_clipped_post_caps_cannot_float_above_a_wall_without_any_rail() -> void:
	for quarter in 4:
		var rotate := Basis(Vector3.UP,quarter*PI*.5)
		var payload := BUILDER._empty_payload(&"clipped_guard",[] as Array[Vector3i])
		var boxes: Array[AABB] = [AABB(Vector3(-8,-1,-8),Vector3(16,2.2,16))]
		BUILDER._append_side_guards(payload,Vector3.ZERO,rotate*Vector3(3,0,0),rotate*Vector3.BACK,true,boxes)
		assert_eq(payload.vertices.size(),0,"Covered rails cannot leave isolated endpoint caps")
		assert_eq(payload.collision_faces.size(),0,"Visual and physical orphan removal must agree")

func test_exposed_guard_keeps_its_full_posts_and_two_rails() -> void:
	var payload := BUILDER._empty_payload(&"exposed_guard",[] as Array[Vector3i])
	BUILDER._append_side_guards(payload,Vector3.ZERO,Vector3(3,0,0),Vector3.BACK)
	assert_eq(payload.vertices.size(),10*24,"Two rails and three supporting posts per side remain")
	assert_eq(payload.collision_faces.size(),10*36)

func test_partial_wall_retains_posts_connected_to_the_exposed_upper_rail() -> void:
	var payload := BUILDER._empty_payload(&"parapet_guard",[] as Array[Vector3i])
	var boxes: Array[AABB] = [AABB(Vector3(-8,-1,-8),Vector3(16,1.9,16))]
	BUILDER._append_side_guards(payload,Vector3.ZERO,Vector3(3,0,0),Vector3.BACK,true,boxes)
	assert_eq(payload.vertices.size(),8*24,"The upper rail and its three bearing posts survive on each side")
	assert_eq(payload.collision_faces.size(),8*36)

func test_photographed_p15_has_no_isolated_post_cap_above_the_lawn() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var fabric := frozen.spatial(frozen.read("res://docs/qa/2026-09-16-manual/05-town-rails/current-source.txt"),program).compiled_fabric_cache()
	var payload := SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan,SettlementFabricAssembler.maze_module_footprints(fabric),SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),fabric.planned_plaza_cells)
	var found := false
	var pieces := 0
	var marker := AABB(Vector3(2.10,10.19,5.10),Vector3(.3,.2,.3))
	for mesh: Dictionary in payload.surface_meshes:
		if String(mesh.stable_id) != "public-transition/volume.transition.10.mesh": continue
		found = true
		for point: Vector3 in mesh.vertices:
			if marker.has_point(point): pieces += 1
	assert_true(found,"Exercise the exact native transition identified by the P15 image ray")
	assert_eq(pieces,0,"The photographed cap has no rail connection and must disappear")
