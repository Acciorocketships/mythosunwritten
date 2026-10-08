extends GutTest

const Old := preload("res://tests/fixtures/town_old_look.gd")  # pre-taste knob values; see that file
## Town taste knobs (Oct 7) task 2: green courts (the plaza and green
## clearings) may drop their one-cell walking ring. Ring chance 1.0 (the
## default) reproduces the ringed planting exactly; ring chance 0 plants the
## lawn up to the court edges that face built mass while every landing stays
## walk and joined.

const LawnEdgeAudit := preload("res://tests/fixtures/court_lawn_edge_audit.gd")
const FOUR := [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]

static var _cache: Dictionary = {}


func _spatial(seed_value: int, scale: StringName, overrides: Dictionary) -> WarrenSpatialPlan:
	var key := "%d/%s/%s" % [seed_value, scale, var_to_str(overrides)]
	if _cache.has(key):
		return _cache[key]
	var profile := WarrenVillageScaleProfile.for_id(scale)
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	program.town_odds = program.town_odds.with_overrides(Old.merge(overrides))
	var spatial := WarrenVolumetricSolver.generate(seed_value, {}, program, profile)
	_cache[key] = spatial
	return spatial


func _source(spatial: WarrenSpatialPlan) -> WarrenMazeSourcePlan:
	return spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan


func _floor(plot: Dictionary) -> Dictionary:
	var out := {}
	for column: Vector2i in WarrenMazeSourcePlan.deck_flat_columns(plot):
		for cell: Vector3i in WarrenVolumetricSolver._fine_square(
				Vector3i(column.x, int(plot.floor), column.y)):
			out[cell] = true
	return out


func _ringed_reference(source: WarrenMazeSourcePlan) -> Dictionary:
	## The pre-knob rule, frozen: eight-neighbour erosion of every green court,
	## then every plot's landing square cleared.
	var out := {}
	for plot: Dictionary in source.plots:
		if not WarrenPlotReservations.is_green_court(plot): continue
		var floor_cells := _floor(plot)
		for cell: Vector3i in floor_cells:
			var interior := true
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					interior = interior and floor_cells.has(cell + Vector3i(dx, 0, dz))
			if interior: out[cell] = true
	for plot: Dictionary in source.plots:
		for cell: Vector3i in WarrenVolumetricSolver._fine_square(plot.door_walk):
			out.erase(cell)
	return out


func _greens(source: WarrenMazeSourcePlan) -> Array:
	return source.plots.filter(func(p: Dictionary) -> bool:
		return WarrenPlotReservations.is_green_court(p))


func test_default_rings_every_green_and_reproduces_the_planting() -> void:
	var spatial := _spatial(53, &"grand", {&"clearing_count": 3.0})
	assert_not_null(spatial)
	var source := _source(spatial)
	assert_gte(_greens(source).size(), 2, "53 grand carries the plaza and a green clearing")
	for plot: Dictionary in _greens(source):
		assert_false(plot.has("ring"), "%s is ringed by default and carries no flag" % plot.id)
	assert_eq(WarrenVolumetricSolver._maze_court_planting_cells(spatial.source_volume),
		_ringed_reference(source))
	assert_true(WarrenVolumetricSolver._maze_ringless_court_cells(spatial.source_volume).is_empty())


func _assert_ringless(seed_value: int, scale: StringName, overrides: Dictionary,
		want_clearing: bool) -> void:
	var spatial := _spatial(seed_value, scale, overrides)
	assert_not_null(spatial, "%d/%s builds ringless" % [seed_value, scale])
	if spatial == null: return
	var source := _source(spatial)
	var planting := WarrenVolumetricSolver._maze_court_planting_cells(spatial.source_volume)
	var ringless := WarrenVolumetricSolver._maze_ringless_court_cells(spatial.source_volume)
	var greens := _greens(source).filter(func(p: Dictionary) -> bool:
		return not bool(p.get("ring", true)))
	assert_gt(greens.size(), 0, "%d/%s has a ringless green" % [seed_value, scale])
	if want_clearing:
		assert_gt(greens.filter(func(p: Dictionary) -> bool:
			return WarrenPlotReservations.is_clearing_plot(p)).size(), 0,
			"%d/%s has a ringless clearing" % [seed_value, scale])
	var reaches_edge := false
	for plot: Dictionary in greens:
		var floor_cells := _floor(plot)
		var walk := {}
		for cell: Vector3i in floor_cells:
			assert_true(ringless.has(cell))
			if not planting.has(cell): walk[cell] = true
			elif not reaches_edge:
				for step: Vector3i in FOUR:
					reaches_edge = reaches_edge or not floor_cells.has(cell + step)
		# Every landing square in the court is walk.
		for other: Dictionary in source.plots:
			for cell: Vector3i in WarrenVolumetricSolver._fine_square(other.door_walk):
				assert_false(planting.has(cell), "%s landing under %s's lawn" % [other.id, plot.id])
		# One connected walk inside the court, reaching the court's own door.
		assert_gt(walk.size(), 0)
		var start: Vector3i = walk.keys()[0]
		var seen := {start: true}
		var frontier: Array[Vector3i] = [start]
		while not frontier.is_empty():
			var cell: Vector3i = frontier.pop_back()
			for step: Vector3i in FOUR:
				if walk.has(cell + step) and not seen.has(cell + step):
					seen[cell + step] = true
					frontier.append(cell + step)
		assert_eq(seen.size(), walk.size(), "%s walk is one component" % plot.id)
		var door_fine := WarrenVolumetricSolver._fine_square(plot.door_walk)
		var meets_door := false
		for cell: Vector3i in walk:
			if door_fine.has(cell):
				meets_door = true
			for step: Vector3i in FOUR:
				if door_fine.has(cell + step):
					meets_door = true
		assert_true(meets_door, "%s walk meets its entrance" % plot.id)
	assert_true(reaches_edge, "%d/%s plants a court edge" % [seed_value, scale])
	# The fabric compiles: the plaza declaration and surface plan accept it.
	var fabric := spatial.compiled_fabric_cache()
	assert_not_null(fabric, "%d/%s ringless fabric compiles" % [seed_value, scale])
	if fabric == null: return
	# Final fabric: no lawn edge beside an unguarded drop, no rail between a
	# walk and the lawn it borders.
	var edges := LawnEdgeAudit.audit(spatial, fabric)
	assert_gt(int(edges.edge_lawn_faces), 0)
	assert_eq(edges.unguarded, [], "%d/%s lawn edge over a drop" % [seed_value, scale])
	assert_eq(edges.railed_walk, [], "%d/%s rail between walk and lawn" % [seed_value, scale])
	gut.p("%d/%s lawn edge faces %d, on walk %d" % [seed_value, scale,
		int(edges.edge_lawn_faces), int(edges.edge_lawn_on_walk)])


func test_ringless_clearings_103_standard() -> void:
	_assert_ringless(103, &"standard", {&"clearing_count": 3.0,
		&"clearing_ring_chance": 0.0, &"plaza_ring_chance": 0.0}, true)


func test_ringless_clearings_53_grand() -> void:
	_assert_ringless(53, &"grand", {&"clearing_count": 3.0,
		&"clearing_ring_chance": 0.0, &"plaza_ring_chance": 0.0}, true)


func test_ringless_edge_planting_is_accepted_only_for_ringless_cells() -> void:
	var plan := SettlementFabricPlan.new(&"rings")
	var cells := {}
	for x in 3:
		for z in 3:
			cells[Vector3i(x, 0, z)] = true
	var edge := {Vector3i(0, 0, 1): true}
	assert_false(SettlementFabricPlan.new(&"rings").set_planned_plaza(cells, edge),
		"a ringed green may not plant its edge")
	assert_true(plan.set_planned_plaza(cells, edge, edge),
		"a ringless green may plant its edge")
