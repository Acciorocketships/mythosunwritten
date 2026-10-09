extends RefCounted
func run(review:Node)->void:
	var director:AtmosphereDirector
	for node in review.find_children("*","",true,false):
		if node is AtmosphereDirector: director=node;break
	assert(director!=null)
	var lights:=review.get_tree().get_nodes_in_group("atmosphere_local_light")
	var chosen:OmniLight3D
	var nearest:=INF
	for light in lights:
		if not light.is_visible_in_tree():continue
		var distance:float=light.global_position.distance_to(Vector3(679,44.6,1539.2))
		if distance<nearest:nearest=distance;chosen=light
	print("ATMOSPHERE_LIGHTS count=",lights.size()," nearest=",chosen.global_position if chosen!=null else Vector3.ZERO)
	if chosen==null:return
	var at:=chosen.global_position
	var old:Array=review._views.duplicate()
	review._views.clear()
	for i in 3:
		var direction:=Vector3(cos(i*TAU/3),0,sin(i*TAU/3))
		var pos:=at+direction*12.0+Vector3.UP*2.0
		var query:=PhysicsRayQueryParameters3D.create(Vector3(pos.x,1000,pos.z),Vector3(pos.x,-500,pos.z),1)
		var hit:Dictionary=review.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():pos.y=maxf(pos.y,hit.position.y+2.0)
		review._views.append({"id":"forest_glow_%d"%i,"position":pos,"target":at,"fov":60.0,"player":at})
	await review._capture_all(10)
	review._views.assign(old)
	print("ATMOSPHERE_VIEWS_DONE")
