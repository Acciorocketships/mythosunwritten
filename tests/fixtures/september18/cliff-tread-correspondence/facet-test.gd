extends GutTest
func test_reported_slope_does_not_form_alternating_sharp_facets()->void:
 var generator:GDScript=load(OS.get_environment("STORY_COLUMN_GENERATOR"))
 var a:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()[9]
 var form:Dictionary=generator.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
 var edges:Dictionary={}
 for i in range(0,form.faces.size(),3):
  var tri:Array=[form.faces[i],form.faces[i+1],form.faces[i+2]]
  var included:=true
  for p:Vector3 in tri:
   if p.x<1.5 or p.x>3.5 or p.y<4.4 or p.y>6.0 or p.z<.5:included=false
  if not included:continue
  var normal:Vector3=(tri[2]-tri[0]).cross(tri[1]-tri[0]).normalized()
  for j in 3:
   var p:Vector3=tri[j];var q:Vector3=tri[(j+1)%3]
   var key:Array=[p,q] if p<q else [q,p]
   if not edges.has(key):edges[key]=[]
   edges[key].append(normal)
 var worst:=0.0;var count:=0;var harsh:=0;var worst_edge:Array=[]
 var worst_normals:Array=[]
 for edge:Array in edges:
  var normals:Array=edges[edge]
  if normals.size()!=2:continue
  var angle:float=rad_to_deg(normals[0].angle_to(normals[1]))
  if angle>worst:
   worst=angle;worst_edge=edge;worst_normals=normals
  count+=1
  if angle>50:harsh+=1
 print("WORST ",worst_edge," ",worst_normals)
 print("PHOTO_SLOPE_FACETS edges=",count," harsh=",harsh," max_angle=",worst)
 assert_gt(count,50,"Measure connected physical faces in the photographed tooth region")
 assert_lt(worst,50.0,"The smooth rock shoulder must not alternate between hard facets")
