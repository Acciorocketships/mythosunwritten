extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
 root.size=Vector2i(1600,900)
 var scene:=Node3D.new();root.add_child(scene)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);scene.add_child(light)
 var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color(.6,.65,.7);world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=.7;scene.add_child(world)
 var mesh:=MeshInstance3D.new();mesh.mesh=load("res://docs/qa/2026-09-26-p03-crown-colour/study-mesh.res");scene.add_child(mesh)
 var cam:=Camera3D.new();scene.add_child(cam);cam.current=true;cam.fov=60;cam.look_at_from_position(Vector3(508,50,934),Vector3(497,40,955))
 var material:ShaderMaterial=mesh.mesh.surface_get_material(0)
 var source:=FileAccess.get_file_as_string("res://terrain/materials/cliff_crag.gdshader")
 var include:=FileAccess.get_file_as_string("res://terrain/materials/slope_green.gdshaderinc")
 for span:float in [1.0,.35,0.0]:
  var shader:=Shader.new();shader.code=source.replace('#include "res://terrain/materials/slope_green.gdshaderinc"',include.replace('smoothstep(.05,.24,grade)','smoothstep(0.0,.85,grade)').replace('lawn*moss_shade*detail','lawn*mix(vec3(1.0),moss_shade,%s)*detail'%span));material.shader=shader
  for i in 5:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://docs/qa/2026-09-26-p03-crown-colour/contrast-%s.png"%span)
 quit()
