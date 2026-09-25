extends "res://tests/harness/september16_manual_qa.gd"
func _capture_views(world:Node3D)->void:
 var base:=_output_dir
 for record:Array in _spots():
  if not record[0] in ["P04","P15"]:continue
  _spot=record;_output_dir=base.path_join(record[0]);DirAccess.make_dir_recursive_absolute(_output_dir)
  await super._capture_views(world)
 _output_dir=base
