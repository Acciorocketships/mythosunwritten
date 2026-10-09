extends RefCounted
## Live, reversible grass-only readability study. Never lifts vegetation.
func run(review:Node)->void:
	var trample:TrampleField=review._streamer._trample_field
	if trample==null:
		push_error("Bush collar study requires --grass");return
	var target:=Vector3(-222.0464,62.416,1328.914)
	var found:Dictionary={}
	var distance:=INF
	for node:MultiMeshInstance3D in review.find_children("*","MultiMeshInstance3D",true,false):
		if node.multimesh==null or node.multimesh.mesh==null:continue
		if not node.multimesh.mesh.resource_path.contains("meadow_birch_bush_03_summer_piece_00"):continue
		for i in node.multimesh.instance_count:
			var t:=node.global_transform*node.multimesh.get_instance_transform(i)
			var d:=Vector2(t.origin.x,t.origin.z).distance_to(Vector2(target.x,target.z))
			if d<distance:distance=d;found={"node":node,"transform":t}
	if found.is_empty():
		push_error("No matching birch bush loaded");return
	var at:Vector3=found.transform.origin
	var old_views:Array[Dictionary]=review._views.duplicate()
	var old_plain:bool=review._plain
	review._views.clear()
	review._views.append({"id":"bush","position":at+Vector3(6,4,9),"target":at+Vector3.UP,"fov":45.0})
	review._plain=true
	await review._capture_all(20)
	for radius:float in [1.5,2.0,2.5]:
		var points:=PackedVector2Array()
		for i in 16:points.append(Vector2(at.x,at.z)+Vector2.RIGHT.rotated(i*TAU/16)*radius)
		trample.update_static_chunks({Vector2i(100000,100000):[{"position":at,"points":points,"radius":radius}]})
		await review._capture_all(25 if radius==1.5 else (26 if radius==2.0 else 27))
	trample.update_static_chunks({Vector2i(100000,100000):null})
	review._views=old_views;review._plain=old_plain
	print("BUSH_COLLAR_TRIAL at=",at," distance_from_photo=",distance)
