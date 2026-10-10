extends SceneTree
## Native materials under identical light: source, prepared Suntail, Pure donor.
func _init() -> void:
 call_deferred("_run")

func _run() -> void:
 root.size=Vector2i(1200,600)
 var stage:=Node3D.new()
 root.add_child(stage)
 var env:=WorldEnvironment.new()
 env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color(.16,.18,.2)
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color(.8,.8,.8)
 env.environment.ambient_light_energy=.6
 env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 stage.add_child(env)
 var sun:=DirectionalLight3D.new()
 sun.rotation_degrees=Vector3(-35,-25,0)
 sun.light_energy=1.2
 stage.add_child(sun)
 var catalog:=EnvironmentCatalog.load_default()
 var cache:=EnvironmentRenderCache.new(catalog)
 var id:=&"suntail.frame.frame_wall_1"
 var visuals:Array[EnvironmentVisual]=[load(catalog.descriptor(id).visual_path),cache.visual(id),cache.visual(&"pure_village.wall.plaster.plain")]
 for i in 3:
  for piece:EnvironmentVisualPiece in visuals[i].pieces:
   var node:=MeshInstance3D.new()
   node.mesh=piece.mesh
   node.transform=piece.local_transform
   node.position.x+=(i-1)*3.0
   stage.add_child(node)
  var label:=Label.new()
  label.text=["Suntail · original","Suntail · warm plaster","Pure Village · reference"][i]
  label.position=Vector2(120+i*330,50)
  label.size=Vector2(300,40)
  label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  label.add_theme_font_size_override("font_size",22)
  root.add_child(label)
 var camera:=Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=5.5
 stage.add_child(camera)
 camera.look_at_from_position(Vector3(0,1.5,12),Vector3(0,1.5,0))
 camera.current=true
 for i in 10: await process_frame
 RenderingServer.force_draw(false)
 var args:=OS.get_cmdline_user_args()
 root.get_texture().get_image().save_png(args[0] if not args.is_empty() else "/tmp/plaster-palette.png")
 quit()
