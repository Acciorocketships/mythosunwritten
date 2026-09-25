extends GutTest
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const WIDTH=preload("res://tests/helpers/cliff_tread_width.gd")

## Ledges are off by default for now (owner, September 24); these tests
## cover the ledge generator itself.
const _LEDGE_STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func before_all()->void:_LEDGE_STYLE.ledges=true
func after_all()->void:_LEDGE_STYLE.apply("chosen")

func test_overlapping_fractures_share_a_cut_instead_of_doubling_its_depth()->void:
 var path:=OS.get_environment("STORY_TALL_TERRACE_GENERATOR")
 var generator:GDScript=CRAGS if path.is_empty() else load(path)
 generator.prepare()
 var fracture:Array=[[[12.0,1.0,.6]],1.0,278]
 var base:float=generator._body_depth(1.0,12.0,3.0,32.0,1.0,278,[],[],2.0)
 var single:float=generator._body_depth(1.0,12.0,3.0,32.0,1.0,278,[fracture],[],2.0)
 var overlap:float=generator._body_depth(1.0,12.0,3.0,32.0,1.0,278,[fracture,fracture],[],2.0)
 print("FRACTURE_UNION single_cut=",base-single," duplicate_extra=",single-overlap)
 assert_gt(base-single,.15,"Retain actual carved surface detail")
 assert_almost_eq(overlap,single,.001,"Overlapping fracture owners describe one cut, not a double-depth gouge")

func test_tall_upper_terraces_have_substantial_treads()->void:
 var path:=OS.get_environment("STORY_TALL_TERRACE_GENERATOR")
 var generator:GDScript=CRAGS if path.is_empty() else load(path)
 # Same seed and native pose as the judged 64 m composition control. Measure
 # connected depth across subdivisions, not individual triangle edge lengths.
 var form:Dictionary=generator.make(Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5)),48,64,2697992464)[0]
 var widths:=WIDTH.at_vertices(form.green)
 var total:=0.0;var broad:=0.0
 for i in range(0,form.green.size(),3):
  var a:Vector3=form.green[i];var b:Vector3=form.green[i+1];var c:Vector3=form.green[i+2]
  if (a.y+b.y+c.y)/3.0<25.6:continue
  var area:float=(c-a).cross(b-a).length()*.5
  total+=area
  if WIDTH.triangle(form.green,i,widths)>=.9:broad+=area
 print("TALL_TREADS upper_area=",total," broad_area=",broad," broad_fraction=",broad/maxf(total,.001))
 assert_gt(broad,15.0,"The upper wall needs occasional substantial shelves, not only fine grass ribbons")
 assert_gt(broad/maxf(total,.001),.30,"Broad ledges must form a visible part of the upper composition")

func test_tall_terraces_keep_lower_support_and_crown_clearance()->void:
 var path:=OS.get_environment("STORY_TALL_TERRACE_GENERATOR")
 var generator:GDScript=CRAGS if path.is_empty() else load(path)
 for height:float in [32.0,64.0]:
  var pose:=Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5))
  var form:Dictionary=generator.make(pose,48,height,2697992464)[0]
  var columns:Dictionary={};var recession:=0.0;var crown_excess:=0.0
  for p:Vector3 in form.faces:
   if p.z<-.4 or p.y<0.0:continue
   if not columns.has(p.x):columns[p.x]={}
   columns[p.x][p.y]=maxf(columns[p.x].get(p.y,-INF),p.z)
   if p.y>height-.5:crown_excess=maxf(crown_excess,p.z-generator._native_depth(pose.origin.x+p.x,p.y))
  for column:Dictionary in columns.values():
   var heights:Array=column.keys();heights.sort();heights.reverse()
   var upper:=-INF
   for y:float in heights:
    if y>height-1.0:continue
    recession=maxf(recession,upper-column[y]);upper=maxf(upper,column[y])
  print("TALL_BEARING height=",height," recession=",recession," crown_excess=",crown_excess)
  assert_lt(recession,.85,"Wide tall shelves need real stone support down to the base")
  assert_lt(crown_excess,.35,"Tall relief must still tuck beneath the native turf lip")
