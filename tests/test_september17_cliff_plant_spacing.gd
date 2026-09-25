extends GutTest
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
func _forms()->Array:
 ROCKS.prepare()
 var forms:Array=[]
 for entry:Array in FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var():
  forms.append_array(ROCKS.CRAGS.make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4]))
 return forms
func test_leaf_canopies_do_not_crowd_neighboring_crevices()->void:
 var forms:=_forms()
 var plants:=ROCKS.plants(forms,null,2697992464)
 var planted:Dictionary={}
 for plant:Dictionary in plants:planted[plant.support_id]=true
 assert_eq(planted.size(),forms.size(),"Retain crevice planting on every photographed formation")
 var crowded:=0
 for i in plants.size():
  for j in range(i+1,plants.size()):
   var a:AABB=plants[i].bounds;var b:AABB=plants[j].bounds
   var overlap:=a.intersection(b)
   if overlap.get_volume()>.15*minf(a.get_volume(),b.get_volume()):crowded+=1
 print("CLIFF_PLANTS count=",plants.size()," crowded=",crowded," fern_bounds=",ROCKS._definitions[ROCKS.PLANTS[0]].bounds)
 assert_gt(plants.size(),8,"Retain a planted cliff rather than removing all foliage")
 assert_eq(crowded,0,"Use actual transformed canopy extents instead of root spacing alone")

func _poses(plants:Array)->Dictionary:
 var out:Dictionary={}
 for plant:Dictionary in plants:out[plant.id]=plant.transform
 return out

func test_neighbor_order_and_owner_selection_preserve_canopy_winners()->void:
 var forms:=_forms()
 var full:=_poses(ROCKS.plants(forms,null,2697992464))
 var reverse:=forms.duplicate();reverse.reverse()
 assert_eq(_poses(ROCKS.plants(reverse,null,2697992464)),full,"Input order must not choose which fern survives")
 var split:Dictionary={}
 var middle:=forms.size()/2
 for subset:Array in [forms.slice(0,middle),forms.slice(middle)]:
  split.merge(_poses(ROCKS.plants(subset,null,2697992464,null,null,forms)))
 assert_eq(split,full,"The same halo must yield the same plants when ownership is split")

func test_real_chunk_halos_keep_the_same_plants()->void:
 ROCKS.prepare()
 var plan:=HeightfieldPlan.new(17,64,12,"mean",4)
 plan.set_raw_height_override(func(x:int,_z:int)->float:return 16.0 if x<=3 else 0.0)
 var region:=plan.compute_region(4,4,12)
 var full:Dictionary={};var split:Dictionary={}
 var data:=ROCKS.compute(region,0,0,8,99)
 for plant:Dictionary in data.placements:
  if plant.kind=="foliage":full[plant.id]=plant.transform
 for origin:Vector2i in [Vector2i(0,0),Vector2i(4,0),Vector2i(0,4),Vector2i(4,4)]:
  var partial:=ROCKS.compute(region,origin.x,origin.y,4,99)
  for plant:Dictionary in partial.placements:
   if plant.kind=="foliage":split[plant.id]=plant.transform
 assert_gt(full.size(),5,"Exercise actual emitted plants")
 assert_eq(split,full,"Independent chunk halos must not move or duplicate foliage")
