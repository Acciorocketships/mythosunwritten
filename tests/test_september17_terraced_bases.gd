extends GutTest
## The owner's photo review requires broad shelves and selectively wider feet.
## These physical-size checks support, but do not replace, matched art judgment.
const WIDTH=preload("res://tests/helpers/cliff_tread_width.gd")
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
func _measure()->Dictionary:
 var path:=OS.get_environment("STORY_TERRACE_GENERATOR")
 var generator:GDScript=CRAGS if path.is_empty() else load(path)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var broad:=0.0;var narrow:=0.0;var deep:=0;var quiet:=0
 for a:Array in anchors:
  var form:Dictionary=generator.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
  var widths:=WIDTH.at_vertices(form.green)
  narrow+=_isolated_narrow_area(form.green,a[1],a[3],a[4])
  for i in range(0,form.green.size(),3):
   var p:Vector3=form.green[i];var q:Vector3=form.green[i+1];var r:Vector3=form.green[i+2]
   var width:=WIDTH.triangle(form.green,i,widths)
   var area:float=(r-p).cross(q-p).length()*.5
   if width>=.8:broad+=area
  var lows:Dictionary={}
  for v:Vector3 in form.faces:
   if v.y>=-.001 and v.y<.21:lows[v.x]=maxf(lows.get(v.x,0.0),v.z)
  for x:float in lows:
   if absf(x-roundf(x))>.01:continue
   if lows[x]>4.0:deep+=1
   if lows[x]<2.5:quiet+=1
 return {"broad":broad,"narrow":narrow,"deep":deep,"quiet":quiet}
func test_reported_cliffs_have_broad_treads_instead_of_painted_slivers()->void:
 var result:=_measure();print("TERRACE_PHOTO ",result)
 # 0.8 m is a usable tread, rather than a thin cap line. Require substantial
 # coverage across the 31 photographed formations; original coverage is 30 m².
 assert_gte(result.broad,100.0,"Restore substantial broad terrace surface across the photographed cliffs")
 assert_lt(result.narrow,.01,"A wholly narrow isolated ledge should not become a turf stripe; tapered ends of broad ledges stay covered")
 # At one-metre lateral samples, retain both larger basal buttresses and quiet
 # wall sections. A uniformly inflated wall would fail the quiet-section check.
 assert_gte(result.deep,100,"Increase the selected projecting basal stretches")
 assert_gte(result.quiet,150,"Keep substantial stretches close to the original cliff")

func _root(parent:Array[int],index:int)->int:
 while parent[index]!=index:index=parent[index]
 return index

func _isolated_narrow_area(faces:PackedVector3Array,width:float,left_end:bool,right_end:bool)->float:
 # A shelf is a connected physical surface, not each triangle created by
 # curved-tread subdivision. Its pointed ends share the broad shelf's turf.
 var widths:=WIDTH.at_vertices(faces)
 var parent:Array[int]=[];var edges:Dictionary={}
 for i in faces.size()/3:parent.append(i)
 for i in parent.size():
  for j in 3:
   var a:=faces[i*3+j];var b:=faces[i*3+(j+1)%3]
   var edge:Array=[a,b] if a<b else [b,a]
   if edges.has(edge):parent[_root(parent,i)]=_root(parent,edges[edge])
   else:edges[edge]=i
 var groups:Dictionary={}
 for i in parent.size():
  var root:=_root(parent,i)
  if not groups.has(root):groups[root]=[0.0,0.0,false]
  var group:Array=groups[root]
  group[0]+=(faces[i*3+2]-faces[i*3]).cross(faces[i*3+1]-faces[i*3]).length()*.5
  group[1]=maxf(group[1],WIDTH.triangle(faces,i*3,widths))
  for j in 3:
   var x:float=faces[i*3+j].x
   if (not left_end and absf(x+width*.5)<.001) or (not right_end and absf(x-width*.5)<.001):group[2]=true
 var narrow:=0.0
 for group:Array in groups.values():
  if group[1]<.5 and not group[2]:narrow+=group[0]
 return narrow

func test_ledge_measurement_still_rejects_a_separate_narrow_ribbon()->void:
 var a:=Vector3(0,1,0);var b:=Vector3(3,1,0);var c:=Vector3(0,1,.3);var d:=Vector3(3,1,.3)
 var ribbon:=PackedVector3Array([a,b,c,b,d,c])
 assert_almost_eq(_isolated_narrow_area(ribbon,10,true,true),.9,.00001)
 # Extend one end into a broad tread, sharing the existing physical edge.
 var e:=Vector3(5,1,0);var f:=Vector3(5,1,1.2)
 ribbon.append_array(PackedVector3Array([b,e,d,e,f,d]))
 assert_eq(_isolated_narrow_area(ribbon,10,true,true),0.0,"A narrow taper belongs to its attached broad ledge")
