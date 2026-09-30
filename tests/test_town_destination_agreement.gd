extends GutTest

## September 27 judging, second pass: the source's destination pruning keeps a
## street because a door opens onto it, so construction must realize that door.
## Each seed below (production size roll) once shipped a pathway to nowhere
## because a counted door was dropped later:
##   132 141 212 258 281 301 324  a street was kept only for the bridge-house
##                                over it, whose endpoint door construction closes
##   184 330 358                  bridge compound reserved a house storey or a
##                                prefab's roof clearance
##   372                          base tower merge swallowed a door that opened
##                                onto a different landing
const SEEDS := [132, 141, 212, 258, 281, 301, 324, 184, 330, 358, 372]

var _program: SettlementFabricProgram


func before_all() -> void:
	_program = SettlementFabricProgram.compile(EnvironmentCatalog.load_default())


func test_bridges_stand_only_over_surviving_streets() -> void:
	# Bridges are allocated after destination pruning, so every allocated
	# bridge's span is still public street and no street survived for a bridge.
	for seed_value: int in [132, 141, 212, 258, 281, 301, 324]:
		var source := WarrenMazeSitePlanner.plan(seed_value, {},
			WarrenVillageScaleProfile.select(seed_value), &"", false)
		assert_not_null(source, "%d did not plan" % seed_value)
		if source == null:
			continue
		for span: Array in source.excavation.bridge_spans:
			for cell: Vector3i in span:
				assert_true(source.passage_kinds.has(cell),
					"%d bridge span cell %s is not a street" % [seed_value, cell])


func test_bridge_compounds_stand_clear_of_other_plots() -> void:
	for seed_value: int in [184, 330, 358]:
		var source := WarrenMazeSitePlanner.plan(seed_value, {},
			WarrenVillageScaleProfile.select(seed_value), &"", false)
		assert_not_null(source, "%d did not plan" % seed_value)
		if source == null:
			continue
		var seeded := source.excavation.bridge_span_audit.get("seeded", []) as Array
		for plot: Dictionary in source.plots:
			if plot.kind != WarrenMazeSourcePlan.PLOT_BRIDGE:
				continue
			var index := int(String(plot.id).trim_prefix("bridge."))
			var columns: Array = (plot.cells as Array).duplicate()
			for group: Array in (seeded[index] as Dictionary).get(
					"endpoint_groups", []):
				columns.append_array(group)
			for other: Dictionary in source.plots:
				# The storeys a house cannot give up: up to its doorway storey.
				var required_top := int(other.top) + 1 \
					if other.kind == WarrenMazeSourcePlan.PLOT_ASSET \
					else mini(int(other.top), (other.door_walk as Vector3i).y + 2)
				if other.id == plot.id or int(other.floor) >= int(plot.top) \
						or required_top <= int(plot.floor):
					continue
				for column: Vector2i in columns:
					assert_false((other.cells as Array).has(column),
						"%d %s compound column %s is %s's storey" % [seed_value,
							plot.id, column, other.id])


func test_every_counted_door_is_built() -> void:
	for seed_value: int in SEEDS:
		var plan := WarrenVolumetricSolver.generate(seed_value, {}, _program,
			WarrenVillageScaleProfile.select(seed_value))
		assert_not_null(plan, "%d: %s" % [seed_value,
			WarrenVolumetricSolver.last_failure])
		if plan == null:
			continue
		var dead: Array = PublicWalkAudit.audit(plan.compiled_fabric_cache(), plan) \
			.dead_ends
		assert_eq(dead.size(), 0, "%d dead ends %s" % [seed_value, dead])
