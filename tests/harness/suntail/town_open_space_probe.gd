extends SceneTree
## Measure pre-bore clearing survival and vertical crossings before changing
## the town field. Circle cores use half the sampled radius, leaving a soft
## edge for dense frontage. No world coordinates or special seed branches.
const FIELD := preload("res://scripts/terrain/features/villages/fabric/WarrenTownField.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var rows: Array[Dictionary] = []
	for profile_id: StringName in [&"compact", &"standard", &"large"]:
		for seed_value: int in [7, 10, 38, 1260018864828801968]:
			var profile := WarrenVillageScaleProfile.for_id(profile_id)
			var field := FIELD.sample(seed_value, profile)
			var source := WarrenMazeSitePlanner.plan(seed_value, {}, profile, &"", false)
			if source == null:
				rows.append({"seed": seed_value, "profile": profile_id, "failed": true})
				continue
			var gap_cells := {}
			for gap: Dictionary in field.clearings:
				var centre: Vector2 = gap.centre
				var radius := float(gap.radius) * 0.5
				for z in range(floori(centre.y - radius), ceili(centre.y + radius) + 1):
					for x in range(floori(centre.x - radius), ceili(centre.x + radius) + 1):
						if Vector2(x, z).distance_to(centre) <= radius:
							gap_cells[Vector2i(x, z)] = true
			var solid := 0
			var occupied := {}
			var kinds := {}
			var reserved := {}
			for space: Dictionary in source.massif.open_spaces: reserved.merge(space.cells)
			var reserved_walks := 0
			for cell: Vector3i in source.passage_kinds:
				if reserved.has(Vector2i(cell.x, cell.z)): reserved_walks += 1
			var reserved_occupied := {}
			for plot: Dictionary in source.plots:
				kinds[String(plot.kind)] = int(kinds.get(String(plot.kind), 0)) + 1
				for cell: Vector2i in plot.cells:
					if gap_cells.has(cell): occupied[cell] = true
					if reserved.has(cell): reserved_occupied[cell] = true
			for cell: Vector2i in gap_cells:
				if source.massif.has_column(cell): solid += 1
			var row := {"seed": seed_value, "profile": profile_id,
				"reserved_spaces": source.massif.open_spaces.size(), "reserved_cells": reserved.size(),
				"reserved_plot_cells": reserved_occupied.size(), "reserved_walk_cells": reserved_walks,
				"clearings": field.clearings.size(), "core_cells": gap_cells.size(),
				"core_massif_cells": solid, "core_plot_cells": occupied.size(),
				"massif_columns": source.massif.columns.size(),
				"tunnel_cells": source.excavation.tunnel_cells.size(), "plots": kinds}
			rows.append(row)
			print(JSON.stringify(row))
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var file := FileAccess.open(args[0], FileAccess.WRITE)
		file.store_string(JSON.stringify(rows, "\t") + "\n")
	quit()
