extends GutTest
func test_same_slope_faces_continue_turf_across_the_complete_ledge()->void:
 var path:=OS.get_environment("STORY_CHANNEL_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var missing:=0;var area:=0.0;var examples:Array=[]
 for index in anchors.size():
  var a:Array=anchors[index]
  var form:Dictionary=source.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
  var turf:Dictionary={};var edge_normals:Dictionary={}
  for i in range(0,form.green.size(),3):
   var tri:Array=[form.green[i],form.green[i+1],form.green[i+2]];turf[tri]=true
   var normal:Vector3=(tri[2]-tri[0]).cross(tri[1]-tri[0]).normalized()
   for j in 3:
    var p:Vector3=tri[j];var q:Vector3=tri[(j+1)%3]
    edge_normals[[p,q] if p<q else [q,p]]=normal
  for i in range(0,form.faces.size(),3):
   var tri:Array=[form.faces[i],form.faces[i+1],form.faces[i+2]]
   if turf.has(tri):continue
   var cross:Vector3=(tri[2]-tri[0]).cross(tri[1]-tri[0]);var normal:=cross.normalized()
   if cross.length()<.006 or normal.y<.8 or minf(tri[0].z,minf(tri[1].z,tri[2].z))<=.4:continue
   for j in 3:
    var p:Vector3=tri[j];var q:Vector3=tri[(j+1)%3];var edge:Array=[p,q] if p<q else [q,p]
    if edge_normals.has(edge) and edge_normals[edge].dot(normal)>.97:
     missing+=1;area+=cross.length()*.5
     if examples.size()<12:examples.append([index,str((tri[0]+tri[1]+tri[2])/3),cross.length()*.5])
     break
 print("CONTINUOUS_TURF missing=",missing," area=",area," examples=",examples)
 assert_eq(missing,0,"A broad ledge should not have a stone strip on its connected continuation at the same slope")
