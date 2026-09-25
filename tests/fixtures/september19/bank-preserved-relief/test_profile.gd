extends GutTest
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
const OLD=preload("res://tests/fixtures/september19/bank-relief/shape.gd")
const NEW=preload("res://tests/fixtures/september19/bank-preserved-relief/shape.gd")
func test_thin_source_relief_is_preserved_instead_of_replaced_by_wall_columns()->void:
 ROCKS.prepare()
 var sources:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/122-bank-attachments/sources.bin",FileAccess.READ).get_var()
 var mapper=OLD if OS.get_environment("BANK_PROFILE_BASELINE")=="1" else NEW
 var examined:=0;var changed:=0;var max_change:=0.0
 for source:Dictionary in sources:
  if source.replay_recipe.kind!="wall":continue
  var seen:Dictionary={}
  for p:Vector3 in source.faces:
   if p.z>1.4 or p.z<0 or seen.has(p):continue
   seen[p]=true
   var native:float=ROCKS.CRAGS._native_depth(source.transform.origin.dot(source.transform.basis.x)+p.x,p.y)
   if p.z<native+.05:continue
   examined+=1
   var distance:float=p.distance_to(mapper.point(p,source)[0])
   max_change=maxf(max_change,distance)
   if distance>.000001:changed+=1
 print("BANK_THIN examined=",examined," changed=",changed," maximum_change=",max_change)
 assert_gt(examined,1000)
 assert_eq(changed,0,"Retain the source's shallow rock formation instead of compressing it into the repeating backing")

func test_compression_cannot_fold_or_expand_the_bank_profile()->void:
 ROCKS.prepare()
 var sources:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/122-bank-attachments/sources.bin",FileAccess.READ).get_var()
 var source:Dictionary={}
 for form:Dictionary in sources:
  if form.replay_recipe.kind=="wall":source=form;break
 assert_false(source.is_empty())
 var folds:=0;var expansions:=0;var maximum:=-INF
 for u:float in [-10.0,-5.0,0.0,5.0,10.0]:
  for y:float in [0.0,.2,1.0,3.9,4.0,6.0,8.0]:
   var previous:=-INF
   for i in 1501:
    var depth:float=-1.2+float(i)*.01
    var p:Vector3=NEW.point(Vector3(u,y,depth),source)[0]
    if p.z<previous-.000001:folds+=1
    if p.z>depth+.000001:expansions+=1
    previous=p.z;maximum=maxf(maximum,p.z)
 assert_eq(folds,0,"Compression must retain depth ordering instead of introducing inward folds")
 assert_eq(expansions,0,"A source formation may only retain or reduce its original projection")
 assert_lte(maximum,3.001,"Retain the finite channel-bank depth limit")
