extends GutTest
## The owner's photo review requires broad shelves and selectively wider feet.
## These physical-size checks support, but do not replace, matched art judgment.
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
func _measure()->Dictionary:
 var path:=OS.get_environment("STORY_TERRACE_GENERATOR")
 var generator:GDScript=CRAGS if path.is_empty() else load(path)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var broad:=0.0;var narrow:=0.0;var deep:=0;var quiet:=0
 for a:Array in anchors:
  var form:Dictionary=generator.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
  for i in range(0,form.green.size(),3):
   var p:Vector3=form.green[i];var q:Vector3=form.green[i+1];var r:Vector3=form.green[i+2]
   var width:=0.0
   for j in 3:
    var v:Vector3=form.green[i+j];var w:Vector3=form.green[i+(j+1)%3]
    if absf(v.x-w.x)<.001:width=maxf(width,absf(v.z-w.z))
   var area:float=(r-p).cross(q-p).length()*.5
   if width>=.8:broad+=area
   if width<.5:narrow+=area
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
 assert_lt(result.narrow,.01,"A sub-half-metre remnant should not become a long turf stripe")
 # At one-metre lateral samples, retain both larger basal buttresses and quiet
 # wall sections. A uniformly inflated wall would fail the quiet-section check.
 assert_gte(result.deep,100,"Increase the selected projecting basal stretches")
 assert_gte(result.quiet,150,"Keep substantial stretches close to the original cliff")
