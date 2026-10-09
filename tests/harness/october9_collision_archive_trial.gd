extends RefCounted

func run(review: Node) -> void:
	var root: Node = review._streamer._built[Vector2i(1,6)]
	var archive := preload("res://scripts/terrain/field/TerrainCollisionArchive.gd").new()
	var before_rays := _rays(review)
	var hashes: Dictionary = {}
	var before := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var suspend_max := 0
	for node: Node in root.find_children("*","CollisionShape3D",true,false):
		if not node.shape is ConcavePolygonShape3D or not node.shape.resource_path.is_empty(): continue
		hashes[node.get_instance_id()] = hash(node.shape.get_faces())
		var began := Time.get_ticks_usec()
		archive.suspend(node)
		suspend_max = maxi(suspend_max,Time.get_ticks_usec()-began)
		await review.get_tree().process_frame
	await review.get_tree().create_timer(1.0).timeout
	var after := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var count := archive.pending()
	var packed := archive.compressed_bytes
	var raw := archive.source_bytes
	var restore_max := 0
	while archive.pending() > 0:
		var began := Time.get_ticks_usec()
		assert(archive.restore_one())
		restore_max = maxi(restore_max,Time.get_ticks_usec()-began)
		await review.get_tree().process_frame
	await review.get_tree().physics_frame
	await review.get_tree().physics_frame
	var mismatches := 0
	for id: int in hashes:
		var node := instance_from_id(id) as CollisionShape3D
		if node == null or node.shape == null or hash(node.shape.get_faces()) != hashes[id]: mismatches += 1
	var after_rays := _rays(review)
	var ray_mismatches := 0
	for i in before_rays.size():
		if before_rays[i] != after_rays[i]: ray_mismatches += 1
	var result := {"shapes":count,"memory_before":before,"memory_suspended":after,"released_bytes":before-after,
		"raw_bytes":raw,"compressed_bytes":packed,"max_suspend_usec":suspend_max,"max_restore_usec":restore_max,
		"face_hash_mismatches":mismatches,"rays":before_rays.size(),"ray_mismatches":ray_mismatches,
		"target":"(1,6)","restored":true}
	FileAccess.open(review._output_dir+"/collision-archive-trial.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("COLLISION_ARCHIVE_TRIAL_DONE ",JSON.stringify(result))

func _rays(review: Node) -> Array:
	var rows: Array = []
	var space: PhysicsDirectSpaceState3D = review.get_world_3d().direct_space_state
	for z in 8:
		for x in 8:
			var p := Vector3(192+x*24+12,1000,1152+z*24+12)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p,p-Vector3.UP*2000))
			rows.append([hit.position,hit.normal] if not hit.is_empty() else [])
	return rows
