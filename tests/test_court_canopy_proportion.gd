extends GutTest

func test_small_islands_keep_open_ground_while_large_islands_allow_markets():
 var catalog := EnvironmentCatalog.load_default()
 var bounds := {}
 for asset: StringName in SettlementFabricAssembler.PLAZA_WIDE_FEATURES + SettlementFabricAssembler.PLAZA_COURT_TREES:
  bounds[asset] = catalog.descriptor(asset).measured_aabb
 var markets := 0
 for width in [3, 6]:
  for offset in 12:
   var bed := {}
   for x in width:
    for z in width: bed[Vector3i(x+offset*8,0,z)] = true
   var feature := SettlementFabricAssembler.maze_plaza_centre_feature(bed,{}, {'asset_bounds':bounds},[],{},true,1)
   assert_false(feature.is_empty())
   if feature.get('asset', &'') == SettlementFabricAssembler.PLAZA_MARKET_STALL:
    if width == 3: fail_test('A canopy must not roof most of a small planting island')
    else: markets += 1
 assert_gt(markets,0,'Large greens retain seeded market variation')

func test_other_courts_and_reserved_walks_cannot_pay_for_a_large_canopy():
 var asset := SettlementFabricAssembler.PLAZA_MARKET_STALL
 var bounds := {asset:EnvironmentCatalog.load_default().descriptor(asset).measured_aabb}
 var bed := {}
 for x in 3:
  for z in 3: bed[Vector3i(x,0,z)] = true
 for x in range(3,12):
  for z in 3: bed[Vector3i(x,0,z)] = true
 var feature := {'asset':asset,'cell':Vector3i(1,0,1)}
 assert_true(SettlementFabricAssembler._plaza_canopy_proportional(feature,bed,{}, {'asset_bounds':bounds}))
 var walkway := {}
 for z in 3: walkway[Vector3i(3,0,z)] = true
 assert_false(SettlementFabricAssembler._plaza_canopy_proportional(feature,bed,walkway, {'asset_bounds':bounds}), 'The reserved crossing splits the planting domain')
 for z in 3: bed.erase(Vector3i(3,0,z))
 assert_false(SettlementFabricAssembler._plaza_canopy_proportional(feature,bed,{}, {'asset_bounds':bounds}), 'A disconnected distant garden contributes no area')
