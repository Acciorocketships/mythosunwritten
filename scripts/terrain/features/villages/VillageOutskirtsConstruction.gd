class_name VillageOutskirtsConstruction
extends RefCounted

## World-road street helpers for a sealed warren: the town's terrain contacts,
## the country-road handoffs crossing its street domain, the graded street
## band, and the street paint/clearance/headroom each connection owns.
## The frontage-lot outskirts constructor and its solver were deleted
## October 7: production records never carried outskirts houses.
const PITCH := VillageWorldScale.WORLD_FINE_CELL_M
const HALF_PATH := PathProgram.PATH_HALF_WIDTH
## Approach distance of the contract-derived contact a source-less fixture
## receives (the retired outskirts program's inner radius).
const FIXTURE_APPROACH_RADIUS := 36.0


static func _ground_contacts(terrain: VillageTerrainView, arrival: Vector2,
		primary_axis: Vector2, urban: VillageUrbanFabricPlan
		) -> Array[VillageCirculationNode]:
	var out: Array[VillageCirculationNode] = []
	# Volumetric warren: consume the exact same sealed contact records that make
	# the terrain handoff ramps. This single source of truth prevents an outskirts
	# road from beginning at a guessed fine-cell endpoint while the rendered town
	# opens somewhere else. The contact point is the ramp's terrain-side edge,
	# already one complete 3 m run beyond the finished two-lane street boundary.
	if urban.volumetric_spatial != null and urban.fabric_plan != null:
		var specs := VillageWarrenFabricSolver.terrain_contact_specs(
			urban.volumetric_spatial, urban.fabric_plan)
		for spec: Dictionary in specs:
			var local_outward := spec.outward as Vector3i
			var contact := VillageWarrenFabricSolver \
				.terrain_contact_local_geometry(spec)
			var outer_centre := contact.outer_centre as Vector3
			var world3 := urban.world_transform * outer_centre
			var point := Vector2(world3.x, world3.z)
			var ground_y := terrain.surface_y(point)
			var world_outward3 := urban.world_transform.basis \
				* Vector3(local_outward)
			var outward := Vector2(world_outward3.x, world_outward3.z).normalized()
			if outward.is_zero_approx():
				continue
			out.append(VillageCirculationNode.new(StringName(
				"warren.contact.%s" % String(spec.stable_suffix)),
				VillageCirculationNode.Kind.TERRAIN_CONTACT, point, ground_y,
				&"warren.public_entry" if String(spec.stable_suffix) == "entry" \
				else &"warren.public_exit", outward))
		if not out.is_empty():
			return out
	# Compact isolated fixtures have no source volume. Retain a contract-derived
	# approach only for those tests/custom programs; production warrens take one
	# of the two exact topology branches above.
	var point := arrival - primary_axis * (FIXTURE_APPROACH_RADIUS * 0.5)
	out.append(VillageCirculationNode.new(&"warren.approach",
		VillageCirculationNode.Kind.TERRAIN_CONTACT, point,
		terrain.surface_y(point), &"warren.approach", -primary_axis))
	return out


static func _append_street(plan: VillageUrbanFabricPlan, points: Array[Vector2],
		owner: StringName, network_id: StringName, terrain: VillageTerrainView,
		seen: Dictionary, surface_id: int = FeatureGroundField.WORN_PATH) -> void:
	plan.surfaces.append_array(PathProgram.filleted_path_shapes(points,HALF_PATH,
		surface_id,VillagePlan.SURFACE_PRIORITY,StringName("%s.street" % owner)))
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
		var heights := TerrainTileField.height_bounds(terrain.region_covering(corridor),corridor)
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


static func _world_road_handoffs(domain: FeatureGroundShape,
		ground: FeatureGroundField, settlement_id: StringName) -> Array[Dictionary]:
	var paths: Array[Dictionary] = []
	if ground == null: return paths
	var corners: Array[Vector2] = []
	for sign_value: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		corners.append(domain._a+(sign_value*domain._half_extents).rotated(domain._angle))
	var seen: Dictionary = {}
	for cell: Vector2i in ground._connection_masks:
		var centre := Vector2(cell)*HeightfieldPlan.CELL
		var mask := int(ground._connection_masks[cell])
		for arm: Array in [[1,Vector2.RIGHT],[2,Vector2.LEFT],[4,Vector2.DOWN],[8,Vector2.UP]]:
			if (mask & int(arm[0])) == 0: continue
			var end := centre+(arm[1] as Vector2)*(HeightfieldPlan.CELL * 0.5)
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
