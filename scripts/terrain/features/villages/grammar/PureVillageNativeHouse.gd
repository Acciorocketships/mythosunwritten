extends RefCounted
## Native stone-shell rule. Facade choices replace complete wall bays (including
## their returns), never overlay a window/door on an uncut solid panel.
## This is a reconstruction/sampling family, not yet a production town adapter.
const Roof = preload("res://scripts/terrain/features/villages/grammar/PureVillageNativeRoof.gd")
const WALL := "WallStone_Middle1_30x30_1"
const OPENINGS := {
	&"solid": WALL, &"window": "Window_1_3", &"stone_window": "Window_14_1", &"door": "Door_9_1"
}


## Face ids: south +Z, north -Z, west -X, east +X. Bay indices follow world
## X on long faces and world Z on ends, independent of outward orientation.
static func derive(bays: int, choices: Dictionary = {}) -> Array[Dictionary]:
	var parts := Roof.derive(bays, 3.0)
	var half_length := bays * 1.5
	for face: StringName in [&"south", &"north", &"west", &"east"]:
		var long_face := face in [&"south", &"north"]
		var count := bays if long_face else 2
		var yaw := 0.0
		match face:
			&"north":
				yaw = PI
			&"west":
				yaw = -PI * .5
			&"east":
				yaw = PI * .5
		for bay in count:
			var at := Vector3(
				-half_length + (bay + .5) * 3 + .125, 0, 3 if face == &"south" else -3
			)
			if not long_face:
				at = Vector3(
					(-half_length if face == &"west" else half_length) + .125, 0, -1.5 + bay * 3
				)
			var key := "%s/%d" % [face, bay]
			var choice: StringName = choices.get(key, &"solid")
			assert(OPENINGS.has(choice), "Unknown native facade interface")
			var module_at := at
			if choice == &"door":
				# Authored door bay's frame centre differs from the stone bay
				# centre by 125 mm along its local X, not along the world axis.
				module_at += Basis(Vector3.UP, yaw) * Vector3(-.125, 0, 0)
			Roof._emit(parts, OPENINGS[choice], module_at, yaw)
			Roof._emit(
				parts,
				(
					"WallStone_BottomEntrance_Middle_15x30"
					if choice == &"door"
					else "WallStone_Bottom_Middle_30x15"
				),
				at + Vector3.DOWN * 1.5,
				yaw
			)
			if long_face:
				Roof._emit(parts, "WallStone_Middle_30x10_1", at + Vector3.UP * 3, yaw)
	# Separate corner courses close both adjoining faces. Their local start/end
	# interface differs on the foundation; it cannot be selected independently.
	for end: int in [-1, 1]:
		for side: int in [-1, 1]:
			var at := Vector3(end * half_length + .125, 0, side * 3)
			var yaw := 0.0 if end == 1 else -PI * .5
			if side == -1:
				yaw = PI * .5 if end == 1 else PI
			Roof._emit(parts, "Stone_Corner_End_x30", at, yaw)
			Roof._emit(parts, "Stone_Corner_End_x7", at + Vector3.UP * 3, yaw)
			Roof._emit(
				parts,
				"Stone_Corner_%s_x15" % ("End" if end == side else "Start"),
				at + Vector3.DOWN * 1.5,
				0 if side == 1 else PI
			)
	return parts


static func instantiate(bays: int, choices: Dictionary = {}) -> Node3D:
	var root := Node3D.new()
	for part: Dictionary in derive(bays, choices):
		var module: Node3D = (
			(load(Roof.MODULE_ROOT + part.module + ".glb") as PackedScene).instantiate()
		)
		root.add_child(module)
		module.transform = part.transform
	return root


static func sample(seed_value: int, bays: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var choices: Dictionary = {}
	# One front entrance; other bays choose compatible complete panels.
	var entrance := rng.randi_range(0, bays - 1)
	for face: StringName in [&"south", &"north", &"west", &"east"]:
		var count := bays if face in [&"south", &"north"] else 2
		var opening := rng.randi_range(0, count - 1)
		for bay in count:
			var choice: StringName = (
				&"stone_window" if bay == opening or rng.randf() < .65 else &"solid"
			)
			if face == &"south" and bay == entrance:
				choice = &"door"
			choices["%s/%d" % [face, bay]] = choice
	return choices
