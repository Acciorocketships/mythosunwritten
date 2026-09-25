extends RefCounted
## Detached, continuous geological profiles. Adjacent canonical panels sample
## the same world-coordinate ridges; their fronts never return to the wall at
## arbitrary module boundaries. Only real exposed run ends taper into the wall.
static func _noise(x:float,salt:int)->float:
 var i:=floori(x);var t:=smoothstep(0.0,1.0,x-i)
 return lerpf(Helper.position_hash01(Vector3(i,salt,0),salt),Helper.position_hash01(Vector3(i+1,salt,0),salt),t)

static func _noise2(x:float,y:float,salt:int)->float:
 var ix:=floori(x);var iy:=floori(y)
 var tx:=smoothstep(0.0,1.0,x-ix);var ty:=smoothstep(0.0,1.0,y-iy)
 return lerpf(lerpf(Helper.position_hash01(Vector3(ix,iy,0),salt),Helper.position_hash01(Vector3(ix+1,iy,0),salt),tx),
  lerpf(Helper.position_hash01(Vector3(ix,iy+1,0),salt),Helper.position_hash01(Vector3(ix+1,iy+1,0),salt),tx),ty)

static func make(pose:Transform3D,width:float,height:float,seed_value:int,left_end:bool,right_end:bool,region:HeightfieldRegion=null)->Dictionary:
 var steps:=maxi(2,roundi(width/.6));var columns:Array=[]
 var faces:=PackedVector3Array();var green:=PackedVector3Array()
 var tangent:=pose.basis.x;var coordinate:=pose.origin.dot(tangent)
 var salt:=seed_value+roundi(pose.origin.dot(pose.basis.z))*13+roundi(pose.origin.y)*71
 var rows:=maxi(16,ceili(height/.6))
 for i in steps+1:
  var x:float=-width*.5+width*float(i)/steps;var u:=coordinate+x
  var fade:=1.0
  if left_end:fade*=smoothstep(0.0,3.0,x+width*.5)
  if right_end:fade*=smoothstep(0.0,3.0,width*.5-x)
  var boulders:Array=[]
  for cell in range(floori(u/11.0)-3,floori(u/11.0)+4):
   var key:=Vector3(cell,salt,0)
   var number:=2+int(Helper.position_hash01(key,salt+151)*3)
   for n in number:
    var q:=key+Vector3(0,0,n*19)
    var centre:=cell*11.0+11.0*Helper.position_hash01(q,salt+157)
    var radius_x:=lerpf(6.0,14.0,Helper.position_hash01(q,salt+163)) if n==0 else lerpf(3.0,9.0,Helper.position_hash01(q,salt+163))
    var radius_y:=height*lerpf(.32,.48,Helper.position_hash01(q,salt+167)) if n==0 else height*lerpf(.15,.31,Helper.position_hash01(q,salt+167))
    var centre_y:=radius_y*.55 if n==0 else height*lerpf(.24,.79,Helper.position_hash01(q,salt+173))
    radius_y=minf(radius_y,height-.18-centre_y)
    var depth:=minf(19.0,radius_y*lerpf(1.35,2.3,Helper.position_hash01(q,salt+179))) if n==0 else radius_y*lerpf(.75,1.5,Helper.position_hash01(q,salt+179))
    var tilt:=lerpf(-.30,.30,Helper.position_hash01(q,salt+181))
    var along:=(u-centre)/radius_x
    if absf(along)>=1.0:continue
    boulders.append({"x":along,"y":centre_y+along*radius_y*tilt,"radius":radius_y,"depth":depth,"power":lerpf(2.8,4.0,Helper.position_hash01(q,salt+193))})
  var floor_y:=-.2
  if region!=null:
   # Complete projected boulder footprint remains seated in real terrain.
   var furthest:=0.0
   for b:Dictionary in boulders:furthest=maxf(furthest,b.depth)
   var foot:Vector3=pose*Vector3(x,0,furthest)
   floor_y=minf(floor_y,TerrainSurfaceField.surface_y(region,foot.x,foot.z)-pose.origin.y-.2)
  var elevations:Array[float]=[height,floor_y]
  for row in range(1,rows):elevations.append(lerpf(height,floor_y,float(row)/rows))
  # Resolve the rounded crown instead of stretching a single triangle several
  # metres from the wall to the first coarse height sample.
  for b:Dictionary in boulders:
   var crown:float=b.y+b.radius*pow(maxf(0.0,1.0-pow(absf(b.x),b.power)),1.0/b.power)
   for offset:float in [0.0,.012,.035,.075,.14,.24,.4,.65]:
    var y:float=crown-offset
    if y>floor_y and y<height:elevations.append(y)
  elevations.sort();elevations.reverse()
  var clean:Array[float]=[]
  for y:float in elevations:
   if clean.is_empty() or clean[-1]-y>.002:clean.append(y)
  var points:=PackedVector3Array()
  for row in clean.size():
   var y:float=clean[row];var t:float=(height-y)/(height-floor_y)
   var z:=-.35
   for b:Dictionary in boulders:
    var vertical:float=(y-b.y)/b.radius
    var shape:float=1.0-pow(absf(b.x),b.power)-pow(absf(vertical),b.power)
    if shape<=0.0:continue
    var front:float=b.depth*pow(shape,1.0/b.power)
    var crown:float=b.y+b.radius*pow(maxf(0.0,1.0-pow(absf(b.x),b.power)),1.0/b.power)
    # A finite rounded shoulder rolls back into the wall. An ellipsoid's
    # infinite tangent at its rear crown creates long needle-like triangles.
    var shoulder:float=maxf(0.0,crown-y)*3.5
    var rounding:=maxf(.35-absf(front-shoulder),0.0)/.35
    front=minf(front,shoulder)-rounding*rounding*.0875
    # Smooth union means overlapping boulders genuinely share the exposed
    # face rather than ending as individual pods placed next to a wall.
    var blend:=maxf(1.2-absf(z-front),0.0)/1.2
    z=maxf(z,front)+blend*blend*.30
   if z>0 and row>0 and row<clean.size()-1:
    var world_y:=y+pose.origin.y
    var weather:=(_noise2(u/3.7,world_y/2.9,salt+197)-.5)*1.35
    weather+=(_noise2(u/1.4,world_y/1.1,salt+199)-.5)*.38
    var joint:=absf(_noise2(u/5.1,world_y/7.7,salt+211)-.47)
    weather-=.48*(1.0-smoothstep(.015,.065,joint))
    z+=weather*smoothstep(0.0,1.0,z)
   # A crown collar stays buried and grey. Roots taper below grade only.
   z=lerpf(-.35,z,smoothstep(0.0,.45,height-y))
   z=lerpf(-.35,z,fade)
   points.append(Vector3(x,y,z))
  columns.append(points)
 for i in steps:
  _join_columns(faces,green,columns[i],columns[i+1],false)
  for top in [true,false]:
   var a:Vector3=columns[i][0 if top else -1];var b:Vector3=columns[i+1][0 if top else -1]
   var c:=Vector3(a.x,a.y,-1.2);var d:=Vector3(b.x,b.y,-1.2)
   if top:_triangle(faces,a,c,b);_triangle(faces,b,c,d)
   else:_triangle(faces,a,b,c);_triangle(faces,b,d,c)
 for i:int in [0,steps]:
  for row in columns[i].size()-1:
   var a:Vector3=columns[i][row];var b:Vector3=columns[i][row+1]
   var c:=Vector3(a.x,a.y,-1.2);var d:=Vector3(b.x,b.y,-1.2)
   if i==0:_triangle(faces,a,b,c);_triangle(faces,b,d,c)
   else:_triangle(faces,a,c,b);_triangle(faces,b,c,d)
 # A single buried backing fan closes the exact perimeter. Dense copied
 # rear relief has no visual or physical value and doubles worker geometry.
 var rim:=PackedVector3Array()
 for column:PackedVector3Array in columns:rim.append(Vector3(column[0].x,column[0].y,-1.2))
 for row in range(1,columns[-1].size()):
  var v:Vector3=columns[-1][row];rim.append(Vector3(v.x,v.y,-1.2))
 for i in range(columns.size()-2,-1,-1):
  var v:Vector3=columns[i][-1];rim.append(Vector3(v.x,v.y,-1.2))
 for row in range(columns[0].size()-2,0,-1):
  var v:Vector3=columns[0][row];rim.append(Vector3(v.x,v.y,-1.2))
 var centre:=Vector3(0,height*.5,-1.2)
 for i in rim.size():_triangle(faces,centre,rim[(i+1)%rim.size()],rim[i])
 var bounds:=AABB(faces[0],Vector3.ZERO)
 for p:Vector3 in faces:bounds=bounds.expand(p)
 return {"faces":faces,"green":green,"bounds":pose*bounds,"transform":pose,"anchor":pose.origin,
  "id":"relief/%s/%s"%[pose.origin,pose.basis.z],"asset":&"cliff.relief","kind":"rock","top":(pose*bounds).end.y,"base":(pose*bounds).position.y}

static func _join_columns(faces:PackedVector3Array,green:PackedVector3Array,a:PackedVector3Array,b:PackedVector3Array,back:bool)->void:
 var ia:=0;var ib:=0
 while ia<a.size()-1 or ib<b.size()-1:
  var tri:Array
  if ib==b.size()-1 or (ia<a.size()-1 and a[ia+1].y>=b[ib+1].y):
   tri=[a[ia],b[ib],a[ia+1]];ia+=1
  else:tri=[b[ib],b[ib+1],a[ia]];ib+=1
  if back:tri.reverse()
  _triangle(faces,tri[0],tri[1],tri[2])
  var normal:Vector3=(tri[2]-tri[0]).cross(tri[1]-tri[0]).normalized()
  if not back and normal.y>.82 and minf(tri[0].z,minf(tri[1].z,tri[2].z))>.9:
   _triangle(green,tri[0],tri[1],tri[2])

static func _triangle(out:PackedVector3Array,a:Vector3,b:Vector3,c:Vector3)->void:
 out.append(a);out.append(b);out.append(c)

static func mesh(rock:Dictionary)->ArrayMesh:
 assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_smooth_group(0)
 var faces:PackedVector3Array=rock.faces;var authored:=PackedVector3Array()
 for i in range(0,faces.size(),3):
  var normal:Vector3=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized()
  st.set_smooth_group(0 if normal.z>.00001 else 1)
  for j in 3:
   authored.append(normal);st.set_normal(normal);st.add_vertex(faces[i+j])
 st.generate_normals()
 var arrays:=st.commit_to_arrays();var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 for i in normals.size():normals[i]=normals[i].normalized()
 arrays[Mesh.ARRAY_NORMAL]=normals
 var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var material:=ShaderMaterial.new();material.shader=load("res://terrain/materials/cliff_relief.gdshader")
 material.set_shader_parameter("ground_palette_texture",CliffDressing.ground_texture())
 material.set_shader_parameter("grass_uv",CliffDressing.ground_uv())
 result.surface_set_material(0,material)
 return result

static func panels(walls:Array)->Array[Dictionary]:
 var planes:Dictionary={}
 for pose:Transform3D in walls:
  var key:=[pose.basis, snappedf(pose.origin.dot(pose.basis.z),.001),snappedf(fposmod(pose.origin.y,4),.001)]
  if not planes.has(key):planes[key]={"basis":pose.basis,"depth":key[1],"phase":key[2],"columns":{}}
  var x:=roundi(pose.origin.dot(pose.basis.x)/3.0-.5)
  if not planes[key].columns.has(x):planes[key].columns[x]=[]
  planes[key].columns[x].append(pose.origin.y)
 var result:Array[Dictionary]=[]
 for key:Array in planes:
  var plane:Dictionary=planes[key];var runs:Dictionary={}
  for x:int in plane.columns:
   var ys:Array=plane.columns[x];ys.sort()
   var start:float=ys[0];var end:float=start+4
   for i in range(1,ys.size()):
    if absf(ys[i]-end)>.01:
     runs[Vector3i(x,roundi(start*1000),roundi(end*1000))]=true;start=ys[i]
    end=ys[i]+4
   runs[Vector3i(x,roundi(start*1000),roundi(end*1000))]=true
  var all_runs:=runs.duplicate();var ordered:Array=runs.keys()
  ordered.sort_custom(func(a:Vector3i,b:Vector3i)->bool:return a.y<b.y or (a.y==b.y and a.x<b.x))
  for run:Vector3i in ordered:
   if not runs.has(run):continue
   var length:=1
   while length<8 and floori(float(run.x+4)/8)==floori(float(run.x+length+4)/8) and runs.has(run+Vector3i(length,0,0)):
    length+=1
   for j in length:runs.erase(run+Vector3i(j,0,0))
   var width:=length*3.0;var bottom:=float(run.y)/1000.0;var height:=float(run.z-run.y)/1000.0
   var origin:Vector3=plane.basis.x*(run.x*3.0+width*.5)+plane.basis.z*float(plane.depth);origin.y=bottom
   var left_end:=not all_runs.has(run-Vector3i(1,0,0))
   var right_end:=not all_runs.has(run+Vector3i(length,0,0))
   # A height change is only an exposed end above the adjoining wall. Read
   # the actual adjacent native column, independent of canonical panel width.
   var shared:=Vector2.ZERO
   if left_end:shared.x=_shared_column_height(plane.columns.get(run.x-1,[]),bottom,height)
   if right_end:shared.y=_shared_column_height(plane.columns.get(run.x+length,[]),bottom,height)
   result.append({"pose":Transform3D(plane.basis,origin),"width":width,"height":height,
    "left_end":left_end,"right_end":right_end,"edge_heights":shared})
 return result

static func grass_supports(rock:Dictionary,neighbors:Array)->Array[Dictionary]:
 var result:Array[Dictionary]=[]
 var green:PackedVector3Array=rock.green
 var borders:=_turf_component_borders(rock,neighbors)
 var bins:Dictionary={}
 for other:Dictionary in neighbors:
  if not (other.bounds as AABB).intersects(rock.bounds):continue
  for j in range(0,other.faces.size(),3):
   var triangle:=PackedVector3Array([other.transform*other.faces[j],other.transform*other.faces[j+1],other.transform*other.faces[j+2]])
   var bounds:=Rect2(Vector2(triangle[0].x,triangle[0].z),Vector2.ZERO)
   for point:Vector3 in triangle:bounds=bounds.expand(Vector2(point.x,point.z))
   for bx in range(floori(bounds.position.x/2),floori(bounds.end.x/2)+1):
    for bz in range(floori(bounds.position.y/2),floori(bounds.end.y/2)+1):
     var key:=Vector2i(bx,bz)
     if not bins.has(key):bins[key]=[]
     bins[key].append({"face":triangle,"bounds":bounds})
 for i in range(0,green.size(),3):
  var face:=PackedVector3Array([rock.transform*green[i],rock.transform*green[i+1],rock.transform*green[i+2]])
  var normal:Vector3=(face[2]-face[0]).cross(face[1]-face[0]).normalized()
  var tri:=PackedVector2Array([Vector2(face[0].x,face[0].z),Vector2(face[1].x,face[1].z),Vector2(face[2].x,face[2].z)])
  # Coplanar neighboring triangles share their exterior border. Reject only
  # zero-area pieces here; the grass worker checks the whole patch footprint.
  if absf((tri[1]-tri[0]).cross(tri[2]-tri[0]))<.00001:continue
  var box:=Rect2(tri[0],Vector2.ZERO)
  for p:Vector2 in tri:box=box.expand(p)
  var polygons:Array=[]
  var seen:Dictionary={}
  for bx in range(floori(box.position.x/2),floori(box.end.x/2)+1):
   for bz in range(floori(box.position.y/2),floori(box.end.y/2)+1):
    for candidate:Dictionary in bins.get(Vector2i(bx,bz),[]):
     if not (candidate.bounds as Rect2).intersects(box,true):continue
     var triangle:PackedVector3Array=candidate.face
     var key:=[triangle[0],triangle[1],triangle[2]]
     if seen.has(key):continue
     seen[key]=true
     var polygon:=PackedVector2Array()
     for edge in 3:
      var a:Vector3=triangle[edge];var b:Vector3=triangle[(edge+1)%3]
      var da:float=(a-face[0]).dot(normal)-.09;var db:float=(b-face[0]).dot(normal)-.09
      if da>0:polygon.append(Vector2(a.x,a.z))
      if (da>0)!=(db>0):
       var crossing:=a.lerp(b,da/(da-db));polygon.append(Vector2(crossing.x,crossing.z))
     if polygon.size()<3:continue
     var area:=0.0
     for edge in polygon.size():area+=polygon[edge].cross(polygon[(edge+1)%polygon.size()])
     if absf(area)>.00001:polygons.append(polygon)
  result.append({"id":rock.id+"/turf/%d"%i,"height":maxf(face[0].y,maxf(face[1].y,face[2].y)),"normal":normal,"face":face,
   "bounds":box,"triangles":tri,"border":borders.get(rock.id+"/turf/%d"%i,PackedVector2Array([tri[0],tri[1],tri[1],tri[2],tri[2],tri[0]])),"obstacles":[],"polygon_obstacles":polygons,"foliage_managed":true})
 return result

static func _root(parent:Array[int],index:int)->int:
 while parent[index]!=index:index=parent[index]
 return index

static func _turf_component_borders(rock:Dictionary,neighbors:Array)->Dictionary:
 var records:Array=[];var parent:Array[int]=[];var edges:Dictionary={};var members:Dictionary={}
 for other:Dictionary in neighbors:
  if not (other.bounds as AABB).intersects(rock.bounds):continue
  for i in range(0,other.green.size(),3):
   var face:=PackedVector3Array([other.transform*other.green[i],other.transform*other.green[i+1],other.transform*other.green[i+2]])
   var normal:Vector3=(face[2]-face[0]).cross(face[1]-face[0]).normalized()
   var index:=records.size();parent.append(index);members[index]=[index]
   records.append({"id":other.id+"/turf/%d"%i,"face":face,"normal":normal})
   for edge in 3:
    var a:Vector3=face[edge].snapped(Vector3.ONE*.0001);var b:Vector3=face[(edge+1)%3].snapped(Vector3.ONE*.0001)
    var key:Array=[a,b] if a<b else [b,a]
    if edges.has(key):
     var neighbor:int=edges[key]
     var a_root:=_root(parent,index);var b_root:=_root(parent,neighbor)
     if a_root!=b_root and _turf_planes_agree(records,members[a_root],members[b_root]):
      parent[a_root]=b_root
      members[b_root].append_array(members[a_root]);members.erase(a_root)
    else:edges[key]=index
 var group_edges:Dictionary={}
 for i in records.size():
  var root:=_root(parent,i)
  if not group_edges.has(root):group_edges[root]={}
  var face:PackedVector3Array=records[i].face
  for edge in 3:
   var a:Vector3=face[edge].snapped(Vector3.ONE*.0001);var b:Vector3=face[(edge+1)%3].snapped(Vector3.ONE*.0001)
   var key:Array=[a,b] if a<b else [b,a]
   group_edges[root][key]=group_edges[root].get(key,0)+1
 var group_borders:Dictionary={}
 for root:int in group_edges:
  var border:=PackedVector2Array()
  for edge:Array in group_edges[root]:
   if group_edges[root][edge]!=1:continue
   border.append(Vector2(edge[0].x,edge[0].z));border.append(Vector2(edge[1].x,edge[1].z))
  group_borders[root]=border
 var result:Dictionary={}
 for i in records.size():result[records[i].id]=group_borders[_root(parent,i)]
 return result

static func _turf_planes_agree(records:Array,left:Array,right:Array)->bool:
 # Quantized curved treads can have sub-millimetre plane differences even
 # where their normal angle changes. Test the actual whole component, not
 # an angle threshold or a transitive chain of individually shallow bends.
 # Every member's plane must support every vertex within one millimetre;
 # roots still use the actual triangle and the worker's whole-patch checks.
 for a:int in left:
  for b:int in right:
   for point:Vector3 in records[a].face:
    if absf((point-records[b].face[0]).dot(records[b].normal))>.001:return false
   for point:Vector3 in records[b].face:
    if absf((point-records[a].face[0]).dot(records[a].normal))>.001:return false
 return true

static func crags(faces:PackedVector3Array)->Array[Dictionary]:
 var edges:Dictionary={};var result:Array[Dictionary]=[]
 for i in range(0,faces.size(),3):
  var normal:Vector3=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized()
  if normal.z<.2:continue
  for j in 3:
   var a:Vector3=faces[i+j].snapped(Vector3.ONE*.001);var b:Vector3=faces[i+(j+1)%3].snapped(Vector3.ONE*.001)
   var key:Array=[a,b] if a<b else [b,a]
   var entry:Dictionary={"point":(a+b)*.5,"normal":normal,"opposite":faces[i+(j+2)%3]}
   if not edges.has(key):edges[key]=entry;continue
   var prior:Dictionary=edges[key]
   if normal.dot(prior.normal)>.98 or normal.dot(prior.normal)<.1:continue
   if (entry.opposite-prior.point).dot(prior.normal)<.01:continue
   if a.distance_to(b)<.3:continue
   var direction:Vector3=(normal+prior.normal).normalized()
   result.append({"point":entry.point,"normal":direction,"kind":"crag"})
 return result

static func _shared_column_height(ys:Array,bottom:float,height:float)->float:
 var shared:=0.0
 while shared<height and ys.has(bottom+shared):shared+=4.0
 return minf(shared,height)
