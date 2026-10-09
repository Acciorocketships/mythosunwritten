extends "res://tests/harness/october8_apply_surface.gd"
func run(review:Node)->void:
	# Camera rays place the two circled fans in (0,5) and (0,6).
	review._views.append({"id":"right_fan_detail","position":Vector3(180,85,1110),"target":Vector3(120,40,1036),"fov":62.0})
	review._views.append({"id":"left_fan_detail","position":Vector3(150,100,1240),"target":Vector3(50,53,1181),"fov":62.0})
	review._collect_inputs()
	await super.run(review)
	review._views.pop_back()
	review._views.pop_back()
