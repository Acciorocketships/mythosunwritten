extends GutTest
# Diagnostic only. Baseline already passes: pocket count does not explain softness.

const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")

func test_close_photo_faces_have_small_physical_weathering_pockets()->void:
 var path:=OS.get_environment("STORY_SPALL_GENERATOR")
 var generator:GDScript=CRAGS if path.is_empty() else load(path)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var tested:=0;var pockets:=0;var sharp:=0
 for index:int in [0,4,12,20]:
  var entry:Array=anchors[index]
  var form:Dictionary=generator.make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4])[0]
  var grid:Dictionary={}
  for p:Vector3 in form.faces:
   if absf(p.y*5-roundf(p.y*5))>.001:continue
   var key:=Vector2i(roundi(p.x*4),roundi(p.y*5))
   grid[key]=maxf(grid.get(key,-INF),p.z)
  for key:Vector2i in grid:
   var z:float=grid[key]
   if z<2.5 or key.y<5:continue
   var depths:Array=[]
   for offset:Vector2i in [Vector2i(-2,0),Vector2i(2,0),Vector2i(0,-2),Vector2i(0,2)]:
    if grid.has(key+offset):depths.append(grid[key+offset])
   if depths.size()!=4:continue
   # A small concavity in both directions distinguishes a weathered pocket
   # from a long groove or a convex boulder. Test the physical skin, not bump.
   var horizontal:float=(depths[0]+depths[1])*.5-z
   var vertical:float=(depths[2]+depths[3])*.5-z
   tested+=1
   if horizontal>.08 and vertical>.08:pockets+=1
   if maxf(absf(horizontal),absf(vertical))>1.0:sharp+=1
 print("PHYSICAL_POCKETS tested=",tested," pockets=",pockets," fraction=",float(pockets)/maxi(1,tested)," extreme=",sharp)
 assert_gt(tested,500,"Exercise thick stone across four actual photo formations")
 assert_gte(float(pockets)/maxi(1,tested),.025,"Resolve some sub-metre concave weathering between the large clefts")
 assert_lt(float(sharp)/maxi(1,tested),.10,"Do not replace the stone with metre-deep small spikes")
