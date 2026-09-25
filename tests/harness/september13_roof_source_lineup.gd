extends SceneTree
func _init() -> void: run.call_deferred()
func run() -> void:
 root.size=Vector2i(1400,800)
 var stage=Node3D.new()
 root.add_child(stage)
 var env=WorldEnvironment.new()
 env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color("677782")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color.WHITE
 env.environment.ambient_light_energy=.8
 stage.add_child(env)
 var sun=DirectionalLight3D.new()
 stage.add_child(sun)
 sun.rotation_degrees=Vector3(-50,-30,0)
 var camera=Camera3D.new()
 stage.add_child(camera)
 camera.current=true
 camera.position=Vector3(15,18,28)
 camera.look_at(Vector3(10,2,3))
 for index in 6:
  var item=load("res://assets/LowPolyFantasyVillage/Models/HouseParts/Roof_%02d.glb"%(index+1)).instantiate()
  stage.add_child(item)
  item.position=Vector3((index%3)*10,0,(index/3)*9)
  var label=Label3D.new()
  stage.add_child(label)
  label.text="Roof %02d"%(index+1)
  label.position=item.position+Vector3(0,0,4)
  label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
  label.pixel_size=.02
 for frame in 10: await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png("res://docs/qa/2026-09-13-manual/11-roof-joins/source-lineup.png")
 quit()
