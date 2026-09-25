extends RefCounted
## Inner-corner terraces built from the native KayKit Nature kit (owner
## review, September 23). A grass-topped hill fills the pocket of a concave
## cliff corner at a storey band; native wall rows on its exposed faces let
## the ordinary rock pipeline dress it. Pieces reuse the cliff's shared
## palette material and biome tint.
const TILE:=24.0
## The interior grass tile: one flat 3 m grid module in the shared ground
## material (the KayKit Hill_Top_E_Center footprint), built on the main thread.
static var _tile:Array=[]

static func prepare()->void:
 if not _tile.is_empty():return
 assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
 var uv:=CliffDressing.ground_uv()
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-1.5,0,-1.5),Vector3(1.5,0,-1.5),Vector3(1.5,0,1.5),Vector3(-1.5,0,-1.5),Vector3(1.5,0,1.5),Vector3(-1.5,0,1.5)])
 arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP])
 arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([uv,uv,uv,uv,uv,uv])
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 _tile=[mesh,Transform3D.IDENTITY]

## Render pieces owned by one terrace: {name: Array[Transform3D]}. Names
## prefixed "native:" are CliffDressing modules.
static func pieces(terrace:Dictionary)->Dictionary:
 return {"tile":terrace.tiles,"native:wall":terrace.rows.wall,"native:outer_wall":terrace.rows.outer_wall,
  "native:lip":terrace.lips.lip,"native:outer_lip":terrace.lips.outer_lip}

## Walkable top and the two exposed faces at the native wall face line.
static func collision(terrace:Dictionary)->PackedVector3Array:
 var faces:=PackedVector3Array()
 var c:Vector3=terrace.corner;var ax:Vector3=terrace.ax;var az:Vector3=terrace.az
 var edge:=TERRACE-.4;var cap:float=terrace.cap+CliffDressing.LIP_LIFT;var low:float=terrace.low-.5
 var corners:=[[-.5,-.5],[-.5,edge],[edge,edge],[edge,-.5]]
 var at:=func(uv:Array,y:float)->Vector3:return c+ax*float(uv[0])+az*float(uv[1])+Vector3.UP*y
 for quad:Array in [[corners[0],cap,corners[1],cap,corners[2],cap,corners[3],cap],
   [corners[1],low,corners[2],low,corners[2],cap,corners[1],cap],
   [corners[3],low,corners[3],cap,corners[2],cap,corners[2],low]]:
  var a:Vector3=at.call(quad[0],quad[1]);var b:Vector3=at.call(quad[2],quad[3])
  var d:Vector3=at.call(quad[4],quad[5]);var e:Vector3=at.call(quad[6],quad[7])
  # Both windings: the shape must stop the player from either side.
  faces.append_array([a,b,d,a,d,e,a,d,b,a,e,d])
 return faces

static func footprint(terrace:Dictionary)->Rect2:
 return Rect2(terrace.center-Vector2.ONE*TERRACE*.5,Vector2.ONE*TERRACE)

## Inner-corner terraces (owner review, September 23). A KayKit hill fills
## the pocket corner so TERRACE metres (three 3 m grid squares) stand clear
## of both walls. Its turf is quantised to the cliff's storey bands: one or
## more whole storeys below the crest and at least one above the ground, so
## a single-storey corner gets none. Its two exposed faces receive native
## wall rows (a 6 m straight run each plus a convex corner), which the
## ordinary rock pipeline dresses like any other cliff.
const TERRACE:=9.0
## The terrace turf sits on one of the cliff's storey bands: whole storeys
## below the crest and at least one storey above the pocket ground. A
## single-storey corner (or an uneven pocket) gets NAN: no terrace.
static func terrace_cap(top:float,lowest:float,highest:float,roll:float)->float:
 var storeys:=floori((top-lowest+.5)/CliffDressing.STOREY)
 if storeys<2 or highest-lowest>1.2:return NAN
 var cap:=top-CliffDressing.STOREY*(1+floori(roll*(storeys-1)))
 return NAN if cap<highest+3.0 else cap
static func terraces(cliffs:Dictionary,region:HeightfieldRegion,seed_value:int,
  features:FeatureContext=null,water:WaterFieldContext=null)->Array[Dictionary]:
 var columns:=_columns(cliffs.inner_wall)
 var keys:=columns.keys();keys.sort()
 var result:Array[Dictionary]=[]
 for key:Vector3i in keys:
  var column:Dictionary=columns[key]
  var wall:Transform3D=column.transform
  var ax:=wall.basis.x;var az:=wall.basis.z
  var corner:=Vector3(wall.origin.x,0,wall.origin.z)+(ax+az)*MODULE*.5
  if _hash(corner,seed_value+8901)>.85:continue
  var lowest:=INF;var highest:=-INF
  for a:float in [.5,3.0,5.5,8.5]:
   for b:float in [.5,3.0,5.5,8.5]:
    var ground:=_ground(region,corner+ax*a+az*b)
    lowest=minf(lowest,ground);highest=maxf(highest,ground)
  var cap:=terrace_cap(column.top,lowest,highest,_hash(corner,seed_value+8911))
  if is_nan(cap):continue
  var center:=corner+(ax+az)*(TERRACE*.5)
  var probe:={"center":Vector2(center.x,center.z),"half":Vector2.ONE*TERRACE*.5,"yaw":0.0}
  if not _clear(probe,region,features,water):continue
  var blocked:=false
  for other:Dictionary in result:
   if (other.center as Vector2).distance_to(probe.center)<TERRACE:blocked=true;break
  if blocked:continue
  var rows:={"wall":[],"outer_wall":[]}
  var count:=ceili((cap-lowest-.01)/CliffDressing.STOREY)
  for k in count:
   var y:=cap-CliffDressing.STOREY*(k+1)
   for faces:Array in [[az,ax],[ax,az]]:
    var normal:Vector3=faces[0];var along:Vector3=faces[1]
    # m=-1 is buried in the higher neighbouring cliff: the face run then
    # continues through its visible junction instead of fading out there.
    for m in range(-1,2):
     var origin:=corner+normal*(TERRACE-1.5)+along*(1.5+3.0*m)
     rows.wall.append(Transform3D(Basis(Vector3.UP,atan2(normal.x,normal.z)),Vector3(origin.x,y,origin.z)))
   var post:=corner+(ax+az)*(TERRACE-1.5)
   rows.outer_wall.append(Transform3D(wall.basis,Vector3(post.x,y,post.z)))
  # The top is built like any natural cliff top on the 3 m grid: native lip
  # modules along the exposed edges, an outer lip on the convex corner, and
  # flat centre tiles inside, with one row reaching back to the cliff face.
  var lips:={"lip":[],"outer_lip":[]}
  var lift:=Vector3.UP*(cap+CliffDressing.LIP_LIFT)
  for wall_row:Transform3D in rows.wall.slice(0,6):
   var offset:=Vector3(wall_row.origin.x,0,wall_row.origin.z)-corner
   if minf(offset.dot(ax),offset.dot(az))<0.0:continue
   lips.lip.append(Transform3D(wall_row.basis,Vector3(wall_row.origin.x,0,wall_row.origin.z)+lift))
  var corner_row:Transform3D=rows.outer_wall[0]
  lips.outer_lip.append(Transform3D(corner_row.basis,Vector3(corner_row.origin.x,0,corner_row.origin.z)+lift))
  var tiles:Array=[]
  for i in range(-1,3):
   for j in range(-1,3):
    if (i==2 or j==2) and i>=0 and j>=0:continue
    var at:=corner+ax*(1.5+3.0*i)+az*(1.5+3.0*j)
    tiles.append(Transform3D(Basis(),Vector3(at.x,cap+CliffDressing.LIP_LIFT,at.z)))
  result.append({"center":probe.center,"owner":_owner(wall.origin),"cap":cap,"low":lowest,"corner":corner,"ax":ax,"az":az,
   "rows":rows,"lips":lips,"tiles":tiles})
 return result

const MODULE:=3.0

static func build(data:Dictionary,seed_value:int)->Node3D:
 prepare();CliffDressing._ensure_loaded()
 var root:=Node3D.new();root.name="CliffTerraces"
 var names_sorted:=data.keys();names_sorted.sort()
 for name:String in names_sorted:
  if (data[name] as Array).is_empty():continue
  var piece:Array=CliffDressing._pieces[name.trim_prefix("native:")] if name.begins_with("native:") else _tile
  root.add_child(CliffDressing._multimesh(piece,data[name],name.replace(":","_"),CliffDressing.compute_tints(data[name],seed_value)))
 return root

static func _columns(walls:Array)->Dictionary:
 var result:Dictionary={}
 for wall:Transform3D in walls:
  var key:=Vector3i(roundi(wall.origin.x*4),roundi(wall.origin.z*4),roundi(wall.basis.get_euler().y*100))
  if not result.has(key):result[key]={"transform":wall,"bottom":wall.origin.y,"top":wall.origin.y+CliffDressing.STOREY}
  result[key].bottom=minf(result[key].bottom,wall.origin.y)
  result[key].top=maxf(result[key].top,wall.origin.y+CliffDressing.STOREY)
 return result

static func _owner(point:Vector3)->Vector2i:
 return Vector2i(floori((point.x+12)/TILE),floori((point.z+12)/TILE))

static func _ground(region:HeightfieldRegion,point:Vector3)->float:
 return TerrainSurfaceField.surface_y(region,point.x,point.z)

static func _hash(point:Vector3,salt:int)->float:
 return Helper.position_hash01(point.snapped(Vector3.ONE*.01),salt)

static func _clear(p:Dictionary,region:HeightfieldRegion,features:FeatureContext,water:WaterFieldContext)->bool:
 var center:Vector2=p.get("clear_center",p.center);var half:Vector2=p.get("clear_half",p.half)
 if features!=null and features.overlaps_clearance(FeatureGroundShape.oriented_rect(center,half,float(p.yaw)),.3,false):return false
 if water!=null:
  for offset:Vector2 in [Vector2.ZERO,Vector2(half.x,half.y),Vector2(-half.x,half.y),Vector2(half.x,-half.y),Vector2(-half.x,-half.y)]:
   var point:=center+offset.rotated(-float(p.yaw))
   if water.covers(point) and water.is_wet(point):return false
 if region.has_method("has_grade_effect_in") and region.has_grade_effect_in(Rect2(center-half,half*2.0)):return false
 return true
