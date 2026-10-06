extends "res://tests/harness/suntail/building_gallery.gd"


func _run() -> void:
	get_root().size = Vector2i(1200, 900)
	var catalog := EnvironmentCatalog.load_default()
	for theme in ["slate", "orange"]:
		var asset := StringName("lpfv.fabric.roof.corner.%s.gable" % theme)
		var bounds := catalog.descriptor(asset).measured_aabb
		var payload := EnvironmentInstancePayload.new()
		for turn in 1:
			payload.add(
				asset,
				Transform3D(
					Basis.IDENTITY.scaled(Vector3.ONE * .5),
					Vector3(0, 1.5 - bounds.position.y * .5, 0)
				),
				Color.WHITE,
				StringName("hip.%d" % turn),
				true
			)
		for end in [-1, 1]:
			payload.add(
				SettlementFabricProgram.GABLE,
				Transform3D(
					Basis(Vector3.UP, 0.0 if end > 0 else PI).scaled(Vector3(.245, .23, .25)),
					Vector3(0, 1.5, end * .65)
				),
				Color.WHITE,
				StringName("attic.%d" % end),
				true
			)
		var stage := _stage()
		await _commit(stage, payload)
		await _shoot(stage, Vector3(3, 4, 4), Vector3(0, 2, 0), theme + "-above", 45)
		await _shoot(stage, Vector3(3, 1.2, 4), Vector3(0, 2, 0), theme + "-below", 45)
		stage.queue_free()
		await process_frame
	quit()
