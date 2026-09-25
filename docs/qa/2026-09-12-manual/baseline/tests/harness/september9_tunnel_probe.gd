extends SceneTree
func _init() -> void:
 var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var frozen:=preload("res://tests/fixtures/frozen_maze_source.gd")
 var rows:Array=[]
 for label in ["east","offset","thin-turf"]:
  var spatial:=frozen.spatial(frozen.read("res://tests/fixtures/september9-%s-source.txt"%label),program)
  var fabric:=spatial.compiled_fabric_cache()
  var tx:=SettlementFabricAssembler.maze_ground_skin_transaction(fabric)
  print(label," retained ",tx.retained.size()," grid ",spatial.route_floor_cells.size())
  for spec in VillageWarrenFabricSolver.terrain_contact_specs(spatial,fabric):
   for p:Vector3i in spec.cells:
    var col:=[]
    for h in range(-1,7): col.append([h,spatial.grid.use_at(p+Vector3i.UP*h),tx.retained.has(p+Vector3i.UP*h),tx.solids.has(p+Vector3i.UP*h)])
    print(p,col)
  var public:Dictionary={}
  for p in spatial.route_floor_cells:public[p]=true
  var mouths:Array=[]
  var grid:=spatial.grid
  for p in spatial.route_floor_cells:
   for d:Vector3i in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
    var lateral:=Vector3i.RIGHT if d.z!=0 else Vector3i.BACK
    var q:=p+lateral
    if not public.has(q):continue
    if not solid(grid,p+Vector3i.UP*3) or not solid(grid,q+Vector3i.UP*3):continue
    if solid(grid,p+d+Vector3i.UP*3) or solid(grid,q+d+Vector3i.UP*3):continue
    if not public.has(p+d) or not public.has(q+d):
     var exterior:=false
     for spec in VillageWarrenFabricSolver.terrain_contact_specs(spatial,fabric):
      if spec.cells[0]==p and spec.cells[1]==q and spec.outward==d:exterior=true
     if not exterior:continue
    var sides:=[]
    for v in [p-lateral,q+lateral]:
     sides.append([grid.use_at(v),grid.use_at(v+Vector3i.UP),grid.use_at(v+Vector3i.DOWN)])
    mouths.append({"p":str(p),"q":str(q),"out":str(d),"sides":sides})
  rows.append({"source":label,"mouths":mouths})
 FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print(rows)
 quit()
func solid(grid:WarrenSpatialGrid,p:Vector3i)->bool:
 return grid.use_at(p) in [WarrenSpatialGrid.Use.STRUCTURAL_VOLUME,WarrenSpatialGrid.Use.PRIVATE_VOLUME]
