extends GutTest
const FROZEN = preload("res://tests/fixtures/frozen_maze_source.gd")

var spatial: WarrenSpatialPlan
var program: FeatureProgram
var fabric: SettlementFabricPlan
var skin: Dictionary
var pose: Transform3D

func before_all() -> void:
	var source := FROZEN.read("res://docs/qa/2026-09-18-manual/83-cliff-fresh-world/town-P02/current-source.txt")
	program = FeatureProgram.compile(EnvironmentCatalog.load_default())
	spatial = FROZEN.spatial(source, program.villages.settlement_fabric_program)
	fabric = spatial.compiled_fabric_cache()
	skin = SettlementFabricAssembler.maze_ground_skin_transaction(fabric)
	pose = FileAccess.open("res://docs/qa/2026-09-18-manual/83-cliff-fresh-world/town-P02/before-payload.bin", FileAccess.READ).get_var().transform

func test_photo_retained_garden_is_inside_the_towns_external_road_bounds() -> void:
	var bounds := VillageWarrenFabricSolver._local_bounds(fabric)
	var missed := 0
	for cell: Vector3i in [Vector3i(10,1,-4), Vector3i(11,1,-4), Vector3i(10,1,-3), Vector3i(11,1,-3)]:
		assert_true(skin.retained.has(cell))
		var centre := Vector3(cell) * FabricRecipe.CELL_SIZE
		for offset: Vector3 in [Vector3(-.75,0,-.75),Vector3(.75,0,-.75),Vector3(-.75,0,.75),Vector3(.75,0,.75)]:
			var point := centre + offset
			if point.x < bounds.position.x-.001 or point.x > bounds.end.x+.001 or point.z < bounds.position.z-.001 or point.z > bounds.end.z+.001: missed += 1
	assert_eq(missed,0,"Actual P02 retained garden corners must constrain external routing before its rounded road is built")

func test_all_final_retained_columns_are_covered_without_mutating_the_plan() -> void:
	var retained_before := fabric.retained_terrace_cells.duplicate()
	var bounds := VillageWarrenFabricSolver._local_bounds(fabric)
	var missed := 0
	for cell: Vector3i in skin.retained:
		var centre := Vector3(cell)*FabricRecipe.CELL_SIZE
		if centre.x-.75 < bounds.position.x-.001 or centre.x+.75 > bounds.end.x+.001 or centre.z-.75 < bounds.position.z-.001 or centre.z+.75 > bounds.end.z+.001: missed += 1
	assert_eq(missed,0)
	assert_eq(fabric.retained_terrace_cells,retained_before)

func test_expanding_road_reservation_preserves_the_actual_town_construction() -> void:
	var original_bounds := AABB()
	var initialized := false
	for unit: FabricUnit in fabric.units:
		original_bounds = original_bounds.merge(unit.bounds) if initialized else unit.bounds
		initialized = true
	for kind in PublicRealmSurfacePlan.SurfaceKind.size():
		for cell: Vector3i in fabric.surface_plan.cells_for_kind(kind):
			var box := AABB(Vector3(cell) * FabricRecipe.CELL_SIZE - Vector3.ONE * .75, Vector3.ONE * 1.5)
			original_bounds = original_bounds.merge(box)
	var terrain := VillageTerrainView.from_region(HeightfieldRegion.new({}, {}))
	var placement := {"transform":pose,"yaw":PI*.5,"minimum_y":9.0,"maximum_y":9.0,"entrance_lift":.08,"local_bounds":original_bounds}
	var before := VillageWarrenFabricSolver._materialize(terrain, &"photo", spatial, fabric, placement, program.villages, 2697992464)
	placement.local_bounds = VillageWarrenFabricSolver._local_bounds(fabric)
	var after := VillageWarrenFabricSolver._materialize(terrain, &"photo", spatial, fabric, placement, program.villages, 2697992464)
	assert_gt(after.entries.size(), 0)
	assert_eq(after.entries, before.entries, "Retained garden, houses and props are preserved")
	assert_eq(after.collision_boxes, before.collision_boxes, "Town collision is preserved")
	assert_eq(after.surface_meshes, before.surface_meshes, "Native public floors and gardens are preserved")
	assert_eq(after.terrain_grade._claims, before.terrain_grade._claims, "Only external routing changes, not the sealed town grade")
