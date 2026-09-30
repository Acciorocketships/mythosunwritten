extends GutTest

## September 27 owner review (seed 2697992464, photos 5 and 11): public
## pathways ended in a single-cell railed deck that led nowhere. Every public
## walk surface must lead to a doorway, a portal, the market or around a loop.
const PHOTO_TOWNS := [
	# photo 5, player (319.5, 21.1, 1083.9): super cell (0, 1)
	[1260018864828801968, &"compact"],
	# photo 11, player (-211.6, 18.1, 1192.4): super cell (-1, 1)
	[85830433957479026, &"compact"],
]

## Zero: construction now keeps every door the source's destination pruning
## relied on (see the corpus test below).
const CORPUS_SUBSET_DEAD_END_CEILING := 0

var _program: SettlementFabricProgram


func before_all() -> void:
	_program = SettlementFabricProgram.compile(EnvironmentCatalog.load_default())


func _dead_ends(city_seed: int, scale: StringName) -> Array:
	var plan := WarrenVolumetricSolver.generate(city_seed, {}, _program,
		WarrenVillageScaleProfile.for_id(scale))
	assert_not_null(plan, WarrenVolumetricSolver.last_failure)
	if plan == null:
		return ["unsealed"]
	return PublicWalkAudit.audit(plan.compiled_fabric_cache(), plan).dead_ends


func test_photographed_decks_lead_somewhere() -> void:
	for town: Array in PHOTO_TOWNS:
		var dead := _dead_ends(int(town[0]), town[1])
		assert_eq(dead.size(), 0, "%d/%s dead ends %s" % [town[0], town[1], dead])


func test_corpus_has_no_pathways_to_nowhere() -> void:
	# The source withdraws every public leaf that has no destination, and the
	# destinations it counts are exactly the doors construction realizes: no
	# door on a flight's tread (bridge endpoints included), no base-tower merge
	# that swallows a door onto a different landing, and no bridge compound
	# reserved over a house storey or a prefab's clearance. 226 corpus-wide
	# before September 27.
	var total := 0
	var found: Array[String] = []
	for seed_value in [1, 2, 3, 4, 5, 6]:
		for scale: StringName in WarrenVillageScaleProfile.IDS:
			var dead := _dead_ends(seed_value, scale)
			total += dead.size()
			if not dead.is_empty():
				found.append("%d/%s %s" % [seed_value, scale, dead])
	assert_lte(total, CORPUS_SUBSET_DEAD_END_CEILING, "\n".join(found))


func test_audit_peels_a_railed_leaf_deck() -> void:
	# The audit itself: a stair to a one-cell deck with no door is peeled,
	# a doorway landing is kept.
	var realm := SectionalPublicRealmPlan.new(&"t", PublicRealmNode.AirRealm.EXTERIOR)
	var cells := func(origin: Vector3i) -> Array[Vector3i]:
		var out: Array[Vector3i] = []
		for dx in 2:
			for dz in 2:
				out.append(origin + Vector3i(dx, 0, dz))
		return out
	var gate := PublicRealmNode.new(&"gate", PublicRealmNode.EpisodeKind.STREET,
		PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET,
		PublicRealmNode.AirRealm.EXTERIOR, PublicRealmNode.CoverPolicy.OPEN,
		cells.call(Vector3i.ZERO), [], 0, 0, false, true)
	var deck := PublicRealmNode.new(&"deck", PublicRealmNode.EpisodeKind.TERRACE,
		PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,
		PublicRealmNode.AirRealm.EXTERIOR, PublicRealmNode.CoverPolicy.OPEN,
		cells.call(Vector3i(2, 0, 0)), [], 0, 0, false, false)
	realm.nodes.append(gate)
	realm.nodes.append(deck)
	var edge := PublicRealmEdge.new(&"e", &"gate", &"deck",
		PublicRealmEdge.TransitionKind.LEVEL)
	edge.add_seam(Vector3i(1, 0, 0), Vector3i(2, 0, 0))
	edge.add_seam(Vector3i(1, 0, 1), Vector3i(2, 0, 1))
	realm.edges.append(edge)
	var fabric := SettlementFabricPlan.new(&"t")
	fabric.public_realm = realm
	assert_eq(PublicWalkAudit.audit(fabric).dead_ends.size(), 1)
