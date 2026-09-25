extends SceneTree
func _initialize()->void:
 var source:="res://scripts/terrain/field/CliffRockCrags.gd"
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--generator="):source=arg.trim_prefix("--generator=")
 var generator:GDScript=load(source)
 var entries:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 for index:int in [0,4,12,20]:
  var entry:Array=entries[index]
  var form:Dictionary=generator.make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4])[0]
  var points:Dictionary={}
  for p:Vector3 in form.faces:
   if absf(p.y*5-roundf(p.y*5))>.001:continue
   var key:=Vector2i(roundi(p.x*4),roundi(p.y*5))
   points[key]=maxf(points.get(key,-INF),p.z)
  var samples:=0;var curvature:=0.0;var detailed:=0;var spike:=0
  for key:Vector2i in points:
   if points[key]<2.5 or key.y<5 or key.y>entry[2]*5-5:continue
   var before:=key-Vector2i(1,0);var after:=key+Vector2i(1,0)
   if not points.has(before) or not points.has(after):continue
   var bend:float=absf(points[before]-2*points[key]+points[after])
   curvature+=bend;samples+=1
   if bend>.10:detailed+=1
   if bend>.65:spike+=1
  print("BODY_DETAIL anchor=",index," samples=",samples," mean_bend=",curvature/maxi(1,samples)," crags=",detailed," spikes=",spike)
 quit()
