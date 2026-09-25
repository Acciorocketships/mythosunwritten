extends GutTest
const C=preload('res://scripts/terrain/field/CliffCornerCrags.gd')
func _backing()->PackedVector3Array:
 var faces:PackedVector3Array=load('res://terrain/environment/meshes/kaykit/kaykit_cliff_inner_wall_piece_00.res').get_faces()
 var wall:PackedVector3Array=load('res://terrain/environment/meshes/kaykit/kaykit_cliff_wall_piece_00.res').get_faces()
 for center:float in [3,6,9]:
  for p:Vector3 in wall:
   faces.append(Vector3(center+p.x,p.y,p.z))
  for p:Vector3 in wall:faces.append(Vector3(p.z,p.y,center-p.x))
 return faces
func test_inner_attachment_samples_actual_diagonal_backing()->void:
 C.prepare();C.CRAGS.prepare()
 var faces:=_backing();var maximum:=0.0;var samples:=0
 var pose:=Transform3D(Basis.IDENTITY,Vector3(-445.5,32,-301.5))
 for y:float in [.1,1,2,3,1.13,2.17]:
  for u:float in [-5.8,-4.13,-2.3,-1.2,-1.05,-.95,.95,1.05,1.2,2.3,4.13,5.87]:
   var base:=Vector3(maxf(u,0),y,maxf(-u,0))
   var actual:=-INF
   for i in range(0,faces.size(),3):
    var hit=Geometry3D.ray_intersects_triangle(base+Vector3(20,0,20),Vector3(-1,0,-1).normalized(),faces[i],faces[i+1],faces[i+2])
    if hit!=null:actual=maxf(actual,hit.x-base.x)
   assert_true(is_finite(actual))
   maximum=maxf(maximum,absf(C._inner_native(u,y,pose)[0]-actual));samples+=1
 print('INNER_ATTACHMENT samples=',samples,' maximum_error=',maximum)
 assert_lt(maximum,.025,'Thin inner joins must follow the actual diagonal intersection, including the adjoining straight tiles')
func test_inner_attachment_has_no_synthetic_switch_at_one_metre()->void:
 C.prepare();C.CRAGS.prepare()
 var maximum:=0.0
 for y:float in [.1,1,2,3]:
  for u:float in [-1,1]:
   var a:Array=C._inner_native(u-.001,y,Transform3D.IDENTITY)
   var b:Array=C._inner_native(u+.001,y,Transform3D.IDENTITY)
   maximum=maxf(maximum,absf(a[0]-b[0]))
 assert_lt(maximum,.01,'Changing sample source must not add a ledge or crease')

func test_inner_upper_metre_remains_nearly_flush()->void:
 var worst:=0.0;var samples:=0
 for height:float in [4,8,32]:
  for rotation in 4:
   var pose:=Transform3D(Basis(Vector3.UP,rotation*PI*.5),Vector3(-445.5,32,-301.5))
   var form:=C.make_inner(pose,height,2697992464)
   for p:Vector3 in form.faces:
    if p.y<height-1 or p.y>height or minf(p.x,p.z)<0:continue
    var native:Array=C._inner_native(p.x-p.z,p.y,pose)
    worst=maxf(worst,minf(p.x,p.z)-float(native[0]));samples+=1
 print('INNER_CROWN samples=',samples,' maximum_excess=',worst)
 assert_gt(samples,100)
 assert_lt(worst,.35,'Concave attachment must stay nearly flush below the turf lip too')
