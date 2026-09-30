extends GutTest

## A 12 m cleft: the one low point column x = 4 (the arch centres 8 i + 4)
## between plateaus whose flat points two steps away bear the abutments.
func _cleft_region() -> HeightfieldRegion:
	var plan := HeightfieldPlan.new(17,64,12,"mean",4)
	plan.set_raw_height_override(func(cx: int,_cz: int) -> float: return 0.0 if cx==4 else 12.0)
	return plan.compute_region(8,8,24)

func test_narrow_clefts_can_carry_real_overhead_rock() -> void:
	var region := _cleft_region()
	var mesher := TerrainChunkMesher.new()
	mesher.prepare_resources()
	var count := 0
	for seed_value in 4:
		mesher.set_seed(seed_value)
		var data := mesher.compute_chunk(Vector2i.ZERO,region)
		count += (data.get("natural_arches",{}).get("placements",[]) as Array).size()
	assert_gt(count,0,"A heightmap cannot supply the missing overhead rock volume")

func test_arch_tops_undersides_and_complete_bearings_are_physical() -> void:
	var region := _cleft_region()
	var mesher := TerrainChunkMesher.new()
	mesher.prepare_resources()
	mesher.set_seed(1)
	var data := mesher.compute_chunk(Vector2i.ZERO,region)
	var stage := mesher.commit_chunk(data)
	add_child_autofree(stage)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var physics := stage.get_world_3d().direct_space_state
	var count := 0
	for record: Dictionary in data.natural_arches.placements:
		var p := Vector3(record.center.x,record.top,record.center.y)
		var top := physics.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*12,p-Vector3.UP*3))
		assert_false(top.is_empty())
		assert_almost_eq((top.position as Vector3).y,record.top+8,.01)
		var under := physics.intersect_ray(PhysicsRayQueryParameters3D.create(p-Vector3.UP*5,p+Vector3.UP*6))
		assert_false(under.is_empty())
		assert_almost_eq((under.position as Vector3).y,record.top+4.2,.01)
		var from := Vector3(p.x,record.low+1,p.z-10)
		assert_true(physics.intersect_ray(PhysicsRayQueryParameters3D.create(from,from+Vector3(0,0,20))).is_empty(),"The low passage remains open beneath the arch")
		for sign_value: float in [-1,1]:
			var end := p+Vector3(record.axis.x,0,record.axis.y)*sign_value*18
			assert_almost_eq(TerrainSurfaceField.surface_y(region,end.x,end.z),record.top,.15)
		count+=1
	assert_gt(count,0)
	assert_eq(data.structure_clearance.size(),count,"Vegetation receives the complete overhead footprint")

func test_arch_mesh_is_closed_and_stays_inside_its_owned_footprint_in_every_axis() -> void:
	var arches:=preload("res://scripts/terrain/field/NaturalArches.gd")
	for axis:Vector2i in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i(1,1),Vector2i(1,-1)]:
		var along:=Vector2(axis).normalized()
		var side:=Vector2(-along.y,along.x)
		var span:=18.0 if axis.x==0 or axis.y==0 else 26.0
		var center:=Vector2(-720,48)
		var size:=along.abs()*span*2+side.abs()*3.5*2.1
		var bounds:=Rect2(center-size*.5,size).grow(.001)
		var record:={"axis":axis,"center":center,"low":8.0,"top":20.0,
			"top_a":20.0,"top_b":24.0,"half_span":span}
		var vertices:=PackedVector3Array()
		var normals:=PackedVector3Array()
		var uvs:=PackedVector2Array()
		var colors:=PackedColorArray()
		arches._mesh(record,17,Vector2.ZERO,vertices,normals,uvs,colors)
		var edges:Dictionary={}
		var bad_faces:=0
		var outside:=0
		for i in range(0,vertices.size(),3):
			var normal:=(vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i])
			bad_faces+=int(normal.length_squared()<.000001 or normal.normalized().dot(normals[i])<.999)
			for k in 3:
				outside+=int(not bounds.has_point(Vector2(vertices[i+k].x,vertices[i+k].z)))
				var a:=str(vertices[i+k].snapped(Vector3.ONE*.0001))
				var b:=str(vertices[i+(k+1)%3].snapped(Vector3.ONE*.0001))
				var key:=a+"/"+b if a<b else b+"/"+a
				var count:Vector2i=edges.get(key,Vector2i.ZERO)
				edges[key]=count+Vector2i(1,1 if a<b else -1)
		var open_edges:=0
		for count:Vector2i in edges.values(): open_edges+=int(count!=Vector2i(2,0))
		assert_eq(bad_faces,0,str(axis)+" nondegenerate outward faces")
		assert_eq(outside,0,str(axis)+" complete reserved envelope")
		assert_eq(open_edges,0,str(axis)+" each edge joins exactly two opposite faces")
