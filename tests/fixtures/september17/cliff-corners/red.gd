extends GutTest
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
const CORNER=preload("res://tests/fixtures/september17/cliff-corners/rooted-study.gd")
func _region()->HeightfieldRegion:
 var plan:=HeightfieldPlan.new(17,64,12,"mean",4)
 plan.set_raw_height_override(func(x:int,z:int)->float:return 16.0 if x>=0 and x<=1 and z>=0 and z<=1 else 0.0)
 return plan.compute_region(0,0,8)
func test_exposed_native_corner_receives_continuous_rock_relief()->void:
 ROCKS.prepare()
 var region:=_region();var cliffs:=CliffDressing.compute(region,-3,-3,8)
 var walls:Array=cliffs.outer_wall
 assert_gt(walls.size(),3)
 var pose:Transform3D=walls[0]
 for wall:Transform3D in walls:
  if wall.origin.x>pose.origin.x or (is_equal_approx(wall.origin.x,pose.origin.x) and wall.origin.z>pose.origin.z):pose=wall
 for wall:Transform3D in walls:
  if wall.basis==pose.basis and Vector2(wall.origin.x,wall.origin.z)==Vector2(pose.origin.x,pose.origin.z):pose.origin.y=minf(pose.origin.y,wall.origin.y)
 var data:=ROCKS.compute(region,-3,-3,8,2697992464)
 var direction:Vector3=pose.basis*Vector3(1,0,1).normalized()
 var covered:=0
 for y:float in [2,5,8,11,14]:
  var center:Vector3=pose*Vector3(-1.5,y,-1.5)
  var front:=-INF
  for rock:Dictionary in data.placements:
   if rock.kind!="rock":continue
   var inverse:Transform3D=rock.transform.affine_inverse()
   var faces:PackedVector3Array=ROCKS._faces(rock)
   for i in range(0,faces.size(),3):
    var hit=Geometry3D.ray_intersects_triangle(inverse*(center+direction*20),inverse.basis*(-direction),faces[i],faces[i+1],faces[i+2])
    if hit!=null:front=maxf(front,(rock.transform*hit-center).dot(direction))
  if front>3.2:covered+=1
 print("CORNER_DIAGONAL pose=",pose," covered=",covered)
 assert_gte(covered,3,"Most of the exposed convex corner must carry relief, rather than a bare repeating column")
