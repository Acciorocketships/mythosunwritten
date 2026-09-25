extends RefCounted
## Measure connected physical tread widths independently of depth subdivision.
static func at_vertices(faces:PackedVector3Array)->Dictionary:
 var adjacent:Dictionary={}
 for i in range(0,faces.size(),3):
  for j in 3:
   var a:Vector3=faces[i+j];var b:Vector3=faces[i+(j+1)%3]
   if absf(a.x-b.x)>.0001 or absf(a.z-b.z)<.00001:continue
   if not adjacent.has(a):adjacent[a]=[]
   if not adjacent.has(b):adjacent[b]=[]
   adjacent[a].append(b);adjacent[b].append(a)
 var widths:Dictionary={};var visited:Dictionary={}
 for start:Vector3 in adjacent:
  if visited.has(start):continue
  var queue:Array[Vector3]=[start];var component:Array[Vector3]=[]
  var lo:=INF;var hi:=-INF
  visited[start]=true
  while not queue.is_empty():
   var point:Vector3=queue.pop_back()
   component.append(point);lo=minf(lo,point.z);hi=maxf(hi,point.z)
   for next:Vector3 in adjacent[point]:
    if visited.has(next):continue
    visited[next]=true;queue.append(next)
  for point:Vector3 in component:widths[point]=hi-lo
 return widths

static func triangle(faces:PackedVector3Array,start:int,widths:Dictionary)->float:
 var width:=0.0
 for j in 3:
  var a:Vector3=faces[start+j];var b:Vector3=faces[start+(j+1)%3]
  if absf(a.x-b.x)<.0001:width=maxf(width,minf(widths.get(a,0.0),widths.get(b,0.0)))
 return width
