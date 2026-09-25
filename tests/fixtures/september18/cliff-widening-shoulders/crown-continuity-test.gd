extends GutTest
func test_photographed_sloping_ledge_does_not_drop_a_whole_support_at_crown_limit()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load(path)
 var a:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()[9]
 var form:Dictionary=source.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
 var depths:Dictionary={}
 for p:Vector3 in form.faces:
  var k:=Vector2(p.x,p.y)
  depths[k]=maxf(depths.get(k,-INF),p.z)
 var worst:=0.0;var samples:=0
 for y:float in [3.0,4.0,5.0,6.0]:
  for x:float in [5.5,5.75,6.0]:
   var p:=Vector2(x,y);var q:=Vector2(x+.25,y)
   if not depths.has(p) or not depths.has(q):continue
   samples+=1;worst=maxf(worst,absf(depths[p]-depths[q]))
 print("CROWN_SUPPORT_JUMP samples=",samples," worst=",worst)
 assert_eq(samples,12)
 assert_lt(worst,.8,"The reported interior face must not lose a whole ledge support across one 25 cm strip")
