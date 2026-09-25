extends GutTest
const CUT=preload("res://tests/harness/september13_roof_prism_cut.gd")
const GEO=preload("res://tools/environment_bake/EnvironmentBakeGeometry.gd")

func plate(x0:float,x1:float,z0:float,z1:float,slope:Vector2=Vector2.ZERO,height:float=2.0) -> ArrayMesh:
 var tool=SurfaceTool.new()
 tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for xz:Vector2 in [Vector2(x0,z0),Vector2(x1,z0),Vector2(x1,z1),Vector2(x0,z0),Vector2(x1,z1),Vector2(x0,z1)]:
  tool.set_normal(Vector3(-slope.x,1,-slope.y).normalized())
  tool.set_uv(xz)
  tool.set_color(Color(.3,.5,.7,1))
  tool.add_vertex(Vector3(xz.x,height+slope.dot(xz),xz.y))
 tool.index()
 return tool.commit()

func projected_area(mesh:ArrayMesh)->float:
 var faces=GEO.triangle_faces(mesh)
 var area=0.0
 for i in range(0,faces.size(),3): area+=absf((faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).y)*.5
 return area

func upper(meshes:Array[ArrayMesh],xz:Vector2)->float:
 var answer=-INF
 for mesh in meshes:
  var faces=GEO.triangle_faces(mesh)
  for i in range(0,faces.size(),3):
   var hit=Geometry3D.ray_intersects_triangle(Vector3(xz.x,20,xz.y),Vector3.DOWN,faces[i],faces[i+1],faces[i+2])
   if hit!=null: answer=maxf(answer,hit.y)
 return answer

func test_coplanar_faces_have_one_owner_without_double_removal()->void:
 var a=plate(-1,1,-1,1)
 var b=plate(0,2,-1,1)
 var kept_a=CUT.subtract(a,b,true)
 var kept_b=CUT.subtract(b,a,false)
 assert_almost_eq(projected_area(kept_a),4.0,.00001,"The host keeps the coincident weather face")
 assert_almost_eq(projected_area(kept_b),2.0,.00001,"The other roof retains only its exposed extension")
 for x in [-.5,.5,1.5]: assert_almost_eq(upper([kept_a,kept_b],Vector2(x,.25)),2.0,.00001)

func test_crossed_slopes_keep_the_exact_upper_surface_and_uvs()->void:
 var a=plate(-2,2,-2,2,Vector2(.4,0))
 var b=plate(-2,2,-2,2,Vector2(0,.4))
 var kept:Array[ArrayMesh]=[CUT.subtract(a,b,true),CUT.subtract(b,a,false)]
 for x in [-1.7,-.8,.05,.9,1.7]:
  for z in [-1.6,-.7,.05,.8,1.6]:
   assert_almost_eq(upper(kept,Vector2(x,z)),2.0+.4*maxf(x,z),.00001,"Native crossing surface at %s"%Vector2(x,z))
 for mesh in kept:
  for surface in mesh.get_surface_count():
   var arrays=mesh.surface_get_arrays(surface)
   for i in arrays[Mesh.ARRAY_VERTEX].size():
    var v:Vector3=arrays[Mesh.ARRAY_VERTEX][i]
    assert_almost_eq(arrays[Mesh.ARRAY_TEX_UV][i],Vector2(v.x,v.z),Vector2(.00001,.00001),"Cut UV remains barycentric on its source triangle")

func test_disjoint_roofs_preserve_the_original_surface()->void:
 var a=plate(-1,1,-1,1)
 var b=plate(3,5,3,5)
 var kept=CUT.subtract(a,b)
 assert_almost_eq(projected_area(kept),4.0,.00001)
 assert_eq(GEO.triangle_faces(kept),GEO.triangle_faces(a))

func test_secondary_uvs_and_tangent_handedness_survive_a_real_cut()->void:
 var source=plate(-1,1,-1,1)
 var arrays=source.surface_get_arrays(0)
 var uv2=PackedVector2Array()
 var tangents=PackedFloat32Array()
 for uv:Vector2 in arrays[Mesh.ARRAY_TEX_UV]:
  uv2.append(uv*2+Vector2(3,4))
  tangents.append_array([1.0,0.0,0.0,-1.0])
 arrays[Mesh.ARRAY_TEX_UV2]=uv2
 arrays[Mesh.ARRAY_TANGENT]=tangents
 source=ArrayMesh.new()
 source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 source.surface_set_name(0,"native_tiles")
 var kept=CUT.subtract(source,plate(0,2,-2,2,Vector2.ZERO,3))
 assert_eq(kept.surface_get_name(0),"native_tiles")
 var output=kept.surface_get_arrays(0)
 assert_true(output[Mesh.ARRAY_TEX_UV2] is PackedVector2Array,"Secondary source coordinates remain available")
 assert_true(output[Mesh.ARRAY_TANGENT] is PackedFloat32Array,"The authored tangent frame remains available")
 if not output[Mesh.ARRAY_TEX_UV2] is PackedVector2Array or not output[Mesh.ARRAY_TANGENT] is PackedFloat32Array: return
 for i in output[Mesh.ARRAY_VERTEX].size():
  var point:Vector3=output[Mesh.ARRAY_VERTEX][i]
  assert_almost_eq(output[Mesh.ARRAY_TEX_UV2][i],Vector2(point.x,point.z)*2+Vector2(3,4),Vector2(.00001,.00001))
  assert_eq(output[Mesh.ARRAY_TANGENT][i*4+3],-1.0,"Mirror handedness is not reset by cutting")

func test_complete_burial_emits_no_surface_and_unindexed_stock_is_supported()->void:
 var source=plate(-1,1,-1,1)
 var buried=CUT.subtract(source,plate(-2,2,-2,2,Vector2.ZERO,3))
 assert_not_null(buried)
 assert_eq(buried.get_surface_count(),0,"Complete buried stock is removed, not replaced with a cover")
 var arrays=source.surface_get_arrays(0)
 var vertices=PackedVector3Array()
 for index in arrays[Mesh.ARRAY_INDEX]: vertices.append(arrays[Mesh.ARRAY_VERTEX][index])
 var unindexed_arrays=[]
 unindexed_arrays.resize(Mesh.ARRAY_MAX)
 unindexed_arrays[Mesh.ARRAY_VERTEX]=vertices
 var unindexed=ArrayMesh.new()
 unindexed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,unindexed_arrays)
 var kept=CUT.subtract(unindexed,plate(0,2,-2,2,Vector2.ZERO,3))
 assert_not_null(kept)
 assert_almost_eq(projected_area(kept),2.0,.00001)

func test_native_section_domain_is_bounded_before_spatial_bucketing()->void:
 assert_null(CUT.subtract(plate(33,34,0,1),plate(0,1,0,1)),"Subject outside the finite bake domain is rejected")
 assert_null(CUT.subtract(plate(0,1,0,1),plate(33,34,0,1)),"Cutter outside the finite bake domain is rejected")
