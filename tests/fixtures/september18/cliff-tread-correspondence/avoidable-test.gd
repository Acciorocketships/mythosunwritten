extends GutTest
## Check physical riser quads, excluding actual ledge folds and ownership ends.
func test_photo_risers_do_not_add_avoidable_diagonal_creases()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var measured:=0;var avoidable:=0;var worst_improvement:=0.0
 for a:Array in anchors:
  var form:Dictionary=source.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
  var edges:Dictionary={}
  for i in range(0,form.faces.size(),3):
   var tri:Array=[form.faces[i],form.faces[i+1],form.faces[i+2]]
   if minf(tri[0].z,minf(tri[1].z,tri[2].z))<.5:continue
   for j in 3:
    var p:Vector3=tri[j];var q:Vector3=tri[(j+1)%3]
    if absf(p.x-q.x)<.01 or absf(p.y-q.y)<.01:continue
    if absf(p.x-q.x)>.251 or absf(p.y-q.y)>.201:continue
    if absf(p.y-snappedf(p.y,.2))>.00011 or absf(q.y-snappedf(q.y,.2))>.00011:continue
    var key:Array=[p,q] if p<q else [q,p]
    if not edges.has(key):edges[key]=[]
    edges[key].append(tri[(j+2)%3])
  for edge:Array in edges:
   var other:Array=edges[edge]
   if other.size()!=2:continue
   var p:Vector3=edge[0];var q:Vector3=edge[1]
   var a0:Vector3=other[0];var b0:Vector3=other[1]
   if not ((absf(a0.x-p.x)<.0001 and absf(a0.y-q.y)<.0001 and absf(b0.x-q.x)<.0001 and absf(b0.y-p.y)<.0001) or (absf(b0.x-p.x)<.0001 and absf(b0.y-q.y)<.0001 and absf(a0.x-q.x)<.0001 and absf(a0.y-p.y)<.0001)):continue
   var n0:Vector3=(a0-p).cross(q-p).normalized()
   var n1:Vector3=(q-p).cross(b0-p).normalized()
   var m0:Vector3=(p-a0).cross(b0-a0).normalized()
   var m1:Vector3=(b0-a0).cross(q-a0).normalized()
   var angle:float=rad_to_deg(n0.angle_to(n1))
   var alternative:float=rad_to_deg(m0.angle_to(m1))
   measured+=1
   if angle>50 and alternative<angle-10:
    avoidable+=1;worst_improvement=maxf(worst_improvement,angle-alternative)
 print("PHOTO_DIAGONALS quads=",measured," avoidable_hard_creases=",avoidable," worst_avoidable_angle=",worst_improvement)
 assert_gt(measured,10000,"Measure physical riser quads across all photo formations")
 assert_eq(avoidable,0,"Triangulation must not add a hard crease that the other diagonal avoids")
