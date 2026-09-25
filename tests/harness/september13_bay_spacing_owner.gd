extends SceneTree
func _init() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1280,800)
	var camera := Camera3D.new()
	root.add_child(camera)
	var second:="--p31" in OS.get_cmdline_user_args()
	camera.fov = 50 if second else 75
	var feet := Vector3(-178.3,8,-904.7)
	var crosshair := Vector3(-188.9,11.4,-919.4)
	if second:
		feet=Vector3(956.3,16,-2065.3)
		crosshair=Vector3(956.1,17.2,-2064.9)
	var pivot := feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT
	var backward := (pivot-crosshair).normalized()
	camera.position = ReviewCam.solve_cam(feet,crosshair,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,
		CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
	if second:
		pivot=feet+Vector3.UP
		camera.position=ReviewCam.solve_cam(feet,crosshair,26,16,1)
	camera.look_at(pivot)
	var path:="res://docs/qa/2026-09-13-manual/11-roof-joins/"
	var data: Dictionary = FileAccess.open(path+("P31-before-payload.bin" if second else "before-payload.bin"),FileAccess.READ).get_var()
	var catalog := EnvironmentCatalog.load_default()
	var result := []
	var pixels: Array[Vector2]=[Vector2(748,201),Vector2(655,198),Vector2(319,274)]
	if second: pixels=[Vector2(680,180),Vector2(760,180),Vector2(650,140),Vector2(550,160),Vector2(680,125)]
	for pixel: Vector2 in pixels:
		var start := camera.project_ray_origin(pixel)
		var direction := camera.project_ray_normal(pixel)
		var hits := []
		for asset: StringName in data.batches:
			var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
			var batch: Dictionary = data.batches[asset]
			for index in batch.transforms.size():
				var transform: Transform3D = data.transform*batch.transforms[index]
				if (transform*catalog.descriptor(asset).measured_aabb).intersects_ray(start,direction) == null: continue
				var nearest := INF
				for piece: EnvironmentVisualPiece in visual.pieces:
					var faces := EnvironmentBakeGeometry.triangle_faces(piece.mesh,transform*piece.local_transform)
					for i in range(0,faces.size(),3):
						var hit = Geometry3D.ray_intersects_triangle(start,direction,faces[i],faces[i+1],faces[i+2])
						if hit != null: nearest = minf(nearest,start.distance_to(hit))
				if nearest < INF: hits.append({"id":batch.ids[index],"asset":asset,"transform":str(transform),"distance":nearest})
		hits.sort_custom(func(a,b): return a.distance<b.distance)
		result.append({"pixel":str(pixel),"hits":hits})
	FileAccess.open("res://docs/qa/2026-09-13-manual/12-bay-spacing/original-owners.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	quit()
