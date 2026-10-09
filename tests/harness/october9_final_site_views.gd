extends RefCounted

## Fresh, ground-relative review of the changed geography. Old screenshot Y
## coordinates can now lie inside a hill. Keep XZ anchors, record both physics
## hits and final camera poses, and never count an unloaded ray as a view.
func run(review: Node) -> void:
	var exclusions: Array[RID] = []
	for body: StaticBody3D in review.find_children("DressingCollision","StaticBody3D",true,false):
		exclusions.append(body.get_rid())
	var space: PhysicsDirectSpaceState3D = review.get_world_3d().direct_space_state
	var sites: Array[Dictionary]
	if review._at.x > 0:
		sites = [
			{"id":"water_ledge","at":Vector2(373,1109),"toward":Vector2(410,1120)},
			{"id":"water_bed","at":Vector2(468,1117),"toward":Vector2(462,1106)},
			{"id":"water_containment","at":Vector2(269,1168),"toward":Vector2(160,1133)}]
	else:
		sites = [
			{"id":"land_transition","at":Vector2(-312,1357),"toward":Vector2(-311,1330)},
			{"id":"land_foliage","at":Vector2(-226,1331),"toward":Vector2(-240,1310)},
			{"id":"land_battle","at":Vector2(-274,1150),"toward":Vector2(-240,1110)}]
	var old_views: Array[Dictionary] = review._views.duplicate()
	var evidence := []
	review._views.clear()
	for site: Dictionary in sites:
		var anchor := _ground(space,site.at,exclusions)
		var target := _ground(space,site.toward,exclusions)
		if anchor.is_empty() or target.is_empty():
			evidence.append({"id":site.id,"error":"unloaded ground"})
			continue
		var at: Vector3 = anchor.position
		var toward: Vector3 = target.position
		var camera := at+Vector3.UP*3.2
		var aim := toward+Vector3.UP*1.2
		review._views.append({"id":site.id,"position":camera,"target":aim,"fov":75.0,"player":at})
		evidence.append({"id":site.id,"ground":str(at),"camera":str(camera),"target":str(aim),
			"ground_collider":str(anchor.collider.get_path()),"target_collider":str(target.collider.get_path())})
	await review._capture_all(40)
	var file := FileAccess.open(review._output_dir+"/final-site-views.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"  "))
	file.close()
	review._views = old_views
	print("FINAL_SITE_VIEWS ",JSON.stringify(evidence))

func _ground(space:PhysicsDirectSpaceState3D,at:Vector2,exclusions:Array[RID])->Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(at.x,1000,at.y),Vector3(at.x,-500,at.y),1)
	ray.exclude = exclusions
	return space.intersect_ray(ray)
