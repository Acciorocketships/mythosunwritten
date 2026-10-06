extends GutTest
const P = preload("res://scripts/terrain/features/villages/fabric/WarrenStairEdgeProfiles.gd")
const B = preload(
	"res://scripts/terrain/features/villages/fabric/WarrenTransitionSurfaceBuilder.gd"
)
const AIR = preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")


func test_roof_margins_are_geometric_in_every_direction() -> void:
	for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		for descent in [false, true]:
			var flight := _flight(dir, descent)
			var ends := B._span_endpoints(flight)
			var along := Vector3(dir.x, 0, dir.y)
			var across := Vector3(-dir.y, 0, dir.x)
			var origin: Vector3 = ends.start
			origin.y = 0.0
			var frame := Transform3D(Basis(along, Vector3.UP, across), origin)
			var roof: AABB = frame * AABB(Vector3(0, 0, 1.2), Vector3(3, 3, 1.8))
			var surfaces := PublicRealmSurfacePlan.new(&"selection")
			var profile: Vector2 = P.choose(flight, [roof], surfaces)
			assert_almost_eq(profile.x, 0.0, .00001)
			assert_almost_eq(profile.y, .32, .00001, "Measured encroachment plus the joint margin")
			var mesh := B.build(&"admitted", flight, flight.surface_cells(), [], false, profile)
			for air: Dictionary in AIR.from_mesh(mesh, Transform3D.IDENTITY, 1.2):
				assert_false(
					(air.bounds as AABB).intersects(roof),
					"Emitted tread clearance keeps the measured roof reservation"
				)
			var too_wide: AABB = frame * AABB(Vector3(0, 0, .5), Vector3(3, 3, 2.5))
			assert_eq(
				P.choose(flight, [too_wide], surfaces),
				Vector2.ZERO,
				"A roof needing a whole lane is not a side margin"
			)
			roof.position.y = 10.0
			assert_eq(
				P.choose(flight, [roof], surfaces),
				Vector2.ZERO,
				"A roof overhead beyond headroom cannot narrow the stair"
			)


func test_side_connections_block_only_the_connected_edge() -> void:
	var flight := _flight(Vector2i.DOWN, false)
	var surfaces := PublicRealmSurfacePlan.new(&"side-connection")
	assert_true(
		surfaces.add_claim(
			Vector3i(-1, 0, 2), PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT, &"side"
		)
	)
	var roofs: Array[AABB] = [
		AABB(Vector3(-3, 0, 2.25), Vector3(2.55, 3, 3)),
		AABB(Vector3(1.95, 0, 2.25), Vector3(2.55, 3, 3))
	]
	var profile: Vector2 = P.choose(flight, roofs, surfaces)
	assert_almost_eq(profile.x, .32, .00001, "Unconnected opposite edge can still fit")
	assert_eq(profile.y, 0.0, "A landing/court joining the flight owns its whole connection")


func _flight(dir: Vector2i, descent: bool) -> WarrenVolumeTransition:
	var t := WarrenVolumeTransition.new(
		&"selection",
		Vector3i(0, int(descent), 0),
		Vector3i(dir.x * 2, int(not descent), dir.y * 2),
		WarrenVolumeTransition.Kind.STAIR,
		[] as Array[Vector3i]
	)
	assert_true(t.seal())
	return t
