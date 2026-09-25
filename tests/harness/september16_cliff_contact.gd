extends "res://tests/harness/september16_cliff_walk.gd"
func _capture_views(_world:Node3D)->void:
 await _shot("warmup")
 var rows:=[];var controller:=WalkController.new();_character.controller=controller
 for side:float in [-1,1]:
  _character.global_position=Vector3(-441.7119-side,29.89,-276.5053)
  _character.velocity=Vector3.ZERO;controller.direction=Vector2.ZERO
  for tick in 20:
   await get_tree().physics_frame;_character._physics_process(1.0/60)
  var start:=_character.global_position;controller.direction=Vector2(side,0)
  var contacts:Dictionary={}
  for tick in 60:
   await get_tree().physics_frame;_character._physics_process(1.0/60)
   for i in _character.get_slide_collision_count():
    var hit:=_character.get_slide_collision(i);var body:CollisionObject3D=hit.get_collider()
    var shape:Node=body.shape_owner_get_owner(body.shape_find_owner(hit.get_collider_shape_index()))
    contacts[str(shape.get_path())+str(hit.get_normal().snapped(Vector3.ONE*.01))]=str(hit.get_position())
  rows.append({"side":side,"start":str(start),"end":str(_character.global_position),"velocity":str(_character.velocity),"input":str(controller.direction),"contacts":contacts})
 FileAccess.open(_output_dir.path_join("contacts.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
