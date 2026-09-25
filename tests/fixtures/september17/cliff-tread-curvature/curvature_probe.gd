extends GutTest

func test_photo_treads_curve_from_wall_to_lip()->void:
 var path:=OS.get_environment("STORY_CURVED_GENERATOR")
 var generator:GDScript=load("res://tests/fixtures/september17/cliff-tread-curvature/candidate.gd" if path.is_empty() else path)
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

