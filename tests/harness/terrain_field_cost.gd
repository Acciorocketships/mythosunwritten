extends SceneTree

## Per-sample cost of the natural field (smooth vs detailed), spec §7 budget.
##   Godot --headless --path . -s res://tests/harness/terrain_field_cost.gd

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var points: Array[Vector3] = []
	for i in 20000:
		points.append(Vector3(float(i % 200) * 6 - 1000, 0, float(i / 200) * 6 - 1200))
	for detail in [false, true, false, true]:
		var start := Time.get_ticks_usec()
		var sum := 0.0
		for point in points:
			sum += HeightfieldPlan.height01(point, 2697992464, detail)
		print("FIELD_COST detail=%s us_per_sample=%.2f checksum=%.6f" % [detail,
			float(Time.get_ticks_usec() - start) / points.size(), sum])
	quit()
