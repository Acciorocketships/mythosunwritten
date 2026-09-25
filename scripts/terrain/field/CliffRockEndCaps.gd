extends RefCounted
## Rebuild planar end caps after sculpting and ledge warps. Preserve every
## boundary sample so the physical shell and adjacent surface remain closed.
static func rebuild(source:Dictionary)->void:
 # Sculpting can make a formerly valid diagonal cross the new outline.
 # Triangulate the final polygon, then restore collinear boundary samples
 # by splitting their containing triangle. Dropping samples opens seams.
 var faces:PackedVector3Array=source.faces
 var half:float=source.replay_recipe.width*.5
 for end:float in [-half,half]:
  var side:=PackedVector3Array();var rest:=PackedVector3Array()
  for i in range(0,faces.size(),3):
   var a:Vector3=faces[i];var b:Vector3=faces[i+1];var c:Vector3=faces[i+2]
   if a.x==end and b.x==end and c.x==end:side.append_array(PackedVector3Array([a,b,c]))
   else:rest.append_array(PackedVector3Array([a,b,c]))
  var edges:Dictionary={}
  for i in range(0,side.size(),3):
   for j in 3:
    var a:=Vector2(side[i+j].z,side[i+j].y)
    var b:=Vector2(side[i+(j+1)%3].z,side[i+(j+1)%3].y)
    var key:Array=[a,b] if a<b else [b,a]
    edges[key]=edges.get(key,0)+1
  var adjacency:Dictionary={}
  for edge:Array in edges:
   if edges[edge]!=1:continue
   for j in 2:
    if not adjacency.has(edge[j]):adjacency[edge[j]]=[]
    adjacency[edge[j]].append(edge[1-j])
  var boundary:Array=adjacency.keys();boundary.sort()
  for options:Array in adjacency.values():options.sort()
  var outline:=PackedVector2Array();var point:Vector2=boundary[0];var previous:=Vector2(INF,INF)
  for step in adjacency.size():
   outline.append(point)
   var next:Vector2=adjacency[point][0]
   if next==previous:next=adjacency[point][1]
   previous=point;point=next
  # A ledge warp across a narrow (subtle) tread can leave an outline the
  # triangulator rejects; keep that end's existing closed cap instead.
  if point!=outline[0]:rest.append_array(side);faces=rest;continue
  var clean:=PackedVector2Array()
  for i in outline.size():
   var a:Vector2=outline[posmod(i-1,outline.size())];var b:=outline[i];var c:=outline[(i+1)%outline.size()]
   if absf((b-a).cross(c-b))>.0000001:clean.append(b)
  var indices:=Geometry2D.triangulate_polygon(clean)
  if indices.is_empty():rest.append_array(side);faces=rest;continue
  var triangles:Array=[];var complete:=true
  for i in range(0,indices.size(),3):triangles.append([clean[indices[i]],clean[indices[i+1]],clean[indices[i+2]]])
  for i in clean.size():
   var start:=outline.find(clean[i]);var finish:=outline.find(clean[(i+1)%clean.size()])
   var chain:Array[Vector2]=[outline[start]]
   while start!=finish:
    start=(start+1)%outline.size();chain.append(outline[start])
   if chain.size()<=2:continue
   var found:=false
   for t in triangles.size():
    var tri:Array=triangles[t]
    for j in 3:
     var reverse:bool=tri[j]==chain[-1] and tri[(j+1)%3]==chain[0]
     if not reverse and not (tri[j]==chain[0] and tri[(j+1)%3]==chain[-1]):continue
     if reverse:chain.reverse()
     var opposite:Vector2=tri[(j+2)%3]
     triangles.remove_at(t)
     for n in chain.size()-1:triangles.append([chain[n],chain[n+1],opposite])
     found=true;break
    if found:break
   if not found:complete=false;break
  if not complete:rest.append_array(side);faces=rest;continue
  for tri:Array in triangles:
   var a:=Vector3(end,tri[0].y,tri[0].x);var b:=Vector3(end,tri[1].y,tri[1].x);var c:=Vector3(end,tri[2].y,tri[2].x)
   if (c-a).cross(b-a).x*end<0:var swap:=b;b=c;c=swap
   rest.append_array(PackedVector3Array([a,b,c]))
  faces=rest
 source.faces=faces
