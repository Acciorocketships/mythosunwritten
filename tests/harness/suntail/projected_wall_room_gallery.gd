extends "res://tests/harness/suntail/building_gallery.gd"


func _run() -> void:
	get_root().size = Vector2i(1400, 1000)
	for projected: bool in [false, true]:
		var fixture := preload("res://tests/fixtures/wall_front_projection.gd").build(projected)
		print("PROJECTED_FIXTURE ", fixture.projections)
		var payload := EnvironmentInstancePayload.new()
		BuildingKitAssembler.append_to_payload(fixture.parts, Transform3D.IDENTITY, payload)
		var stage := _stage()
		await _commit(stage, payload)
		var name := "projected" if projected else "flush"
		await _shoot(stage, Vector3(11, 6, -12), Vector3(4, 4.5, 0), name + "-front", 50)
		await _shoot(stage, Vector3(8, 3, -5), Vector3(4, 4, 0), name + "-below", 65)
		stage.queue_free()
		await process_frame
	quit()
