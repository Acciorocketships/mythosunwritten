extends GutTest

func test_planted_upper_court_has_seating_clear_of_its_tree_and_walk_ring() -> void:
 var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var spatial := WarrenVolumetricSolver.generate(13,{},program,WarrenVillageScaleProfile.for_id(&"grand"))
 assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
 if spatial==null: return
 var fabric := spatial.compiled_fabric_cache()
 var payload := SettlementFabricAssembler.terrace_retaining_payload(fabric)
 var catalog := EnvironmentCatalog.load_default()
 var count := 0
 var tree_boxes: Array[AABB] = []
 for asset: StringName in payload.batches:
  var batch: Dictionary = payload.batches[asset]
  for i in batch.ids.size():
   if String(batch.ids[i]).begins_with("maze-plaza-centre/"):
    for band: AABB in preload("res://scripts/terrain/features/villages/TownTreeProfiles.gd").BANDS.get(asset,[]):
     tree_boxes.append(batch.transforms[i]*band)
 for asset: StringName in payload.batches:
  var batch: Dictionary = payload.batches[asset]
  for i in batch.ids.size():
   if not String(batch.ids[i]).begins_with("maze-plaza-seat/"): continue
   count += 1
   var box: AABB = batch.transforms[i]*catalog.descriptor(asset).measured_aabb
   assert_almost_eq(box.position.y,12.005,0.001,"seating stands on the upper garden")
   for tree_box: AABB in tree_boxes: assert_false(box.intersects(tree_box),"seats can sit under the crown but never intersect roots, trunk or low branches")
   for claim: Dictionary in fabric.surface_plan._claims.values():
    var cell: Vector3i = claim.cell
    var walk := AABB(Vector3(cell)*FabricRecipe.CELL_SIZE-Vector3(0.75,0,0.75),Vector3(1.5,3,1.5))
    assert_false(box.intersects(walk.grow(0.25)),"seating leaves a margin for the walk ring and its guard posts")
 assert_gt(count,0,"the elevated planted square should offer a place to sit")

func test_seating_requires_both_support_and_clear_construction_space() -> void:
 var feature := {"asset":&"lpfv.tree.01","cell":Vector3i.ZERO,
  "origin":Vector3(0.75,1.505,0.75),"quarter":0,"scale":1.0,
  "cells":{Vector3i.ZERO:true,Vector3i.RIGHT:true,Vector3i.BACK:true,Vector3i(1,0,1):true}}
 var footprints := {"asset_bounds":{
  &"lpfv.tree.01":AABB(Vector3(-0.2,0,-0.2),Vector3(0.4,2,0.4)),
  &"interior.bench.001":EnvironmentCatalog.load_default().descriptor(&"interior.bench.001").measured_aabb}}
 assert_eq(SettlementFabricAssembler.maze_plaza_seats(feature,footprints,[]).size(),2)
 var obstacle: Array[AABB] = [AABB(Vector3(-2,1,-2),Vector3(6,3,6))]
 assert_true(SettlementFabricAssembler.maze_plaza_seats(feature,footprints,obstacle).is_empty())
 feature.cells.clear()
 assert_true(SettlementFabricAssembler.maze_plaza_seats(feature,footprints,[]).is_empty(),"no furnishing on unsupported space")
