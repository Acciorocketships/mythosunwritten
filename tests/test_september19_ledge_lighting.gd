extends GutTest
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const SOURCE="res://docs/qa/2026-09-19-manual/94-stepped-inner-join/candidate/after-forms.bin"

func test_photographed_curved_treads_do_not_expose_sampling_strips()->void:
 CRAGS.prepare()
 var tested:=0;var broken:=0;var formations:=0
 for rock:Dictionary in FileAccess.open(SOURCE,FileAccess.READ).get_var():
  if rock.replay_recipe.kind!="wall" or not rock.replay_recipe.has("inner_connections"):continue
  formations+=1
  var mesh:=CRAGS.mesh(rock)
  var arrays:=mesh.surface_get_arrays(1)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  assert_eq(vertices,rock.green,"Shading preserves every actual turf triangle")
  assert_eq(mesh.surface_get_material(1),CliffDressing.shared_material())
  var edges:Dictionary={}
  for i in range(0,vertices.size(),3):
   var face:Vector3=(vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
   for j in 3:
    var a:Vector3=vertices[i+j];var b:Vector3=vertices[i+(j+1)%3]
    var key:Array=[a,b] if a<b else [b,a]
    var ns:Array=[normals[i+j],normals[i+(j+1)%3]] if a<b else [normals[i+(j+1)%3],normals[i+j]]
    if not edges.has(key):edges[key]=[]
    edges[key].append([face,ns])
  for pair:Array in edges.values():
   if pair.size()!=2 or pair[0][0].dot(pair[1][0])<cos(deg_to_rad(30)):continue
   tested+=1
   if pair[0][1][0].angle_to(pair[1][1][0])>.015 or pair[0][1][1].angle_to(pair[1][1][1])>.015:broken+=1
 print("TREAD_LIGHTING formations=",formations," gentle_edges=",tested," broken=",broken)
 assert_eq(formations,4)
 assert_gt(tested,500)
 assert_eq(broken,0,"Connected curved grass must not show per-triangle light bands")

func test_sharp_fold_remains_separate_from_smooth_turf_fans()->void:
 var points:=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.BACK,Vector3.ZERO,Vector3.UP,Vector3.RIGHT])
 var rock:Dictionary={"faces":points+PackedVector3Array([Vector3(0,0,-1.2),Vector3(0,1,-1.2),Vector3(1,0,-1.2)]),"green":points,"transform":Transform3D.IDENTITY}
 var normals:PackedVector3Array=CRAGS.mesh(rock).surface_get_arrays(1)[Mesh.ARRAY_NORMAL]
 assert_gt(normals[0].angle_to(normals[3]),1.5,"A genuinely sharp fold retains its geometric edge")
