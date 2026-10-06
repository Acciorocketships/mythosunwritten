extends GutTest
const FIELD := preload("res://scripts/terrain/features/villages/fabric/WarrenTownField.gd")

func test_small_independent_lobes_are_houses_but_merged_lobes_remain_massifs() -> void:
 var lobes: Array[Dictionary] = [
  {"centre":Vector2.ZERO,"width":Vector2(8,8),"height":18.0,"angle":0.0},
  {"centre":Vector2(15,0),"width":Vector2(3,3),"height":12.0,"angle":0.0},
  {"centre":Vector2(2,0),"width":Vector2(3,3),"height":12.0,"angle":0.0}]
 FIELD._classify_lobes(lobes)
 assert_eq(lobes[0].kind,&"massif")
 assert_eq(lobes[1].kind,&"house")
 assert_eq(lobes[1].storeys,1)
 assert_eq(lobes[2].kind,&"massif")
 assert_eq(lobes[0].height,18.0)

func test_house_lobes_survive_as_low_ground_level_sites() -> void:
 var sites := 0
 for seed_value in range(16):
  var massif := WarrenMassifBuilder.build(seed_value,{},WarrenVillageScaleProfile.for_id(&"large"))
  assert_not_null(massif)
  if massif == null: continue
  for column: Vector2i in massif.columns:
   var record: Dictionary = massif.columns[column]
   if not record.has("house_lobe"): continue
   sites += 1
   assert_between(int(record.house_storeys),1,2)
   assert_false(WarrenPassageLatticeRules.slot_is_borable(massif,WarrenExcavation.new(seed_value),
    Vector3i(column.x,massif.base_at(column)+1,column.y),3))
 assert_gt(sites,10,"the real mixture must actually contain small-house territory")

func test_built_house_sites_remain_low_and_do_not_leave_unbuilt_rock() -> void:
 var houses := 0
 for seed_value in [6,9,10,12]:
  var source := WarrenMazeSitePlanner.plan(seed_value,{},WarrenVillageScaleProfile.for_id(&"large"),&"",false)
  assert_not_null(source,WarrenMazeSitePlanner.last_failure)
  if source == null: continue
  for column: Vector2i in source.massif.columns:
   var record: Dictionary = source.massif.columns[column]
   if not record.has("house_lobe"): continue
   var plots := source.plots_at(column)
   if plots.is_empty():
    assert_eq(source.rock_shoulder(column),source.massif.base_at(column))
   for index: int in plots:
    var plot: Dictionary = source.plots[index]
    if plot.kind != WarrenMazeSourcePlan.PLOT_HOUSE: continue
    houses += 1
    assert_lte(int(plot.top),source.massif.base_at(column)+int(record.house_storeys)*WarrenBuildingParcel.STOREY_BANDS+WarrenBuildingParcel.ROOF_RESERVATION_BANDS)
 assert_gt(houses,4,"generated small-lobe territory must contain actual houses")

func test_reserved_house_sites_are_occupied_by_reachable_houses() -> void:
 var checked := 0
 for seed_value in [6,9,10,12]:
  var source := WarrenMazeSitePlanner.plan(seed_value,{},WarrenVillageScaleProfile.for_id(&"large"),&"",false)
  assert_not_null(source)
  if source == null: continue
  var sites := {}
  for column: Vector2i in source.massif.columns:
   var record: Dictionary = source.massif.columns[column]
   if not record.has("house_site"): continue
   var id := int(record.house_site)
   if not sites.has(id): sites[id] = {}
   for index: int in source.plots_at(column):
    var plot: Dictionary = source.plots[index]
    if plot.kind != WarrenMazeSourcePlan.PLOT_HOUSE: continue
    sites[id][plot.id] = true
    assert_true(source.passage_kinds.has(plot.door_walk))
  for id in sites:
   checked += 1
   assert_gt((sites[id] as Dictionary).size(),0,"seed %d house site %d needs an actual addressed house" % [seed_value,id])
 assert_gt(checked,2)

func test_native_landmark_clearance_preserves_reserved_cottage_sites() -> void:
 var source := WarrenMazeSitePlanner.plan(12,{},WarrenVillageScaleProfile.for_id(&"large"),&"reserve",false)
 assert_not_null(source)
 if source == null: return
 var checked := 0
 for column: Vector2i in source.massif.columns:
  if not source.massif.columns[column].has("house_site"): continue
  checked += 1
  assert_false(WarrenPlotPlanner._asset_clearance_blocks(source,column,source.massif.base_at(column)),
   "native eaves cannot erase the cottage frontage reserved before the landmark")
 assert_gt(checked,0)
