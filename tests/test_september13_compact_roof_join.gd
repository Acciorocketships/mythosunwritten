extends GutTest

func test_reported_compact_branch_joins_the_continuing_roof_across_its_ridge() -> void:
 var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
 var fabric := frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/07-platform/current-source.txt"),program).compiled_fabric_cache()
 var branch: FabricUnit
 var host: FabricUnit
 for unit: FabricUnit in fabric.units:
  if unit.stable_id == &"spatial.roof.spatial.maze_back.03.room00": branch = unit
  if unit.stable_id == &"spatial.roof.spatial.parcel.maze.house.031.part00.room00": host = unit
 assert_not_null(branch,"The photographed tower crown is retained")
 assert_not_null(host,"The adjacent continuing townhouse crown is retained")
 if branch == null or host == null: return
 var branch_recipe := program.recipe(branch.recipe_id)
 var host_recipe := program.recipe(host.recipe_id)
 var branch_axis := branch.transform().basis * (Vector3.RIGHT if branch_recipe.has_tag(&"ridge_x") else Vector3.BACK)
 var host_axis := host.transform().basis * (Vector3.RIGHT if host_recipe.has_tag(&"ridge_x") else Vector3.BACK)
 assert_almost_eq(absf(branch_axis.normalized().dot(host_axis.normalized())),0.0,.00001,"The branch ridge must enter the continuing roof at a right angle")
 assert_true(branch_recipe.has_tag(&"open_gable_branch"),"The internal branch gable belongs to the joined roof construction")
 assert_true(host_recipe.has_tag(&"bisected_valley_host"),"The host owns complementary slopes at the branch junction")

 var continuous := FabricContinuousRoofPlan.compile(fabric)
 assert_true(continuous.suppressed_placement_ids.has(StringName("%s/roof.adjacent" % host.stable_id)),"The joined host stays in the continuing roof run")
 var cut_roles: Dictionary={}
 for section: Dictionary in continuous.synthetic_placements:
  var asset:=String(section.asset_id)
  if ".03.valley." in asset: cut_roles[asset.get_slice(".",asset.get_slice_count(".")-1)]=true
 assert_eq(cut_roles.size(),3,"The continuous run retains all three complementary native valley sections")
 var chimney: Dictionary={}
 for placement: Dictionary in branch_recipe.placements:
  if placement.id==&"chimney": chimney=placement
 assert_false(chimney.is_empty(),"The original chimney survives the junction choice")
 if not chimney.is_empty():
  var old_recipe:=program.recipe(&"roof.tower.short.blue")
  var old_chimney: Dictionary={}
  for placement: Dictionary in old_recipe.placements:
   if placement.id==&"chimney": old_chimney=placement
  assert_false(old_chimney.is_empty())
  if not old_chimney.is_empty():
   var room: FabricUnit
   for unit: FabricUnit in fabric.units:
    if unit.stable_id==branch.parent_ids[0]: room=unit
   assert_not_null(room)
   if room!=null:
    var old_centre:=room.transform()*Vector3(-.75,3.0,-.75)
    var old_pose:=Transform3D(room.transform().basis,old_centre-room.transform().basis*Vector3(-.75,0,-.75))
    assert_true((branch.transform()*(chimney.transform as Transform3D)).is_equal_approx(old_pose*(old_chimney.transform as Transform3D)),"Chimney native pose remains unchanged in world space")

func test_second_photo_keeps_the_two_sided_dormered_roof_complete() -> void:
 var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var frozen:=preload("res://tests/fixtures/frozen_maze_source.gd")
 var fabric:=frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/11-roof-joins/P31-current-source.txt"),program).compiled_fabric_cache()
 var middle: FabricUnit
 for unit: FabricUnit in fabric.units:
  if unit.stable_id==&"spatial.roof.spatial.maze_back.06.room00": middle=unit
 assert_not_null(middle)
 if middle==null:return
 assert_eq(middle.recipe_id,&"roof.tower.orange.dormer.right","The two-sided middle crown cannot be replaced with the one-sided compact branch")
 var recipe:=program.recipe(middle.recipe_id)
 assert_true(recipe.has_tag(&"dormer"))
 assert_true(recipe.compact_roof_junction.is_empty())
