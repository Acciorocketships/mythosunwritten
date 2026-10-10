extends GutTest

func test_low_wall_room_cannot_erase_the_bearing_of_an_upper_bridge_house() -> void:
 var source := preload("res://tests/fixtures/frozen_maze_source.gd").read("res://tests/fixtures/october5-court-bridge-bearing-source.txt")
 var found := false
 for plot: Dictionary in source.plots:
  if plot.id != &"house.wall-room.004": continue
  found = true
  assert_false(source.wall_room_support_ok(plot,plot.cells[0]),"the lower terrace cap must not erase stone between its top and the bridge house above")
 assert_true(found)

func test_refusing_short_lower_room_restores_actual_bridge_house_bearing() -> void:
 var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
 var source := frozen.read("res://tests/fixtures/october5-court-bridge-bearing-source.txt")
 var before := WarrenMazeVolumeAdapter.to_volume_plan(source)
 var bearing := Vector3i(-2,6,-1)
 assert_false(before.has_mass(bearing),"the failing layout really lost this course")
 for i in range(source.plots.size()-1,-1,-1):
  if source.plots[i].id==&"house.wall-room.004": source.plots.remove_at(i)
 source.finish_construction(false)
 var after := WarrenMazeVolumeAdapter.to_volume_plan(source)
 assert_true(after.has_mass(bearing),"retained stone closes the support gap")
 var parcel := WarrenBuildingParcel.new(&"proof",[Vector2i(-2,-1)] as Array[Vector2i],7,10,Vector3i(-2,7,-2),Vector2i(-2,-1),Vector2i(0,-1),0,true)
 assert_true(parcel.seal(after),"the actual upper house now seals against the unchanged volume contract")
