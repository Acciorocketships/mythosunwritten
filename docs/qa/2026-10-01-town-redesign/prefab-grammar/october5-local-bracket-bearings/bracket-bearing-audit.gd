extends SceneTree
func _init():
 var program=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var rows={}
 for seed_value in [53,63,103,301]:
  var s=WarrenVolumetricSolver.generate(seed_value,{},program,WarrenVillageScaleProfile.for_id(&"grand"))
  var b=KitVillageBuildings.build(s,s.compiled_fabric_cache(),SuntailBuildingKit.create())
  var contacts=preload("res://scripts/terrain/features/villages/kit/KitBracketBearings.gd").cells(b.masses)
  var missing=[]
  var checked=0
  for cell in contacts:
   if s.grid.use_at(cell)!=WarrenSpatialGrid.Use.PRIVATE_VOLUME:continue
   checked+=1
   var borne=false
   for mass in b.houses:
    if mass.cells_at_band(cell.y).has(Vector2i(cell.x,cell.z)):borne=true
   if not borne:missing.append(cell)
  rows[str(seed_value)]={"checked":checked,"missing":missing}
 print(JSON.stringify(rows))
 FileAccess.open("/tmp/bracket-bearing-audit.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
 quit()
