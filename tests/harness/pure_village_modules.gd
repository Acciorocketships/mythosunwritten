extends "res://tests/harness/pure_village_lineup.gd"
## Curated native joins, separately framed and freed between studies.
## Opening panels are 3 m wide; plain wall stock also comes in 2 m widths.
const STUDIES := [
	["open_windows", "Window_10_3", "Window_12_3", "Window_18_3"],
	["window_variants", "Window_1_1", "Window_1_2", "Window_1_3"],
	["plaster_openings", "Window_1_3", "Door_2_2", "Window_8_1"],
	["stone_openings", "Window_14_1", "Door_9_1", "Window_14_1"],
	["wall_stock", "Wall_Start_20x30_0", "Wall_End_20x30_1", "WallStone_Start_20x30_1"],
]
const BAKED := {
	"Window_1_3": "wall_plaster_window", "Door_2_2": "wall_plaster_door",
	"Window_14_1": "wall_stone_window", "Door_9_1": "wall_stone_door",
	"Wall_Start_20x30_0": "wall_plaster_plain", "WallStone_Start_20x30_1": "wall_stone_plain",
}

func _run() -> void:
	get_root().size = Vector2i(1600, 900)
	var baked := OS.get_cmdline_user_args().has("--baked")
	for study: Array in STUDIES:
		var stage := Node3D.new()
		get_root().add_child(stage)
		_light(stage)
		for i in range(1, study.size()):
			if baked and not BAKED.has(study[i]): continue
			var part: Node3D
			if baked:
				part = Node3D.new()
				var visual := load("res://terrain/environment/visuals/pure_village_kit/pure_village_%s.tres" % BAKED[study[i]]) as EnvironmentVisual
				for piece: EnvironmentVisualPiece in visual.pieces:
					var instance := MeshInstance3D.new()
					instance.mesh = piece.mesh
					instance.transform = piece.local_transform
					part.add_child(instance)
			else:
				part = (load(R + "Architecture/" + study[i] + ".glb") as PackedScene).instantiate()
			stage.add_child(part)
			part.position.x = (i - 2) * (2.0 if baked else 3.0)
			print("MODULE %s %s" % [study[i], _aabb(part)])
		await _shoot(stage, Vector3(8, 4, 12), Vector3(0, 1.5, 0), study[0] + "_front")
		await _shoot(stage, Vector3(-8, 4, -12), Vector3(0, 1.5, 0), study[0] + "_back")
		stage.queue_free()
		await process_frame
	quit()
