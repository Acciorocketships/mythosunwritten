extends SceneTree
func _init():call_deferred("run")
func run():
 var catalog:=EnvironmentCatalog.load_default()
 var program:=SettlementFabricProgram.compile(catalog)
 var spatial:=WarrenVolumetricSolver.generate(53,{},program,WarrenVillageScaleProfile.for_id(&"grand"))
 var fabric:=spatial.compiled_fabric_cache()
 var tx:=SettlementFabricAssembler.maze_ground_skin_transaction(fabric)
 for x in [14,15]:
  for z in range(4,8):
   for y in range(0,6):
    var c:=Vector3i(x,y,z)
    print('COLUMN ',c,' use=',spatial.grid.use_at(c),' owner=',spatial.grid.owner_name_at(c),' retained=',fabric.retained_terrace_cells.has(c),' crown=',fabric.passage_crown_cells.has(c),' solid=',tx.solids.has(c),' garden=',tx.capped_ground.has(c))
 print('DONE')
 quit()
