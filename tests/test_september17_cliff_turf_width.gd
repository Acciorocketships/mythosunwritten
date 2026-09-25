extends GutTest
const WIDTH=preload("res://tests/helpers/cliff_tread_width.gd")
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const BEFORE=preload("res://tests/fixtures/september17/cliff-turf/before.gd")
const TURF_ONLY=preload("res://tests/fixtures/september17/cliff-body-crags/before.gd")
## Ledges are off by default for now (owner, September 24); these tests
## cover the ledge generator itself.
const _LEDGE_STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func before_all()->void:_LEDGE_STYLE.ledges=true
func after_all()->void:_LEDGE_STYLE.apply("chosen")

func _forms(generator:GDScript)->Array:
 var forms:Array=[]
 for entry:Array in FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var():
  forms.append_array(generator.make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4]))
 return forms
func _measure(forms:Array)->Dictionary:
 var thin:=0;var area:=0.0;var broad_area:=0.0;var count:=0
 for rock:Dictionary in forms:
  var widths:=WIDTH.at_vertices(rock.green)
  for i in range(0,rock.green.size(),3):
   var a:Vector3=rock.green[i];var b:Vector3=rock.green[i+1];var c:Vector3=rock.green[i+2]
   var width:=WIDTH.triangle(rock.green,i,widths)
   var triangle_area:float=(c-a).cross(b-a).length()*.5
   area+=triangle_area;count+=1
   if width<.20:thin+=1
   if width>=.35:broad_area+=triangle_area
 return {"thin":thin,"area":area,"broad_area":broad_area,"triangles":count}
func test_photographed_cliffs_do_not_paint_hairline_ledge_remnants_as_turf()->void:
 var original:=_measure(_forms(BEFORE));var current:=_measure(_forms(CRAGS))
 print("PHOTO_TURF before=",original," current=",current)
 assert_gt(original.thin,100,"The frozen photo geometry reproduces narrow painted stripes")
 assert_eq(_small_islands(_forms(CRAGS),true),0,"Narrow pointed ends may continue a broad shelf, but isolated hairline shoulders remain stone")
 assert_gt(current.area,original.area*.70,"Keep broad green shelves rather than erase cliff planting")
 assert_gt(current.broad_area,original.broad_area*.95,"Preserve the usable broad ledges")
func test_frozen_turf_only_revision_preserved_every_physical_stone_vertex()->void:
 # This archived comparison proves the turf-only repair did not reshape stone.
 # Later deliberate crag geometry changes have their own physical controls.
 var original:=_forms(BEFORE);var current:=_forms(TURF_ONLY)
 assert_eq(current.size(),original.size())
 for i in current.size():assert_eq(current[i].faces,original[i].faces,"Changing turf eligibility cannot reshape collision or native attachments")

func _small_islands(forms:Array,require_width:bool=false)->int:
 var count:=0
 for rock:Dictionary in forms:
  var left:=INF;var right:=-INF
  for point:Vector3 in rock.faces:left=minf(left,point.x);right=maxf(right,point.x)
  var parents:Array[int]=[];var edges:Dictionary={};var sums:Dictionary={};var shared:Dictionary={};var broad:Dictionary={}
  var widths:=WIDTH.at_vertices(rock.green)
  for i in rock.green.size()/3:parents.append(i)
  for i in parents.size():
   for j in 3:
    var a:Vector3=rock.green[i*3+j];var b:Vector3=rock.green[i*3+(j+1)%3]
    var key:Array=[a,b] if a<b else [b,a]
    if edges.has(key):parents[_root(parents,i)]=_root(parents,edges[key])
    else:edges[key]=i
  for i in parents.size():
   var root:=_root(parents,i)
   var a:Vector3=rock.green[i*3];var b:Vector3=rock.green[i*3+1];var c:Vector3=rock.green[i*3+2]
   sums[root]=sums.get(root,0.0)+(c-a).cross(b-a).length()*.5
   if WIDTH.triangle(rock.green,i*3,widths)>=.55:broad[root]=true
   # Canonical ownership cuts can divide a larger patch; only judge complete islands.
   for point:Vector3 in [a,b,c]:
    if absf(point.x-left)<.001 or absf(point.x-right)<.001:shared[root]=true
  for root:int in sums:
   if not shared.has(root) and (sums[root]<.35 or (require_width and not broad.has(root))):count+=1
 return count
func _root(parents:Array[int],i:int)->int:
 while parents[i]!=i:i=parents[i]
 return i
func test_turf_does_not_leave_tiny_isolated_paint_dashes()->void:
 var current:=_small_islands(_forms(CRAGS))
 print("TURF_SMALL_ISLANDS count=",current)
 assert_eq(current,0,"Small disconnected paint dashes must remain stone")

func test_a_small_patch_at_an_open_owner_cut_keeps_its_neighbor_continuation()->void:
 var patch:=PackedVector3Array([Vector3(.5,1,1),Vector3(1,1,1),Vector3(.5,1,1.25),Vector3(1,1,1),Vector3(1,1,1.25),Vector3(.5,1,1.25)])
 assert_eq(CRAGS._turf_without_dashes(patch,2,true,false),patch,"A canonical owner cut does not turn a shared ledge into a small isolated scrap")
 assert_true(CRAGS._turf_without_dashes(patch,2,true,true).is_empty(),"The same tiny patch at an actual cliff end is isolated")

func test_turf_keeps_a_pointed_taper_attached_to_a_broad_cap()->void:
 var a:=Vector3(0,1,1);var b:=Vector3(0,1,2);var c:=Vector3(1,1,1);var d:=Vector3(1,1,2);var tip:=Vector3(3,1,1.5)
 var patch:=PackedVector3Array([a,c,b,c,d,b,c,tip,d])
 var broad:Dictionary={[a,c,b]:true,[c,d,b]:true}
 assert_eq(CRAGS._turf_without_dashes(patch,10,true,true,broad,true),patch,"The whole pointed ledge retains turf, including its narrowing end")
 var strip:=PackedVector3Array([Vector3(0,1,3),Vector3(4,1,3),Vector3(0,1,3.15),Vector3(4,1,3),Vector3(4,1,3.15),Vector3(0,1,3.15)])
 assert_true(CRAGS._turf_without_dashes(strip,10,true,true,{},true).is_empty(),"An isolated long narrow strip is not a usable broad ledge")
