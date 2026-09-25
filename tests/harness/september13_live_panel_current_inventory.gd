extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var path := "res://docs/qa/2026-09-13-manual/45-live-panels/"
	var data: Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/39-door-panels/after-payload.bin",FileAccess.READ).get_var()
	var world := load("res://docs/qa/2026-09-13-manual/39-door-panels/final-live/P37/world.scn").instantiate() as Node3D
	root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	await process_frame
	var catalog := EnvironmentCatalog.load_default()
	var actual := {}
	for node: Node in world.find_children("*","MultiMeshInstance3D",true,false):
		if not actual.has(node.multimesh.mesh.resource_path): actual[node.multimesh.mesh.resource_path] = []
		for index in node.multimesh.instance_count:
			actual[node.multimesh.mesh.resource_path].append({"transform":node.global_transform*node.multimesh.get_instance_transform(index),"node":str(node.get_path()),"index":index,"visible":node.is_visible_in_tree(),"count":node.multimesh.visible_instance_count,"mesh":node.multimesh.mesh.resource_path,"material":str(node.material_override),"color":str(node.multimesh.get_instance_color(index)) if node.multimesh.use_colors else "none","owner":str(node.multimesh.get_instance_custom_data(index)) if node.multimesh.use_custom_data else "none"})
	var missing := []
	var matched := 0
	var report := []
	for asset: StringName in data.batches:
		var visual := load(catalog.descriptor(asset).visual_path) as EnvironmentVisual
		var batch: Dictionary = data.batches[asset]
		for index in batch.transforms.size():
			for pi in visual.pieces.size():
				var expected: Transform3D = data.transform * batch.transforms[index] * visual.pieces[pi].local_transform
				var key: String = visual.pieces[pi].mesh.resource_path
				var nearest := INF
				var candidate := {}
				for entry: Dictionary in actual.get(key,[]):
					var delta := expected.origin.distance_to(entry.transform.origin)
					if delta < nearest:
						nearest = delta
						candidate = entry.duplicate()
				if nearest < .001:
					matched += 1
				else:
					missing.append({"asset":asset,"id":batch.ids[index],"expected":str(expected),"distance":nearest if is_finite(nearest) else -1.0,"nearest":candidate})
				if String(asset).contains("window") or String(asset).contains("wall"):
					report.append({"asset":asset,"id":batch.ids[index],"expected":str(expected),"distance":nearest if is_finite(nearest) else -1.0,"actual":candidate})
	print("LIVE_PANEL_INVENTORY matched=",matched," missing=",missing.size())
	FileAccess.open(path+"current-inventory.json",FileAccess.WRITE).store_string(JSON.stringify({"matched":matched,"missing":missing,"walls":report},"  "))
	quit()
