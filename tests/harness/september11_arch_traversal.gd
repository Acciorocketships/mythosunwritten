extends SceneTree

class FixedController extends CharacterController:
	var direction:=Vector2.ZERO
	func get_move_vector(_character:CharacterBody3D,_delta:float)->Vector2: return direction

func _init() -> void: call_deferred("_run")

func _run() -> void:
	Engine.max_fps=60
	root.size=Vector2i(1920,1080)
	var seed_value:=2697992464
	var water:=TerrainWorldTuning.make_water(seed_value)
	var fields:=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(seed_value,water),water,26,0)
	var chunk:=Vector2i(-4,0)
	var region:=fields.region(chunk)
	var field:=fields.water(chunk)
	var mesher:=TerrainChunkMesher.new()
	mesher.set_seed(seed_value)
	mesher.prepare_resources()
	var data:=mesher.compute_chunk(chunk,region,field)
	assert(data.natural_arches.placements.size()>0)
	var stage:=mesher.commit_chunk(data)
	root.add_child(stage)
	var sheet:=WaterSurfaceBuilder.new().commit_chunk(WaterSurfaceBuilder.new().compute_chunk(water,chunk,region,field))
	if sheet!=null: root.add_child(sheet)
	var record:Dictionary=data.natural_arches.placements[0]
	var center:Vector2=record.center
	var along:=Vector2(record.axis).normalized()
	var side:=Vector2(-along.y,along.x)
	var arch:=stage.get_node("NaturalArches") as MeshInstance3D
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("91adbb")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=.65
	root.add_child(environment)
	var light:=DirectionalLight3D.new()
	root.add_child(light)
	light.rotation_degrees=Vector3(-45,-30,0)
	var camera:=Camera3D.new()
	root.add_child(camera)
	camera.current=true
	camera.fov=50
	var controller:=FixedController.new()
	var actor:=preload("res://characters/character.tscn").instantiate()
	actor.controller=controller
	root.add_child(actor)
	actor.set_physics_process(false)
	var target:=Vector3(center.x,record.low+3,center.y)
	camera.position=target+Vector3(side.x*32+along.x*24,24,side.y*32+along.y*24)
	camera.look_at(target)
	var folder:="res://docs/qa/2026-09-11-manual/12-landforms/arch-traversal"
	var rows:Array[Dictionary]=[]
	for phase:String in ["before","after"]: DirAccess.make_dir_recursive_absolute(folder.path_join(phase))
	for offset:float in [-2,0,2]:
		for sign_value:float in [-1,1]:
			var point:=center+along*offset-side*sign_value*10
			var ground:=TerrainTileField.surface_y(region,point.x,point.y)
			var level:=field.level_at(point)
			actor.position=Vector3(point.x,maxf(ground+.05,level-.5),point.y)
			actor.velocity=Vector3.ZERO
			controller.direction=Vector2.ZERO
			for frame in 45:
				await physics_frame
				actor._physics_process(1.0/60)
			var start:Vector3=actor.position
			controller.direction=side*sign_value
			var samples:Array[Dictionary]=[]
			var capture_index:=0
			# A 20 m swim needs more than six seconds at the actual swim speed.
			for tick in 600:
				await physics_frame
				actor._physics_process(1.0/60)
				var p:=Vector2(actor.position.x,actor.position.z)
				var progress:=(p-center).dot(side)*sign_value
				samples.append({"tick":tick,"position":str(actor.position),"swimming":actor.in_water,"progress":progress})
				if tick==0 or (capture_index==1 and progress>=0) or progress>=10:
					var id:="%d_%d_%d"%[offset,sign_value,capture_index]
					for phase:String in ["before","after"]:
						arch.visible=phase=="after"
						for frame in 5: await process_frame
						_draw.call_deferred()
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png(folder.path_join(phase).path_join(id+".png"))
					capture_index+=1
				if progress>=10: break
			var passed:bool=samples[-1].progress>=10
			rows.append({"offset":offset,"direction":sign_value,"start":str(start),"passed":passed,"camera":str(camera.transform),"samples":samples})
			FileAccess.open(folder.path_join("walks.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
			print("ARCH_TRAVERSE offset=",offset," sign=",sign_value," passed=",passed," end=",actor.position)
			assert(passed,"Real character must cross the complete arch opening")
	quit()

func _draw() -> void: RenderingServer.force_draw(true)
