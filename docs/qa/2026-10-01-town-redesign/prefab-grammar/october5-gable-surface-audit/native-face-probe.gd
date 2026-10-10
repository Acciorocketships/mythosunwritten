extends SceneTree
const F = preload("res://tests/fixtures/frozen_maze_source.gd")
const AUDIT = preload("res://tests/fixtures/kit_roof_audit.gd")
func _init():call_deferred("run")
func run():
 var p=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var rows=[]
 for seed_value in [-1]:
  var source=F.read("res://tests/fixtures/october5-court43-gable-source.txt") if seed_value==-1 else WarrenMazeSitePlanner.plan(seed_value,{},WarrenVillageScaleProfile.for_id(&"grand"),&"",false)
  var s=F.spatial(source,p)
  var kit=SuntailBuildingKit.create()
  var built=KitVillageBuildings.build(s,s.compiled_fabric_cache(),kit)
  var ctx=AUDIT.UNION.prepare(built.roofs,built.walls,kit,built.get("roof_kits",{}))
  var target=-1
  for i in built.roofs.size():
   var r=built.roofs[i]
   if r.rect==Rect2i(2,-16,6,4) and int(r.eave_band)==6: target=i
  print("TARGET ",target," ROOF ",built.roofs[target])
  var pieces=built.placements.filter(func(x):return int(x.get("roof_index",-1))==target)
  print("TARGETKIT ",ctx.roof_kits.get(target,kit).roles.get(&"gable.left",[]))
  for piece in pieces:
   if String(piece.role).begins_with("gable."): print("GABLE ",piece)
  for z in [-27.633,-27.233,-26.833,-26.433]:
   var pt=Vector3(16,12.113,z)
   for piece in pieces:
    if not String(piece.role).begins_with("gable."):continue
    var t:Transform3D=piece.transform
    for surface in ctx.data[piece.asset_id]:
     for i in range(0,surface.indices.size(),3):
      var a:Vector3=t*surface.vertices[surface.indices[i]]
      var b:Vector3=t*surface.vertices[surface.indices[i+1]]
      var c:Vector3=t*surface.vertices[surface.indices[i+2]]
      var n:Vector3=(t.basis.inverse().transposed()*(surface.normals[surface.indices[i]]+surface.normals[surface.indices[i+1]]+surface.normals[surface.indices[i+2]])).normalized()
      if n.x<0.2:continue
      var hit=Geometry3D.segment_intersects_triangle(pt+Vector3.RIGHT*.7,pt-Vector3.RIGHT*.7,a,b,c)
      if hit!=null:print("RAW_FACE ",hit," NORMAL ",n," BURIED_AT ",AUDIT._buried(hit,target,ctx,false)," BURIED_OUT ",AUDIT._buried(hit+Vector3.RIGHT*.01,target,ctx,false)," PIECE ",piece.stable_id)
  var row=AUDIT.audit(built,kit)
  row.seed=seed_value
  row.towers=built.get("towers",[]).size()
  row.decks=0
  for mass in built.masses:row.decks+=mass.decks.size()
  print("AUDIT ",row)
  rows.append(row)
 FileAccess.open("/tmp/oct5-43-gable-audit.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
 quit()
