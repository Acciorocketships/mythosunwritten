extends GutTest
const BEFORE=preload("res://tests/fixtures/september18/cliff-solid-shoulders/before.gd")
func test_added_rock_solids_have_exposed_volume_and_closed_physical_faces()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var pose:=Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5))
 var original:Dictionary=BEFORE.make(pose,48,16,2697992464)[0]
 var current:Dictionary=source.make(pose,48,16,2697992464)[0]
 assert_gt(current.faces.size(),original.faces.size()+500,"Whole rock solids must add physical triangles, not shader detail")
 assert_eq(current.green,original.green,"Existing curved ledges keep their native surface triangles")
 var columns:Dictionary={}
 for p:Vector3 in original.faces:
  if p.z<0:continue
  if not columns.has(p.x):columns[p.x]=[]
  if not p in columns[p.x]:columns[p.x].append(p)
 for x:float in columns:columns[x].sort_custom(func(a:Vector3,b:Vector3):return a.y>b.y)
 var exposed:=0;var max_depth:=0.0;var new_faces:=PackedVector3Array()
 for i in range(original.faces.size(),current.faces.size()):
  var p:Vector3=current.faces[i];new_faces.append(p)
  if p.y<.1 or p.y>14:continue
  var x:float=snappedf(p.x,.25)
  if not columns.has(x):continue
  var points:Array=columns[x];var depth:=-INF
  for j in range(points.size()-1):
   var a:Vector3=points[j];var b:Vector3=points[j+1]
   if p.y>a.y or p.y<b.y:continue
   var t:=clampf((a.y-p.y)/maxf(.000001,a.y-b.y),0,1)
   depth=maxf(depth,lerpf(a.z,b.z,t))
  if is_finite(depth):
   max_depth=maxf(max_depth,p.z-depth)
   if p.z-depth>.2:exposed+=1
 assert_gt(exposed,100,"The added solid needs actual exposed depth beyond the existing face")
 var edges:Dictionary={};var degenerate:=0
 for i in range(0,new_faces.size(),3):
  var triangle:Array=[]
  for j in 3:triangle.append(new_faces[i+j].snapped(Vector3.ONE*.0001))
  if (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).length_squared()<1e-12:degenerate+=1
  for j in 3:
   var a:Vector3=triangle[j];var b:Vector3=triangle[(j+1)%3]
   var key:Array=[a,b] if a<b else [b,a]
   edges[key]=edges.get(key,0)+1
 var open:=0
 for count:int in edges.values():
  if count!=2:open+=1
 print("NATIVE_VOLUMES additional_vertices=",new_faces.size()," exposed=",exposed," max_depth=",max_depth," nonmanifold_edges=",open," degenerate=",degenerate)
 assert_eq(open,0,"Each added rock retains a closed collision shell")
 assert_eq(degenerate,0,"No collapsed triangles enter collision")
 assert_lte(current.bounds.end.y,16.001,"Added rocks stay below the native crown")
