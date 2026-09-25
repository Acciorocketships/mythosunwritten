extends "res://tests/harness/september16_manual_qa.gd"
func _capture_views(world:Node3D)->void:
 _freeze_material_clocks(world)
 _capture_view.size=Vector2i(1600,1000)
 _character.visible=false
 var views:Array=[
  ["inner_front",Vector3(-434,38,-291),Vector3(-444,35,-300)],
  ["inner_above",Vector3(-437,44,-294),Vector3(-443,34,-299)],
  ["outer_oblique",Vector3(-437,41,-242),Vector3(-445,35,-252)]]
 for view:Array in views:
  _camera.global_position=view[1];_camera.look_at(view[2]);_camera.fov=65
  await _shot(view[0])
