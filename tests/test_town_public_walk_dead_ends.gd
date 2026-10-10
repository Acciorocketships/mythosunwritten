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


func _clearing_town() -> WarrenSpatialPlan:
	# The shipped table plus clearing_count 1 (its default is 0).
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	program.town_odds = program.town_odds.with_overrides({&"clearing_count": 1.0})
	return WarrenVolumetricSolver.generate(103, {}, program,
		WarrenVillageScaleProfile.for_id(&"standard"))


func test_a_clearing_court_is_a_destination() -> void:
	# 103:standard grows one 4-cell green: its 12-cell walk ring is under the
	# overlook threshold, but the court itself is a reason to walk there.
	var spatial := _clearing_town()
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null: return
	var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
	var clearings := source.plots.filter(func(p: Dictionary) -> bool:
		return WarrenPlotReservations.is_clearing_plot(p))
	assert_gt(clearings.size(), 0, "the fixture grows a clearing")
	var fabric := spatial.compiled_fabric_cache()
	var destinations := PublicWalkAudit.destination_cells(fabric, spatial)
	for plot: Dictionary in clearings:
		var column: Vector2i = plot.cells[0]
		assert_true(destinations.has(Vector3i(column.x * 2, int(plot.floor), column.y * 2)),
			"%s counts as a destination" % plot.id)
	assert_eq(PublicWalkAudit.audit(fabric, spatial).summary.dead_end_nodes, 0)


func test_a_leaf_far_from_any_clearing_still_reports() -> void:
	# The clearing rule adds destinations only on clearing cells: a railed
	# deck elsewhere with no door is still peeled in the same town.
	var spatial := _clearing_town()
	assert_not_null(spatial)
	if spatial == null: return
	var fabric := spatial.compiled_fabric_cache()
	var realm := fabric.public_realm
	var far := Vector3i(900, 0, 900)
	var cells: Array[Vector3i] = []
	for dx in 2:
		for dz in 2:
			cells.append(far + Vector3i(dx, 0, dz))
	var anchor: PublicRealmNode = realm.nodes[0]
	var anchor_cell: Vector3i = anchor.surface_cells[0]
	var deck := PublicRealmNode.new(&"far_deck", PublicRealmNode.EpisodeKind.TERRACE,
		PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,
		PublicRealmNode.AirRealm.EXTERIOR, PublicRealmNode.CoverPolicy.OPEN,
		cells, [], 0, 0, false, false)
	realm.nodes.append(deck)
	var edge := PublicRealmEdge.new(&"far_e", anchor.stable_id, &"far_deck",
		PublicRealmEdge.TransitionKind.LEVEL)
	edge.add_seam(anchor_cell, far)
	edge.add_seam(anchor_cell + Vector3i(0, 0, 1), far + Vector3i(0, 0, 1))
	realm.edges.append(edge)
	var dead: Array = PublicWalkAudit.audit(fabric, spatial).dead_ends
	assert_eq(dead.size(), 1, "only the far deck: %s" % [dead])
	assert_eq(dead[0].id, &"far_deck")


func test_a_leaf_beside_a_clearing_that_does_not_enter_it_still_reports() -> void:
	# Only surface cells ON a clearing count: a railed deck one step beside a
	# clearing, reached only from elsewhere, is still a pathway to nowhere.
	var spatial := _clearing_town()
	assert_not_null(spatial)
	if spatial == null: return
	var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
	var fabric := spatial.compiled_fabric_cache()
	var destinations := PublicWalkAudit.destination_cells(fabric, spatial)
	var surfaced := {}
	for node: PublicRealmNode in fabric.public_realm.nodes:
		for cell: Vector3i in node.surface_cells:
			surfaced[cell] = true
	var origin := Vector3i.MAX
	for plot: Dictionary in source.plots:
		if not WarrenPlotReservations.is_clearing_plot(plot): continue
		for column: Vector2i in plot.cells:
			for step: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
				var candidate := Vector3i(column.x * 2 + step.x, int(plot.floor), column.y * 2 + step.y)
				var free := true
				for dx in 2:
					for dz in 2:
						var cell := candidate + Vector3i(dx, 0, dz)
						free = free and not destinations.has(cell) and not surfaced.has(cell)
				if free:
					origin = candidate
					break
			if origin != Vector3i.MAX: break
		if origin != Vector3i.MAX: break
	assert_ne(origin, Vector3i.MAX, "a free 2x2 beside the clearing")
	if origin == Vector3i.MAX: return
	var cells: Array[Vector3i] = []
	for dx in 2:
		for dz in 2:
			cells.append(origin + Vector3i(dx, 0, dz))
	var realm := fabric.public_realm
	var anchor: PublicRealmNode = realm.nodes[0]
	var anchor_cell: Vector3i = anchor.surface_cells[0]
	var deck := PublicRealmNode.new(&"beside_deck", PublicRealmNode.EpisodeKind.TERRACE,
		PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,
		PublicRealmNode.AirRealm.EXTERIOR, PublicRealmNode.CoverPolicy.OPEN,
		cells, [], 0, 0, false, false)
	realm.nodes.append(deck)
	var edge := PublicRealmEdge.new(&"beside_e", anchor.stable_id, &"beside_deck",
		PublicRealmEdge.TransitionKind.LEVEL)
	edge.add_seam(anchor_cell, origin)
	edge.add_seam(anchor_cell + Vector3i(0, 0, 1), origin + Vector3i(0, 0, 1))
	realm.edges.append(edge)
	var dead: Array = PublicWalkAudit.audit(fabric, spatial).dead_ends
	assert_eq(dead.size(), 1, "only the beside deck: %s" % [dead])
	if dead.size() == 1:
		assert_eq(dead[0].id, &"beside_deck")
