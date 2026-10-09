extends RefCounted
func run(review: Node) -> void:
	var director: AtmosphereDirector = review.find_child("AtmosphereDirector",true,false)
	director.camera = review._camera
	director.set_process(false)
	review._plain = true
	var views := [
		{"id":"forest", "position":Vector3(330,127,1190), "target":Vector3(355,95,1300), "fov":65.0},
		{"id":"frontier", "position":Vector3(535,135,1270), "target":Vector3(660,75,1310), "fov":65.0}]
	for view in views:
		review._views.clear()
		review._views.append(view)
		review._camera.look_at_from_position(view.position,view.target)
		director._frontier.update_view(review._camera,review._streamer._built,director.frontier_color())
		await review._capture_all(40)
	# Same loaded woodland, different authored biome atmosphere controls.
	review._views.clear()
	review._views.append(views[0])
	for id: StringName in [&"meadow", &"deep_forest", &"twilight_marsh", &"amber_heath"]:
		director._mood_weights = {id:1.0}
		director._update_mood(0.0,{id:1.0})
		review._views[0].id = String(id)
		review._camera.look_at_from_position(views[0].position,views[0].target)
		director._frontier.update_view(review._camera,review._streamer._built,director.frontier_color())
		await review._capture_all(41)
	print("WORLD_GALLERY_DONE")
