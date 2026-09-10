extends GutTest

func test_reported_town_builds_connected_nonoverlapping_ground_houses_once() -> void:
	var seed_value := 2697992464
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var water := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value,water)
	var fields := WorldFieldBlockCache.new(heightfield,water,program.query_margin,
		program.shore_distance_limit,program.field_cache_cap)
	var terrain := VillageTerrainView.from_fields(fields)
	var urban := VillageWarrenFabricSolver.solve(terrain,
		VillagePlan.warren_seed_for_cell(seed_value,Vector2i(11,12)),
		&"reported-town",Vector2(264,288),Vector2.DOWN,program.villages,seed_value)
	assert_true(urban.accepted)
	if not urban.accepted: return
	terrain = terrain.with_terrain_grades([urban.terrain_grade])
	var start := Time.get_ticks_msec()
	var outskirts := VillageOutskirtsConstruction.generate(terrain,&"reported-town",
		Vector2(264,288),Vector2.DOWN,&"village",&"blue",program.villages,urban,null)
	print("FRONTAGE_CONSTRUCTION ms=",Time.get_ticks_msec()-start," houses=",outskirts.placements.size()," branches=",outskirts.branch_count)
	assert_gte(outskirts.placements.size(),6,"the ground-house neighborhood must remain populated")
	assert_true(outskirts.validate(program.villages.outskirts_program,&"village"),
		"completed geometry is audited here, not used to reject runtime houses")
	var physical_urban: Array[VillageOccupancyVolume] = []
	for volume: VillageOccupancyVolume in urban.volumes:
		if volume.role != VillageOccupancy.Role.GROUND_EXCLUSIVE: physical_urban.append(volume)
	assert_eq(VillageOccupancy.first_cross_conflict(outskirts.volumes,physical_urban),{},
		"all built lanes and houses must clear the urban construction")
	var finished := terrain.with_terrain_grades([urban.terrain_grade])
	var worst_step := 0.0
	var worst_points: Array[Vector2] = []
	for street: Dictionary in outskirts.street_paths:
		var points := street.points as Array[Vector2]
		for index in range(1, points.size()):
			var a := points[index - 1]
			var b := points[index]
			var steps := maxi(1, ceili(a.distance_to(b) / 0.25))
			var previous := a
			var previous_y := finished.surface_y(a)
			for sample in range(1, steps + 1):
				var point := a.lerp(b, float(sample) / steps)
				var height := finished.surface_y(point)
				var rise := absf(height - previous_y)
				if rise > worst_step:
					worst_step = rise
					worst_points.assign([previous, point])
				previous = point
				previous_y = height
	assert_lte(worst_step, 0.3,
		"the finished street must be continuous across natural cliffs: %s" % [worst_points])
	var circuits: Array[Dictionary] = []
	for street: Dictionary in outskirts.street_paths:
		if String(street.owner).ends_with(".perimeter"): circuits.append(street)
	assert_eq(circuits.size(), 1, "all houses share one exterior circuit")
	if circuits.size() == 1:
		var loop := circuits[0].points as Array[Vector2]
		assert_eq(loop[0], loop[-1], "the perimeter has no dead ends")
		assert_eq(loop.size(), 6, "four corners and one shared straight-side closure")
		for street: Dictionary in outskirts.street_paths:
			if not String(street.owner).contains(".gate."): continue
			var gate_points := street.points as Array[Vector2]
			assert_eq(gate_points.size(),2,"an exterior portal goes straight to its circuit side")
			for segment in range(1,gate_points.size()):
				var delta := gate_points[segment]-gate_points[segment-1]
				assert_true(absf(delta.x)<0.001 or absf(delta.y)<0.001,
					"the gate preserves its own transverse phase instead of drawing a diagonal notch")
			var end: Vector2 = street.points[-1]
			var incidence := INF
			for edge in range(1,loop.size()):
				incidence = minf(incidence,Geometry2D.get_closest_point_to_segment(
					end,loop[edge-1],loop[edge]).distance_to(end))
			assert_lt(incidence,0.001,"each gate meets the same perimeter")
	for volume: VillageOccupancyVolume in outskirts.volumes:
		if volume.role != VillageOccupancy.Role.HEADROOM: continue
		for fraction: float in [-1.0,-0.5,0.0,0.5,1.0]:
			var point := volume.centre + Vector2.RIGHT.rotated(volume.angle) \
				* volume.half_extents.x*fraction
			var ground := finished.surface_y(point)
			assert_lte(volume.y_range.x,ground+0.001)
			assert_gte(volume.y_range.y,ground+TraversalEnvelope.MIN_HEADROOM-0.001,
				"street headroom follows the completed graded ground")
	var approach := FeatureGroundShape.oriented_rect(Vector2(264,244),Vector2(2,26),0)
	for house: VillageMassingPlacement in outskirts.placements:
		assert_false(house.solid_shape().intersects(approach),
			"the shared incoming approach remains free of houses")
	for i in outskirts.placements.size():
		var house := outskirts.placements[i]
		# The authored porch/foundation can be inset from the visible facade.
		# Measure the street setback at the actual outer house envelope.
		assert_almost_eq(house.solid_shape().signed_distance(house.street_contact),
			PathProgram.PATH_HALF_WIDTH + VillageOutskirtsConstruction.MARGIN, 0.01,
			"the house facade must directly address the shared perimeter")
		for j in range(i+1,outskirts.placements.size()):
			assert_false(house.solid_shape().intersects(outskirts.placements[j].solid_shape()))
		for shape: FeatureGroundShape in urban.surfaces:
			assert_false(house.support_shape().intersects(shape),"house must not overlap the town path")
		for shape: FeatureGroundShape in outskirts.surfaces:
			assert_false(_overlaps_interior(_paint_obstacle(house,program.villages), shape),
				"the complete painted junction must clear the house base: %s / %s" % [house.stable_key,shape.stable_id])
		var pad_height := house.floor_y - VillageTerrainSurvey.FLOOR_GUARD
		var bounds := house.support_shape().bounds()
		for point: Vector2 in [bounds.position,bounds.end,bounds.get_center(),
				Vector2(bounds.position.x,bounds.end.y),Vector2(bounds.end.x,bounds.position.y)]:
			assert_almost_eq(urban.terrain_grade.surface_y(point,terrain.surface_y(point)),pad_height,0.02,
				"the entire building base must meet its constructed ground pad")
		assert_eq(outskirts.audit[i].placement_count,1)


func _paint_obstacle(house: VillageMassingPlacement, program: VillageProgram) -> FeatureGroundShape:
	var support := house.support_shape()
	var spec := program.spec_for_asset(house.asset_id)
	if not spec.ground_entrance_local.is_finite(): return support
	# Foundation reservations include empty space in front of an inset native
	# porch. Only that front strip may carry ground paint. The real tread at
	# this plane is independently ray-tested in test_september8_porch_path.
	var outward := house.entrance_outward
	var x_axis := Vector2.RIGHT.rotated(support._angle)
	var y_axis := Vector2.DOWN.rotated(support._angle)
	var half := support._half_extents
	var extent := absf(outward.dot(x_axis))*half.x+absf(outward.dot(y_axis))*half.y
	var trim := maxf(0.0,support._a.dot(outward)+extent-house.entrance_ground_contact.dot(outward))
	if absf(outward.dot(x_axis))>0.99: half.x -= trim*0.5
	else: half.y -= trim*0.5
	return FeatureGroundShape.oriented_rect(support._a-outward*trim*0.5,half,support._angle)


func _overlaps_interior(left: FeatureGroundShape, right: FeatureGroundShape) -> bool:
	# A doorway path ends on the wall boundary. The inclusive intersection
	# predicate treats that intended seam as a collision; measure rectangle
	# area in local coordinates instead. Curved paint keeps the exact predicate.
	if left.kind != FeatureGroundShape.Kind.ORIENTED_RECT \
			or right.kind != FeatureGroundShape.Kind.ORIENTED_RECT:
		return left.intersects(right)
	var a := _rectangle(left, left._a)
	var b := _rectangle(right, left._a)
	var area := 0.0
	for polygon: PackedVector2Array in Geometry2D.intersect_polygons(a, b):
		for index in range(1, polygon.size() - 1):
			area += absf((polygon[index] - polygon[0]).cross(
				polygon[index + 1] - polygon[0])) * 0.5
	return area > 0.0001


func _rectangle(shape: FeatureGroundShape, origin: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for corner: Vector2 in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
		result.append(shape._a - origin + (corner * shape._half_extents).rotated(shape._angle))
	return result


func test_doorstep_contact_is_distinct_from_paint_inside_the_house() -> void:
	var house := FeatureGroundShape.oriented_rect(Vector2(300,350), Vector2(9,12), 0)
	var touching := FeatureGroundShape.oriented_rect(Vector2(300,336), Vector2(2,2), 0)
	var intrusion := FeatureGroundShape.oriented_rect(Vector2(300,336.01), Vector2(2,2), 0)
	assert_false(_overlaps_interior(house, touching))
	assert_true(_overlaps_interior(house, intrusion), "even one centimetre of paint inside the wall fails")
