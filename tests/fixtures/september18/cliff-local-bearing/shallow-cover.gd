extends RefCounted
## Embedded weathered rock masses with staggered ledges and broader rooted feet.
## World-coordinate fields agree across chunk ownership; no course repeats by cell.
## Lower terrace outlines come from baked CC0 Nature Pack rock cross-sections.
static var _nature_fields:Array=[]
static var _nature_bodies:Array=[]
static var _wall_depth:=PackedFloat32Array()
static var _wall_normals:=PackedVector3Array()
const MASS_FOOT_WIDENING:=.38
const MASS_SIDE_VARIATION:=.24
const MASS_LATERAL_DRIFT:=.12
static func prepare()->void:
 if not _wall_depth.is_empty():return
 assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
 var profiles:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://terrain/cliff/nature_rock_profiles.json"))
 for source:Dictionary in profiles.sources:
  var sections:Array=[]
  for section:Array in source.sections:sections.append(PackedFloat32Array(section))
  _nature_fields.append(sections)
  var rows:Array=[]
  for row:Array in source.body:rows.append(PackedFloat32Array(row))
  # Sub-metre sampling corners should not become isolated geometric teeth.
  for iteration in 2:
   var filtered:Array=[]
   for y in 33:
    var line:=PackedFloat32Array();line.resize(49)
    for x in 49:
     var value:=0.0
     for dy in range(-1,2):
      for dx in range(-1,2):
       var weight:float=(2.0 if dx==0 else 1.0)*(2.0 if dy==0 else 1.0)/16.0
       value+=rows[clampi(y+dy,0,32)][clampi(x+dx,0,48)]*weight
     line[x]=value
    filtered.append(line)
   rows=filtered
  _nature_bodies.append(rows)
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
 # A cubic shoulder has zero derivative where the skin emerges. Borrowing
 # normals alone hid the crease without making the physical join tangent.
 var distance:=front-.62
 if absf(distance)<.65:
  var ratio:=absf(distance)/.65
  front=.62+distance*ratio*(2.0-ratio)
 var weight:float=(1.0-smoothstep(.65,1.3,front))*smoothstep(-.5,.3,front)
 return front+(_native_depth(u,y)-.62)*weight


static func _noise(x:float,salt:int)->float:
 var i:=floori(x);var t:=smoothstep(0.0,1.0,x-i)
 return lerpf(Helper.position_hash01(Vector3(i,salt,0),salt),Helper.position_hash01(Vector3(i+1,salt,0),salt),t)

static func make(pose:Transform3D,width:float,height:float,seed_value:int,region:HeightfieldRegion=null,left_end:bool=false,right_end:bool=false)->Array[Dictionary]:
 if _wall_depth.is_empty():prepare()
 var steps:=maxi(2,roundi(width/.25));var columns:Array=[];var column_bands:Array=[]
 var faces:=PackedVector3Array();var green:=PackedVector3Array();var broad_turf:Dictionary={}
 var detail_cache:Dictionary={}
 var coordinate:=pose.origin.dot(pose.basis.x)
 var salt:=seed_value+roundi(pose.origin.dot(pose.basis.z))*13+roundi(pose.origin.y)*71

 for ix in steps+1:
  var x:float=-width*.5+width*float(ix)/steps;var u:=coordinate+x
  var fade:=1.0
  if left_end:fade*=smoothstep(0.0,2.5,x+width*.5)
  if right_end:fade*=smoothstep(0.0,2.5,width*.5-x)
  var core:=lerpf(1.6,2.0,_noise(u/13.0,salt+53))*clampf(height/10.0,.35,1.15)
  var boulder:=2.5*smoothstep(.38,.84,_noise(u/5.7,salt+83))*clampf(height/16.0,.25,1.0)
  var crest:=height-.08-minf(2.6,height*.25)*pow(_noise(u/3.7,salt+91),12.0)
  var basal:=_basal_profile(u,height,salt)
  var fractures:=_fracture_profile(u,height,salt)
  var masses:=_mass_profile(u,height,salt)
  for mass:Array in masses:mass[3]*=lerpf(.65,.9,smoothstep(16.0,64.0,height))
  masses.append_array(_nature_mass_profile(u,height,salt))
  var cuts:Array=[]
  var major:=_long_terraces(u,height,crest,salt)
  for cut in 9:
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
   # Use the same resting/sloped tread family above and below. Keeping these
   # shelves at zero grade made the upper cliff read as flat horizontal strips.
   cuts.append([top,strength,thickness,_tread_grade(Helper.position_hash01(key,salt+247))])
  # Leave breathing room around a major shelf. Widening every existing shelf
  # instead creates crossings that split the visible grass back into fragments.
  for cut:Array in cuts:
   for shelf:Array in major:
    cut[1]*=1.0-smoothstep(.05,.8,shelf[1])*(1.0-smoothstep(1.3,3.5,absf(cut[0]-shelf[0])))
  # The authored lower terraces are part of the rock's supporting mass, not
  # optional short shelf decoration; a long shelf must not erase their treads.
  cuts.append_array(_nature_terraces(u,height,crest,salt))
  cuts.append_array(major)
  cuts.sort_custom(func(a:Array,b:Array)->bool:return a[0]<b[0])
  _merge_close_ledges(cuts)
  cuts=cuts.filter(func(cut:Array)->bool:return cut[1]>.000001)
  cuts.sort_custom(func(a:Array,b:Array)->bool:return a[0]<b[0])
  for cut in range(cuts.size()-2,-1,-1):cuts[cut][0]=minf(cuts[cut][0],cuts[cut+1][0]-.0001)
  # Curving a low shelf must not carry it below the rooted closing floor.
  for cut in cuts.size():cuts[cut][0]=maxf(cuts[cut][0],.08*(cut+1))
  var points:=PackedVector3Array([Vector3(x,height,-.5),Vector3(x,crest,-.5)])
  var bands:Array=[[0,1,false]]
  var previous_y:=crest
  for cut in range(cuts.size()-1,-1,-1):
   var top:float=minf(cuts[cut][0],previous_y)
   var cut_drop:=0.0
   var band_start:=points.size()-1
   var samples:=_height_samples(previous_y,top)
   for y:float in samples:
    var depth:float=_surface_depth(u,y,core,crest,boulder,salt,fractures,masses,cuts,cut+1,detail_cache)
    points.append(Vector3(x,y,_attach(depth,u,y,fade)))
   bands.append([band_start,points.size()-1,false])
   band_start=points.size()-1
   var depth:float=_surface_depth(u,top-cut_drop,core,crest,boulder,salt,fractures,masses,cuts,cut,detail_cache)
   var front:=_attach(depth,u,top-cut_drop,fade)
   var outward:=maxf(0.0,front-points[-1].z)
   var available:float=top-float(cuts[cut-1][0]) if cut>0 else top
   # Keep the measured front depth: re-sampling it at the lowered lip makes
   # adjacent strips disagree on their tread slope and fragments grass support.
   cut_drop=maxf(cut_drop,minf(outward*cuts[cut][3],maxf(0.0,available)*.45))
   # The tread is a curved surface, not one planar strip from root to lip.
   # A monotone eased descent keeps both edges and the lower bearing fixed.
   # The selected broad terrace family carries curves across its treads.
   var inner:Vector3=points[-1]
   var curvature:=1.0 if cuts[cut][3]>0.0 else 0.0
   var tread_samples:Array=[.5,1.0] if curvature>0.0 else [1.0]
   for t:float in tread_samples:
    var bend:=t*t if cuts[cut][3]>.18 else t*(2.0-t)
    var descent:=lerpf(t,bend,curvature)
    points.append(Vector3(x,top-cut_drop*descent,lerpf(inner.z,front,t)))
   bands.append([band_start,points.size()-1,true])
   previous_y=top-cut_drop
  var foot_depth:=_attach(_surface_depth(u,0,core,crest,boulder,salt,fractures,masses,cuts,0,detail_cache),u,0,fade)
  var floor_y:=-.20
  if region!=null:
   var total_foot:=foot_depth+_basal_depth(0.0,height,basal)*fade
   for z:float in [0.0,total_foot*.5,total_foot]:
    var foot:Vector3=pose*Vector3(x,0,z)
    floor_y=minf(floor_y,TerrainSurfaceField.surface_y(region,foot.x,foot.z)-pose.origin.y-.2)
  var band_start:=points.size()-1
  for y:float in _height_samples(previous_y,floor_y):
   var depth:float=_surface_depth(u,y,core,crest,boulder,salt,fractures,masses,cuts,0,detail_cache)
   points.append(Vector3(x,y,_attach(depth,u,y,fade)))
  bands.append([band_start,points.size()-1,false])
  # A shallow independent face covers the periodic backing away from actual
  # joins. Its large shaped sections and creases share one geological field.
  var root_reach:=maxf(0.0,points[-1].z)
  for i in range(2,points.size()):
   points[i]=points[i].snapped(Vector3.ONE*.0001)
   var p:Vector3=points[i]
   var native:=_native_depth(coordinate+p.x,p.y)
   var drop:=height-p.y
   var collar:=smoothstep(1.05,minf(3.0,height*.7),drop)
   var geology:=_stone_relief(coordinate+p.x,p.y,salt,detail_cache)
   var covering:=lerpf(native+.035,1.09+.5*geology,collar)
   covering=lerpf(-.5,covering,fade)
   var excess:=points[i].z-covering
   # The smooth union adds no ridge when the incoming body has no depth.
   var radius:=.20*collar*fade
   var blend:=maxf(0.0,radius-absf(excess))/radius if radius>0.0 else 0.0
   points[i].z=maxf(points[i].z,covering)+blend*blend*radius*.25
   var descent:=clampf((drop-1.05)/maxf(1.0,height-1.05),0.0,1.0)
   var limit:=covering+maxf(0.0,root_reach-covering)*descent
   var over:=points[i].z-limit
   if over>-.12:
    points[i].z-=pow(maxf(0.0,over+.12),2.0)/.48 if over<.12 else over
   # Lower embedded rock widens independently of the upper face envelope.
   # Both edges of each curved tread receive the same continuous displacement.
   points[i].z+=_basal_depth(p.y,height,basal)*fade
  columns.append(points);column_bands.append(bands)
 # Join each continuous face band by elevation, not its sampling-row index.
 # Neighboring ledges can have different heights; index pairing shears dense
 # samples into long diagonal triangles and creates a visible sawtooth pattern.
 var tread_edges:Dictionary={}
 for ix in columns.size():
  for band:Array in column_bands[ix]:
   if not band[2]:continue
   for i in range(band[0],band[1]):
    var a:Vector3=columns[ix][i].snapped(Vector3.ONE*.0001);var b:Vector3=columns[ix][i+1].snapped(Vector3.ONE*.0001)
    if absf(a.z-b.z)>.0001:tread_edges[[a,b] if a<b else [b,a]]=true
 for ix in steps:
  var joins:=_matched_bands(columns[ix],columns[ix+1],column_bands[ix],column_bands[ix+1])
  for join:Array in joins:
   var band:Array=join[0];var next_band:Array=join[1]
   var left:int=band[0];var right:int=next_band[0];var last_left:int=band[1];var last_right:int=next_band[1]
   # Broad treads seed connected turf. Their shallow pointed ends and joins
   # retain the same material even when the local width falls below the seed
   # threshold; isolated hairline shoulders still remain stone.
   var usable_turf:bool=band[2] and absf(columns[ix][last_left].z-columns[ix][left].z)>=.55 and absf(columns[ix+1][last_right].z-columns[ix+1][right].z)>=.55
   while left<last_left or right<last_right:
    var tri:Array
    # Curved caps stitch by distance across the tread. Elevation ordering is
    # only appropriate for risers: along-wall slope can otherwise fan a cap
    # across several depth intervals and destroy its intended cross-section.
    var advance_left:=false
    if left<last_left and right<last_right:
     advance_left=float(left+1-band[0])/(last_left-band[0])<=float(right+1-next_band[0])/(last_right-next_band[0]) if band[2] else columns[ix][left+1].y>=columns[ix+1][right+1].y
    if not band[2] and left<last_left and right<last_right and absf(columns[ix][left].y-columns[ix+1][right].y)<.0001 and absf(columns[ix][left+1].y-columns[ix+1][right+1].y)<.0001:
     # Follow the local shoulder rather than imposing one diagonal across every
     # sample square. Both choices share a boundary; render and collision use
     # the same resulting triangles.
     var la:Vector3=columns[ix][left];var ra:Vector3=columns[ix+1][right]
     var lb:Vector3=columns[ix][left+1];var rb:Vector3=columns[ix+1][right+1]
     var n0:Vector3=(lb-la).cross(ra-la).normalized()
     var n1:Vector3=(rb-lb).cross(ra-lb).normalized()
     var n2:Vector3=(rb-la).cross(ra-la).normalized()
     var n3:Vector3=(lb-la).cross(rb-la).normalized()
     advance_left=n0.dot(n1)>=n2.dot(n3)
    if right==last_right or advance_left:
     tri=[columns[ix][left],columns[ix+1][right],columns[ix][left+1]]
     left+=1
    else:
     tri=[columns[ix][left],columns[ix+1][right],columns[ix+1][right+1]]
     right+=1
    for vertex in 3:tri[vertex]=tri[vertex].snapped(Vector3.ONE*.0001)
    _triangle(faces,tri[0],tri[1],tri[2])
    var normal:Vector3=(tri[2]-tri[0]).cross(tri[1]-tri[0]).normalized()
    var is_tread:bool=band[2]
    for edge in 3:
     var a:Vector3=tri[edge];var b:Vector3=tri[(edge+1)%3]
     if tread_edges.has([a,b] if a<b else [b,a]):is_tread=true
    if is_tread and normal.y>.80 and minf(tri[0].z,minf(tri[1].z,tri[2].z))>.4:
     _triangle(green,tri[0],tri[1],tri[2])
     if usable_turf:broad_turf[tri]=true
 green=_turf_without_dashes(green,width,left_end,right_end,broad_turf,true)
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
  # Triangulate the whole side polygon. Projecting a flat tread edge onto
  # the back at the same height creates a zero-area side triangle.
  var outline:=PackedVector2Array()
  for point:Vector3 in columns[ix]:
   var p:=Vector2(point.z,point.y).snapped(Vector2.ONE*.0001)
   if outline.is_empty() or outline[-1]!=p:outline.append(p)
  for row in range(columns[ix].size()-1,-1,-1):
   var p:=Vector2(-1.2,columns[ix][row].y).snapped(Vector2.ONE*.0001)
   if outline[-1]!=p:outline.append(p)
  var indices:=Geometry2D.triangulate_polygon(outline)
  assert(not indices.is_empty())
  for i in range(0,indices.size(),3):
   var tri:Array[Vector3]=[]
   for j in 3:
    var point:Vector2=outline[indices[i+j]]
    tri.append(Vector3(columns[ix][0].x,point.y,point.x))
   var outward:Vector3=Vector3.LEFT if ix==0 else Vector3.RIGHT
   if (tri[2]-tri[0]).cross(tri[1]-tri[0]).dot(outward)>0:_triangle(faces,tri[0],tri[1],tri[2])
   else:_triangle(faces,tri[0],tri[2],tri[1])
 var bounds:=AABB(faces[0],Vector3.ZERO)
 for p:Vector3 in faces:bounds=bounds.expand(p)
 return [{"faces":faces,"green":green,"bounds":pose*bounds,"transform":pose,"anchor":pose.origin,
  "id":"worn_crag/%s/%s"%[pose.origin,pose.basis.z],"asset":&"cliff.native_crag","kind":"rock","native_crag":true,"top":(pose*bounds).end.y,"base":(pose*bounds).position.y}]

static func _matched_bands(left:PackedVector3Array,right:PackedVector3Array,left_bands:Array,right_bands:Array)->Array:
 # Sampling-only cuts have no tread. They must not determine correspondence:
 # a merged ledge can move across several empty cut slots between columns.
 var a:Array=[];var b:Array=[]
 for band:Array in left_bands:
  if band[2] and left[band[1]].z-left[band[0]].z>.0001:a.append(band)
 for band:Array in right_bands:
  if band[2] and right[band[1]].z-right[band[0]].z>.0001:b.append(band)
 var result:Array=[];var i:=0;var j:=0;var from_left:=0;var from_right:=0
 while i<a.size() and j<b.size():
  var delta:float=left[a[i][0]].y-right[b[j][0]].y
  if absf(delta)<.75:
   result.append([[from_left,a[i][0],false],[from_right,b[j][0],false]])
   result.append([a[i],b[j]])
   from_left=a[i][1];from_right=b[j][1];i+=1;j+=1
  elif delta>0:i+=1
  else:j+=1
 result.append([[from_left,left.size()-1,false],[from_right,right.size()-1,false]])
 return result

static func _merge_close_ledges(cuts:Array)->void:
 # Two overlapping shelves close in height are one broad ledge, not a pair
 # of thin channels. Transfer support continuously and preserve total depth.
 for i in range(cuts.size()-2,-1,-1):
  if cuts[i][1]<=0.0:continue
  for j in range(i+1,cuts.size()):
   var gap:float=cuts[j][0]-cuts[i][0]
   if gap>=1.4:break
   if cuts[j][1]<=.000001:continue
   var weight:float=1.0-smoothstep(.7,1.4,gap)
   var transfer:float=cuts[i][1]*weight
   if transfer>0.0:
    for property in [0,2,3]:
     cuts[j][property]=(cuts[j][property]*cuts[j][1]+cuts[i][property]*transfer)/(cuts[j][1]+transfer)
   cuts[j][1]+=transfer;cuts[i][1]-=transfer
   break

static func _turf_without_dashes(green:PackedVector3Array,width:float,left_end:bool,right_end:bool,broad_seeds:Dictionary={},require_broad:bool=false)->PackedVector3Array:
 # Measure connected native triangles, rather than their convex hull. Tiny
 # isolated scraps read as paint on a wall. Open ownership cuts can divide a
 # larger patch, so keep those pieces until their neighboring owner continues it.
 var parents:Array[int]=[];var edges:Dictionary={}
 for i in green.size()/3:parents.append(i)
 for i in parents.size():
  for j in 3:
   var a:Vector3=green[i*3+j];var b:Vector3=green[i*3+(j+1)%3]
   var key:Array=[a,b] if a<b else [b,a]
   if edges.has(key):parents[_turf_root(parents,i)]=_turf_root(parents,edges[key])
   else:edges[key]=i
 var areas:Dictionary={};var shared:Dictionary={};var broad:Dictionary={}
 for i in parents.size():
  var root:=_turf_root(parents,i)
  var a:Vector3=green[i*3];var b:Vector3=green[i*3+1];var c:Vector3=green[i*3+2]
  areas[root]=areas.get(root,0.0)+(c-a).cross(b-a).length()*.5
  if broad_seeds.has([a,b,c]):broad[root]=true
  for point:Vector3 in [a,b,c]:
   if (not left_end and absf(point.x+width*.5)<.001) or (not right_end and absf(point.x-width*.5)<.001):shared[root]=true
 var result:=PackedVector3Array()
 for i in parents.size():
  var root:=_turf_root(parents,i)
  if areas[root]<.35 and not shared.has(root):continue
  if require_broad and not broad.has(root) and not shared.has(root):continue
  for j in 3:result.append(green[i*3+j])
 return result

static func _turf_root(parents:Array[int],i:int)->int:
 while parents[i]!=i:
  parents[i]=parents[parents[i]]
  i=parents[i]
 return i

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

static func _surface_depth(u:float,y:float,core:float,crest:float,boulder:float,salt:int,fractures:Array,masses:Array,cuts:Array,first:int,detail_cache:Dictionary={})->float:
 var shoulder:=_shoulders(y,cuts,first)
 # Preserve the carved cap at each sampling-band boundary. Introduce the
 # extra shoulder relief below it, where it cannot narrow the usable shelf.
 var cap_distance:=INF
 for cut:Array in cuts:cap_distance=minf(cap_distance,absf(y-float(cut[0])))
 var detail_shoulder:=shoulder*smoothstep(.01,.45,cap_distance)
 detail_cache["ledge_wear"]=1.0-smoothstep(.4,1.8,cap_distance)
 var depth:=_body_depth(u,y,core,crest,boulder,salt,fractures,masses,detail_shoulder,detail_cache)+shoulder
 # The same broad stone sections shape exposed masses as well as the thin
 # backing skin. Keep tread interiors clear of perpendicular relief channels.
 depth+=1.35*_stone_relief(u,y,salt,detail_cache)*smoothstep(.05,.65,cap_distance)
 # Upper projections return to their actual native backing below the turf lip.
 # Continuous changes in exposure leave recessed intervals between buttresses.
 depth=1.15+(depth-1.15)*(.75+.25*smoothstep(.2,.8,_noise(u/12.0+y/17.0,salt+1201)))
 var crown_weight:=smoothstep(.45,.75,crest-y)
 return lerpf(-.5,depth,crown_weight)

static func _body_depth(u:float,y:float,core:float,crest:float,boulder:float,salt:int,fractures:Array,masses:Array,shoulder:float=0.0,detail_cache:Dictionary={})->float:
 if y>=crest:return -.5
 var t:=clampf(1.0-y/crest,0.0,1.0)
 var broad:float=-.5+(core+.5)*t
 broad+=1.35*smoothstep(24.0,64.0,crest)*t*t
 var lower:float=boulder*(1.0-smoothstep(.06,.48,maxf(0,y)/crest))
 var mass_depth:=0.0
 var seam:=0.0
 for mass:Array in masses:
  if mass.size()==5:
   var fraction:=clampf((y-mass[0])/mass[1],0.0,1.0)
   var ny:=fraction*32.0
   var row:=mini(31,floori(ny))
   var column:PackedFloat32Array=mass[4]
   var native_shape:float=lerpf(column[row],column[row+1],ny-row)*mass[3]*smoothstep(1.0,.78,fraction)
   # The blend radius must vanish with the incoming shape. A fixed radius
   # adds a raised ridge even when an admitted profile has zero depth.
   var radius:=minf(.45,2.0*minf(mass_depth,native_shape))
   var blend:=maxf(radius-absf(mass_depth-native_shape),0.0)/radius if radius>0.0 else 0.0
   seam=maxf(seam,blend*smoothstep(.15,.6,minf(mass_depth,native_shape)))
   mass_depth=maxf(mass_depth,native_shape)+blend*blend*radius*.25
   continue
  # A shoulder keeps its full bearing beneath its widest point.
  var dy:float=maxf(0.0,(y-mass[0])/mass[1])
  var descent:=clampf((mass[0]-y)/maxf(1.0,mass[0]),0.0,1.0)
  var drift:float=MASS_LATERAL_DRIFT*sin((y-mass[0])/4.1+mass[0]*1.3)
  var side:float=absf(mass[4]-drift/mass[5])/(1.0+MASS_FOOT_WIDENING*descent)
  # A rounded asymmetric shoulder, not a max-norm box with a flat front.
  # Broad lower support remains; finite ledge cuts still create sharp treads.
  side*=1.0+MASS_SIDE_VARIATION*(_noise(y/3.7+u/11.0,mass[6])-.5)
  var distance:float=pow(pow(side,2.3)+pow(absf(dy),2.3),1.0/2.3)
  var bevel:float=smoothstep(0.0,.82,1.0-distance)
  mass_depth=maxf(mass_depth,mass[3]*bevel*(1.0+.10*dy+ .20*pow(clampf((mass[0]-y)/maxf(1.0,mass[0]),0.0,1.0),1.3)))
 var q:=Vector2(u*.91+y*.41,-u*.41+y*.91)
 # Larger shallow divisions follow actual shelf risers and blended mass
 # junctions. Uninterrupted broad faces do not receive randomly placed patches.
 var wear:=maxf(seam,float(detail_cache.get("ledge_wear",0.0))*.8)
 var detail:=_rock_planes(q/5.0,salt,detail_cache)*.38*wear
 var envelope:=pow(t,1.15)
 var structure:=broad+lower+mass_depth*envelope
 # The complete rock includes the support below a ledge. Decide exposure
 # after that support is present; otherwise thick shoulders lose their crags
 # merely because the underlying body would have been a thin attachment.
 var detail_weight:=smoothstep(.25,1.7,_projection(structure+shoulder)-_native_depth(u,y))
 var change:float=detail*envelope*detail_weight
 # Retain the exposed native attachment beneath an eroded outer face. A soft
 # depth budget avoids both re-entering the wall and a flat clamp at its surface.
 var budget:float=maxf(0.0,structure-.62/.80)
 if budget>0.0 and change<-.65*budget:
  var remainder:=.35*budget
  change=-.65*budget-remainder*(1.0-exp((change+.65*budget)/remainder))
 return structure+change

# Read the native rock's widening horizontal sections into connected ledge
# supports. Actual caps still use the cliff's common surface/collision builder.
static func _nature_terraces(u:float,height:float,crest:float,salt:int)->Array:
 var result:Array=[]
 var cell:=floori(u/26.0)
 var key:=Vector3(cell,0,9)
 var selected:=Helper.position_hash01(key,salt+1009)>=.42
 var center:float=(cell+.5)*26.0+lerpf(-2.0,2.0,Helper.position_hash01(key,salt+1013))
 var width:=lerpf(13.0,20.0,Helper.position_hash01(key,salt+1019))
 var rise:=minf(12.0,height*lerpf(.50,.83,Helper.position_hash01(key,salt+1021)))
 var index:=mini(7,int(Helper.position_hash01(key,salt+1031)*8.0))
 for tier in 3:
  var section:float=[.22,.48,.72][tier]
  var nx:float=(u-center)/(width*(1.0-.13*tier))+.5
  var sample:=0.0
  if selected and nx>0 and nx<1:
   var field:PackedFloat32Array=_nature_fields[index][tier]
   var px:=nx*96
   var ix:=mini(95,floori(px))
   sample=maxf(0,lerpf(field[ix],field[ix+1],px-ix))
   sample*=smoothstep(0.0,.16,nx)*smoothstep(1.0,.84,nx)
  var elevation:=section+lerpf(-.065,.065,Helper.position_hash01(Vector3(cell,tier,0),salt+1051))
  var tilt:=lerpf(-.23,.23,Helper.position_hash01(Vector3(cell,tier,0),salt+1049))
  var bend:=lerpf(.35,.9,Helper.position_hash01(Vector3(cell,tier,0),salt+1061))
  var phase:=Helper.position_hash01(Vector3(cell,tier,0),salt+1063)*TAU
  var top:=rise*elevation+tilt*(u-center)+bend*sin((u-center)/4.3+phase)
  top+=.25*sin((u-center)/2.6+phase*1.7)
  top=minf(top,crest-.15)
  if tier==2 and Helper.position_hash01(key,salt+1057)<.28:sample=0.0
  var strength:=sample*lerpf(2.8,4.2,Helper.position_hash01(Vector3(cell,tier,0),salt+1039))*(1.0-.12*tier)
  result.append([top,strength,2.0,_tread_grade(Helper.position_hash01(Vector3(cell,tier,0),salt+1069))])
 return result

static func _nature_mass_profile(u:float,height:float,salt:int)->Array:
 var result:Array=[]
 # Overlapping authored fronts own widening lower footprints; a shallower
 # background body carries relief through the gaps and taller native crowns.
 for cell in range(floori(u/8.0)-2,floori(u/8.0)+3):
  var key:=Vector3(cell,3,17)
  if Helper.position_hash01(key,salt+1103)<.22:continue
  var center:float=(cell+.5)*8.0+lerpf(-2.5,2.5,Helper.position_hash01(key,salt+1109))
  var width:=lerpf(7.0,12.0,Helper.position_hash01(key,salt+1117))
  if absf(u-center)>=width*.72:continue
  var index:=mini(7,int(Helper.position_hash01(key,salt+1123)*8.0))
  var column:=PackedFloat32Array();column.resize(33)
  var bearing:=0.0
  for row in range(32,-1,-1):
   var t:=float(row)/32.0
   var nx:float=(u-center)/(width*lerpf(1.42,.82,t))+.5
   var depth:=0.0
   if nx>0.0 and nx<1.0:
    var px:=nx*48.0;var ix:=mini(47,floori(px))
    var samples:PackedFloat32Array=_nature_bodies[index][row]
    depth=maxf(0.0,(lerpf(samples[ix],samples[ix+1],px-ix)-.22)/.78)
    depth*=smoothstep(0.0,.18,nx)*smoothstep(1.0,.82,nx)
   bearing=maxf(bearing,depth)
   column[row]=maxf(depth,bearing-.10)
  var rise:=height*lerpf(.80,1.25,Helper.position_hash01(key,salt+1129))
  result.append([0.0,rise,0.0,lerpf(2.6,4.0,Helper.position_hash01(key,salt+1151))*(1.0+.45*smoothstep(16.0,64.0,height)),column])
 return result

static func _ledge_plane(u:float,slot:int,cut:int,phase:float,height:float,salt:int)->float:
 var key:=Vector3(slot,cut,0)
 var center:float=(slot+.5)*32.0-phase
 var tilt:=lerpf(-.25,.25,Helper.position_hash01(key,salt+227))
 var bend:=lerpf(.4,1.1,Helper.position_hash01(key,salt+229))*clampf(height/12.0,.25,1.0)
 var wavelength:=lerpf(3.5,7.0,Helper.position_hash01(key,salt+233))
 var curve_phase:=Helper.position_hash01(key,salt+239)*TAU
 return height*lerpf(.05 if cut>=6 else .09,.27 if cut>=6 else .87,Helper.position_hash01(key,salt+219))+tilt*(u-center)+bend*sin((u-center)/wavelength+curve_phase)

static func _shoulders(y:float,cuts:Array,first:int)->float:
 # Finite ledge spans have supporting stone below them, rather than pinched
 # mushroom undersides. Their combined foot projection remains bounded.
 var depth:=0.0
 for i in range(first,cuts.size()):
  var drop:float=maxf(0,cuts[i][0]-y)
  depth+=cuts[i][1]*(.8+.2*smoothstep(0.0,cuts[i][2],drop))
 return depth

static func _mass_profile(u:float,height:float,salt:int)->Array:
 # Embedded, rounded block faces are distributed in two dimensions. Independent
 # centers/sizes break both vertical courses and repeated hemispherical pods.
 var result:Array=[]
 var scale:=smoothstep(16.0,64.0,height)
 # Discovery includes the complete widening foot, not just the upper radius.
 # At maximum tall scale this reaches 10.95 m and needs three neighboring cells.
 var search_cells:=ceili(_mass_support_reach(3.6*1.35*(1.0+.42*scale))/5.0)
 for cell in range(floori(u/5.0)-search_cells,floori(u/5.0)+search_cells+1):
  for layer in ceili(height/4.0):
   var key:=Vector3(cell,layer,0)
   if Helper.position_hash01(key,salt+701)<.24:continue
   var center:float=(cell+Helper.position_hash01(key,salt+703))*5.0
   var cy:float=(layer+Helper.position_hash01(key,salt+709))*4.0
   var lower:=1.0-clampf(cy/height,0.0,1.0)
   var rx:=lerpf(1.2,3.6,pow(Helper.position_hash01(key,salt+719),1.7))*(1.0+.35*lower)
   var ry:=lerpf(1.1,3.5,Helper.position_hash01(key,salt+727))
   # Larger upright formations are occasional, interleaved with the small faces.
   var large:=smoothstep(.68,.94,Helper.position_hash01(key,salt+743))
   ry*=1.0+large*1.7*scale
   rx*=1.0+large*.42*scale
   var dx:=absf(u-center)/rx
   var support_reach:=_mass_support_reach(rx)
   if absf(u-center)>=support_reach:continue
   # The cross-section belongs to the mass, not the rounded height of its
   # sloping crest at each query. Rounding that moving height changed the
   # noise seed abruptly along a single rock and produced vertical cuts.
   var shape_seed:=salt+roundi(cy)*17+1223
   cy+=lerpf(-.25,.25,Helper.position_hash01(key,salt+733))*(u-center)
   var depth:=lerpf(1.0,3.3,Helper.position_hash01(key,salt+739))*(.8+.90*lower)*clampf(height/16.0,.25,1.0)
   # Broad exposure varies along the wall: smaller crags remain in recesses
   # between the occasional larger buttresses, not a uniform thick facade.
   depth*=lerpf(1.0,lerpf(.45,1.0,smoothstep(.25,.75,_noise(u/13.0,salt+751))),scale)
   result.append([cy,ry,dx,depth,(u-center)/rx,rx,shape_seed])
 return result

static func _mass_support_reach(radius:float)->float:
 return radius*(1.0+MASS_FOOT_WIDENING)/(1.0-MASS_SIDE_VARIATION*.5)+MASS_LATERAL_DRIFT

static func _fracture_profile(u:float,height:float,salt:int)->Array:
 # On tall faces, separate fracture clusters leave larger coherent formations.
 # Short walls retain their scale. Sparse cuts leave broad quiet faces.
 # All centers remain world-coordinate owned.
 var result:Array=[]
 var scale:=smoothstep(16.0,64.0,height)
 for cell in range(floori(u/6.0)-1,floori(u/6.0)+2):
  var key:=Vector3(cell,0,0)
  var center:float=(cell+Helper.position_hash01(key,salt+601))*6.0
  var half_span:=lerpf(4.2,5.2,Helper.position_hash01(key,salt+607))
  var joints:Array=[]
  var count:=maxi(3,ceili(height/3.8))
  var interval:=height/count
  for joint in count:
   var joint_key:=Vector3(cell,joint,0)
   if Helper.position_hash01(joint_key,salt+677)<.45:continue
   var level:float=lerpf(interval*(joint+lerpf(.20,.80,Helper.position_hash01(joint_key,salt+613))),height*Helper.position_hash01(joint_key,salt+613),scale)
   level+=lerpf(lerpf(-.22,.22,Helper.position_hash01(joint_key,salt+619)),lerpf(-.48,.48,Helper.position_hash01(joint_key,salt+619)),scale)*(u-center)
   level+=.12*(_noise(u/1.8,salt+joint*31+617)-.5)
   var span:=lerpf(half_span*lerpf(.85,1.15,Helper.position_hash01(joint_key,salt+623)),lerpf(1.1,4.6,Helper.position_hash01(joint_key,salt+623)),scale)
   var joint_center:float=(cell+Helper.position_hash01(joint_key,salt+627))*6.0
   var weight:=smoothstep(span,span*.55,absf(u-joint_center))*lerpf(1.0,lerpf(.55,1.0,Helper.position_hash01(joint_key,salt+631)),scale)
   joints.append([level,weight,lerpf(.45,.75,Helper.position_hash01(joint_key,salt+629))])
  # Short oblique chips interrupt the larger fracture faces at independent
  # heights and lengths. They stay recessed in the same connected stone skin.
  for chip in ceili(height/2.1):
   var chip_key:=Vector3(cell,chip,1)
   if Helper.position_hash01(chip_key,salt+683)<.65:continue
   var chip_center:float=(cell+Helper.position_hash01(chip_key,salt+643))*6.0
   var chip_span:=lerpf(.65,1.8,Helper.position_hash01(chip_key,salt+647))
   var chip_level:float=(chip+Helper.position_hash01(chip_key,salt+653))*2.1
   chip_level+=lerpf(-.65,.65,Helper.position_hash01(chip_key,salt+659))*(u-chip_center)
   var chip_weight:=smoothstep(chip_span,chip_span*.55,absf(u-chip_center))
   chip_weight*=lerpf(.30,.60,Helper.position_hash01(chip_key,salt+661))
   joints.append([chip_level,chip_weight,lerpf(.20,.36,Helper.position_hash01(chip_key,salt+673))])
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
   var arrays:=st.commit_to_arrays()
   var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var normals:=_connected_normals(points)
   var colors:=PackedColorArray()
   var coordinate:float=rock.transform.origin.dot(rock.transform.basis.x)
   for i in points.size():
    var p:Vector3=points[i];var u:float=coordinate+p.x
    var thickness:=p.z-_native_depth(u,p.y)
    var independent:=smoothstep(.015,.18,thickness)
    if rock.has("native_roots"):
     var root:Array=rock.native_roots[p]
     independent=root[1]
     normals[i]=root[0].lerp(normals[i],independent).normalized()
    elif p.z>-.4:normals[i]=_native_normal(u,p.y).lerp(normals[i],independent).normalized()
    colors.append(Color(1,1,1,independent))
   arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors
   result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  else:st.commit(result)
  if grass:result.surface_set_material(1,CliffDressing.shared_material())
  else:
   var material:=ShaderMaterial.new();material.shader=load("res://terrain/materials/cliff_crag.gdshader")
   result.surface_set_material(0,material)
 return result

static func _connected_normals(points:PackedVector3Array)->PackedVector3Array:
 # Every connected smooth fan has one normal at its shared vertex. Per-face
 # weighting of the same incident normals creates differing corner normals and
 # exposes the triangulation even where the geometric surface is continuous.
 var incident:Dictionary={}
 var weighted:=PackedVector3Array()
 for i in range(0,points.size(),3):
  weighted.append((points[i+2]-points[i]).cross(points[i+1]-points[i]))
  for j in 3:
   if not incident.has(points[i+j]):incident[points[i+j]]=[]
   incident[points[i+j]].append(i)
 var result:=PackedVector3Array();result.resize(points.size())
 for point:Vector3 in incident:
  var faces:Array=incident[point]
  var parent:Array[int]=[];var edge_faces:Dictionary={}
  for index in faces.size():
   parent.append(index)
   var start:int=faces[index]
   for j in 3:
    var other:Vector3=points[start+j]
    if other==point:continue
    if not edge_faces.has(other):edge_faces[other]=[]
    edge_faces[other].append(index)
  for neighbors:Array in edge_faces.values():
   for a in neighbors.size():
    for b in range(a+1,neighbors.size()):
     var left:int=neighbors[a];var right:int=neighbors[b]
     if weighted[faces[left]/3].normalized().dot(weighted[faces[right]/3].normalized())<cos(deg_to_rad(50)):continue
     while parent[left]!=left:left=parent[left]
     while parent[right]!=right:right=parent[right]
     parent[right]=left
  var sums:Dictionary={}
  for index in faces.size():
   var root:=index
   while parent[root]!=root:root=parent[root]
   parent[index]=root
   sums[root]=sums.get(root,Vector3.ZERO)+weighted[faces[index]/3]
  for index in faces.size():
   var normal:Vector3=(sums[parent[index]] as Vector3).normalized()
   for j in 3:
    if points[faces[index]+j]==point:result[faces[index]+j]=normal
 return result

static func _tread_grade(choice:float)->float:
 # Broad resting shelves coexist with shallow outward slopes. One grade per
 # finite shelf preserves coherent support while its path bends along the wall.
 return 0.0 if choice<.45 else lerpf(.10,.25,(choice-.45)/.55)

static func _rock_planes(p:Vector2,salt:int,detail_cache:Dictionary={})->float:
 var cell:=p.floor();var nearest:=Vector2.ZERO;var distance:=INF
 # This cache belongs to one make() call, never shared between workers.
 # Store only seed positions: cached and uncached evaluation remain identical.
 var cache_key:=Vector3i(int(cell.x),int(cell.y),salt)
 if not detail_cache.has(cache_key):
  var entries:Array[Vector2]=[]
  for iy in range(-1,2):
   for ix in range(-1,2):
    var key:=Vector3(cell.x+ix,cell.y+iy,0)
    entries.append(Vector2(key.x,key.y)+Vector2(.12+.76*Helper.position_hash01(key,salt+2101),.12+.76*Helper.position_hash01(key,salt+2107)))
  detail_cache[cache_key]=entries
 var seeds:Array[Vector2]=detail_cache[cache_key]
 for seed:Vector2 in seeds:
  var d:=p.distance_squared_to(seed)
  if d<distance:distance=d;nearest=seed
 var edge:=INF
 for seed:Vector2 in seeds:
  if seed==nearest:continue
  edge=minf(edge,((seed+nearest)*.5-p).dot((seed-nearest).normalized()))
 # A broad chipped plane with a short bevel; the value is continuous at
 # cell boundaries and blends back to native relief at thin attachments.
 return smoothstep(.015,.16,edge)*(.32+.35*edge)-.22

static func _face_noise(p:Vector2,salt:int)->float:
 var row:=floori(p.y)
 return lerpf(_noise(p.x,salt+row*37),_noise(p.x,salt+(row+1)*37),smoothstep(0.0,1.0,p.y-row))-.5


static func _long_terraces(u:float,height:float,crest:float,salt:int)->Array:
 var result:Array=[]
 var layers:=maxi(1,ceili(height/24.0))
 for cell in range(floori(u/46.0)-1,floori(u/46.0)+2):
  for layer in layers:
   var key:=Vector3(cell,layer,47)
   if Helper.position_hash01(key,salt+3411)<.30:continue
   var center:float=(cell+.15+.70*Helper.position_hash01(key,salt+3413))*46.0
   var half_width:=lerpf(10.0,23.0,Helper.position_hash01(key,salt+3419))
   var dx:=u-center
   if absf(dx)>=half_width:continue
   var band_height:=height/float(layers)
   var top:float=(layer+.18+.62*Helper.position_hash01(key,salt+3421))*band_height
   top+=lerpf(-.12,.12,Helper.position_hash01(key,salt+3427))*dx+.65*sin(dx/8.0+layer)
   var weight:=pow(maxf(0.0,1.0-pow(dx/half_width,2.0)),.85)
   var peak:=lerpf(2.0,3.4,Helper.position_hash01(key,salt+3433))*weight
   peak*=smoothstep(.6,2.0,height-top)*smoothstep(.5,1.5,top)
   if peak<=0:continue
   var thickness:=lerpf(2.0,6.0,Helper.position_hash01(key,salt+3437))
   result.append([minf(top,crest-.12),peak,thickness,_tread_grade(Helper.position_hash01(key,salt+3449))])
 return result

static func _stone_relief(u:float,y:float,salt:int,cache:Dictionary)->float:
 return _geology(u,y,salt,cache,true)+.45*_geology(u,y,salt,cache,false)

static func _geology(u:float,y:float,salt:int,cache:Dictionary,joint:bool)->float:
 # Shape and fracture share a gently warped, oblique geological partition.
 # Every joint is a boundary between the actual neighboring rock volumes.
 var p:=Vector2(u+.23*y,y-.14*u)
 p+=Vector2(1.3*(_noise(y/7.0+u/19.0,salt+2801)-.5),1.1*(_noise(u/8.0-y/23.0,salt+2807)-.5))
 var cell:=_stone_cell(p,7.3,salt+2811,cache)
 var edge:float=cell[0]
 var key:Vector3=cell[2]
 var amplitude:=lerpf(.45,.70,Helper.position_hash01(key,salt+2819))
 if joint:
  return -.10*(1.0-smoothstep(.03,.40,edge))
 return amplitude*(1.0-exp(-edge*.65))

static func _stone_cell(p:Vector2,spacing:float,salt:int,cache:Dictionary)->Array:
 var bucket:=Vector2i(floori(p.x/spacing),floori(p.y/spacing))
 var cache_key:=Vector3i(bucket.x,bucket.y,roundi(spacing*100.0))
 if not cache.has(cache_key):
  var sites:Array=[]
  for x in range(bucket.x-2,bucket.x+3):
   for y in range(bucket.y-2,bucket.y+3):
    var key:=Vector3(x,y,19)
    if Helper.position_hash01(key,salt+1811)<.18:continue
    var site:=Vector2((x+.08+.84*Helper.position_hash01(key,salt+1813))*spacing,(y+.08+.84*Helper.position_hash01(key,salt+1817))*spacing)
    sites.append([site,key])
  cache[cache_key]=sites
 var sites:Array=cache[cache_key]
 var nearest:=INF;var owner:=0
 for i in sites.size():
  var distance:=p.distance_squared_to(sites[i][0])
  if distance<nearest:nearest=distance;owner=i
 var center:Vector2=sites[owner][0];var edge:=INF
 for i in sites.size():
  if i==owner:continue
  var other:Vector2=sites[i][0]
  edge=minf(edge,((center+other)*.5-p).dot((other-center).normalized()))
 return [maxf(0,edge),center,sites[owner][1]]


# Finite authored rock bodies shape grounded ridges at ordinary cliff scale.
# Their footprint stays in world coordinates across ownership boundaries.
static func _basal_profile(u:float,height:float,salt:int)->Array:
 var result:Array=[]
 var cell_size:=18.0
 for cell in range(floori(u/cell_size)-1,floori(u/cell_size)+2):
  var key:=Vector3(cell,11,31)
  if Helper.position_hash01(key,salt+1801)<.32:continue
  var center:float=(cell+.5)*cell_size+lerpf(-4.0,4.0,Helper.position_hash01(key,salt+1807))
  var width:=lerpf(7.0,15.0,Helper.position_hash01(key,salt+1811))
  if absf(u-center)>width*.72:continue
  var index:=mini(7,int(Helper.position_hash01(key,salt+1817)*8.0))
  var rise:=minf(14.0,height*lerpf(.38,.62,Helper.position_hash01(key,salt+1823)))
  var column:=PackedFloat32Array();column.resize(33)
  var bearing:=0.0
  for row in range(32,-1,-1):
   var t:=float(row)/32.0
   var nx:float=(u-center)/(width*lerpf(1.42,.82,t))+.5
   var depth:=0.0
   if nx>0.0 and nx<1.0:
    var px:=nx*48.0;var ix:=mini(47,floori(px))
    var values:PackedFloat32Array=_nature_bodies[index][row]
    depth=maxf(0.0,(lerpf(values[ix],values[ix+1],px-ix)-.22)/.78)
    depth*=smoothstep(0.0,.18,nx)*smoothstep(1.0,.82,nx)
    depth*=pow(1.0-t,1.25)
   # Actual sampled rock sections keep their support below wider shoulders.
   bearing=maxf(bearing,depth)
   column[row]=bearing
  var reach:=lerpf(1.8,3.6,Helper.position_hash01(key,salt+1831))*clampf(height/8.0,.4,1.3)
  result.append([rise,reach,column])
 return result

static func _basal_depth(y:float,height:float,profiles:Array)->float:
 var depth:=0.0
 for profile:Array in profiles:
  var t:=clampf(y/profile[0],0.0,1.0)*32.0
  var row:=mini(31,floori(t))
  var column:PackedFloat32Array=profile[2]
  depth=maxf(depth,lerpf(column[row],column[row+1],t-row)*profile[1])
 return depth
