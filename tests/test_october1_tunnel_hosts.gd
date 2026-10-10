extends GutTest
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")

func test_cover_reservations_exclude_unrelated_residual_rooms() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i.ZERO, Vector3i(4, 4, 4))
	var cell := Vector3i.ONE
	var owner := &"spatial.skywalk.reserve.maze_over.over.01"
	var protected := {cell: {owner: true}}
	assert_true(WarrenVolumetricSolver._residual_feature_protected(grid, cell, protected))
	assert_false(WarrenVolumetricSolver._residual_feature_protected(grid, cell,
		protected, &"spatial.skywalk.reserve.maze_over."))
	protected[cell][&"spatial.feature.other"] = true
	assert_true(WarrenVolumetricSolver._residual_feature_protected(grid, cell,
		protected, &"spatial.skywalk.reserve.maze_over."))

func test_final_tunnel_covers_are_whole_or_absent() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var proposed := 0
	var complete := 0
	for job: Array in [[7,&"compact"],[9,&"compact"],[4,&"large"],[7,&"large"],[9,&"large"],
			[1260018864828801968,&"compact"],[1260018864828801968,&"standard"],
			[12,&"grand"]]:
		var source := WarrenMazeSitePlanner.plan(job[0],{},WarrenVillageScaleProfile.for_id(job[1]),&"",false)
		assert_not_null(source)
		if source == null: continue
		var spatial := FROZEN.spatial(source,program)
		assert_not_null(spatial)
		if spatial == null: continue
		var rooms := WarrenVolumetricSolver.building_private_cells(spatial.buildings)
		for plot: Dictionary in source.plots:
			if plot.kind != WarrenMazeSourcePlan.PLOT_OVER: continue
			proposed += 1
			var count := 0
			var expected := 0
			for column: Vector2i in plot.cells:
				for band in range(int(plot.floor),int(plot.floor)+WarrenBuildingParcel.STOREY_BANDS):
					for cell: Vector3i in WarrenVolumetricSolver._fine_square(Vector3i(column.x,band,column.y)):
						expected += 1
						count += int(rooms.has(cell))
			assert_true(count == 0 or count == expected,
				"%s/%s %s: all %d room cells or none, got %d" % [job[0],job[1],plot.id,expected,count])
			complete += int(count == expected)
		var fabric := spatial.compiled_fabric_cache()
		var built := KitVillageBuildings.build(spatial,fabric,SuntailBuildingKit.create())
		var audit := KitFloatingMassAudit.audit(spatial,fabric,built.masses)
		assert_eq(audit.unborne_crown_cells,[] as Array[Vector3i])
		assert_eq(audit.floating_storey_cells,[] as Array[Vector3i])
	assert_gt(proposed,0,"exercise actual source cover reservations")
	assert_gt(complete,0,"preserve genuinely supported complete covers")

func test_early_supported_spans_survive_finished_composition() -> void:
	# The established 24-town corpus built eight before early load-path
	# reservation and twelve afterward. Direct cottage entrances withdraw the
	# unused12/compact street and its bridge, leaving eleven. Allocating before
	# pruning was tested and rejected: it kept invalid endpoint doors. Count
	# supported surviving spans, without retaining purposeless paths for one.
	# See QA cottage-access and bridge-destination-validation.
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var total := 0
	var jobs: Array = []
	for profile_id: StringName in [&"compact", &"standard", &"large"]:
		for seed_value: int in [3,5,6,7,9,10,12,1260018864828801968]:
			jobs.append([seed_value,profile_id])
	for job: Array in jobs:
		var spatial := WarrenVolumetricSolver.generate(job[0],{},program,
			WarrenVillageScaleProfile.for_id(job[1]))
		assert_not_null(spatial)
		if spatial == null: continue
		for outcome: Dictionary in spatial.audit.get("maze_bridge_outcomes",[]):
			total += int(outcome.outcome == "stamped")
		var fabric := spatial.compiled_fabric_cache()
		var built := KitVillageBuildings.build(spatial,fabric,SuntailBuildingKit.create())
		var audit := KitFloatingMassAudit.audit(spatial,fabric,built.masses)
		assert_eq(audit.count,0,"complete supported rooms at both ends and over the street")
	print("Finished bridge houses across 24 towns: ",total)
	assert_gte(total,11,"restored bridge houses survive final composition across the corpus")
