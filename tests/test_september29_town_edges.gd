extends GutTest

## September 29 town review, "edges" stream (seed 2697992464, photo 7). Owner:
## "the outside of the towns appear very bare. there are often multi-storey
## buildings lining the outside of the town, so it's just a sheer face. it
## would be nice if the building height went down to single-storey".
##
## The massif already descends to a one-storey rim, but houses were not held
## to it: a parcel reaching inward kept its whole storey roll on the lawn,
## skyline towers stood on the rim, landmarks were always two or three
## storeys, and a shifted upper floorplate could overhang a low rim house.
## `tests/fixtures/town_perimeter_profile.gd` measures the built kit masses
## along every exterior edge; baseline (71398f7c) photo town A had 15 rim
## edges over two storeys and 11 multi-storey rim houses.
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
const PROFILE := preload("res://tests/fixtures/town_perimeter_profile.gd")
## The two photographed towns (A: photos 1-5/7/9, B: photos 6/8/10) and a
## standard/large pair.
const TOWNS := [[1260018864828801968, &"compact"],
	[1998423929946073270, &"compact"], [3, &"standard"], [6, &"large"]]

static var _towns: Array = []


func _measured_towns() -> Array:
	if not _towns.is_empty():
		return _towns
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for job: Array in TOWNS:
		var source := WarrenMazeSitePlanner.plan(int(job[0]), {},
			WarrenVillageScaleProfile.for_id(job[1]), &"", false)
		assert_not_null(source, "%s/%s plans" % job)
		if source == null:
			continue
		var spatial := FROZEN.spatial(source, program)
		var built := KitVillageBuildings.build(spatial,
			spatial.compiled_fabric_cache(), SuntailBuildingKit.create())
		_towns.append({"id": "%d/%s" % job, "source": source,
			"asset_outcomes": spatial.audit.get("maze_asset_outcomes", []),
			"metric": PROFILE.measure(source, built.masses)})
	return _towns


func test_no_wall_on_the_lawn_rises_past_one_storey_on_its_plinth() -> void:
	for town: Dictionary in _measured_towns():
		var metric: Dictionary = town.metric
		assert_gt(int(metric.edges), 0, "%s has an exterior edge" % town.id)
		assert_eq(int(metric.rim_over), 0,
			"%s: rim walls stand at most two storeys (one storey on the rim terrace) above the lawn: %s"
				% [town.id, metric.offenders])


func test_rim_houses_are_single_storey() -> void:
	for town: Dictionary in _measured_towns():
		var metric: Dictionary = town.metric
		assert_eq(int(metric.rim_tall_house), 0,
			"%s: every house on the rim is one storey above its own floor: %s"
				% [town.id, metric.offenders])


func test_the_ring_behind_the_rim_climbs_one_storey() -> void:
	for town: Dictionary in _measured_towns():
		var metric: Dictionary = town.metric
		assert_eq(int(metric.inner_over), 0,
			"%s: the ring 8 m inside the rim stands at most three storeys: %s"
				% [town.id, metric.offenders])


func test_the_town_meets_the_lawn_without_a_stone_rampart() -> void:
	## Follow-up: after the height cap the rim still stood on the one-storey
	## rim terrace -- a stone course around the whole town (merged head
	## bc485052: 233 of 812 edges over ten towns). A perimeter lane at grade on
	## the second ring (`WarrenMazeCarver._carve_perimeter_lanes`) lets
	## single-storey cottages stand on the lawn.
	var lanes := 0
	for town: Dictionary in _measured_towns():
		var metric: Dictionary = town.metric
		lanes += int(metric.perimeter_lane_cells)
		assert_true(float(metric.rampart) <= 0.10 * float(metric.edges),
			"%s: at most 10%% of the rim is a storey of retaining stone (%d of %d)"
				% [town.id, metric.rampart, metric.edges])

	assert_gt(lanes,0,"The corpus still exercises perimeter lanes; direct-access towns need not retain redundant circuits.")


func test_landmarks_keep_their_sites_beside_the_lane() -> void:
	## Second follow-up: laying the lane before the plot reservation took the
	## flat at-grade edge band the landmark prefabs are sited on (38-town
	## corpus 58 -> 20 landmarks). The carver now holds the landmark sites the
	## reservation would choose (`WarrenMazeCarver._preview_reserved_columns`)
	## and the lane detours round them. The four towns carried 7 landmarks on
	## f1e5f619 (before the lane) and 3 with the lane laid first.
	## October 1 reserves greens before boring. The old aggregate of seven
	## measured a different buildable domain: all three old 3/standard sites
	## overlap new greens. Check the lane's actual contract instead: preserve
	## every valid site held before it was carved, and realize every admitted
	## landmark. This must fail if a lane steals a site, even if another town
	## happens to supply an extra prefab and hides that loss in a total.
	var held_count := 0
	for town: Dictionary in _measured_towns():
		var source: WarrenMazeSourcePlan = town.source
		var held: Array = source.audit.get("preselected_landmarks", [])
		held_count += held.size()
		for site: Dictionary in held:
			assert_true(source.plots.any(func(plot: Dictionary) -> bool:
				return plot.kind == WarrenMazeSourcePlan.PLOT_ASSET \
					and plot.cells == site.cells and plot.floor == site.floor \
					and plot.top == site.top),
				"%s: the lane preserves complete site %s" % [town.id, site.id])
		for plot: Dictionary in source.plots:
			if plot.kind != WarrenMazeSourcePlan.PLOT_ASSET:
				continue
			# Later streets may offer a better doorway on the same whole site.
			assert_true(source.passage_kinds.has(plot.door_walk),
				"%s: landmark %s keeps a public address" % [town.id, plot.id])
			assert_true((town.asset_outcomes as Array).any(func(outcome: Dictionary) -> bool:
				return outcome.id == plot.id and bool(outcome.placed) \
					and outcome.door_walk == plot.door_walk),
				"%s: admitted landmark %s is built" % [town.id, plot.id])

	assert_gt(held_count,0,"The corpus exercises held landmark sites even when a town has no suitable site.")


func test_edge_profile_is_a_plot_rule() -> void:
	## The source plan itself holds the profile, before any kit realisation:
	## no house plot on the two edge rings rises past its ring, measured from
	## its floor and from the column's ground.
	for town: Dictionary in _measured_towns():
		var source: WarrenMazeSourcePlan = town.source
		for plot: Dictionary in source.plots:
			if plot.kind != WarrenMazeSourcePlan.PLOT_HOUSE \
					or String(plot.id).begins_with("bridge."):
				continue
			var cells: Array = plot.cells
			var cap := WarrenPlotPlanner.edge_storey_cap(source, cells,
				int(plot.floor))
			if cap < 0:
				continue
			var storeys := (int(plot.top) - int(plot.floor)
				- WarrenBuildingParcel.ROOF_RESERVATION_BANDS) \
				/ WarrenBuildingParcel.STOREY_BANDS
			assert_true(storeys <= cap, "%s: %s stands %d storeys, edge cap %d"
				% [town.id, plot.id, storeys, cap])
