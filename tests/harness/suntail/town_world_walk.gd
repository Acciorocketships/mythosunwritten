extends "res://tests/harness/suntail/town_world_review.gd"
## Actual streamed terrain, committed native collision and production player.
## Each route starts at its first point; no teleporting within a route.

const Routes = preload("res://tests/harness/suntail/nested_gate_walk.gd")

class WalkController extends CharacterController:
	var direction := Vector2.ZERO
	func get_move_vector(_body: CharacterBody3D, _delta: float) -> Vector2:
		return direction

var _controller := WalkController.new()
var _results: Array = []

func _run() -> void:
	await get_tree().create_timer(5.0).timeout
	_camera = get_viewport().get_camera_3d()
	_camera.set("target", null)
	_camera.set_physics_process(false)
	_camera.set_process(false)
	_character.controller = _controller
	_character.set_physics_process(false)
	var started := Time.get_ticks_msec()
	var ready := await _wait_for_site()
	var ready_stats := _streamer._features.stats()
	var ready_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	var site := Vector2i(-1,0) if OS.get_cmdline_user_args().has("--wooded") else Vector2i(0,1)
	var frame := _streamer._features.frame_for(site)
	var record := _streamer._features.village_plan().record_for(frame)
	var town := record.urban_fabric
	var spatial := town.volumetric_spatial
	var source: WarrenMazeSourcePlan = spatial.source_volume.mass_context[&"maze_source_plan"]
	var routes := Routes._routes(source, town.fabric_plan, true, spatial)
	var spine: Array = []
	for cell: Vector3i in source.excavation.route:
		spine.append(Routes._macro_point(cell))
	routes.push_front({"label":"entrance_spine", "points":spine})
	routes.append_array(Routes._routes(source, town.fabric_plan, false, spatial))
	if ready:
		for route: Dictionary in routes:
			await _walk(route, town.world_transform, false)
			await _walk(route, town.world_transform, true)
	var reentry := {}
	if ready and OS.get_cmdline_user_args().has("--reentry"):
		var chunk := FieldTerrainStreamer.chunk_of(Vector3(_spot[2]))
		var old_node: Node = _streamer._built.get(chunk)
		var old_id := old_node.get_instance_id() if old_node != null else 0
		_controller.direction = Vector2.ZERO
		_character.global_position = Vector3(_spot[2]) + Vector3(1536,0,0)
		_character.velocity = Vector3.ZERO
		await get_tree().create_timer(2.0).timeout
		reentry.evicted = not _streamer._built.has(chunk)
		_character.global_position = Vector3(_spot[2])
		reentry.ready = await _wait_for_site()
		var new_node: Node = _streamer._built.get(chunk)
		reentry.replaced = new_node != null and new_node.get_instance_id() != old_id
		if reentry.ready:
			await _walk(routes[0], town.world_transform, false)
	var passed := ready and not _results.is_empty()
	for row: Dictionary in _results: passed = passed and row.passed
	if not reentry.is_empty(): passed = passed and reentry.evicted and reentry.ready and reentry.replaced
	var result := {"ready":ready,"passed":passed,"site":str(site),"routes":_results,
		"reentry":reentry,"elapsed_seconds":(Time.get_ticks_msec()-started)/1000.0,
		"ready_feature_stats":ready_stats,"final_feature_stats":_streamer._features.stats(),
		"ready_static_memory_bytes":ready_memory,
		"final_static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)}
	FileAccess.open(_output_dir.path_join("walk.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("WORLD_WALK_COMPLETE ",JSON.stringify(result))
	get_tree().quit(0 if passed else 1)

func _walk(route: Dictionary, transform: Transform3D, reverse: bool) -> void:
	var points: Array[Vector3] = []
	var floors: Array = []
	for local: Vector3 in route.points:
		var point := transform * local
		var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*2.0,point-Vector3.UP*2.0)
		query.exclude = [_character.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		floors.append({"expected":str(point),"floor":str(hit.get("position","missing"))})
		if not hit.is_empty() and (hit.normal as Vector3).y > 0.5:
			point.y = (hit.position as Vector3).y
		points.append(point)
	if reverse: points.reverse()
	_character.global_position = points[0]+Vector3.UP*0.1
	_character.velocity = Vector3.ZERO
	_controller.direction = Vector2.ZERO
	for tick in 30: await _tick()
	var passed := true
	var trace: Array = []
	for index in range(1,points.size()):
		var target := points[index]
		var reached := false
		for tick in 600:
			var delta := Vector2(target.x-_character.global_position.x,target.z-_character.global_position.z)
			if delta.length() < 0.3 and (index < points.size()-1 or
					(_character.is_on_floor() and absf(_character.global_position.y-target.y)<_character.MAX_STEP_HEIGHT)):
				reached = true
				break
			_controller.direction = delta.normalized()*0.75
			await _tick()
			if tick%60 == 0:
				trace.append({"waypoint":index,"tick":tick,"position":str(_character.global_position),"target":str(target),"floor":_character.is_on_floor()})
		if not reached:
			passed = false
			for i in _character.get_slide_collision_count():
				var collision := _character.get_slide_collision(i)
				var owner := collision.get_collider_shape() as Node
				trace.append({"collider":str(owner.get_path()) if owner != null else "unknown",
					"position":str(collision.get_position()),"normal":str(collision.get_normal())})
			break
	_controller.direction = Vector2.ZERO
	_results.append({"label":route.label,"reverse":reverse,"passed":passed,"floors":floors,"trace":trace})
	print("WORLD_ROUTE ",route.label," reverse=",reverse," passed=",passed)

func _tick() -> void:
	await get_tree().physics_frame
	_character.set_physics_process(false)
	_character._physics_process(1.0/60.0)
