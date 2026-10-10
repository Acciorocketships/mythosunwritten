extends SceneTree
func _initialize() -> void:
	var visual := load("res://terrain/environment/visuals/fantasy_village_structures/sfm_stall_butcher_001.tres") as EnvironmentVisual
	var pose := Transform3D(Basis.IDENTITY,Vector3(6.5,0,-2.25))
	var box := AABB(Vector3(5.25,2.8389,-.75),Vector3(.28,3,.28)).grow(-.001)
	var area := 0.0
	var triangles := 0
	for piece in visual.pieces:
		for surface in piece.mesh.get_surface_count():
			var arrays := piece.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in range(0,indices.size(),3):
				var poly: Array[Vector3] = []
				for j in 3: poly.append(pose*piece.local_transform*vertices[indices[i+j]])
				for axis in 3:
					for side in 2:
						var clipped: Array[Vector3] = []
						var plane := box.position[axis] if side==0 else box.end[axis]
						for k in poly.size():
							var a := poly[k]
							var b := poly[(k+1)%poly.size()]
							var da := (a[axis]-plane)*(1 if side==0 else -1)
							var db := (b[axis]-plane)*(1 if side==0 else -1)
							if da>=0: clipped.append(a)
							if (da>=0)!=(db>=0): clipped.append(a.lerp(b,da/(da-db)))
						poly=clipped
				if poly.size()>=3:
					triangles+=1
					for k in range(1,poly.size()-1): area+=(poly[k]-poly[0]).cross(poly[k+1]-poly[0]).length()*.5
	print("CANOPY_IN_POST triangles=",triangles," area=",area)
	quit()
