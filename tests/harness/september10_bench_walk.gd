extends "res://tests/harness/september10_reported_qa.gd"

class WalkController extends CharacterController:
	var direction := Vector2.ZERO
	func get_move_vector(_character: CharacterBody3D, _delta: float) -> Vector2:
		return direction

func _run() -> void:
	await get_tree().create_timer(5.0).timeout
	_camera = get_viewport().get_camera_3d()
	_camera.set("target", null)
	_camera.set_physics_process(false)
	_camera.set_process(false)
	assert(await _wait_for_site())
	var frame_cell := Vector2i(floori(float(_spot[2].x)/SettlementPlan.SUPER_WORLD), floori(float(_spot[2].z)/SettlementPlan.SUPER_WORLD))
	var urban := _streamer._features.village_plan().record_for(_streamer._features.frame_for(frame_cell)).urban_fabric
	var nearest: Dictionary = {}
	var distance := INF
	for entry: Dictionary in urban.entries:
		if entry.asset_id not in [SettlementFabricProgram.TERRACE_BENCH, SettlementFabricProgram.TERRACE_BENCH_ALT]:
			continue
		var d: float = entry.transform.origin.distance_to(_spot[2])
		if d < distance:
			nearest = entry
			distance = d
	assert(not nearest.is_empty() and distance < 3.0)
	var pose: Transform3D = nearest.transform
	var shapes: Array[CollisionShape3D] = []
	for node: Node in find_children("lpfv_fabric_prop_bench_*", "CollisionShape3D", true, false):
		shapes.append(node)
	assert(not shapes.is_empty())
	var controller := WalkController.new()
	_character.controller = controller
	_character.set_physics_process(false)
	_camera.global_position = ReviewCam.solve_cam(_spot[2], _spot[3])
	_camera.look_at(_spot[2])
	_camera.force_update_transform()
	var rows: Array = []
	for enabled in [false, true]:
		for shape: CollisionShape3D in shapes:
			shape.set_deferred("disabled", not enabled)
		await get_tree().physics_frame
		await get_tree().physics_frame
		for sign_value: float in [-1.0, 1.0]:
			for offset: float in [-.6, 0.0, .6]:
				var normal := pose.basis.z.normalized() * sign_value
				var centre := pose.origin + pose.basis.x.normalized() * offset
				_character.global_position = centre + normal * 1.3 + Vector3.UP * .1
				_character.velocity = Vector3.ZERO
				controller.direction = Vector2.ZERO
				for tick in 20:
					await get_tree().physics_frame
					_character._physics_process(1.0/60)
				var trace: Array = []
				controller.direction = Vector2(-normal.x, -normal.z)
				for tick in 90:
					await get_tree().physics_frame
					_character._physics_process(1.0/60)
					trace.append({"tick":tick,"position":str(_character.position),"side":(_character.position-centre).dot(normal),"grounded":_character.is_on_floor()})
					if (_character.position-centre).dot(normal) < -1.0:
						break
				controller.direction = Vector2.ZERO
				var side := (_character.position-centre).dot(normal)
				var passed := side > .4 and _character.is_on_floor() if enabled else side < -1.0
				rows.append({"collision":enabled,"side":sign_value,"offset":offset,"passed":passed,"remaining_side_m":side,"trace":trace})
				print("BENCH_WALK collision=",enabled," side=",sign_value," offset=",offset," passed=",passed," distance=",side)
				await _shot("%s_side_%d_offset_%d" % ["after" if enabled else "before",int(sign_value),roundi(offset*10)])
	FileAccess.open(_output_dir+"/walking.json",FileAccess.WRITE).store_string(JSON.stringify({"asset":String(nearest.asset_id),"id":String(nearest.stable_id),"pose":str(pose),"runs":rows},"  "))
	var passed := true
	for row: Dictionary in rows:
		passed = passed and bool(row.passed)
	get_tree().quit(0 if passed else 1)
