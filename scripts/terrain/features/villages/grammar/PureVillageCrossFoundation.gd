extends RefCounted
## Native foundation course and entry stair derived from the final ground walls.
const Native = preload("res://scripts/terrain/features/villages/grammar/PureVillageNativeRoof.gd")


static func derive(
	shell: Array[Dictionary], x_bays: int, z_bays: int, world_scale: float = 1.0
) -> Array[Dictionary]:
	assert(
		world_scale == 1.0 or world_scale == 2.0,
		"Entry stairs support native or double-scale houses"
	)
	var parts: Array[Dictionary] = []
	for wall in shell:
		if not is_zero_approx(wall.transform.origin.y):
			continue
		var name: String = wall.module
		if not (
			name.begins_with("Wall_") or name.begins_with("Window_") or name.begins_with("Door_")
		):
			continue
		var half := name.contains("15x30")
		var door := name.begins_with("Door_")
		var pose: Transform3D = wall.transform * Transform3D(Basis.IDENTITY, Vector3(0, -1.5, 0))
		if half and name.begins_with("Wall_Start"):
			pose.basis = pose.basis.scaled_local(Vector3(-1, 1, 1))
		parts.append(
			{
				"module":
				(
					"WallStone_BottomEntrance_Middle_15x30"
					if door
					else ("WallStone_Bottom_End_15x15" if half else "WallStone_Bottom_Middle_30x15")
				),
				"transform": pose
			}
		)
		if door:
			(
				parts
				. append(
					{
						# Preserve walkable native risers at both supported house scales.
						# The 3 m stair is used at its authored world size beneath
						# a double-scale house, rather than doubling 0.3 m steps.
						"module": "Stone_Stair_11" if world_scale == 2.0 else "Stone_Stair_2",
						"transform":
						(
							wall.transform
							* Transform3D(
								Basis.IDENTITY.scaled(Vector3.ONE / world_scale),
								Vector3(0, -1.5, .1)
							)
						),
						"entry_for": wall.facade_slot
					}
				)
			)
	# Eight convex footprint corners; reentrant corners are the meeting
	# of the complete straight and half courses, with no redundant corner block.
	for end: int in [-1, 1]:
		for side: int in [-1, 1]:
			var yaw := atan2(end, side) + PI / 4
			Native._emit(
				parts,
				"Stone_Corner_Start_x15",
				Vector3(end * (x_bays * 3.0 + 3) - .125, -1.5, side * 3.0),
				yaw
			)
			Native._emit(
				parts,
				"Stone_Corner_Start_x15",
				Vector3(
					end * 3.0 - .125, -1.5, side * (z_bays * 3.0 + (1.5 if side == 1 else 1.375))
				),
				yaw
			)
	return parts
