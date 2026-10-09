extends RefCounted
func run(review:Node)->void:
	review._views.append({"id":"right_fan_detail","position":Vector3(180,85,1110),"target":Vector3(120,40,1036),"fov":62.0})
	review._views.append({"id":"left_fan_detail","position":Vector3(150,100,1240),"target":Vector3(50,53,1181),"fov":62.0})
	review._collect_inputs()
	await review._capture_all(1)
	await preload("res://tests/harness/october8_apply_surface.gd").new().sample_path(review)
	await preload("res://tests/harness/october8_visible_rivers.gd").new().run(review)
	await preload("res://tests/harness/october8_join_probe.gd").new().run(review)
	review._views.pop_back();review._views.pop_back()
