extends SceneTree
const Frozen = preload("res://tests/fixtures/frozen_terrain_grade.gd")
class InputController extends CharacterController:
	var direction := Vector2.ZERO
	func get_move_vector(_character: CharacterBody3D,_delta: float)->Vector2:return direction
func _init()->void:call_deferred("_run")
func _run()->void:
	var region:=Frozen.region("res://tests/fixtures/september8-night-crease-field.txt")
	var cache:=EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var assets:Array[StringName]=[]
	assets.assign(CliffDressing.ASSETS.values())
	cache.prepare(assets)
	CliffDressing.prepare(cache)
	var mesher:=TerrainChunkMesher.new()
	mesher.set_seed(2697992464)
	mesher.prepare_resources()
	var payload:=mesher.compute_chunk(Vector2i(9,2),region)
	var body:=StaticBody3D.new()
	root.add_child(body)
	var collider:=CollisionShape3D.new()
	var shape:=ConcavePolygonShape3D.new()
	shape.backface_collision=true
	shape.set_faces(payload.collision_faces)
	collider.shape=shape
	body.add_child(collider)
	var player:CharacterBody3D=load("res://characters/character.tscn").instantiate()
	var controller:=InputController.new()
	player.controller=controller
	root.add_child(player)
	player.set_physics_process(false)
	var results:Array=[]
	for route in [[Vector2(1907,407),Vector2(1917,403)],[Vector2(1913,400),Vector2(1913,413)]]:
		for reverse in [false,true]:
			var start:Vector2=route[1] if reverse else route[0]
			var end:Vector2=route[0] if reverse else route[1]
			player.global_position=Vector3(start.x,TerrainSurfaceField.surface_y(region,start.x,start.y)+.2,start.y)
			player.velocity=Vector3.ZERO
			controller.direction=Vector2.ZERO
			for tick in 30:
				await physics_frame
				player._physics_process(1.0/60)
			controller.direction=(end-start).normalized()
			for tick in 240:
				await physics_frame
				player._physics_process(1.0/60)
				if (Vector2(player.position.x,player.position.z)-end).dot(controller.direction)>=0:break
			var passed:bool=(Vector2(player.position.x,player.position.z)-end).dot(controller.direction)>=0 and player.is_on_floor()
			results.append({"start":str(start),"end_target":str(end),"end":str(player.position),"passed":passed})
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("CREASE_WALKS ",JSON.stringify(results))
	player.queue_free()
	body.queue_free()
	await process_frame
	quit()
