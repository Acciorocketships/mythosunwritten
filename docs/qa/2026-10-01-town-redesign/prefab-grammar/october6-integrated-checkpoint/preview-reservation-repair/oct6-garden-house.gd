extends SceneTree
func _init():call_deferred("run")
func run():
 var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var spatial:=WarrenVolumetricSolver.generate(53,{},program,WarrenVillageScaleProfile.for_id(&"grand"))
 var built:=KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),SuntailBuildingKit.create(),true,true)
 var rows:=[]
 for mass:BuildingMass in built.masses:
  if not mass.storeys.any(func(f:Dictionary)->bool:return f.cells.has(Vector2i(14,5))):continue
  var roofs:=[]
  for roof:Dictionary in mass.roofs:roofs.append({"rect":roof.rect,"axis":roof.axis,"band":roof.eave_band})
  rows.append({"id":mass.stable_id,"roofs":roofs,"trace":mass.roof_design_trace,"ground":mass.ground_band,"storeys":mass.storeys,"decks":mass.decks})
 FileAccess.open('/tmp/oct6-garden-house.json',FileAccess.WRITE).store_string(JSON.stringify(rows,'  '))
 print('ROOF_DIAGNOSTIC_DONE ',rows.size())
 quit()
