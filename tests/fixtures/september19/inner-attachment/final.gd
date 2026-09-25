extends RefCounted
## Closed rock joins following convex and concave native corners.
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
static var _depth:=PackedFloat32Array()
static var _normal:=PackedVector3Array()
static func prepare()->void:
 if not _depth.is_empty():return
 assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
 var depths:=PackedFloat32Array();var normals:=PackedVector3Array()
 var faces:PackedVector3Array=load("res://terrain/environment/meshes/kaykit/kaykit_cliff_outer_wall_piece_00.res").get_faces()
 for row in 41:
  var y:=clampf(-.3+row*.1,-.29999,3.69999)
  for column in 31:
   var angle:=clampf(float(column)/30.0*PI*.5,.00001,PI*.5-.00001)
   var direction:=Vector3(sin(angle),0,cos(angle))
   var center:=Vector3(-1.5,y,-1.5)
   var radius:=-INF;var normal:=direction
   # Exact authored groove boundaries can be coplanar with the ray.
   # Use a bounded one-sided native sample there, never a guessed depth.
   for offset:float in [0.0,.0001,-.0001]:
    var origin:=center+direction*20+Vector3.UP*offset
    for i in range(0,faces.size(),3):
     var hit=Geometry3D.ray_intersects_triangle(origin,-direction,faces[i],faces[i+1],faces[i+2])
     if hit!=null and (hit-center).dot(direction)>radius:
      radius=(hit-center).dot(direction)
      normal=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized()
    if is_finite(radius):break
   assert(is_finite(radius),"Native corner ray missed: row=%d column=%d y=%f"%[row,column,y])
   depths.append(radius-1.5);normals.append(normal)
 _normal=normals;_depth=depths
 _prepare_inner()

static func _native(u:float,y:float,pose:Transform3D)->Array:
 if u<=-1.5:
  var phase:float=pose.origin.dot(pose.basis.x)+u
  return [CRAGS._native_depth(phase,y),CRAGS._native_normal(phase,y)]
 if u>=1.5:
  var phase:float=-pose.origin.dot(pose.basis.z)+u
  var n:Vector3=CRAGS._native_normal(phase,y)
  return [CRAGS._native_depth(phase,y),Vector3(n.z,n.y,-n.x)]
 var x:float=(u+1.5)*10.0;var v:float=fposmod(y+.3,4.0)*10.0
 var ix:=mini(29,floori(x));var iy:=mini(39,floori(v))
 var tx:=x-ix;var ty:=v-iy;var i:=iy*31+ix
 return [lerpf(lerpf(_depth[i],_depth[i+1],tx),lerpf(_depth[i+31],_depth[i+32],tx),ty),
  _normal[i].lerp(_normal[i+1],tx).lerp(_normal[i+31].lerp(_normal[i+32],tx),ty).normalized()]

static func corner_shift(u:float)->float:
 return 1.0-smoothstep(1.4,4.5,absf(u))

static func make(pose:Transform3D,height:float,seed_value:int,region:HeightfieldRegion=null)->Dictionary:
 prepare();CRAGS.prepare()
 var source:Dictionary=CRAGS.make(pose,12,height,seed_value,null,true,true)[0]
 _repair_flat_end_caps(source)
 var mapping:Dictionary={};var roots:Dictionary={}
 var minimum:=0.0
 for p:Vector3 in source.faces:minimum=minf(minimum,p.y)
 var floor_y:=minimum
 for p:Vector3 in source.faces:
  if mapping.has(p):continue
  # Keep the formation wavelength comparable to the neighboring faces.
  # Compressing 12 m of source into this 3 m turn created radial pleats.
  var native_u:float=p.x
  var native:=_native(native_u,p.y,pose)
  var old_native:float=CRAGS._native_depth(pose.origin.dot(pose.basis.x)+p.x,p.y)
  var thickness:=p.z-old_native
  var root_weight:=1.0-smoothstep(.2,2.0,thickness)
  # Preserve the body's thickness when turning around the deeper native corner.
  # Only the thin join borrows individual courses; thick stone gets a mean shift.
  var correction:float=lerpf(.55*corner_shift(native_u),native[0]-old_native,root_weight)*smoothstep(-.5,.4,p.z)
  var depth:=p.z+correction
  # A convex join carries a shallow shoulder, not a cylinder as deep as a
  # straight face. Preserve the native corner through the thin root, then let
  # asymmetric clefts and the lower shoulder project independently.
  var corner_weight:=1.0-smoothstep(1.4,4.5,absf(native_u))
  var exposure:=maxf(0.0,depth-float(native[0]))
  # Let lower corner bearings retain their fuller source shoulder; the upper
  # face and genuinely thin native attachment keep the original attenuation.
  var relief_scale:=lerpf(.65,1.0,1.0-smoothstep(.0,.6,p.y/height))
  relief_scale+=.18*(CRAGS._noise(p.y/2.7+p.x*.24,seed_value+313)-.5)
  depth-=exposure*corner_weight*(1.0-relief_scale)
  var position:Vector3
  if p.x<=-1.5:position=Vector3(p.x,p.y,depth)
  elif p.x>=1.5:position=Vector3(depth,p.y,-p.x)
  else:
   var angle:float=(p.x+1.5)/3.0*PI*.5
   position=Vector3(-1.5+sin(angle)*(1.5+depth),p.y,-1.5+cos(angle)*(1.5+depth))
  position=position.snapped(Vector3.ONE*.0001)
  mapping[p]=position
  roots[position]=[native[1],smoothstep(.015,.18,depth-float(native[0]))]
  if region!=null and p.y<=minimum+.001:
   var world:Vector3=pose*position
   floor_y=minf(floor_y,TerrainSurfaceField.surface_y(region,world.x,world.z)-pose.origin.y-.2)
 return _finish(source,mapping,roots,pose,height,seed_value,minimum,floor_y,false)

static func _finish(source:Dictionary,mapping:Dictionary,roots:Dictionary,pose:Transform3D,height:float,seed_value:int,minimum:float,floor_y:float,inner:bool)->Dictionary:
 if floor_y<minimum:
  for p:Vector3 in mapping.keys():
   if p.y>minimum+.001:continue
   var moved:Vector3=mapping[p];roots.erase(moved);moved.y=floor_y
   moved=moved.snapped(Vector3.ONE*.0001);mapping[p]=moved
   roots[moved]=[Vector3.BACK,1.0]
 var faces:=PackedVector3Array();var green:=PackedVector3Array()
 # Quantization can identify the two tips of a vanishing tread. Drop only
 # triangles whose mapped vertices become identical; adjacent faces retain
 # that exact shared edge and the closed shell does not gain a slit.
 for source_faces:PackedVector3Array in [source.faces,source.green]:
  var target:PackedVector3Array=faces if source_faces==source.faces else green
  for i in range(0,source_faces.size(),3):
   var a:Vector3=mapping[source_faces[i]]
   var b:Vector3=mapping[source_faces[i+1]]
   var c:Vector3=mapping[source_faces[i+2]]
   if a==b or b==c or c==a:continue
   target.append(a);target.append(b);target.append(c)
 var bounds:=AABB(faces[0],Vector3.ZERO)
 for p:Vector3 in faces:bounds=bounds.expand(p)
 return {"faces":faces,"green":green,"native_roots":roots,"bounds":pose*bounds,"transform":pose,"anchor":pose.origin,
  "replay_recipe":{"kind":"inner_corner" if inner else "corner","height":height,"seed":seed_value},
  "id":"%s_crag/%s/%s"%["inner_corner" if inner else "corner",pose.origin,pose.basis],"asset":&"cliff.native_crag","kind":"rock","native_crag":true,
  "top":(pose*bounds).end.y,"base":(pose*bounds).position.y}

static func formations(rows:Array,seed_value:int,region:HeightfieldRegion=null,features:FeatureContext=null,inner:bool=false)->Array[Dictionary]:
 var columns:Dictionary={}
 for pose:Transform3D in rows:
  var key:Array=[pose.basis,Vector2(pose.origin.x,pose.origin.z)]
  if not columns.has(key):columns[key]=[]
  if not columns[key].has(pose.origin.y):columns[key].append(pose.origin.y)
 var result:Array[Dictionary]=[]
 for key:Array in columns:
  var heights:Array=columns[key];heights.sort()
  var bottom:float=heights[0];var top:float=bottom+4
  for index in range(1,heights.size()+1):
   if index==heights.size() or absf(float(heights[index])-top)>.01:
    if top-bottom>=(4 if inner else 8):
     var pose:=Transform3D(key[0],Vector3(key[1].x,bottom,key[1].y))
     var rock:=make_inner(pose,top-bottom,seed_value,region) if inner else make(pose,top-bottom,seed_value,region)
     var box:AABB=rock.bounds
     var footprint:=Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
     var graded:bool=region!=null and region.has_grade_effect_in(footprint.grow(.1))
     var reserved:bool=features!=null and features.overlaps_clearance(FeatureGroundShape.axis_rect(footprint),.3)
     if not graded and not reserved:result.append(rock)
    if index==heights.size():break
    bottom=heights[index]
   top=heights[index]+4
 return result

static var _inner_depth:=PackedFloat32Array()
static var _inner_normal:=PackedVector3Array()
const INNER_COLUMNS:=481
const INNER_HALF_WIDTH:=6.0
const INNER_STEP:=.025
const INNER_ROWS:=41
const INNER_VERTICAL_STEP:=.1
static func _prepare_inner()->void:
 if not _inner_depth.is_empty():return
 assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
 var faces:PackedVector3Array=load("res://terrain/environment/meshes/kaykit/kaykit_cliff_inner_wall_piece_00.res").get_faces()
 # The diagonal sweep also advances along each straight wall. Sample that
 # actual intersection together with the native corner, rather than switching
 # to a perpendicular sample at |u|=1 (which made a visible depth jump).
 var wall:PackedVector3Array=load("res://terrain/environment/meshes/kaykit/kaykit_cliff_wall_piece_00.res").get_faces()
 for center:float in [3,6,9]:
  for p:Vector3 in wall:faces.append(Vector3(center+p.x,p.y,p.z))
  for p:Vector3 in wall:faces.append(Vector3(p.z,p.y,center-p.x))
 var depths:=PackedFloat32Array();var normals:=PackedVector3Array()
 for row in INNER_ROWS:
  var y:=clampf(-.3+row*INNER_VERTICAL_STEP,-.29999,3.69999)
  for column in INNER_COLUMNS:
   var u:float=-INNER_HALF_WIDTH+float(column)*INNER_STEP
   var base:=Vector3(maxf(u,0),y,maxf(-u,0))
   var depth:=-INF;var normal:=Vector3(1,0,1).normalized()
   for offset:float in [0.0,.0001,-.0001]:
    for i in range(0,faces.size(),3):
     var hit=Geometry3D.ray_intersects_triangle(base+Vector3(20,offset,20),Vector3(-1,0,-1).normalized(),faces[i],faces[i+1],faces[i+2])
     if hit!=null and hit.x-base.x>depth:
      depth=hit.x-base.x
      normal=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized()
    if is_finite(depth):break
   assert(is_finite(depth),"Missing native inner-corner bearing: %d %d"%[row,column])
   depths.append(depth);normals.append(normal)
 _inner_depth=depths;_inner_normal=normals

static func _inner_native(u:float,y:float,_pose:Transform3D)->Array:
 var x:float=(clampf(u,-INNER_HALF_WIDTH,INNER_HALF_WIDTH)+INNER_HALF_WIDTH)/INNER_STEP
 var v:float=fposmod(y+.3,4.0)/INNER_VERTICAL_STEP
 var ix:=mini(INNER_COLUMNS-2,floori(x));var iy:=mini(INNER_ROWS-2,floori(v))
 var tx:=x-ix;var ty:=v-iy;var i:=iy*INNER_COLUMNS+ix
 return [lerpf(lerpf(_inner_depth[i],_inner_depth[i+1],tx),lerpf(_inner_depth[i+INNER_COLUMNS],_inner_depth[i+INNER_COLUMNS+1],tx),ty),
  _inner_normal[i].lerp(_inner_normal[i+1],tx).lerp(_inner_normal[i+INNER_COLUMNS].lerp(_inner_normal[i+INNER_COLUMNS+1],tx),ty).normalized()]

static func make_inner(pose:Transform3D,height:float,seed_value:int,region:HeightfieldRegion=null)->Dictionary:
 prepare();CRAGS.prepare()
 var source:Dictionary=CRAGS.make(pose,12,height,seed_value,null,true,true)[0]
 _repair_flat_end_caps(source)
 var mapping:Dictionary={};var roots:Dictionary={}
 var minimum:float=source.faces[0].y
 for p:Vector3 in source.faces:minimum=minf(minimum,p.y)
 var floor_y:=minimum
 for p:Vector3 in source.faces:
  if mapping.has(p):continue
  var native:=_inner_native(p.x,p.y,pose)
  var old_native:=CRAGS._native_depth(pose.origin.dot(pose.basis.x)+p.x,p.y)
  var thickness:=p.z-old_native
  # Sweep along the bisector instead of shrinking a concave radius: the latter
  # folds over itself as soon as a lower shoulder exceeds the native radius.
  # x-z remains the source coordinate, so even wide lower treads cannot cross.
  var weight:=1.0-smoothstep(.2,2.0,thickness)
  # Broad bodies retain their own relief; subtracting the sampled native
  # course here would emboss the inverse tile pattern on the added rock.
  var rounding:=.5*(sqrt(p.x*p.x+2.25)-absf(p.x))
  var correction:=lerpf(rounding,float(native[0])-old_native,weight)
  var depth:=p.z+correction*smoothstep(-.5,.4,p.z)
  var position:=Vector3(maxf(p.x,0)+depth,p.y,maxf(-p.x,0)+depth).snapped(Vector3.ONE*.0001)
  mapping[p]=position
  roots[position]=[native[1],smoothstep(.015,.18,thickness)]
  if region!=null and p.y<=minimum+.001:
   var world:=pose*position
   floor_y=minf(floor_y,TerrainSurfaceField.surface_y(region,world.x,world.z)-pose.origin.y-.2)
 return _finish(source,mapping,roots,pose,height,seed_value,minimum,floor_y,true)

static func _repair_flat_end_caps(source:Dictionary)->void:
 # Native polygon triangulation can leave zero-area ears along a straight end
 # boundary. Retriangulate only affected end caps, then restore every boundary
 # sample by splitting its containing triangle. Dropping ears alone opens seams.
 var faces:PackedVector3Array=source.faces
 for end:float in [-6.0,6.0]:
  var broken:=false
  for i in range(0,faces.size(),3):
   var a:Vector3=faces[i];var b:Vector3=faces[i+1];var c:Vector3=faces[i+2]
   if a.x==end and b.x==end and c.x==end and (b-a).cross(c-a).length_squared()<1e-14:
    broken=true;break
  if not broken:continue
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
  var outline:=PackedVector2Array();var point:Vector2=adjacency.keys()[0];var previous:=Vector2(INF,INF)
  for step in adjacency.size():
   outline.append(point)
   var next:Vector2=adjacency[point][0]
   if next==previous:next=adjacency[point][1]
   previous=point;point=next
  assert(point==outline[0],"End-cap boundary must be one closed loop")
  var clean:=PackedVector2Array()
  for i in outline.size():
   var a:Vector2=outline[posmod(i-1,outline.size())];var b:=outline[i];var c:=outline[(i+1)%outline.size()]
   if absf((b-a).cross(c-b))>.0000001:clean.append(b)
  var indices:=Geometry2D.triangulate_polygon(clean)
  assert(not indices.is_empty())
  var triangles:Array=[]
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
   assert(found,"Every collinear boundary sample retains its physical edge")
  for tri:Array in triangles:
   var a:=Vector3(end,tri[0].y,tri[0].x);var b:=Vector3(end,tri[1].y,tri[1].x);var c:=Vector3(end,tri[2].y,tri[2].x)
   if (c-a).cross(b-a).x*end<0:var swap:=b;b=c;c=swap
   rest.append_array(PackedVector3Array([a,b,c]))
  faces=rest
 source.faces=faces
