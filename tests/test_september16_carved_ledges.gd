extends GutTest
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const RELIEF=preload("res://scripts/terrain/field/CliffRockRelief.gd")

func test_carved_turf_is_finite_staggered_and_stays_off_the_gray_wall_join()->void:
 var forms:Array=[]
 for x:float in [-24,0,24]:forms.append_array(CRAGS.make(Transform3D(Basis.IDENTITY,Vector3(x,0,0)),24,16,2697992464))
 var heights:Dictionary={};var extents:Array[float]=[];var seen:Dictionary={}
 var bad_turf:=0;var area:=0.0
 for rock:Dictionary in forms:
  # Grass support borders intentionally split non-coplanar surfaces. Count
  # geometric shelf connectivity here, so a curving shelf remains one ledge.
  var parents:Array[int]=[];var edges:Dictionary={};var patches:Dictionary={}
  for i in rock.green.size()/3:parents.append(i)
  for i in parents.size():
   for j in 3:
    var a:Vector3=rock.green[i*3+j];var b:Vector3=rock.green[i*3+(j+1)%3]
    var key:Array=[a,b] if a<b else [b,a]
    if edges.has(key):parents[_root(parents,i)]=_root(parents,edges[key])
    else:edges[key]=i
  for i in range(0,rock.green.size(),3):
   var a:Vector3=rock.green[i];var b:Vector3=rock.green[i+1];var c:Vector3=rock.green[i+2]
   var normal:Vector3=(c-a).cross(b-a)
   area+=normal.length()*.5
   if normal.normalized().y<.8 or minf(a.z,minf(b.z,c.z))<=.4:bad_turf+=1
   var root:=_root(parents,i/3)
   if not patches.has(root):patches[root]=[INF,-INF,0.0,0]
   var patch:Array=patches[root]
   for point:Vector3 in [a,b,c]:
    patch[0]=minf(patch[0],point.x);patch[1]=maxf(patch[1],point.x)
    patch[2]+=point.y;patch[3]+=1
  for patch:Array in patches.values():
   if patch[1]-patch[0]<1:continue
   extents.append(patch[1]-patch[0]);heights[roundi(patch[2]/patch[3])]=true
 print("CARVED_LEDGES count=",extents.size()," heights=",heights.keys()," extents=",extents," turf_area=",area)
 assert_gt(extents.size(),8,"Several separate ledges must survive, rather than two full-wall ribbons")
 # Whole pointed caps are now painted, including their former narrow ends.
 # Test the stated full-owner prohibition against the actual 24 m owner; the
 # old 14 m limit measured only the width-trimmed middle of each turf patch.
 assert_lt(extents.max(),24.0,"No ledge spans a full canonical wall owner")
 assert_gt(extents.max()-extents.min(),2.0,"Ledges have materially different lengths")
 assert_gt(heights.size(),6,"Ledge elevations cannot collapse back to two courses")
 assert_gt(area,30.0,"Visible exposed turf surfaces remain after finite ledge clipping")
 assert_eq(bad_turf,0,"Only flatter exposed shelves carry turf; gray rock owns the wall attachment")

func _root(parents:Array[int],i:int)->int:
 while parents[i]!=i:i=parents[i]
 return i

func test_generated_caps_use_native_turf_and_the_collision_vertices()->void:
 var rock:Dictionary=CRAGS.make(Transform3D.IDENTITY,24,16,2697992464)[0]
 var mesh:=CRAGS.mesh(rock)
 assert_eq(mesh.get_surface_count(),2)
 assert_eq(mesh.surface_get_material(1),CliffDressing.shared_material())
 var original:Dictionary={}
 for p:Vector3 in rock.faces:original[p]=true
 var alien:=0
 for p:Vector3 in mesh.get_faces():
  if not original.has(p):alien+=1
 assert_eq(alien,0,"Rendered ledges use the same physical shell vertices")
 for uv:Vector2 in mesh.surface_get_arrays(1)[Mesh.ARRAY_TEX_UV]:assert_eq(uv,CliffDressing.ground_uv())
