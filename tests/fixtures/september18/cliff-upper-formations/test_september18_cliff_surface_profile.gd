extends GutTest

func test_clear_stone_faces_do_not_inherit_backing_tile_normals()->void:
 var source:GDScript=load("res://tests/fixtures/september18/cliff-upper-formations/soft-joins.gd")
 source.prepare()
 var worst:=0.0;var checked:=0
 for offset:float in [0.0,.5,1.0,1.5,2.0]:
  var a:=Vector3(offset,.8,1.25);var b:=a+Vector3(.4,0,0)
  var c:=a+Vector3(.4,1.5,0);var d:=a+Vector3(0,1.5,0)
  var faces:=PackedVector3Array([a,c,b,a,d,c])
  var mesh:ArrayMesh=source.mesh({"faces":faces,"green":PackedVector3Array(),"transform":Transform3D.IDENTITY})
  var normals:PackedVector3Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
  for normal:Vector3 in normals:
   worst=maxf(worst,rad_to_deg(normal.angle_to(Vector3.BACK)));checked+=1
 print("CLEAR_FACE_NORMAL samples=",checked," error_degrees=",worst)
 assert_eq(checked,30)
 assert_lt(worst,5.0,"A face clear of the native crests must shade from its own geometry")


func test_upper_silhouette_does_not_spend_the_root_projection_near_the_crown()->void:
 var source:GDScript=load("res://tests/fixtures/september18/cliff-upper-formations/soft-joins.gd")
 var worst:=0.0;var sampled:=0
 for height:float in [8.0,16.0,32.0,64.0]:
  var pose:=Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5))
  var form:Dictionary=source.make(pose,48,height,2697992464)[0]
  var feet:Dictionary={}
  for p:Vector3 in form.faces:
   if p.y<=.01 and p.z>0:feet[p.x]=maxf(feet.get(p.x,0.0),p.z)
  for p:Vector3 in form.faces:
   var drop:=height-p.y
   if drop<=1.0 or drop>height*.45 or p.z<0 or not feet.has(p.x):continue
   # Measure the outer silhouette against the measured 1 m native crest,
   # not its inset mortar valleys. Allow 0.4 m for the larger shallow stone
   # sections, then require the remaining projection to grow with descent.
   # This rejects the old abrupt collar without stamping native tile valleys
   # back into every section of the independent stone surface.
   var limit:float=1.4+maxf(0.0,feet[p.x]-1.0)*(drop-1.0)/(height-1.0)
   worst=maxf(worst,p.z-limit);sampled+=1
 print("UPPER_SILHOUETTE samples=",sampled," envelope_excess=",worst)
 assert_gt(sampled,1000)
 assert_lt(worst,.08,"The large projection must develop toward the foot, not just below the turf lip")

func test_added_tall_skin_covers_the_native_relief_between_joins()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://tests/fixtures/september18/cliff-upper-formations/soft-joins.gd" if path.is_empty() else path)
 var height:=64.0
 var form:Dictionary=source.make(Transform3D.IDENTITY,48,height,2697992464)[0]
 var checked:=0;var covered:=0;var points:Dictionary={}
 var native_peak:=0.0
 for value:float in source._wall_depth:native_peak=maxf(native_peak,value)
 for p:Vector3 in form.faces:
  if p.y<2 or p.y>height-3 or p.z<0 or absf(p.x)>20:continue
  points[p]=true
 for p:Vector3 in points:
  checked+=1
  if p.z>native_peak+.02:covered+=1
 var fraction:=float(covered)/maxi(1,checked)
 print("INDEPENDENT_SKIN samples=",checked," coverage=",fraction," native_peak=",native_peak)
 assert_gt(checked,1000)
 assert_gt(fraction,.98,"Away from real attachment edges, tile crests must not break through the added continuous stone")
