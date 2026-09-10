extends GutTest
const Builder = preload("res://scripts/terrain/features/villages/fabric/WarrenTransitionSurfaceBuilder.gd")

func _hits(faces: PackedVector3Array, a: Vector3, b: Vector3) -> int:
	var hits := 0
	for i in range(0,faces.size(),3):
		if Geometry3D.segment_intersects_triangle(a,b,faces[i],faces[i+1],faces[i+2]) != null:
			hits += 1
	return hits

func test_gate_rails_enter_actual_native_landing_posts_in_four_orientations() -> void:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var native := cache.visual(SettlementFabricAssembler.PLANK_RAILING)
	for quarter in 4:
		var rotation := Basis(Vector3.UP,quarter*PI*0.5)
		var start := rotation*Vector3(0,1.5,0)
		var end := rotation*Vector3(3,0,0)
		var lateral := rotation*Vector3.BACK
		var geometry := {"inner_centre":start,"stair_end":end,"outer_centre":rotation*Vector3(4.5,0,0)}
		var payload := Builder.build_gate_approach(&"gate",geometry)
		var previous := Builder._empty_payload(&"old-attachment",[] as Array[Vector3i])
		Builder._append_side_guards(previous,start,end,lateral,false)
		for side: float in [-1.0,1.0]:
			var pose := Transform3D(rotation,start+lateral*1.5*side+rotation*Vector3(-0.75,0.025,0))
			var native_faces := PackedVector3Array()
			for piece: EnvironmentVisualPiece in native.pieces:
				native_faces.append_array(pose*piece.local_transform*piece.mesh.get_faces())
			for fraction: float in [0.52,1.0]:
				var socket := start+lateral*1.5*side+rotation*Vector3(-Builder.LANDING_POST_INSET,Builder.LANDING_RAIL_HEIGHT*fraction,0)
				socket += rotation*Vector3(0.02,0,0) # Cross inside the rail, not on its end-cap plane.
				var crosswise := rotation*Vector3(0,0,0.2)
				assert_gte(_hits(native_faces,socket-crosswise,socket+crosswise),2,
					"The rail socket must pass through actual native post triangles")
				assert_gte(_hits(payload.collision_faces,socket-crosswise,socket+crosswise),2,
					"The generated rail's collision reaches that same timber socket")
				assert_eq(_hits(previous.collision_faces,socket-crosswise,socket+crosswise),0,
					"The previous constant-height rails leave these actual post sockets empty")
				var detached := start+lateral*1.5*side+Vector3.UP*Builder.GUARD_HEIGHT
				assert_eq(_hits(native_faces,detached-crosswise,detached+crosswise),0,
					"The old full-height attachment lies above the native post")

func test_attachment_keeps_the_reserved_treads_and_lower_landing() -> void:
	var start := Vector3(0,1.5,0)
	var end := Vector3(3,0,0)
	var outer := Vector3(4.5,0,0)
	var full := Builder.build_gate_approach(&"gate",{"inner_centre":start,"stair_end":end,"outer_centre":outer})
	var floors := Builder._empty_payload(&"floors",[] as Array[Vector3i])
	Builder._append_stairs(floors,start,end,Vector3.RIGHT,Vector3.BACK)
	Builder._append_ramp(floors,end,outer,Vector3.BACK)
	# All independent floor triangles survive verbatim in the finished payload.
	var actual := {}
	var faces: PackedVector3Array = full.collision_faces
	for i in range(0,faces.size(),3): actual[str([faces[i],faces[i+1],faces[i+2]])] = true
	faces = floors.collision_faces
	for i in range(0,faces.size(),3):
		assert_true(actual.has(str([faces[i],faces[i+1],faces[i+2]])))
