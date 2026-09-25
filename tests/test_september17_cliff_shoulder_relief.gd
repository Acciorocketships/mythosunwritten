extends GutTest
# Historical depth/cap pins: the owner subsequently rejected these deeper gouges
# and requested wider terraces. Keep the exact repair proof on its frozen pair;
# current terrain is covered by terraced_bases, cut_depth and native-root tests.
const CURRENT=preload("res://tests/fixtures/september17/cliff-shoulder-union/cap-preserving.gd")
const UNCARVED=preload("res://tests/fixtures/september17/cliff-shoulder-union/unfractured.gd")
const FULL_DETAIL=preload("res://tests/fixtures/september17/cliff-shoulder-union/full-detail.gd")
func _front(form:Dictionary)->Dictionary:
 var result:Dictionary={}
 for point:Vector3 in form.faces:
  var key:=Vector2i(roundi(point.x*10000),roundi(point.y*10000))
  result[key]=maxf(result.get(key,-INF),point.z)
 return result
func test_frozen_shoulder_repair_restored_crags_below_the_caps()->void:
 var path:=OS.get_environment("STORY_SHOULDER_GENERATOR")
 var generator:GDScript=CURRENT if path.is_empty() else load(path)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 # Actual exposed face samples below the shelves, identified in the photo
 # reproduction. Cap transitions deliberately retain their original shape.
 var sites:Dictionary={9:[Vector2(-6,1),Vector2(-5,1),Vector2(-2,1.2)],12:[Vector2(.5,3.8),Vector2(2.75,3.4),Vector2(3,3.2)],20:[Vector2(4,4.2),Vector2(5,3),Vector2(6,4.2)]}
 for index:int in sites:
  var entry:Array=anchors[index]
  var original:=_front(UNCARVED.make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4])[0])
  var full:=_front(FULL_DETAIL.make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4])[0])
  var current:=_front(generator.make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4])[0])
  for sample:Vector2 in sites[index]:
   var point:=Vector2i(roundi(sample.x*10000),roundi(sample.y*10000))
   assert_true(current.has(point),"Retain the photographed physical sample")
   if not current.has(point):continue
   var expected:float=original[point]-full[point]
   var relief:float=original[point]-current[point]
   print("SHOULDER_PIN anchor=",index," xy=",sample," expected=",expected," actual=",relief)
   assert_gte(relief,expected*.90,"Exposed shoulder faces must retain physical crags")

func test_frozen_shoulder_repair_preserved_the_photographed_usable_caps()->void:
 var generator:GDScript=CURRENT
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 for index:int in [9,12,20]:
  var entry:Array=anchors[index]
  var before:Dictionary=preload("res://tests/fixtures/september17/cliff-shoulder-union/before.gd").make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4])[0]
  var current:Dictionary=generator.make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4])[0]
  assert_eq(current.green,before.green,"More detailed shoulder faces must not narrow or reshape the usable caps")
