extends "res://tests/fixtures/september19/fresh-corner-review/details.gd"
func _capture_views(world:Node3D)->void:
 await super._capture_views(world)
 for shot:Array in [["short_above",Vector3(-410,42,-338),Vector3(-421,30,-349)],["short_side",Vector3(-413,33,-340),Vector3(-421,31,-348)]]:
  _camera.global_position=shot[1];_camera.look_at(shot[2]);_camera.fov=65
  await _shot(shot[0])
