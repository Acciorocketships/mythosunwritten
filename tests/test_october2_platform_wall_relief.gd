extends GutTest

func _wall() -> BuildingMass:
 var mass := BuildingMass.new()
 mass.stable_id = &"wall-relief"
 mass.seed = 318
 var cells := {}
 for x in 4:
  for z in 2: cells[Vector2i(x,z)] = true
 var storey := mass.add_storey(0,cells,BuildingMass.MATERIAL_STONE)
 storey.fortified = true
 return mass

func test_street_wall_has_relief_inside_its_existing_envelope_without_rejected_arches() -> void:
 var kit := SuntailBuildingKit.create()
 var assembler := BuildingKitAssembler.new(kit)
 assembler.public_floor = func(cell: Vector2i, band: int) -> bool:
  return band==0 and cell.y==-1
 var parts := assembler.assemble(_wall())
 var bounds := EnvironmentCatalog.load_default().descriptor(&"suntail.stone.stone_wall_plain").measured_aabb
 var arches := 0
 var courses := 0
 var pilasters := 0
 for part: Dictionary in parts:
  var detail := StringName(part.get("fort_detail",&""))
  if detail == &"": continue
  arches += int(detail==&"blind_arch")
  courses += int(detail==&"course")
  pilasters += int(detail==&"pilaster")
  var edge: Vector3i = part.fort_detail_edge
  var outward: Vector2i = BuildingMass.DIRS[edge.z]
  var box: AABB = part.transform*EnvironmentCatalog.load_default().descriptor(part.asset_id).measured_aabb
  var face := Vector2(edge.x+0.5,edge.y+0.5)*kit.module_width+Vector2(outward)*kit.module_width*0.5
  for corner in 8:
   var point := box.get_endpoint(corner)
   assert_lte((Vector2(point.x,point.z)-face).dot(Vector2(outward)),0.095,
    "relief cannot advance beyond the original wall into the public street")
  if detail==&"blind_arch": assert_eq(edge.z,3,"arches face the actual lower street")
 assert_eq(arches,0,"the owner rejected the repeated stone arches")
 assert_gt(courses,0,"horizontal stone bands break up the blank face")
 assert_eq(pilasters,0,"the owner rejected the repeated grid of pilasters")

func test_tall_wall_has_one_cornice_at_its_rim_not_a_grid_at_each_storey() -> void:
 var mass := _wall()
 var upper := mass.add_storey(2,mass.storeys[0].cells,BuildingMass.MATERIAL_STONE)
 upper.fortified = true
 var assembler := BuildingKitAssembler.new(SuntailBuildingKit.create())
 var courses := 0
 for part: Dictionary in assembler.assemble(mass):
  if StringName(part.get("fort_detail",&""))!=&"course": continue
  courses += 1
  assert_gt((part.transform as Transform3D).origin.y,3.0,"only the exposed top receives a cornice")
 assert_gt(courses,0)

func test_no_street_means_no_blind_arcade_and_gate_openings_stay_clear() -> void:
 var assembler := BuildingKitAssembler.new(SuntailBuildingKit.create())
 var mass := _wall()
 var plain := assembler.assemble(mass)
 for part: Dictionary in plain: assert_ne(StringName(part.get("fort_detail",&"")),&"blind_arch")
 mass.storeys[0].gates = {Vector3i(1,0,3):true,Vector3i(2,0,3):false}
 assembler.public_floor = func(cell: Vector2i, band: int) -> bool: return band==0 and cell.y==-1
 var parts := assembler.assemble(mass)
 for part: Dictionary in parts:
  if not part.has("fort_detail_edge"): continue
  assert_false((mass.storeys[0].gates as Dictionary).has(part.fort_detail_edge),"ornamental relief yields to gates")

func test_upper_corner_turret_cannot_drop_through_a_lower_tunnel() -> void:
 var mass := BuildingMass.new()
 mass.stable_id = &"tunnel-corner"
 mass.ground_band = 0
 var storey := mass.add_storey(6,{Vector2i.ZERO:true},BuildingMass.MATERIAL_STONE)
 storey.fortified = true
 var kit := SuntailBuildingKit.create()
 var assembler := BuildingKitAssembler.new(kit)
 var air := AABB(Vector3(-0.2,0,-0.2),Vector3(0.4,3,0.4))
 assembler.overhead_solids = [{"open":true,"bounds":air}]
 var bounds := EnvironmentCatalog.load_default().descriptor(&"suntail.stone.stone_wall_plain").measured_aabb
 var intrusions := 0
 for part: Dictionary in assembler.assemble(mass):
  if (part.transform*EnvironmentCatalog.load_default().descriptor(part.asset_id).measured_aabb as AABB).intersects(air): intrusions += 1
 assert_eq(intrusions,0,"a decorative corner tower cannot descend across public passage air")

func test_battlements_yield_to_an_upper_room_beside_the_rim() -> void:
 var mass := BuildingMass.new()
 mass.stable_id = &"inhabited-rim"
 var storey := mass.add_storey(0,{Vector2i.ZERO:true},BuildingMass.MATERIAL_STONE)
 storey.fortified = true
 var kit := SuntailBuildingKit.create()
 var assembler := BuildingKitAssembler.new(kit)
 assembler.external_blocked = func(cell: Vector2i, band: int) -> bool:
  return cell==Vector2i.RIGHT and band==2
 var face := AABB(Vector3(kit.module_width-0.02,kit.band_height()*2+0.01,kit.module_width*0.25),
  Vector3(0.04,1.0,kit.module_width*0.5))
 var bounds := EnvironmentCatalog.load_default().descriptor(&"suntail.stone.stone_wall_plain").measured_aabb
 var blocked := 0
 for part: Dictionary in assembler.assemble(mass):
  if (part.transform*EnvironmentCatalog.load_default().descriptor(part.asset_id).measured_aabb as AABB).intersects(face): blocked += 1
 assert_eq(blocked,0,"an inhabited facade closes the rim; battlements must not cover its windows or doors")
