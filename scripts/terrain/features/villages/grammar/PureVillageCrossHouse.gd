extends RefCounted
## Native compound shell with compatible middle-bay openings.
## Foundation and production access/clearance fitting are still required.
const CrossRoof = preload("res://scripts/terrain/features/villages/grammar/PureVillageCrossRoof.gd")
const Roof = preload("res://scripts/terrain/features/villages/grammar/PureVillageNativeRoof.gd")


static func derive(x_bays: int = 1, z_bays: int = 1, choices: Dictionary = {}) -> Array[Dictionary]:
	var parts := CrossRoof.derive(x_bays, z_bays)
	var walls: Array[Dictionary] = []
	for end: int in [-1, 1]:
		for side: int in [-1, 1]:
			var yaw := 0.0 if side == 1 else PI
			var kind := "End" if end * side == 1 else "Start"
			if end == -1 and side == -1:
				kind = "End"
			var x := end * 4.5 + (.125 if end == 1 and side == -1 else 0.0)
			Roof._emit(
				walls,
				"Wall_%s_30x30_1" % kind,
				Vector3(x + end * (x_bays - 1) * 3, 0, side * 3.0),
				yaw
			)
			for bay in range(x_bays - 1):
				Roof._emit(
					walls,
					"Wall_Middle1_30x30_1",
					Vector3(end * (4.5 + bay * 3), 0, side * 3.0),
					yaw
				)
			# X gable facade consists of two native corner panels.
			Roof._emit(
				walls,
				"Wall_%s_30x30_1" % ("Start" if end * side == 1 else "End"),
				Vector3(end * (x_bays * 3.0 + 3), 0, side * 1.5),
				end * PI / 2
			)
			walls.back()["gable_socket"] = true
			# The short-verge facades inherit the authored front/back seat.
			Roof._emit(
				walls,
				"Wall_%s_30x30_1" % ("End" if end * side == 1 else "Middle1"),
				Vector3(side * 1.5, 0, end * (z_bays * 3.0 + (1.5 if end == 1 else 1.375))),
				0.0 if end == 1 else PI
			)
			walls.back()["gable_socket"] = true
			walls.back()["owns_corner"] = end * side == 1
			var at := Vector3(side * 3.0, 0, end * 3.0)
			if side == -1 and end == -1:
				at.z -= .0361557006835938
			Roof._emit(
				walls,
				"Wall_%s_15x30_1" % ("Start" if end * side == 1 else "End"),
				at,
				side * PI / 2
			)
			for bay in range(1, z_bays):
				Roof._emit(
					walls,
					"Wall_Middle1_30x30_1",
					Vector3(side * 3.0, 0, end * (3 + bay * 3)),
					side * PI / 2
				)
	var slots: Dictionary = {}
	var corner_posts: Array[Dictionary] = []
	for index in walls.size():
		var part: Dictionary = walls[index]
		part.transform.origin.x -= .125
		if part.module == "Wall_Middle1_30x30_1" or part.has("gable_socket"):
			var middle: bool = part.module == "Wall_Middle1_30x30_1"
			var slot := ("middle/%d" if middle else "gable/%d") % index
			slots[slot] = true
			part.facade_slot = slot
			var selected: String = choices.get(slot, part.module)
			assert(
				selected in [part.module, "Window_1_2", "Window_12_2", "Door_3_1"],
				"Incompatible middle-bay opening"
			)
			assert(
				middle or selected != "Door_3_1",
				"Doors use middle bays; retain corner-return ownership"
			)
			if selected != part.module and part.get("owns_corner", false):
				# This end bay owns the short wing's outer post. Its adjacent
				# half-bay has no post there. Replace that ownership explicitly.
				var post := Transform3D(
					Basis.from_scale(Vector3(1.2, 1, 1.2)), Vector3(1.5, 1.493916869, 0)
				)
				corner_posts.append(
					{
						"module": "Wood_Beam_3x30_2",
						"transform": part.transform * post,
						"corner_for": slot
					}
				)
			part.module = selected
	for slot in choices:
		assert(slots.has(slot), "Cannot replace a corner or return panel")
	parts.append_array(walls)
	parts.append_array(corner_posts)
	return parts


static func instantiate(
	x_bays: int = 1, z_bays: int = 1, choices: Dictionary = {}, foundation: bool = false
) -> Node3D:
	var root := Node3D.new()
	var parts := derive(x_bays, z_bays, choices)
	if foundation:
		parts.append_array(
			(
				preload(
					"res://scripts/terrain/features/villages/grammar/PureVillageCrossFoundation.gd"
				)
				. derive(parts, x_bays, z_bays)
			)
		)
	for part in parts:
		var instance: Node3D = load(Roof.MODULE_ROOT + part.module + ".glb").instantiate()
		root.add_child(instance)
		instance.transform = part.transform
	return root


static func sample(seed_value: int, x_bays: int = 1, z_bays: int = 1) -> Dictionary:
	var slots: Array[String] = []
	var door_slots: Array[String] = []
	for part in derive(x_bays, z_bays):
		if part.has("facade_slot"):
			slots.append(part.facade_slot)
			if String(part.facade_slot).begins_with("middle/"):
				door_slots.append(part.facade_slot)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var door: String = door_slots[rng.randi_range(0, door_slots.size() - 1)]
	var family := "Window_1_2" if rng.randf() < .5 else "Window_12_2"
	var choices: Dictionary = {}
	for index in slots.size():
		choices[slots[index]] = "Door_3_1" if slots[index] == door else family
	return choices


static func gable_details(shell: Array[Dictionary]) -> Array[Dictionary]:
	# WindowSolo_6 is the pack's surface-mounted round gable window (House_1
	# and House_9). This peak has a lower tie beam: seat the complete frame
	# above it, with glass ahead of the plaster and clear of the roof verge.
	var out: Array[Dictionary] = []
	for part in shell:
		if part.module != "Wall_Peak_30x30_1":
			continue
		out.append(
			{
				"module": "WindowSolo_6",
				"transform":
				(
					part.transform
					* Transform3D(Basis.from_scale(Vector3.ONE * .77019), Vector3(0, 1.45, .25))
				),
				"role": &"gable_window"
			}
		)
	return out
