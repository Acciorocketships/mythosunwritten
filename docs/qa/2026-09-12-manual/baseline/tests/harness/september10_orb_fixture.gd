extends "res://tests/harness/september10_reported_qa.gd"

func _capture_spot(spot: Array) -> void:
	await super._capture_spot(spot)
	var world := _streamer.get_parent() as Node3D
	var rows: Array = []
	for fx: Node3D in world.find_children("BiomeFx*", "Node3D", true, false):
		var small := PackedVector3Array()
		var large: Array[Vector3] = []
		for child in fx.get_children():
			if child is GPUParticles3D and child.name == &"fireflies":
				var material := child.process_material as ParticleProcessMaterial
				var points := material.emission_point_texture.get_image()
				for i in material.emission_point_count:
					var p := points.get_pixel(i, 0)
					small.append(Vector3(p.r,p.g,p.b))
			if child is SpiritOrb:
				large.append(child.anchor)
		fx.set_meta("orb_small_anchors", small)
		fx.set_meta("orb_large_anchors", large)
		rows.append({"origin":str(fx.global_position),"small":small.size(),"large":large.size()})
	assert(load("res://tests/harness/september9_render_fixture.gd").save_world(world,
		_output_dir+"/world.scn") == OK)
	FileAccess.open(_output_dir+"/inventory.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
