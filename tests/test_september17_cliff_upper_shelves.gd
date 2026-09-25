extends GutTest
const WIDTH=preload("res://tests/helpers/cliff_tread_width.gd")

## Ledges are off by default for now (owner, September 24); these tests
## cover the ledge generator itself.
const _LEDGE_STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func before_all()->void:_LEDGE_STYLE.ledges=true
func after_all()->void:_LEDGE_STYLE.apply("chosen")

func test_photographed_upper_shelves_include_substantial_depth()->void:
 var path:=OS.get_environment("STORY_SHELF_GENERATOR")
 var generator:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var total:=0.0;var broad:=0.0;var inclined:=0.0;var forms:=0
 for anchor:Array in anchors:
  var form:Dictionary=generator.make(anchor[0],anchor[1],anchor[2],2697992464,null,anchor[3],anchor[4])[0]
  var faces:PackedVector3Array=form.green
  var widths:=WIDTH.at_vertices(faces)
  var area_here:=0.0
  for i in range(0,faces.size(),3):
   var a:=faces[i];var b:=faces[i+1];var c:=faces[i+2]
   if (a.y+b.y+c.y)/3.0<anchor[2]*.45:continue
   var cross:Vector3=(c-a).cross(b-a)
   var area:=cross.length()*.5
   total+=area;area_here+=area
   if WIDTH.triangle(faces,i,widths)>=.9:broad+=area
   if cross.y>0 and absf(cross.z/cross.y)>.03:inclined+=area
  if area_here>1.0:forms+=1
 print("UPPER_SHELVES total=",total," broad=",broad," inclined=",inclined," forms=",forms)
 assert_gt(total,30.0,"Retain substantial upper ledges rather than erase the thin ones")
 assert_gt(broad/maxf(.001,total),.45,"Upper shelf area should include deep terraces, not mostly narrow ribbons")
 assert_gt(inclined/maxf(.001,total),.35,"Upper shelves should carry depthwise slopes as well as the lower nature-rock terraces")
 assert_gt(forms,8,"Broader ledges should occur across the photographed field")
