extends RefCounted

func run(review:Node)->void:
	var old_views:Array[Dictionary] = review._views.duplicate()
	review._views.clear()
	var space:PhysicsDirectSpaceState3D = review.get_world_3d().direct_space_state
	var excluded:Array[RID] = []
	for body:StaticBody3D in review.find_children("DressingCollision","StaticBody3D",true,false): excluded.append(body.get_rid())
	for entry:Array in [["bush",Vector3(-226.7,60.1,1331.7),Vector3(-222.4,61.8,1330.8)],
		["transition",Vector3(-312.3,47,1357.6),Vector3(-311.8,49.2,1355.6)]]:
		var old_player:Vector3 = entry[1]
		var query := PhysicsRayQueryParameters3D.create(Vector3(old_player.x,1000,old_player.z),Vector3(old_player.x,-500,old_player.z),1)
		query.exclude=excluded
		var hit := space.intersect_ray(query)
		if hit.is_empty():continue
		var player:Vector3 = hit.position
		var crosshair:Vector3 = entry[2]+Vector3.UP*(player.y-old_player.y)
		var pivot := player+Vector3.UP*CameraMouseView.PIVOT_HEIGHT
		var delta := crosshair-pivot
		var pitch := atan2(-delta.y,Vector2(delta.x,delta.z).length())
		var camera := ReviewCam.solve_cam(player,crosshair,CameraMouseView.BOOM_LENGTH*cos(pitch),
			CameraMouseView.PIVOT_HEIGHT+CameraMouseView.BOOM_LENGTH*sin(pitch),CameraMouseView.PIVOT_HEIGHT)
		review._views.append({"id":entry[0]+"_original_direction","position":camera,"target":pivot,"fov":75.0,"player":player})
	var at:=Vector3(-274,108.4545,1150)
	review._views.append({"id":"battle_overview","position":at+Vector3(60,75,60),"target":at,"fov":65.0,"player":at})
	await review._capture_all(42)
	review._views.clear()
	var water_at:=Vector3(-39.17648,75.66567,1144.4)
	review._views.append({"id":"river_shallow_without_water","position":Vector3(-60.09403,107.6657,1180.82),"target":water_at,"fov":60.0,"player":water_at})
	var hidden:Array[Node3D]=[]
	for node:Node in review.get_tree().get_nodes_in_group("water_surface"):
		if node is Node3D and node.visible:
			hidden.append(node);node.visible=false
	await review._capture_all(43)
	for node:Node3D in hidden:node.visible=true
	review._views=old_views
	print("FINAL_DETAIL_VIEWS done")
