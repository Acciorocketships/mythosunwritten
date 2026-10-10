extends RefCounted
## StreetHouse_8c's recessed ground door owns the address. The approach passes
## under its native arcade; the rear storefront remains private to the parcel.
const House = preload("res://scripts/terrain/features/villages/grammar/PureVillageArcadeHouse.gd")
const Compiler = preload("res://scripts/terrain/features/villages/grammar/NativeGrammarCompiler.gd")
const ARRIVAL_MARGIN := .75


static func place(
	catalog: EnvironmentCatalog,
	upper_storeys: int,
	upper_side_window: String,
	world_scale: float,
	arrival: Vector3,
	outward: Vector3
) -> Dictionary:
	if upper_storeys not in [1, 2] or upper_side_window not in ["", "Window_1_2", "Window_5_2"]:
		return {"ok": false, "reason": "unsupported_derivation"}
	if upper_storeys == 1 and upper_side_window == "Window_5_2":
		return {"ok": false, "reason": "hood_eave_conflict"}
	if world_scale not in [1.0, 2.0]:
		return {"ok": false, "reason": "unsupported_entry_scale"}
	if (
		not arrival.is_finite()
		or not outward.is_finite()
		or absf(outward.y) > .0001
		or not is_equal_approx(outward.length(), 1.0)
	):
		return {"ok": false, "reason": "invalid_entrance_frame"}
	var parts := House.derive(upper_storeys, upper_side_window)
	var entry := {}
	for part in parts:
		if part.module == "Door_2_1" and is_zero_approx(part.transform.origin.y):
			if not entry.is_empty():
				return {"ok": false, "reason": "ambiguous_ground_entry"}
			entry = part
	if entry.is_empty():
		return {"ok": false, "reason": "missing_ground_entry"}
	var door: Transform3D = entry.transform
	var boxes: Array[AABB] = []
	var local_envelope := AABB()
	for part in parts:
		var canonical := Compiler.placement(part.module, part.transform, part.asset_id)
		var descriptor := catalog.descriptor(canonical.asset_id)
		if descriptor == null or descriptor.collision_piece_count == 0:
			return {"ok": false, "reason": "missing_baked_module:%s" % canonical.asset_id}
		var box: AABB = canonical.transform * descriptor.measured_aabb
		local_envelope = box if boxes.is_empty() else local_envelope.merge(box)
		boxes.append(box)
	# Keep the public address beyond the entire roof/arcade envelope. The
	# private straight approach reaches the actual ground door beneath it.
	var reach := 0.0
	for corner in 8:
		reach = maxf(
			reach,
			(local_envelope.get_endpoint(corner) - door.origin).dot(door.basis.z.normalized())
		)
	var local_arrival := (
		door.origin + door.basis.z.normalized() * (reach + ARRIVAL_MARGIN / world_scale)
	)
	var turn := atan2(outward.x, outward.z) - atan2(door.basis.z.x, door.basis.z.z)
	var basis := Basis(Vector3.UP, turn).scaled(Vector3.ONE * world_scale)
	var pose := Transform3D(basis, arrival - basis * local_arrival)
	var bearing: Array[AABB] = []
	var envelope := AABB()
	for index in boxes.size():
		var box: AABB = pose * boxes[index]
		envelope = box if index == 0 else envelope.merge(box)
		if boxes[index].position.y <= .15 and boxes[index].end.y > 0:
			bearing.append(
				AABB(
					Vector3(box.position.x, arrival.y, box.position.z),
					Vector3(box.size.x, 0, box.size.z)
				)
			)
	return {
		"ok": true,
		"reason": "",
		"parts": parts,
		"pose": pose,
		"envelope": envelope,
		"bearing_bounds": bearing,
		"arrival": arrival,
		"outward": outward,
		"door": pose * door,
		"entry_route": [arrival, pose * door * Vector3(0, 0, .4)],
		"ground_y": arrival.y,
		"world_scale": world_scale
	}
