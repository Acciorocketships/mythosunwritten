extends GutTest
const ROOT="res://docs/qa/2026-09-19-manual/122-bank-attachments"
const ATTACH=preload("res://tests/fixtures/september19/bank-attachments/attachments.gd")
const SHAPE=preload("res://tests/fixtures/september19/bank-attachments/shape.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
var sources:Dictionary={}
var plants:Array=[]
var banks:Dictionary={}
func before_all()->void:
 ROCKS.prepare()
 for rock:Dictionary in FileAccess.open(ROOT.path_join("sources.bin"),FileAccess.READ).get_var():sources[rock.id]=rock
 plants=FileAccess.open(ROOT.path_join("source-plants.bin"),FileAccess.READ).get_var()
 for rock:Dictionary in FileAccess.open("res://docs/qa/2026-09-19-manual/121-shoreline-rock/owned/all-banks.bin",FileAccess.READ).get_var():banks[rock.id]=rock
func test_ferns_follow_the_same_bank_triangles_as_the_solid()->void:
 var examined:=0;var floating:=0;var maximum:=0.0;var mapped_count:=0
 for plant:Dictionary in plants:
  if not banks.has(plant.support_id):continue
  var bank:Dictionary=banks[plant.support_id]
  if plant.support_point.y<bank.replay_recipe.shore_level+.3:continue
  examined+=1
  var mapped:Dictionary=plant if OS.get_environment("BANK_ATTACHMENT_BASELINE")=="1" else ATTACH.map_attachment(plant,sources[plant.support_id])
  if mapped.is_empty():continue
  mapped_count+=1
  var p:Vector3=(bank.transform as Transform3D).affine_inverse()*mapped.support_point
  var distance:=INF
  for i in range(0,bank.faces.size(),3):
   var a:Vector3=bank.faces[i];var b:Vector3=bank.faces[i+1];var c:Vector3=bank.faces[i+2]
   distance=minf(distance,_triangle_distance(p,a,b,c))
  if distance>.004:
   floating+=1
   print("BANK_FLOAT ",plant.support_id," source=",plant.support_point," new=",mapped.support_point," distance=",distance)
  maximum=maxf(maximum,distance)
 print("BANK_ATTACHMENT count=",examined," mapped=",mapped_count," floating=",floating," maximum=",maximum)
 assert_gt(examined,3,"Exercise the photographed banks' actual above-water plant candidates")
 assert_gt(mapped_count,3,"Retain supported plants rather than deleting every fern")
 assert_eq(floating,0,"Every remapped plant root must lie on the actual admitted bank triangles")
func test_point_mapping_preserves_the_judged_bank_geometry()->void:
 var checked:=0;var mismatch:=0
 for id:String in banks:
  var bank:Dictionary=banks[id]
  var source:Dictionary=sources[id]
  # The source frozen in pass121 contains two subsequently removed collapsed
  # triangles. Evaluate that exact frozen source to pin the deformation itself.
  var original:PackedVector3Array=bank.shore_source_faces
  var seen:Dictionary={}
  for i in original.size():
   if seen.has(original[i]):continue
   seen[original[i]]=true;checked+=1
   if (SHAPE.point(original[i],source)[0] as Vector3).distance_to(bank.faces[i])>.000001:mismatch+=1
 assert_gt(checked,10000)
 assert_eq(mismatch,0,"Extracting attachment mapping may not change the already judged rock shape")

static func _triangle_distance(p:Vector3,a:Vector3,b:Vector3,c:Vector3)->float:
 var normal:Vector3=(b-a).cross(c-a).normalized()
 if normal.is_zero_approx():return INF
 var height:float=(p-a).dot(normal)
 var q:=p-normal*height
 if (b-a).cross(q-a).dot(normal)>=0 and (c-b).cross(q-b).dot(normal)>=0 and (a-c).cross(q-c).dot(normal)>=0:return absf(height)
 var distance:=INF
 for edge:Array in [[a,b],[b,c],[c,a]]:
  var d:Vector3=edge[1]-edge[0]
  var t:=clampf((p-edge[0]).dot(d)/maxf(d.length_squared(),1e-12),0,1)
  distance=minf(distance,p.distance_to(edge[0]+d*t))
 return distance

func test_bank_plant_ownership_does_not_change_selection()->void:
 var all:=ATTACH.publish(plants,sources.values(),banks.values())
 var first:Array=[];var second:Array=[]
 for bank:Dictionary in banks.values():
  if bank.anchor.z<288:first.append(bank)
  else:second.append(bank)
 var split:=ATTACH.publish(plants,sources.values(),first)
 split.append_array(ATTACH.publish(plants,sources.values(),second))
 var expected:Dictionary={};var actual:Dictionary={}
 for plant:Dictionary in all:expected[plant.id]=plant
 for plant:Dictionary in split:actual[plant.id]=plant
 print("BANK_PUBLISHED ",all.size())
 assert_gt(all.size(),3,"Keep an actual above-water bank population after conservative competition")
 assert_eq(actual,expected,"Adjacent ownership partitions publish the identical roots, poses and bounds")
 assert_eq(split.size(),actual.size(),"No plant is published by two owners")
 var crowds:=0
 for i in all.size():
  for j in range(i+1,all.size()):
   if ROCKS._canopies_crowd(all[i].bounds,all[j].bounds):crowds+=1
 assert_eq(crowds,0,"Narrowing banks must not crowd ferns selected on the wider original rocks")

class OwnedWater extends WaterFieldContext:
 var allowed:Array=[]
 var outside:=0
 func has_sources()->bool:return true
 func covers(point:Vector2)->bool:
  for bounds:AABB in allowed:
   if Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)).grow(.001).has_point(point):return true
  return false
 func level_at(point:Vector2)->float:
  if not covers(point):outside+=1
  return 13.7
func test_bank_plants_query_only_admitted_owner_water()->void:
 var chosen:Array=[]
 var water:=OwnedWater.new()
 for bank:Dictionary in banks.values():
  if bank.anchor.z>=288 and bank.top<21:
   chosen.append(bank);water.allowed.append(bank.bounds)
 var result:=ATTACH.publish(plants,sources.values(),chosen,null,null,water)
 assert_gt(result.size(),0)
 assert_eq(water.outside,0,"Potential halo plant poses must not query water outside the admitted owners")
 for plant:Dictionary in result:assert_gte(plant.support_point.y,14.0)

func test_adapted_canopies_respect_public_clearance_without_mutating_sources()->void:
 var reserved:=FeatureGroundShape.axis_rect(Rect2(-1000,-1000,2000,2000))
 var context:=FeatureContext.new(reserved.bounds(),FeatureGroundField.new([],[reserved],0.0),EnvironmentInstancePayload.new())
 var original:=var_to_bytes(plants)
 var result:=ATTACH.publish(plants,sources.values(),banks.values(),null,context)
 assert_true(result.is_empty(),"The moved complete canopy must still respect the common public reservation")
 assert_eq(var_to_bytes(plants),original,"Bank publication must leave canonical dry proposals unchanged")
