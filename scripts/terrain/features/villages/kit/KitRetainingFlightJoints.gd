extends RefCounted
## Native masonry below an upper landing must stay behind its attachment
## plane. A centred wall otherwise protrudes through the last part of a ramp.
## Seat complete panels inward; never flatten their relief or cut their tops.
const EPS := 0.001


static func fit(
	parts: Array[Dictionary], transitions: Array, map: Transform3D, catalog: EnvironmentCatalog
) -> int:
	var count := 0
	var inverse := map.affine_inverse()
	for transition: WarrenVolumeTransition in transitions:
		if not transition.is_vertical():
			continue
		var ends := WarrenTransitionSurfaceBuilder._span_endpoints(transition)
		var high: Vector3 = inverse * (ends.end if ends.end.y > ends.start.y else ends.start)
		var low: Vector3 = inverse * (ends.start if ends.end.y > ends.start.y else ends.end)
		var outward := ((low - high) * Vector3(1, 0, 1)).normalized()
		var tangent := outward.cross(Vector3.UP)
		var half := WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M * 0.5 / (map.basis * tangent).length()
		for part: Dictionary in parts:
			if (
				not part.has("retaining_ceiling")
				or (
					part.get("role", &"")
					not in [&"wall.stone.retaining", &"wall.stone.retaining_half"]
				)
			):
				continue
			var pose: Transform3D = part.transform
			if pose.basis.z.normalized().dot(outward) < 0.999:
				continue
			var descriptor := catalog.descriptor(part.asset_id)
			if descriptor == null:
				continue
			var box: AABB = pose * descriptor.measured_aabb
			if absf(box.end.y - high.y) > EPS:
				continue
			var reach := Vector2(INF, -INF)
			var along := Vector2(INF, -INF)
			for i in 8:
				var offset := box.get_endpoint(i) - high
				reach.x = minf(reach.x, offset.dot(outward))
				reach.y = maxf(reach.y, offset.dot(outward))
				along.x = minf(along.x, offset.dot(tangent))
				along.y = maxf(along.y, offset.dot(tangent))
			# Only full panels beneath this landing, crossing its shared edge.
			if along.x < -half - EPS or along.y > half + EPS:
				continue
			if reach.x >= 0 or reach.y <= EPS or reach.y > 0.3:
				continue
			pose.origin -= outward * reach.y
			part.transform = pose
			part["retaining_flight_joint"] = true
			count += 1
	return count
