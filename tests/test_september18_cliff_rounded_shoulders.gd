extends GutTest

# Pins the full-projection ("current") rock shape this test was written for.
# The owner-selected September 23 default compresses projection (subtle),
# which narrows ledges by design; test_september23_cliff_directions.gd
# covers that style, including its retained wall turf.
const _STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func before_all()->void:_STYLE.apply("current")
func after_all()->void:_STYLE.apply("chosen")
const BEFORE=preload("res://tests/fixtures/september18/cliff-connected-relief/before.gd")
func _front(faces:PackedVector3Array)->Dictionary:
 var result:Dictionary={}
 for p:Vector3 in faces:
  if p.z<0.0:continue
  var key:=Vector2(p.x,p.y).snapped(Vector2.ONE*.0001)
  result[key]=maxf(result.get(key,-INF),p.z)
 return result
func test_photo_has_physical_bumps_without_moving_crown_or_unbounded_depth()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var anchor:Array=anchors[20]
 var old:=_front(BEFORE.make(anchor[0],anchor[1],anchor[2],2697992464,null,anchor[3],anchor[4])[0].faces)
 var current:=_front(source.make(anchor[0],anchor[1],anchor[2],2697992464,null,anchor[3],anchor[4])[0].faces)
 var moved:=0;var columns:Dictionary={};var maximum:=0.0;var crown:=0.0
 for key:Vector2 in old:
  if not current.has(key):continue
  var delta:float=current[key]-old[key]
  maximum=maxf(maximum,absf(delta))
  if key.y>anchor[2]-1.3:crown=maxf(crown,absf(delta))
  if key.y>1.0 and key.y<anchor[2]-2.0 and delta>.35:
   moved+=1;columns[key.x]=true
 print("ROUNDED_SHOULDERS moved=",moved," columns=",columns.size()," maximum=",maximum," crown=",crown)
 assert_gt(moved,150,"Substantial exterior mesh patches must change; a shader cannot satisfy this")
 assert_gt(columns.size(),20,"The added volume must have broad support across the photo wall")
 assert_lt(maximum,1.5,"Keep the additional volume moderate rather than oversized masses")
 assert_lt(crown,.001,"Keep the previously repaired crown attachment flush")
