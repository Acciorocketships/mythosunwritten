extends RefCounted


## Worker-safe bridge from native derivations to the existing environment payload.
## Bounds rejection is conservative: the planner must reserve native overhangs,
## not shrink or clip an assembly after it has been derived.
static func asset_id(module: String) -> StringName:
	return StringName("pure_village.native." + module.to_lower())


static func placement(
	module: String, transform: Transform3D, authored_id: StringName = &""
) -> Dictionary:
	var id := asset_id(module) if authored_id.is_empty() else authored_id
	# MultiMesh does not switch face winding per reflected instance. Bake the
	# reflection into geometry/collision, leaving a positive runtime basis.
	if transform.basis.determinant() < 0:
		# An authored ID can already contain the baked reflection. Reflecting
		# it again restores the original geometry but retains its material binding.
		id = (
			StringName(String(id).trim_suffix(".mirror_x"))
			if String(id).ends_with(".mirror_x")
			else StringName(String(id) + ".mirror_x")
		)
		transform.basis = transform.basis * Basis.from_scale(Vector3(-1, 1, 1))
	return {"asset_id": id, "transform": transform}


static func compile(
	parts: Array[Dictionary],
	catalog: EnvironmentCatalog,
	pose: Transform3D,
	owner: StringName,
	reservation: AABB,
	public_air: Array[AABB] = []
) -> Dictionary:
	var result := {
		"ok": false, "reason": "", "envelope": AABB(), "payload": EnvironmentInstancePayload.new()
	}
	if parts.is_empty() or owner.is_empty() or not pose.is_finite():
		result.reason = "invalid_derivation"
		return result
	var placements: Array[Dictionary] = []
	for index in parts.size():
		var part: Dictionary = parts[index]
		var canonical := placement(part.module, pose * part.transform, part.get("asset_id", &""))
		var id: StringName = canonical.asset_id
		var descriptor := catalog.descriptor(id)
		if descriptor == null or descriptor.collision_piece_count == 0:
			result.reason = "missing_baked_module:%s" % id
			return result
		var transform: Transform3D = canonical.transform
		if not transform.is_finite() or absf(transform.basis.determinant()) < .000001:
			result.reason = "invalid_transform"
			return result
		var bounds: AABB = transform * descriptor.measured_aabb
		if not reservation.encloses(bounds):
			result.reason = "outside_reservation:%s" % id
			return result
		for air in public_air:
			if bounds.intersects(air):
				result.reason = "public_clearance:%s" % id
				return result
		result.envelope = bounds if index == 0 else result.envelope.merge(bounds)
		placements.append(
			{
				"asset_id": id,
				"transform": transform,
				"stable_id": StringName("%s/native.%04d" % [owner, index])
			}
		)
	# Publish only after the complete assembly is validated; never leave a
	# partially emitted house when one roof, return or stair cannot fit.
	for placement in placements:
		result.payload.add(
			placement.asset_id, placement.transform, Color.WHITE, placement.stable_id, true
		)
	result.ok = true
	return result
