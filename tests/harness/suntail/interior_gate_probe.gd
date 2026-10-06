extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds: Array[int] = [7, 31, 43, 53, 63, 83, 103, 301]
	if args.has("--seeds"):
		var bounds := args[args.find("--seeds") + 1].split("-")
		seeds.assign(range(int(bounds[0]), int(bounds[1]) + 1))
	var rows := []
	for seed_value: int in seeds:
		var profile := &"large" if seed_value == 31 else &"grand"
		var source := WarrenMazeSitePlanner.plan(
			seed_value, {}, WarrenVillageScaleProfile.for_id(profile), &"reserve"
		)
		if source == null:
			print("GATE ", seed_value, " FAILED ", WarrenMazeSitePlanner.last_failure)
			rows.append({"seed": seed_value, "failure": WarrenMazeSitePlanner.last_failure})
			continue
		var gates := []
		for lane: Dictionary in source.excavation.lanes:
			if lane.get("feature_kind", &"") == &"citadel_gate":
				var inside := 0
				for cell: Vector3i in lane.cells:
					var column := Vector2i(cell.x, cell.z)
					inside += int(
						(
							source.massif.is_platform(column)
							and cell.y < source.massif.bearing_at(column)
						)
					)
				gates.append(
					{
						"cells": lane.cells,
						"covers": lane.get("gate_covers", {}),
						"interior_cells": inside
					}
				)
		rows.append({"seed": seed_value, "gates": gates})
		print("GATE ", seed_value, " ", gates)
	if args.has("--output"):
		FileAccess.open(args[args.find("--output") + 1], FileAccess.WRITE).store_string(
			JSON.stringify(rows, "\t")
		)
	quit()
