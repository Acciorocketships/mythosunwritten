extends RefCounted
## StreetHouse_1 roof family: 3 m wide, native 3 m longitudinal bays, short
## curved cornice, and a one-metre projecting gable supported by long end caps.
## Derives the entire roof course and both closed gables as one assembly.
const NativeRoof = preload(
	"res://scripts/terrain/features/villages/grammar/PureVillageNativeRoof.gd"
)
const BAY := 3.0
const RUN := 1.5
const RISE := 3.0
const PROJECTION := 1.0
const AXIAL_SEAT := .125
const VERTICAL_SEAT := .074167251586914
# Authored ridge end fit for the long (10) projecting verge. This is a fixed
# source socket fit, never adjusted to conceal an arbitrary span mismatch.
const RIDGE_END_SCALE := 1.2650949954986572


static func derive(bays: int, wall_top: float, rear_jetty: bool = false) -> Array[Dictionary]:
	assert(bays >= 1 and bays <= 8)
	var parts: Array[Dictionary] = []
	var half_length := bays * BAY * .5
	var seam := wall_top + VERTICAL_SEAT
	for side: int in [-1, 1]:
		var yaw := side * PI * .5
		for bay in bays:
			var at := Vector3(side * RUN, seam, -half_length + (bay + .5) * BAY + AXIAL_SEAT)
			NativeRoof._emit(parts, "Roof_Base_30x30_1", at, yaw)
			NativeRoof._emit(parts, "Roof_BottomCurved_30x5_1", at, yaw)
		for end: int in [-1, 1]:
			var cap := "Start" if side * end == 1 else "End"
			var width := "10" if end == 1 or rear_jetty else "5"
			var at := Vector3(side * RUN, seam, end * half_length + AXIAL_SEAT)
			NativeRoof._emit(parts, "Roof_Base_%s_%sx30_1" % [cap, width], at, yaw)
			NativeRoof._emit(parts, "Roof_BottomCurved_%s_%sx5_1" % [cap, width], at, yaw)
	for bay in bays:
		NativeRoof._emit(
			parts,
			"Roof_Top30_Start_x30_1",
			Vector3(0, seam + RISE, -half_length + (bay + .5) * BAY + AXIAL_SEAT),
			-PI * .5
		)
	NativeRoof._emit(
		parts,
		"Roof_Top30_Start_x10" if rear_jetty else "Roof_Top30_Start_x5_1",
		Vector3(0, seam + RISE, -half_length + AXIAL_SEAT),
		-PI * .5
	)
	if rear_jetty:
		parts.back().transform.basis = (
			parts.back().transform.basis * Basis.from_scale(Vector3(RIDGE_END_SCALE, 1, 1))
		)
	NativeRoof._emit(
		parts, "Roof_Top30_End_x10_1", Vector3(0, seam + RISE, half_length + AXIAL_SEAT), -PI * .5
	)
	parts.back().transform.basis = (
		parts.back().transform.basis * Basis.from_scale(Vector3(RIDGE_END_SCALE, 1, 1))
	)
	NativeRoof._emit(parts, "Wall_Peak_30x30_1", Vector3(0, wall_top, half_length + PROJECTION), 0)
	NativeRoof._emit(
		parts,
		"Wall_Peak_30x30_1",
		Vector3(0, wall_top, -half_length - (PROJECTION if rear_jetty else 0.0)),
		0
	)
	parts.back().transform.basis = Basis.from_scale(Vector3(1, 1, -1))
	return parts


static func instantiate(bays: int, wall_top: float) -> Node3D:
	var root := Node3D.new()
	for part: Dictionary in derive(bays, wall_top):
		var module: Node3D = (
			(load(NativeRoof.MODULE_ROOT + part.module + ".glb") as PackedScene).instantiate()
		)
		root.add_child(module)
		module.transform = part.transform
	return root
