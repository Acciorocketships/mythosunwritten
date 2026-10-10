extends RefCounted
## Four native valley corners own the junction; arms extend in whole 3 m bays.
## Includes the authored gable interfaces. Host walls/floors remain an obligation.
const Roof = preload("res://scripts/terrain/features/villages/grammar/PureVillageNativeRoof.gd")


static func derive(x_bays: int = 1, z_bays: int = 1, seam: float = 6.125) -> Array[Dictionary]:
	assert(x_bays >= 1 and x_bays <= 4 and z_bays >= 1 and z_bays <= 4)
	var parts: Array[Dictionary] = []
	for corner: Vector2 in [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var yaw := atan2(corner.x, corner.y) + PI / 4
		for module in ["Roof_Base_InCorner_15x15_1", "Roof_Curved_InCorner_30x30x15_1"]:
			Roof._emit(parts, module, Vector3(corner.x * 1.5, seam, corner.y * 1.5), yaw)
	for axis in 2:
		var count := x_bays if axis == 0 else z_bays
		for end: int in [-1, 1]:
			for side: int in [-1, 1]:
				var yaw := (0.0 if side == 1 else PI) if axis == 0 else side * PI / 2
				for bay in range(1, count + 1):
					var at := Vector3(end * bay * 3.0, seam, side * 1.5)
					if axis == 1:
						at = Vector3(side * 1.5, seam, end * bay * 3.0)
					Roof._emit(parts, "Roof_Base_30x30_1", at, yaw)
					if end * side == 1:
						parts[-1].transform.basis = parts[-1].transform.basis.scaled_local(
							Vector3(-1, 1, 1)
						)
					# The core curved corner already supplies the first lower bay.
					if bay > 1:
						Roof._emit(parts, "Roof_Curved_30x30_1", at, yaw)
				var cap := "Start" if end * side == (-1 if axis == 0 else 1) else "End"
				var edge := end * (count * 3.0 + 1.5)
				var at := (
					Vector3(edge, seam, side * 1.5)
					if axis == 0
					else Vector3(side * 1.5, seam, edge)
				)
				for course in ["Base", "Curved"]:
					Roof._emit(
						parts,
						"Roof_%s_%s_%sx30_1" % [course, cap, "15" if axis == 0 else "5"],
						at,
						yaw
					)
			var ridge_yaw := 0.0 if axis == 0 else -end * PI / 2
			for bay in range(1, count + 1):
				var at := (
					Vector3(end * bay * 3.0, seam + 3, 0)
					if axis == 0
					else Vector3(0, seam + 3, end * bay * 3.0)
				)
				Roof._emit(parts, "Roof_Top30_Start_x30_1", at, ridge_yaw)
			var edge := end * (count * 3.0 + 1.5)
			var at := Vector3(edge, seam + 3, 0) if axis == 0 else Vector3(0, seam + 3, edge)
			Roof._emit(
				parts,
				(
					"Roof_Top30_%s_x%s_1"
					% ["Start" if axis == 0 and end == -1 else "End", "15" if axis == 0 else "5"]
				),
				at,
				ridge_yaw
			)
			if axis == 1:
				Roof._emit(
					parts, "Roof_Top30_Start_x10", Vector3(0, seam + 3, end * 1.5), ridge_yaw
				)
				parts[-1].transform.basis = parts[-1].transform.basis.scaled_local(
					Vector3(.7641580700874329, 1, 1)
				)
	Roof._emit(parts, "Roof_Top30_Start_x30_1", Vector3(0, seam + 3, 0), 0)
	# The long X verge seats its gable at the cap end. The short Z verge
	# seats the lower front half 125 mm ahead of its upper peak, as authored.
	var wall_top := seam - 3.125
	for axis in 2:
		var count := x_bays if axis == 0 else z_bays
		for end: int in [-1, 1]:
			var yaw := end * PI / 2 if axis == 0 else (0.0 if end == 1 else PI)
			var distance := count * 3.0 + (3.0 if axis == 0 else 1.375)
			var peak := (
				Vector3(end * distance, wall_top + 3, 0)
				if axis == 0
				else Vector3(0, wall_top + 3, end * distance)
			)
			var lower := peak - Vector3.UP * 3
			if axis == 1 and end == 1:
				lower.z += .125
			for half in ["Start", "End"]:
				Roof._emit(parts, "Wall_CutBendDown_%s_30x30_1" % half, lower, yaw)
			Roof._emit(parts, "Wall_Peak_30x30_1", peak, yaw)
	_attic_sides(parts, x_bays, z_bays, wall_top)
	for part in parts:
		part.transform.origin.x -= .125
	return parts


static func _attic_sides(
	parts: Array[Dictionary], x_bays: int, z_bays: int, wall_top: float
) -> void:
	for end: int in [-1, 1]:
		for side: int in [-1, 1]:
			var yaw := 0.0 if side == 1 else PI
			var kind := "End" if end * side == 1 else "Start"
			var x := end * 4.5
			if end == -1 and side == -1:
				kind = "End"
			if end == 1 and side == -1:
				kind = "Middle1"
				x += .125
			Roof._emit(
				parts,
				"Wall_%s_30x10_1" % kind,
				Vector3(x + end * (x_bays - 1) * 3, wall_top, side * 3.0),
				yaw
			)
			for bay in range(x_bays - 1):
				Roof._emit(
					parts,
					"Wall_Middle1_30x10_1",
					Vector3(end * (4.5 + bay * 3), wall_top, side * 3.0),
					yaw
				)
			# Short returns have opposite handedness on diagonally opposing
			# corners. Start pieces pivot at the far end, End at the valley.
			var start := end * side == 1
			var z := end * (4.5 if start else 3.0)
			var at := Vector3(side * 3.0, wall_top, z)
			if side == -1 and end == -1:
				at.z -= .036163330078125
			Roof._emit(
				parts,
				"Wall_%s_15x10_1" % ("Start" if start else "End"),
				at,
				-end * PI / 2 if start else side * PI / 2
			)
			if start:
				parts[-1].transform.basis = parts[-1].transform.basis.scaled_local(
					Vector3(1, 1, -1)
				)
			for bay in range(1, z_bays):
				Roof._emit(
					parts,
					"Wall_Middle1_30x10_1",
					Vector3(side * 3.0, wall_top, end * (3 + bay * 3)),
					side * PI / 2
				)


static func instantiate(x_bays: int = 1, z_bays: int = 1) -> Node3D:
	var root := Node3D.new()
	for part in derive(x_bays, z_bays):
		var instance: Node3D = load(Roof.MODULE_ROOT + part.module + ".glb").instantiate()
		root.add_child(instance)
		instance.transform = part.transform
	return root
