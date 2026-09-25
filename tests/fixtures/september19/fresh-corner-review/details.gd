extends "res://tests/fixtures/september18/cliff-corner-continuity/fresh-details.gd"
func _capture_views(world:Node3D)->void:
 await super._capture_views(world)
 var views:Array=[
  ["lower_inner_front",Vector3(-434,35,-266),Vector3(-445,30,-277)],
  ["lower_inner_above",Vector3(-435,43,-267),Vector3(-444,29,-276)],
  ["short_inner",Vector3(-409,35,-338),Vector3(-421,30,-349)]]
 for view:Array in views:
  _camera.global_position=view[1];_camera.look_at(view[2]);_camera.fov=65
  await _shot(view[0])
