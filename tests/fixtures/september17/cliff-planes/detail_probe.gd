extends GutTest
const BASE=preload("res://tests/fixtures/september17/cliff-planes/before.gd")
const CONTROL=preload("res://tests/fixtures/september17/cliff-scale/selected-unfractured.gd")
func test_moderate_attachments_retain_stone_breaks()->void:
 var selected:=OS.get_environment("STORY_DETAIL_GENERATOR")
 var generator:GDScript=BASE if selected.is_empty() else load(selected)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 generator.prepare()
 var total:=0;var cut:=0;var buried:=0
 for index:int in [0,4,12,20]:
  var entry:Array=anchors[index]
  var reference:Dictionary={};var current:Dictionary={}
  for form:Dictionary in CONTROL.make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4]):
   for point:Vector3 in form.faces:
    var key:=Vector2(point.x,point.y)
    reference[key]=maxf(reference.get(key,-INF),point.z)
  for form:Dictionary in generator.make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4]):
   for point:Vector3 in form.faces:
    var key:=Vector2(point.x,point.y)
    current[key]=maxf(current.get(key,-INF),point.z)
  var coordinate:float=entry[0].origin.dot(entry[0].basis.x)
  var local_total:=0;var local_cut:=0
  for key:Vector2 in reference:
   if key.y<1 or not current.has(key):continue
   var native:float=generator._native_depth(coordinate+key.x,key.y)
   var thickness:float=reference[key]-native
   if thickness<.8 or thickness>1.4:continue
   total+=1;local_total+=1
   if reference[key]-current[key]>=.20:cut+=1;local_cut+=1
   if current[key]<native:
    buried+=1
    print("REENTRY anchor=",index," local=",key," current=",current[key]," native=",native," uncut=",reference[key])
  print("DETAIL_RANGE anchor=",index," count=",local_total," cut=",local_cut)
 print("DETAIL_RANGE total=",total," cut=",cut," ratio=",float(cut)/maxi(1,total)," buried=",buried)
 assert_gt(total,200,"Exercise the thinner visible shoulders at the actual photo sites")
 assert_gt(float(cut)/maxi(1,total),.12,"Exposed shoulders must retain resolved 20 cm breaks instead of smoothing all the way to the thick outer rock")
 assert_eq(buried,0,"Finite breaks must not cut the exposed shoulder back through its native wall")
