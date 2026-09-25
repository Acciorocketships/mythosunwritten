extends GutTest
func test_deep_water_remains_physical_when_steep_swim_trigger_is_absent()->void:
 var stage:=Node3D.new();add_child(stage)
 var records:Array=FileAccess.open("res://docs/qa/2026-09-16-manual/baseline/P10/samplers.bin",FileAccess.READ).get_var()
 for values:Dictionary in records:
  var s:=WaterSampler.new()
  for key:String in values:s.set(key,values[key])
  var owner:=Node.new();owner.set_meta("sampler",s);stage.add_child(owner);owner.add_to_group("water_surface")
 var player:CharacterBody3D=load("res://characters/character.tscn").instantiate()
 player.controller=CharacterController.new();stage.add_child(player);player.set_physics_process(false)
 player.global_position=Vector3(-1175.3,8,-731)
 await get_tree().physics_frame
 player._update_in_water()
 assert_true(player.immersed,"P01 is seven metres below real water even though steep swimming volumes are excluded")
 assert_false(player.in_water,"Immersion drag must not create a buoyant elevator up a fall face")
 player.global_position.y=30
 player._update_in_water()
 assert_false(player.immersed,"Above-water state must restore ordinary movement immediately")
 stage.free()

class Pool extends WaterSampler:
 func level_at(p:Vector2)->float:return 2.0 if p.length()<5.0 else NAN
func test_submerged_camera_restores_its_environment_without_changing_other_views()->void:
 var stage:=Node3D.new();add_child(stage)
 var owner:=Node.new();owner.set_meta("sampler",Pool.new());stage.add_child(owner);owner.add_to_group("water_surface")
 var camera:=Camera3D.new();stage.add_child(camera)
 var original:=Environment.new();original.fog_density=.001;original.tonemap_exposure=1.1
 original.sky=Sky.new();original.sky.sky_material=ProceduralSkyMaterial.new()
 camera.environment=original
 var other:=Camera3D.new();other.environment=original;stage.add_child(other)
 var sky_color:Color=original.sky.sky_material.sky_top_color
 var effect=preload("res://scripts/camera/UnderwaterView.gd").new()
 effect.camera=camera;effect.world_seed=2697992464;stage.add_child(effect)
 camera.position=Vector3(0,1,0);effect.update_view()
 assert_ne(camera.environment,original,"Submerged camera owns a separate environment")
 assert_eq(effect._material.get_shader_parameter("immersion"),1.0,"Actual water depth enables distance extinction")
 assert_eq(other.environment,original,"Other cameras retain the air environment")
 assert_eq(original.sky.sky_material.sky_top_color,sky_color,"Underwater sky tint cannot leak into the world sky")
 camera.position.y=3;effect.update_view()
 assert_eq(camera.environment,original,"Leaving the water restores the exact original environment")
 camera.position=Vector3(10,-1,0);effect.update_view()
 assert_eq(camera.environment,original,"A low camera outside the wet footprint receives no underwater effect")
 stage.free()
