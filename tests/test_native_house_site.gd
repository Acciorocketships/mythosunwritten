extends GutTest
const Site = preload("res://scripts/terrain/features/villages/grammar/NativeHouseSite.gd")
const Compiler = preload("res://scripts/terrain/features/villages/grammar/NativeGrammarCompiler.gd")


func test_door_owned_sites_keep_native_scale_bounds_and_ground_at_every_facing() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var arrival := Vector3(42, 3, -27)
	for scale_value: float in [1.0, 2.0]:
		for seed_value in [7, 11, 31]:
			for facing in 4:
				var outward := Basis(Vector3.UP, facing * PI * .5) * Vector3.BACK
				var site := Site.cross(catalog, 2, 1, seed_value, scale_value, arrival, outward)
				assert_true(site.ok, site.reason)
				assert_almost_eq(site.door.basis.z.normalized(), outward, Vector3.ONE * .0001)
				assert_almost_eq(site.door.origin.y, arrival.y + 1.5 * scale_value, .0001)
				assert_almost_eq(
					site.pose.basis.get_scale(), Vector3.ONE * scale_value, Vector3.ONE * .0001
				)
				assert_eq(site.entry_route[0], arrival)
				assert_lt(
					(site.entry_route[1] - arrival).dot(outward),
					0.0,
					"Route enters toward the door"
				)
				var compiled := Compiler.compile(
					site.parts, catalog, site.pose, &"site.fixture", site.envelope.grow(.001)
				)
				assert_true(compiled.ok, compiled.reason)
				assert_eq(compiled.payload.instance_count, site.parts.size())
				assert_almost_eq(
					compiled.envelope.position, site.envelope.position, Vector3.ONE * .0001
				)
				assert_almost_eq(compiled.envelope.size, site.envelope.size, Vector3.ONE * .0001)
				for contact: AABB in site.bearing_bounds:
					assert_eq(contact.position.y, arrival.y)
					assert_eq(contact.size.y, 0.0)
					assert_gt(contact.size.x * contact.size.z, 0.0)
				# The arrival is outside the actual stair, with room for the capsule.
				for part: Dictionary in site.parts:
					if not part.has("entry_for"):
						continue
					var descriptor := catalog.descriptor(Compiler.asset_id(part.module))
					var stair_in_door: AABB = (
						site.door.affine_inverse()
						* site.pose
						* part.transform
						* descriptor.measured_aabb
					)
					var arrival_in_door: Vector3 = site.door.affine_inverse() * arrival
					assert_almost_eq(
						(arrival_in_door.z - stair_in_door.end.z) * scale_value,
						Site.ARRIVAL_MARGIN,
						.001
					)


func test_invalid_site_inputs_fail_before_emitting_a_derivation() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for site: Dictionary in [
		Site.cross(catalog, 2, 1, 31, 3.0, Vector3.ZERO, Vector3.BACK),
		Site.cross(catalog, 0, 1, 31, 2.0, Vector3.ZERO, Vector3.BACK),
		Site.cross(catalog, 2, 1, 31, 2.0, Vector3.ZERO, Vector3.UP),
		Site.cross(catalog, 2, 1, 31, 2.0, Vector3.ZERO, Vector3.ZERO),
		Site.cross(catalog, 2, 1, 31, 2.0, Vector3(INF, 0, 0), Vector3.BACK),
		Site.cross(EnvironmentCatalog.new(), 2, 1, 31, 2.0, Vector3.ZERO, Vector3.BACK),
	]:
		assert_false(site.ok)
		assert_false(site.reason.is_empty())
		assert_false(site.has("parts"), "Failure cannot become a partially specified building")
