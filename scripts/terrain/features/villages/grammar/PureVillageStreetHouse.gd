extends RefCounted
## Two-storey timber street-house family with a supported projecting gable.
## Length is measured in 3 m native bays. Side rows, foundations, projection,
## roof courses and closure positions share that one dimension.
const Roof = preload("res://scripts/terrain/features/villages/grammar/PureVillageJettyRoof.gd")
const Jetty = preload("res://scripts/terrain/features/villages/grammar/PureVillageJetty.gd")
const Native = preload("res://scripts/terrain/features/villages/grammar/PureVillageNativeRoof.gd")


static func derive(
	bays: int, facade_choices: Dictionary = {}, rear_jetty: bool = false
) -> Array[Dictionary]:
	assert(bays >= 2 and bays <= 6)
	var parts := Roof.derive(bays, 6.0, rear_jetty)
	var half_length := bays * 1.5
	var front := Transform3D(Basis.IDENTITY, Vector3(0, 3, half_length))
	# The right upper end bay continues through the projection. It owns that
	# return; emitting a second short wall would overlap its timber and plaster.
	for part: Dictionary in Jetty.derive([1]).parts:
		parts.append({"module": part.module, "transform": front * part.transform})
	Native._emit(parts, "Door_4_1", Vector3(0, 0, half_length), 0)
	Native._emit(parts, "Wall_End_30x30_1", Vector3(0, 0, -half_length), PI)
	if rear_jetty:
		# Unlike the authored front, both rear returns belong to the projection.
		# Its window, soffit and brackets replace the complete upper end panel.
		var rear := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 3, -half_length))
		for part: Dictionary in Jetty.derive().parts:
			parts.append({"module": part.module, "transform": rear * part.transform})
	else:
		Native._emit(parts, "Window_18_2", Vector3(0, 3, -half_length), PI)
	for bay in bays:
		var z := -half_length + (bay + .5) * 3
		_emit_facade(
			parts,
			"Wall_End_30x30_1" if bay == bays - 1 else "Wall_Middle1_30x30_1",
			Vector3(-1.5, 0, z),
			-PI * .5,
			"west/lower/%d" % bay if bay < bays - 1 else "",
			facade_choices
		)
		Native._emit(
			parts, "Window_1_1" if bay == 0 else "Window_1_2", Vector3(-1.5, 3, z), -PI * .5
		)
		if bay == 0:
			_mirror_last(parts)
		for side: int in [-1, 1]:
			Native._emit(
				parts, "WallStone_Bottom_Middle_30x15", Vector3(side * 1.5, -1.5, z), side * PI * .5
			)
	# Right facade uses a one-metre edge bay, then full middle bays; the last
	# panel closes two metres below and three metres above (including the jetty).
	for floor_level in [0.0, 3.0]:
		Native._emit(
			parts, "Wall_End_10x30_1", Vector3(1.5, floor_level, -half_length + 1), PI * .5
		)
		for bay in bays - 1:
			_emit_facade(
				parts,
				"Window_12_2" if floor_level == 0.0 and bay == 0 else "Wall_Middle1_30x30_1",
				Vector3(1.5, floor_level, -half_length + 2.5 + bay * 3),
				PI * .5,
				"east/%s/%d" % ["lower" if floor_level == 0.0 else "upper", bay],
				facade_choices
			)
		Native._emit(
			parts,
			"Wall_End_20x30_1" if floor_level == 0.0 else "Wall_End_30x30_1",
			Vector3(1.5, floor_level, half_length - 2 if floor_level == 0.0 else half_length - .5),
			PI * .5
		)
		_mirror_last(parts)
	Native._emit(parts, "WallStone_BottomEntrance_Middle_15x30", Vector3(0, -1.5, half_length), 0)
	Native._emit(parts, "WallStone_Bottom_Middle_30x15", Vector3(0, -1.5, -half_length), PI)
	# Native corner ownership: masonry at both front corners and back-right;
	# the rear-left joint has the full-height timber post instead.
	Native._emit(parts, "Stone_Corner_Start_x15", Vector3(-1.5, -1.5, half_length), 0)
	Native._emit(parts, "Stone_Corner_Start_x15", Vector3(1.5, -1.5, half_length), PI * .5)
	Native._emit(parts, "Stone_Corner_Start_x15", Vector3(1.5, -1.5, -half_length), PI)
	Native._emit(parts, "Wood_Beam_3x30_2", Vector3(-1.5, 4.5, -half_length), 0)
	parts.back().transform.basis = Basis.from_scale(Vector3(1.5, 1, 1.5))
	var available: Dictionary = {}
	for part: Dictionary in parts:
		if part.has("facade_slot"):
			available[part.facade_slot] = true
	for slot in facade_choices:
		assert(available.has(slot), "Unknown facade slot; corner/return panels cannot be replaced")
	return parts


static func _mirror_last(parts: Array[Dictionary]) -> void:
	parts.back().transform.basis = (
		parts.back().transform.basis * Basis.from_scale(Vector3(-1, 1, 1))
	)


static func instantiate(
	bays: int, facade_choices: Dictionary = {}, rear_jetty: bool = false
) -> Node3D:
	var root := Node3D.new()
	for part: Dictionary in derive(bays, facade_choices, rear_jetty):
		var module: Node3D = (
			(load(Native.MODULE_ROOT + part.module + ".glb") as PackedScene).instantiate()
		)
		root.add_child(module)
		module.transform = part.transform
	return root


# Only complete three-metre middle bays share this socket. End/return panels
# keep their timber ownership and cannot enter the optional window vocabulary.
const FACADE_WINDOWS: Array[String] = ["Window_1_2", "Window_12_2"]
## House_12/12b use this complete three-metre projecting window bay below
## another inhabited storey. Keep its native hood, returns and wall opening
## together; it replaces the wall panel rather than sitting on top of it.
const FACADE_PROJECTIONS: Array[String] = ["Window_5_2"]


static func _emit_facade(
	parts: Array[Dictionary],
	module: String,
	at: Vector3,
	yaw: float,
	slot: String,
	choices: Dictionary
) -> void:
	var selected: String = choices.get(slot, module) if not slot.is_empty() else module
	assert(
		selected == module or selected in FACADE_WINDOWS or selected in FACADE_PROJECTIONS,
		"Incompatible facade module"
	)
	assert(
		(
			not slot.contains("/upper/")
			or (selected != "Window_12_2" and selected not in FACADE_PROJECTIONS)
		),
		"High narrow window conflicts with upper eave"
	)
	Native._emit(parts, selected, at, yaw)
	if not slot.is_empty():
		parts.back()["facade_slot"] = slot


static func sample(seed_value: int, bays: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# One lower-window family per house, paired with shuttered upper windows
	# below the eaves. Individual middle
	# bays can remain solid, but no eligible side/storey is left entirely blank.
	var window := FACADE_WINDOWS[rng.randi_range(0, FACADE_WINDOWS.size() - 1)]
	var rows: Dictionary = {}
	for part: Dictionary in derive(bays):
		if not part.has("facade_slot"):
			continue
		var slot: String = part.facade_slot
		var row := slot.get_slice("/", 0) + "/" + slot.get_slice("/", 1)
		if not rows.has(row):
			rows[row] = []
		rows[row].append(slot)
	var choices: Dictionary = {}
	for row: String in rows:
		var slots: Array = rows[row]
		var required := rng.randi_range(0, slots.size() - 1)
		for index in slots.size():
			if index == required or rng.randf() < .7:
				choices[slots[index]] = "Window_1_2" if row.ends_with("/upper") else window
		# One projecting bay can articulate each lower frontage. Its hood is
		# a full storey below the main eave; upper rows retain flush windows.
		if row.ends_with("/lower") and rng.randf() < .65:
			choices[slots[required]] = FACADE_PROJECTIONS[0]
	return choices
