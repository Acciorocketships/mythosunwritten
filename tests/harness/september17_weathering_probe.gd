extends SceneTree
func _initialize()->void:
 call_deferred("_run")
func _run()->void:
 for path:String in ["res://tests/fixtures/september17/cliff-weathering/before.gd","res://tests/fixtures/september17/cliff-weathering/study.gd"]:
  var generator:GDScript=load(path);generator.prepare()
  var entries:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
  for index:int in [0,4,12,20]:
   var entry:Array=entries[index]
   var form:Dictionary=generator.make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4])[0]
   var samples:Dictionary={}
   for p:Vector3 in form.faces:
    if p.z<2 or absf(p.y/.2-roundf(p.y/.2))>.001:continue
    var key:=Vector2i(roundi(p.x*4),roundi(p.y*5))
    samples[key]=maxf(samples.get(key,-INF),p.z)
   var clefts:=0;var tested:=0
   for key:Vector2i in samples:
    if not samples.has(key+Vector2i(0,2)) or not samples.has(key-Vector2i(0,2)):continue
    tested+=1
    if samples[key]+.18<minf(samples[key+Vector2i(0,2)],samples[key-Vector2i(0,2)]):clefts+=1
   print("WEATHER ",path," index=",index," clefts=",clefts," tested=",tested)
 quit()
