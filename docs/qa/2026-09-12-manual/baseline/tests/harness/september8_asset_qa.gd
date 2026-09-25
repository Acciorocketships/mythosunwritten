extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1500,900)
	var stage:=Node3D.new()
	root.add_child(stage)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("738080")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE
	env.environment.ambient_light_energy=0.8
	stage.add_child(env)
	var light:=DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees=Vector3(-45,-30,0)
	var catalog:=EnvironmentCatalog.load_default()
	var assets:Array[StringName]=[&"sfv.fabric.wall.rock.door.closed.005",&"sfv.fabric.wall.rock.plain.001",&"sfv.foundation.rock.001",&"sfv.fabric.wall.wood.s.001"]
	for i in assets.size():
		var v:EnvironmentVisual=load(catalog.descriptor(assets[i]).visual_path)
		for piece:EnvironmentVisualPiece in v.pieces:
			var mesh:=MeshInstance3D.new()
			mesh.mesh=piece.mesh
			mesh.transform=Transform3D(Basis(Vector3.UP,-0.4),Vector3(i*4,0,0))*piece.local_transform
			stage.add_child(mesh)
	var camera:=Camera3D.new()
	stage.add_child(camera)
	camera.position=Vector3(9,6,15)
	camera.look_at(Vector3(6,1.5,0))
	camera.current=true
	for frame in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/september8-assets.png")
	quit()
