extends GutTest
const ROCKS=preload("res://tests/fixtures/september17/cliff-connected-stone/local-dressing.gd")
const CORNER=preload("res://tests/fixtures/september17/cliff-connected-stone/local-corner.gd")
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

func test_corner_solids_are_closed_at_short_and_tall_native_heights()->void:
 for height:float in [16,32,64]:
  var rock:=CORNER.make(Transform3D.IDENTITY,height,2697992464)
  var edges:Dictionary={};var bad:=0;var degenerate:=0
  for i in range(0,rock.faces.size(),3):
   var a:Vector3=rock.faces[i];var b:Vector3=rock.faces[i+1];var c:Vector3=rock.faces[i+2]
   if (b-a).cross(c-a).length_squared()<1e-14:degenerate+=1
   for j in 3:
    a=rock.faces[i+j];b=rock.faces[i+(j+1)%3]
    var key:Array=[a,b] if a<b else [b,a]
    edges[key]=edges.get(key,0)+1
  for count:int in edges.values():
   if count!=2:bad+=1
  print("CORNER_CLOSED height=",height," bad=",bad," degenerate=",degenerate)
  assert_eq(bad,0,"Mapped joins retain every shared physical edge")
  assert_eq(degenerate,0,"Compression cannot collapse collision triangles")
  assert_lte(rock.bounds.end.y,height+.001)

func test_saved_photo_corners_have_variable_full_height_relief()->void:
 var rows:Array=FileAccess.open("res://tests/fixtures/september17/cliff-corners/photographed-rows.bin",FileAccess.READ).get_var()
 var forms:=CORNER.formations(rows,2697992464)
 assert_gt(forms.size(),1)
 for rock:Dictionary in forms:
  var depths:Array[float]=[];var covered:=0
  var height:float=rock.top-rock.anchor.y
  for fraction:float in [.13,.3,.5,.72,.94]:
   var y:=height*fraction;var direction:=Vector3(1,0,1).normalized()
   var center:=Vector3(-1.5,y,-1.5);var depth:=-INF
   for i in range(0,rock.faces.size(),3):
    var hit=Geometry3D.ray_intersects_triangle(center+direction*20,-direction,rock.faces[i],rock.faces[i+1],rock.faces[i+2])
    if hit!=null:depth=maxf(depth,(hit-center).dot(direction)-1.5)
   depths.append(depth)
   if depth>float(CORNER._native(0,y,rock.transform)[0])+.04:covered+=1
  print("PHOTO_CORNER anchor=",rock.anchor," height=",height," depth=",depths," covered=",covered)
  assert_gte(covered,3,"Most of the corner height carries rooted relief")
  assert_gt(depths.max()-depths.min(),.6,"Avoid a uniform-radius corner column")

func test_corner_render_fades_to_native_attachment_normals()->void:
 var rock:=CORNER.make(Transform3D.IDENTITY,32,2697992464)
 var mesh:=ROCKS.CRAGS.mesh(rock)
 var arrays:=mesh.surface_get_arrays(0)
 var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
 var thin:=0;var worst:=0.0;var independent:=0
 for i in points.size():
  var root:Array=rock.native_roots[points[i]]
  if float(root[1])<.02 and points[i].z>0 and points[i].x>0:
   thin+=1;worst=maxf(worst,normals[i].angle_to(root[0]))
  if float(root[1])>.9:independent+=1
  if absf(colors[i].a-float(root[1]))>1.0/255.0+.00001:fail_test("Shader and normal attachment must share the same weight");return
 assert_gt(thin,20)
 assert_gt(independent,100)
 assert_lt(worst,.04,"The thin join inherits the actual native corner normal")

func test_native_corner_preparation_is_safe_for_detached_worker_geometry()->void:
 ROCKS.prepare()
 var pose:=Transform3D(Basis(Vector3.UP,PI*.5),Vector3(10.5,0,10.5))
 var expected:=CORNER.make(pose,16,2697992464)
 var thread:=Thread.new()
 assert_eq(thread.start(func():return CORNER.make(pose,16,2697992464)),OK)
 var actual:Dictionary=thread.wait_to_finish()
 assert_eq(actual.faces,expected.faces)
 assert_eq(actual.native_roots,expected.native_roots)

func test_all_orientations_keep_buried_feet_and_actual_collision()->void:
 ROCKS.prepare();var region:=_region()
 var data:=ROCKS.compute(region,-3,-3,8,2697992464)
 var corners:=0;var feet:=0;var floating:=0;var expected_collision:=0
 var rotations:Dictionary={}
 for rock:Dictionary in data.placements:
  if rock.kind!="rock":continue
  expected_collision+=rock.faces.size()
  if not rock.has("native_roots"):continue
  corners+=1;rotations[rock.transform.basis]=true
  var minimum:float=rock.base
  for p:Vector3 in rock.faces:
   var world:Vector3=rock.transform*p
   if absf(world.y-minimum)>.001:continue
   feet+=1
   if world.y>TerrainSurfaceField.surface_y(region,world.x,world.z)-.05:floating+=1
 assert_eq(rotations.size(),4)
 assert_eq(corners,4)
 assert_gt(feet,100)
 assert_eq(floating,0,"Every bottom contact remains below the real neighboring ground")
 assert_eq(data.collision_faces.size(),expected_collision,"Visual and physical solids use identical triangles")

func test_corner_admission_respects_complete_public_and_wet_footprints()->void:
 ROCKS.prepare();var region:=_region();var cliffs:=CliffDressing.compute(region,-3,-3,8)
 var dry:=CORNER.formations(cliffs.outer_wall,2697992464,region)
 var solid:Dictionary=dry[0]
 var box:AABB=solid.bounds
 # A narrow reservation at the outer foot, away from the anchor, still vetoes it.
 var rect:=Rect2(Vector2(box.end.x-.1,box.position.z),Vector2(.2,box.size.z))
 var ground:=FeatureGroundField.new([], [FeatureGroundShape.axis_rect(rect)],0)
 var context:=FeatureContext.new(Rect2(-1000,-1000,2000,2000),ground,EnvironmentInstancePayload.new())
 var reserved:=CORNER.formations(cliffs.outer_wall,2697992464,region,context)
 assert_gt(dry.size(),reserved.size())
 var wet:=ROCKS.compute(region,-3,-3,8,2697992464,null,preload("res://tests/test_september16_outcrops.gd").ChannelWater.new())
 assert_eq(wet.collision_faces.size(),0)

func test_corner_ownership_is_identical_across_independent_chunk_halos()->void:
 ROCKS.prepare();var region:=_region()
 var whole:=ROCKS.compute(region,-3,-3,8,2697992464)
 var expected:Dictionary={};var actual:Dictionary={};var duplicates:=0
 for rock:Dictionary in whole.placements:
  if rock.has("native_roots"):expected[rock.id]=rock.faces
 for lo:Vector2i in [Vector2i(-3,-3),Vector2i(1,-3),Vector2i(-3,1),Vector2i(1,1)]:
  var part:=ROCKS.compute(region,lo.x,lo.y,4,2697992464)
  for rock:Dictionary in part.placements:
   if not rock.has("native_roots"):continue
   if actual.has(rock.id):duplicates+=1
   actual[rock.id]=rock.faces
 assert_eq(duplicates,0)
 assert_eq(actual,expected,"Independent chunks publish the same closed corner solids exactly once")

func _upper_corner_projection(generator:GDScript)->Array:
 var rock:Dictionary=generator.make(Transform3D(Basis.IDENTITY,Vector3(10.5,0,10.5)),64,2697992464)
 var values:Array[float]=[]
 for fraction:float in [.52,.65,.78,.9]:
  for angle:float in [25,45,65]:
   var direction:=Vector3(sin(deg_to_rad(angle)),0,cos(deg_to_rad(angle)))
   var center:=Vector3(-1.5,64*fraction,-1.5);var depth:=-INF
   for i in range(0,rock.faces.size(),3):
    var hit=Geometry3D.ray_intersects_triangle(center+direction*20,-direction,rock.faces[i],rock.faces[i+1],rock.faces[i+2])
    if hit!=null:depth=maxf(depth,(hit-center).dot(direction)-1.5)
   var u:float=angle/90.0*3.0-1.5
   values.append(depth-float(generator._native(u,64*fraction,rock.transform)[0]))
 return values

func test_tall_corner_body_does_not_collapse_into_a_native_tile_strip()->void:
 var before:=_upper_corner_projection(preload("res://tests/fixtures/september17/cliff-scale/shallow-body-control.gd"))
 var current:=_upper_corner_projection(CORNER)
 var bare_before:=0;var bare_current:=0
 for value:float in before:
  if value<.35:bare_before+=1
 for value:float in current:
  if value<.35:bare_current+=1
 print("UPPER_CORNER_BODY before=",before," current=",current)
 assert_gt(bare_before,5,"The rejected tall study reproduces insufficient independent upper relief")
 assert_lt(bare_current,bare_before/2,"Restore thickness over most of the thin repeated column")
