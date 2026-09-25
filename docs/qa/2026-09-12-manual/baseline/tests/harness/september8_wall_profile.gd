extends SceneTree

func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for asset: StringName in [&"sfv.fabric.wall.rock.door.closed.005",&"sfv.fabric.wall.wood.window.010.mirror_x",&"sfv.fabric.wall.wood.plain.003",&"sfv.fabric.wall.wood.door.closed.001"]:
		var descriptor := catalog.descriptor(asset)
		var visual: EnvironmentVisual = load(descriptor.visual_path)
		var planes := {}
		for piece: EnvironmentVisualPiece in visual.pieces:
			var faces := piece.local_transform*piece.mesh.get_faces()
			for offset in range(0,faces.size(),3):
				var a := faces[offset]
				var b := faces[offset+1]
				var c := faces[offset+2]
				var cross := (b-a).cross(c-a)
				if absf(cross.normalized().z)<0.9999: continue
				var key := roundi(a.z*10000)
				planes[key]=float(planes.get(key,0.0))+cross.length()*0.5
		var keys := planes.keys()
		keys.sort_custom(func(a,b):return planes[a]>planes[b])
		print(asset," bounds=",descriptor.measured_aabb)
		for key in keys.slice(0,8): print("PLANE ",key/10000.0," area=",planes[key])
	quit()
