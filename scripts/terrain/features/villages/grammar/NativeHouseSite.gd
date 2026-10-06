extends RefCounted
## Door-owned world-space siting contract for the native compound family.
## Source modules are never loaded here: worker planning uses catalog bounds.
const House = preload("res://scripts/terrain/features/villages/grammar/PureVillageCrossHouse.gd")
const Foundation = preload(
	"res://scripts/terrain/features/villages/grammar/PureVillageCrossFoundation.gd"
)
const Compiler = preload("res://scripts/terrain/features/villages/grammar/NativeGrammarCompiler.gd")
## Clear standing space beyond the measured lowest tread, in world metres.
const ARRIVAL_MARGIN := .75


static func cross(
	catalog: EnvironmentCatalog,
	x_bays: int,
	z_bays: int,
	seed_value: int,
	world_scale: float,
	arrival: Vector3,
	outward: Vector3
) -> Dictionary:
	var result := {"ok": false, "reason": ""}
	if (
		not arrival.is_finite()
		or not outward.is_finite()
		or absf(outward.y) > .0001
		or not is_equal_approx(outward.length(), 1.0)
	):
		result.reason = "invalid_entrance_frame"
		return result
	if world_scale != 1.0 and world_scale != 2.0:
		result.reason = "unsupported_entry_scale"
		return result
	if x_bays < 1 or x_bays > 4 or z_bays < 1 or z_bays > 4:
		result.reason = "unsupported_bay_count"
		return result
	var parts := House.derive(x_bays, z_bays, House.sample(seed_value, x_bays, z_bays))
	parts.append_array(House.gable_details(parts))
	var foundation := Foundation.derive(parts, x_bays, z_bays, world_scale)
	parts.append_array(foundation)
	return _place(catalog, parts, foundation, world_scale, arrival, outward)


static func street(
	catalog: EnvironmentCatalog,
	bays: int,
	seed_value: int,
	world_scale: float,
	arrival: Vector3,
	outward: Vector3,
	rear_jetty: bool = false
) -> Dictionary:
	if bays < 2 or bays > 6:
		return {"ok": false, "reason": "unsupported_bay_count"}
	if world_scale != 1.0 and world_scale != 2.0:
		return {"ok": false, "reason": "unsupported_entry_scale"}
	var family = preload(
		"res://scripts/terrain/features/villages/grammar/PureVillageStreetHouse.gd"
	)
	var parts: Array[Dictionary] = family.derive(bays, family.sample(seed_value, bays), rear_jetty)
	var foundation: Array[Dictionary] = []
	for part in parts:
		if part.transform.origin.y < 0:
			foundation.append(part)
		if String(part.module).begins_with("Door_"):
			var stair := {
				"module": "Stone_Stair_11" if world_scale == 2.0 else "Stone_Stair_2",
				"transform":
				(
					part.transform
					* Transform3D(Basis.from_scale(Vector3.ONE / world_scale), Vector3(0, -1.5, .1))
				),
				"entry_for": "front"
			}
			foundation.append(stair)
	# Foundation courses are already authored by the street-house rule.
	# The last foundation course need not be the entry stair.
	for part in foundation:
		if part.has("entry_for"):
			parts.append(part)
	return _place(catalog, parts, foundation, world_scale, arrival, outward)


static func _place(
	catalog: EnvironmentCatalog,
	parts: Array[Dictionary],
	foundation: Array[Dictionary],
	world_scale: float,
	arrival: Vector3,
	outward: Vector3
) -> Dictionary:
	var result := {"ok": false, "reason": ""}
	if (
		not arrival.is_finite()
		or not outward.is_finite()
		or absf(outward.y) > .0001
		or not is_equal_approx(outward.length(), 1.0)
	):
		return {"ok": false, "reason": "invalid_entrance_frame"}
	var door := Transform3D.IDENTITY
	var entry := {}
	for part in parts:
		if String(part.module).begins_with("Door_"):
			door = part.transform
		if part.has("entry_for"):
			entry = part
	if entry.is_empty():
		result.reason = "missing_entry"
		return result
	# The start of the path is beyond the real stair bounds, not beyond the
	# building centre or an assumed 2 m module. This works for any sampled door.
	var stair := catalog.descriptor(Compiler.asset_id(entry.module))
	if stair == null:
		result.reason = "missing_entry_asset"
		return result
	var local_stair: AABB = door.affine_inverse() * entry.transform * stair.measured_aabb
	var local_arrival := door * Vector3(0, -1.5, local_stair.end.z + ARRIVAL_MARGIN / world_scale)
	var turn := atan2(outward.x, outward.z) - atan2(door.basis.z.x, door.basis.z.z)
	var basis := Basis(Vector3.UP, turn).scaled(Vector3.ONE * world_scale)
	var pose := Transform3D(basis, arrival - basis * local_arrival)
	var bounds := AABB()
	var bearing: Array[AABB] = []
	for index in parts.size():
		var part: Dictionary = parts[index]
		var descriptor := catalog.descriptor(Compiler.asset_id(part.module))
		if descriptor == null:
			result.reason = "missing_baked_module:%s" % part.module
			return result
		var box: AABB = pose * part.transform * descriptor.measured_aabb
		bounds = box if index == 0 else bounds.merge(box)
	# Conservative contact outlines for terrain grading. Keep them separate:
	# filling the overall bounding rectangle would fill the compound's notches.
	for part in foundation:
		var descriptor := catalog.descriptor(Compiler.asset_id(part.module))
		var box: AABB = pose * part.transform * descriptor.measured_aabb
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
		"envelope": bounds,
		"bearing_bounds": bearing,
		"arrival": arrival,
		"outward": outward,
		"door": pose * door,
		# The closed door remains collision geometry. This endpoint stands on
		# its exterior top tread, matching the actual-character entry probe.
		"entry_route": [arrival, pose * door * Vector3(0, 0, .4)],
		"ground_y": arrival.y,
		"world_scale": world_scale,
	}
