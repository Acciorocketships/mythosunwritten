extends SceneTree
func _init() -> void:
	var before: Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/06-rails/after-payload.bin",FileAccess.READ).get_var()
	var after: Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/07-platform/after-payload.bin",FileAccess.READ).get_var()
	var result := {"batches_identical":before.batches==after.batches,"collision_boxes_identical":before.collision_boxes==after.collision_boxes,"walked_identical":before.walked==after.walked,"before_meshes":before.surface_meshes.size(),"after_meshes":after.surface_meshes.size(),"new_meshes":[],"changed_meshes":[]}
	result["batch_changes"] = []
	for key in before.batches:
		if before.batches[key]!=after.batches.get(key,[]): result.batch_changes.append({"asset":str(key),"before":str(before.batches[key]).length(),"after":str(after.batches.get(key,[])).length()})
	var originals := {}
	for mesh: Dictionary in before.surface_meshes: originals[String(mesh.get("stable_id",""))]=mesh
	for mesh: Dictionary in after.surface_meshes:
		var id := String(mesh.get("stable_id",""))
		if not originals.has(id): result.new_meshes.append(id)
		elif originals[id]!=mesh: result.changed_meshes.append(id)
	FileAccess.open("res://docs/qa/2026-09-13-manual/07-platform/payload-comparison.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print(result)
	quit()
