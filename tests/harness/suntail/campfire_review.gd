extends "res://tests/harness/pure_village_lineup.gd"

func _run() -> void:
	get_root().size = Vector2i(1200,900)
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	for id: StringName in [&"sfbp.campfire.001",&"suntail.prop.bonfire"]:
		var stage := Node3D.new()
		get_root().add_child(stage)
		_light(stage)
		var visual := cache.visual(id)
		for piece: EnvironmentVisualPiece in visual.pieces:
			var node := MeshInstance3D.new()
			node.mesh = piece.mesh
			node.transform = piece.local_transform
			stage.add_child(node)
		var box := cache.descriptor(id).measured_aabb
		box = box.expand(Vector3(0,1.8,0))
		preload("res://scripts/terrain/environment/EnvironmentCampfires.gd").attach(stage,id,[Transform3D.IDENTITY])
		var target := box.get_center()
		await _shoot(stage,target+Vector3(1,.6,1)*box.size.length(),target,String(id))
		for phase in 2:
			await create_timer(.3).timeout
			await _shoot(stage,target+Vector3(1,.6,1)*box.size.length(),target,"%s_phase%d" % [id,phase])
		for light: DirectionalLight3D in stage.find_children("*","DirectionalLight3D",true,false):
			light.light_energy = .12
		for environment: WorldEnvironment in stage.find_children("*","WorldEnvironment",true,false):
			environment.environment.ambient_light_energy = .18
			environment.environment.background_color = Color(.025,.035,.075)
		await _shoot(stage,target+Vector3(1,.6,1)*box.size.length(),target,"%s_night" % id)
		stage.queue_free()
		await process_frame
	quit()
