class_name FabricModuleProgram
extends RefCounted

## Compiled finite construction vocabulary. Asset-specific declarations stop
## here; recipes and solvers use only generic datum/run/envelope operations.
const CELL := FabricRecipe.CELL_SIZE
const SEAM_EPSILON := 0.001

var _catalog: EnvironmentCatalog
var _contracts: Dictionary = {}
var _sealed := false
var last_rejection := ""


func _init(catalog: EnvironmentCatalog) -> void:
	_catalog = catalog


func add_generic(asset_id: StringName,
		visual_clearance: float = 0.0) -> bool:
	var contract := _contract(asset_id, FabricModuleContract.Kind.GENERIC)
	if contract == null:
		return false
	contract.visual_clearance = visual_clearance
	return _add(contract)


func add_walk_surface(asset_id: StringName,
		visual_clearance: float = 0.0) -> bool:
	var contract := _contract(asset_id, FabricModuleContract.Kind.WALK_SURFACE)
	if contract == null:
		return false
	contract.visual_clearance = visual_clearance
	return _add(contract)


func add_roof_repeat(asset_id: StringName, repeat_axis: Vector3i,
		repeat_pitch: float, pair_axis: Vector3i, pair_offset: float,
		seam_profile: StringName,
		material_family: StringName, visual_clearance: float = 0.0) -> bool:
	var contract := _contract(asset_id, FabricModuleContract.Kind.ROOF_REPEAT)
	if contract == null:
		return false
	contract.repeat_axis = repeat_axis
	contract.repeat_pitch = repeat_pitch
	contract.pair_axis = pair_axis
	contract.pair_offset = pair_offset
	contract.seam_profile = seam_profile
	contract.material_family = material_family
	contract.visual_clearance = visual_clearance
	return _add(contract)


func add_roof_end(asset_id: StringName, seam_profile: StringName) -> bool:
	var contract := _contract(asset_id, FabricModuleContract.Kind.ROOF_END)
	if contract == null:
		return false
	contract.seam_profile = seam_profile
	return _add(contract)


func add_shed_roof(asset_id: StringName, high_edge: Vector3i,
		visual_clearance: float = 0.0) -> bool:
	var contract := _contract(asset_id, FabricModuleContract.Kind.ROOF_SHED)
	if contract == null:
		return false
	contract.shed_high_edge = high_edge
	contract.visual_clearance = visual_clearance
	return _add(contract)


func add_prefab(asset_id: StringName,
		visual_clearance: float = 0.0) -> bool:
	var contract := _contract(asset_id, FabricModuleContract.Kind.PREFAB)
	if contract == null:
		return false
	contract.visual_clearance = visual_clearance
	return _add(contract)


func add_switchback_stair(asset_id: StringName, low_tread_y: float,
		high_tread_y: float, visual_clearance: float = 0.0) -> bool:
	var contract_value := _contract(asset_id,
		FabricModuleContract.Kind.STAIR_SWITCHBACK)
	if contract_value == null:
		return false
	contract_value.stair_low_tread_y = low_tread_y
	contract_value.stair_high_tread_y = high_tread_y
	contract_value.visual_clearance = visual_clearance
	return _add(contract_value)


func seal() -> bool:
	last_rejection = ""
	if _sealed or _catalog == null or _contracts.is_empty():
		last_rejection = "missing catalog or construction contracts"
		return false
	for contract_value: FabricModuleContract in _contracts.values():
		if not contract_value.is_sealed():
			last_rejection = "unsealed module contract %s" % contract_value.asset_id
			return false
	_sealed = true
	return true


func contract(asset_id: StringName) -> FabricModuleContract:
	return _contracts.get(asset_id) as FabricModuleContract


func apply_visual_envelope(recipe: FabricRecipe) -> bool:
	## Compile one conservative construction envelope without leaking asset
	## pivots or descriptor queries into any layout solver.
	if not _sealed or recipe == null or recipe.placements.is_empty():
		return recipe != null
	var envelope := AABB()
	var has_bounds := false
	for placement: Dictionary in recipe.placements:
		var asset_id := StringName(placement.get("asset_id", ""))
		var transform := placement.get("transform", Transform3D()) as Transform3D
		var contract_value := contract(asset_id)
		var asset_bounds := AABB()
		if contract_value != null:
			asset_bounds = contract_value.clearance_bounds()
		else:
			var descriptor := _catalog.descriptor(asset_id)
			if descriptor == null:
				return false
			asset_bounds = descriptor.measured_aabb
		if not asset_bounds.has_volume():
			return false
		var placed_bounds := transform * asset_bounds
		envelope = placed_bounds if not has_bounds else envelope.merge(placed_bounds)
		has_bounds = true
	# Compact continuous roofs publish every finite start/middle/end realization
	# before this envelope is sealed. During layout each provisional bay owns its
	# exact party-seam interval, not both possible exterior eaves: whether a bay is
	# an end is a property of the maximal connected component and does not exist
	# yet. SettlementFabricPlan validates the two realized exterior eaves against
	# every unrelated finished placement after that component is compiled.
	for run: Dictionary in recipe.compact_roof_runs:
		for bay_value: Variant in run.get("bays", []) as Array:
			var bay := bay_value as Dictionary
			for roles_value: Variant in (bay.get("variants", {}) \
					as Dictionary).values():
				for variant_value: Variant in (roles_value as Dictionary).values():
					var variant := variant_value as Dictionary
					var asset_id := StringName(variant.get("asset_id", ""))
					var transform := variant.get("transform", Transform3D()) \
						as Transform3D
					var contract_value := contract(asset_id)
					if contract_value == null \
							or not contract_value.clearance_bounds().has_volume():
						return false
					var placed_bounds := transform \
						* contract_value.clearance_bounds()
					placed_bounds = _compact_roof_party_span_bounds(
						placed_bounds, run)
					if not placed_bounds.has_volume():
						# A half-depth source claim can meet an exterior-role
						# section exactly at its party plane. That role owns no
						# early clearance inside this isolated claim; the original
						# finite half-roof still supplies its provisional envelope,
						# and the final component checks its two real exterior eaves.
						continue
					envelope = placed_bounds if not has_bounds \
						else envelope.merge(placed_bounds)
					has_bounds = true
	return has_bounds and recipe.set_local_clearance_bounds(envelope)


static func _compact_roof_party_span_bounds(bounds: AABB,
		run: Dictionary) -> AABB:
	## The run endpoints are the semantic outer party planes in recipe-local
	## space. Clip only along the ridge; authored transverse eaves and the full
	## height profile remain part of the early construction envelope.
	var start := run.get("local_start", Vector3.INF) as Vector3
	var end := run.get("local_end", Vector3.INF) as Vector3
	var delta := end - start
	var axis_x := absf(delta.x) > 0.001 and absf(delta.z) <= 0.001
	var axis_z := absf(delta.z) > 0.001 and absf(delta.x) <= 0.001
	if not start.is_finite() or not end.is_finite() or not (axis_x or axis_z):
		return AABB()
	var low := minf(start.x, end.x) if axis_x else minf(start.z, end.z)
	var high := maxf(start.x, end.x) if axis_x else maxf(start.z, end.z)
	var clipped_low := maxf(bounds.position.x, low) if axis_x \
		else maxf(bounds.position.z, low)
	var clipped_high := minf(bounds.end.x, high) if axis_x \
		else minf(bounds.end.z, high)
	if clipped_high <= clipped_low:
		return AABB()
	var out := bounds
	if axis_x:
		out.position.x = clipped_low
		out.size.x = clipped_high - clipped_low
	else:
		out.position.z = clipped_low
		out.size.z = clipped_high - clipped_low
	return out


func walk_aligned_transform(asset_id: StringName, pose: Transform3D,
		target_walk_y: float) -> Transform3D:
	var contract_value := contract(asset_id)
	assert(contract_value != null and contract_value.is_sealed())
	assert(contract_value.kind == FabricModuleContract.Kind.WALK_SURFACE)
	# Village construction permits yaw only, so the asset's authored top remains
	# a horizontal plane. Compute through the transformed AABB anyway: a future
	# pivot correction cannot silently reintroduce a threshold step.
	var transformed := pose * contract_value.visual_bounds
	pose.origin.y += target_walk_y - transformed.end.y
	return pose


func facade_aligned_transform(asset_id: StringName, pose: Transform3D,
		outward: Vector3i, boundary: float) -> Transform3D:
	var contract_value := contract(asset_id)
	assert(contract_value != null and contract_value.is_sealed())
	assert(outward.y == 0 and absi(outward.x) + absi(outward.z) == 1)
	var transformed := pose * contract_value.visual_bounds
	if outward.x > 0:
		pose.origin.x += boundary - transformed.end.x
	elif outward.x < 0:
		pose.origin.x += boundary - transformed.position.x
	elif outward.z > 0:
		pose.origin.z += boundary - transformed.end.z
	else:
		pose.origin.z += boundary - transformed.position.z
	return pose


func roof_bearing_aligned_transform(asset_id: StringName, pose: Transform3D,
		target_bearing_y: float) -> Transform3D:
	## Roof imports do not share a trustworthy pivot: most begin at zero, while
	## several complete boarded shells sit a few millimetres below it.  A roof
	## recipe names the wall-top bearing plane, never the source pivot.  Pin the
	## measured lowest visual point to that plane so adjacent roof modules cannot
	## acquire different vertical datums merely because they came from different
	## authored assets.
	var contract_value := contract(asset_id)
	assert(contract_value != null and contract_value.is_sealed())
	var transformed := pose * contract_value.visual_bounds
	pose.origin.y += target_bearing_y - transformed.position.y
	return pose


func shed_roof_aligned_transform(asset_id: StringName,
		target_centre: Vector3, target_bearing_y: float,
		target_high_edge: Vector3i, target_high_boundary: float) -> Transform3D:
	## Rotate the authored high edge toward the wall, then pin that measured edge
	## to the logical wall plane.  The transverse centre and actual lowest visual
	## point are aligned from the same contract.  A shallow roof consequently
	## cannot be inverted or drift off its supporting facade by construction.
	var contract_value := contract(asset_id)
	assert(contract_value != null and contract_value.is_sealed())
	assert(contract_value.kind == FabricModuleContract.Kind.ROOF_SHED)
	assert(target_high_edge.y == 0 and absi(target_high_edge.x) \
		+ absi(target_high_edge.z) == 1)
	var yaw_quarters := -1
	for candidate in 4:
		if FabricRecipe.transform_direction(contract_value.shed_high_edge,
				candidate) == target_high_edge:
			yaw_quarters = candidate
			break
	assert(yaw_quarters >= 0)
	var pose := Transform3D(Basis(Vector3.UP,
		float(yaw_quarters) * PI * 0.5), target_centre)
	var transformed := pose * contract_value.visual_bounds
	if target_high_edge.x != 0:
		pose.origin.z += target_centre.z - transformed.get_center().z
		pose.origin.x += target_high_boundary \
			- (transformed.end.x if target_high_edge.x > 0 \
			else transformed.position.x)
	else:
		pose.origin.x += target_centre.x - transformed.get_center().x
		pose.origin.z += target_high_boundary \
			- (transformed.end.z if target_high_edge.z > 0 \
			else transformed.position.z)
	return roof_bearing_aligned_transform(asset_id, pose, target_bearing_y)


func stair_lane_transforms(asset_id: StringName,
		corridor_minimum_x: int = -1, corridor_width_cells: int = 2) \
		-> Array[Transform3D]:
	## Aligns the authored low terminus and lateral centre from measured bounds.
	## The full Fantasy Village stair spans the whole 3 m public corridor; the
	## small half-rise spans one 1.5 m lane and is therefore repeated once per
	## lane. This is a datum operation, never a scale correction.
	var contract_value := contract(asset_id)
	assert(contract_value != null and contract_value.is_sealed())
	assert(corridor_width_cells > 0)
	var bounds := contract_value.visual_bounds
	var corridor_width := float(corridor_width_cells) * CELL
	var lane_count := corridor_width_cells if bounds.size.x < CELL * 1.25 else 1
	var out: Array[Transform3D] = []
	for lane in lane_count:
		# Lattice coordinates name cell centres. The old +0.5 formulation
		# interpreted them as cell corners and shifted every stair 0.75 m sideways
		# from the public surface that its sockets joined. A repeated narrow asset
		# is centred on each claimed lane; a full-width asset is centred on the
		# arithmetic mean of the first and last claimed cell centres.
		var target_centre_x := (float(corridor_minimum_x) + float(lane)) * CELL \
			if lane_count > 1 else (float(corridor_minimum_x) \
				+ float(corridor_width_cells - 1) * 0.5) * CELL
		out.append(Transform3D(Basis.IDENTITY, Vector3(
			target_centre_x - bounds.get_center().x,
			-bounds.position.y,
			-bounds.end.z)))
	return out


func stair_high_aligned_transform(asset_id: StringName, pose: Transform3D,
		target_high_tread_y: float) -> Transform3D:
	## Pin the actual upper walking tread, never the decorative handrail top, to
	## the destination platform. Village stair transforms permit yaw only, so the
	## authored tread Y remains invariant under the supplied basis.
	var contract_value := contract(asset_id)
	assert(contract_value != null and contract_value.is_sealed())
	assert(contract_value.kind == FabricModuleContract.Kind.STAIR_SWITCHBACK)
	pose.origin.y += target_high_tread_y \
		- (pose.origin.y + contract_value.stair_high_tread_y)
	return pose


func prefab_aligned_transform(asset_id: StringName, pose: Transform3D,
		footprint_minimum: Vector3i, footprint_size: Vector3i,
		target_ground_y: float) -> Transform3D:
	var contract_value := contract(asset_id)
	assert(contract_value != null and contract_value.is_sealed())
	assert(contract_value.kind == FabricModuleContract.Kind.PREFAB)
	var target_centre := footprint_centre(footprint_minimum, footprint_size)
	var transformed := pose * contract_value.visual_bounds
	var visual_centre := transformed.get_center()
	pose.origin += Vector3(target_centre.x - visual_centre.x,
		target_ground_y - transformed.position.y,
		target_centre.z - visual_centre.z)
	return pose


func add_roof_run(recipe: FabricRecipe, run_id: StringName,
		roof_asset: StringName, end_asset: StringName, centre: Vector3,
		base_y: float, yaw_radians: float, run_length: float,
		replacement_assets: Dictionary = {}, emit_negative_end: bool = true,
		emit_positive_end: bool = true) -> bool:
	var repeat := contract(roof_asset)
	var roof_end := contract(end_asset)
	if recipe == null or repeat == null or roof_end == null \
			or repeat.kind != FabricModuleContract.Kind.ROOF_REPEAT \
			or roof_end.kind != FabricModuleContract.Kind.ROOF_END \
			or repeat.seam_profile != roof_end.seam_profile:
		return false
	var repeat_count := roundi(run_length / repeat.repeat_pitch)
	if repeat_count <= 0 or absf(float(repeat_count) * repeat.repeat_pitch \
			- run_length) > SEAM_EPSILON:
		return false
	var basis := Basis(Vector3.UP, yaw_radians)
	var first_seam := -run_length * 0.5
	var placement_ids: Array[StringName] = []
	var pair_direction := basis * Vector3(repeat.pair_axis)
	for index in repeat_count:
		var along := first_seam + (float(index) + 0.5) * repeat.repeat_pitch
		var run_offset := basis * Vector3(repeat.repeat_axis) * along
		var negative_id := StringName("%s.repeat.%02d.negative" % [run_id,
			index])
		var positive_id := StringName("%s.repeat.%02d.positive" % [run_id,
			index])
		var negative_asset := StringName(replacement_assets.get(
			"%d:negative" % index, roof_asset))
		var positive_asset := StringName(replacement_assets.get(
			"%d:positive" % index, roof_asset))
		if contract(negative_asset) == null or contract(positive_asset) == null:
			return false
		var negative_pose := Transform3D(basis.rotated(Vector3.UP, PI),
			Vector3(centre.x, base_y, centre.z) + run_offset
			- pair_direction * repeat.pair_offset)
		var positive_pose := Transform3D(basis,
			Vector3(centre.x, base_y, centre.z) + run_offset
			+ pair_direction * repeat.pair_offset)
		recipe.add_placement(negative_id, negative_asset,
			roof_bearing_aligned_transform(negative_asset, negative_pose, base_y))
		recipe.add_placement(positive_id, positive_asset,
			roof_bearing_aligned_transform(positive_asset, positive_pose, base_y))
		placement_ids.append(negative_id)
		placement_ids.append(positive_id)
	var run_direction := basis * Vector3(repeat.repeat_axis)
	# End walls align by their authored peak datum, not by assuming that two
	# source families share a zero plane. The reviewed S roof and M gable differ
	# by about half a metre at their pivots; aligning both origins produced the
	# conspicuous triangles protruding above every ridge.
	var end_base_y := base_y + repeat.visual_bounds.end.y \
		- roof_end.visual_bounds.end.y
	if emit_negative_end:
		var negative_id := StringName("%s.end.negative" % run_id)
		recipe.add_placement(negative_id, end_asset,
			Transform3D(basis, Vector3(centre.x, end_base_y, centre.z)
				+ run_direction * first_seam))
		placement_ids.append(negative_id)
	if emit_positive_end:
		var positive_id := StringName("%s.end.positive" % run_id)
		recipe.add_placement(positive_id, end_asset,
			Transform3D(basis.rotated(Vector3.UP, PI),
				Vector3(centre.x, end_base_y, centre.z)
				+ run_direction * -first_seam))
		placement_ids.append(positive_id)
	recipe.add_construction_run(run_id, &"roof", placement_ids,
		first_seam, -first_seam, repeat.repeat_pitch, repeat.seam_profile,
		repeat.material_family)
	return true


static func footprint_centre(minimum: Vector3i, size: Vector3i) -> Vector3:
	assert(size.x > 0 and size.y > 0 and size.z > 0)
	return Vector3(
		float(minimum.x) + float(size.x - 1) * 0.5,
		float(minimum.y),
		float(minimum.z) + float(size.z - 1) * 0.5) * CELL


func _contract(asset_id: StringName, kind: FabricModuleContract.Kind) \
		-> FabricModuleContract:
	if _sealed or _catalog == null or asset_id.is_empty():
		return null
	var descriptor := _catalog.descriptor(asset_id)
	if descriptor == null or not descriptor.measured_aabb.has_volume():
		last_rejection = "missing measured descriptor for %s" % asset_id
		return null
	return FabricModuleContract.new(asset_id, kind, descriptor.measured_aabb)


func _add(contract_value: FabricModuleContract) -> bool:
	if contract_value == null or _contracts.has(contract_value.asset_id) \
			or not contract_value.seal():
		last_rejection = "invalid or duplicate construction contract"
		if contract_value != null and not contract_value.last_rejection.is_empty():
			last_rejection = contract_value.last_rejection
		return false
	_contracts[contract_value.asset_id] = contract_value
	return true
