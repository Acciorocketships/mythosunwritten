extends RefCounted
func run(review:Node)->void:
	for view:Dictionary in review._views:
		print("LOCAL_ORIGINAL_CAMERA ",view)
		view.position.y+=70
		view.target.y+=20
	review._views.append({"id":"local_battle","position":Vector3(-370,180,1060),"target":Vector3(-200,65,900),"fov":62.0})
	review._collect_inputs()
	await review._capture_all(1)
	print("LOCAL_WORLD_CAPTURE done")
