extends GutTest
const Assembler = preload("res://scripts/terrain/features/villages/fabric/SettlementFabricAssembler.gd")
const Frozen = preload("res://tests/fixtures/frozen_maze_source.gd")

func test_native_knees_reach_the_wall_and_bottom_plate_in_four_orientations() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var descriptor := catalog.descriptor(Assembler.TIMBER_SUPPORT)
	assert_true(descriptor.measured_aabb.is_equal_approx(Assembler.FACADE_JETTY_BRACE_BOUNDS))
	var visual: EnvironmentVisual = load(descriptor.visual_path)
	for direction in 4:
		for kind in [Assembler.FacadeOutcrop.BAY,Assembler.FacadeOutcrop.BUMP]:
			var key := Vector4i(0,3,0,direction)
			var outward := Vector3(Assembler.STONE_FACE_DIRECTIONS[direction])
			var cross := Vector3(-outward.z,0,outward.x)
			var boundary := outward*0.75+cross*0.75
			var braces := Assembler._maze_facade_jetty_braces(key,kind)
			assert_eq(braces.size(),2)
			for pose: Transform3D in braces:
				var faces := PackedVector3Array()
				for piece: EnvironmentVisualPiece in visual.pieces:
					faces.append_array(pose*piece.local_transform*piece.mesh.get_faces())
				var bounds := AABB(faces[0],Vector3.ZERO)
				var inner := INF
				for point: Vector3 in faces:
					bounds = bounds.expand(point)
					inner = minf(inner,(point-boundary).dot(outward))
				assert_lt(inner,0.0,"Actual timber enters the supporting wall")
				assert_gt(bounds.end.y,3.0-Assembler.PLANK_TERRACE_THICKNESS,"Actual timber enters the floor plate")
				assert_gt(bounds.position.y,1.5,"All support stays inside the reserved lower band")
			# Put a walked surface directly below a knee. Admission must inspect
			# the deeper visible timber, not only the old short corbel envelope.
			var walked := {Vector3i(outward)+Vector3i(0,1,0):true}
			assert_false(Assembler._maze_facade_outcrop_bearers_clear(key,kind,walked))

func test_photographed_bays_emit_two_visible_supports_each() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := Frozen.spatial(Frozen.read("res://tests/fixtures/september9-offset-source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	var payload := SettlementFabricAssembler.terrace_retaining_payload(fabric)
	var batch: Dictionary = payload.batches.get(Assembler.TIMBER_SUPPORT,{})
	for prefix in ["maze-outcrop/-1/3/11/3/brace/","maze-outcrop/-3/3/11/3/brace/"]:
		var count := 0
		for id in batch.get("ids",[]): count += int(String(id).begins_with(prefix))
		assert_eq(count,2,"The photographed deep bays have visible wall-to-floor supports")
