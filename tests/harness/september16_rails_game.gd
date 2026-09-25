extends "res://tests/harness/september16_town_qa.gd"

func _capture_views(world: Node3D) -> void:
	var output := _output_dir
	_output_dir = output.path_join("before")
	await super._capture_views(world)
	var path := "res://docs/qa/2026-09-16-manual/05-town-rails/"
	var before: Dictionary = FileAccess.open(path+"before-payload.bin",FileAccess.READ).get_var()
	var after: Dictionary = FileAccess.open(path+"after-payload.bin",FileAccess.READ).get_var()
	var removed: Array[Transform3D] = []
	for asset: StringName in before.batches:
		var batch: Dictionary = before.batches[asset]
		var keep: Array = after.batches.get(asset,{}).get("ids",[])
		for i in batch.ids.size():
			if batch.ids[i] in keep: continue
			assert(String(batch.ids[i]).begins_with("public-guard/"))
			removed.append((before.transform as Transform3D)*batch.transforms[i])
	assert(removed.size()==2)
	var matches := 0
	for node: MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
		if not String(node.name).begins_with("sfv_deck_railing_s_001"): continue
		var mm := node.multimesh.duplicate() as MultiMesh
		for i in mm.instance_count:
			var transform := mm.get_instance_transform(i)
			for target: Transform3D in removed:
				if (node.global_transform*transform).origin.distance_to(target.origin)>.001: continue
				# Matched frozen art replay: remove exactly the production delta.
				# Native collision is exercised separately by rails_clearance.
				mm.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))
				matches += 1
		node.multimesh = mm
	assert(matches==2,"Both removed native rails must exist in the frozen game")
	_output_dir = output.path_join("after")
	await super._capture_views(world)
	_output_dir = output
	print("RAILS_GAME_REPLAY removed=",matches)
