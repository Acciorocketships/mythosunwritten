extends SceneTree

# Exploratory rays using rounded world transforms from the placement report.
# Misses include intentional door openings; this is not an acceptance census.
# test_september9_door_return_cap.gd checks the exact local cut triangles.

func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var rows := [
		[&"sfv.fabric.wall.wood.window.013.mirror_x.doorreturn.back1070858.square",Transform3D(Basis.from_scale(Vector3.ONE*2),Vector3(486,12.08,-2065.553))],
		[&"sfv.fabric.wall.wood.door.closed.001",Transform3D(Basis(Vector3(0,0,2),Vector3(0,2,0),Vector3(-2,0,0)),Vector3(484.0166,12.08,-2068))],
	]
	var faces := PackedVector3Array()
	for row: Array in rows:
		var visual: EnvironmentVisual=load(catalog.descriptor(row[0]).visual_path)
		for piece: EnvironmentVisualPiece in visual.pieces:
			for surface in piece.mesh.get_surface_count():
				var a := piece.mesh.surface_get_arrays(surface)
				var v: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
				var ids: PackedInt32Array=a[Mesh.ARRAY_INDEX]
				for i in (v.size() if ids.is_empty() else ids.size()): faces.append(row[1]*piece.local_transform*v[i if ids.is_empty() else ids[i]])
	var samples: Array=[]
	for y in [12.5,13.0,13.5,14.0,14.5,15.0,15.5,16.0,16.5,17.0,17.5]:
		for x in [483.5,484.0,484.5,485.0,485.14,485.3,485.5,486.0]:
			var a:=Vector3(x,y,-2064.0)
			var b:=Vector3(x,y,-2066.7)
			var distance:=INF
			for i in range(0,faces.size(),3):
				var hit: Variant=Geometry3D.segment_intersects_triangle(a,b,faces[i],faces[i+1],faces[i+2])
				if hit!=null:distance=minf(distance,a.distance_to(hit))
			samples.append({"x":x,"y":y,"hit":is_finite(distance),"distance":distance if is_finite(distance) else -1})
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(samples,"  "))
	print("WALL_SEAM_PROBE samples=",samples.size())
	quit()
