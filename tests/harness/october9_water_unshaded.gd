extends RefCounted
func run(review: Node) -> void:
	var viewport: Viewport = review._camera.get_viewport()
	var old := viewport.debug_draw
	viewport.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	var at := Vector3(318.5781, 59.67733, 1228.326)
	review._views.append({"id":"water_unshaded","position":at+Vector3(45,45,45),"target":at,"fov":50.0})
	await review._capture_all(4)
	review._views.pop_back()
	viewport.debug_draw = old
	print("WATER_UNSHADED_DONE")
