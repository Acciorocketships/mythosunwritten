extends RefCounted
## Destructive diagnostic for cliff_site_review only. Stop all producers before
## dropping categories; never use these mutations in a live game.
func mark(label: String) -> void:
	print("MEMORY_CATEGORY ", JSON.stringify({"label":label,
		"static_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,
		"objects":Performance.get_monitor(Performance.OBJECT_COUNT),
		"video_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0}))
func settle(review: Node, label: String) -> void:
	for i in 8: await review.get_tree().process_frame
	mark(label)
func run(review: Node) -> void:
	var s: FieldTerrainStreamer = review._streamer
	s.set_process(false)
	s._mutex.lock(); s._exit = true; s._mutex.unlock(); s._sem.post()
	if s._thread.is_started(): s._thread.wait_to_finish()
	s._reap_tail_tasks(true)
	if s._grass_work != null: s._grass_work.stop()
	s._done.clear()
	s._abandon_integration()
	s._flush_drops(); s._reap_drop_tasks(true)
	await settle(review,"stopped")
	for pair in [[s._fields,"_entries"],[s._plan,"_samples"],[s._plan,"_water_bank_bounds"],
		[s._water,"_region_cache"],[s._water,"_native_regions"],
		[s._water,"_smooth_samples"],[s._water,"_detail_samples"]]:
		var cache: Dictionary = pair[0].get(pair[1])
		print("MEMORY_CACHE ",pair[1]," entries=",cache.size())
		cache.clear()
		await settle(review,pair[1])
	var shapes := review.get_tree().root.find_children("*","CollisionShape3D",true,false)
	for shape: CollisionShape3D in shapes: shape.shape = null
	shapes.clear()
	await settle(review,"collision_shapes_removed")
	var meshes := review.get_tree().root.find_children("*","MeshInstance3D",true,false)
	for mesh: MeshInstance3D in meshes: mesh.mesh = null
	meshes.clear()
	await settle(review,"scene_meshes_removed")
	var multis := review.get_tree().root.find_children("*","MultiMeshInstance3D",true,false)
	for multi: MultiMeshInstance3D in multis: multi.multimesh = null
	multis.clear()
	await settle(review,"scene_multimeshes_removed")
	print("MEMORY_CATEGORY_DONE")
