extends RefCounted

func run(review: Node) -> void:
	# Destructive diagnostic in the disposable review scene only. Keep the
	# photographed chunk's physics available for further riverbed probes.
	var before := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var shapes := 0
	for chunk: Vector2i in review._streamer._built:
		if chunk == Vector2i(1,6): continue
		var root: Node = review._streamer._built[chunk]
		for node: Node in root.find_children("*","CollisionShape3D",true,false):
			node.free()
			shapes += 1
	await review.get_tree().create_timer(2.0).timeout
	var after := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var result := {"before":before,"after":after,"released_bytes":before-after,"removed_shapes":shapes,
		"kept_physics_chunk":"(1,6)","scope":"eight review chunks; scene physics deliberately removed outside the target; includes backend shape memory, not just input faces"}
	FileAccess.open(review._output_dir+"/collision-release.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("COLLISION_MEMORY_RELEASE_DONE ",JSON.stringify(result))
