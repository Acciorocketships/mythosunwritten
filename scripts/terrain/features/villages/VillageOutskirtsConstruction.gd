class_name VillageOutskirtsConstruction
extends RefCounted

## Construct houses from disjoint frontage intervals. The street graph and all
## measured house envelopes precede allocation; a selected lot emits one house,
## one flat ground pad, and its doorway connection, without placement trials.
const PITCH := VillageWorldScale.WORLD_FINE_CELL_M
const HALF_PATH := PathProgram.PATH_HALF_WIDTH
const MARGIN := 0.25

static func generate(terrain: VillageTerrainView, settlement_id: StringName,
		arrival: Vector2, axis: Vector2, tier: StringName, theme: StringName,
		program: VillageProgram, urban: VillageUrbanFabricPlan,
		canonical_ground: FeatureGroundField) -> VillageOutskirtsPlan:
	var plan := VillageOutskirtsPlan.new()
	var contacts := VillageOutskirtsSolver._ground_contacts(terrain, arrival, axis, urban)
	var annulus := VillageOutskirtsSolver._outskirts_annulus(urban, arrival, true)
	var branches := VillageOutskirtsSolver._outskirts_branches(terrain, arrival,
		axis, contacts, annulus.x, urban, true)
	plan.route_exit_count = contacts.size()
	VillageOutskirtsSolver._construct_gate_connections(plan, terrain, settlement_id,
		arrival, axis, contacts, urban)
	var obstacles: Array[Rect2] = []
	for volume: VillageOccupancyVolume in urban.volumes:
		if volume.role in [VillageOccupancy.Role.SOLID, VillageOccupancy.Role.WALK_SURFACE,
				VillageOccupancy.Role.WALK_GUARD, VillageOccupancy.Role.HEADROOM]:
			obstacles.append(volume.bounds_xz())
	for site: Dictionary in urban.frontage_sites:
		obstacles.append(Rect2((site.centre as Vector2) - (site.half_extents as Vector2),
			(site.half_extents as Vector2) * 2.0))
	if canonical_ground != null:
		for shape: FeatureGroundShape in canonical_ground._clearance_shapes:
			obstacles.append(shape.bounds())
	for shape: FeatureGroundShape in plan.surfaces: obstacles.append(shape.bounds())
	# Every potential frontage shares this already-decided street graph. Lots
	# cannot consume a lane merely because its house is allocated later.
	for branch: Dictionary in branches:
		var nodes: Array = branch.network_nodes
		for index in range(1,nodes.size()):
			var a: Vector2 = nodes[index-1].point
			var b: Vector2 = nodes[index].point
			obstacles.append(Rect2(a,Vector2.ZERO).expand(b).grow(HALF_PATH))
	var domains: Array[Dictionary] = []
	var scale_value := VillageWorldScale.PRODUCTION_UNIFORM_SCALE
	var datum := urban.world_transform.origin.y - VillageWarrenFabricSolver.DATUM_GUARD
	var claims: Dictionary = urban.terrain_grade._claims
	var grade_origin: Vector2 = urban.terrain_grade._origin
	for branch_index in branches.size():
		var branch := branches[branch_index]
		var node := branch.node as VillageCirculationNode
		var tangent := Vector2(-node.outward.y,node.outward.x)
		var ground_y := datum + roundf((node.surface_y-datum)/PITCH)*PITCH
		var incompatible_ground: Array[Rect2] = []
		for cell: Vector2i in claims:
			if not is_equal_approx(float(claims[cell]),ground_y):
				incompatible_ground.append(Rect2(grade_origin + Vector2(cell)*PITCH
					-Vector2.ONE*PITCH*0.5,Vector2.ONE*PITCH))
		for spec: VillageAssetSpec in program.outskirts_program.house_specs:
			if not spec.allowed_in(tier): continue
			var yaw := spec.entrance_outward.angle() - (-node.outward).angle()
			var transform := Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*scale_value),Vector3.ZERO)
			var visual := spec.world_solid(transform)
			var support := spec.world_ground_contact(transform)
			var bounds := FeatureGroundShape.oriented_rect(visual.centre,visual.half_extents,visual.angle).bounds()
			var pad := FeatureGroundShape.oriented_rect(support.centre,support.half_extents,support.angle).bounds().grow(PITCH)
			var near_edge := VillageFrontageDomain.projection(bounds,node.outward).x
			var setback := HALF_PATH + MARGIN
			if bool(branch.get("market",false)): setback += VillageOutskirtsSolver.MARKET_STALL_BAND
			var origin := node.point + node.outward*(setback-near_edge)
			var free := VillageFrontageDomain.subtract_obstacles(
				[Vector2(-VillageOutskirtsSolver.PERIMETER_ROOT_SEPARATION*0.5,
					VillageOutskirtsSolver.PERIMETER_ROOT_SEPARATION*0.5)] as Array[Vector2],origin,tangent,bounds,obstacles,MARGIN)
			free = VillageFrontageDomain.subtract_obstacles(free,origin,tangent,
				pad,incompatible_ground,0.0)
			domains.append({"id":"%s/%s" % [node.stable_key,spec.asset_id],
				"group":branch.side_key,"origin":origin,"tangent":tangent,
				"bounds":bounds,"pad":pad,"area":spec.ground_contact_local_rect.get_area(),
				"intervals":free,"spec":spec,"branch":branch,"yaw":yaw,"ground_y":ground_y})
	var lots := VillageFrontageDomain.allocate(domains,
		program.outskirts_program.target_houses(tier,contacts.size()),String(settlement_id).hash(),
		VillageOutskirtsProgram.SUBSTANTIAL_COHORT_FRACTION)
	var ground_cells := claims.duplicate()
	var served: Dictionary = {}
	var street_ids: Dictionary = {}
	var streets: Array[Dictionary] = []
	for index in lots.size():
		var lot := lots[index]
		var branch: Dictionary = lot.branch
		var node := branch.node as VillageCirculationNode
		var spec := lot.spec as VillageAssetSpec
		var translation := lot.translation as Vector2
		var transform := Transform3D(Basis(Vector3.UP,float(lot.yaw)).scaled(
			Vector3.ONE*scale_value),Vector3(translation.x,0.0,translation.y))
		var support := spec.world_ground_contact(transform)
		var floor_y := float(lot.ground_y) + VillageTerrainSurvey.FLOOR_GUARD
		var perch := VillageTerrainPerch.new(StringName("frontage.%d" % index),Vector2i.ZERO,
			0,support.centre,float(lot.yaw),support.half_extents,floor_y,
			float(lot.ground_y),float(lot.ground_y),1.0,0,VillageTerrainPerch.SupportKind.NATURAL,
			(support.centre as Vector2).distance_to(arrival))
		var slot := VillageMassingSlot.new(StringName("outskirts.house.%02d" % index),spec.asset_id)
		var placement := VillageMassingPlacement.from_perch(slot,spec,perch,0,scale_value)
		var built := placement.building_transform(spec)
		placement.entrance = spec.world_entrance(built)
		placement.entrance_outward = spec.world_entrance_outward(built)
		placement.street_contact = node.point + (lot.tangent as Vector2) * \
			(placement.entrance-node.point).dot(lot.tangent)
		placement.street_contact_y = float(lot.ground_y)
		# Some prefabs address an inset porch. The terrain street ends at its
		# outer base; the authored porch owns the remaining walk to the door.
		var support_projection := VillageFrontageDomain.projection(
			placement.support_shape().bounds(),placement.entrance_outward)
		placement.entrance_ground_contact = placement.entrance + placement.entrance_outward \
			* maxf(0.0,support_projection.y-placement.entrance.dot(placement.entrance_outward))
		placement.entrance_ground_y = float(lot.ground_y)
		placement.entrance_residual_step = VillageTerrainSurvey.FLOOR_GUARD
		placement.access_half_width = TraversalEnvelope.MIN_APERTURE_WIDTH * 0.5
		placement.access_min_y = float(lot.ground_y)
		placement.access_max_y = floor_y + TraversalEnvelope.MIN_HEADROOM
		placement.ground_accessible = true
		placement.ground_route_support_profile = true
		var owner := StringName("%s.%s" % [settlement_id,slot.stable_key])
		plan.entries.append({"asset_id":spec.asset_for_theme(theme),"stable_id":owner,"transform":built})
		for attachment: VillageAttachedAssetSpec in spec.attachments:
			plan.entries.append({"asset_id":attachment.asset_for_theme(theme),
				"stable_id":StringName("%s.component.%s" % [owner,attachment.stable_key]),
				"transform":attachment.world_transform(built)})
		plan.placements.append(placement)
		plan.volumes.append(VillageOccupancyVolume.new(VillageOccupancy.Role.SOLID,
			placement.support_centre,placement.support_half_extents,placement.support_angle,
			placement.solid_min_y,placement.solid_max_y,StringName("%s.solid" % owner),owner))
		if placement.solid_max_y > floor_y + TraversalEnvelope.MIN_HEADROOM:
			plan.volumes.append(VillageOccupancyVolume.new(VillageOccupancy.Role.SOLID,
				placement.solid_centre,placement.solid_half_extents,placement.solid_angle,
				floor_y + TraversalEnvelope.MIN_HEADROOM,placement.solid_max_y,
				StringName("%s.upper-solid" % owner),owner))
		var pad := lot.pad as Rect2
		pad.position += translation
		var lo := Vector2i(floori((pad.position.x-grade_origin.x)/PITCH),floori((pad.position.y-grade_origin.y)/PITCH))
		var hi := Vector2i(ceili((pad.end.x-grade_origin.x)/PITCH),ceili((pad.end.y-grade_origin.y)/PITCH))
		for z in range(lo.y,hi.y+1):
			for x in range(lo.x,hi.x+1):
				var cell := Vector2i(x,z)
				if not ground_cells.has(cell): ground_cells[cell]=float(lot.ground_y)
		var street: Array[Vector2] = []
		for value: VillageCirculationNode in branch.network_nodes:
			street.append(value.point)
		street.append(placement.street_contact)
		street.append(placement.entrance_ground_contact)
		streets.append({"points":street,"owner":owner,"half_width":placement.access_half_width})
		plan.clearances.append(FeatureGroundShape.axis_rect(lot.world_bounds,
			FeatureGroundField.NATURAL,0,StringName("%s.clearance" % owner)))
		served[lot.group]=true
		plan.audit.append({"slot":String(slot.stable_key),"accepted":true,
			"asset_id":String(spec.asset_id),"contact":String(node.stable_key),
			"construction_method":"frontage_domain","placement_count":1})
	urban.terrain_grade = TerrainGradePatch.new(urban.terrain_grade.stable_id,
		ground_cells,grade_origin,PITCH)
	var finished_terrain := terrain.with_terrain_grades([urban.terrain_grade])
	for street: Dictionary in streets:
		_append_street(plan,street.points,street.owner,urban.public_walk_network_id,
			finished_terrain,float(street.half_width),street_ids)
	plan.surfaces.append_array(PathProgram.shared_junction_shapes(plan.street_paths,
		HALF_PATH,FeatureGroundField.WORN_PATH,VillagePlan.SURFACE_PRIORITY,
		StringName("%s.junctions" % settlement_id)))
	plan.clearances.append_array(PathProgram.shared_junction_shapes(plan.street_paths,
		HALF_PATH+0.5,FeatureGroundField.NATURAL,0,
		StringName("%s.junction-clearance" % settlement_id)))
	plan.branch_count = served.size()
	plan.supported_house_count = lots.size()
	plan.side_served_house_count = lots.size()
	plan.accepted = true
	plan.reason = &"accepted"
	return plan

static func _append_street(plan: VillageOutskirtsPlan, points: Array[Vector2],
		owner: StringName, network_id: StringName, terrain: VillageTerrainView,
		door_half_width: float, seen: Dictionary) -> void:
	plan.street_paths.append({"points":points,"owner":owner})
	plan.surfaces.append_array(PathProgram.filleted_path_shapes(points,HALF_PATH,
		FeatureGroundField.WORN_PATH,VillagePlan.SURFACE_PRIORITY,StringName("%s.street" % owner)))
	plan.clearances.append_array(PathProgram.filleted_path_shapes(points,HALF_PATH+0.5,
		FeatureGroundField.NATURAL,0,StringName("%s.street-clearance" % owner)))
	for index in range(1,points.size()):
		var a := points[index-1]
		var b := points[index]
		if a.distance_to(b)<0.001: continue
		var key := "%s/%s" % [a,b] if a.x<b.x or (a.x==b.x and a.y<b.y) else "%s/%s" % [b,a]
		if seen.has(key): continue
		seen[key]=true
		var ay := terrain.surface_y(a)
		var by := terrain.surface_y(b)
		plan.volumes.append(VillageOccupancyVolume.new(VillageOccupancy.Role.HEADROOM,
			(a+b)*0.5,Vector2(a.distance_to(b)*0.5,door_half_width if index==points.size()-1 else HALF_PATH),
			(b-a).angle(),minf(ay,by),maxf(ay,by)+TraversalEnvelope.MIN_HEADROOM,
			StringName("%s.street.%d" % [owner,index]),owner,network_id))
