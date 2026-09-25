extends SceneTree
const OUT := "res://docs/qa/2026-09-19-manual/132-bank-source-shapes"
class RouteController extends CharacterController:
	var direction := Vector2.ZERO
	func get_move_vector(_character: CharacterBody3D, _delta: float) -> Vector2: return direction

func _init() -> void: run.call_deferred()

func run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1280,800)
	var stage: Node3D = load("res://docs/qa/2026-09-19-manual/119-small-town/world.scn").instantiate()
	root.add_child(stage)
	for key: StringName in stage.get_meta("shader_globals",{}):
		if key in [&"biome_ground_a",&"biome_ground_b",&"biome_ground_color",&"biome_ground_origin",&"grass_lod_origin",&"wind_direction",&"wind_idle_bend",&"wind_gust_texture",&"wind_gust_scale",&"wind_gust_speed",&"wind_gust_bend",&"grass_trample_texture",&"grass_static_trample_texture",&"grass_trample_origin",&"grass_trample_size",&"grass_trample_epoch"]:
			RenderingServer.global_shader_parameter_set(key,stage.get_meta("shader_globals")[key])
	# Frozen review scenes retain visuals/collision but not RefCounted samplers.
	# Reattach the fresh production payload to the ordinary water builder.
	for owner: Node in get_nodes_in_group("water_volume"): owner.queue_free()
	for owner: Node in get_nodes_in_group("water_surface"): owner.remove_from_group("water_surface")
	var payload: Dictionary = FileAccess.open("res://docs/qa/2026-09-19-manual/130-bank-traversal/water.bin",FileAccess.READ).get_var()
	var sampler := WaterSampler.new()
	for key: StringName in payload.sampler: sampler.set(key,payload.sampler[key])
	payload.sampler = sampler
	var fresh_water := WaterSurfaceBuilder.new().commit_chunk(payload)
	fresh_water.get_node("WaterSheet").hide() # identical frozen view remains visible
	root.add_child(fresh_water)
	var rocks = preload("res://scripts/terrain/field/CliffRockDressing.gd")
	rocks.prepare()
	var forms: Array = FileAccess.open("res://docs/qa/2026-09-19-manual/132-bank-source-shapes/validated-banks.bin",FileAccess.READ).get_var()
	var added := rocks.build({"placements":forms},2697992464)
	root.add_child(added)
	var bodies: Array[StaticBody3D] = []
	for form: Dictionary in forms:
		var body := StaticBody3D.new()
		body.collision_layer = 64
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(form.faces)
		collision.shape = shape
		body.add_child(collision)
		root.add_child(body)
		body.transform = form.transform
		bodies.append(body)
	var controller := RouteController.new()
	var actor: CharacterBody3D = preload("res://characters/character.tscn").instantiate()
	actor.controller = controller
	actor.collision_mask |= 64
	root.add_child(actor)
	actor.set_physics_process(false)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = 65
	var routes: Array = [
		[Vector2(-538,308),Vector2(-538,320),Vector2(-536,322),Vector2(-521,322)],
		[Vector2(-480,298),Vector2(-472,298),Vector2(-470,296),Vector2(-470,290)]
	]
	var rows: Array = []
	var failures := 0
	for index in routes.size():
		var centre: Vector3 = Vector3(-534,14,320) if index==0 else Vector3(-473,14,296)
		camera.position = centre+(Vector3(13,16,-20) if index==0 else Vector3(-13,16,-20))
		camera.look_at(centre)
		for reverse: bool in [false,true]:
			var route: Array = routes[index].duplicate()
			if reverse: route.reverse()
			for candidate: bool in [false,true]:
				added.visible = candidate
				for body: StaticBody3D in bodies: body.collision_layer = 64 if candidate else 0
				controller.direction = Vector2.ZERO
				var start: Vector2 = route[0]
				actor.position = Vector3(start.x,sampler.level_at(start)-1.05,start.y)
				actor.velocity = Vector3.ZERO
				for tick in 45:
					await physics_frame
					actor._physics_process(1.0/60)
				var waypoint := 1
				var swimming := 0
				var contacts := 0
				var samples: Array = []
				for tick in 1200:
					var p := Vector2(actor.position.x,actor.position.z)
					if p.distance_to(route[waypoint])<.5:
						waypoint += 1
						if waypoint==route.size(): break
					controller.direction = (route[waypoint]-p).normalized()
					await physics_frame
					actor._physics_process(1.0/60)
					if actor.in_water: swimming += 1
					for collision_index in actor.get_slide_collision_count():
						var hit := actor.get_slide_collision(collision_index)
						if hit.get_collider() in bodies: contacts += 1
					if tick%15==0: samples.append({"tick":tick,"position":str(actor.position),"swimming":actor.in_water})
					if tick in [0,180] and not reverse:
						await process_frame
						RenderingServer.force_draw(false)
						root.get_texture().get_image().save_png(OUT.path_join("bend-%d-%s-%d.png"%[index,"after" if candidate else "before",tick]))
				var passed := waypoint==route.size() and swimming>30
				if not passed: failures += 1
				rows.append({"bend":index,"reverse":reverse,"candidate":candidate,"passed":passed,"swimming_frames":swimming,"rock_contacts":contacts,"end":str(actor.position),"samples":samples})
				FileAccess.open(OUT.path_join("swims.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
				print("BANK_SWIM bend=",index," reverse=",reverse," candidate=",candidate," passed=",passed," swim_frames=",swimming," contacts=",contacts)
	quit(0 if failures==0 else 1)
