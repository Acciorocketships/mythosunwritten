extends GutTest
const CONTROL=preload("res://tests/fixtures/september18/cliff-formation-sampling/tread-before.gd")
func test_projection_preserves_physical_tread_grade()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var checked:=0;var missing:=0;var steepened:=0;var worst:=0.0
 for height:float in [8,32]:
  var pose:=Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5))
  var control:Dictionary=CONTROL.make(pose,48,height,2697992464)[0]
  var current:Dictionary=source.make(pose,48,height,2697992464)[0]
  var vertices:Dictionary={}
  for p:Vector3 in current.faces:
   var key:=Vector2(p.x,p.z).snapped(Vector2.ONE*.0001)
   if not vertices.has(key):vertices[key]={}
   vertices[key][p.y]=true
  for section:Array in control.tread_sections:
   var a:Vector3=section[0];var b:Vector3=section[1]
   if b.z-a.z<.15 or float(section[2])<.01:continue
   var ak:=Vector2(a.x,a.z).snapped(Vector2.ONE*.0001)
   var bk:=Vector2(b.x,b.z).snapped(Vector2.ONE*.0001)
   if not vertices.has(ak) or not vertices.has(bk):missing+=1;continue
   var ay:=INF;var by:=INF
   for value:float in vertices[ak]:
    if absf(value-a.y)<.001:ay=value;break
   for value:float in vertices[bk]:
    if value>=b.y-.001 and value<=a.y+.001:by=minf(by,value)
   if not is_finite(ay) or not is_finite(by):missing+=1;continue
   checked+=1
   var excess:float=(ay-by)/(b.z-a.z)-float(section[2]);worst=maxf(worst,excess)
   if excess>.02:steepened+=1
 print("ACTUAL_TREADS checked=",checked," missing=",missing," steepened=",steepened," max_excess=",worst)
 assert_eq(missing,0,"Every measured cap endpoint must exist in the actual collision/rendered shell")
 assert_gt(checked,400)
 assert_eq(steepened,0,"Final body shaping must preserve a ledge's intended shallow grade")
