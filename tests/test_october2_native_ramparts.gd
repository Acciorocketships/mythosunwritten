extends GutTest

func test_ramparts_use_closed_native_blocks_and_unstretched_wall_courses() -> void:
 var mass := BuildingMass.new()
 mass.stable_id = &"native-rampart"
 var floor := mass.add_storey(0,{Vector2i.ZERO:true},BuildingMass.MATERIAL_STONE)
 floor.fortified = true
 floor.bands = 8
 var parts := BuildingKitAssembler.new(SuntailBuildingKit.create()).assemble(mass)
 var blocks := 0
 var walls := 0
 for part: Dictionary in parts:
  var id := String(part.asset_id)
  blocks += int(id.begins_with("pure_village.stone.block."))
  if id=="pure_village.wall.stone.plain":
   walls += 1
   assert_lte((part.transform as Transform3D).basis.get_scale().y,1.01,"masonry courses preserve authored stone proportions")
 assert_gt(blocks,0,"parapets and merlons use actual closed stone assets")
 assert_gt(walls,4,"tall walls are assembled in native-height courses")
