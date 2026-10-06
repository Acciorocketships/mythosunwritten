extends RefCounted
## Native 3 m ridge-bay grammar, measured from House_1. Not a 2 m kit adapter.
## A derivation contains dimensions/datums; every dependent closure follows them.
## Production integration waits for the complete building/envelope grammar.
const MODULE_ROOT := "res://assets/PureVillage/Models/Architecture/"
const BAY := 3.0
const UPPER_RUN := 1.5
const UPPER_RISE := 3.0
const PANEL_SEAT := 0.125
const GABLE_PIVOT := 0.125


static func derive(bays: int, wall_top: float) -> Array[Dictionary]:
	assert(bays >= 1 and bays <= 8, "Native roof supports one to eight ridge bays")
	var parts: Array[Dictionary] = []
	var half_length := bays * BAY * 0.5
	var seam := wall_top + UPPER_RISE + PANEL_SEAT
	for side: int in [-1, 1]:
		var yaw := 0.0 if side == 1 else PI
		for bay in bays:
			var x := -half_length + (bay + 0.5) * BAY
			for course in ["Base", "Curved"]:
				_emit(parts, "Roof_%s_30x30_1" % course, Vector3(x, seam, side * UPPER_RUN), yaw)
		for end: int in [-1, 1]:
			# Start/end are local to each roof plane, so swap on its opposite side.
			var cap := "Start" if end * side == -1 else "End"
			for course in ["Base", "Curved"]:
				_emit(
					parts,
					"Roof_%s_%s_5x30_1" % [course, cap],
					Vector3(end * half_length, seam, side * UPPER_RUN),
					yaw
				)
	for bay in bays:
		_emit(
			parts,
			"Roof_Top30_Start_x30_1",
			Vector3(-half_length + (bay + 0.5) * BAY, seam + UPPER_RISE, 0),
			0
		)
	for end: int in [-1, 1]:
		_emit(
			parts,
			"Roof_Top30_%s_x5_1" % ("Start" if end == -1 else "End"),
			Vector3(end * half_length, seam + UPPER_RISE, 0),
			0
		)
		# The source gable interface has a 125 mm axial pivot offset. Both end
		# planes use that offset; mirroring the translation creates a seam error.
		var x := end * half_length + GABLE_PIVOT
		for half in ["Start", "End"]:
			_emit(
				parts, "Wall_CutBendDown_%s_30x30_3" % half, Vector3(x, wall_top, 0), end * PI * 0.5
			)
			_emit(
				parts,
				"Wall_Cut_%s_15x30_3" % half,
				Vector3(x, wall_top + UPPER_RISE, 0),
				end * PI * 0.5
			)
	return parts


static func _emit(parts: Array[Dictionary], module: String, at: Vector3, yaw: float) -> void:
	parts.append({"module": module, "transform": Transform3D(Basis(Vector3.UP, yaw), at)})


static func instantiate(bays: int, wall_top: float) -> Node3D:
	var root := Node3D.new()
	for part: Dictionary in derive(bays, wall_top):
		var module := (
			(load(MODULE_ROOT + part.module + ".glb") as PackedScene).instantiate() as Node3D
		)
		root.add_child(module)
		module.transform = part.transform
	return root
