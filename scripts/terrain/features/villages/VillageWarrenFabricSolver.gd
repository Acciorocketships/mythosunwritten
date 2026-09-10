class_name VillageWarrenFabricSolver
extends RefCounted

## Production adapter for the seeded volumetric warren. One town is generated
## on its construction datum and placed with its primary gate facing the road.
## Its finite grade patch is published before final terrain sampling.
const DATUM_GUARD := VillageWorldScale.GROUND_DATUM_GUARD
const MAX_TERRAIN_RELIEF := VillageUrbanFabricPlan.MAX_FABRIC_TERRAIN_RELIEF \
	* VillageWorldScale.PRODUCTION_UNIFORM_SCALE
const SUPPORT_STEP := 3.0
const CLEARANCE_MARGIN := 1.5
const WALK_HALF_THICKNESS := 0.10
const GUARD_HALF_WIDTH := 0.10
const GUARD_HEIGHT := 1.5
const TERRAIN_HANDOFF_LIFT := 0.025
const TERRAIN_HANDOFF_SUPPORT_EPSILON := 0.005
const OPTIONAL_FRONTAGE_GROUND_TOLERANCE := 0.12
const OPTIONAL_FRONTAGE_MAX_DROP := TraversalEnvelope.MAX_PLANNED_STEP
const _CARDINAL_QUARTERS := 4


static func solve(terrain: VillageTerrainView, city_seed: int,
		stable_id: StringName, centre: Vector2, street_axis: Vector2,
		program: VillageProgram, world_seed: int = 0) -> VillageUrbanFabricPlan:
	assert(terrain != null and not stable_id.is_empty() and centre.is_finite())
	assert(street_axis.is_normalized() and program != null)
	if program.settlement_fabric_program == null:
		return _rejected(&"fabric_program")
	var scale_profile := WarrenVillageScaleProfile.select(city_seed)
	# One-pass generation carves exactly one town per seed: there is no attempt
	# rotation to memo, resume, prove exhausted, or budget a slice of, so the
	# solve is simply run. The persistent solution-pin cache this adapter used
	# to consult died with the search it memoized.
	var preview := WarrenVolumetricSolver.generate(city_seed, {},
		program.settlement_fabric_program, scale_profile)
	if preview == null:
		return _rejected(StringName("volume_%s" %
			WarrenVolumetricSolver.last_failure))
	# Generation owns compilation exactly once. The world adapter only places
	# that construction; a missing result must never trigger another compile.
	var preview_fabric := preview.compiled_fabric_cache()
	if preview_fabric == null:
		return _rejected(StringName("fabric_%s" %
			WarrenSpatialFabricCompiler.last_failure))
	var placement := _placement(terrain, preview, centre, street_axis)
	placement["local_bounds"] = _local_bounds(preview_fabric)
	return _materialize(terrain, stable_id, preview, preview_fabric,
		placement, program, world_seed)


static func _placement(terrain: VillageTerrainView,
		spatial: WarrenSpatialPlan, centre: Vector2,
		street_axis: Vector2) -> Dictionary:
	## The entrance fixes the one world frame. The sealed grade patch adapts
	## terrain to its construction datum; terrain never requests another town.
	var volume := spatial.source_volume
	var entry := volume.entry_cell
	var entry_local := Vector3(float(entry.x) * WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M
		+ FabricRecipe.CELL_SIZE * 0.5,
		float(entry.y) * WarrenVolumePlan.VERTICAL_BAND_SIZE_M,
		float(entry.z) * WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M
		+ FabricRecipe.CELL_SIZE * 0.5)
	var route_delta := volume.primary_itinerary[1] - entry
	var local_inward := Vector3(float(route_delta.x), 0.0,
		float(route_delta.z)).normalized()
	var world_inward := Vector3(street_axis.x, 0.0, street_axis.y)
	var yaw := snappedf(local_inward.signed_angle_to(world_inward, Vector3.UP), PI * 0.5)
	var basis := VillageWorldScale.production_basis(yaw)
	var road_half_local := PathProgram.PATH_HALF_WIDTH \
		/ VillageWorldScale.PRODUCTION_UNIFORM_SCALE
	var contact_local := entry_local - local_inward \
		* (WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M + road_half_local)
	var rotated_contact := basis * contact_local
	var landing_y := terrain.surface_y(centre)
	var datum_y := landing_y + DATUM_GUARD - (basis * entry_local).y
	var world_frame := Transform3D(basis,
		Vector3(centre.x - rotated_contact.x, datum_y, centre.y - rotated_contact.z))
	var sample := _sample_ground_bands(terrain, volume.envelope, world_frame)
	return {
		"quarter": posmod(roundi(yaw / (PI * 0.5)), 4),
		"yaw": yaw, "datum_y": datum_y,
		"minimum_y": sample.minimum_y, "maximum_y": sample.maximum_y,
		"entrance_lift": DATUM_GUARD, "transform": world_frame,
	}


static func _materialize(terrain: VillageTerrainView, stable_id: StringName,
		spatial: WarrenSpatialPlan, fabric: SettlementFabricPlan,
		placement: Dictionary,
		program: VillageProgram, world_seed: int = 0) -> VillageUrbanFabricPlan:
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
	var contact_specs := terrain_contact_specs(spatial, fabric)
	result.terrain_grade = _ground_grade(stable_id, spatial, fabric, world_frame)
	result.world_transform = world_frame
	var local_payload := SettlementFabricAssembler.payload(fabric)
	# TASK I4 ROUND 6, B2. The court's own edge planters are gated on the module
	# boxes the plan really carries, exactly as the garden planting is -- see
	# `maze_courtyard_planter_is_clear`.
	local_payload.append_from(SettlementFabricAssembler.production_surface_bundle(
		fabric.surface_plan,
		SettlementFabricAssembler.maze_module_footprints(fabric),
		SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),
		fabric.planned_plaza_cells))
	local_payload.append_from(SettlementFabricAssembler.low_retaining_payload(fabric))
	local_payload.append_from(
		SettlementFabricAssembler.terrace_retaining_payload(fabric, false))
	var frontage := _terrain_qualified_frontage(terrain, fabric, world_frame)
	result.frontage_sites = frontage.records
	local_payload.append_from(frontage.payload as EnvironmentInstancePayload)
	_append_terrain_bearing_foundations(local_payload, terrain, fabric,
		world_frame)
	_append_ground_supports(local_payload, terrain, fabric, world_frame, contact_specs)
	for asset_id: StringName in local_payload.asset_ids():
		var batch := local_payload.batches[asset_id] as Dictionary
		var collision_flags: Array = batch.get("collision_enabled", [])
		for index in batch.transforms.size():
			var local_transform := batch.transforms[index] as Transform3D
			var world_transform := world_frame * local_transform
			var local_instance_id := StringName(batch.ids[index]) \
				if not batch.ids.is_empty() else StringName("anonymous.%d" % index)
			# TASK I2. THE COLOUR CHANNEL SURVIVES THE CROSSING. `entries` carried
			# asset, transform and id and nothing else, and both consumers
			# (`VillagePlan._materialize_urban_fabric` and the review harness's
			# production commit) then wrote `Color.WHITE` -- so the payload's own
			# instance colour was dropped between the assembler and the renderer,
			# and every tint the fabric asks for reached the game as white.
			#
			# The garden turf is the casualty that FOUND this: rendered raw, the
			# KayKit grass swatch is the pale "lime plate" the direction retired,
			# and the tint that fixes it is the payload's. But it is not the
			# only casualty and not the oldest one -- `_append_courtyard_paving`
			# (SettlementFabricAssembler.gd:2617, colours at :2631) has always
			# passed real colours, the weathered-board checker
			# (`Color("b9c1b8")` against `Color("c8b79d")`), on both adapters,
			# and `test_settlement_fabric.gd`'s "courtyard paving must differ
			# visibly" has pinned the two-tone the whole time. This crossing
			# flattened THAT to white in-game too, for the pipeline's entire
			# life, so the fix below RESTORES a designed, tested feature; it
			# does not only switch one on for the first time. Defaulted to
			# WHITE on read, so the timber, stair and outskirts channels that
			# set no colour are byte-identical.
			#
			# Nothing in today's corpus exercises that restoration: every
			# planner town's `source_courtyard_macro_cell_count` is 0 and both
			# big scale groups audit `elevated_courtyards: 0`, so no sealed
			# town builds an elevated court and the checker has not rendered in
			# a single reviewed frame. The first seed that grows one ships a
			# two-tone deck nobody has looked at -- I4's watch list, not closed
			# here.
			var color := batch.colors[index] as Color
			if CliffDressing.is_terrain_skin_asset(asset_id):
				color = CliffDressing.tint_at(world_transform, world_seed)
			result.entries.append({
				"asset_id": asset_id,
				"transform": world_transform,
				"color": color,
				"collision_enabled": collision_flags.is_empty() \
					or bool(collision_flags[index]),
				"stable_id": StringName("%s/%s" % [stable_id,
					String(local_instance_id)]),
			})
	for box: Dictionary in local_payload.collision_boxes:
		result.collision_boxes.append({
			"transform": world_frame * (box.transform as Transform3D),
			"size": box.size as Vector3,
			"stable_id": StringName("%s/%s" % [stable_id,
				String(StringName(box.get("stable_id", &"generated-box")))]),
		})
	for mesh: Dictionary in local_payload.surface_meshes:
		# Ground streets are paint on the edited terrain, not a second floating
		# sheet. Elevated turf and timber keep their structural surface owner.
		if String(mesh.get("stable_id", "")).begins_with("public-terrain-street"):
			continue
		result.surface_meshes.append(_world_surface_mesh(mesh, world_frame,
			stable_id, world_seed))
	var local_bounds := placement.local_bounds as AABB
	var local_centre := Vector3(local_bounds.get_center().x, 0.0,
		local_bounds.get_center().z)
	var world_centre3 := world_frame * local_centre
	var world_scale := VillageWorldScale.scale_of(world_frame)
	var horizontal_size := Vector2(local_bounds.size.x,
		local_bounds.size.z) * world_scale
	var yaw := float(placement.yaw)
	var district_id := StringName("%s.warren" % stable_id)
	var district_centre := Vector2(world_centre3.x, world_centre3.z)
	_append_typed_occupancy(result, fabric, world_frame, district_id, yaw)
	result.clearances.append(FeatureGroundShape.oriented_rect(
		district_centre, horizontal_size * 0.5 \
			+ Vector2.ONE * CLEARANCE_MARGIN * world_scale,
		yaw, 0, 0, StringName("%s.clearance" % district_id)))
	# Ground-level cells retain the canonical path paint beneath their plank
	# modules.  Upper cells are deliberately absent from the 2D ground field.
	for cell: Vector3i in fabric.surface_plan.cells_for_kind(
			PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET):
		var world3 := world_frame * (Vector3(cell) * FabricRecipe.CELL_SIZE)
		result.surfaces.append(FeatureGroundShape.oriented_rect(
			Vector2(world3.x, world3.z),
			Vector2.ONE * VillageWorldScale.WORLD_FINE_CELL_M * 0.5, yaw,
			FeatureGroundField.WORN_PATH, VillagePlan.SURFACE_PRIORITY,
			StringName("%s.ground.%d.%d" % [district_id, cell.x, cell.z])))
	_append_terrain_handoffs(result, contact_specs, district_id)
	var top_y := (world_frame * Vector3(local_centre.x,
		local_bounds.end.y, local_centre.z)).y
	result.volumes.append(VillageOccupancyVolume.new(
		VillageOccupancy.Role.GROUND_EXCLUSIVE, district_centre,
		horizontal_size * 0.5 + Vector2.ONE * CLEARANCE_MARGIN * world_scale, yaw,
		float(placement.minimum_y) - SUPPORT_STEP * world_scale, top_y,
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
	return result


static func _append_terrain_handoffs(result: VillageUrbanFabricPlan,
		contact_specs: Array[Dictionary], district_id: StringName) -> void:
	## Level gates paint ground; raised gates own a flight and lower landing.
	## Both publish their entire approach before outskirts frontage is allocated.
	var scale_value := VillageWorldScale.scale_of(result.world_transform)
	for spec: Dictionary in contact_specs:
		var geometry := terrain_contact_local_geometry(spec)
		var inner: Vector3 = result.world_transform * (geometry.inner_centre as Vector3)
		var outer: Vector3 = result.world_transform * (geometry.outer_centre as Vector3)
		var a := Vector2(inner.x, inner.z)
		var b := Vector2(outer.x, outer.z)
		var centre := (a + b) * 0.5
		var half_extents := Vector2(a.distance_to(b) * 0.5,
			float(geometry.half_width) * scale_value)
		var angle := (b - a).angle()
		var id := StringName("%s.handoff.%s" % [district_id, spec.stable_suffix])
		if bool(geometry.has_stairs):
			var mesh := WarrenTransitionSurfaceBuilder.build_gate_approach(id,geometry)
			result.surface_meshes.append(_world_surface_mesh(mesh,result.world_transform,district_id,0))
			result.entrance_stair_count += 1
			result.volumes.append(VillageOccupancyVolume.new(
				VillageOccupancy.Role.WALK_SURFACE,centre,half_extents,angle,
				minf(inner.y,outer.y)-PublicRealmSurfacePlan.FLOOR_THICKNESS*scale_value,
				maxf(inner.y,outer.y),id,district_id,result.public_walk_network_id))
		# Paint shares the connecting road's width. The two-cell structural
		# aperture still owns its complete clearance and, when raised, its stairs.
		result.surfaces.append(FeatureGroundShape.oriented_rect(centre,
			Vector2(half_extents.x,PathProgram.PATH_HALF_WIDTH), angle, FeatureGroundField.WORN_PATH,
			VillagePlan.SURFACE_PRIORITY, id))
		result.clearances.append(FeatureGroundShape.oriented_rect(centre,
			half_extents, angle, FeatureGroundField.NATURAL, 0,
			StringName("%s.clearance" % id)))
		result.volumes.append(VillageOccupancyVolume.new(
			VillageOccupancy.Role.HEADROOM, centre, half_extents, angle,
			minf(inner.y,outer.y) - DATUM_GUARD, maxf(inner.y,outer.y) + TraversalEnvelope.MIN_HEADROOM,
			id, district_id, result.public_walk_network_id))


static func _terrain_qualified_frontage_payload(terrain: VillageTerrainView,
		fabric: SettlementFabricPlan, world_frame: Transform3D) \
		-> EnvironmentInstancePayload:
	return _terrain_qualified_frontage(terrain, fabric, world_frame).payload \
		as EnvironmentInstancePayload


static func _terrain_qualified_frontage(terrain: VillageTerrainView,
		fabric: SettlementFabricPlan, world_frame: Transform3D) -> Dictionary:
	## Perimeter stalls and props are optional dressing, so their complete
	## measured envelope must fit the immutable terrain before the group exists.
	## This is the same reservation discipline used for outskirts houses: no
	## canopy may be repaired upward after selection, and rejecting a canopy also
	## rejects every stocked-good child derived from that site.
	var retained := fabric.retained_terrace_cells
	var solids := fabric.transformed_cells(&"solid")
	var paved := SettlementFabricAssembler.public_floor_cells(
		fabric.surface_plan)
	var walked := SettlementFabricAssembler.walked_floor_cells(
		fabric.surface_plan)
	var footprints := SettlementFabricAssembler.maze_module_footprints(fabric)
	var skin := SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric)
	var sites := SettlementFabricAssembler.maze_perimeter_frontage_sites(
		retained, solids, paved, walked, fabric.world_seed, skin, footprints)
	var asset_bounds := footprints.get("asset_bounds", {}) as Dictionary
	var accepted: Array[Dictionary] = []
	var records: Array[Dictionary] = []
	for site: Dictionary in sites:
		var asset_id := StringName(site.asset)
		if not asset_bounds.has(asset_id):
			continue
		var local_transform := SettlementFabricAssembler \
			.maze_perimeter_frontage_transform(site)
		var world_transform := world_frame * local_transform
		var world_bounds: AABB = world_frame * (local_transform \
			* (asset_bounds[asset_id] as AABB))
		var footprint := Rect2(Vector2(world_bounds.position.x,
			world_bounds.position.z), Vector2(world_bounds.size.x,
			world_bounds.size.z))
		if not footprint.has_area():
			continue
		var region := terrain.region_covering(footprint)
		var height_range := TerrainSurfaceField.height_bounds(region, footprint)
		var base_y := world_transform.origin.y
		if height_range.y > base_y + OPTIONAL_FRONTAGE_GROUND_TOLERANCE \
				or height_range.x < base_y - OPTIONAL_FRONTAGE_MAX_DROP:
			continue
		accepted.append(site)
		var outward3 := (world_frame.basis \
			* Vector3(site.direction as Vector3i)).normalized()
		records.append({
			"asset": asset_id,
			"transform": world_transform,
			"centre": footprint.get_center(),
			"half_extents": footprint.size * 0.5,
			"height": world_bounds.size.y,
			"outward": Vector2(outward3.x, outward3.z).normalized(),
			"width_cells": (site.cells as Array).size(),
		})
	return {
		"payload": SettlementFabricAssembler.maze_perimeter_frontage_from_sites(
			accepted),
		"records": records,
	}


static func _world_surface_mesh(mesh: Dictionary, world_frame: Transform3D,
		stable_id: StringName, world_seed: int = 0) -> Dictionary:
	## Bake the uniform town frame into the plain mesh arrays so the streamed
	## payload needs no per-mesh transform channel. Uniform scale preserves normal
	## directions, so the transformed basis only needs normalization here.
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
	if bool(mesh.get("terrain_ground", false)):
		var colors := PackedColorArray()
		colors.resize(vertices.size())
		for index in vertices.size():
			# Streamed grass, path paint, cliff skirts, and village terrain
			# surfaces all multiply the shared atlas by the same world-space biome
			# tint. Leaving structural paths white made a handoff change colour at
			# the exact seam even when its vertices were coincident with terrain.
			colors[index] = BiomeRegistry.ground_tint_at(vertices[index], world_seed) \
				if world_seed != 0 else Color.WHITE
		out["colors"] = colors
	out["anchor"] = world_frame * (mesh.get("anchor", Vector3.ZERO) as Vector3)
	out["stable_id"] = StringName("%s/%s" % [stable_id,
		StringName(mesh.get("stable_id", ""))])
	return out


static func terrain_contact_specs(spatial: WarrenSpatialPlan,
		fabric: SettlementFabricPlan) -> Array[Dictionary]:
	## Production maze towns carry explicit, sealed exterior portals. Project
	## those facts onto the finished two-lane fine-grid street and never infer a
	## gate from graph degree: a short interior cul-de-sac is also degree one and
	## the old heuristic put a handoff road straight through its facade. The
	## fallback below remains only for non-maze compatibility fixtures which have
	## no portal provenance.
	var out: Array[Dictionary] = []
	if spatial == null or fabric == null or fabric.surface_plan == null:
		return out
	var street: Dictionary = {}
	for cell: Vector3i in fabric.surface_plan.cells_for_kind(
			PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET):
		street[cell] = true
	if street.is_empty():
		return out
	var maze_source := spatial.source_volume.mass_context.get(
		&"maze_source_plan") as WarrenMazeSourcePlan \
		if spatial.source_volume != null else null
	if maze_source != null:
		# A portal one band above natural ground is a supported public landing,
		# not a terrain-street cell. Its handoff still belongs to that same gate.
		var portal_surfaces := street.duplicate()
		for kind in PublicRealmSurfacePlan.SurfaceKind.size():
			for cell: Vector3i in fabric.surface_plan.cells_for_kind(kind):
				portal_surfaces[cell] = true
		return _explicit_maze_contact_specs(maze_source, portal_surfaces)
	var blocks: Dictionary = {}
	for cell_value: Variant in street.keys():
		var cell := cell_value as Vector3i
		var macro := Vector3i(floori(float(cell.x) * 0.5), cell.y,
			floori(float(cell.z) * 0.5))
		var complete := true
		for dx in 2:
			for dz in 2:
				complete = complete and street.has(Vector3i(
					macro.x * 2 + dx, macro.y, macro.z * 2 + dz))
		if complete:
			blocks[macro] = true
	var ordered_blocks: Array[Vector3i] = []
	ordered_blocks.assign(blocks.keys())
	ordered_blocks.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.z < b.z if a.z != b.z else a.x < b.x)
	var seen: Dictionary = {}
	# The authored entrance remains a semantic boundary even when the finished
	# street immediately bends or widens and therefore has macro degree two.
	# Resolve its outer row from the same source-route fact that seals the spatial
	# plan, then let the graph search below add any later ground arcade exits.
	if spatial.source_volume != null \
			and spatial.source_volume.primary_itinerary.size() >= 2:
		var source := spatial.source_volume
		var entry_macro := source.primary_itinerary[0]
		var route_delta := source.primary_itinerary[1] - entry_macro
		var inward := Vector3i(signi(route_delta.x), 0,
			signi(route_delta.z))
		if absi(inward.x) + absi(inward.z) == 1:
			var outward := -inward
			var lateral := Vector3i(-inward.z, 0, inward.x)
			var boundary_cells: Array[Vector3i] = []
			for lateral_index in 2:
				var cell := Vector3i(
					entry_macro.x * 2 + (1 if outward.x > 0 else 0),
					entry_macro.y,
					entry_macro.z * 2 + lateral_index) \
					if outward.x != 0 else Vector3i(
					entry_macro.x * 2 + lateral_index, entry_macro.y,
					entry_macro.z * 2 + (1 if outward.z > 0 else 0))
				while street.has(cell + outward):
					cell += outward
				boundary_cells.append(cell)
			boundary_cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
				return a.x * lateral.x + a.z * lateral.z \
					< b.x * lateral.x + b.z * lateral.z)
			if boundary_cells.size() == 2 \
					and boundary_cells[0] + lateral == boundary_cells[1]:
				var contact_key := "%s/%s" % [boundary_cells[0], outward]
				seen[contact_key] = true
				out.append({
					"cells": boundary_cells,
					"outward": outward,
					"lateral": lateral,
					"stable_suffix": "entry",
				})
	for macro: Vector3i in ordered_blocks:
		var neighbours: Array[Vector3i] = []
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			if blocks.has(macro + direction):
				neighbours.append(macro + direction)
		if neighbours.size() != 1:
			continue
		var inward_delta := neighbours[0] - macro
		var inward := Vector3i(signi(inward_delta.x), 0,
			signi(inward_delta.z))
		if absi(inward.x) + absi(inward.z) != 1:
			continue
		var outward := -inward
		var lateral := Vector3i(-inward.z, 0, inward.x)
		var boundary_set: Dictionary = {}
		for lateral_index in 2:
			var cell := Vector3i(
				macro.x * 2 + (1 if outward.x > 0 else 0), macro.y,
				macro.z * 2 + lateral_index) if outward.x != 0 else Vector3i(
				macro.x * 2 + lateral_index, macro.y,
				macro.z * 2 + (1 if outward.z > 0 else 0))
			while street.has(cell + outward):
				cell += outward
			if not street.has(cell + outward):
				boundary_set[cell] = true
		var boundary_cells: Array[Vector3i] = []
		boundary_cells.assign(boundary_set.keys())
		boundary_cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			return a.x * lateral.x + a.z * lateral.z \
				< b.x * lateral.x + b.z * lateral.z)
		# A legal two-lane macro street owns exactly one adjacent pair on its
		# outer row. Refuse a partial or widened accident rather than inventing a
		# decorative ramp whose width no topology owns.
		if boundary_cells.size() != 2 \
				or boundary_cells[0].y != boundary_cells[1].y \
				or boundary_cells[0] + lateral != boundary_cells[1]:
			continue
		var contact_key := "%s/%s" % [boundary_cells[0], outward]
		if seen.has(contact_key):
			continue
		seen[contact_key] = true
		out.append({
			"cells": boundary_cells,
			"outward": outward,
			"lateral": lateral,
			"stable_suffix": "%d.%d.%d" % [macro.x, macro.y, macro.z],
		})
	return out


static func _explicit_maze_contact_specs(source: WarrenMazeSourcePlan,
		street: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if source == null or not source.is_sealed() or source.excavation == null:
		return out
	var public: Dictionary = {}
	for cell: Vector3i in source.excavation.public_cells():
		public[cell] = true
	for portal_index in source.excavation.portals.size():
		var portal := source.excavation.portals[portal_index]
		var outward := _explicit_portal_outward(source, portal, public)
		if absi(outward.x) + absi(outward.z) != 1:
			continue
		var boundary_cells: Array[Vector3i] = []
		for across in 2:
			var cell := Vector3i(
				portal.x * 2 + (1 if outward.x > 0 else 0), portal.y,
				portal.z * 2 + across) if outward.x != 0 else Vector3i(
				portal.x * 2 + across, portal.y,
				portal.z * 2 + (1 if outward.z > 0 else 0))
			if street.has(cell):
				boundary_cells.append(cell)
		if boundary_cells.size() != 2:
			continue
		# Positive-Z for an X-facing row and positive-X for a Z-facing row give
		# the exact adjacent pair in increasing fine-cell order. Geometry needs
		# only a consistent tangent; it does not attach semantics to handedness.
		var lateral := Vector3i.BACK if outward.x != 0 else Vector3i.RIGHT
		boundary_cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			return a.x * lateral.x + a.z * lateral.z \
				< b.x * lateral.x + b.z * lateral.z)
		if boundary_cells[0] + lateral != boundary_cells[1] \
				or street.has(boundary_cells[0] + outward) \
				or street.has(boundary_cells[1] + outward):
			continue
		out.append({
			"cells": boundary_cells,
			"outward": outward,
			"lateral": lateral,
			"stable_suffix": "entry" if portal_index == 0 \
				else "gate.%02d" % portal_index,
			"source_portal": portal,
			"ground_band": source.massif.base_at(Vector2i(portal.x,portal.z)),
		})
	return out


static func _explicit_portal_outward(source: WarrenMazeSourcePlan,
		portal: Vector3i, public: Dictionary) -> Vector3i:
	## Prefer the direction in which the authored walk actually reaches the
	## massif edge. At a corner two sides can be exterior; checking the approach
	## first keeps the camera, road, and facade opening on the intended side.
	var intended := Vector3i.ZERO
	var excavation := source.excavation
	if portal == excavation.route[0] and excavation.route.size() >= 2:
		intended = portal - excavation.route[1]
	elif portal == excavation.route[-1] and excavation.route.size() >= 2:
		intended = portal - excavation.route[-2]
	else:
		for lane_value: Variant in excavation.lanes:
			var lane := lane_value as Dictionary
			var cells := lane.get("cells", []) as Array[Vector3i]
			if cells.is_empty() or cells[-1] != portal:
				continue
			var previous := lane.get("anchor", Vector3i.ZERO) as Vector3i \
				if cells.size() == 1 else cells[-2]
			intended = portal - previous
			break
	intended = Vector3i(signi(intended.x), 0, signi(intended.z))
	var exterior: Array[Vector3i] = []
	for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
		var outward := Vector3i(direction.x, 0, direction.y)
		if WarrenPassageLatticeRules.exterior_approach_is_clear(source.massif,portal,direction):
			exterior.append(outward)
	if intended in exterior:
		return intended
	for outward: Vector3i in exterior:
		if public.has(portal - outward):
			return outward
	return exterior[0] if not exterior.is_empty() else Vector3i.ZERO


static func terrain_contact_local_geometry(spec: Dictionary) -> Dictionary:
	## Convert one topology-owned pair of fine cells into its complete approach.
	## PublicRealmSurfacePlan indexes cells by their centres (`cell * 1.5 m`),
	## not by their lower corners. Keeping this conversion beside the contact
	## solver prevents the rendered handoff and the outskirts road from acquiring
	## independent half-cell phases.
	var boundary_cells := spec.get("cells", []) as Array[Vector3i]
	var outward := spec.get("outward", Vector3i.ZERO) as Vector3i
	var lateral := spec.get("lateral", Vector3i.ZERO) as Vector3i
	assert(boundary_cells.size() == 2)
	assert(absi(outward.x) + absi(outward.z) == 1)
	assert(absi(lateral.x) + absi(lateral.z) == 1)
	var street_centre := Vector3.ZERO
	for cell: Vector3i in boundary_cells:
		street_centre += Vector3(cell) * FabricRecipe.CELL_SIZE
	street_centre /= float(boundary_cells.size())
	var inner_centre := street_centre + Vector3(outward) \
		* FabricRecipe.CELL_SIZE * 0.5
	var ground_y := float(spec.get("ground_band",boundary_cells[0].y)) * FabricRecipe.CELL_SIZE
	var rise := inner_centre.y - ground_y
	var stair_end := inner_centre
	if not is_zero_approx(rise):
		# A raised portal is an architectural landing. Reserve a complete flight
		# before frontage allocation; never force its elevation into fine ground
		# controls beside lower rooms. The ordinary ground field stays continuous.
		stair_end += Vector3(outward) * maxf(WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M,absf(rise)*2.0)
		stair_end.y = ground_y
	return {
		"street_centre": street_centre,
		"inner_centre": inner_centre,
		"stair_end": stair_end,
		"has_stairs": not is_zero_approx(rise),
		"outer_centre": stair_end + Vector3(outward) \
			* FabricRecipe.CELL_SIZE,
		"half_width": FabricRecipe.CELL_SIZE \
			* float(boundary_cells.size()) * 0.5,
	}




static func _append_typed_occupancy(result: VillageUrbanFabricPlan,
		fabric: SettlementFabricPlan, world_frame: Transform3D,
		district_id: StringName, yaw: float) -> void:
	## Preserve the sealed fabric's semantic cells in the production occupancy
	## index. The former single district box was sufficient to exclude a second
	## settlement but discarded the very solid/walk/headroom distinctions that
	## make future extensions safe. These cell volumes are an adapter over the
	## canonical plan, just like the render payload; they do not infer geometry.
	var walk_network_id := StringName("%s.public" % district_id)
	result.public_walk_network_id = walk_network_id
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
		var world_scale := VillageWorldScale.scale_of(world_frame)
		result.volumes.append(VillageOccupancyVolume.new(
			VillageOccupancy.Role.WALK_GUARD,
			Vector2(world_centre.x, world_centre.z),
			Vector2(local_delta.length() * world_scale * 0.5,
				GUARD_HALF_WIDTH * world_scale),
			yaw + local_angle, world_centre.y,
			world_centre.y + GUARD_HEIGHT * world_scale,
			StringName("%s.guard.%s" % [district_id,
				StringName(segment.stable_key)]), district_id,
			walk_network_id))


static func _append_cell_volumes(result: VillageUrbanFabricPlan,
		cells: Dictionary, role: int, world_frame: Transform3D,
		district_id: StringName, walk_network_id: StringName,
		yaw: float) -> void:
	var world_scale := VillageWorldScale.scale_of(world_frame)
	var half_cell := FabricRecipe.CELL_SIZE * world_scale * 0.5
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
			+ float(minimum.y) * VillageWorldScale.WORLD_FINE_CELL_M - half_cell
		var y_max := world_frame.origin.y \
			+ float(maximum.y) * VillageWorldScale.WORLD_FINE_CELL_M + half_cell
		if role == VillageOccupancy.Role.WALK_SURFACE:
			y_min = world_centre.y - WALK_HALF_THICKNESS * world_scale
			y_max = world_centre.y + WALK_HALF_THICKNESS * world_scale
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
		world_frame: Transform3D, contact_specs: Array[Dictionary] = []) -> void:
	## The local review scene's y=0 is real terrain in production.  When the
	## conservative datum lifts a plank, scaled authored posts continue down until the
	## lowest post is buried; no post is stretched to fit an arbitrary gap.
	var approach_boxes: Array[AABB] = []
	for spec: Dictionary in contact_specs:
		var geometry := terrain_contact_local_geometry(spec)
		var inner: Vector3 = geometry.inner_centre
		var outer: Vector3 = geometry.outer_centre
		var lateral := Vector3(spec.lateral) * float(geometry.half_width)
		var box := AABB(inner-lateral,Vector3.ZERO).expand(inner+lateral)
		box = box.expand(outer-lateral).expand(outer+lateral)
		box.size.y += TraversalEnvelope.MIN_HEADROOM / VillageWorldScale.scale_of(world_frame)
		approach_boxes.append(box)
	var support_cells: Dictionary = {}
	var solids := fabric.transformed_cells(&"solid")
	# Supports belong to the same structural-floor kinds that actually emit a
	# raised plank surface. TERRAIN_STREET is paint on the terrain sheet; giving
	# it posts manufactures detached pegs below a floor that does not exist.
	for kind in SettlementFabricAssembler.PAVED_FLOOR_KINDS:
		for cell: Vector3i in fabric.surface_plan.cells_for_kind(kind):
			support_cells[cell] = true
	var lowest_bearing_y := _lowest_bearing_y_by_column(solids, support_cells)
	var walked := SettlementFabricAssembler.walked_floor_cells(
		fabric.surface_plan)
	for anchor: Dictionary in SettlementFabricAssembler \
			.structural_support_anchors(support_cells):
		var owner_cells := anchor.cells as Array[Vector3i]
		var surface_band := (owner_cells[0] as Vector3i).y
		var support_base := 2147483647
		for owner: Vector3i in owner_cells:
			support_base = mini(support_base,
				fabric.surface_plan.support_base_at(owner))
		if surface_band - support_base == 1 \
				or SettlementFabricAssembler._support_anchor_crosses_public_lane(
					anchor.point as Vector3, support_base, surface_band, walked):
			continue
		var borne := false
		for owner: Vector3i in owner_cells:
			borne = borne or int(lowest_bearing_y.get(
				Vector2i(owner.x, owner.z), owner.y)) < owner.y
		if borne:
			continue
		var local_point := anchor.point as Vector3
		var world_point3 := world_frame * local_point
		var terrain_y := terrain.surface_y(Vector2(world_point3.x,
			world_point3.z))
		var drop := world_point3.y - terrain_y
		if drop <= TraversalEnvelope.MAX_PLANNED_STEP:
			continue
		# Exterior gates are compiled after the internal walk mesh. Their sealed
		# approach must nevertheless reserve its standing space before posts are
		# emitted, just as the internal public lanes do above. Test the whole
		# column, including the native timber width, so no floating upper stump remains.
		var local_drop := drop / VillageWorldScale.scale_of(world_frame)
		var column := AABB(local_point-Vector3(0.35,local_drop,0.35),Vector3(0.7,local_drop,0.7))
		var crosses_approach := false
		for approach: AABB in approach_boxes:
			crosses_approach = crosses_approach or approach.intersects(column)
		if crosses_approach:
			continue
		var world_support_step := SUPPORT_STEP \
			* VillageWorldScale.scale_of(world_frame)
		var segment_count := ceili(drop / world_support_step)
		for segment in segment_count:
			var local_y := local_point.y - float(segment + 1) * SUPPORT_STEP
			payload.add(SettlementFabricAssembler.TIMBER_SUPPORT,
				Transform3D(Basis.IDENTITY,
					Vector3(local_point.x, local_y, local_point.z)),
				Color.WHITE, StringName("terrain-support/%d/%d/%d/%d" % [
					int(anchor.x2), surface_band, int(anchor.z2), segment]))


static func _append_terrain_bearing_foundations(
		payload: EnvironmentInstancePayload, terrain: VillageTerrainView,
		fabric: SettlementFabricPlan, world_frame: Transform3D) -> void:
	## A terrain-bearing room promises that its floorplate is carried by the
	## immutable terrain field. On a continuous slope the conservative lattice
	## datum can sit slightly above that field along one exposed facade even when
	## every sampled point remains traversal-valid. Close that visible interval
	## with the same complete authored foundation course used above retained
	## stone. The course is selected from the exact bearing boundary; it is never
	## a post, stretched mesh, or after-the-fact visual offset.
	var bearing := fabric.transformed_cells(&"terrain_bearing")
	if bearing.is_empty():
		return
	var solids := fabric.transformed_cells(&"solid")
	var retained := fabric.retained_terrace_cells
	var ordered: Array[Vector3i] = []
	ordered.assign(bearing.keys())
	ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.z < b.z if a.z != b.z else a.x < b.x)
	for cell: Vector3i in ordered:
		# Retained stone already owns this foundation seam through the canonical
		# plinth transaction. Emitting again would overlap identical courses.
		if retained.has(cell - Vector3i.UP):
			continue
		for direction_index in SettlementFabricAssembler.FACE_DIRECTIONS.size():
			var direction := SettlementFabricAssembler.FACE_DIRECTIONS[
				direction_index]
			if solids.has(cell + direction) or bearing.has(cell + direction):
				continue
			var outward := Vector3(direction)
			var tangent := Vector3(-direction.z, 0.0, direction.x)
			var local_face := Vector3(cell) * FabricRecipe.CELL_SIZE \
				+ outward * FabricRecipe.CELL_SIZE * 0.5
			var floor_world_y := (world_frame * (Vector3(cell) \
				* FabricRecipe.CELL_SIZE)).y
			var minimum_ground_y := INF
			# Complete-edge support, not a centre sample: either terminal can expose
			# a gap on sloping terrain even while the midpoint touches.
			for along in [-0.48, 0.0, 0.48]:
				var probe3 := world_frame * (local_face + tangent \
					* FabricRecipe.CELL_SIZE * float(along))
				minimum_ground_y = minf(minimum_ground_y, terrain.surface_y(
					Vector2(probe3.x, probe3.z)))
			if floor_world_y - minimum_ground_y \
					<= OPTIONAL_FRONTAGE_GROUND_TOLERANCE:
				continue
			# Upper rooms can carry the semantic terrain-bearing tag through an
			# elevated terrace. A single plinth is not a column: if its authored
			# bottom cannot reach the ground, emitting it creates a floating stone
			# box beside the lower roof. Structural terrace supports own that span.
			var course_height := 3.0 * VillageWorldScale.scale_of(world_frame)
			if floor_world_y - minimum_ground_y > course_height \
					+ OPTIONAL_FRONTAGE_GROUND_TOLERANCE:
				continue
			var origin := local_face - outward \
				* SettlementFabricAssembler.STONE_CAP_HALF_DEPTH
			origin.y = float(cell.y) * FabricRecipe.CELL_SIZE - 3.0
			var yaw := PI * 0.5 if direction.x != 0 else 0.0
			payload.add(SettlementFabricAssembler.HOUSE_PLINTH,
				Transform3D(Basis(Vector3.UP, yaw), origin), Color.WHITE,
				StringName("terrain-foundation/%d/%d/%d/%d" % [cell.x,
					cell.y, cell.z, direction_index]))


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


static func _ground_grade(stable_id: StringName, spatial: WarrenSpatialPlan,
		fabric: SettlementFabricPlan, world_frame: Transform3D) -> TerrainGradePatch:
	var heights: Dictionary = {}
	var origin := Vector2(world_frame.origin.x, world_frame.origin.z)
	var pitch := VillageWorldScale.WORLD_FINE_CELL_M
	var envelope := spatial.source_volume.envelope
	# A macro column contains four construction cells, including their half-cell
	# phase. Preserve each column's sealed ground band rather than flattening the
	# whole settlement to one height.
	for column: Vector2i in envelope.ground_bands:
		for dz in 2:
			for dx in 2:
				var cell := Vector3i(column.x * 2 + dx,
					envelope.ground_at(column), column.y * 2 + dz)
				var world := world_frame * (Vector3(cell) * FabricRecipe.CELL_SIZE)
				var key := Vector2i(roundi((world.x - origin.x) / pitch),
					roundi((world.z - origin.y) / pitch))
				heights[key] = world.y - DATUM_GUARD
	for cell: Vector3i in fabric.surface_plan.cells_for_kind(
			PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET):
		var world := world_frame * (Vector3(cell) * FabricRecipe.CELL_SIZE)
		var key := Vector2i(roundi((world.x - origin.x) / pitch),
			roundi((world.z - origin.y) / pitch))
		# The placement frame includes the existing floor/threshold guard. The
		# ground itself must not inherit it or its triangles intersect authored
		# floorboards and the slightly uneven bases of the facade assets.
		heights[key] = world.y - DATUM_GUARD
	# A gate continues the underlying ground outside the public street. Raised
	# landings reach this ground with architectural stairs; promoting their top
	# into these fine controls creates a narrow hump beside lower building bases.
	for spec: Dictionary in terrain_contact_specs(spatial, fabric):
		for boundary: Vector3i in spec.cells:
			var cell := boundary + (spec.outward as Vector3i)
			cell.y = int(spec.get("ground_band",cell.y))
			var world := world_frame * (Vector3(cell) * FabricRecipe.CELL_SIZE)
			var key := Vector2i(roundi((world.x - origin.x) / pitch),
				roundi((world.z - origin.y) / pitch))
			heights[key] = world.y - DATUM_GUARD
	return TerrainGradePatch.new(StringName("%s/terrain-grade" % stable_id),
		heights, origin, pitch)


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
			var height := terrain.surface_y(point)
			minimum_y = minf(minimum_y, height)
			maximum_y = maxf(maximum_y, height)
			column_max = maxf(column_max, height)
		bands[column] = ceili((column_max - world_frame.origin.y) \
			/ VillageWorldScale.WORLD_FINE_CELL_M)
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
