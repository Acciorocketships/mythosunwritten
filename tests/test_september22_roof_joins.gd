extends GutTest
## September 22 manual review, photos 1/5: touching compact roofs at one eave
## datum must connect. A branch crown meeting a host's side continues to the
## host ridge (its flush end buried under the host crown), forming valleys.
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
const SOURCE := "res://tests/fixtures/september22/town-e-source.txt"
const ROOF := "spatial.roof.spatial."
static var _fabric: SettlementFabricPlan


func _plan() -> SettlementFabricPlan:
	if _fabric == null:
		var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
		_fabric = FROZEN.spatial(FROZEN.read(SOURCE), program).compiled_fabric_cache()
	return _fabric


func _run(unit_suffix: String) -> Dictionary:
	for run: Dictionary in _plan().continuous_roof_plan.compiled_runs:
		if String(run.unit_id) == ROOF + unit_suffix: return run
	return {}


func _reach(prefixes: Array, axis_x: bool, toward_positive: bool) -> float:
	## Furthest realized roof extent of a roof chain along one axis direction.
	var best := -INF if toward_positive else INF
	for placement: Dictionary in _plan().expanded_placements():
		var owned := false
		for prefix: String in prefixes:
			owned = owned or String(placement.get("stable_id", "")).begins_with(ROOF + prefix)
		if not owned: continue
		var bounds := placement.bounds as AABB
		var value := (bounds.end.x if toward_positive else bounds.position.x) if axis_x \
			else (bounds.end.z if toward_positive else bounds.position.z)
		best = maxf(best, value) if toward_positive else minf(best, value)
	return best


func _assert_branch_reaches_ridge(branch: String, host: String, toward_positive: bool,
		owners: Array = []) -> void:
	var branch_run := _run(branch)
	var host_run := _run(host)
	assert_false(branch_run.is_empty() or host_run.is_empty(), "both roofs exist")
	if branch_run.is_empty() or host_run.is_empty(): return
	var ridge := (float(host_run.cross_min) + float(host_run.cross_max)) * 0.5
	var reach := _reach(owners if not owners.is_empty() else [branch], bool(branch_run.axis_x), toward_positive)
	var gap := (ridge - reach) if toward_positive else (reach - ridge)
	assert_lt(gap, 0.01, "%s crown continues to the %s ridge (gap %.3f)" % [branch, host, gap])


func test_perpendicular_branches_continue_to_host_ridge() -> void:
	# Photo 1 lower left: house.012 (ridge X) meets maze_back.05's east wall.
	_assert_branch_reaches_ridge("parcel.maze.house.012.part00.room00", "maze_back.05.room00", false)
	# Photo 1/5: its east end meets house.015's west wall.
	_assert_branch_reaches_ridge("parcel.maze.house.012.part00.room00", "parcel.maze.house.015.part00.room00", true)
	# Photo 1 centre: the house.011/013 chain meets house.012's north wall.
	_assert_branch_reaches_ridge("parcel.maze.house.013.part00.room00.tile01", "parcel.maze.house.012.part00.room00", true,
		["parcel.maze.house.011.part00.room00", "parcel.maze.house.013.part00.room00"])


func test_joined_roofs_prove_their_realization() -> void:
	assert_eq(_plan()._continuous_roof_realization_conflict(), "")


func test_square_leaf_turns_into_longer_parallel_neighbour() -> void:
	# Photo 5: the 6 m square maze_back.03 stood beside the 12 m house.007 as a
	# second parallel gable. It turns its ridge and continues to house.007's ridge.
	var host := _run("parcel.maze.house.007.part00.room00")
	var leaf := _run("maze_back.03.room00")
	assert_false(host.is_empty() or leaf.is_empty(), "both roofs exist")
	if host.is_empty() or leaf.is_empty(): return
	assert_false(bool(host.axis_x), "the host ridge runs along Z")
	var ridge := (float(host.cross_min) + float(host.cross_max)) * 0.5
	var reach := _reach(["maze_back.03.room00"], true, false)
	assert_lt(reach - ridge, 0.01, "turned leaf crown reaches the host ridge (gap %.3f)" % (reach - ridge))
	var turned := 0
	for placement: Dictionary in _plan().expanded_placements():
		if String(placement.get("stable_id", "")).ends_with("/turned"): turned += 1
	assert_gt(turned, 0, "the leaf's dormer turns with its crown")


func test_modular_roof_continues_over_its_compact_double_pile() -> void:
	# Photo 4: two 12 m compact crowns side by side exactly fill the west wall of
	# the wider modular (teal) roof at the same eave datum. One roof covers the block.
	var modular := _run("maze_back.01.room00")
	assert_false(modular.is_empty(), "the modular roof exists")
	if modular.is_empty(): return
	var reach := _reach(["maze_back.01.room00"], true, false)
	assert_lt(reach, 5.25 + 0.5, "modular crown continues to the block's west wall (reach %.3f)" % reach)
	for placement: Dictionary in _plan().expanded_placements():
		var id := String(placement.get("stable_id", ""))
		assert_false(id.begins_with(ROOF + "maze_back.00.room00/") \
			or id.begins_with(ROOF + "parcel.maze.house.006.part00.room00/"),
			"the double pile's separate roof is withdrawn: %s" % id)
