extends "res://tests/harness/september16_manual_qa.gd"
func _capture_views(world:Node3D)->void:
 _freeze_material_clocks(world)
 var base:=_output_dir
 var views:Array=[
  ["P12_front",Vector3(-423,40,-292),Vector3(-442,36,-298)],
  ["P12_side",Vector3(-414,42,-311),Vector3(-442,35,-298)],
  ["P17_front",Vector3(-425,39,-247),Vector3(-445,34,-250)],
  ["P20_oblique",Vector3(-482,42,-229),Vector3(-483,36,-249)],
  ["P05_vines",Vector3(-427,36,-263),Vector3(-445,36,-269)]]
 var rows:=[]
 for view:Array in views:
  _character.global_position=view[2]-Vector3.UP*4
  _spot=[view[0],"cliff inspection",_character.global_position,view[2]]
  await _prepare_review_grass()
  _camera.global_position=view[1];_camera.look_at(view[2]);_camera.fov=65
  rows.append({"id":view[0],"camera":str(_camera.global_transform),"fov":65})
  await _shot(view[0])
 FileAccess.open(base.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
