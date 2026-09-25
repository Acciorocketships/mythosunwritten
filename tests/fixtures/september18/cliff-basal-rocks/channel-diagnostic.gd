extends GutTest

func test_reported_shelf_has_no_cluster_of_wide_treads_separated_by_tiny_risers()->void:
 var path:=OS.get_environment("STORY_CHANNEL_GENERATOR")
 var generator=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var a:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()[11]
 var form:Dictionary=generator.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
 var columns:Dictionary={};var adjacent:Dictionary={}
 # The report projects to this lower ledge in saved P05 camera 0. Join
 # depth subdivisions before measuring a physical tread's width/elevation.
 for i in range(0,form.faces.size(),3):
  var normal:Vector3=(form.faces[i+2]-form.faces[i]).cross(form.faces[i+1]-form.faces[i]).normalized()
  if normal.y<.8:continue
  for j in 3:
   var p:Vector3=form.faces[i+j];var q:Vector3=form.faces[i+(j+1)%3]
   if absf(p.x-q.x)>.0001 or p.x<0 or p.x>6:continue
   if minf(p.y,q.y)<1 or maxf(p.y,q.y)>3.5 or absf(p.z-q.z)<.0001:continue
   if not adjacent.has(p):adjacent[p]=[]
   if not adjacent.has(q):adjacent[q]=[]
   adjacent[p].append(q);adjacent[q].append(p)
 var visited:Dictionary={}
 for start:Vector3 in adjacent:
  if visited.has(start):continue
  var queue:Array[Vector3]=[start];var top:=-INF;var near:=INF;var far:=-INF
  visited[start]=true
  while not queue.is_empty():
   var p:Vector3=queue.pop_back()
   top=maxf(top,p.y);near=minf(near,p.z);far=maxf(far,p.z)
   for q:Vector3 in adjacent[p]:
    if not visited.has(q):visited[q]=true;queue.append(q)
  if far-near<.55:continue
  if not columns.has(start.x):columns[start.x]={}
  columns[start.x][snappedf(top,.001)]=true
 var narrow:=0;var measured:=0
 for levels:Dictionary in columns.values():
  var sorted:Array=levels.keys();sorted.sort()
  for j in range(1,sorted.size()):
   var gap:float=sorted[j]-sorted[j-1]
   if gap>.025 and gap<.4:
    narrow+=1;print("NARROW_DIAGNOSTIC ",sorted," gap=",gap)
   measured+=1
 print("LEDGE_CHANNELS narrow_risers=",narrow," adjacent_treads=",measured," columns=",columns.size())
 assert_gt(columns.size(),5,"Measure the actual broad shelf in the reported image")
 assert_eq(narrow,0,"Nearby broad treads should merge instead of carving a sharp narrow channel across a usable ledge")

func test_usable_turf_continues_into_shallow_pointed_tips()->void:
 var path:=OS.get_environment("STORY_CHANNEL_GENERATOR")
 var generator=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var a:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()[11]
 var form:Dictionary=generator.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
 var turf:Dictionary={};var edges:Dictionary={}
 for i in range(0,form.green.size(),3):
  var tri:Array=[form.green[i],form.green[i+1],form.green[i+2]]
  turf[tri]=true
  var normal:Vector3=(tri[2]-tri[0]).cross(tri[1]-tri[0]).normalized()
  for j in 3:
   var p:Vector3=tri[j];var q:Vector3=tri[(j+1)%3]
   if absf(p.x-q.x)<.0001:edges[[p,q] if p<q else [q,p]]=normal
 var missing:=0
 for i in range(0,form.faces.size(),3):
  var tri:Array=[form.faces[i],form.faces[i+1],form.faces[i+2]]
  if turf.has(tri):continue
  var cross:Vector3=(tri[2]-tri[0]).cross(tri[1]-tri[0])
  if cross.length()<.006 or cross.normalized().y<.8:continue
  if minf(tri[0].z,minf(tri[1].z,tri[2].z))<=.4:continue
  for j in 3:
   var p:Vector3=tri[j];var q:Vector3=tri[(j+1)%3]
   var key:Array=[p,q] if p<q else [q,p]
   if edges.has(key) and edges[key].dot(cross.normalized())>.97:missing+=1;break
 print("LEDGE_TURF abrupt_shallow_continuations=",missing)
 assert_eq(missing,0,"Turf must follow a usable shelf into its pointed taper instead of stopping at a rectangular width cutoff")

func test_photo_shells_remain_closed_when_shelf_correspondence_changes()->void:
 var path:=OS.get_environment("STORY_CHANNEL_GENERATOR")
 var generator=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var bad_edges:=0;var degenerate:=0;var count:=0
 for a:Array in FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var():
  var form:Dictionary=generator.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
  var edges:Dictionary={}
  for i in range(0,form.faces.size(),3):
   if (form.faces[i+1]-form.faces[i]).cross(form.faces[i+2]-form.faces[i]).length_squared()<1e-14:degenerate+=1
   for j in 3:
    var p:Vector3=form.faces[i+j];var q:Vector3=form.faces[i+(j+1)%3]
    var key:Array=[p,q] if p<q else [q,p]
    edges[key]=edges.get(key,0)+1
  for uses:int in edges.values():
   if uses!=2:bad_edges+=1
  count+=1
 print("PHOTO_LEDGE_SHELLS forms=",count," bad_edges=",bad_edges," degenerate=",degenerate)
 assert_eq(bad_edges,0,"Joining different active shelf slots cannot open the actual collision solid")
 assert_eq(degenerate,0,"Merged shelves cannot leave collapsed triangles")

func test_merged_cap_has_no_stone_channel_across_its_interior()->void:
 # Follow the actual tread between the same three reported wall columns.
 # A new rock silhouette may relocate it in depth; fixed old-depth rays then
 # test empty air. Interior coverage still reproduces the historical defect.
 var path:=OS.get_environment("STORY_CHANNEL_GENERATOR")
 var generator:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var a:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()[11]
 var form:Dictionary=generator.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
 var samples:=0;var covered:=0
 for x:float in [5.05,5.125,5.2]:
  var near:=INF;var far:=-INF
  var faces:PackedVector3Array=form.faces
  for i in range(0,faces.size(),3):
   var normal:Vector3=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized()
   if normal.y<.8:continue
   for j in 3:
    var p:=faces[i+j];var q:=faces[i+(j+1)%3]
    if absf(p.x-q.x)<.00001 or x<minf(p.x,q.x) or x>maxf(p.x,q.x):continue
    var hit:=p.lerp(q,(x-p.x)/(q.x-p.x))
    if hit.y<=2.0 or hit.y>3.5 or hit.z<.4:continue
    near=minf(near,hit.z);far=maxf(far,hit.z)
  print("CAP_INTERVAL x=",x," near=",near," far=",far)
  if far-near<.55:continue
  for step in 19:
   var z:=lerpf(near,far,float(step+1)/20)
   var origin:=Vector3(x,3.5,z);var shell:=-INF;var turf:=-INF
   for type:String in ["faces","green"]:
    var triangles:PackedVector3Array=form[type]
    for i in range(0,triangles.size(),3):
     var hit=Geometry3D.ray_intersects_triangle(origin,Vector3.DOWN,triangles[i],triangles[i+1],triangles[i+2])
     if hit==null:continue
     if type=="faces":shell=maxf(shell,hit.y)
     else:turf=maxf(turf,hit.y)
   if shell>2.0:samples+=1
   if shell>2.0 and absf(turf-shell)<.0001:covered+=1
 print("CAP_INTERVAL_RESULT samples=",samples," covered=",covered)
 assert_eq(samples,57,"The complete reported shelf remains physically present")
 assert_eq(covered,samples,"The full tread must remain turf without interior stone channels")
