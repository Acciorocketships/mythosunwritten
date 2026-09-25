extends RefCounted
## Study: hand over the raised collinear wall at the actual tall-wall end.
const S=preload("res://scripts/terrain/field/CliffInnerSurface.gd")
const C=preload("res://tests/fixtures/september19/receiver-crown-transition/transition.gd")
static func apply(forms:Array)->Dictionary:
 var tall:Dictionary={};var raised:Dictionary={}
 for f:Dictionary in forms:
  if f.transform.origin.distance_to(Vector3(-445.5,28,-267))<.01:tall=f
  if f.transform.origin.distance_to(Vector3(-445.5,32,-289.5))<.01:raised=f
 if tall.is_empty() or raised.is_empty():return {"error":"missing source"}
 var source:=S.section(tall,Vector3(12,0,0),12)
 var a:=PackedVector2Array()
 var floor_y:=INF
 for p:Vector3 in raised.faces:floor_y=minf(floor_y,p.y+4.0)
 for p:Vector2 in source:
  if p.y>=floor_y:a.append(p)
  else:
   if a[-1].y>floor_y:a.append(a[-1].lerp(p,(floor_y-a[-1].y)/(p.y-a[-1].y)))
   break
 var b:=S.section(raised,Vector3(-5.5,0,0),8)
 for i in b.size():b[i].y+=4.0
 var at:=S.main_tread(tall,Vector3(12,0,0),12)
 var bt:=S.main_tread(raised,Vector3(-5.5,0,0),8)
 for i in bt.size():bt[i]+=Vector2(0,4)
 var ad:=S.parameters(a,at);var bd:=S.parameters(b,bt)
 if ad.is_empty() or bd.is_empty():return {"error":"missing treads","a":a,"b":b,"at":at,"bt":bt,"ad":ad,"bd":bd}
 var samples:Array[float]=[]
 for list:PackedFloat32Array in [ad,bd]:
  for value:float in list:
   if value not in samples:samples.append(value)
 samples.sort()
 var front:Array=[];var back:Array=[]
 for i in 41:
  var t:=i/40.0;var blend:=smoothstep(0,1,t)
  var row:=PackedVector3Array();var rear:=PackedVector3Array()
  for s:float in samples:
   var p:=S.at(a,ad,s).lerp(S.at(b,bd,s),blend)
   row.append(Vector3(12+5*t,p.y,p.x).snapped(Vector3.ONE*.0001))
   rear.append(Vector3(12+5*t,p.y,-1.2).snapped(Vector3.ONE*.0001))
  front.append(row);back.append(rear)
 var faces:=PackedVector3Array();var green:=PackedVector3Array()
 for i in 40:
  for j in samples.size()-1:
   var turf:bool=samples[j]>=.4-.00001 and samples[j+1]<=.6+.00001
   S.tri(faces,green,front[i][j],front[i+1][j],front[i][j+1],turf)
   S.tri(faces,green,front[i+1][j],front[i+1][j+1],front[i][j+1],turf)
   S.tri(faces,green,back[i][j],back[i][j+1],back[i+1][j],false)
   S.tri(faces,green,back[i+1][j],back[i][j+1],back[i+1][j+1],false)
  S.tri(faces,green,front[i][0],back[i][0],front[i+1][0],false)
  S.tri(faces,green,front[i+1][0],back[i][0],back[i+1][0],false)
  S.tri(faces,green,front[i][-1],front[i+1][-1],back[i][-1],false)
  S.tri(faces,green,front[i+1][-1],back[i+1][-1],back[i][-1],false)
 for j in samples.size()-1:
  S.tri(faces,green,front[0][j],front[0][j+1],back[0][j],false)
  S.tri(faces,green,back[0][j],front[0][j+1],back[0][j+1],false)
  S.tri(faces,green,front[-1][j],back[-1][j],front[-1][j+1],false)
  S.tri(faces,green,back[-1][j],back[-1][j+1],front[-1][j+1],false)
 C._clip(raised,-5.5,true)
 var patch:Dictionary=tall.duplicate(true)
 patch.faces=faces;patch.green=green;patch.id="actual_end_profile_study";patch.erase("native_roots")
 C._bounds(patch);forms.append(patch)
 return {"triangles":faces.size()/3,"start":tall.transform*Vector3(12,0,0),"finish":tall.transform*Vector3(17,0,0),"floor":floor_y,"tread_a":at,"tread_b":bt}
