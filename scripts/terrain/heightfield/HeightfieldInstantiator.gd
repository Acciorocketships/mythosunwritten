class_name HeightfieldInstantiator
extends RefCounted

## Turns the heightfield plan into placement records and (Task 3) real tiles.
## A placement record is {variant_tag, family, world_x, world_z, origin_y, yaw}.

## Build the neighbour-height dictionaries (socket name -> surface height) for a cell.
static func _neighbour_heights(plan: HeightfieldPlan, cx: int, cz: int) -> Array:
	var cardinals: Dictionary = {}
	var diagonals: Dictionary = {}
	for off in HeightfieldFacing.OFFSET_TO_SOCKET.keys():
		var socket_name: String = HeightfieldFacing.OFFSET_TO_SOCKET[off]
		var h: float = plan.surface_height(cx + off.x, cz + off.y)
		if off.x == 0 or off.y == 0:
			cardinals[socket_name] = h
		else:
			diagonals[socket_name] = h
	return [cardinals, diagonals]


## One placement record per cell in the (2*place_radius+1)^2 block around (cx,cz).
static func placements(plan: HeightfieldPlan, cx: int, cz: int, place_radius: int) -> Array:
	var out: Array = []
	for dz in range(-place_radius, place_radius + 1):
		for dx in range(-place_radius, place_radius + 1):
			out.append(placement_for_cell(plan, cx + dx, cz + dz))
	return out


## The placement record for a single cell.
static func placement_for_cell(plan: HeightfieldPlan, cx: int, cz: int) -> Dictionary:
	var tp: Dictionary = plan.tile_plan(cx, cz)
	var h0: float = float(tp["height"])
	var nb: Array = _neighbour_heights(plan, cx, cz)
	var desc: Dictionary = HeightfieldVariant.cell_descriptor(
		h0, int(tp["storey"]), int(tp["level"]), nb[0], nb[1]
	)
	return {
		"variant_tag": desc["variant_tag"],
		"family": desc["family"],
		"world_x": float(cx) * HeightfieldPlan.TILE,
		"world_z": float(cz) * HeightfieldPlan.TILE,
		"origin_y": float(desc["origin_y"]),
		"yaw": HeightfieldFacing.yaw_for_rotation_steps(int(desc["rotation_steps"])),
	}
