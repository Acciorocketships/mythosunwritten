extends GutTest

func test_photographed_towns_do_not_fence_retained_walls() -> void:
	var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen:=preload("res://tests/fixtures/frozen_maze_source.gd")
	for fixture in ["september7-manual-source.txt","september8-night-center-source.txt"]:
		var fabric:=frozen.spatial(frozen.read("res://tests/fixtures/"+fixture),program).compiled_fabric_cache()
		var intersections:Array[String]=[]
		for segment:Dictionary in fabric.surface_plan.guard_segments:
			var coords:=String(segment.stable_key).split(":")
			var neighbor:=Vector3i(int(coords[0])+int(coords[3]),int(coords[1]),int(coords[2])+int(coords[4]))
			if fabric.retained_terrace_cells.has(neighbor):intersections.append(segment.stable_key)
		assert_eq(intersections.size(),0,fixture+": rails crossing retained walls "+str(intersections))

func test_wall_socket_preserves_exposed_guard_and_collision_in_all_directions() -> void:
	for quarter in 4:
		var rotate:=Basis(Vector3.UP,float(quarter)*PI*0.5)
		# One metre of full-height wall, then exposed stair; a low parapet
		# on the opposite side must keep its upper rail.
		var walls:Array[AABB]=[
			Transform3D(rotate,Vector3.ZERO)*AABB(Vector3(1.5,0,0),Vector3(1.5,4,1.5)),
			Transform3D(rotate,Vector3.ZERO)*AABB(Vector3(-3,0,0),Vector3(1.5,0.4,3))]
		var payload:=WarrenTransitionSurfaceBuilder._empty_payload(&"wall-socket",[] as Array[Vector3i])
		WarrenTransitionSurfaceBuilder._append_side_guards(payload,Vector3.ZERO,rotate*Vector3(0,1.5,3),rotate*Vector3.RIGHT,true,walls)
		var exposed:=0
		var blocked:=0
		var opposite_top:=0
		var points:PackedVector3Array=payload.vertices
		for index in range(0,points.size(),4):
			var center:Vector3=rotate.inverse()*((points[index]+points[index+1]+points[index+2]+points[index+3])*0.25)
			if center.x>1.4 and center.z>0.01 and center.z<1.49 and center.y>0.01:blocked+=1
			if center.x>1.4 and center.z>1.6:exposed+=1
			if center.x< -1.4 and center.y>center.z*0.5+0.9:opposite_top+=1
		assert_eq(blocked,0,"No timber remains across the wall face")
		assert_gt(exposed,0,"Exposed half of the stair retains its barrier")
		assert_gt(opposite_top,0,"The short parapet retains the upper guard")
		assert_eq(payload.collision_faces.size(),points.size()/4*6,"Every retained guard face has collision")

func test_photo14_lower_rail_respects_full_hanging_stone_course() -> void:
	var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen:=preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial:=frozen.spatial(frozen.read("res://tests/fixtures/september8-night-center-source.txt"),program)
	var fabric:=spatial.compiled_fabric_cache()
	var ends:=WarrenTransitionSurfaceBuilder._span_endpoints(spatial.source_volume.transitions[8])
	var start:Vector3=ends.start
	var run:Vector3=(ends.end as Vector3)-start
	var violations:=0
	for mesh:Dictionary in fabric.surface_plan.mesh_payloads:
		if String(mesh.get("stable_id",""))!="volume.transition.08.mesh":continue
		var points:PackedVector3Array=mesh.vertices
		for i in range(0,points.size(),4):
			var p:Vector3=(points[i]+points[i+1]+points[i+2]+points[i+3])*0.25
			var t:=Vector2(p.x-start.x,p.z-start.z).dot(Vector2(run.x,run.z))/Vector2(run.x,run.z).length_squared()
			var floor_y:=start.y+run.y*t
			if p.y>floor_y+0.4 and p.x>2.0 and p.x<4.0 and p.y>3.0 and p.y<4.49 and p.z>2.17 and p.z<2.33:violations+=1
	assert_eq(violations,0,"The photographed lower rail must not cross the hanging stone course below its owning mass cell")
