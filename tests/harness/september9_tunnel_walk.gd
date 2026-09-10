extends "res://tests/harness/september9_reported_qa.gd"

class WalkController extends CharacterController:
	var direction := Vector2.ZERO
	func get_move_vector(_character: CharacterBody3D,_delta: float) -> Vector2:
		return direction

func _run() -> void:
	await get_tree().create_timer(5.0).timeout
	_camera = get_viewport().get_camera_3d()
	_camera.set("target",null)
	_camera.set_physics_process(false)
	_camera.set_process(false)
	_character.set_physics_process(false)
	assert(await _wait_for_site())
	var super_cell := Vector2i(floori(float(_spot[2].x)/SettlementPlan.SUPER_WORLD),floori(float(_spot[2].z)/SettlementPlan.SUPER_WORLD))
	var urban := _streamer._features.village_plan().record_for(_streamer._features.frame_for(super_cell)).urban_fabric
	var controller := WalkController.new()
	_character.controller = controller
	var report: Array = []
	var arches:Array[Dictionary]=[]
	for placement in urban.fabric_plan.expanded_placements():
		if String(placement.stable_id).begins_with("tunnel-mouth/"):arches.append(placement)
	if OS.get_cmdline_user_args().has("--before"):
		arches=[{"stable_id":&"tunnel-mouth/0/0/0/-1/0","transform":Transform3D(Basis(Vector3.UP,-PI/2),Vector3(-0.65,0,0.75))}]
	elif arches.is_empty():
		push_error("The production town did not emit its tunnel arch")
		get_tree().quit(1)
		return
	for arch in arches:
		var centre:Vector3=urban.world_transform*arch.transform.origin
		var normal:Vector3=(urban.world_transform.basis*arch.transform.basis.z).normalized()
		var high:Vector3=centre-normal*3
		var low:Vector3=centre+normal*3
		var outward := ((low-high)*Vector3(1,0,1)).normalized()
		var side := outward.cross(Vector3.UP)
		for offset: float in [-1.5,0.0,1.5]:
			for reverse: bool in [false,true]:
				var start := (high-outward if reverse else low+outward)+side*offset
				var end := (low+outward if reverse else high-outward)+side*offset
				var forward := ((end-start)*Vector3(1,0,1)).normalized()
				_character.global_position = start+Vector3.UP*0.1
				_character.velocity = Vector3.ZERO
				controller.direction = Vector2.ZERO
				for tick in 30:
					await get_tree().physics_frame
					_character._physics_process(1.0/60)
				var trace: Array = []
				controller.direction = Vector2(forward.x,forward.z)
				for tick in 300:
					await get_tree().physics_frame
					_character._physics_process(1.0/60)
					trace.append({"tick":tick,"xyz":[_character.position.x,_character.position.y,_character.position.z],"ground":_character.is_on_floor()})
					if (_character.global_position-end).dot(forward)>=0: break
				var success := (_character.global_position-end).dot(forward)>=-0.2 and absf(_character.position.y-end.y)<0.2
				var row := {"gate":String(arch.stable_id),"descent":reverse,"offset":offset,"passed":success,"end":str(_character.position),"trace":trace}
				report.append(row)
				print("GATE_WALK ",String(arch.stable_id)," descent=",reverse," offset=",offset," passed=",success," end=",_character.position)
		controller.direction = Vector2.ZERO
		for view in [["front",Vector3(-3.8,1.8,0.75)],["left",Vector3(-3.2,1.7,-0.2)],["right",Vector3(-3.2,1.7,1.7)],["inside",Vector3(2,1.8,0.75)],["overview",Vector3(-3.5,2.5,0.75)]]:
			_camera.global_position=urban.world_transform*view[1]
			_camera.look_at(urban.world_transform*Vector3(-0.65,1.9,0.75))
			_camera.force_update_transform()
			for frame in 4:await get_tree().process_frame
			await _shot("tunnel_"+String(view[0]))
	FileAccess.open(_output_dir+"/walking.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	var shots: Array = _spots() if _capture_all else [_spot]
	for spot: Array in shots: await _capture_spot(spot)
	var passed := not report.is_empty()
	for row: Dictionary in report: passed = passed and bool(row.passed)
	get_tree().quit(0 if passed else 1)
