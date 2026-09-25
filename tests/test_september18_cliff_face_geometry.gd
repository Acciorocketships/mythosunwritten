extends GutTest
const BEFORE=preload("res://tests/fixtures/september18/cliff-shape-envelope/before.gd")
func _front(faces:PackedVector3Array)->Dictionary:
 var result:Dictionary={}
 for p:Vector3 in faces:
  if p.z<0.0:continue
  var key:=Vector2(p.x,p.y).snapped(Vector2.ONE*.0001)
  result[key]=maxf(result.get(key,-INF),p.z)
 return result
func test_photo_face_has_real_volume_variation_while_retaining_ledge_caps()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var anchor:Array=anchors[20]
 var before:Dictionary=BEFORE.make(anchor[0],anchor[1],anchor[2],2697992464,null,anchor[3],anchor[4])[0]
 var current:Dictionary=source.make(anchor[0],anchor[1],anchor[2],2697992464,null,anchor[3],anchor[4])[0]
 var old:=_front(before.faces);var now:=_front(current.faces)
 var moved:=0;var outward:=0;var columns:Dictionary={};var crown:=0.0
 for key:Vector2 in old:
  if not now.has(key):continue
  var delta:float=now[key]-old[key]
  if key.y>anchor[2]-1.3:crown=maxf(crown,absf(delta))
  if key.y<1.0 or key.y>anchor[2]-2.0:continue
  if absf(delta)>.08:moved+=1;columns[key.x]=true
  if delta>.08:outward+=1
 print("FACE_GEOMETRY moved=",moved," outward=",outward," columns=",columns.size()," crown=",crown," turf_points=",current.green.size())
 assert_gt(moved,150,"The physical face needs meaningful shape variation, not a material change")
 assert_gt(outward,50,"Some formations must add real volume beyond the previous smooth face")
 assert_gt(columns.size(),20,"Added rock must span supported patches rather than isolated spikes")
 var green_points:Dictionary={}
 for p:Vector3 in current.green:green_points[p.snapped(Vector3.ONE*.0001)]=true
 var missing:=0
 for p:Vector3 in before.green:
  if not green_points.has(p.snapped(Vector3.ONE*.0001)):
   missing+=1
   var nearest:=INF
   for q:Vector3 in current.green:nearest=minf(nearest,p.distance_to(q))
   print("TURF_DIFFERENCE vertex=",p," distance=",nearest)
 print("PRESERVED_TURF missing_vertices=",missing)
 assert_eq(missing,0,"Retain the full existing curved grass ledges")
 assert_lt(crown,.001,"Keep the repaired upper attachment unchanged")
