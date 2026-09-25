extends "res://tests/harness/village_september7_qa.gd"

func _spots() -> Array:
	var spots: Array = [
		["06_ground_crease", "11.06.55 PM", Vector3(1911.3,11.5,408.1), Vector3(1911.3,11.7,408.4)],
		["15_water_edge", "11.07.55 PM", Vector3(2114.2,16,582.7), Vector3(2114.6,16.2,582.8)],
		["17_water_wall", "11.07.13 PM", Vector3(1922.1,12,424.1), Vector3(1921.9,12.2,423.8)],
		["07_water_divot", "11.05.05 PM", Vector3(1457.5,8,554.4), Vector3(1457.2,8.2,554.2)],
		["09_door_path", "11.03.18 PM", Vector3(1301.6,17,343.7), Vector3(1301.4,17.2,344.0)],
		["16_lamp", "10.59.46 PM", Vector3(357.2,20,433.7), Vector3(357.5,20.2,433.5)],
		["10_swim", "10.59.12 PM", Vector3(394.4,8.7,330.8), Vector3(394.1,8.9,330.7)],
		["11_bridge", "10.58.52 PM", Vector3(312.3,16.2,269.3), Vector3(312.3,16.4,269.0)],
		["13_walkway_end", "10.57.03 PM", Vector3(240.7,23.1,-351.2), Vector3(242.8,25.0,-349.0)],
		["20_walkway_end", "11.00.21 PM", Vector3(347.9,32.1,505.7), Vector3(348.1,32.4,506.0)],
		["12_stair_end", "11.02.51 PM", Vector3(1289.5,16.9,384.6), Vector3(1289.1,17.2,384.6)],
		["04_rail_wall", "10.56.33 PM", Vector3(233.4,18.2,-362.6), Vector3(233.3,18.4,-362.2)],
		["08_unattached_outcrop", "10.55.29 PM", Vector3(227.9,11.1,-376.0), Vector3(227.9,11.3,-375.6)],
		["01_corner_east", "11.00.50 PM", Vector3(360.6,20,497.4), Vector3(360.4,20.2,497.0)],
		["02_corner_west", "10.55.09 PM", Vector3(237.4,8,-370.2), Vector3(237.7,8.2,-370.4)],
		["05_corner_market", "10.56.04 PM", Vector3(223.6,8,-358.7), Vector3(223.5,8.2,-359.1)],
		["14_upper_corner", "11.00.05 PM", Vector3(362.2,29.1,505.6), Vector3(361.9,29.3,505.8)],
		["19_window_edge", "11.02.57 PM", Vector3(1294.6,17,361.9), Vector3(1294.3,17.2,362.0)],
		["18_corner_overview", "10.55.55 PM", Vector3(209.3,12.4,-375.7), Vector3(208.9,12.7,-375.8)],
	]
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()-1):
		if args[i] == "--only":
			var names := args[i+1].split(",")
			var selected: Array = []
			for name in names:
				for spot: Array in spots:
					if String(spot[0]) == name: selected.append(spot)
			return selected
	return spots

func _ready() -> void:
	super._ready()
	get_window().size = Vector2i(1718,1035)

func _shot(name: String) -> void:
	if name.begins_with("06_ground_crease"):
		# Keep the reported camera fixed while seating the avatar on the real
		# collision surface. The repaired grade can change its standing height.
		var point := Vector3(1911.3,11.5,408.1)
		var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*20,point+Vector3.DOWN*20)
		query.exclude=[_character.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		assert(not hit.is_empty())
		_character.global_position=hit.position+Vector3.UP*0.01
		for frame in 3: await get_tree().process_frame
	await super._shot(name)

func _capture_spot(spot: Array) -> void:
	_spot = spot
	_character.global_position = spot[2]
	assert(await _wait_for_site(), "Photographed site must finish streaming")
	if String(spot[0]) == "10_swim":
		_prepare_swim_pose()
	await super._capture_spot(spot)

	if String(spot[0]) == "12_stair_end" and OS.get_cmdline_user_args().has("--stair-probe"):
		await _stair_probe()

	if String(spot[0]) == "11_bridge" and OS.get_cmdline_user_args().has("--bridge-probe"):
		await _bridge_probe()

	if String(spot[0]) == "08_unattached_outcrop":
		# Additional construction view; never substitutes for the reconstructed photo.
		_camera.global_position = Vector3(231.0,12.0,-377.8)
		_camera.look_at(Vector3(228.75,14.2,-381.5),Vector3.UP)
		_camera.force_update_transform()
		for frame in 4: await get_tree().process_frame
		await _shot("08_unattached_outcrop_underside")

class BridgeController extends CharacterController:
	var direction := Vector2.ZERO
	func get_move_vector(_character: CharacterBody3D,_delta: float)->Vector2: return direction

func _bridge_probe() -> void:
	var results: Array = []
	var controller := BridgeController.new()
	_character.controller=controller
	for z in range(266,340,2):
		var start := Vector3(312.3,25,z)
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,start+Vector3.DOWN*30))
		results.append({"probe_z":z,"hit":str(hit.get("position",Vector3.INF)),"collider":str(hit.get("collider","none"))})
	for reverse in [false,true]:
		var start := Vector3(312.3,16.4,335 if reverse else 267)
		var end_z := 267.0 if reverse else 335.0
		var sign_z := -1.0 if reverse else 1.0
		_character.global_position=start
		_character.velocity=Vector3.ZERO
		controller.direction=Vector2.ZERO
		for tick in 30:
			await get_tree().physics_frame
			_character._physics_process(1.0/60)
		controller.direction=Vector2(0,sign_z)
		var trace: Array = []
		for tick in 540:
			await get_tree().physics_frame
			_character._physics_process(1.0/60)
			if tick%15==0: trace.append(str(_character.global_position))
			if (_character.global_position.z-end_z)*sign_z>=0: break
		var row := {"walk_reverse":reverse,"trace":trace,"end":str(_character.global_position),"passed":(_character.global_position.z-end_z)*sign_z>=0 and _character.global_position.y>15}
		results.append(row)
		print("BRIDGE_WORLD ",JSON.stringify(row))
	controller.direction=Vector2.ZERO
	for z in [280,300,320]:
		_character.global_position=Vector3(312.3,20,z)
		_character.velocity=Vector3.ZERO
		for tick in 150:
			await get_tree().physics_frame
			_character._physics_process(1.0/60)
		results.append({"drop_z":z,"end":str(_character.global_position),"grounded":_character.is_on_floor(),"in_water":_character.in_water})
	FileAccess.open(_output_dir+"/bridge-world-physics.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))

func _prepare_swim_pose() -> void:
	_character.anim_tree.callback_mode_process=2
	_character.anim_tree.advance(0.01)
	_character.in_water=false
	_character.jump_animation(true)
	for tick in 40: _character.anim_tree.advance(1.0/60)
	_character.in_water=true
	_character.on_ground=false
	_character.velocity=Vector3.ZERO
	for tick in 180:
		_character.jump_animation(false)
		_character.movement_animation(0)
		_character.anim_tree.advance(1.0/60)

func _stair_probe() -> void:
	var results: Array = []
	var controller := BridgeController.new()
	_character.controller=controller
	for offset in [0.0,-1.5,1.5]:
		for descent in [false,true]:
			var revised := OS.get_cmdline_user_args().has("--stair-open-route")
			var start := Vector3(1296 if descent else 1284,20.25 if descent else 17.2,380+offset) if revised else Vector3(1296+offset,20.25 if descent else 17.2,380 if descent else 392)
			var direction := Vector3.LEFT if descent else Vector3.RIGHT
			var target := Vector3(1284 if descent else 1296,17 if descent else 20,380+offset)
			if not revised:
				direction=Vector3.BACK if descent else Vector3.FORWARD
				target=Vector3(1296+offset,17 if descent else 20,392 if descent else 380)
			_character.global_position=start
			_character.velocity=Vector3.ZERO
			controller.direction=Vector2.ZERO
			for tick in 30:
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
			controller.direction=Vector2(direction.x,direction.z)
			var trace: Array = []
			for tick in 240:
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
				if tick%10==0: trace.append(str(_character.global_position))
				if (_character.global_position-target).dot(direction)>=0: break
			var row := {"offset":offset,"descent":descent,"passed":(_character.global_position-target).dot(direction)>=0,"end":str(_character.global_position),"trace":trace}
			results.append(row)
			print("EXTERIOR_STAIR ",JSON.stringify(row))
	FileAccess.open(_output_dir+"/stair-world-physics.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
