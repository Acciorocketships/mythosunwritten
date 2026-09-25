extends SceneTree
const QA := "res://docs/qa/2026-09-19-manual/"
var mesh_hashes: Dictionary = {}
func _initialize() -> void: _run.call_deferred()
func mesh_hash(mesh: Mesh) -> PackedByteArray:
	if not mesh_hashes.has(mesh.get_instance_id()):
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		for surface in mesh.get_surface_count():
			hash.update(var_to_bytes(mesh.surface_get_arrays(surface)))
		mesh_hashes[mesh.get_instance_id()] = hash.finish()
	return mesh_hashes[mesh.get_instance_id()]
func fingerprint(stage: Node3D) -> Dictionary:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	var geometry := 0
	var collision := 0
	for node in stage.find_children("*","",true,false):
		if node is GeometryInstance3D and not node.is_in_group("tactical_preserve_surface"):
			hash.update(var_to_bytes(node.global_transform))
			if node is MeshInstance3D:
				hash.update(mesh_hash(node.mesh))
			elif node is MultiMeshInstance3D:
				hash.update(mesh_hash(node.multimesh.mesh))
				hash.update(var_to_bytes(node.multimesh.buffer))
			else:
				assert(false,"Unsupported geometry in unchanged-ground study")
			geometry+=1
		elif node is CollisionShape3D:
			hash.update(var_to_bytes(node.global_transform))
			hash.update(var_to_bytes([node.disabled,node.get_parent().collision_layer,node.get_parent().collision_mask]))
			if node.shape is ConcavePolygonShape3D:
				hash.update(node.shape.get_faces().to_byte_array())
			elif node.shape is BoxShape3D:
				hash.update(var_to_bytes(node.shape.size))
			else:
				assert(false,"Unsupported collision in unchanged-ground study")
			collision+=1
	return {"geometry":geometry,"collision":collision,"sha256":hash.finish().hex_encode()}
func _run() -> void:
	var selected := PackedStringArray(["P10","P21"])
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--spots="): selected=arg.trim_prefix("--spots=").split(",")
	var reports: Array[Dictionary] = []
	var okay := true
	for spot: String in selected:
		var row := {"spot":spot}
		for phase: String in ["before","after"]:
			var folder := "112-hillside-native-reaches/before/" if phase=="before" else "113-hillside-stable-terrain/after/"
			var stage: Node3D = load(QA+folder+spot+"/geometry.scn").instantiate()
			root.add_child(stage)
			row[phase]=fingerprint(stage)
			stage.free()
			mesh_hashes.clear()
		row.equal=row.before==row.after
		okay = okay and row.equal
		reports.append(row)
		print("GROUND_IDENTITY ",JSON.stringify(row))
	FileAccess.open(QA+"113-hillside-stable-terrain/geometry-"+"-".join(selected)+".json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	quit(0 if okay else 1)
