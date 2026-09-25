extends GutTest
const CURRENT=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const UNCARVED=preload("res://tests/fixtures/september17/cliff-shoulder-union/unfractured.gd")
const FULL_DETAIL=preload("res://tests/fixtures/september17/cliff-shoulder-union/full-detail.gd")
func _front(form:Dictionary)->Dictionary:
 var result:Dictionary={}
 for point:Vector3 in form.faces:
  var key:=Vector2(point.x,point.y)
  result[key]=maxf(result.get(key,-INF),point.z)
 return result
func test_thick_photographed_shoulders_retain_their_physical_crags()->void:
 var path:=OS.get_environment("STORY_SHOULDER_GENERATOR")
 var generator:GDScript=CURRENT if path.is_empty() else load(path)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 # Saved physical formations at P12 and P20. The uncarved and full-detail
 # fixtures hold the existing mass, ledge placement and bounded cuts fixed.
 # Count real surface vertices whose complete shoulder has room for detail.
 for index:int in [9,12,20]:
  var entry:Array=anchors[index]
  var original:=_front(UNCARVED.make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4])[0])
  var full:=_front(FULL_DETAIL.make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4])[0])
  var current:=_front(generator.make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4])[0])
  var old:=_front(preload("res://tests/fixtures/september17/cliff-shoulder-union/before.gd").make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4])[0])
  var seen:Dictionary={}
  var coordinate:float=entry[0].origin.dot(entry[0].basis.x)
  var total:=0;var suppressed:=0
  for point:Vector2 in original:
   if point.y<1 or point.y>entry[2]-1 or not current.has(point) or not full.has(point):continue
   if original[point]-UNCARVED._native_depth(coordinate+point.x,point.y)<1.7:continue
   var expected:float=original[point]-full[point]
   if expected<.30:continue
   total+=1
   if original[point]-old[point]<expected*.80 and original[point]-current[point]>=expected*.99 and seen.size()<6:
    var bucket:=floori(point.x)
    if not seen.has(bucket):
     seen[bucket]=true
     print("PIN ",index," ",point," expected=",expected," old=",original[point]-old[point]," current=",original[point]-current[point])
   if original[point]-current[point]<expected*.90:suppressed+=1
  print("SHOULDER_DETAIL anchor=",entry[0].origin," eligible=",total," suppressed=",suppressed)
  assert_gt(total,500,"Exercise actual broad photographed shoulders, not only a synthetic surface")
  assert_eq(suppressed,0,"Fully exposed shoulders must not lose crags because only their thinner underlying body was considered")
