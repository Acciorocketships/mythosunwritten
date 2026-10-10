extends GutTest
const BUILDER = preload(
	"res://scripts/terrain/features/villages/fabric/WarrenTransitionSurfaceBuilder.gd"
)
const AIR = preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")


func test_profile_preserves_lane_centres_and_closes_landing_shoulders() -> void:
	for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		for kind in [WarrenVolumeTransition.Kind.STAIR, WarrenVolumeTransition.Kind.RAMP]:
			for descending in [false, true]:
				for insets in [Vector2(.225, 0), Vector2(0, .225), Vector2(.15, .225)]:
					var run = 2 if kind == WarrenVolumeTransition.Kind.STAIR else 3
					var from = Vector3i(0, int(descending), 0)
					var to = Vector3i(direction.x * run, int(not descending), direction.y * run)
					var flight = WarrenVolumeTransition.new(
						&"edge-profile", from, to, kind, [] as Array[Vector3i]
					)
					assert_true(flight.seal())
					var mesh = BUILDER.build(
						&"edge-profile", flight, flight.surface_cells(), [], false, insets
					)
					assert_false(mesh.is_empty())
					var ends = BUILDER._span_endpoints(flight)
					var lateral = Vector3(-direction.y, 0, direction.x)
					var lo = INF
					var hi = -INF
					for air in AIR.from_mesh(mesh, Transform3D.IDENTITY, 1.2):
						for vertex in Geometry3D.compute_convex_mesh_points(air.planes):
							var across = (vertex - ends.start).dot(lateral)
							lo = minf(lo, across)
							hi = maxf(hi, across)
					assert_almost_eq(
						lo, -1.5 + insets.x, .0001, "Actual treads own the negative edge"
					)
					assert_almost_eq(
						hi, 1.5 - insets.y, .0001, "Actual treads own the positive edge"
					)
					assert_lt(lo, -.75, "Both reserved lane centres remain on the flight")
					assert_gt(hi, .75)
					for endpoint in [ends.start, ends.end]:
						for side in [-1, 1]:
							var inset = insets.x if side == -1 else insets.y
							if inset == 0:
								continue
							var inner = endpoint + lateral * (1.5 - inset) * side
							var outer = endpoint + lateral * 1.5 * side
							var found = false
							for span in mesh.guard_spans:
								if (
									span.foot_a.distance_to(inner) < .0001
									and span.foot_b.distance_to(outer) < .0001
								):
									found = true
							assert_true(
								found,
								"Each landing shoulder has a complete native redraw rail span"
							)
							for fraction in [.52, 1.0]:
								var centre = (
									inner.lerp(outer, .5)
									+ Vector3.UP * BUILDER.GUARD_HEIGHT * fraction
								)
								assert_true(
									_ray_hit(
										mesh.collision_faces,
										centre - Vector3(direction.x, 0, direction.y) * .3,
										centre + Vector3(direction.x, 0, direction.y) * .3
									),
									"Return rail also exists in collision"
								)


func test_deferred_guards_use_the_same_physical_profile() -> void:
	var flight = WarrenVolumeTransition.new(
		&"deferred",
		Vector3i.ZERO,
		Vector3i(0, 1, 2),
		WarrenVolumeTransition.Kind.STAIR,
		[] as Array[Vector3i]
	)
	assert_true(flight.seal())
	var immediate = BUILDER.build(
		&"deferred", flight, flight.surface_cells(), [], false, Vector2(.225, 0)
	)
	var deferred = BUILDER.build(
		&"deferred", flight, flight.surface_cells(), [], true, Vector2(.225, 0)
	)
	BUILDER.finish_profile_guards(deferred, deferred.pending_guard_span, [])
	deferred.erase("pending_guard_span")
	assert_eq(
		deferred, immediate, "Deferred production guard completion must match direct emission"
	)
	var plan := PublicRealmSurfacePlan.new(&"profile-plan")
	for cell: Vector3i in flight.surface_cells():
		assert_true(plan.add_claim(cell, PublicRealmSurfacePlan.SurfaceKind.STAIR, &"deferred"))
	var pending := BUILDER.build(
		&"deferred", flight, flight.surface_cells(), [], true, Vector2(.225, 0)
	)
	assert_true(plan.add_transition_mesh_payload(pending))
	assert_true(plan.finish_transition_guards([]))
	assert_eq(
		plan._transition_mesh_payloads[0],
		immediate,
		"The actual surface-plan guard pass preserves the physical profile"
	)


func test_invalid_profiles_cannot_remove_a_reserved_lane() -> void:
	for inset in [Vector2(-.1, 0), Vector2(.75, 0), Vector2(0, .75), Vector2(INF, 0)]:
		assert_false(BUILDER.valid_side_insets(inset))
	assert_true(BUILDER.valid_side_insets(Vector2.ZERO))


func _ray_hit(faces: PackedVector3Array, a: Vector3, b: Vector3) -> bool:
	for i in range(0, faces.size(), 3):
		if (
			Geometry3D.segment_intersects_triangle(a, b, faces[i], faces[i + 1], faces[i + 2])
			!= null
		):
			return true
	return false


func test_native_returns_keep_one_ordinary_width_post() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var kit := SuntailBuildingKit.create()
	KitSubstitution.prepare(catalog, kit)
	var widths := []
	for length in [.15, .225, .4]:
		var span := {
			"foot_a": Vector3.ZERO,
			"foot_b": Vector3(length, 0, 0),
			"top_a": Vector3(0, 1.15, 0),
			"top_b": Vector3(length, 1.15, 0),
			"landing_return": true
		}
		var parts := KitSubstitution._flight_railing(span)
		assert_eq(
			parts.size(), 3, "Two stock beams and one end post; flight owns the attachment post"
		)
		var beams := 0
		var posts := 0
		for part: Dictionary in parts:
			var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
			if part.asset_id == kit.asset(&"beam.floor"):
				beams += 1
				assert_almost_eq(box.size.x, length, .00001)
				assert_almost_eq(box.size.y, .064*1.15/.9430792, .00001)
				assert_almost_eq(box.size.z, PublicRealmSurfacePlan.GUARD_BEAM, .00001)
			if part.asset_id == kit.asset(&"rail.post"):
				posts += 1
				widths.append(box.size.x)
				assert_almost_eq(box.get_center().x, length, .00001)
				assert_almost_eq(box.position.y, 0.0, .00001, "Post stands on the landing")
		assert_eq(beams, 2)
		assert_eq(posts, 1)
	assert_almost_eq(widths[0], widths[1], .00001, "Post width cannot shrink with the shoulder")
	assert_almost_eq(widths[1], widths[2], .00001)
