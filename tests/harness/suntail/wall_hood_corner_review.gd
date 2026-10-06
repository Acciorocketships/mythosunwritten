extends "res://tests/harness/suntail/building_gallery.gd"
## Connected native shallow canopies, independent of the town planner.
func _run() -> void:
 get_root().size=Vector2i(1400,1000)
 var kit := SuntailBuildingKit.create()
 var mass := BuildingMass.new()
 mass.stable_id=&"hood.corner.fixture"
 var inner := OS.get_cmdline_user_args().has("--inner")
 var cells := BuildingMass.rect_cells(Rect2i(0,0,4,4) if inner else Rect2i(0,0,3,3))
 if inner:
  for x in range(2,4):
   for z in range(2,4):cells.erase(Vector2i(x,z))
 var lower := mass.add_storey(0,cells,BuildingMass.MATERIAL_TIMBER)
 lower.pent_colour=&"blue"
 var upper := mass.add_storey(2,cells,BuildingMass.MATERIAL_STONE)
 upper.retaining=true
 var assembler := BuildingKitAssembler.new(kit)
 var payload := EnvironmentInstancePayload.new()
 BuildingKitAssembler.append_to_payload(assembler.assemble(mass),Transform3D.IDENTITY,payload)
 var stage := _stage()
 await _commit(stage,payload)
 if inner:
  await _shoot(stage,Vector3(17,11,17),Vector3(4,3,4),"inner-corner",45)
  await _shoot(stage,Vector3(11,4.5,11),Vector3(4,3.5,4),"inner-corner-close",45)
 else:
  await _shoot(stage,Vector3(-10,8,17),Vector3(3,3,3),"outer-corner",45)
  await _shoot(stage,Vector3(-7,3.5,12),Vector3(0,3,6),"outer-corner-close",45)
 quit()
