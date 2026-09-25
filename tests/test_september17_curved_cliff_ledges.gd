extends GutTest

## Ledges are off by default for now (owner, September 24); these tests
## cover the ledge generator itself.
const _LEDGE_STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func before_all()->void:_LEDGE_STYLE.ledges=true
func after_all()->void:_LEDGE_STYLE.apply("chosen")

func test_photo_treads_change_slope_within_connected_shelves()->void:
 var path:=OS.get_environment("STORY_CURVED_GENERATOR")
 var generator:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var broad:=0;var curved:=0;var sloping:=0
 for anchor:Array in anchors:
  var form:Dictionary=generator.make(anchor[0],anchor[1],anchor[2],2697992464,null,anchor[3],anchor[4])[0]
  var faces:PackedVector3Array=form.green
  var parents:Array[int]=[];var edges:Dictionary={}
  for i in faces.size()/3:parents.append(i)
  for i in parents.size():
   for j in 3:
    var a:=faces[i*3+j];var b:=faces[i*3+(j+1)%3]
    var key:Array=[a,b] if a<b else [b,a]
    if edges.has(key):parents[_root(parents,i)]=_root(parents,edges[key])
    else:edges[key]=i
  var groups:Dictionary={}
  for i in parents.size():
   var root:=_root(parents,i)
   if not groups.has(root):groups[root]=[0.0,INF,-INF,INF,-INF,INF,-INF]
   var g:Array=groups[root]
   var a:=faces[i*3];var b:=faces[i*3+1];var c:=faces[i*3+2]
   var cross:Vector3=(c-a).cross(b-a)
   var area:=cross.length()*.5
   if area<.00001:continue
   var slope:float=-cross.x/cross.y
   g[0]+=area;g[1]=minf(g[1],slope);g[2]=maxf(g[2],slope)
   for p:Vector3 in [a,b,c]:
    g[3]=minf(g[3],p.x);g[4]=maxf(g[4],p.x)
    g[5]=minf(g[5],p.y);g[6]=maxf(g[6],p.y)
  for g:Array in groups.values():
   if g[0]<1.0 or g[4]-g[3]<3.0:continue
   broad+=1
   if g[6]-g[5]>.35:sloping+=1
   if g[2]-g[1]>.12:curved+=1
 print("CURVED_TREADS broad=",broad," sloping=",sloping," curved=",curved)
 assert_gte(broad,10,"Retain substantial connected ledges in the photographed cliff field")
 assert_gte(sloping,8,"Several broad shelves must visibly gain or lose elevation across their span")
 assert_gte(curved,6,"Several actual connected treads must bend rather than remain tilted planes")
 assert_gt(float(sloping)/maxi(1,broad),.5,"Most substantial shelves should change elevation, rather than only a few exceptional tips")
 assert_gt(float(curved)/maxi(1,broad),.4,"Curving treads should be a substantial part of the composition")

func test_photo_treads_include_depthwise_slopes()->void:
 var path:=OS.get_environment("STORY_CURVED_GENERATOR")
 var generator:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var total:=0.0;var inclined:=0.0
 for anchor:Array in anchors:
  var form:Dictionary=generator.make(anchor[0],anchor[1],anchor[2],2697992464,null,anchor[3],anchor[4])[0]
  var faces:PackedVector3Array=form.green
  for i in range(0,faces.size(),3):
   var cross:Vector3=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i])
   var area:=cross.length()*.5
   if area<.00001 or cross.y<=0:continue
   total+=area
   if absf(cross.z/cross.y)>.03:inclined+=area
 print("DEPTHWISE_TREADS total=",total," inclined=",inclined)
 assert_gt(total,30.0,"Sloping treads retain substantial actual turf area")
 assert_gt(inclined/maxf(.001,total),.2,"Depthwise inclines occur on substantial shelves, not only degenerate tips")

func _root(parents:Array[int],i:int)->int:
 while parents[i]!=i:i=parents[i]
 return i

func test_photo_treads_curve_from_wall_to_lip()->void:
 var path:=OS.get_environment("STORY_CURVED_GENERATOR")
 var generator:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var curved_columns:=0
 for anchor:Array in anchors:
  var form:Dictionary=generator.make(anchor[0],anchor[1],anchor[2],2697992464,null,anchor[3],anchor[4])[0]
  var edges:Dictionary={}
  var faces:PackedVector3Array=form.green
  for i in range(0,faces.size(),3):
   for j in 3:
    var a:=faces[i+j];var b:=faces[i+(j+1)%3]
    if absf(a.x-b.x)>.00001 or absf(a.z-b.z)<.03:continue
    if a.z>b.z:
     var swap:=a;a=b;b=swap
    edges[[a,b]]=true
  var incoming:Dictionary={};var outgoing:Dictionary={}
  for edge:Array in edges:
   var a:Vector3=edge[0];var b:Vector3=edge[1]
   var grade:float=(b.y-a.y)/(b.z-a.z)
   incoming[b]=grade;outgoing[a]=grade
  var columns:Dictionary={}
  for point:Vector3 in incoming:
   if outgoing.has(point) and absf(incoming[point]-outgoing[point])>.035:
    columns[point.x]=true
  curved_columns+=columns.size()
 print("CROSS_TREAD_CURVES columns=",curved_columns)
 assert_gt(curved_columns,30,"Photographed shelves need actual curvature across their depth, rather than one ruled strip per tread")

