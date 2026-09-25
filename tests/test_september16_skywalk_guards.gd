extends GutTest

func test_accepted_skywalk_mouths_are_open_in_public_guards() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen = preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://docs/qa/2026-09-16-manual/05-town-rails/current-source.txt"), program)
	var fabric := spatial.compiled_fabric_cache()
	var spans := SettlementFabricAssembler.maze_skywalk_spans(fabric)
	var mouths := 0
	var conflicts := []
	for span: Dictionary in spans:
		var step: Vector3i = span.step
		for lane: Vector3i in SettlementFabricAssembler._skywalk_candidate_walk_lanes(span):
			for pair: Array in [[lane,step], [lane+step*(int(span.gap)+1),-step]]:
				if not fabric.surface_plan.has_cell(pair[0]): continue
				mouths += 1
				var center := (Vector3(pair[0])+Vector3(pair[1])*.5)*FabricRecipe.CELL_SIZE
				for guard: Dictionary in fabric.surface_plan.guard_segments:
					var midpoint := ((guard.a as Vector3)+(guard.b as Vector3))*.5
					# Guards have a deliberate floor lift. Compare the boundary in XZ
					# and its storey separately; exact 3D equality hid the real defect.
					if Vector2(midpoint.x,midpoint.z).distance_to(Vector2(center.x,center.z))<.001 and absf(midpoint.y-center.y)<.05:
						conflicts.append(guard.stable_key)
	assert_gt(mouths,0,"The photographed town has public skywalk connections")
	assert_eq(conflicts,[],"Accepted bridge mouths must not retain a terminal public railing")

func test_only_accepted_walk_lane_ends_open_and_collision_rebuilds() -> void:
	for direction: Vector3i in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
		var plan := PublicRealmSurfacePlan.new(&"bridge-control")
		var near := Vector3i(0,4,0)
		var far := near + direction*3
		assert_true(plan.add_claim(near,PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,&"near"))
		assert_true(plan.add_claim(far,PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,&"far"))
		assert_true(plan.seal())
		assert_eq(plan.guard_segments.size(),8)
		var before_faces: PackedVector3Array = plan.guard_mesh_payload.collision_faces
		var spans: Array[Dictionary] = [{"cell":near,"step":direction,"gap":2,"width":2,"walk_width":1,"cross":Vector3i(direction.z,0,direction.x)}]
		plan.finish_exterior_bridge_guards(spans)
		assert_eq(plan.guard_segments.size(),6,"Only the two accepted terminal boundaries open")
		assert_lt(plan.guard_mesh_payload.collision_faces.size(),before_faces.size(),"Collision follows the removed rail beams")
		var once := plan.guard_segments.duplicate(true)
		plan.finish_exterior_bridge_guards(spans)
		assert_eq(plan.guard_segments,once,"Reapplying the same topology is deterministic")
		plan.finish_exterior_bridge_guards([])
		assert_eq(plan.guard_segments.size(),8,"Withdrawing the bridge restores fall guards")
		assert_eq(plan.guard_mesh_payload.collision_faces,before_faces)
