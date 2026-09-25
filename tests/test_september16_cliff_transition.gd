extends GutTest
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const BEFORE=preload("res://tests/fixtures/september16/crags_before_wall_transition.gd")
const PROFILE=preload("res://tests/test_september16_continuous_cliffs.gd")
func test_relief_reaches_near_crown_on_most_short_and_tall_walls()->void:
 var probe=PROFILE.new()
 for height:float in [16,32,64]:
  var forms:Array=CRAGS.make(Transform3D.IDENTITY,24,height,2697992464)
  var covered:=0
  for x in range(-11,12):
   if probe._front(forms,x,height*.94)>CRAGS._native_depth(x,height*.94)+.04:covered+=1
  print("UPPER_CLIFF height=",height," covered=",covered,"/23")
  assert_gte(covered,17,"Most of a wall needs relief near its own crown, including tall walls")
 probe.free()
func test_selected_lower_shoulders_project_farther_without_widening_everywhere()->void:
 var probe=PROFILE.new();var old:Array=[];var current:Array=[]
 for x:float in [-24,0,24]:
  var pose:=Transform3D(Basis.IDENTITY,Vector3(x,0,0))
  old.append_array(BEFORE.make(pose,24,16,2697992464));current.append_array(CRAGS.make(pose,24,16,2697992464))
 var broadened:=0;var restrained:=0;var deepest:=0.0
 for x in range(-34,35,2):
  var before:float=probe._front(old,x,.5);var after:float=probe._front(current,x,.5)
  if after-before>.65:broadened+=1
  if after<4:restrained+=1
  deepest=maxf(deepest,after)
 print("LOWER_SHOULDERS broadened=",broadened," restrained=",restrained," deepest=",deepest)
 assert_gte(broadened,9,"Add broad lower buttresses in selected areas")
 assert_gte(restrained,4,"Keep recesses between the broader feet")
 assert_lt(deepest,8.0,"Retain the agreed restrained maximum projection")
 probe.free()

func _attachment_error(generator:GDScript)->Vector2:
 var faces:PackedVector3Array=load("res://terrain/environment/meshes/kaykit/kaykit_cliff_wall_piece_00.res").get_faces()
 var rock:Dictionary=generator.make(Transform3D.IDENTITY,24,16,2697992464)[0]
 var mesh:ArrayMesh=generator.mesh(rock)
 var arrays:=mesh.surface_get_arrays(0);var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 var count:=0;var error:=0.0
 for i in points.size():
  var p:Vector3=points[i]
  if p.z<.25 or p.z>1.5:continue
  var q:=Vector3(fposmod(p.x,3.0)-1.5,fposmod(p.y+.3,4.0)-.3,5)
  var depth:=-INF;var normal:=Vector3.ZERO
  for j in range(0,faces.size(),3):
   var hit=Geometry3D.ray_intersects_triangle(q,Vector3.FORWARD,faces[j],faces[j+1],faces[j+2])
   if hit!=null and hit.z>depth:
    depth=hit.z;normal=(faces[j+2]-faces[j]).cross(faces[j+1]-faces[j]).normalized()
  # Only genuinely exposed, thin attachment vertices, not buried backs.
  if p.z-depth<.04 or p.z-depth>.30:continue
  error+=normals[i].angle_to(normal);count+=1
 return Vector2(error/maxi(1,count),count)
func test_thin_attachment_normals_follow_actual_native_wall_faces()->void:
 CRAGS.prepare()
 var before:=_attachment_error(BEFORE);var current:=_attachment_error(CRAGS)
 print("WALL_ATTACHMENT mean_angle_before=",rad_to_deg(before.x)," current=",rad_to_deg(current.x)," samples=",current.y)
 assert_gt(current.y,40.0,"Sample the exposed native/addition junction, not only buried geometry")
 assert_lt(current.x,before.x*.65,"Blend thin attachments toward the actual wall normals")
 assert_lt(current.x,.35,"Keep the attachment normal discontinuity small")
func test_tall_faces_keep_enough_vertical_geometry_for_native_scale_crags()->void:
 var form:Dictionary=CRAGS.make(Transform3D.IDENTITY,24,64,2697992464)[0]
 var longest:=0.0
 for i in range(0,form.faces.size(),3):
  for edge in 3:
   var a:Vector3=form.faces[i+edge];var b:Vector3=form.faces[i+(edge+1)%3]
   if absf(a.x-b.x)>.001 or minf(a.z,b.z)<.5:continue
   longest=maxf(longest,absf(a.y-b.y))
 print("TALL_ROCK_SAMPLE longest=",longest)
 assert_lt(longest,1.5,"Tall wall geometry must resolve crags rather than stretch them vertically")
