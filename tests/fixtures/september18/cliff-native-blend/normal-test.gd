extends GutTest
func test_clear_stone_faces_do_not_inherit_backing_tile_normals()->void:
 var source:GDScript=load(OS.get_environment("STORY_COLUMN_GENERATOR"))
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
