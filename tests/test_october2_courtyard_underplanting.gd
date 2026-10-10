extends GutTest

func test_courtyard_underplanting_is_supported_and_leaves_seats_and_walks_clear() -> void:
 var catalog := EnvironmentCatalog.load_default()
 var spatial := WarrenVolumetricSolver.generate(13,{},SettlementFabricProgram.compile(catalog),WarrenVillageScaleProfile.for_id(&"grand"))
 assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
 if spatial == null: return
 var fabric := spatial.compiled_fabric_cache()
 var payload := SettlementFabricAssembler.terrace_retaining_payload(fabric)
 var seats: Array[AABB] = []
 for asset: StringName in payload.batches:
  var batch: Dictionary = payload.batches[asset]
  for i in batch.ids.size():
   if String(batch.ids[i]).begins_with("maze-plaza-seat/"):
    seats.append(batch.transforms[i]*catalog.descriptor(asset).measured_aabb)
 var count := 0
 for asset: StringName in payload.batches:
  var batch: Dictionary = payload.batches[asset]
  for i in batch.ids.size():
   if not String(batch.ids[i]).begins_with("maze-plaza-plant/"): continue
   count += 1
   var box: AABB = batch.transforms[i]*catalog.descriptor(asset).measured_aabb
   assert_almost_eq(box.position.y,12.005,0.001,"roots meet the elevated garden")
   for seat: AABB in seats: assert_false(box.grow(.1).intersects(seat),"plants leave the seat clear")
   for claim: Dictionary in fabric.surface_plan._claims.values():
    var walk := AABB(Vector3(claim.cell)*1.5-Vector3(.75,0,.75),Vector3(1.5,3,1.5))
    assert_false(box.grow(.12).intersects(walk),"the complete plant stays outside public walking space")
   for x in range(floori((box.position.x+.75)/1.5),ceili((box.end.x+.75)/1.5)):
    for z in range(floori((box.position.z+.75)/1.5),ceili((box.end.z+.75)/1.5)):
     assert_true(fabric.planned_plaza_planting_cells.has(Vector3i(x,7,z)),"whole plant has garden support")
 assert_gt(count,2,"the tree island includes a small underplanting cluster")

func test_underplanting_declines_missing_support_and_obstacles() -> void:
 var catalog := EnvironmentCatalog.load_default()
 var bounds := {}
 for id: StringName in SettlementFabricAssembler.PLAZA_UNDERPLANTS:
  bounds[id] = catalog.descriptor(id).measured_aabb
 var footprints := {"asset_bounds":bounds}
 var feature := {"asset":&"lpfv.tree.01","cell":Vector3i.ZERO,
  "origin":Vector3(.75,1.505,.75),"quarter":2,
  "cells":{Vector3i.ZERO:true,Vector3i.RIGHT:true,Vector3i.BACK:true,Vector3i(1,0,1):true}}
 var accepted := SettlementFabricAssembler.maze_plaza_underplants(feature,footprints,[],[])
 assert_gt(accepted.size(),2)
 assert_eq(accepted,SettlementFabricAssembler.maze_plaza_underplants(feature,footprints,[],[]),"stable generation")
 var obstacle: Array[AABB] = [AABB(Vector3(-2,1,-2),Vector3(6,3,6))]
 assert_true(SettlementFabricAssembler.maze_plaza_underplants(feature,footprints,obstacle,[]).is_empty())
 feature.cells.clear()
 assert_true(SettlementFabricAssembler.maze_plaza_underplants(feature,footprints,[],[]).is_empty())
