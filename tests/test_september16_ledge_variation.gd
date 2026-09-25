extends GutTest
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
func test_ledge_family_contains_sloping_turf_and_level_walking_patches()->void:
 ROCKS.prepare()
 var graded:=0;var level:=0
 for id:StringName in ROCKS._definitions:
  if id in ROCKS.PLANTS:continue
  var green:PackedVector3Array=ROCKS._definitions[id].green
  var graded_area:=0.0;var level_area:=0.0
  for i in range(0,green.size(),3):
   var a:=green[i]*Vector3(26,16,9);var b:=green[i+1]*Vector3(26,16,9);var c:=green[i+2]*Vector3(26,16,9)
   var n:Vector3=(c-a).cross(b-a);var area:float=n.length()*.5
   if n.normalized().y>.99999:level_area+=area
   elif n.normalized().y>.82:graded_area+=area
  if graded_area>5:graded+=1
  if level_area>5:level+=1
 print("LEDGE_VARIATION graded_forms=",graded," level_forms=",level)
 assert_gte(graded,3,"Whole-family horizontal shelves must not recur")
 assert_gte(level,2,"Useful native walking patches remain among the graded shoulders")

func test_outcrops_cover_a_majority_of_the_requested_full_height_wall()->void:
 ROCKS.prepare()
 var walls:=[]
 for x in range(-16,16):
  for y in 4:walls.append(Transform3D(Basis.IDENTITY,Vector3(x*3+1.5,y*4,0)))
 var forms:=ROCKS.formations(walls,2697992464)
 var hit_count:=0;var total:=0
 for x in range(-46,47,2):
  for y in range(1,16,2):
   total+=1;var covered:=false
   for rock:Dictionary in forms:
    var box:AABB=rock.bounds
    if x<box.position.x or x>box.end.x or y<box.position.y or y>box.end.y:continue
    var inverse:Transform3D=rock.transform.affine_inverse()
    var origin:Vector3=inverse*Vector3(x,y,30);var direction:Vector3=inverse.basis*Vector3.FORWARD
    var faces:PackedVector3Array=ROCKS._faces(rock)
    for i in range(0,faces.size(),3):
     var hit=Geometry3D.ray_intersects_triangle(origin,direction,faces[i],faces[i+1],faces[i+2])
     if hit!=null and (rock.transform*hit).z>.5:covered=true;break
    if covered:break
   if covered:hit_count+=1
 var coverage:=float(hit_count)/total
 print("WALL_ROCK_COVERAGE hits=",hit_count," total=",total," fraction=",coverage)
 assert_gt(coverage,.5,"The owner requested substantially more wall coverage")
 # The September 16 full-height request supersedes the older <90% sparse
 # coverage ceiling. Actual thin-junction normals and native crown protection
 # are checked in cliff_transition and continuous_cliffs, respectively.
