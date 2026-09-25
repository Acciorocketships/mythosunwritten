extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/126-bank-relief"
const SHAPE=preload("res://tests/fixtures/september19/bank-relief/shape.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
func _init()->void:
 ROCKS.prepare()
 var sources:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/122-bank-attachments/sources.bin",FileAccess.READ).get_var()
 var by_id:Dictionary={}
 for source:Dictionary in sources:by_id[source.id]=source
 var banks:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/121-shoreline-rock/owned/all-banks.bin",FileAccess.READ).get_var()
 var result:Array=[]
 for old:Dictionary in banks:
  assert(by_id.has(old.id))
  var source:Dictionary=by_id[old.id];var bank:Dictionary=old.duplicate(true)
  var mapping:Dictionary={};var roots:Dictionary={}
  for p:Vector3 in source.faces:
   if mapping.has(p):continue
   var mapped:=SHAPE.point(p,source);mapping[p]=mapped[0];roots[mapped[0]]=[mapped[1],mapped[2]]
  var faces:=PackedVector3Array();var green:=PackedVector3Array()
  for p:Vector3 in source.faces:faces.append(mapping[p])
  for i in range(0,source.green.size(),3):
   var a:Vector3=mapping[source.green[i]];var b:Vector3=mapping[source.green[i+1]];var c:Vector3=mapping[source.green[i+2]]
   if minf(a.y,minf(b.y,c.y))+source.transform.origin.y<old.replay_recipe.shore_level+.3:continue
   green.append_array(PackedVector3Array([a,b,c]))
  bank.faces=faces;bank.green=green;bank.native_roots=roots
  var box:=AABB(faces[0],Vector3.ZERO)
  for p:Vector3 in faces:box=box.expand(p)
  bank.bounds=bank.transform*box;bank.top=bank.bounds.end.y;bank.base=bank.bounds.position.y
  bank.render_arrays=ROCKS.CRAGS.mesh_arrays(bank)
  result.append(bank)
 FileAccess.open(OUT.path_join("banks.bin"),FileAccess.WRITE).store_var(result)
 print("BANK_RELIEF_STUDY ",result.size()," formations; hydraulic admission still needs fresh validation")
 quit()
