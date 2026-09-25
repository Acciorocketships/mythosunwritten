extends SceneTree
func _init() -> void:
	var path := "res://docs/qa/2026-09-13-manual/"
	var args:=OS.get_cmdline_user_args()
	var before_path:=path+"07-platform/after-payload.bin"
	var after_path:=path+"08-roofs/after-payload.bin"
	var output:=path+"08-roofs/batch-differences.json"
	if "--before" in args: before_path=args[args.find("--before")+1]
	if "--after" in args: after_path=args[args.find("--after")+1]
	if "--output" in args: output=args[args.find("--output")+1]
	var before: Dictionary = FileAccess.open(before_path,FileAccess.READ).get_var()
	var after: Dictionary = FileAccess.open(after_path,FileAccess.READ).get_var()
	var old := _placements(before.batches)
	var current := _placements(after.batches)
	var result := {"before":old.size(),"after":current.size(),"removed":[],"added":[],"changed":[],"unchanged":0}
	for id in old:
		if not current.has(id): result.removed.append(id)
		elif old[id] != current[id]: result.changed.append({"id":id,"before":old[id],"after":current[id]})
		else: result.unchanged += 1
	for id in current:
		if not old.has(id): result.added.append(id)
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("ROOF_BATCHES ",result)
	quit()
func _placements(batches: Dictionary) -> Dictionary:
	var result := {}
	for asset in batches:
		var batch: Dictionary = batches[asset]
		for i in batch.transforms.size():
			var entry := {"asset":str(asset),"transform":str(batch.transforms[i]),"color":str(batch.colors[i])}
			for field: String in ["collision_enabled","visibility_owners"]:
				entry[field] = str(batch[field][i]) if batch.has(field) and not batch[field].is_empty() else "default"
			result[str(batch.ids[i])] = entry
	return result
