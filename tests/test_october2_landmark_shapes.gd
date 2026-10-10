extends GutTest

func _feature(id: StringName, size: Vector2i) -> WarrenFeatureReservation:
 var feature := WarrenFeatureReservation.new(id,&"landmark")
 for x in size.x:
  for z in size.y:
   for y in 8: feature.reserved_cells.append(Vector3i(x,y,z))
 feature.audit.landmark_entrance_cell = Vector3i(size.x/2,0,0)
 feature.audit.landmark_public_landing_cell = feature.audit.landmark_entrance_cell+Vector3i.FORWARD
 return feature

func test_broad_landmarks_vary_into_connected_wings_without_losing_the_door() -> void:
 var shaped := 0
 var signatures := {}
 for seed in 24:
  var feature := _feature(StringName("landmark.%d" % seed),Vector2i(8,6))
  var house := KitVillageBuildings._landmark_house(feature)
  var floor: Dictionary = house.storeys[0]
  shaped += int(floor.size()<48)
  assert_true(floor.has(Vector2i(4,0)),"entrance survives the composition")
  assert_true(floor.has(Vector2i(3,0)),"door keeps a whole module pair")
  assert_gte(floor.size(),24,"wings retain substantial building area")
  var reached := {}
  var queue: Array[Vector2i] = [Vector2i(4,0)]
  while not queue.is_empty():
   var cell: Vector2i = queue.pop_back()
   if reached.has(cell): continue
   reached[cell]=true
   for direction: Vector2i in BuildingMass.DIRS:
    if floor.has(cell+direction) and not reached.has(cell+direction): queue.append(cell+direction)
  assert_eq(reached.size(),floor.size(),"all wings connect to the entrance")
  for cell: Vector2i in floor:
   var horizontal := floor.has(cell+Vector2i.LEFT) or floor.has(cell+Vector2i.RIGHT)
   var vertical := floor.has(cell+Vector2i.UP) or floor.has(cell+Vector2i.DOWN)
   assert_true(horizontal and vertical,"no one-module-wide roof slivers")
  signatures[str(floor.keys())]=true
  assert_eq(house,KitVillageBuildings._landmark_house(feature),"deterministic composition")
 assert_gte(shaped,16,"most broad landmark reservations become articulated houses")
 assert_gt(signatures.size(),3,"orientation and shape vary procedurally")

func test_small_landmark_keeps_its_complete_footprint() -> void:
 var house := KitVillageBuildings._landmark_house(_feature(&"small",Vector2i(4,4)))
 assert_eq((house.storeys[0] as Dictionary).size(),16)

func test_real_landmark_wings_keep_doors_bearing_and_roof_clearance() -> void:
 var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var shaped := 0
 for job: Array in [[13,&"large"],[58,&"large"],[7,&"standard"]]:
  var spatial := WarrenVolumetricSolver.generate(job[0],{},program,WarrenVillageScaleProfile.for_id(job[1]))
  assert_not_null(spatial)
  if spatial == null: continue
  var houses := KitVillageBuildings._houses(spatial)
  for id: StringName in houses:
   var house: Dictionary = houses[id]
   if not bool(house.get("landmark",false)): continue
   var floor: Dictionary = house.storeys[house.terrain_band]
   var bounds := BuildingDesigner._bounds(floor)
   if floor.size() == bounds.get_area(): continue
   shaped += 1
   for door: Dictionary in house.doors:
    var cell: Vector3i = door.cell
    assert_true(floor.has(Vector2i(cell.x,cell.z)),"composed wing preserves the actual entrance")
  var fabric := spatial.compiled_fabric_cache()
  var built := KitVillageBuildings.build(spatial,fabric,SuntailBuildingKit.create())
  assert_eq(int(KitFloatingMassAudit.audit(spatial,fabric,built.masses).count),0)
  var air := preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built,SuntailBuildingKit.create())
  assert_eq(int(air.intrusions),0,"articulated roofs stay out of public headroom")
 assert_gte(shaped,3,"the production pipeline actually realizes nonrectangular landmarks")
