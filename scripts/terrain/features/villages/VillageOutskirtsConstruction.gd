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
	var street_grid := VillageOutskirtsSolver._urban_perimeter_grid(urban, arrival, axis)
	var datum := urban.world_transform.origin.y - VillageWarrenFabricSolver.DATUM_GUARD
	var approach_length := PITCH
	for spec: VillageAssetSpec in program.outskirts_program.house_specs:
		approach_length = maxf(approach_length,spec.solid_local_rect.size.length()
			* VillageWorldScale.PRODUCTION_UNIFORM_SCALE + PathProgram.PATH_WIDTH)
	var topology := _perimeter_streets(terrain, settlement_id, arrival, axis,
		contacts, street_grid, datum,approach_length)
	var branches: Array[Dictionary] = topology.branches
	var planned_streets: Array[Dictionary] = topology.paths
	# The town owns its street network inside the circuit. Country roads meet
	# that boundary; they cannot independently paint a second street through it.
	plan.surfaces.append(topology.domain)
	planned_streets.append_array(_world_road_handoffs(topology.domain,
		canonical_ground, settlement_id))
	plan.route_exit_count = contacts.size()
	urban.terrain_grade = _extend_street_grade(urban.terrain_grade, planned_streets, datum)
	terrain = terrain.with_terrain_grades([urban.terrain_grade])
	for branch: Dictionary in branches:
		var node := branch.node as VillageCirculationNode
		node.surface_y = terrain.surface_y(node.point)
	var obstacles: Array[Rect2] = []
	for volume: VillageOccupancyVolume in urban.volumes:
		if volume.role in [VillageOccupancy.Role.SOLID, VillageOccupancy.Role.WALK_SURFACE,
				VillageOccupancy.Role.WALK_GUARD, VillageOccupancy.Role.HEADROOM]:
			obstacles.append(volume.bounds_xz())
	for site: Dictionary in urban.frontage_sites:
		obstacles.append(Rect2((site.centre as Vector2) - (site.half_extents as Vector2),
			(site.half_extents as Vector2) * 2.0))
	if canonical_ground != null:
		obstacles.append_array(canonical_ground.construction_clearance_bounds())
	for street: Dictionary in planned_streets:
		for shape: FeatureGroundShape in PathProgram.filleted_path_shapes(street.points,
				HALF_PATH, FeatureGroundField.WORN_PATH, 0, &"reserved-street"):
			obstacles.append(shape.bounds())
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
	var claims: Dictionary = urban.terrain_grade._claims
	var grade_origin: Vector2 = urban.terrain_grade._origin
	for branch_index in branches.size():
		var branch := branches[branch_index]
		var node := branch.node as VillageCirculationNode
		var tangent := Vector2(-node.outward.y,node.outward.x)
		var ground_y := float(branch.get("ground_y", datum))
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
			for depth: float in [0.0]:
				var origin := node.point + node.outward*(setback + depth - near_edge)
				var span := float(branch.frontage_half_length) - PathProgram.CORNER_RADIUS - HALF_PATH
				var house_span := VillageFrontageDomain.projection(bounds,tangent)
				var free := VillageFrontageDomain.subtract_obstacles(
					[Vector2(-span-house_span.x,span-house_span.y)] as Array[Vector2],
					origin,tangent,bounds,obstacles,MARGIN)
				free = VillageFrontageDomain.subtract_obstacles(free,origin,tangent,
					pad,incompatible_ground,0.0)
				domains.append({"id":"%s/%s/%d" % [node.stable_key,spec.asset_id,depth],
					"group":branch.side_key,"origin":origin,"tangent":tangent,
					"bounds":bounds,"pad":pad,"access_bounds":bounds.merge(
					Rect2(node.point-origin-Vector2.ONE*HALF_PATH,Vector2.ONE*HALF_PATH*2.0)),"area":spec.ground_contact_local_rect.get_area(),
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
		placement.entrance_ground_contact = _ground_entrance(spec,built)
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
		var street: Array[Vector2] = [placement.street_contact,
			placement.entrance_ground_contact]
		streets.append({"points":street,"owner":owner,"half_width":placement.access_half_width})
		plan.clearances.append(FeatureGroundShape.axis_rect(lot.world_bounds,
			FeatureGroundField.NATURAL,0,StringName("%s.clearance" % owner)))
		served[lot.group]=true
		plan.audit.append({"slot":String(slot.stable_key),"accepted":true,
			"asset_id":String(spec.asset_id),"contact":String(node.stable_key),
			"construction_method":"frontage_domain","placement_count":1})
	urban.terrain_grade = urban.terrain_grade.with_fixed_extension(ground_cells)
	urban.terrain_grade = _extend_street_grade(urban.terrain_grade, streets, datum)
	var finished_terrain := terrain.with_terrain_grades([urban.terrain_grade])
	for street: Dictionary in planned_streets:
		_append_street(plan,street.points,street.owner,urban.public_walk_network_id,
			finished_terrain,HALF_PATH,street_ids)
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

static func _ground_entrance(spec: VillageAssetSpec, built: Transform3D) -> Vector2:
	if spec.ground_entrance_local.is_finite():
		var point := built * Vector3(spec.ground_entrance_local.x,0,spec.ground_entrance_local.y)
		return Vector2(point.x,point.z)
	var entrance := spec.world_entrance(built)
	var outward := spec.world_entrance_outward(built)
	var support := spec.world_ground_contact(built)
	var bounds := FeatureGroundShape.oriented_rect(support.centre,support.half_extents,support.angle).bounds()
	var projection := VillageFrontageDomain.projection(bounds,outward)
	return entrance + outward * maxf(0.0,projection.y-entrance.dot(outward))

static func _append_street(plan: VillageOutskirtsPlan, points: Array[Vector2],
		owner: StringName, network_id: StringName, terrain: VillageTerrainView,
		_door_half_width: float, seen: Dictionary) -> void:
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
		var corridor := FeatureGroundShape.oriented_rect((a+b)*0.5,
			Vector2(a.distance_to(b)*0.5,HALF_PATH),(b-a).angle()).bounds()
		var heights := TerrainSurfaceField.height_bounds(terrain.region_covering(corridor),corridor)
		plan.volumes.append(VillageOccupancyVolume.new(VillageOccupancy.Role.HEADROOM,
			(a+b)*0.5,Vector2(a.distance_to(b)*0.5,HALF_PATH),
			(b-a).angle(),heights.x,heights.y+TraversalEnvelope.MIN_HEADROOM,
			StringName("%s.street.%d" % [owner,index]),owner,network_id))


static func _extend_street_grade(source: TerrainGradePatch,
		streets: Array[Dictionary], datum: float) -> TerrainGradePatch:
	# Streets claim their complete walking width before lots. The existing
	# construction field supplies height; natural cliffs cannot own a road cell.
	# All targets read the same immutable source, independent of traversal order.
	var cells := source._claims.duplicate()
	var radius := HALF_PATH + PITCH
	for street: Dictionary in streets:
		var points := street.points as Array[Vector2]
		for index in range(1, points.size()):
			var a := points[index - 1]
			var b := points[index]
			var bounds := Rect2(a, Vector2.ZERO).expand(b).grow(radius)
			var low := Vector2i(floori((bounds.position.x - source._origin.x) / PITCH),
				floori((bounds.position.y - source._origin.y) / PITCH))
			var high := Vector2i(ceili((bounds.end.x - source._origin.x) / PITCH),
				ceili((bounds.end.y - source._origin.y) / PITCH))
			for z in range(low.y, high.y + 1):
				for x in range(low.x, high.x + 1):
					var cell := Vector2i(x, z)
					if cells.has(cell): continue
					var point := source._origin + Vector2(cell) * PITCH
					if point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)) > radius:
						continue
					cells[cell] = source.surface_y(point,datum)
	return source.with_continuous_extension(cells,datum)

static func _frontage_path(existing: Array[Dictionary], branch: Array[Vector2],
		contact: Vector2, door: Vector2) -> Array[Vector2]:
	# The doorway ray meets the first existing street on its way into town.
	# Select that graph incidence before emitting the route, so the unused
	# remainder of a frontage branch never becomes a painted dead end.
	var branch_line := branch.duplicate()
	branch_line.append(contact)
	var routes := existing.duplicate()
	routes.append({"points": branch_line})
	var prefix := branch_line
	var split_index := branch_line.size() - 1
	var split_point := contact
	var nearest := INF
	for route: Dictionary in routes:
		var line := route.points as Array[Vector2]
		for index in range(1, line.size()):
			var crossing: Variant = Geometry2D.segment_intersects_segment(
				contact, door, line[index - 1], line[index])
			if crossing == null: continue
			var point := crossing as Vector2
			var distance := point.distance_squared_to(door)
			if distance >= nearest - 0.000001: continue
			nearest = distance
			prefix = line
			split_index = index
			split_point = point
	var out: Array[Vector2] = []
	out.assign(prefix.slice(0, split_index))
	if out.is_empty() or out[-1].distance_to(split_point) > 0.001:
		out.append(split_point)
	out.append(door)
	return out


static func _perimeter_streets(terrain: VillageTerrainView, settlement_id: StringName,
		arrival: Vector2, axis: Vector2, contacts: Array[VillageCirculationNode],
		grid: Dictionary, datum: float, approach_length: float) -> Dictionary:
	# One four-sided circuit owns all outskirts frontage. Its straight sides
	# are shared by both directions at the approach; independent gate routes
	# cannot choose staggered parallel distributors.
	var envelope := grid.envelope as Rect2
	var margin := HALF_PATH + MARGIN + PathProgram.CORNER_RADIUS * (1.0-sqrt(0.5))
	var lo := ((envelope.position-Vector2.ONE*margin)/PITCH).floor()*PITCH
	var hi := ((envelope.end+Vector2.ONE*margin)/PITCH).ceil()*PITCH
	var corners: Array[Vector2] = [lo,Vector2(hi.x,lo.y),hi,Vector2(lo.x,hi.y)]
	var mid := (corners[0]+corners[1])*0.5
	var loop: Array[Vector2] = [VillageOutskirtsSolver._grid_world(mid,arrival,axis)]
	for index: int in [1,2,3,0]:
		loop.append(VillageOutskirtsSolver._grid_world(corners[index],arrival,axis))
	loop.append(loop[0])
	var paths: Array[Dictionary] = [{"points":loop,
		"owner":StringName("%s.perimeter" % settlement_id)}]
	var branches: Array[Dictionary] = []
	for index in 4:
		var a := corners[index]
		var b := corners[(index+1)%4]
		var local_middle := (a+b)*0.5
		var outward := Vector2((b-a).y,-(b-a).x).normalized()
		var point := VillageOutskirtsSolver._grid_world(local_middle,arrival,axis)
		var world_outward := axis*outward.x+Vector2(-axis.y,axis.x)*outward.y
		var id := StringName("perimeter.side.%d" % index)
		var node := VillageCirculationNode.new(id,VillageCirculationNode.Kind.TERRAIN_CONTACT,
			point,datum,contacts[0].owner_key,world_outward)
		branches.append({"node":node,"side_key":id,"ground_y":datum,
			"frontage_half_length":a.distance_to(b)*0.5,
			"network_nodes":[node] as Array[VillageCirculationNode]})
	var side := Vector2(-axis.y,axis.x)
	for contact: VillageCirculationNode in contacts:
		var local := VillageOutskirtsSolver._grid_local(contact.point,arrival,axis)
		var outward := Vector2(contact.outward.dot(axis),contact.outward.dot(side))
		var target := local.clamp(lo,hi)
		if absf(outward.x)>absf(outward.y):
			target.x=hi.x if outward.x>0 else lo.x
		else:
			target.y=hi.y if outward.y>0 else lo.y
		# Each sealed portal already faces exterior air. Its straight exit keeps
		# that portal's transverse coordinate all the way to the circuit. Secondary
		# portals need not share the primary portal's 3 m lattice phase: snapping
		# them creates a short diagonal wedge at the wider town-street handoff.
		var points: Array[Vector2] = [contact.point,
			VillageOutskirtsSolver._grid_world(target,arrival,axis)]
		paths.append({"points":points,
			"owner":StringName("%s.gate.%s" % [settlement_id,contact.stable_key])})
		if contact == contacts[0]:
			var mouth := VillageOutskirtsSolver._grid_world(target,arrival,axis)
			paths.append({"points":[mouth,mouth+contact.outward*approach_length] as Array[Vector2],
				"owner":StringName("%s.approach" % settlement_id)})
	var domain := FeatureGroundShape.oriented_rect(
		VillageOutskirtsSolver._grid_world((lo+hi)*0.5,arrival,axis),
		(hi-lo)*0.5,axis.angle(),FeatureGroundField.NATURAL,
		VillagePlan.SURFACE_PRIORITY-1,StringName("%s.street-domain" % settlement_id))
	return {"paths":paths,"branches":branches,"domain":domain}


static func _world_road_handoffs(domain: FeatureGroundShape,
		ground: FeatureGroundField, settlement_id: StringName) -> Array[Dictionary]:
	var paths: Array[Dictionary] = []
	if ground == null: return paths
	var corners: Array[Vector2] = []
	for sign_value: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		corners.append(domain._a+(sign_value*domain._half_extents).rotated(domain._angle))
	var seen: Dictionary = {}
	for cell: Vector2i in ground._connection_masks:
		var centre := Vector2(cell)*TerrainSurfaceField.TILE
		var mask := int(ground._connection_masks[cell])
		for arm: Array in [[1,Vector2.RIGHT],[2,Vector2.LEFT],[4,Vector2.DOWN],[8,Vector2.UP]]:
			if (mask & int(arm[0])) == 0: continue
			var end := centre+(arm[1] as Vector2)*TerrainSurfaceField.HALF
			var centre_outside := domain.signed_distance(centre)>0.001
			var end_outside := domain.signed_distance(end)>0.001
			if centre_outside == end_outside: continue
			var outside := centre if centre_outside else end
			for side_index in 4:
				var hit: Variant = Geometry2D.segment_intersects_segment(centre,end,
					corners[side_index],corners[(side_index+1)%4])
				if hit == null: continue
				var point := hit as Vector2
				var key := str(point.snapped(Vector2.ONE*0.001))
				if seen.has(key): continue
				seen[key]=true
				paths.append({"points":[point,outside] as Array[Vector2],
					"owner":StringName("%s.world-road.%s" % [settlement_id,key])})
	paths.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return String(a.owner)<String(b.owner))
	return paths
