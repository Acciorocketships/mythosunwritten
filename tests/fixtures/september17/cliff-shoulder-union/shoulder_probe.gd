extends GutTest
const BASE=preload("res://tests/fixtures/september17/cliff-shoulder-union/before.gd")
const CONTROL=preload("res://tests/fixtures/september17/cliff-shoulder-union/unfractured.gd")
func _front(form:Dictionary)->Dictionary:
 var result:Dictionary={}
 for point:Vector3 in form.faces:
  var key:=Vector2(point.x,point.y)
  result[key]=maxf(result.get(key,-INF),point.z)
 return result
func test_probe_actual_exposed_shoulders()->void:
 var path:=OS.get_environment("STORY_SHOULDER_GENERATOR")
 var generator:GDScript=BASE if path.is_empty() else load(path)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 for index in anchors.size():
  var entry:Array=anchors[index]
  var control:=_front(CONTROL.make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4])[0])
  var current:=_front(generator.make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4])[0])
  var coordinate:float=entry[0].origin.dot(entry[0].basis.x)
  var flat:=0;var total:=0;var keys:Array=[]
  for key:Vector2 in current:
   if key.y<1 or key.y>entry[2]-1 or not control.has(key):continue
   if control[key]-BASE._native_depth(coordinate+key.x,key.y)<1.7:continue
   total+=1
   if absf(control[key]-current[key])<.002:
    flat+=1
    if keys.size()<6:keys.append(key)
  print("SHOULDER_PROBE anchor=",index," origin=",entry[0].origin," thick=",total," uncut=",flat," example=",keys)
 assert_true(true)
