extends SceneTree
const UNION=preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
func _init():
 var saved:Dictionary=FileAccess.open("/tmp/oct5-junction-extract.bin",FileAccess.READ).get_var()
 var kit:=SuntailBuildingKit.create()
 var pure:=preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").roof_study()
 var ctx:=saved.duplicate()
 ctx.kit=kit
 ctx.roof_kits={}
 for i in saved.kit_ids:ctx.roof_kits[i]=pure if String(saved.kit_ids[i]).contains("pure") else kit
 var parts:Array[Dictionary]=[]
 parts.assign(saved.parts)
 UNION.fit_ridge_contacts(parts,ctx)
 var fitted:=0
 for part:Dictionary in parts:
  if not String(part.get("role","")).begins_with("trim.ridge"):continue
  if part.get("clip_volumes",[]).is_empty():continue
  var result:=UNION.realize(part,ctx)
  var vertices:=0
  for mesh:Dictionary in result.get("meshes",[]):vertices+=mesh.vertices.size()
  print(part.stable_id," cuts=",part.clip_volumes.size()," vertices=",vertices)
  fitted+=1
 print("FITTED ",fitted)
 quit()
