extends SceneTree
func _init():
 var program=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var seed_value=VillagePlan.warren_seed_for_cell(2697992464,Vector2i(8,-143))
 var spatial=WarrenVolumetricSolver.solve(seed_value,{},program,WarrenVillageScaleProfile.select(seed_value))
 var p=spatial.compiled_fabric_cache()
 print("SEED ",seed_value," audit=",p.continuous_roof_plan.audit())
 for placement in p.expanded_placements():
  var id=String(placement.stable_id)
  if id.contains("maze_back.03.room00") and id.contains("chimney"):print("RETAINED ",placement)
 print("VALIDATION ",WarrenSpatialFabricCompiler.validation_errors(p))
 quit()
