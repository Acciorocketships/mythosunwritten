extends RefCounted
## Geometry-only study. Reuses the closed cliff topology and exact turf triangles.
const BASE=preload("res://tests/fixtures/september18/cliff-formation-sampling/before.gd")
static var _rocks:Array=[]
static var _contours:Array=[]
static func prepare()->void:
 BASE.prepare()
 if not _rocks.is_empty():return
 assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/september18/cliff-volume-union/rotated_bare_contours.json"))
 for source:Dictionary in data.sources:
  var body:Array=[];var contour:Array=[]
  for row:Array in source.body:body.append(PackedFloat32Array(row))
  for row:Array in source.contour:contour.append(PackedFloat32Array(row))
  _rocks.append(body);_contours.append(contour)

static func mesh(rock:Dictionary)->ArrayMesh:return BASE.mesh(rock)

static func make(pose:Transform3D,width:float,height:float,seed_value:int,region:HeightfieldRegion=null,left_end:bool=false,right_end:bool=false)->Array[Dictionary]:
 prepare()
 var forms:=BASE.make(pose,width,height,seed_value,region,left_end,right_end)
 var coordinate:=pose.origin.dot(pose.basis.x)
 var salt:=seed_value+roundi(pose.origin.dot(pose.basis.z))*13+roundi(pose.origin.y)*71
 var shapes:=_shapes(coordinate-width*.5,coordinate+width*.5,height,salt)
 for form:Dictionary in forms:
  var terraces:Dictionary={}
  for p:Vector3 in form.green:
   var key:=roundi(p.x*10000)
   if not terraces.has(key):terraces[key]=[]
   terraces[key].append(p.y)
  var offsets:Dictionary={}
  var faces:PackedVector3Array=form.faces
  for p:Vector3 in faces:
   if offsets.has(p):continue
   var q:=p
   if p.z>0 and p.y<height-1.05:
    # Contact is defined in metres, independent of the source's normalized
    # image grid. The same continuous deformation carries the entire tread.
    var gain:=_depth(coordinate+p.x,p.y,height,shapes)
    if left_end:gain*=smoothstep(0.0,2.5,p.x+width*.5)
    if right_end:gain*=smoothstep(0.0,2.5,width*.5-p.x)
    q.z+=gain
   offsets[p]=q
  for i in faces.size():faces[i]=offsets[faces[i]]
  var green:PackedVector3Array=form.green
  for i in green.size():green[i]=offsets[green[i]]
  form.faces=faces;form.green=green
 return forms

static func _shapes(lo:float,hi:float,height:float,salt:int)->Array:
 var result:Array=[]
 for cell in range(floori(lo/6.5)-1,floori(hi/6.5)+2):
  for layer in maxi(1,ceili(height/4.8)):
   var key:=Vector3(cell,layer,73)
   if Helper.position_hash01(key,salt+7201)<.22:continue
   var cx:float=(cell+.08+.84*Helper.position_hash01(key,salt+7207))*6.5
   var cy:float=(layer+.15+.7*Helper.position_hash01(key,salt+7211))*4.8
   var w:=lerpf(2.4,5.5,Helper.position_hash01(key,salt+7213))
   var h:=lerpf(2.0,4.4,Helper.position_hash01(key,salt+7219))
   var d:=lerpf(.4,1.2,Helper.position_hash01(key,salt+7223))
   var angle:=lerpf(-.45,.45,Helper.position_hash01(key,salt+7229))
   var index:=mini(7,int(Helper.position_hash01(key,salt+7237)*8))
   result.append([cx,cy,w,h,d,angle,index])
 return result

static func _depth(u:float,y:float,height:float,shapes:Array)->float:
 var result:=0.0
 for shape:Array in shapes:
  var low:float=clampf((shape[1]-y)/shape[3],0,1)
  var q:Vector2=(Vector2(u,y)-Vector2(shape[0],shape[1])).rotated(shape[5])
  var nx:float=q.x/(shape[2]*(1.0+.28*low))+.5
  var ny:float=q.y/shape[3]+.5
  if nx<=0 or nx>=1 or ny>=1 or ny<=-.65:continue
  # The outer shoulder continues downward into a broader support, instead
  # of becoming a free oval attached to the wall at its middle.
  var sample_y:=maxf(.36,ny)
  var fx:=nx*48;var ix:=mini(47,floori(fx));var fy:=sample_y*32;var iy:=mini(31,floori(fy))
  var rock:Array=_rocks[shape[6]];var contours:Array=_contours[shape[6]]
  var value:float=lerpf(lerpf(rock[iy][ix],rock[iy][ix+1],fx-ix),lerpf(rock[iy+1][ix],rock[iy+1][ix+1],fx-ix),fy-iy)
  var edge:float=lerpf(lerpf(contours[iy][ix],contours[iy][ix+1],fx-ix),lerpf(contours[iy+1][ix],contours[iy+1][ix+1],fx-ix),fy-iy)
  value=maxf(0.0,(value-.38)/.62)
  # A shallow contact ramp joins the original rock silhouette to its wall.
  # Fixed normalized feather widths made small rocks almost vertical fins.
  var contact:float=maxf(0.0,edge)*minf(shape[2],shape[3])*.85
  var incoming:float=minf(value*shape[4],contact)
  incoming*=smoothstep(-.65,.15,ny) if shape[1]>2.5 else 1.0
  var radius:=minf(.16,minf(result,incoming))
  var blend:=maxf(0.0,radius-absf(result-incoming))/radius if radius>0 else 0.0
  result=maxf(result,incoming)+blend*blend*radius*.25
 return result*smoothstep(1.1,maxf(3.5,height*.32),height-y)

static func _native_depth(u:float,y:float)->float:return BASE._native_depth(u,y)
static func _native_normal(u:float,y:float)->Vector3:return BASE._native_normal(u,y)
static func _noise(x:float,salt:int)->float:return BASE._noise(x,salt)
