extends SceneTree
const U=preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
func _init(): call_deferred("run")
func run():
 var catalog=EnvironmentCatalog.load_default()
 var kit=SuntailBuildingKit.create()
 var spatial=WarrenVolumetricSolver.generate(53,{},SettlementFabricProgram.compile(catalog),WarrenVillageScaleProfile.for_id(&"grand"))
 var built=KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),kit)
 var ctx=U.prepare(built.roofs,built.walls,kit,built.roof_kits)
 var report=[]
 for tower in built.towers:
  if tower.host.stable_id!=&"kit.spatial.parcel.maze.house.033":continue
  var cap=tower.pose*tower.parts[-1].transform
  print("CAP ",cap," PART ",tower.parts[-1])
  for part in built.placements:
   var box=part.transform*catalog.descriptor(part.asset_id).measured_aabb
   if not box.intersects(tower.bounds.grow(2.0)):continue
   var realized=U.realize(part,ctx)
   if realized.is_empty():
    if not ctx.data.has(part.asset_id):continue
    realized={"meshes":[]}
    for original in ctx.data[part.asset_id]:
     realized.meshes.append({"vertices":part.transform*original.vertices,"indices":original.indices})
   var surfaces=[]
   for mesh in realized.meshes:
    var vs=[]
    for v in mesh.vertices:vs.append([v.x,v.y,v.z])
    surfaces.append({"vertices":vs,"indices":Array(mesh.indices) if mesh.has("indices") else [],"keys":mesh.keys()})
   report.append({"id":part.get("stable_id",""),"role":part.role,"asset":part.asset_id,"surfaces":surfaces})
 FileAccess.open('/tmp/turret-fragments.json',FileAccess.WRITE).store_string(JSON.stringify(report))
 quit()
