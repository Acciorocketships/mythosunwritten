extends RefCounted
const BASE=preload("res://tests/fixtures/september18/cliff-connected-relief/before.gd")
static func prepare()->void:BASE.prepare()
static func make(pose:Transform3D,width:float,height:float,seed_value:int,region:HeightfieldRegion=null,left_end:bool=false,right_end:bool=false)->Array[Dictionary]:
 var forms:=BASE.make(pose,width,height,seed_value,region,left_end,right_end)
 if pose.origin.distance_to(Vector3(-480,32,-253.5))>.01:return forms
 var rock:Dictionary=forms[0]
 var definitions:Array=[[-6.0,2.1,8.8,4.8,3.8,.23,1],[1.2,3.0,6.5,5.8,3.3,-.28,4],[6.1,1.6,9.5,3.8,4.2,.14,6]]
 var bodies:Array=[]
 for row:Array in definitions:
  var front:=-INF
  for i in range(0,rock.faces.size(),3):
   var hit=Geometry3D.ray_intersects_triangle(Vector3(row[0],row[1],30),Vector3.FORWARD,rock.faces[i],rock.faces[i+1],rock.faces[i+2])
   if hit!=null:front=maxf(front,hit.z)
  assert(is_finite(front))
  bodies.append(row+[front])
 var mapping:Dictionary={}
 for p:Vector3 in rock.faces:
  if mapping.has(p):continue
  var q:=p
  if p.z>0 and p.y>0 and p.y<height-1.2:
   for row:Array in bodies:
    var dx:float=p.x-row[0];var dy:float=p.y-row[1]
    var nx:float=(dx*cos(row[5])+dy*sin(row[5]))/row[2]+.5
    var ny:float=(-dx*sin(row[5])+dy*cos(row[5]))/row[3]+.5
    if nx<=0 or nx>=1 or ny<=0 or ny>=1:continue
    var fx:=nx*48;var ix:=mini(47,floori(fx))
    var fy:=ny*32;var iy:=mini(31,floori(fy))
    var body:Array=BASE._nature_bodies[int(row[6])]
    var value:float=lerpf(lerpf(body[iy][ix],body[iy][ix+1],fx-ix),lerpf(body[iy+1][ix],body[iy+1][ix+1],fx-ix),fy-iy)
    var front:float=row[7]+(value-.58)*row[4]
    var blend:=maxf(0.0,1.1-absf(q.z-front))/1.1
    var united:float=maxf(q.z,front)+blend*blend*1.1*.25
    var edge:=smoothstep(0.0,.15,minf(minf(nx,1-nx),minf(ny,1-ny)))
    var crown:=smoothstep(1.2,3.0,height-p.y)*smoothstep(.0,.75,p.y)
    q.z=lerpf(q.z,united,edge*crown)
  mapping[p]=q.snapped(Vector3.ONE*.0001)
 var faces:=PackedVector3Array();var green:=PackedVector3Array()
 for p:Vector3 in rock.faces:faces.append(mapping[p])
 for i in range(0,rock.green.size(),3):
  var a:Vector3=mapping[rock.green[i]];var b:Vector3=mapping[rock.green[i+1]];var c:Vector3=mapping[rock.green[i+2]]
  if (c-a).cross(b-a).normalized().y>.8:green.append_array(PackedVector3Array([a,b,c]))
 rock.faces=faces;rock.green=green
 var bounds:=AABB(faces[0],Vector3.ZERO)
 for p:Vector3 in faces:bounds=bounds.expand(p)
 rock.bounds=pose*bounds
 return forms
static func mesh(rock:Dictionary)->ArrayMesh:return BASE.mesh(rock)
