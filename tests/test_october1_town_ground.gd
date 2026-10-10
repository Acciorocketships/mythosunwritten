extends GutTest

func test_natural_ground_ignores_only_the_broad_reservation() -> void:
 var envelope := FeatureGroundShape.oriented_rect(Vector2.ZERO, Vector2(20,20), 0, 0, 0, &"town")
 envelope.envelope = true
 var wall := FeatureGroundShape.oriented_rect(Vector2(8,0), Vector2(2,6), 0, 0, 0, &"wall")
 var field := FeatureGroundField.new([], [envelope, wall], 12)
 assert_lt(field.clearance_at(Vector2.ZERO), 0.0, "ambient placement still respects the district")
 assert_eq(field.clearance_at(Vector2.ZERO, false), 6.0, "grass sees the actual wall distance")
 assert_lt(field.clearance_at(Vector2(8,0), false), 0.0, "physical walls always exclude grass")
 assert_eq(field.surface_at(Vector2.ZERO), FeatureGroundField.NATURAL)

func test_physical_town_projection_keeps_walks_and_solids_but_not_empty_air() -> void:
 var town := VillageUrbanFabricPlan.new()
 for role in [VillageOccupancy.Role.SOLID, VillageOccupancy.Role.WALK_SURFACE,
   VillageOccupancy.Role.WALK_GUARD, VillageOccupancy.Role.HEADROOM,
   VillageOccupancy.Role.GROUND_EXCLUSIVE]:
  town.volumes.append(VillageOccupancyVolume.new(role, Vector2(role*10,0),
   Vector2(2,2), 0.3, 0, 3, StringName("volume.%d" % role)))
 VillageWarrenFabricSolver._append_physical_ground_clearance(town, &"town")
 assert_eq(town.clearances.size(), 3)
 var field := FeatureGroundField.new([], town.clearances, 3)
 for role in [VillageOccupancy.Role.SOLID, VillageOccupancy.Role.WALK_SURFACE,
   VillageOccupancy.Role.WALK_GUARD]:
  assert_lt(field.clearance_at(Vector2(role*10,0), false), 0.0)
 for role in [VillageOccupancy.Role.HEADROOM, VillageOccupancy.Role.GROUND_EXCLUSIVE]:
  assert_gt(field.clearance_at(Vector2(role*10,0), false), 0.0)

func test_generated_greens_reach_the_physical_clearance_field() -> void:
 var source := WarrenMazeSitePlanner.plan(10, {}, WarrenVillageScaleProfile.for_id(&"large"), &"", false)
 assert_not_null(source)
 if source == null: return
 var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var spatial := preload("res://tests/fixtures/frozen_maze_source.gd").spatial(source, program)
 var fabric := spatial.compiled_fabric_cache()
 var town := VillageUrbanFabricPlan.new()
 VillageWarrenFabricSolver._append_typed_occupancy(town, fabric, Transform3D.IDENTITY, &"town", 0)
 VillageWarrenFabricSolver._append_physical_ground_clearance(town, &"town")
 var field := FeatureGroundField.new([], town.clearances, 8)
 var open_samples := 0
 var green_samples := 0
 for space: Dictionary in source.massif.open_spaces:
  for column: Vector2i in space.cells:
   for fine: Vector3i in WarrenVolumetricSolver._fine_square(Vector3i(column.x, 0, column.y)):
    var position := Vector3(fine) * FabricRecipe.CELL_SIZE
    green_samples += 1
    if field.clearance_at(Vector2(position.x,position.z), false) > 0.5:
     open_samples += 1
 assert_gt(green_samples, 12, "inspect a real reserved green")
 assert_gt(open_samples, 4, "construction projection must leave usable ground in generated greens")

func test_planted_core_survives_final_ground_paint_and_physical_clearance() -> void:
 var source := WarrenMazeSitePlanner.plan(32,{},WarrenVillageScaleProfile.for_id(&"large"),&"",false)
 assert_not_null(source)
 if source==null: return
 var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var spatial := preload("res://tests/fixtures/frozen_maze_source.gd").spatial(source,program)
 var town := VillageUrbanFabricPlan.new()
 VillageWarrenFabricSolver._append_typed_occupancy(town,spatial.compiled_fabric_cache(),Transform3D.IDENTITY,&"green",0)
 VillageWarrenFabricSolver._append_physical_ground_clearance(town,&"green")
 var field := FeatureGroundField.new(town.surfaces,town.clearances,8)
 var count := 0
 for column: Vector2i in source.massif.columns:
  if not bool(source.massif.columns[column].get("planting_core",false)): continue
  var point := Vector2(column.x*3.0+.75,column.y*3.0+.75)
  assert_eq(field.surface_at(point),FeatureGroundField.NATURAL,"the protected island remains natural ground")
  assert_gt(field.clearance_at(point,false),.5,"the island retains actual space beyond its route reservation")
  count+=1
 assert_gte(count,8)
