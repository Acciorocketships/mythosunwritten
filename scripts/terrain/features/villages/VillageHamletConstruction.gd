class_name VillageHamletConstruction
extends RefCounted

## A tiny settlement starts with its shared square, not an inhabited massif.
## Complete native houses use the ordinary measured frontage construction.

## A green square's focal tree (a broad Meadow oak, 14 m).
const FOCAL_TREE := &"meadow.oak.04.summer"

static func solve(terrain: VillageTerrainView, city_seed: int,
		settlement_id: StringName, centre: Vector2, axis: Vector2,
		theme: StringName, program: VillageProgram,
		canonical_ground: FeatureGroundField, world_seed: int = 0) -> VillageUrbanFabricPlan:
	var urban := VillageUrbanFabricPlan.new()
	urban.generation_kind = VillageUrbanFabricPlan.GenerationKind.GROUND_HAMLET
	var count := 3 + posmod(Helper._mix64(city_seed ^ 0x48414D), 4)
	var green := posmod(city_seed, 3) == 0
	var focal_id := FOCAL_TREE if green else &"sfv.well.001" if posmod(city_seed, 2) == 0 \
		else &"sfbp.campfire.001"
	var clearing := focal_id == &"sfbp.campfire.001"
	var radius := 9.0 if count <= 4 else 15.0
	if green:
		radius = maxf(radius, 12.0)
	# A through-road occupies the middle of its frontage. Budget room for houses
	# beside that immutable handoff before selecting the square, never erase a
	# road after discovering it intersects a small lot.
	var nearby_domain: FeatureGroundShape = square_topology(settlement_id,
		centre, axis, radius, 0.0, green).domain
	if not VillageOutskirtsConstruction._world_road_handoffs(nearby_domain,
			canonical_ground, settlement_id).is_empty():
		radius = 18.0
	var datum := terrain.surface_y(centre)
	urban.world_transform.origin = Vector3(centre.x,
		datum + VillageWarrenFabricSolver.DATUM_GUARD, centre.y)
	urban.public_walk_network_id = StringName("%s.square.walk" % settlement_id)
	var cells: Dictionary = {}
	var half_cells := ceili(radius / VillageOutskirtsConstruction.PITCH)
	for z in range(-half_cells, half_cells + 1):
		for x in range(-half_cells, half_cells + 1):
			cells[Vector2i(x, z)] = datum
	urban.terrain_grade = TerrainGradePatch.new(
		StringName("%s.square.grade" % settlement_id), cells, centre,
		VillageOutskirtsConstruction.PITCH)
	# Reserve the actual, uniformly scaled civic solid before the common lot
	# allocator runs. Its walking circuit clears that same complete footprint.
	var local_box: AABB = program.runtime_aabbs[focal_id]
	var pose := Transform3D(Basis.IDENTITY,
		Vector3(centre.x, datum - local_box.position.y, centre.y))
	if not green:
		pose = (program.prop_assets[focal_id] as VillagePropSpec).placement_for(centre, axis, datum)
		if focal_id == &"sfv.well.001":
			pose.basis = pose.basis.scaled(Vector3.ONE * 1.5)
			pose.origin.y = datum - local_box.position.y * 1.5
	var box := pose * local_box
	var focal_owner := StringName("%s.square.focus" % settlement_id)
	urban.volumes.append(VillageOccupancyVolume.new(VillageOccupancy.Role.SOLID,
		Vector2(box.get_center().x, box.get_center().z),
		Vector2(box.size.x, box.size.z) * 0.5, 0.0,
		box.position.y, box.end.y, focal_owner, focal_owner))
	var ring_radius := maxf(5.0, maxf(maxf(absf(box.position.x-centre.x), absf(box.end.x-centre.x)),
		maxf(absf(box.position.z-centre.y), absf(box.end.z-centre.y))) + PathProgram.PATH_HALF_WIDTH + 0.75)
	var topology := square_topology(settlement_id, centre, axis, radius, datum, green, ring_radius)
	if clearing:
		topology["street_surface"] = FeatureGroundField.NATURAL
		for street: Dictionary in topology.paths:
			street["surface_id"] = FeatureGroundField.NATURAL
	topology["target_houses"] = count
	topology["substantial_fraction"] = 0.0
	# Keep a tiny square in proportion to its houses using complete measured
	# silhouettes. Larger tiers may still select the tall SFV civic-sized homes.
	topology["maximum_house_height"] = 12.0
	var houses := VillageOutskirtsConstruction.construct_frontages(terrain,
		settlement_id, centre, &"hamlet", theme, program, urban,
		canonical_ground, topology, 1)
	if houses.placements.size() < 3 or not houses.validate(
			program.outskirts_program, &"hamlet"):
		urban.candidate_audit.append({"houses": houses.placements.size(),
			"target": count, "radius": radius,
			"conflict": VillageOccupancy.new().first_conflict(houses.volumes),
			"frontages": houses.audit})
		urban.volumes.clear()
		urban.reason = &"hamlet_frontage"
		return urban
	urban.ground_settlement = houses
	urban.entries.append_array(houses.entries)
	urban.volumes.append_array(houses.volumes)
	urban.surfaces.append_array(houses.surfaces)
	urban.clearances.append_array(houses.clearances)
	# A campfire shares the same safe circulation and entrances in a grassy
	# clearing. Real incoming roads retain their own paving to its boundary.
	if not clearing:
		urban.surfaces.append(FeatureGroundShape.axis_rect(
			Rect2(centre - Vector2.ONE * (radius - 2.0), Vector2.ONE * (radius - 2.0) * 2.0),
			FeatureGroundField.WORN_PATH, VillagePlan.SURFACE_PRIORITY,
			StringName("%s.square.paving" % settlement_id)))
	if green:
		urban.surfaces.append(FeatureGroundShape.circle(centre, 8.0,
			FeatureGroundField.NATURAL, VillagePlan.SURFACE_PRIORITY + 1,
			StringName("%s.square.green" % settlement_id)))
	var tint := BiomeRegistry.blended_environment_tint(
		Helper.biome_weights5(Vector3(centre.x, datum, centre.y), world_seed),
		&"tree") if green else Color.WHITE
	var focal_entry := KitSubstitution.swap_world_entry({"asset_id": focal_id,
		"transform": pose, "color": tint, "stable_id": focal_owner})
	urban.entries.append(focal_entry)
	urban.clearances.append(FeatureGroundShape.axis_rect(
		Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z)),
		FeatureGroundField.NATURAL, 0, focal_owner))
	urban.accepted = true
	urban.reason = &"accepted"
	urban.fabric_audit = {"generation_source": "ground_hamlet",
		"house_count": houses.placements.size(), "target_houses": count,
		"square_radius": radius, "focal_asset": focal_entry.asset_id}
	assert(urban.validate(program, &"hamlet"))
	return urban


static func square_topology(id: StringName, centre: Vector2, axis: Vector2,
		radius: float, datum: float, green: bool = false, inner_radius: float = 5.0) -> Dictionary:
	var side := Vector2(-axis.y, axis.x)
	var directions: Array[Vector2] = [axis, side, -axis, -side]
	var branches: Array[Dictionary] = []
	var paths: Array[Dictionary] = []
	for i in 4:
		var outward := directions[i]
		var owner := StringName("%s.square.side.%d" % [id, i])
		var point := centre + outward * radius
		var node := VillageCirculationNode.new(owner,
			VillageCirculationNode.Kind.TERRAIN_CONTACT, point, datum, id, outward)
		branches.append({"node": node, "side_key": owner, "ground_y": datum,
			"frontage_half_length": radius, "end_margin": 2.25,
			"network_nodes": [node] as Array[VillageCirculationNode]})
		if not green:
			paths.append({"owner": owner,
				"points": [point, centre + outward * inner_radius] as Array[Vector2]})
	var loop_radii: Array[float] = [radius]
	if not green:
		loop_radii.append(inner_radius)
	for loop_radius: float in loop_radii:
		var loop: Array[Vector2] = []
		for corner: Vector2 in [Vector2(-1,-1), Vector2(1,-1),
				Vector2(1,1), Vector2(-1,1), Vector2(-1,-1)]:
			loop.append(centre + (axis * corner.x + side * corner.y) * loop_radius)
		paths.append({"owner": StringName("%s.square.loop.%d" % [id, loop_radius]),
			"points": loop})
	return {"branches": branches, "paths": paths,
		"domain": FeatureGroundShape.axis_rect(
			Rect2(centre - Vector2.ONE * radius, Vector2.ONE * radius * 2.0),
			FeatureGroundField.NATURAL, VillagePlan.SURFACE_PRIORITY - 1,
			StringName("%s.square.domain" % id))}
