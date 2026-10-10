extends SceneTree
func _init():call_deferred("run")
func run():
 var catalog:=EnvironmentCatalog.load_default()
 var program:=SettlementFabricProgram.compile(catalog)
 var spatial:=WarrenVolumetricSolver.generate(53,{},program,WarrenVillageScaleProfile.for_id(&"grand"))
 var fabric:=spatial.compiled_fabric_cache()
 var tx:=SettlementFabricAssembler.maze_ground_skin_transaction(fabric)
 var built:=KitVillageBuildings.build(spatial,fabric,SuntailBuildingKit.create(),true,true)
 var rows:=[]
 for mass:BuildingMass in built.masses:
  if mass.stable_id not in [&"kit.retained",&"kit.tunnel-ceilings",&"kit.platform-wall"]:continue
  for storey:Dictionary in mass.storeys:
   var cells:=[]
   for cell:Vector2i in storey.cells:
    if cell.x<9 or cell.x>18 or cell.y<4 or cell.y>13:continue
    var below:=Vector3i(cell.x,int(storey.floor_band)-1,cell.y)
    cells.append({"cell":cell,"below_use":spatial.grid.use_at(below),"below_owner":spatial.grid.owner_name_at(below)})
   if not cells.is_empty():rows.append({"mass":mass.stable_id,"floor":storey.floor_band,"bands":storey.get("bands",2),"soffit":storey.get("soffit",false),"cells":cells})
 var sets:={}
 for key in ["suspended_plaza","capped_ground","garden"]:
  sets[key]=tx[key].keys()
 FileAccess.open('/tmp/oct6-garden-underside.json',FileAccess.WRITE).store_string(JSON.stringify({"storeys":rows,"sets":sets},'  '))
 print('DONE')
 quit()
