extends GutTest
const BEFORE=preload("res://tests/fixtures/september18/cliff-recovered-composition/recovered.gd")
func _depths(form:Dictionary)->Dictionary:
 var result:Dictionary={}
 for p:Vector3 in form.faces:
  if absf(p.y)>.0001:continue
  result[p.x]=maxf(result.get(p.x,-INF),p.z)
 return result
func test_added_lower_rocks_extend_selected_feet_without_widening_the_whole_wall()->void:
 var source:GDScript=load(OS.get_environment("STORY_COLUMN_GENERATOR"))
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var maximum:=0.0;var minimum:=INF;var extended:=0;var unchanged:=0;var total:=0
 for a:Array in anchors:
  if a[2]>16.0:continue
  var old:=_depths(BEFORE.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0])
  var current:=_depths(source.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0])
  for x:float in old:
   if not current.has(x):continue
   var delta:float=current[x]-old[x]
   maximum=maxf(maximum,delta);minimum=minf(minimum,delta);total+=1
   if delta>.35:extended+=1
   if absf(delta)<.01:unchanged+=1
 print("LOWER_ROCK_REACH samples=",total," min=",minimum," max=",maximum," extended=",extended," unchanged=",unchanged)
 assert_gt(total,100)
 assert_gt(maximum,.65,"Some actual lower faces should extend materially beyond the recovered reference")
 assert_lt(maximum,1.8,"Localized new slopes must not inflate the entire formation")
 assert_gte(minimum,-.001,"Recovering the earlier style must not hollow out its existing rooted base")
 assert_gt(extended,30)
 assert_gt(float(unchanged)/total,.20,"Retain quiet intervals between the larger outcrops")
