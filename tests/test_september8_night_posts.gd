extends GutTest

func test_free_stair_ends_have_posts_above_and_wider_than_the_rail() -> void:
	for quarter in 4:
		var rotate:=Basis(Vector3.UP,float(quarter)*PI*0.5)
		var payload:=WarrenTransitionSurfaceBuilder._empty_payload(&"finished-ends",[] as Array[Vector3i])
		WarrenTransitionSurfaceBuilder._append_side_guards(payload,Vector3.ZERO,rotate*Vector3(0,1.5,3),rotate*Vector3.RIGHT)
		var points:PackedVector3Array=payload.vertices
		for end in [Vector3.ZERO,Vector3(0,1.5,3)]:
			for side in [-1.0,1.0]:
				var foot:Vector3=end+Vector3.RIGHT*1.5*side
				var top:=-INF
				var width:=0.0
				for point:Vector3 in points:
					var p:Vector3=rotate.inverse()*point-foot
					if absf(p.z)>0.15 or absf(p.x)>0.15:continue
					top=maxf(top,p.y)
					if p.y>1.23:width=maxf(width,absf(p.x)*2)
				assert_gt(top,1.25,"End post must rise above the exposed beam cap")
				assert_gte(width,0.19,"Post head must be wider than the 0.14 m rail")

func test_every_guard_face_has_noncollapsed_texture_coordinates() -> void:
	var payload:=WarrenTransitionSurfaceBuilder._empty_payload(&"textured-guards",[] as Array[Vector3i])
	WarrenTransitionSurfaceBuilder._append_side_guards(payload,Vector3.ZERO,Vector3(0,1.5,3),Vector3.RIGHT)
	var uvs:PackedVector2Array=payload.uvs
	var collapsed:=0
	for i in range(0,uvs.size(),4):
		if absf((uvs[i+1]-uvs[i]).cross(uvs[i+2]-uvs[i]))<0.000001:collapsed+=1
	assert_eq(collapsed,0,"Side and end faces need real two-dimensional UVs")
