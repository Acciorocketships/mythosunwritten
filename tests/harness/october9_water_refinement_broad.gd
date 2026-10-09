extends RefCounted


func run(review: Node) -> void:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(
		"res://tests/harness/october9_water_mesh_clearance.gd"
	)
	if script.reload() != OK:
		return
	var probe: RefCounted = script.new()
	probe.scan_rect = Rect2(-192, 960, 191.5, 383.5)
	probe.scan_step = 1.0
	await probe.run(review)
	DirAccess.rename_absolute(
		review._output_dir + "/water-mesh-clearance.json",
		review._output_dir + "/water-mesh-clearance-broad.json"
	)
