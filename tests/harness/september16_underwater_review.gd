extends "res://tests/harness/september16_manual_qa.gd"
var _effect:Node
var _phase:="before"
class TrialController extends CharacterController:
 var direction:=Vector2.ZERO
 func get_move_vector(_body:CharacterBody3D,_dt:float)->Vector2:return direction
func _capture_views(world:Node3D)->void:
 var records:Array=FileAccess.open("res://docs/qa/2026-09-16-manual/baseline/P10/samplers.bin",FileAccess.READ).get_var()
 var owners:=[]
 for values:Dictionary in records:
  var s:=WaterSampler.new()
  for key:String in values:s.set(key,values[key])
  var owner:=Node.new();owner.set_meta("sampler",s);world.add_child(owner);owner.add_to_group("water_surface");owners.append(owner)
 _effect=preload("res://scripts/camera/UnderwaterView.gd").new()
 _effect.camera=_camera;_effect.world_seed=WORLD_SEED;add_child(_effect)
 var base:=_output_dir
 var controller:=TrialController.new();_character.controller=controller
 var report:=[]
 for phase:String in ["before","after"]:
  for owner:Node in owners:
   if phase=="before":owner.remove_from_group("water_surface")
   else:owner.add_to_group("water_surface")
  for direction:Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.LEFT]:
   controller.direction=direction
   _character.global_position=Vector3(-1175.3,8,-731)
   _character.velocity=Vector3.ZERO;_character.in_water=false;_character.immersed=false
   for frame in 120:
    await get_tree().physics_frame
    _character._physics_process(1.0/60.0)
   report.append({"phase":phase,"input":str(direction),"feet":str(_character.global_position),"velocity":str(_character.velocity),"swim":_character.in_water,"immersed":_character.immersed})
  _phase=phase;controller.direction=Vector2.ZERO
  for record:Array in _spots():
   if not record[0] in ["P01","P10"]:continue
   _spot=record;_output_dir=base.path_join(phase).path_join(record[0]);DirAccess.make_dir_recursive_absolute(_output_dir)
   await super._capture_views(world)
 FileAccess.open(base.path_join("motion.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 _output_dir=base
func _shot(label:String)->void:
 if _phase=="after":_effect.update_view()
 else:_effect.clear()
 if _phase=="after":
  var e:Environment=_camera.environment
  print("UNDERWATER_ENV ",label," depth=",_effect.depth," background=",e.background_mode if e else -1," sky=",e.sky.sky_material if e and e.sky else null," fog=",e.fog_light_color if e else Color.BLACK," aerial=",e.fog_aerial_perspective if e else -1)
 if "--diagnose-background" in OS.get_cmdline_user_args() and _phase=="after" and _effect.depth>0:
  _camera.environment.background_mode=Environment.BG_COLOR
  _camera.environment.background_color=Color(1,0,1)
  for n:Node3D in get_tree().get_nodes_in_group("tactical_preserve_surface"):n.visible=false
 await super._shot(label)
