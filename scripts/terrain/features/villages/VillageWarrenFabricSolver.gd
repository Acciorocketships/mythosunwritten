class_name VillageWarrenFabricSolver
extends RefCounted

## Production adapter for the seeded volumetric warren. It aligns the maze's
## actual boundary landing to the road, samples immutable terrain into the same
## 1.5 m vertical lattice, then rebuilds the selected topology attempt against
## those bands before materializing any geometry.
const DATUM_GUARD := 0.08
const MAX_TERRAIN_RELIEF := VillageUrbanFabricPlan.MAX_FABRIC_TERRAIN_RELIEF
const SUPPORT_STEP := 3.0
const CLEARANCE_MARGIN := 1.5
const WALK_HALF_THICKNESS := 0.10
const GUARD_HALF_WIDTH := 0.10
const GUARD_HEIGHT := 1.5
const _CARDINAL_QUARTERS := 4


static func solve(terrain: VillageTerrainView, city_seed: int,
		stable_id: StringName, centre: Vector2, street_axis: Vector2,
		program: VillageProgram) -> VillageUrbanFabricPlan:
	assert(terrain != null and not stable_id.is_empty() and centre.is_finite())
	assert(street_axis.is_normalized() and program != null)
	if program.settlement_fabric_program == null:
		return _rejected(&"fabric_program")
	var preview := WarrenVolumetricSolver.solve(city_seed, {},
		program.settlement_fabric_program)
	if preview == null:
		return _rejected(StringName("volume_%s" %
			WarrenVolumetricSolver.last_failure))
	var preview_fabric := WarrenSpatialFabricCompiler.solve(preview,
		program.settlement_fabric_program)
	if preview_fabric == null:
		return _rejected(StringName("fabric_%s" %
			WarrenSpatialFabricCompiler.last_failure))
	for placement: Dictionary in _placement_candidates(terrain, preview,
			centre, street_axis, city_seed):
		var spatial := preview if bool(placement.flat_ground) \
			else WarrenVolumetricSolver.solve_selected(city_seed, preview,
				placement.ground_bands as Dictionary,
				program.settlement_fabric_program)
		if spatial == null:
			continue
		var preview_entry := preview.source_volume.entry_cell
		var built_entry := spatial.source_volume.entry_cell
		if Vector2i(preview_entry.x, preview_entry.z) \
				!= Vector2i(built_entry.x, built_entry.z):
			continue
		var fabric := preview_fabric if spatial == preview \
			else WarrenSpatialFabricCompiler.solve(spatial,
				program.settlement_fabric_program)
		if fabric == null:
			continue
		placement["local_bounds"] = _local_bounds(fabric)
		return _materialize(terrain, stable_id, spatial, fabric, placement, program)
	return _rejected(&"terrain_footprint")


static func _placement_candidates(terrain: VillageTerrainView,
		preview: WarrenSpatialPlan, centre: Vector2, street_axis: Vector2,
		city_seed: int) -> Array[Dictionary]:
	var volume := preview.source_volume
	var entry := volume.entry_cell
	var entry_local := Vector3(float(entry.x) \
		* WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M \
		+ FabricRecipe.CELL_SIZE * 0.5,
		float(entry.y) * WarrenVolumePlan.VERTICAL_BAND_SIZE_M,
		float(entry.z) * WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M \
		+ FabricRecipe.CELL_SIZE * 0.5)
	var route_delta := volume.primary_itinerary[1] - entry
	var local_inward := Vector3(float(route_delta.x), 0.0,
		float(route_delta.z)).normalized()
	var world_inward := Vector3(street_axis.x, 0.0, street_axis.y)
	var candidates: Array[Dictionary] = []
	for quarter in _CARDINAL_QUARTERS:
		var yaw := float(quarter) * PI * 0.5
		var basis := Basis(Vector3.UP, yaw)
		var rotated_entry := basis * entry_local
		var datum_y := terrain.surface_y(centre) + DATUM_GUARD \
			- entry_local.y
		var world_frame := Transform3D(basis,
			Vector3(centre.x - rotated_entry.x, datum_y,
				centre.y - rotated_entry.z))
		var terrain_sample := _sample_ground_bands(terrain, volume.envelope,
			world_frame)
		if terrain_sample.is_empty() or bool(terrain_sample.wet):
			continue
		var minimum_y := float(terrain_sample.minimum_y)
		var maximum_y := float(terrain_sample.maximum_y)
		if maximum_y - minimum_y > MAX_TERRAIN_RELIEF:
			continue
		var landing_y := terrain.surface_y(centre)
		var entry_band := int((terrain_sample.ground_bands as Dictionary).get(
			Vector2i(entry.x, entry.z), entry.y))
		var entrance_lift := datum_y \
			+ float(entry_band) * WarrenVolumePlan.VERTICAL_BAND_SIZE_M \
			- landing_y
		if entrance_lift < 0.0 \
				or entrance_lift > TraversalEnvelope.MAX_PLANNED_STEP:
			continue
		var tie := posmod(Helper._mix64(city_seed ^ quarter * 0x45d9f3b),
			0x7fffffff)
		var alignment := (basis * local_inward).dot(world_inward)
		candidates.append({
			"quarter": quarter,
			"yaw": yaw,
			"datum_y": datum_y,
			"minimum_y": minimum_y,
			"maximum_y": maximum_y,
			"entrance_lift": entrance_lift,
			"ground_bands": terrain_sample.ground_bands,
			"flat_ground": _all_zero(terrain_sample.ground_bands as Dictionary),
			# The first maze segment should carry the village route into the mass.
			# Terrain support then decides between equally aligned frames.
			"score": (1.0 - alignment) * 10000.0
				+ entrance_lift * 1000.0
				+ (maximum_y - minimum_y) * 100.0,
			"tie": tie,
			"transform": world_frame,
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.score) < float(b.score) \
			if not is_equal_approx(float(a.score), float(b.score)) \
			else int(a.tie) < int(b.tie))
	return candidates


static func _materialize(terrain: VillageTerrainView, stable_id: StringName,
		spatial: WarrenSpatialPlan, fabric: SettlementFabricPlan,
		placement: Dictionary,
		program: VillageProgram) -> VillageUrbanFabricPlan:
	var result := VillageUrbanFabricPlan.new()
	result.generation_kind = \
		VillageUrbanFabricPlan.GenerationKind.VOLUMETRIC_WARREN
	result.fabric_plan = fabric
	result.fabric_audit = fabric.audit.duplicate(true)
	result.volumetric_spatial = spatial
	result.terrain_entrance_lift_m = float(placement.entrance_lift)
	result.terrain_relief_m = float(placement.maximum_y) \
		- float(placement.minimum_y)
	var world_frame := placement.transform as Transform3D
	result.world_transform = world_frame
	var local_payload := SettlementFabricAssembler.payload(fabric)
	local_payload.append_from(SettlementFabricAssembler.production_surface_bundle(
		fabric.surface_plan))
	local_payload.append_from(SettlementFabricAssembler.low_retaining_payload(fabric))
	local_payload.append_from(
		SettlementFabricAssembler.terrace_retaining_payload(fabric))
	_append_ground_supports(local_payload, terrain, fabric, world_frame)
	for asset_id: StringName in local_payload.asset_ids():
		var batch := local_payload.batches[asset_id] as Dictionary
		for index in batch.transforms.size():
			var local_transform := batch.transforms[index] as Transform3D
			var local_instance_id := StringName(batch.ids[index]) \
				if not batch.ids.is_empty() else StringName("anonymous.%d" % index)
			result.entries.append({
				"asset_id": asset_id,
				"transform": world_frame * local_transform,
				"stable_id": StringName("%s/%s" % [stable_id,
					String(local_instance_id)]),
			})
	for mesh: Dictionary in local_payload.surface_meshes:
		result.surface_meshes.append(_world_surface_mesh(mesh, world_frame,
			stable_id))
	var local_bounds := placement.local_bounds as AABB
	var local_centre := Vector3(local_bounds.get_center().x, 0.0,
		local_bounds.get_center().z)
	var world_centre3 := world_frame * local_centre
	var horizontal_size := Vector2(local_bounds.size.x,
		local_bounds.size.z)
	var yaw := float(placement.yaw)
	var district_id := StringName("%s.warren" % stable_id)
	var district_centre := Vector2(world_centre3.x, world_centre3.z)
	_append_typed_occupancy(result, fabric, world_frame, district_id, yaw)
	result.clearances.append(FeatureGroundShape.oriented_rect(
		district_centre, horizontal_size * 0.5 + Vector2.ONE * CLEARANCE_MARGIN,
		yaw, 0, 0, StringName("%s.clearance" % district_id)))
	# Ground-level cells retain the canonical path paint beneath their plank
	# modules.  Upper cells are deliberately absent from the 2D ground field.
	for cell: Vector3i in fabric.surface_plan.cells_for_kind(
			PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET):
		var world3 := world_frame * (Vector3(cell) * FabricRecipe.CELL_SIZE)
		result.surfaces.append(FeatureGroundShape.oriented_rect(
			Vector2(world3.x, world3.z),
			Vector2.ONE * FabricRecipe.CELL_SIZE * 0.5, yaw,
			FeatureGroundField.WORN_PATH, VillagePlan.SURFACE_PRIORITY,
			StringName("%s.ground.%d.%d" % [district_id, cell.x, cell.z])))
	var top_y := world_frame.origin.y + local_bounds.end.y
	result.volumes.append(VillageOccupancyVolume.new(
		VillageOccupancy.Role.GROUND_EXCLUSIVE, district_centre,
		horizontal_size * 0.5 + Vector2.ONE * CLEARANCE_MARGIN, yaw,
		float(placement.minimum_y) - SUPPORT_STEP, top_y,
		StringName("%s.exclusive" % district_id), district_id))
	for building: WarrenBuildingVolume in spatial.buildings:
		result.buildings.append({
			"stable_id": StringName("%s/%s" % [district_id, building.stable_id]),
			"volumetric": true,
		})
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.kind != &"prefab_landmark":
			continue
		result.buildings.append({
			"stable_id": StringName("%s/%s" % [district_id, feature.stable_id]),
			"volumetric": true,
			"prefab_landmark": true,
		})
	result.entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.stable_id) < String(b.stable_id))
	result.accepted = true
	result.reason = &"accepted"
	assert(result.validate(program, &"village"),
		"volumetric production failed its sealed materialization contract")
	return result


static func _world_surface_mesh(mesh: Dictionary, world_frame: Transform3D,
		stable_id: StringName) -> Dictionary:
	## Bake the rigid town frame into the plain mesh arrays so the streamed
	## payload needs no per-mesh transform channel. Yaw is orthogonal and scale
	## is forbidden, so normals rotate by the basis alone.
	var out := mesh.duplicate(true)
	var vertices := PackedVector3Array()
	for vertex: Vector3 in mesh.vertices as PackedVector3Array:
		vertices.append(world_frame * vertex)
	var normals := PackedVector3Array()
	for normal: Vector3 in mesh.normals as PackedVector3Array:
		normals.append((world_frame.basis * normal).normalized())
	var collision := PackedVector3Array()
	for face_point: Vector3 in mesh.collision_faces as PackedVector3Array:
		collision.append(world_frame * face_point)
	out["vertices"] = vertices
	out["normals"] = normals
	out["collision_faces"] = collision
	out["anchor"] = world_frame * (mesh.get("anchor", Vector3.ZERO) as Vector3)
	out["stable_id"] = StringName("%s/%s" % [stable_id,
		StringName(mesh.get("stable_id", ""))])
	return out


static func _append_typed_occupancy(result: VillageUrbanFabricPlan,
		fabric: SettlementFabricPlan, world_frame: Transform3D,
		district_id: StringName, yaw: float) -> void:
	## Preserve the sealed fabric's semantic cells in the production occupancy
	## index. The former single district box was sufficient to exclude a second
	## settlement but discarded the very solid/walk/headroom distinctions that
	## make future extensions safe. These cell volumes are an adapter over the
	## canonical plan, just like the render payload; they do not infer geometry.
	var walk_network_id := StringName("%s.public" % district_id)
	_append_cell_volumes(result, fabric.transformed_cells(&"solid"),
		VillageOccupancy.Role.SOLID, world_frame, district_id,
		walk_network_id, yaw)
	var walk_cells: Dictionary = {}
	for kind in PublicRealmSurfacePlan.SurfaceKind.size():
		for cell: Vector3i in fabric.surface_plan.cells_for_kind(kind):
			walk_cells[cell] = true
	_append_cell_volumes(result, walk_cells,
		VillageOccupancy.Role.WALK_SURFACE, world_frame, district_id,
		walk_network_id, yaw)
	var headroom_cells := fabric.transformed_cells(&"headroom")
	for cell: Vector3i in fabric.volume_plan.exterior_air_cells:
		headroom_cells[cell] = true
	_append_cell_volumes(result, headroom_cells,
		VillageOccupancy.Role.HEADROOM, world_frame, district_id,
		walk_network_id, yaw)
	for segment: Dictionary in fabric.surface_plan.guard_segments:
		var local_a := segment.a as Vector3
		var local_b := segment.b as Vector3
		var local_delta := local_b - local_a
		var local_centre := (local_a + local_b) * 0.5
		var world_centre := world_frame * local_centre
		var local_angle := atan2(-local_delta.z, local_delta.x)
		result.volumes.append(VillageOccupancyVolume.new(
			VillageOccupancy.Role.WALK_GUARD,
			Vector2(world_centre.x, world_centre.z),
			Vector2(local_delta.length() * 0.5, GUARD_HALF_WIDTH),
			yaw + local_angle, world_centre.y,
			world_centre.y + GUARD_HEIGHT,
			StringName("%s.guard.%s" % [district_id,
				StringName(segment.stable_key)]), district_id,
			walk_network_id))


static func _append_cell_volumes(result: VillageUrbanFabricPlan,
		cells: Dictionary, role: int, world_frame: Transform3D,
		district_id: StringName, walk_network_id: StringName,
		yaw: float) -> void:
	var half_cell := FabricRecipe.CELL_SIZE * 0.5
	# Coalesce identical-role voxels before entering the bucketed occupancy
	# index. This retains exact cell coverage while avoiding a quadratic
	# transaction check over hundreds of one-cell prisms.
	var boxes := _coalesced_cell_boxes(cells,
		role != VillageOccupancy.Role.WALK_SURFACE)
	for box: Dictionary in boxes:
		var minimum := box.minimum as Vector3i
		var maximum := box.maximum as Vector3i
		var local_centre := (Vector3(minimum) + Vector3(maximum)) * 0.5 \
			* FabricRecipe.CELL_SIZE
		var world_centre := world_frame * local_centre
		var cell_count := maximum - minimum + Vector3i.ONE
		var y_min := world_frame.origin.y \
			+ float(minimum.y) * FabricRecipe.CELL_SIZE - half_cell
		var y_max := world_frame.origin.y \
			+ float(maximum.y) * FabricRecipe.CELL_SIZE + half_cell
		if role == VillageOccupancy.Role.WALK_SURFACE:
			y_min = world_centre.y - WALK_HALF_THICKNESS
			y_max = world_centre.y + WALK_HALF_THICKNESS
		result.volumes.append(VillageOccupancyVolume.new(role,
			Vector2(world_centre.x, world_centre.z),
			Vector2(float(cell_count.x), float(cell_count.z)) * half_cell,
			yaw, y_min, y_max,
			StringName("%s.cells.%d.%d.%d.%d.%d.%d.%d" % [district_id,
				role, minimum.x, minimum.y, minimum.z, maximum.x,
				maximum.y, maximum.z]), district_id,
			walk_network_id if role in [VillageOccupancy.Role.WALK_SURFACE,
				VillageOccupancy.Role.WALK_GUARD] else &""))


static func _coalesced_cell_boxes(cells: Dictionary,
		allow_vertical_merge: bool) -> Array[Dictionary]:
	## Greedy lexicographic maximal cuboids are deterministic and exactly cover
	## the input set. Walk surfaces deliberately stay one cell thick in Y;
	## merging vertically adjacent landings would reserve a false wall between
	## two legitimate levels.
	var pending := cells.duplicate()
	var boxes: Array[Dictionary] = []
	while not pending.is_empty():
		var ordered: Array[Vector3i] = []
		ordered.assign(pending.keys())
		ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			return a.y < b.y if a.y != b.y else a.z < b.z \
				if a.z != b.z else a.x < b.x)
		var minimum := ordered[0]
		var maximum := minimum
		while pending.has(Vector3i(maximum.x + 1, minimum.y, minimum.z)):
			maximum.x += 1
		var next_z := maximum.z + 1
		while _box_plane_present(pending, minimum.x, maximum.x,
				next_z, next_z, minimum.y):
			maximum.z = next_z
			next_z += 1
		if allow_vertical_merge:
			var next_y := maximum.y + 1
			while _box_plane_present(pending, minimum.x, maximum.x,
					minimum.z, maximum.z, next_y):
				maximum.y = next_y
				next_y += 1
		for y in range(minimum.y, maximum.y + 1):
			for z in range(minimum.z, maximum.z + 1):
				for x in range(minimum.x, maximum.x + 1):
					pending.erase(Vector3i(x, y, z))
		boxes.append({"minimum": minimum, "maximum": maximum})
	return boxes


static func _box_plane_present(cells: Dictionary, minimum_x: int,
		maximum_x: int, minimum_z: int, maximum_z: int, y: int) -> bool:
	for z in range(minimum_z, maximum_z + 1):
		for x in range(minimum_x, maximum_x + 1):
			if not cells.has(Vector3i(x, y, z)):
				return false
	return true


static func _append_ground_supports(payload: EnvironmentInstancePayload,
		terrain: VillageTerrainView, fabric: SettlementFabricPlan,
		world_frame: Transform3D) -> void:
	## The local review scene's y=0 is real terrain in production.  When the
	## conservative datum lifts a plank, fixed 3 m posts continue down until the
	## lowest post is buried; no post is stretched to fit an arbitrary gap.
	var support_cells: Dictionary = {}
	var solids := fabric.transformed_cells(&"solid")
	for kind in [PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET,
			PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT]:
		for cell: Vector3i in fabric.surface_plan.cells_for_kind(kind):
			support_cells[cell] = true
	var lowest_bearing_y := _lowest_bearing_y_by_column(solids, support_cells)
	var ordered: Array[Vector3i] = []
	ordered.assign(support_cells.keys())
	ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return a.x < b.x if a.x != b.x else a.z < b.z)
	for cell: Vector3i in ordered:
		if fabric.surface_plan.has_support_base(cell) \
				and cell.y - fabric.surface_plan.support_base_at(cell) == 1:
			continue
		# Boundary-biased sparse supports keep alleys open while visibly carrying
		# broad ground decks.  Interior cells supported by four neighbours do
		# not need a redundant post forest.
		var neighbors := 0
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			neighbors += int(support_cells.has(cell + direction))
		# Retain roughly one stack per three exposed 1.5 m modules. Thin winding
		# paths turn often; forcing a post at every geometric corner would make
		# almost every route cell a support and erase the lower alleys.
		if neighbors >= 4 \
				or posmod(cell.x * 17 + cell.y * 13 + cell.z * 31, 3) != 0:
			continue
		if int(lowest_bearing_y.get(Vector2i(cell.x, cell.z), cell.y)) < cell.y:
			continue
		var local_point := Vector3(cell) * FabricRecipe.CELL_SIZE
		var world_point3 := world_frame * local_point
		var terrain_y := terrain.surface_y(Vector2(world_point3.x,
			world_point3.z))
		var drop := world_point3.y - terrain_y
		if drop <= TraversalEnvelope.MAX_PLANNED_STEP:
			continue
		var segment_count := ceili(drop / SUPPORT_STEP)
		for segment in segment_count:
			var local_y := local_point.y - float(segment + 1) * SUPPORT_STEP
			payload.add(SettlementFabricAssembler.TIMBER_SUPPORT,
				Transform3D(Basis.IDENTITY,
					Vector3(local_point.x, local_y, local_point.z)),
				Color.WHITE, StringName("terrain-support/%d/%d/%d/%d" % [
					cell.x, cell.y, cell.z, segment]))


static func _lowest_bearing_y_by_column(solids: Dictionary,
		surface_cells: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for source: Dictionary in [solids, surface_cells]:
		for cell_value: Variant in source.keys():
			var cell := cell_value as Vector3i
			var column := Vector2i(cell.x, cell.z)
			if not out.has(column) or cell.y < int(out[column]):
				out[column] = cell.y
	return out


static func _local_bounds(fabric: SettlementFabricPlan) -> AABB:
	var bounds := AABB()
	var initialized := false
	for unit: FabricUnit in fabric.units:
		if not initialized:
			bounds = unit.bounds
			initialized = true
		else:
			bounds = bounds.merge(unit.bounds)
	for kind in PublicRealmSurfacePlan.SurfaceKind.size():
		for cell: Vector3i in fabric.surface_plan.cells_for_kind(kind):
			var centre := Vector3(cell) * FabricRecipe.CELL_SIZE
			var cell_bounds := AABB(centre - Vector3.ONE \
				* FabricRecipe.CELL_SIZE * 0.5,
				Vector3.ONE * FabricRecipe.CELL_SIZE)
			bounds = cell_bounds if not initialized else bounds.merge(cell_bounds)
			initialized = true
	assert(initialized)
	return bounds


static func _sample_ground_bands(terrain: VillageTerrainView,
		envelope: WarrenVolumeEnvelope, world_frame: Transform3D) -> Dictionary:
	var bands: Dictionary = {}
	var minimum_y := INF
	var maximum_y := -INF
	var half_sample := WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M * 0.45
	for column_value: Variant in envelope.height_bands.keys():
		var column := column_value as Vector2i
		var local_centre := Vector3(
			float(column.x) * WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M
				+ FabricRecipe.CELL_SIZE * 0.5,
			0.0,
			float(column.y) * WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M
				+ FabricRecipe.CELL_SIZE * 0.5)
		var column_max := -INF
		for offset: Vector2 in [Vector2.ZERO,
				Vector2(-half_sample, -half_sample),
				Vector2(half_sample, -half_sample),
				Vector2(-half_sample, half_sample),
				Vector2(half_sample, half_sample)]:
			var world3 := world_frame * (local_centre \
				+ Vector3(offset.x, 0.0, offset.y))
			var point := Vector2(world3.x, world3.z)
			if terrain.is_wet(point):
				return {"wet": true}
			var height := terrain.surface_y(point)
			minimum_y = minf(minimum_y, height)
			maximum_y = maxf(maximum_y, height)
			column_max = maxf(column_max, height)
		bands[column] = ceili((column_max - world_frame.origin.y) \
			/ WarrenVolumePlan.VERTICAL_BAND_SIZE_M)
	return {
		"wet": false,
		"ground_bands": bands,
		"minimum_y": minimum_y,
		"maximum_y": maximum_y,
	}


static func _all_zero(values: Dictionary) -> bool:
	for value: Variant in values.values():
		if int(value) != 0:
			return false
	return true


static func _rejected(reason: StringName) -> VillageUrbanFabricPlan:
	var result := VillageUrbanFabricPlan.new()
	result.generation_kind = \
		VillageUrbanFabricPlan.GenerationKind.VOLUMETRIC_WARREN
	result.reason = reason
	return result
