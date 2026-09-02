extends GutTest

func _volume(role: int, centre: Vector2, extents: Vector2,
		angle: float, y_min: float, y_max: float,
		id: String, owner: String = "", walk_network: String = ""
		) -> VillageOccupancyVolume:
	return VillageOccupancyVolume.new(role, centre, extents, angle,
		y_min, y_max, StringName(id), StringName(owner),
		StringName(walk_network))

func test_rotated_solids_conflict_across_bucket_boundaries() -> void:
	var index := VillageOccupancy.new()
	assert_true(index.add(_volume(VillageOccupancy.Role.SOLID,
		Vector2(23.5, 0.0), Vector2(3.0, 1.0), PI * 0.25,
		0.0, 3.0, "building.a")))
	var candidate := _volume(VillageOccupancy.Role.SOLID,
		Vector2(25.0, 0.0), Vector2(2.0, 1.0), -PI * 0.2,
		0.0, 2.0, "building.b")
	assert_false(index.can_add(candidate))
	assert_eq(index.conflicts(candidate)[0].stable_id, &"building.a")

func test_vertical_separation_and_contacts_are_legal() -> void:
	var index := VillageOccupancy.new()
	assert_true(index.add(_volume(VillageOccupancy.Role.SOLID,
		Vector2.ZERO, Vector2.ONE, 0.0, 0.0, 2.0, "stall")))
	assert_true(index.add(_volume(VillageOccupancy.Role.WALK_SURFACE,
		Vector2.ZERO, Vector2.ONE, 0.0, 2.0, 2.2, "deck.touching")),
		"a deck may contact the exact top of its support")
	assert_true(index.can_add(_volume(VillageOccupancy.Role.SOLID,
		Vector2.ZERO, Vector2.ONE, 0.0, 3.0, 4.0, "upper")),
		"the same footprint is legal when its vertical interval is separate")

func test_headroom_rejects_intrusions_without_banning_ground_overlap() -> void:
	var index := VillageOccupancy.new()
	assert_true(index.add(_volume(VillageOccupancy.Role.HEADROOM,
		Vector2.ZERO, Vector2(1.0, 3.0), 0.0, 0.0,
		TraversalEnvelope.MIN_HEADROOM, "alley.headroom")))
	assert_false(index.can_add(_volume(VillageOccupancy.Role.SOLID,
		Vector2.ZERO, Vector2.ONE, 0.0, 1.0, 3.0, "beam.low")))
	assert_true(index.can_add(_volume(VillageOccupancy.Role.GROUND_EXCLUSIVE,
		Vector2.ZERO, Vector2.ONE, 0.0, -1.0, 5.0, "lot")),
		"ecological ground exclusion is independent from 3D obstruction")

func test_multi_volume_add_is_atomic() -> void:
	var index := VillageOccupancy.new()
	assert_true(index.add(_volume(VillageOccupancy.Role.SOLID,
		Vector2.ZERO, Vector2.ONE, 0.0, 0.0, 3.0, "existing")))
	var candidates: Array[VillageOccupancyVolume] = [
		_volume(VillageOccupancy.Role.SOLID, Vector2(10.0, 0.0), Vector2.ONE,
			0.0, 0.0, 2.0, "group.valid"),
		_volume(VillageOccupancy.Role.SOLID, Vector2.ZERO, Vector2.ONE,
			0.0, 0.0, 2.0, "group.invalid"),
	]
	assert_false(index.add_all(candidates))
	assert_eq(index.volumes().size(), 1,
		"a rejected group leaves no partial reservations")

func test_owned_access_can_cross_only_its_own_structure_envelope() -> void:
	var index := VillageOccupancy.new()
	assert_true(index.add(_volume(VillageOccupancy.Role.SOLID,
		Vector2.ZERO, Vector2(3.0, 3.0), 0.0, 0.0, 4.0,
		"house.solid", "house")))
	assert_true(index.add(_volume(VillageOccupancy.Role.HEADROOM,
		Vector2(0.0, 2.5), Vector2(0.6, 2.0), 0.0, 0.0, 2.4,
		"house.doorway", "house")),
		"an authored doorway reserves passage through its own envelope")
	assert_false(index.can_add(_volume(VillageOccupancy.Role.HEADROOM,
		Vector2(0.0, 2.5), Vector2(0.6, 2.0), 0.0, 0.0, 2.4,
		"neighbour.passage", "neighbour")),
		"ownership cannot weaken another structure's obstruction")


func test_owned_doorway_headroom_can_share_its_walkable_floor() -> void:
	var index := VillageOccupancy.new()
	assert_true(index.add(_volume(VillageOccupancy.Role.HEADROOM,
		Vector2.ZERO, Vector2(0.75, 1.5), 0.0, 3.0, 5.4,
		"house.doorway", "house")))
	assert_true(index.add(_volume(VillageOccupancy.Role.WALK_SURFACE,
		Vector2.ZERO, Vector2(0.75, 0.75), 0.0, 2.9, 3.1,
		"house.landing", "house")),
		"the owned landing is the doorway headroom's floor")
	assert_false(index.can_add(_volume(VillageOccupancy.Role.WALK_SURFACE,
		Vector2.ZERO, Vector2(0.75, 0.75), 0.0, 2.9, 3.1,
		"foreign.landing", "foreign")),
		"another route cannot consume the reserved doorway volume")

func test_authored_module_contact_survives_large_world_translation() -> void:
	var length := 2.21838021278381
	var first := _volume(VillageOccupancy.Role.SOLID,
		Vector2(121.2798, 1153.1091), Vector2(length * 0.5, 0.0674),
		-PI * 0.5, 0.0, 1.0, "rail.a")
	var second := _volume(VillageOccupancy.Role.SOLID,
		Vector2(121.2798, 1150.8909), Vector2(length * 0.5, 0.0674),
		-PI * 0.5, 0.0, 1.0, "rail.b")
	assert_false(first.overlaps(second),
		"sub-millimetre float32 drift at a designed seam is contact")

func test_one_owned_walk_network_unions_turns_and_stair_landings() -> void:
	var index := VillageOccupancy.new()
	assert_true(index.add(_volume(VillageOccupancy.Role.WALK_SURFACE,
		Vector2.ZERO, Vector2(1.5, 0.75), 0.0, 3.0, 3.2,
		"street.a", "vertical.street")))
	assert_true(index.add(_volume(VillageOccupancy.Role.WALK_SURFACE,
		Vector2(0.5, 0.5), Vector2(0.75, 1.5), 0.0, 3.0, 3.2,
		"street.turn", "vertical.street")),
		"one semantic walk graph can overlap at a compiled turn")
	assert_false(index.can_add(_volume(VillageOccupancy.Role.WALK_SURFACE,
		Vector2(0.5, 0.5), Vector2(0.75, 1.5), 0.0, 3.0, 3.2,
		"foreign.walk")),
		"independent elevated lots still compete for the same walk volume")


func test_declared_walk_network_can_cross_a_structural_owner_seam_only() -> void:
	var index := VillageOccupancy.new()
	assert_true(index.add(_volume(VillageOccupancy.Role.WALK_SURFACE,
		Vector2.ZERO, Vector2(1.5, 0.75), 0.0, 3.0, 3.2,
		"building.skirt", "building", "village.walk")))
	assert_true(index.add(_volume(VillageOccupancy.Role.WALK_SURFACE,
		Vector2(0.5, 0.0), Vector2(1.5, 0.75), 0.0, 3.0, 3.2,
		"public.link", "public", "village.walk")),
		"one connected floor may change structural owner at a doorway seam")
	assert_false(index.can_add(_volume(VillageOccupancy.Role.WALK_SURFACE,
		Vector2(0.5, 0.0), Vector2(1.5, 0.75), 0.0, 3.0, 3.2,
		"foreign.link", "foreign", "other.walk")))
	assert_false(index.can_add(_volume(VillageOccupancy.Role.SOLID,
		Vector2(0.5, 0.0), Vector2(0.5, 0.5), 0.0, 3.0, 4.0,
		"foreign.solid", "foreign", "village.walk")),
		"walk-network identity never admits a solid intrusion")


func test_declared_walk_network_carries_headroom_across_a_floor_seam() -> void:
	var index := VillageOccupancy.new()
	assert_true(index.add(_volume(VillageOccupancy.Role.WALK_SURFACE,
		Vector2.ZERO, Vector2(1.5, 0.75), 0.0, 3.0, 3.2,
		"urban.floor", "urban", "village.walk")))
	assert_true(index.add(_volume(VillageOccupancy.Role.HEADROOM,
		Vector2(0.75, 0.0), Vector2(1.5, 0.75), 0.0, 3.0, 5.4,
		"edge.street.headroom", "edge.street", "village.walk")),
		"one declared public route keeps its clear volume across an owner seam")
	assert_false(index.can_add(_volume(VillageOccupancy.Role.HEADROOM,
		Vector2(0.75, 0.0), Vector2(1.5, 0.75), 0.0, 3.0, 5.4,
		"foreign.headroom", "foreign", "other.walk")),
		"an unrelated route cannot borrow the public-floor seam")


func test_walk_guard_can_meet_only_its_declared_public_floor_network() -> void:
	var index := VillageOccupancy.new()
	assert_true(index.add(_volume(VillageOccupancy.Role.WALK_SURFACE,
		Vector2.ZERO, Vector2(1.5, 0.75), 0.0, 3.0, 3.2,
		"platform", "platform.owner", "village.walk")))
	assert_true(index.add(_volume(VillageOccupancy.Role.WALK_GUARD,
		Vector2(0.8, 0.0), Vector2(0.75, 0.08), 0.0, 3.0, 4.4,
		"stair.rail", "stair.owner", "village.walk")),
		"a stair rail may meet its connected platform across an owner seam")
	assert_false(index.can_add(_volume(VillageOccupancy.Role.WALK_GUARD,
		Vector2.ZERO, Vector2(0.75, 0.08), 0.0, 3.0, 4.4,
		"foreign.rail", "foreign", "other.walk")))
	assert_false(index.can_add(_volume(VillageOccupancy.Role.SOLID,
		Vector2.ZERO, Vector2(0.5, 0.5), 0.0, 3.0, 4.4,
		"ordinary.solid", "ordinary", "village.walk")),
		"generic solids cannot borrow the guard-floor contact contract")

func test_one_owned_rigid_network_unions_railing_corners() -> void:
	var index := VillageOccupancy.new()
	assert_true(index.add(_volume(VillageOccupancy.Role.SOLID,
		Vector2.ZERO, Vector2(1.0, 0.08), 0.0, 3.0, 4.0,
		"railing.a", "owned.railing")))
	assert_true(index.add(_volume(VillageOccupancy.Role.SOLID,
		Vector2(0.92, 0.92), Vector2(1.0, 0.08), PI * 0.5,
		3.0, 4.0, "railing.b", "owned.railing")))
	assert_false(index.can_add(_volume(VillageOccupancy.Role.SOLID,
		Vector2(0.92, 0.92), Vector2(1.0, 0.08), PI * 0.5,
		3.0, 4.0, "railing.other", "other.railing")))
