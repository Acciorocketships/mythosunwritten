extends RefCounted
## Embedded weathered rock masses with staggered ledges and broader rooted feet.
## World-coordinate fields agree across chunk ownership; no course repeats by cell.
static var _wall_depth:=PackedFloat32Array()
static var _wall_normals:=PackedVector3Array()
static func prepare()->void:
 if not _wall_depth.is_empty():return
 assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
 # Detach the real native relief once. Worker geometry uses only numeric arrays.
 var native:Mesh=load("res://terrain/environment/meshes/kaykit/kaykit_cliff_wall_piece_00.res")
 var faces:=native.get_faces()
 for iy in 41:
  for ix in 31:
   var origin:=Vector3(clampf(-1.5+ix*.1,-1.49999,1.49999),clampf(-.3+iy*.1,-.29999,3.69999),5)
   var depth:=-INF;var normal:=Vector3.BACK
   for i in range(0,faces.size(),3):
    var hit=Geometry3D.ray_intersects_triangle(origin,Vector3.FORWARD,faces[i],faces[i+1],faces[i+2])
    if hit!=null and hit.z>depth:
     depth=hit.z;normal=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized()
   assert(is_finite(depth))
   _wall_depth.append(depth);_wall_normals.append(normal)

static func _wall_indices(u:float,y:float)->Vector4:
 var x:=fposmod(u,3.0)*10.0;var v:=fposmod(y+.3,4.0)*10.0
 return Vector4(mini(29,floori(x)),mini(39,floori(v)),x-floorf(x),v-floorf(v))

static func _native_depth(u:float,y:float)->float:
 var q:=_wall_indices(u,y);var i:=int(q.y)*31+int(q.x)
 return lerpf(lerpf(_wall_depth[i],_wall_depth[i+1],q.z),lerpf(_wall_depth[i+31],_wall_depth[i+32],q.z),q.w)

static func _native_normal(u:float,y:float)->Vector3:
 var q:=_wall_indices(u,y);var i:=int(q.y)*31+int(q.x)
 return _wall_normals[i].lerp(_wall_normals[i+1],q.z).lerp(_wall_normals[i+31].lerp(_wall_normals[i+32],q.z),q.w).normalized()

static func _attach(depth:float,u:float,y:float,fade:float)->float:
 var front:=lerpf(-.5,_projection(depth),fade)
 # Native courses are only borrowed while the added skin is thin. They disappear
 # through a broad transition before the independent outer rock faces take over.
 var weight:float=(1.0-smoothstep(.65,2.5,front))*smoothstep(-.5,.3,front)
 return front+(_native_depth(u,y)-.62)*weight


static func _noise(x:float,salt:int)->float:
 var i:=floori(x);var t:=smoothstep(0.0,1.0,x-i)
 return lerpf(Helper.position_hash01(Vector3(i,salt,0),salt),Helper.position_hash01(Vector3(i+1,salt,0),salt),t)

static func make(pose:Transform3D,width:float,height:float,seed_value:int,region:HeightfieldRegion=null,left_end:bool=false,right_end:bool=false)->Array[Dictionary]:
 if _wall_depth.is_empty():prepare()
 var steps:=maxi(2,roundi(width/.25));var columns:Array=[];var column_bands:Array=[]
 var faces:=PackedVector3Array();var green:=PackedVector3Array()
 var coordinate:=pose.origin.dot(pose.basis.x)
 var salt:=seed_value+roundi(pose.origin.dot(pose.basis.z))*13+roundi(pose.origin.y)*71

 for ix in steps+1:
  var x:float=-width*.5+width*float(ix)/steps;var u:=coordinate+x
  var fade:=1.0
  if left_end:fade*=smoothstep(0.0,2.5,x+width*.5)
  if right_end:fade*=smoothstep(0.0,2.5,width*.5-x)
  var core:=lerpf(1.9,2.8,_noise(u/13.0,salt+53))*clampf(height/10.0,.35,1.15)
  var boulder:=4.8*smoothstep(.38,.82,_noise(u/5.7,salt+83))*clampf(height/16.0,.25,1.0)
  var crest:=height-.08-height*.34*pow(_noise(u/3.7,salt+91),12.0)
  var fractures:=_fracture_profile(u,height,salt)
  var masses:=_mass_profile(u,height,salt)
  var chips:=_chip_profile(u,height,salt)
  var cuts:Array=[]
  for cut in 8:
   var phase:=float(cut)*5.31
   var slot:=floori((u+phase)/32.0)
   var key:=Vector3(slot,cut,0)
   var center:float=(slot+.5)*32.0-phase+lerpf(-1.0,1.0,Helper.position_hash01(key,salt+149))
   var half_width:=lerpf(2.2 if cut>=6 else 1.4,5.2,Helper.position_hash01(key,salt+173))
   var top:=_ledge_plane(u,slot,cut,phase,height,salt)
   # Only the gaps between finite ledges interpolate elevation. The sampling
   # rows never race several metres vertically at a disappearing ledge tip.
   var cell_t:float=(u+phase)/32.0-slot
   if cell_t<.30:
    top=lerpf(_ledge_plane(u,slot-1,cut,phase,height,salt),top,smoothstep(-.30,.30,cell_t))
   elif cell_t>.70:
    top=lerpf(top,_ledge_plane(u,slot+1,cut,phase,height,salt),smoothstep(.70,1.30,cell_t))
   top=minf(top,crest-.12)
   var weight:=smoothstep(half_width,half_width*.6,absf(u-center))
   weight*=smoothstep(.03,.12,(crest-top)/height)
   var strength:=weight*lerpf(.7,1.7,Helper.position_hash01(key,salt+193))*clampf(height/12.0,.35,1.0)
   var thickness:=lerpf(1.1,4.2,Helper.position_hash01(key,salt+241))
   cuts.append([top,strength,thickness])
  cuts.sort_custom(func(a:Array,b:Array)->bool:return a[0]<b[0])
  for cut in range(cuts.size()-2,-1,-1):cuts[cut][0]=minf(cuts[cut][0],cuts[cut+1][0]-.12)
  var points:=PackedVector3Array([Vector3(x,height,-.5),Vector3(x,crest,-.5)])
  var bands:Array=[[0,1,false]]
  var previous_y:=crest
  for cut in range(cuts.size()-1,-1,-1):
   var top:float=cuts[cut][0];var strength:float=cuts[cut][1]
   var cut_drop:=.005*(1.0-smoothstep(0.0,.15,strength))
   var band_start:=points.size()-1
   var samples:=_height_samples(previous_y,top)
   for y:float in samples:
    var depth:float=_body_depth(u,y,core,crest,boulder,salt,fractures,masses,chips)+_shoulders(y,cuts,cut+1)
    points.append(Vector3(x,y,_attach(depth,u,y,fade)))
   bands.append([band_start,points.size()-1,false])
   band_start=points.size()-1
   var depth:float=_body_depth(u,top-cut_drop,core,crest,boulder,salt,fractures,masses,chips)+_shoulders(top-cut_drop,cuts,cut)
   points.append(Vector3(x,top-cut_drop,_attach(depth,u,top-cut_drop,fade)))
   bands.append([band_start,points.size()-1,true])
   previous_y=top-cut_drop
  var foot_depth:=_attach(_body_depth(u,0,core,crest,boulder,salt,fractures,masses,chips)+_shoulders(0,cuts,0),u,0,fade)
  var floor_y:=-.20
  if region!=null:
   for z:float in [0.0,foot_depth*.5,foot_depth]:
    var foot:Vector3=pose*Vector3(x,0,z)
    floor_y=minf(floor_y,TerrainSurfaceField.surface_y(region,foot.x,foot.z)-pose.origin.y-.2)
  var band_start:=points.size()-1
  for y:float in _height_samples(previous_y,floor_y):
   var depth:float=_body_depth(u,y,core,crest,boulder,salt,fractures,masses,chips)+_shoulders(y,cuts,0)
   points.append(Vector3(x,y,_attach(depth,u,y,fade)))
  bands.append([band_start,points.size()-1,false])
  columns.append(points);column_bands.append(bands)
 # Join each continuous face band by elevation, not its sampling-row index.
 # Neighboring ledges can have different heights; index pairing shears dense
 # samples into long diagonal triangles and creates a visible sawtooth pattern.
 for ix in steps:
  for band_index in column_bands[ix].size():
   var band:Array=column_bands[ix][band_index];var next_band:Array=column_bands[ix+1][band_index]
   var left:int=band[0];var right:int=next_band[0];var last_left:int=band[1];var last_right:int=next_band[1]
   while left<last_left or right<last_right:
    var tri:Array
    if right==last_right or (left<last_left and columns[ix][left+1].y>=columns[ix+1][right+1].y):
     tri=[columns[ix][left],columns[ix+1][right],columns[ix][left+1]]
     left+=1
    else:
     tri=[columns[ix][left],columns[ix+1][right],columns[ix+1][right+1]]
     right+=1
    for vertex in 3:tri[vertex]=tri[vertex].snapped(Vector3.ONE*.0001)
    _triangle(faces,tri[0],tri[1],tri[2])
    var normal:Vector3=(tri[2]-tri[0]).cross(tri[1]-tri[0]).normalized()
    if band[2] and normal.y>.80 and minf(tri[0].z,minf(tri[1].z,tri[2].z))>.4:
     _triangle(green,tri[0],tri[1],tri[2])
 # Close the same front triangulation against the buried back plane. Using
 # its exact edges also closes unequal-height neighboring sampling columns.
 var front_faces:=faces.duplicate()
 for i in range(0,front_faces.size(),3):
  var a:Vector3=front_faces[i];var b:Vector3=front_faces[i+1];var c:Vector3=front_faces[i+2]
  a.z=-1.2;b.z=-1.2;c.z=-1.2
  _triangle(faces,a,c,b)
 for ix in steps:
  for end:int in [0,1]:
   var row:int=0 if end==0 else columns[ix].size()-1
   var next_row:int=0 if end==0 else columns[ix+1].size()-1
   var a:Vector3=columns[ix][row];var b:Vector3=columns[ix+1][next_row];var c:=Vector3(a.x,a.y,-1.2);var d:=Vector3(b.x,b.y,-1.2)
   if row==0:_triangle(faces,a,c,b);_triangle(faces,b,c,d)
   else:_triangle(faces,a,b,c);_triangle(faces,b,d,c)
 for ix:int in [0,steps]:
  for row in columns[ix].size()-1:
   var a:Vector3=columns[ix][row];var b:Vector3=columns[ix][row+1];var c:=Vector3(a.x,a.y,-1.2);var d:=Vector3(b.x,b.y,-1.2)
   if ix==0:_triangle(faces,a,b,c);_triangle(faces,b,d,c)
   else:_triangle(faces,a,c,b);_triangle(faces,b,c,d)
 var bounds:=AABB(faces[0],Vector3.ZERO)
 for p:Vector3 in faces:bounds=bounds.expand(p)
 return [{"faces":faces,"green":green,"bounds":pose*bounds,"transform":pose,"anchor":pose.origin,
  "id":"worn_crag/%s/%s"%[pose.origin,pose.basis.z],"asset":&"cliff.native_crag","kind":"rock","native_crag":true,"top":(pose*bounds).end.y,"base":(pose*bounds).position.y}]

static func _height_samples(top:float,bottom:float)->Array[float]:
 # A shared physical lattice keeps steep neighboring faces sampled at the same
 # heights. Exact ledge boundaries are retained as additional constrained rows.
 var result:Array[float]=[]
 var y:=floorf((top-.0001)/.20)*.20
 while y>bottom+.0001:
  result.append(y)
  y-=.20
 result.append(bottom)
 return result

static func _projection(depth:float)->float:
 var reach:=depth*.80
 # Compress only unusually deep combinations, rather than clipping a flat face.
 return reach if reach<=6.5 else 6.5+1.25*(1.0-exp(-(reach-6.5)/1.25))

static func _body_depth(u:float,y:float,core:float,crest:float,boulder:float,salt:int,fractures:Array,masses:Array,chips:Array=[])->float:
 if y>=crest:return -.5
 var t:=clampf(1.0-y/crest,0.0,1.0)
 var broad:float=-.5+(core+.5)*pow(t,.17)
 var lower:float=boulder*(1.0-smoothstep(.06,.48,maxf(0,y)/crest))
 var mass_depth:=0.0
 for mass:Array in masses:
  var dy:float=(y-mass[0])/mass[1]
  var distance:float=maxf(mass[2],absf(dy))+.16*minf(mass[2],absf(dy))
  var bevel:float=smoothstep(0.0,.30,1.0-distance)
  mass_depth=maxf(mass_depth,mass[3]*bevel*(1.0+.10*dy))
 var v:=y/1.25;var row:=floori(v)
 var detail:=lerpf(_noise(u/1.1,salt+row*37+211),_noise(u/1.1,salt+(row+1)*37+211),smoothstep(0.0,1.0,v-row))-.5
 var small:=lerpf(_noise(u/.52,salt+row*31+271),_noise(u/.52,salt+(row+1)*31+271),smoothstep(0.0,1.0,v-row))-.5
 # Short, staggered fractures break the broad worn faces. Each ends within
 # the stone rather than becoming a repeated course across the entire wall.
 var fracture:=0.0
 for entry:Array in fractures:
  for joint:Array in entry[0]:
   var dy:float=y-joint[0]
   # A narrow cleft between worn faces: straight sloping sides with a small
   # bevel, rather than the soft Gaussian trench that inflated each shoulder.
   var width:float=joint[2] if joint.size()>2 else .24
   var cleft_shape:=clampf(1.0-absf(dy)/width,0.0,1.0)
   fracture+=joint[1]*.58*cleft_shape*smoothstep(0.0,.16,cleft_shape)
  var shift:=.18*(_noise(y/3.0,entry[2])-.5)
  var cleft:=exp(-pow((u-entry[1]+shift)/.40,2.0))
  fracture+=.48*cleft*smoothstep(.0,.15,t)*smoothstep(1.0,.70,t)
 var envelope:=smoothstep(0.0,.065,t)
 var structure:=broad+lower+mass_depth*envelope
 # Independent clefts must not cut holes through a thin attachment. Let the
 # sampled native wall own that region, then introduce the outer crags gradually.
 var detail_weight:=smoothstep(.25,1.7,_projection(structure)-_native_depth(u,y))
 var chipped:=0.0
 if not chips.is_empty():
  var row_index:=floori(y/2.2)
  for layer in range(maxi(0,row_index-1),mini(chips.size(),row_index+2)):
   for chip:Array in chips[layer]:
    var dy:float=(y-chip[0])/chip[1]
    var extent:float=maxf(chip[2],absf(dy))+.22*minf(chip[2],absf(dy))
    var edge:=clampf((1.0-extent)/.24,0.0,1.0)
    # A shallow fractured face with a narrow worn rim, not another round bump.
    chipped=maxf(chipped,chip[3]*edge*(.85+.15*dy))
 return structure+(.90*detail+.20*small-fracture-chipped)*envelope*detail_weight

static func _chip_profile(u:float,height:float,salt:int)->Array:
 var result:Array=[]
 for layer in ceili(height/2.2)+1:
  var entries:Array=[]
  for cell in range(floori(u/2.4)-1,floori(u/2.4)+2):
   var key:=Vector3(cell,layer,0)
   if Helper.position_hash01(key,salt+811)<.25:continue
   var center:float=(cell+Helper.position_hash01(key,salt+821))*2.4
   var dx:float=(u-center)/lerpf(.5,1.35,Helper.position_hash01(key,salt+823))
   if absf(dx)>=1.0:continue
   var cy:float=(layer+Helper.position_hash01(key,salt+827))*2.2
   cy+=dx*lerpf(-.4,.4,Helper.position_hash01(key,salt+829))
   entries.append([cy,lerpf(.5,1.5,Helper.position_hash01(key,salt+839)),absf(dx),lerpf(.28,.60,Helper.position_hash01(key,salt+853))])
  result.append(entries)
 return result

static func _ledge_plane(u:float,slot:int,cut:int,phase:float,height:float,salt:int)->float:
 var key:=Vector3(slot,cut,0)
 var center:float=(slot+.5)*32.0-phase
 return height*lerpf(.05 if cut>=6 else .09,.27 if cut>=6 else .87,Helper.position_hash01(key,salt+219))+lerpf(-.10,.10,Helper.position_hash01(key,salt+227))*(u-center)

static func _shoulders(y:float,cuts:Array,first:int)->float:
 # Finite ledge spans have supporting stone below them, rather than pinched
 # mushroom undersides. Their combined foot projection remains bounded.
 var depth:=0.0
 for i in range(first,cuts.size()):
  var drop:float=maxf(0,cuts[i][0]-y)
  depth+=cuts[i][1]*(.8+.2*smoothstep(0.0,cuts[i][2],drop))
 return minf(depth,2.2)

static func _mass_profile(u:float,height:float,salt:int)->Array:
 # Embedded, rounded block faces are distributed in two dimensions. Independent
 # centers/sizes break both vertical courses and repeated hemispherical pods.
 var result:Array=[]
 for cell in range(floori(u/5.0)-2,floori(u/5.0)+3):
  for layer in ceili(height/4.0):
   var key:=Vector3(cell,layer,0)
   if Helper.position_hash01(key,salt+701)<.24:continue
   var center:float=(cell+Helper.position_hash01(key,salt+703))*5.0
   var cy:float=(layer+Helper.position_hash01(key,salt+709))*4.0
   var lower:=1.0-clampf(cy/height,0.0,1.0)
   var rx:=lerpf(1.2,3.6,pow(Helper.position_hash01(key,salt+719),1.7))*(1.0+.35*lower)
   var ry:=lerpf(1.1,3.5,Helper.position_hash01(key,salt+727))
   var dx:=absf(u-center)/rx
   if dx>=1.0:continue
   cy+=lerpf(-.25,.25,Helper.position_hash01(key,salt+733))*(u-center)
   var depth:=lerpf(1.0,3.3,Helper.position_hash01(key,salt+739))*(.8+.90*lower)*clampf(height/16.0,.25,1.0)
   result.append([cy,ry,dx,depth])
 return result

static func _fracture_profile(u:float,height:float,salt:int)->Array:
 # Centers, spans and levels are constant down a vertical column. Prepare
 # once, keeping exactly the same field and arithmetic evaluation order.
 var result:Array=[]
 for cell in range(floori(u/6.0)-1,floori(u/6.0)+2):
  var key:=Vector3(cell,0,0)
  var center:float=(cell+Helper.position_hash01(key,salt+601))*6.0
  var half_span:=lerpf(4.2,5.2,Helper.position_hash01(key,salt+607))
  var joints:Array=[]
  var count:=maxi(3,ceili(height/3.8))
  var interval:=height/count
  for joint in count:
   var joint_key:=Vector3(cell,joint,0)
   var level:float=interval*(joint+lerpf(.20,.80,Helper.position_hash01(joint_key,salt+613)))
   level+=lerpf(-.22,.22,Helper.position_hash01(joint_key,salt+619))*(u-center)
   level+=.12*(_noise(u/1.8,salt+joint*31+617)-.5)
   var span:=half_span*lerpf(.85,1.15,Helper.position_hash01(joint_key,salt+623))
   var joint_center:float=(cell+Helper.position_hash01(joint_key,salt+627))*6.0
   var weight:=smoothstep(span,span*.55,absf(u-joint_center))
   joints.append([level,weight,lerpf(.35,.60,Helper.position_hash01(joint_key,salt+629))])
  result.append([joints,center,salt+cell*31+631])
 return result

static func _triangle(out:PackedVector3Array,a:Vector3,b:Vector3,c:Vector3)->void:
 # Planar shelves collapse the corresponding rear skin row. Weld first so
 # the front, rear and end skins agree on the same surviving edge vertices.
 a=a.snapped(Vector3.ONE*.0001);b=b.snapped(Vector3.ONE*.0001);c=c.snapped(Vector3.ONE*.0001)
 if a==b or b==c or c==a:return
 out.append(a);out.append(b);out.append(c)

static func mesh(rock:Dictionary)->ArrayMesh:
 assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
 var result:=ArrayMesh.new();var green:PackedVector3Array=rock.green
 var turf:Dictionary={}
 for i in range(0,green.size(),3):turf[[green[i],green[i+1],green[i+2]]]=true
 for grass in [false,true]:
  if grass and green.is_empty():continue
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_smooth_group(0)
  var faces:PackedVector3Array=green if grass else rock.faces
  for i in range(0,faces.size(),3):
   if not grass and turf.has([faces[i],faces[i+1],faces[i+2]]):continue
   var normal:Vector3=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized()
   for j in 3:
    st.set_normal(normal)
    st.set_uv(CliffDressing.ground_uv() if grass else Vector2.ZERO)
    st.add_vertex(faces[i+j])
  if not grass:
   st.generate_normals()
   var arrays:=st.commit_to_arrays()
   var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
   var colors:=PackedColorArray()
   var incident:Dictionary={}
   for i in range(0,points.size(),3):
    var face_normal:Vector3=(points[i+2]-points[i]).cross(points[i+1]-points[i]).normalized()
    for j in 3:
     if not incident.has(points[i+j]):incident[points[i+j]]=[]
     incident[points[i+j]].append(face_normal)
   var coordinate:float=rock.transform.origin.dot(rock.transform.basis.x)
   for i in points.size():
    var p:Vector3=points[i];var u:float=coordinate+p.x
    # Average the neighboring triangles on this side of a fracture. Broad
    # rounded faces remain smooth without borrowing light from across a joint.
    var start:=i-i%3
    var face_normal:Vector3=(points[start+2]-points[start]).cross(points[start+1]-points[start]).normalized()
    var average:=Vector3.ZERO
    for adjacent:Vector3 in incident[p]:
     average+=adjacent*smoothstep(cos(deg_to_rad(45)),cos(deg_to_rad(25)),face_normal.dot(adjacent))
    normals[i]=average.normalized()
    var thickness:=p.z-_native_depth(u,p.y)
    var independent:=smoothstep(.08,1.8,thickness)
    if p.z>-.4:normals[i]=_native_normal(u,p.y).lerp(normals[i],independent).normalized()
    colors.append(Color(1,1,1,independent))
   arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors
   result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  else:st.commit(result)
  if grass:result.surface_set_material(1,CliffDressing.shared_material())
  else:
   var material:=ShaderMaterial.new();material.shader=load("res://terrain/materials/cliff_crag.gdshader")
   result.surface_set_material(0,material)
 return result
