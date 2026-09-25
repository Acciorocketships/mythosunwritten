extends GutTest
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const BEFORE=preload("res://tests/fixtures/september17/cliff-shading/before.gd")

func _fold(angle:float)->Array:
 var c:=cos(angle);var s:=sin(angle)
 # A vertical fold, outside the native-wall attachment region.
 var faces:=PackedVector3Array([
  Vector3(-1,0,5),Vector3(0,0,5),Vector3(0,1,5),
  Vector3(0,0,5),Vector3(c,0,5-s),Vector3(0,1,5)])
 return CRAGS.mesh({"faces":faces,"green":PackedVector3Array(),"transform":Transform3D.IDENTITY}).surface_get_arrays(0)

func test_carved_fracture_retains_a_clear_normal_break()->void:
 CRAGS.prepare()
 var arrays:=_fold(PI*.5)
 var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 assert_lt(normals[1].angle_to(Vector3.FORWARD),deg_to_rad(12),"A sharp fracture must not shade like a rounded bulge")
 assert_lt(normals[3].angle_to(Vector3.LEFT),deg_to_rad(12),"Both sides must retain their own rock face")

func test_gently_rounded_faces_keep_smooth_normals()->void:
 CRAGS.prepare()
 var arrays:=_fold(deg_to_rad(20))
 var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 assert_lt(normals[1].angle_to(normals[3]),.001,"Preserve smoothing across broad rounded faces")

func test_shading_preserves_actual_geometry_turf_and_attachment_weights()->void:
 CRAGS.prepare();BEFORE.prepare()
 var form:Dictionary=CRAGS.make(Transform3D.IDENTITY,24,16,2697992464)[0]
 var before:ArrayMesh=BEFORE.mesh(form);var after:ArrayMesh=CRAGS.mesh(form)
 assert_eq(after.get_surface_count(),before.get_surface_count())
 for surface in after.get_surface_count():
  var a:=after.surface_get_arrays(surface);var b:=before.surface_get_arrays(surface)
  for slot:int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_COLOR]:
   assert_eq(a[slot],b[slot],"Only rock shading normals may change")
  for normal:Vector3 in a[Mesh.ARRAY_NORMAL]:
   if not normal.is_finite() or normal.length()<.99:
    fail_test("All generated normals must remain finite and normalized")
    return
 pass_test("Actual production normals are finite and normalized")
