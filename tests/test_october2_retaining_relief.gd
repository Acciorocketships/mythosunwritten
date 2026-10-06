extends GutTest
const RELIEF := preload("res://scripts/terrain/features/villages/kit/KitRetainingRelief.gd")
func test_native_corbels_keep_whole_geometry_and_clear_finished_air() -> void:
 var catalog := EnvironmentCatalog.load_default()
 var kit := SuntailBuildingKit.create()
 var mass := BuildingMass.new()
 mass.stable_id = &"kit.retained"
 var storey := mass.add_storey(2,BuildingMass.rect_cells(Rect2i(0,0,6,3)),BuildingMass.MATERIAL_STONE)
 storey.retaining=true
 var parts := RELIEF.fit([mass],[],kit,catalog,[],[])
 assert_gt(parts.size(),0)
 for part: Dictionary in parts:
  assert_eq(part.transform.basis.get_scale(),Vector3.ONE,"Native corbels are not stretched or clipped.")
  assert_lte(part.bounds.end.y,4*kit.band_height())
  assert_true(part.collision)
 var occupied: Array[Dictionary] = [{"bounds":AABB(Vector3(-100,-100,-100),Vector3(200,200,200))}]
 assert_eq(RELIEF.fit([mass],[],kit,catalog,occupied,[]).size(),0)
 assert_eq(RELIEF.fit([mass],parts,kit,catalog,[],[]).size(),0,"Repeated fitting must not duplicate existing relief.")

func test_real_holdout_keeps_public_air_and_masonry_supports() -> void:
 var catalog := EnvironmentCatalog.load_default()
 var kit := SuntailBuildingKit.create()
 var program := SettlementFabricProgram.compile(catalog)
 for seed_value in [41,67]:
  var spatial := WarrenVolumetricSolver.generate(seed_value,{},program,WarrenVillageScaleProfile.for_id(&"large"))
  assert_not_null(spatial)
  if spatial==null:continue
  var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),kit)
  # Arched panels and corbels now compete for the same wall area.
  # A holdout may choose either complete native treatment.
  assert_gt(int(built.roof_audit.retaining_relief)+int(built.roof_audit.get("retaining_windows",0)),0)
  assert_eq(int(preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built,kit).intrusions),0)
  for mass: BuildingMass in built.masses:
   if mass.stable_id!=&"kit.retained":continue
   for storey: Dictionary in mass.storeys:
    assert_eq(storey.material,BuildingMass.MATERIAL_STONE)

func test_tall_retained_faces_have_relief_below_the_crown() -> void:
 var catalog := EnvironmentCatalog.load_default()
 var kit := SuntailBuildingKit.create()
 var mass := BuildingMass.new()
 mass.stable_id = &"kit.retained"
 for band in [0,2,4]:
  var storey := mass.add_storey(band,BuildingMass.rect_cells(Rect2i(0,0,6,3)),BuildingMass.MATERIAL_STONE)
  storey.retaining = true
 var parts := RELIEF.fit([mass],[],kit,catalog,[],[])
 var tiers := {}
 for part: Dictionary in parts:
  tiers[roundi(part.bounds.end.y / kit.storey_height)] = true
 assert_true(tiers.has(1),"A six-band retained face needs depth in its lower course.")
 assert_true(tiers.has(2),"Intermediate masonry must not wait for an exposed crown.")
 assert_true(tiers.has(3))
 assert_eq(kit.roles[&"wall.stone.retaining"],[&"pure_village.wall.stone.plain"],
  "Native masonry must not repeat a timber grid across the retained earth.")

func test_corbel_seats_under_a_floor_instead_of_losing_the_whole_course() -> void:
 var catalog := EnvironmentCatalog.load_default()
 var kit := SuntailBuildingKit.create()
 var mass := BuildingMass.new()
 mass.stable_id = &"kit.retained"
 var storey := mass.add_storey(0,BuildingMass.rect_cells(Rect2i(0,0,6,3)),BuildingMass.MATERIAL_STONE)
 storey.retaining = true
 var original := RELIEF.fit([mass],[],kit,catalog,[],[])
 assert_false(original.is_empty())
 if original.is_empty(): return
 var candidate: Dictionary = original[0]
 var asset: StringName = kit.roles[&"deck.board"][0]
 var floor_box: AABB = catalog.descriptor(asset).measured_aabb
 var floor_pose := Transform3D(Basis.IDENTITY,Vector3(candidate.bounds.get_center().x-floor_box.get_center().x,
  candidate.bounds.end.y-0.002-floor_box.position.y,candidate.bounds.get_center().z-floor_box.get_center().z))
 var parts: Array[Dictionary] = [{"asset_id":asset,"role":&"deck.board","stable_id":&"kit.house/floor","transform":floor_pose}]
 var fitted := RELIEF.fit([mass],parts,kit,catalog,[],[])
 var found := false
 for part: Dictionary in fitted:
  if not is_equal_approx(part.transform.origin.x,candidate.transform.origin.x) or not is_equal_approx(part.transform.origin.z,candidate.transform.origin.z):continue
  found = true
  assert_false(part.bounds.intersects(floor_pose*floor_box))
  assert_lt(part.transform.origin.y,candidate.transform.origin.y)
  assert_gt(part.transform.origin.y,candidate.transform.origin.y-0.01)
  assert_eq(part.transform.basis,candidate.transform.basis)
 assert_true(found,"A two-millimetre floor/cap conflict should seat the whole native support below that floor.")

 # The tiny downward seat must still clear the air beneath it.
 var below: AABB = candidate.bounds
 below.position.y -= 0.004
 below.size.y = 0.003
 var low_air: Array[Dictionary] = [{"bounds":below}]
 for part: Dictionary in RELIEF.fit([mass],parts,kit,catalog,low_air,[]):
  assert_false(is_equal_approx(part.transform.origin.x,candidate.transform.origin.x) and is_equal_approx(part.transform.origin.z,candidate.transform.origin.z),
   "Seating cannot move a support into public headroom below it.")
 # A floor halfway through the support is a real obstruction, not seating.
 parts[0].transform.origin.y -= 1.0
 for part: Dictionary in RELIEF.fit([mass],parts,kit,catalog,[],[]):
  assert_false(is_equal_approx(part.transform.origin.x,candidate.transform.origin.x) and is_equal_approx(part.transform.origin.z,candidate.transform.origin.z),
   "Do not shift an entire native support around an intersecting room floor.")
