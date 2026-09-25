extends GutTest
func test_tall_wall_has_long_and_short_connected_upper_ledges()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load(path)
 var form:Dictionary=source.make(Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5)),48,64,2697992464)[0]
 var green:PackedVector3Array=form.green
 var parent:Array[int]=[];var edges:Dictionary={}
 for i in green.size()/3:parent.append(i)
 for i in parent.size():
  for j in 3:
   var a:Vector3=green[i*3+j];var b:Vector3=green[i*3+(j+1)%3]
   var key:Array=[a,b] if a<b else [b,a]
   if edges.has(key):parent[source._turf_root(parent,i)]=source._turf_root(parent,edges[key])
   else:edges[key]=i
 var bounds:Dictionary={}
 for i in parent.size():
  var root:int=source._turf_root(parent,i)
  for j in 3:
   var p:Vector3=green[i*3+j]
   bounds[root]=(bounds[root] as AABB).expand(p) if bounds.has(root) else AABB(p,Vector3.ZERO)
 var longest:=0.0;var shortest:=INF;var counted:=0
 for box:AABB in bounds.values():
  if box.position.y<20.0 or box.size.x<2.0:continue
  longest=maxf(longest,box.size.x);shortest=minf(shortest,box.size.x);counted+=1
 print("UPPER_LEDGE_SPANS count=",counted," longest=",longest," shortest=",shortest)
 assert_gt(counted,3)
 assert_gte(longest,12.0,"The tall study should include a genuinely long upper shelf, with shorter ledges elsewhere")
 assert_gt(longest/maxf(shortest,.01),1.8,"Connected ledges need different lengths")
