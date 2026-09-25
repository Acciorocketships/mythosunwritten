extends RefCounted
## Continuous rock wrapped around a real convex native corner.
const CRAGS=preload("res://tests/fixtures/september17/cliff-connected-stone/subtle.gd")
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
 var source:Dictionary=CRAGS.make(pose,21,height,seed_value,null,true,true)[0]
 var mapping:Dictionary={};var roots:Dictionary={}
 var minimum:=0.0
 for p:Vector3 in source.faces:minimum=minf(minimum,p.y)
 var floor_y:=minimum
 for p:Vector3 in source.faces:
  if mapping.has(p):continue
  # Sample a longer stretch of independently varying rock around the corner.
  # Three metres of source geometry stretched around the whole turn makes one
  # broad shelf wrap into a ring. Keep the arms at their physical scale and
  # compress a twelve-metre composition across the short convex turn instead.
  var native_u:float=p.x+4.5 if p.x<=-6.0 else p.x-4.5 if p.x>=6.0 else p.x*.25
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
  if p.x<=-6.0:position=Vector3(p.x+4.5,p.y,depth)
  elif p.x>=6.0:position=Vector3(depth,p.y,4.5-p.x)
  else:
   var angle:float=(p.x+6.0)/12.0*PI*.5
   position=Vector3(-1.5+sin(angle)*(1.5+depth),p.y,-1.5+cos(angle)*(1.5+depth))
  # Preserve distinct source vertices through the nonlinear corner map.
  mapping[p]=position
  roots[position]=[native[1],smoothstep(.08,1.8,depth-float(native[0]))]
  if region!=null and p.y<=minimum+.001:
   var world:Vector3=pose*position
   floor_y=minf(floor_y,TerrainSurfaceField.surface_y(region,world.x,world.z)-pose.origin.y-.2)
 if floor_y<minimum:
  for p:Vector3 in mapping.keys():
   if p.y>minimum+.001:continue
   var moved:Vector3=mapping[p];roots.erase(moved);moved.y=floor_y
   moved=moved.snapped(Vector3.ONE*.0001);mapping[p]=moved
   roots[moved]=[Vector3.BACK,1.0]
 var faces:=PackedVector3Array();var green:=PackedVector3Array()
 for p:Vector3 in source.faces:faces.append(mapping[p])
 for p:Vector3 in source.green:green.append(mapping[p])
 var bounds:=AABB(faces[0],Vector3.ZERO)
 for p:Vector3 in faces:bounds=bounds.expand(p)
 return {"faces":faces,"green":green,"native_roots":roots,"bounds":pose*bounds,"transform":pose,"anchor":pose.origin,
  "id":"corner_crag/%s/%s"%[pose.origin,pose.basis],"asset":&"cliff.native_crag","kind":"rock","native_crag":true,
  "top":(pose*bounds).end.y,"base":(pose*bounds).position.y}

static func formations(rows:Array,seed_value:int,region:HeightfieldRegion=null,features:FeatureContext=null)->Array[Dictionary]:
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
    if top-bottom>=8:
     var rock:=make(Transform3D(key[0],Vector3(key[1].x,bottom,key[1].y)),top-bottom,seed_value,region)
     var box:AABB=rock.bounds
     var footprint:=Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
     var graded:bool=region!=null and region.has_grade_effect_in(footprint.grow(.1))
     var reserved:bool=features!=null and features.overlaps_clearance(FeatureGroundShape.axis_rect(footprint),.3)
     if not graded and not reserved:result.append(rock)
    if index==heights.size():break
    bottom=heights[index]
   top=heights[index]+4
 return result
