extends RefCounted
## Ground entrance of the complete corner-turret house. Its upper terrace door
## is private; only the ground stair is offered to the town path planner.
const House = preload("res://scripts/terrain/features/villages/grammar/PureVillageTurretHouse.gd")
const Compiler = preload("res://scripts/terrain/features/villages/grammar/NativeGrammarCompiler.gd")
const ARRIVAL_MARGIN := .75


static func place(
	catalog: EnvironmentCatalog,
	extra_upper_storeys: int,
	world_scale: float,
	arrival: Vector3,
	outward: Vector3,
	street_front: bool = false
) -> Dictionary:
	if extra_upper_storeys not in [0, 1]:
		return {"ok": false, "reason": "unsupported_course_count"}
	if world_scale not in [1.0, 2.0]:
		return {"ok": false, "reason": "unsupported_entry_scale"}
	if (
		not arrival.is_finite()
		or not outward.is_finite()
		or absf(outward.y) > .0001
		or not is_equal_approx(outward.length(), 1.0)
	):
		return {"ok": false, "reason": "invalid_entrance_frame"}
	var parts := House.derive(extra_upper_storeys)
	if world_scale == 2.0:
		# Doubling the short flight would double its 0.3 m risers beyond the
		# character's step limit. Use the kit's authored 3 m flight, unscaled
		# in world space, at the same landing joint and width instead.
		for part in parts:
			if part.module == "Stone_Stair_2":
				part.module = "Stone_Stair_11"
				part.asset_id = Compiler.asset_id(part.module)
				part.transform.basis = part.transform.basis.scaled_local(Vector3.ONE / world_scale)
	var door := Transform3D.IDENTITY
	var door_y := INF
	for part in parts:
		if String(part.module).begins_with("Door_") and part.transform.origin.y < door_y:
			door = part.transform
			door_y = door.origin.y
	# The authored entrance has a frontal flight and a side flight sharing a
	# stone landing. Select the frontal flight by orientation, not array order.
	var entry := {}
	var reach := INF
	for part in parts:
		if not String(part.module).begins_with("Stone_Stair_"):
			continue
		var stair_pose: Transform3D = part.transform
		if stair_pose.basis.z.normalized().dot(door.basis.z.normalized()) < .99:
			continue
		var distance := stair_pose.origin.distance_squared_to(door.origin)
		if distance < reach:
			entry = part
			reach = distance
	if entry.is_empty():
		return {"ok": false, "reason": "missing_ground_entry"}
	var descriptor := catalog.descriptor(entry.asset_id)
	if descriptor == null:
		return {"ok": false, "reason": "missing_entry_asset"}
	var stair: Transform3D = entry.transform
	var local_arrival := (
		stair
		* Vector3(
			0,
			0,
			descriptor.measured_aabb.end.z + ARRIVAL_MARGIN / (world_scale * stair.basis.z.length())
		)
	)
	var turn := atan2(outward.x, outward.z) - atan2(stair.basis.z.x, stair.basis.z.z)
	var basis := Basis(Vector3.UP, turn).scaled(Vector3.ONE * world_scale)
	var pose := Transform3D(basis, arrival - basis * local_arrival)
	var envelope := AABB()
	var bearing: Array[AABB] = []
	for index in parts.size():
		var part: Dictionary = parts[index]
		var canonical := Compiler.placement(part.module, part.transform, part.asset_id)
		var stock := catalog.descriptor(canonical.asset_id)
		if stock == null:
			return {"ok": false, "reason": "missing_baked_module:%s" % canonical.asset_id}
		var local_box: AABB = canonical.transform * stock.measured_aabb
		var box: AABB = pose * local_box
		envelope = box if index == 0 else envelope.merge(box)
		# Footings cross the authored ground datum. Their buried bevels remain
		# below the grade; the lowest decorative mesh cannot raise the house.
		if local_box.position.y <= .05 and local_box.end.y > 0:
			bearing.append(
				AABB(
					Vector3(box.position.x, arrival.y, box.position.z),
					Vector3(box.size.x, 0, box.size.z)
				)
			)
	var landing := stair.origin + stair.basis.z.normalized() * .1
	landing.y = door_y
	var result := {
		"ok": true,
		"reason": "",
		"parts": parts,
		"pose": pose,
		"envelope": envelope,
		"bearing_bounds": bearing,
		"arrival": arrival,
		"outward": outward,
		"door": pose * door,
		"entry_route": [arrival, pose * landing, pose * door * Vector3(0, 0, .4)],
		"ground_y": arrival.y,
		"world_scale": world_scale,
	}
	if street_front:
		# The public address sits outside the complete house, including the
		# high corner cap. Preserve the recessed source door and give it a
		# straight private approach; do not clip its forward-reaching turret.
		var reach_out := 0.0
		for corner in 8:
			reach_out = maxf(reach_out, (envelope.get_endpoint(corner) - arrival).dot(outward))
		var shift := -outward * (reach_out + ARRIVAL_MARGIN)
		result.pose.origin += shift
		result.door.origin += shift
		result.envelope.position += shift
		for index in bearing.size():
			bearing[index].position += shift
		var route: Array[Vector3] = [arrival]
		for point: Vector3 in result.entry_route:
			route.append(point + shift)
		result.entry_route = route
	return result
