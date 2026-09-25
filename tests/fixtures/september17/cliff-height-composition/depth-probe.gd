extends SceneTree
const WIDTH=preload("res://tests/helpers/cliff_tread_width.gd")
func _initialize()->void:
 for version:String in ["before","heights","reach"]:
  var g=load("res://tests/fixtures/september17/cliff-height-composition/"+version+".gd")
  var form:Dictionary=g.make(Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5)),48,64,2697992464)[0]
  var samples:Dictionary={};var compressed:=0
  for p:Vector3 in form.faces:
   if p.y>2 and p.y<60 and p.z>0:samples[p]=true
  for p:Vector3 in samples:if p.z>6.5:compressed+=1
  var widths:=WIDTH.at_vertices(form.green);var area:=0.0;var broad:=0.0
  for i in range(0,form.green.size(),3):
   var a:Vector3=form.green[i];var b:Vector3=form.green[i+1];var c:Vector3=form.green[i+2]
   if (a.y+b.y+c.y)/3<25.6:continue
   var size:float=(c-a).cross(b-a).length()*.5;area+=size
   if WIDTH.triangle(form.green,i,widths)>=.9:broad+=size
  print("TALL_RELIEF variant=",version," samples_above_6_5=",compressed," samples=",samples.size()," upper_turf=",area," upper_broad_turf=",broad," max_depth=",form.bounds.end.z-10.5)
 quit()
