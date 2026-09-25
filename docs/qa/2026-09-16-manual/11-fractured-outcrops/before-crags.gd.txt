extends RefCounted
## Continuous worn stone with finite recessed ledges and broader lower shoulders.
## World-coordinate fields agree across chunk ownership; no course repeats by cell.
static func prepare()->void:
 pass

static func _noise(x:float,salt:int)->float:
 var i:=floori(x);var t:=smoothstep(0.0,1.0,x-i)
 return lerpf(Helper.position_hash01(Vector3(i,salt,0),salt),Helper.position_hash01(Vector3(i+1,salt,0),salt),t)

static func make(pose:Transform3D,width:float,height:float,seed_value:int,region:HeightfieldRegion=null,left_end:bool=false,right_end:bool=false)->Array[Dictionary]:
 var steps:=maxi(2,roundi(width/.35));var columns:Array=[]
 var faces:=PackedVector3Array();var green:=PackedVector3Array()
 var coordinate:=pose.origin.dot(pose.basis.x)
 var salt:=seed_value+roundi(pose.origin.dot(pose.basis.z))*13+roundi(pose.origin.y)*71
 var turf_rows:Dictionary={}
 for ix in steps+1:
  var x:float=-width*.5+width*float(ix)/steps;var u:=coordinate+x
  var fade:=1.0
  if left_end:fade*=smoothstep(0.0,2.5,x+width*.5)
  if right_end:fade*=smoothstep(0.0,2.5,width*.5-x)
  var core:=lerpf(1.6,2.8,_noise(u/13.0,salt+53))*clampf(height/10.0,.35,1.15)
  var boulder:=2.4*smoothstep(.3,.85,_noise(u/5.7,salt+83))
  var crest:=minf(height-.15,height*lerpf(.58,1.06,_noise(u/10.3,salt+91)))
  var fractures:=_fracture_profile(u,height,salt)
  var tops:Array[float]=[];var strengths:Array[float]=[]
  for cut in 4:
   tops.append(crest*(float(cut+1)/5.0+lerpf(-.078,.078,_noise(u/8.0,salt+cut*71+131))))
   var strength:=0.0;var selected_top:float=tops[-1];var selected_weight:=0.0
   for slot in range(floori(u/17.0)-1,floori(u/17.0)+2):
    var center:float=(slot+lerpf(.22,.78,Helper.position_hash01(Vector3(slot,cut,0),salt+149)))*17.0
    var half_width:=lerpf(2.0,5.5,Helper.position_hash01(Vector3(slot,cut,0),salt+173))
    var weight:=smoothstep(half_width,half_width*.5,absf(u-center))
    var target_top:float=height*(float(cut+1)/5.0+lerpf(-.09,.09,Helper.position_hash01(Vector3(slot,cut,0),salt+219)))+lerpf(-.09,.09,Helper.position_hash01(Vector3(slot,cut,0),salt+227))*(u-center)
    weight*=smoothstep(.03,.12,(crest-target_top)/height)
    if weight>selected_weight:selected_weight=weight;selected_top=target_top
    strength=maxf(strength,weight*lerpf(.8,1.5,_noise(u/9.0,salt+cut*59+193)))
   tops[-1]=lerpf(tops[-1],selected_top,smoothstep(.0,.25,selected_weight))
   strengths.append(strength)
  var sum_strength:=0.0
  for strength:float in strengths:sum_strength+=strength
  if sum_strength>2.6:
   for cut in 4:strengths[cut]*=2.6/sum_strength
  for cut in range(2,-1,-1):tops[cut]=minf(tops[cut],tops[cut+1]-.12)
  var points:=PackedVector3Array([Vector3(x,height,-.5),Vector3(x,crest,-.5)])
  var accumulated:=0.0
  var previous_y:=crest
  for cut in range(3,-1,-1):
   var top:=tops[cut];var strength:=strengths[cut]
   var cut_drop:=.005*(1.0-smoothstep(0.0,.15,strength))
   for part in range(1,7):
    var t:=float(part)/6.0;var y:=lerpf(previous_y,top,t)
    var depth:float=_body_depth(u,y,core,crest,boulder,salt,fractures)+accumulated
    points.append(Vector3(x,y,lerpf(-.5,depth*.80,fade)))
   turf_rows[points.size()-1]=true
   accumulated+=strength
   var depth:float=_body_depth(u,top-cut_drop,core,crest,boulder,salt,fractures)+accumulated
   points.append(Vector3(x,top-cut_drop,lerpf(-.5,depth*.80,fade)))
   previous_y=top-cut_drop
  var foot_depth:=(_body_depth(u,0,core,crest,boulder,salt,fractures)+accumulated)*.80
  var floor_y:=-.20
  if region!=null:
   for z:float in [0.0,foot_depth*.5,foot_depth]:
    var foot:Vector3=pose*Vector3(x,0,z)
    floor_y=minf(floor_y,TerrainSurfaceField.surface_y(region,foot.x,foot.z)-pose.origin.y-.2)
  for part in range(1,7):
   var t:=float(part)/6.0;var y:=lerpf(previous_y,floor_y,t)
   var depth:float=_body_depth(u,y,core,crest,boulder,salt,fractures)+accumulated
   points.append(Vector3(x,y,lerpf(-.5,depth*.80,fade)))
  columns.append(points)
 var count:int=columns[0].size()
 for ix in steps:
  for row in count-1:
   var a:Vector3=columns[ix][row];var b:Vector3=columns[ix+1][row];var c:Vector3=columns[ix][row+1];var d:Vector3=columns[ix+1][row+1]
   for tri:Array in [[a,b,c],[b,d,c]]:
    _triangle(faces,tri[0],tri[1],tri[2])
    var normal:Vector3=(tri[2]-tri[0]).cross(tri[1]-tri[0]).normalized()
    if turf_rows.has(row) and normal.y>.80 and minf(tri[0].z,minf(tri[1].z,tri[2].z))>.4:
     _triangle(green,tri[0],tri[1],tri[2])
 # Closed back, ends and feet; rendered and physical vertices are identical.
 for ix in steps:
  for row in count-1:
   var a:Vector3=columns[ix][row];var b:Vector3=columns[ix+1][row];var c:Vector3=columns[ix][row+1];var d:Vector3=columns[ix+1][row+1]
   a.z=-1.2;b.z=-1.2;c.z=-1.2;d.z=-1.2
   _triangle(faces,a,c,b);_triangle(faces,b,c,d)
  for row:int in [0,count-1]:
   var a:Vector3=columns[ix][row];var b:Vector3=columns[ix+1][row];var c:=Vector3(a.x,a.y,-1.2);var d:=Vector3(b.x,b.y,-1.2)
   if row==0:_triangle(faces,a,c,b);_triangle(faces,b,c,d)
   else:_triangle(faces,a,b,c);_triangle(faces,b,d,c)
 for ix:int in [0,steps]:
  for row in count-1:
   var a:Vector3=columns[ix][row];var b:Vector3=columns[ix][row+1];var c:=Vector3(a.x,a.y,-1.2);var d:=Vector3(b.x,b.y,-1.2)
   if ix==0:_triangle(faces,a,b,c);_triangle(faces,b,d,c)
   else:_triangle(faces,a,c,b);_triangle(faces,b,c,d)
 var bounds:=AABB(faces[0],Vector3.ZERO)
 for p:Vector3 in faces:bounds=bounds.expand(p)
 return [{"faces":faces,"green":green,"bounds":pose*bounds,"transform":pose,"anchor":pose.origin,
  "id":"worn_crag/%s/%s"%[pose.origin,pose.basis.z],"asset":&"cliff.native_crag","kind":"rock","native_crag":true,"top":(pose*bounds).end.y,"base":(pose*bounds).position.y}]

static func _body_depth(u:float,y:float,core:float,crest:float,boulder:float,salt:int,fractures:Array)->float:
 if y>=crest:return -.5
 var t:=clampf(1.0-y/crest,0.0,1.0)
 var broad:float=-.5+(core+.5)*pow(t,.35)
 var lower:float=boulder*exp(-pow((maxf(0,y)/crest-.18)/.29,4.0))
 var v:=y/2.8;var row:=floori(v)
 var detail:=lerpf(_noise(u/2.2,salt+row*37+211),_noise(u/2.2,salt+(row+1)*37+211),smoothstep(0.0,1.0,v-row))-.5
 var small:=lerpf(_noise(u/.9,salt+row*31+271),_noise(u/.9,salt+(row+1)*31+271),smoothstep(0.0,1.0,v-row))-.5
 # Short, staggered fractures break the broad worn faces. Each ends within
 # the stone rather than becoming a repeated course across the entire wall.
 var fracture:=0.0
 for entry:Array in fractures:
  for joint:Array in entry[0]:
   var dy:float=y-joint[0]
   fracture+=joint[1]*.36*exp(-pow(dy/.27,2.0))
  var shift:=.18*(_noise(y/3.0,entry[2])-.5)
  var cleft:=exp(-pow((u-entry[1]+shift)/.32,2.0))
  fracture+=.45*cleft*smoothstep(.0,.15,t)*smoothstep(1.0,.70,t)
 return broad+lower+(1.05*detail+.23*small-fracture)*smoothstep(0.0,.1,t)

static func _fracture_profile(u:float,height:float,salt:int)->Array:
 # Centers, spans and levels are constant down a vertical column. Prepare
 # once, keeping exactly the same field and arithmetic evaluation order.
 var result:Array=[]
 for cell in range(floori(u/6.0)-1,floori(u/6.0)+2):
  var key:=Vector3(cell,0,0)
  var center:float=(cell+Helper.position_hash01(key,salt+601))*6.0
  var half_span:=lerpf(1.6,3.6,Helper.position_hash01(key,salt+607))
  var along:=smoothstep(half_span,half_span*.6,absf(u-center))
  var joints:Array=[]
  for joint in 3:
   var joint_key:=Vector3(cell,joint,0)
   var level:float=height*(float(joint)+lerpf(.15,.85,Helper.position_hash01(joint_key,salt+613)))/3.0
   level+=.13*(u-center)+.18*(_noise(u/1.8,salt+joint*31+617)-.5)
   joints.append([level,along])
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
  var authored_normals:=PackedVector3Array()
  var faces:PackedVector3Array=green if grass else rock.faces
  for i in range(0,faces.size(),3):
   if not grass and turf.has([faces[i],faces[i+1],faces[i+2]]):continue
   var normal:Vector3=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized()
   for j in 3:
    authored_normals.append(normal)
    st.set_normal(normal)
    st.set_uv(CliffDressing.ground_uv() if grass else Vector2.ZERO)
    st.add_vertex(faces[i+j])
  if not grass:
   st.generate_normals()
   var arrays:=st.commit_to_arrays();var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
   for i in normals.size():normals[i]=authored_normals[i].lerp(normals[i],.94).normalized()
   arrays[Mesh.ARRAY_NORMAL]=normals
   result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  else:st.commit(result)
  if grass:result.surface_set_material(1,CliffDressing.shared_material())
  else:
   var material:=ShaderMaterial.new();material.shader=load("res://terrain/materials/field_rock.gdshader")
   material.set_shader_parameter("use_texture",false);material.set_shader_parameter("instance_variation",false)
   result.surface_set_material(0,material)
 return result
