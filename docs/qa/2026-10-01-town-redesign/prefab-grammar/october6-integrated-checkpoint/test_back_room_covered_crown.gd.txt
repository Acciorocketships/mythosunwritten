extends GutTest

func test_an_inhabited_ceiling_needs_no_separate_roof():
 var setup := _rooms()
 assert_true(WarrenVolumetricSolver._residual_roof_envelope_fits(
  setup.lower, setup.hosts, setup.program, 53),
  "A completely covered lower room must not require a roof inside its upper room")

func test_partial_cover_still_requires_a_fitting_roof():
 var setup := _rooms()
 var upper: WarrenRoomStamp = setup.upper
 for cell: Vector3i in upper.private_cells.duplicate():
  if cell.y == upper.lattice_origin.y:
   upper.private_cells.erase(cell)
   break
 assert_false(WarrenVolumetricSolver._residual_roof_envelope_fits(
  setup.lower, setup.hosts, setup.program, 53),
  "One missing ceiling cell cannot bypass the exposed-roof checks")

func _room(id: StringName, origin: Vector3i) -> WarrenRoomStamp:
 var result := WarrenRoomStamp.new(id, id, &"tower", origin, 0, 0, true, false,
  Vector3i(2147483647,2147483647,2147483647), Vector3i.ZERO, 0, &"", -1, 0, true)
 result.private_cells.assign(WarrenRoomStamp.expected_private_cells(&"tower",origin,0))
 return result

func _rooms() -> Dictionary:
 var lower := _room(&"lower", Vector3i.ZERO)
 var upper := _room(&"upper", Vector3i(0,2,0))
 var building := WarrenBuildingVolume.new(&"upper",2)
 building.room_records.append(upper)
 building.private_cells.assign(upper.private_cells)
 return {"lower":lower,"upper":upper,"hosts":{&"upper":building},
  "program":SettlementFabricProgram.compile(EnvironmentCatalog.load_default())}
