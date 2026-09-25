extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/123-bank-grass"
func _init()->void:run.call_deferred()
func run()->void:
 var hydraulic:=TerrainWorldTuning.make_water(2697992464)
 var fields:=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,hydraulic),hydraulic,26,0,8)
 var region:=fields.region(Vector2i(-3,1))
 var banks:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/121-shoreline-rock/owned/all-banks.bin",FileAccess.READ).get_var()
 var caps:=preload("res://tests/fixtures/september19/bank-grass/supports.gd").surfaces(banks,Rect2(-576,192,192,192))
 var index:=GrassSupportSurfaces.spatial_index(caps)
 var counts:={"caps":caps.size(),"visible":0,"wide":0,"native_clear":0,"max_edge":0.0};var rows:Array=[]
 for cap:Dictionary in caps:
  var p:Vector3=(cap.face[0]+cap.face[1]+cap.face[2])/3
  var sample:=GrassSupportSurfaces.at_index(index,Vector2(p.x,p.z))
  if sample.is_empty():continue
  counts.visible+=1;counts.max_edge=maxf(counts.max_edge,sample.edge_distance)
  var ground:=TerrainSurfaceField.surface_y(region,p.x,p.z)
  if sample.y>ground+.05:counts.native_clear+=1
  if sample.edge_distance>.10 and sample.y>ground+.05:
   counts.wide+=1;rows.append({"point":p,"edge":sample.edge_distance,"ground":ground,"normal":sample.normal})
 counts["wide_samples"]=rows
 FileAccess.open(OUT.path_join("root-audit-all.json"),FileAccess.WRITE).store_string(JSON.stringify(counts,"  "))
 print("BANK_ROOT_AUDIT ",counts)
 quit()
