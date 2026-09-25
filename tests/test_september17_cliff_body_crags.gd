extends GutTest
const BASE=preload("res://tests/fixtures/september17/cliff-body-crags/before.gd")
const UNFRACTURED=preload("res://tests/fixtures/september17/cliff-body-crags/unfractured.gd")
const CURRENT_UNFRACTURED=preload("res://tests/fixtures/september17/cliff-scale/selected-unfractured.gd")
# Historical dense-fracture art control. Its half-metre cleft density was
# superseded by the owner's explicit request to remove noisy dark gouges.
const CRAGS=preload("res://tests/fixtures/september17/cliff-shoulder-union/cap-preserving.gd")

func _generator()->GDScript:
 var path:=OS.get_environment("STORY_BODY_GENERATOR")
 return CRAGS if path.is_empty() else load(path)

func _form(generator:GDScript,index:int)->Dictionary:
 var entry:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()[index]
 return generator.make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4])[0]

func _front(form:Dictionary)->Dictionary:
 var result:Dictionary={}
 for p:Vector3 in form.faces:
  var key:=Vector2(p.x,p.y)
  result[key]=maxf(result.get(key,-INF),p.z)
 return result

func _cut_coverage(generator:GDScript,index:int,reference_generator:GDScript=UNFRACTURED)->Vector3:
 var reference:=_front(_form(reference_generator,index));var current:=_front(_form(generator,index))
 var tested:=0;var cut:=0;var depth:=0.0
 for key:Vector2 in reference:
  if key.y<1.0 or reference[key]<3.0 or not current.has(key):continue
  var recess:float=reference[key]-current[key]
  tested+=1
  if recess>.50:cut+=1
  depth=maxf(depth,recess)
 return Vector3(tested,cut,depth)

func test_frozen_dense_fracture_revision_contains_resolved_geometric_fractures()->void:
 for index:int in [0,4,12,20]:
  var before:=_cut_coverage(BASE,index);var current:=_cut_coverage(_generator(),index,CURRENT_UNFRACTURED)
  print("BODY_CUT anchor=",index," before=",before," current=",current)
  assert_gt(current.x,100.0,"Exercise exposed stone in the actual photographed formation")
  assert_gt(current.y/current.x,.10,"At least a tenth of thick stone must carry a half-metre physical cleft, not just shader grain")
  assert_lt(current.y/current.x,.65,"Leave coherent broad stone faces between the clefts")
  assert_lt(current.z,2.5,"Local fractures must not hollow away whole outcroppings")
