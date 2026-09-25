extends GutTest

const SOURCE := "res://docs/qa/2026-09-13-manual/04-path/source.txt"
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")

func test_photographed_stone_ramp_has_no_native_masonry_in_its_walking_aperture() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var spatial := FROZEN.spatial(FROZEN.read(SOURCE),program)
	var plan := spatial.compiled_fabric_cache()
	var feet := Vector3(-217.9,20.4,-945.9)
	var town := Transform3D(Basis.from_scale(Vector3(-2,2,-2)),Vector3(-214.5,8.08,-944.5))
	var inverse := town.affine_inverse()
	# The second photographed ramp rises toward +X through the retained course.
	var invaded := []
	for x: float in [-212.5,-211,-209.5,-208]:
		var local := inverse*Vector3(x,20.08+(x+219)*.25+.1,feet.z)
		var cell := Vector3i(roundi(local.x/FabricRecipe.CELL_SIZE),floori(local.y/FabricRecipe.CELL_SIZE),roundi(local.z/FabricRecipe.CELL_SIZE))
		if spatial.grid.use_at(cell) != WarrenSpatialGrid.Use.PUBLIC_AIR: invaded.append(cell)
	assert_true(invaded.is_empty(),"Retained masonry cannot occupy the real ramp air: %s"%str(invaded))
	var payload := SettlementFabricAssembler.payload(plan)
	payload.append_from(SettlementFabricAssembler.structural_support_payload(plan))
	payload.append_from(SettlementFabricAssembler.production_surface_bundle(plan.surface_plan,
		SettlementFabricAssembler.maze_module_footprints(plan),
		SettlementFabricAssembler.maze_skin_panel_boxes_for(plan),plan.planned_plaza_cells))
	var cache := EnvironmentRenderCache.new(catalog)
	cache.prepare(payload.asset_ids())
	var stage := Node3D.new()
	add_child_autofree(stage)
	stage.transform = town
	EnvironmentCollisionBuilder.commit(stage,payload,cache,&"NativeTown")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var capsule := CapsuleShape3D.new()
	capsule.radius = .39746094
	capsule.height = 2.244
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.margin = .02
	var blocked := []
	for offset: float in [-1.5,-.75,0,.75,1.5]:
		for i in 25:
			var x := -212.8+float(i)*.24
			var y := 20.08+(x+219)*.25
			query.transform = Transform3D(Basis.IDENTITY,Vector3(x,y+capsule.height*.5+.06,feet.z+offset))
			if not stage.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): blocked.append(query.transform.origin)
	assert_true(blocked.is_empty(),"Actual native stone collision must clear the photographed ramp at five lateral lines: %s"%str(blocked))

