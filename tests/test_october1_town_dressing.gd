extends GutTest
const DRESS := preload("res://scripts/terrain/features/villages/TownGroundDressing.gd")

func test_woodland_includes_true_urban_and_heavily_wooded_towns() -> void:
 var urban := 0
 var wooded := 0
 for seed_value in 100:
  var density := DRESS.woodland(seed_value)
  assert_eq(density,DRESS.woodland(seed_value))
  if density == 0: urban += 1
  if density > 0.8: wooded += 1
 assert_gt(urban,5)
 assert_gt(wooded,5)

func test_dressing_assets_have_runtime_geometry_and_collision() -> void:
 var catalog := EnvironmentCatalog.load_default()
 for id in DRESS.asset_ids():
  var descriptor := catalog.descriptor(id)
  assert_not_null(descriptor)
  if descriptor == null: continue
  assert_true(descriptor.measured_aabb.has_volume())
  assert_gt(descriptor.collision_piece_count,0, "dressing must not be walk-through: %s" % id)

class FlatGround extends VillageTerrainView:
 func surface_y(_point: Vector2) -> float: return 2.0
 func is_wet(_point: Vector2) -> bool: return false

func test_group_is_grounded_and_rejected_atomically_at_a_walk() -> void:
 var town := VillageUrbanFabricPlan.new()
 town.public_walk_network_id = &"test-town"
 var bounds := {DRESS.BARREL: AABB(Vector3(-0.5,-0.1,-0.5),Vector3(1,1.2,1))}
 var allowed := {}
 for z in range(-3,4):
  for x in range(-3,4): allowed[Vector2i(x,z)] = true
 var placed: Array[FeatureGroundShape] = []
 var group := [{"asset": DRESS.BARREL,"offset":Vector2.ZERO},
  {"asset": DRESS.BARREL,"offset":Vector2(2,0)}]
 var walk := FeatureGroundShape.axis_rect(Rect2(Vector2(1.5,-1),Vector2(2,2)))
 var blocked := FeatureGroundField.new([], [walk], 2)
 assert_false(DRESS._place_group(town,group,Vector2.ZERO,0,bounds,FlatGround.new(),
  blocked,placed,allowed,Transform3D.IDENTITY,"blocked"))
 assert_eq(town.entries.size(),0,"one blocked companion rejects the entire group")
 var clear := FeatureGroundField.new([], [], 2)
 assert_true(DRESS._place_group(town,group,Vector2.ZERO,0,bounds,FlatGround.new(),
  clear,placed,allowed,Transform3D.IDENTITY,"clear"))
 assert_eq(town.entries.size(),2)
 for entry: Dictionary in town.entries:
  assert_almost_eq((entry.transform as Transform3D).origin.y,2.1,0.0001,"measured foot meets terrain")
 assert_eq(town.clearances.size(),2)

func test_real_green_accepts_dressing_without_using_walks() -> void:
 var source := WarrenMazeSitePlanner.plan(6, {}, WarrenVillageScaleProfile.for_id(&"large"), &"", false)
 assert_not_null(source)
 if source == null: return
 var catalog := EnvironmentCatalog.load_default()
 var program := SettlementFabricProgram.compile(catalog)
 var spatial := preload("res://tests/fixtures/frozen_maze_source.gd").spatial(source,program)
 var town := VillageUrbanFabricPlan.new()
 town.world_transform = Transform3D(VillageWorldScale.production_basis(0),Vector3.ZERO)
 VillageWarrenFabricSolver._append_typed_occupancy(town,spatial.compiled_fabric_cache(),town.world_transform,&"test",0)
 VillageWarrenFabricSolver._append_physical_ground_clearance(town,&"test")
 var repeated := VillageUrbanFabricPlan.new()
 repeated.public_walk_network_id = town.public_walk_network_id
 repeated.world_transform = town.world_transform
 repeated.volumes.assign(town.volumes)
 repeated.surfaces.assign(town.surfaces)
 repeated.clearances.assign(town.clearances)
 var bounds := {}
 for id in DRESS.asset_ids(): bounds[id] = catalog.descriptor(id).measured_aabb
 var audit := DRESS.dress(town,source,bounds,FlatGround.new(),6)
 gut.p("real town dressing: %s" % audit)
 assert_gt(int(audit.props)+int(audit.trees),0,"reserved greens must actually admit measured assets")
 assert_eq(town.entries.size(),int(audit.props)+int(audit.trees))
 assert_gt(int(audit.trees),0,"a wooded town must admit a real tree, not only roll a density")
 for entry: Dictionary in town.entries:
  if entry.asset_id in DRESS.TREES: assert_ne(entry.color,Color.WHITE,"foliage inherits the biome tint")
 var repeated_audit := DRESS.dress(repeated,source,bounds,FlatGround.new(),6)
 assert_eq(repeated_audit,audit,"rebuilding the town preserves accepted groups and trees")
 assert_eq(repeated.entries,town.entries,"streaming reentry preserves asset IDs, transforms and colours")

func test_production_registers_dressing_and_both_building_families() -> void:
 var program := VillageProgram.compile({},EnvironmentCatalog.load_default())
 assert_not_null(program)
 if program == null: return
 var styles := preload("res://scripts/terrain/features/villages/kit/TownBuildingStyles.gd")
 var ids := DRESS.asset_ids()
 for seed_value in 100:
  var kit := styles.for_house(SuntailBuildingKit.create(),seed_value,&"registered-house")
  ids.append_array(kit.all_asset_ids())
 assert_true(ids.has(&"pure_village.roof.eave"),"exercise native Pure Village roof demand")
 for id in ids:
  assert_true(program.referenced_asset_ids.has(id),"runtime demand includes %s" % id)
  assert_true(program.runtime_aabbs.has(id))

func test_context_groups_fit_measured_companions_and_cover_new_packs() -> void:
 var catalog := EnvironmentCatalog.load_default()
 var bounds := {}
 for id in DRESS.asset_ids(): bounds[id] = catalog.descriptor(id).measured_aabb
 var allowed := {}
 for z in range(-10,11):
  for x in range(-10,11): allowed[Vector2i(x,z)] = true
 var seen := {}
 for seed_value in 24:
  var rng := RandomNumberGenerator.new()
  rng.seed = seed_value
  for purpose: StringName in [&"workyard",&"market",&"courtyard",&"grove",&"green"]:
   var group := DRESS._group(purpose,rng)
   var town := VillageUrbanFabricPlan.new()
   var placed: Array[FeatureGroundShape] = []
   assert_true(DRESS._place_group(town,group,Vector2.ZERO,rng.randf()*TAU,bounds,
    FlatGround.new(),FeatureGroundField.new([],[],2),placed,allowed,
    Transform3D.IDENTITY,"context"),"complete %s group fits its own measured parts" % purpose)
   for item: Dictionary in group: seen[item.asset] = true
 for id in [DRESS.CAULDRON,DRESS.HERBALIST,DRESS.VEGETABLE_STALL,DRESS.BAKERY,
   DRESS.FORGE_ANVIL,DRESS.TAVERN_TABLE,DRESS.TAVERN_BENCH,DRESS.GARDEN_BENCH,DRESS.TENT]:
  assert_true(seen.has(id),"contextual groups use %s" % id)

func test_vendor_front_faces_nearest_ground_street() -> void:
 var streets: Array[Vector2] = [Vector2(8,0),Vector2(0,20)]
 var yaw := DRESS._street_facing(Vector2.ZERO,streets,PI)
 var front := Basis(Vector3.UP,yaw)*Vector3.BACK
 assert_lt(front.distance_to(Vector3.RIGHT),0.0001)

func test_vendor_does_not_face_a_street_through_a_wall() -> void:
 var streets: Array[Vector2] = [Vector2(8,0),Vector2(0,12)]
 var blockers: Array[FeatureGroundShape] = [FeatureGroundShape.axis_rect(Rect2(Vector2(3,-3),Vector2(1,6)))]
 var yaw := DRESS._street_facing(Vector2.ZERO,streets,NAN,blockers)
 assert_lt((Basis(Vector3.UP,yaw)*Vector3.BACK).distance_to(Vector3.BACK),0.0001)
 blockers.append(FeatureGroundShape.axis_rect(Rect2(Vector2(-3,3),Vector2(6,1))))
 assert_true(is_nan(DRESS._street_facing(Vector2.ZERO,streets,NAN,blockers)))

func test_grove_crowns_can_join_but_trunks_and_buildings_stay_clear() -> void:
 var catalog := EnvironmentCatalog.load_default()
 var asset: StringName = DRESS.TREES[0]
 var bounds := {asset: catalog.descriptor(asset).measured_aabb}
 var allowed := {}
 for z in range(-10,11):
  for x in range(-10,11): allowed[Vector2i(x,z)] = true
 var town := VillageUrbanFabricPlan.new()
 town.public_walk_network_id = &"grove"
 var placed: Array[FeatureGroundShape] = []
 var bands := {}
 var group := [{"asset":asset,"offset":Vector2.ZERO,"scale":1.0}]
 var field := FeatureGroundField.new([],[],2)
 assert_true(DRESS._place_group(town,group,Vector2.ZERO,0,bounds,FlatGround.new(),
  field,placed,allowed,Transform3D.IDENTITY,"first",0,bands))
 assert_true(DRESS._place_group(town,group,Vector2(6,0),0,bounds,FlatGround.new(),
  field,placed,allowed,Transform3D.IDENTITY,"second",0,bands),
  "measured crowns may join above clear pedestrian space")
 assert_true(placed[0].intersects(placed[1]),"the test must exercise overlapping crowns")
 assert_false(DRESS._place_group(town,group,Vector2(0.5,0),0,bounds,FlatGround.new(),
  field,placed,allowed,Transform3D.IDENTITY,"trunk",0,bands),"trunks remain separated")
 town.volumes.append(VillageOccupancyVolume.new(VillageOccupancy.Role.SOLID,
  Vector2(12,0),Vector2(2,2),0,8,16,&"upper-room"))
 assert_false(DRESS._place_group(town,group,Vector2(12,0),0,bounds,FlatGround.new(),
  field,placed,allowed,Transform3D.IDENTITY,"wall",0,bands),"a crown cannot enter a building")
 assert_eq(town.entries.size(),2)

func test_natural_pockets_allow_planting_inside_town_without_carving_massifs() -> void:
 var massif := WarrenMassif.new(1)
 for z in 5:
  for x in 5:
   if x in [0,4] or z in [0,4]:
    massif.columns[Vector2i(x,z)] = {"base":0,"top":8,"terrace":8}
 var before := massif.columns.duplicate(true)
 var spaces := DRESS._planting_spaces(massif)
 assert_eq(spaces.size(),1)
 assert_eq(spaces[0].cells.size(),9,"the existing empty courtyard is eligible")
 assert_true(spaces[0].plant_only,"uncarved pockets do not invent markets or workyards")
 for column: Vector2i in spaces[0].cells:
  assert_true(column.x>0 and column.x<4 and column.y>0 and column.y<4)
  assert_false(massif.columns.has(column),"standing massifs stay unplantable")
 assert_eq(massif.columns,before,"planting never changes bearing heights or topology")
 assert_true(massif.open_spaces.is_empty(),"the original construction reservations stay unchanged")

func test_young_tree_can_fit_an_enclosed_garden_without_weakening_canopy_clearance() -> void:
 var catalog := EnvironmentCatalog.load_default()
 var asset := DRESS.TREES[0]
 var bounds := {asset:catalog.descriptor(asset).measured_aabb}
 var allowed := {}
 for z in range(-4,5):
  for x in range(-4,5): allowed[Vector2i(x,z)] = true
 var field := FeatureGroundField.new([],[],2)
 for height in [10.0,6.0]:
  var town := VillageUrbanFabricPlan.new()
  for axis in [Vector2.RIGHT,Vector2.DOWN]:
   for side in [-1.0,1.0]:
    town.volumes.append(VillageOccupancyVolume.new(VillageOccupancy.Role.SOLID,
     axis*3.9*side,Vector2(.5,10) if axis==Vector2.RIGHT else Vector2(10,.5),
     0,2,25,&"garden-wall"))
  var placed: Array[FeatureGroundShape] = []
  var group := [{"asset":asset,"offset":Vector2.ZERO,"scale":height/(bounds[asset] as AABB).size.y}]
  var accepted := DRESS._place_group(town,group,Vector2.ZERO,0,bounds,FlatGround.new(),
   field,placed,allowed,Transform3D.IDENTITY,"young-tree")
  assert_eq(accepted,height==6.0,"only the measured smaller crown fits between these walls")
  assert_eq(town.entries.size(),1 if height==6.0 else 0)

func test_large_urban_central_green_has_separated_activities_without_forcing_trees() -> void:
 var source := WarrenMazeSitePlanner.plan(17,{},WarrenVillageScaleProfile.for_id(&"large"),&"",false)
 var catalog := EnvironmentCatalog.load_default()
 var program := SettlementFabricProgram.compile(catalog)
 var spatial := preload("res://tests/fixtures/frozen_maze_source.gd").spatial(source,program)
 var town := VillageUrbanFabricPlan.new()
 town.world_transform = Transform3D(VillageWorldScale.production_basis(0),Vector3.ZERO)
 VillageWarrenFabricSolver._append_typed_occupancy(town,spatial.compiled_fabric_cache(),town.world_transform,&"activities",0)
 VillageWarrenFabricSolver._append_physical_ground_clearance(town,&"activities")
 var original_walks := town.surfaces.duplicate()
 var bounds := {}
 for id in DRESS.asset_ids(): bounds[id] = catalog.descriptor(id).measured_aabb
 var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),SuntailBuildingKit.create())
 for id: StringName in built.payload.asset_ids():
  bounds[id] = catalog.descriptor(id).measured_aabb
  var batch: Dictionary = built.payload.batches[id]
  for pose: Transform3D in batch.transforms:
   town.entries.append({"asset_id":id,"transform":town.world_transform*pose})
 var original_count := town.entries.size()
 var native_clearances := DRESS._native_ground_clearances(town,bounds,FlatGround.new())
 var audit := DRESS.dress(town,source,bounds,FlatGround.new(),17)
 var dressing_entries: Array = town.entries.slice(original_count)
 assert_eq(int(audit.trees),0,"urban remains a real no-tree variant")
 var centres: Array[Vector2] = []
 var streets: Array[Vector2] = []
 for cell: Vector3i in source.passage_kinds:
  if cell.y != source.massif.base_at(Vector2i(cell.x,cell.z)): continue
  var p: Vector3 = town.world_transform*Vector3(cell.x*3.0+0.75,0,cell.z*3.0+0.75)
  streets.append(Vector2(p.x,p.z))
 for entry: Dictionary in dressing_entries:
  var stable := String(entry.stable_id)
  if not stable.contains("group.open.central_ground.") or not stable.ends_with(".0"): continue
  var p: Vector3 = entry.transform.origin
  var centre := Vector2(p.x,p.z)
  centres.append(centre)
  var nearest := INF
  for street: Vector2 in streets: nearest = minf(nearest,street.distance_to(centre))
  assert_lt(nearest,12.01,"activities belong to the street edge, not isolated mid-lawn")
 assert_gt(centres.size(),2,"the broad central lawn hosts several distinct activities")
 for i in centres.size():
  for j in i:
   assert_gte(centres[i].distance_to(centres[j]),15.9,"activity areas retain generous intervening lawn")
 for entry: Dictionary in dressing_entries:
  var box: AABB = entry.transform * (bounds[entry.asset_id] as AABB)
  var shape := FeatureGroundShape.axis_rect(Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)))
  for native: FeatureGroundShape in native_clearances:
   assert_false(shape.intersects(native),"complete props clear the actual low facade pieces")
  for walk: FeatureGroundShape in original_walks:
   if walk.surface_id == FeatureGroundField.NATURAL: continue
   assert_false(shape.intersects(walk),"the complete prop envelope leaves the public route open")

func test_activity_facing_rejects_a_remote_street() -> void:
 var remote: Array[Vector2] = [Vector2(30,0)]
 assert_true(is_nan(DRESS._street_facing(Vector2.ZERO,remote,NAN,[],12.0)))
 assert_true(is_finite(DRESS._street_facing(Vector2.ZERO,remote,NAN)),"unbounded callers retain their behavior")

func test_ground_props_leave_room_for_projecting_facade_decoration() -> void:
 var town := VillageUrbanFabricPlan.new()
 town.volumes.append(VillageOccupancyVolume.new(VillageOccupancy.Role.SOLID,
  Vector2(2,0),Vector2(.2,5),0,2,10,&"house"))
 var bounds := {DRESS.BARREL:AABB(Vector3(-.5,0,-.5),Vector3(1,1,1))}
 var allowed := {}
 for z in range(-4,5):
  for x in range(-4,5): allowed[Vector2i(x,z)] = true
 var placed: Array[FeatureGroundShape] = []
 var group := [{"asset":DRESS.BARREL,"offset":Vector2.ZERO}]
 var field := FeatureGroundField.new([],[],2)
 assert_false(DRESS._place_group(town,group,Vector2.ZERO,0,bounds,FlatGround.new(),
  field,placed,allowed,Transform3D.IDENTITY,"wall-close"),"coarse body clearance alone cannot protect projecting trim")
 assert_true(DRESS._place_group(town,group,Vector2(-2,0),0,bounds,FlatGround.new(),
  field,placed,allowed,Transform3D.IDENTITY,"wall-clear"))

func test_finished_low_asset_bounds_protect_noncolliding_facade_details() -> void:
 var town := VillageUrbanFabricPlan.new()
 var bounds := {&"window_box":AABB(Vector3(-1,0,-.5),Vector3(2,1,1))}
 town.entries.append({"asset_id":&"window_box","transform":Transform3D(Basis.IDENTITY,Vector3(5,3,0)),"collision_enabled":false})
 town.entries.append({"asset_id":&"window_box","transform":Transform3D(Basis.IDENTITY,Vector3(5,10,0)),"collision_enabled":false})
 town.entries.append({"asset_id":&"window_box","transform":Transform3D(Basis.IDENTITY,Vector3(5,0,0)),"collision_enabled":false})
 var clearances := DRESS._native_ground_clearances(town,bounds,FlatGround.new())
 assert_eq(clearances.size(),1,"only low exposed native geometry reserves ground")
 var field := FeatureGroundField.new([],clearances,2)
 assert_true(field.overlaps_clearance(FeatureGroundShape.axis_rect(Rect2(4.5,-.25,1,.5)),0.6,false),"noncolliding flowers still block a canopy")
 assert_false(field.overlaps_clearance(FeatureGroundShape.axis_rect(Rect2(-2,-.25,1,.5)),0.6,false))
