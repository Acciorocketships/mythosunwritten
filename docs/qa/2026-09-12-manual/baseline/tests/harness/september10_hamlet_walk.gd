extends "res://tests/harness/september10_hamlet_qa.gd"

class WalkController extends CharacterController:
	var direction := Vector2.ZERO
	func get_move_vector(_character: CharacterBody3D, _delta: float) -> Vector2:
		return direction

func _capture_all() -> void:
	var player := SCALE_CHARACTER_SCENE.instantiate() as CharacterBody3D
	var controller := WalkController.new()
	player.controller = controller
	add_child(player)
	player.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var routes: Array[Dictionary] = []
	var radius := float(_production_urban.fabric_audit.square_radius)
	for side in 4:
		var angle := side * PI * 0.5
		var start := Vector3(-radius + 2, 0, radius).rotated(Vector3.UP, angle)
		var end := Vector3(radius - 2, 0, radius).rotated(Vector3.UP, angle)
		routes.append({"id":"square.%d" % side, "start":start, "end":end})
	var inverse := _production_urban.world_transform.affine_inverse()
	for house: VillageMassingPlacement in _production_urban.ground_settlement.placements:
		var start := inverse * Vector3(house.street_contact.x, house.street_contact_y, house.street_contact.y)
		var end := inverse * Vector3(house.entrance_ground_contact.x, house.entrance_ground_y, house.entrance_ground_contact.y)
		# The native LPFV door is closed. Stop on its approach, before the leaf.
		var direction := ((end-start) * Vector3(1,0,1)).normalized()
		end -= direction * 1.0
		routes.append({"id":String(house.asset_id), "start":start, "end":end})
	var rows: Array = []
	for route: Dictionary in routes:
		for reverse in [false,true]:
			var start: Vector3 = route.end if reverse else route.start
			var target: Vector3 = route.start if reverse else route.end
			var direction := ((target-start) * Vector3(1,0,1)).normalized()
			player.global_position = start + Vector3.UP * 0.2
			player.velocity = Vector3.ZERO
			controller.direction = Vector2.ZERO
			for tick in 30:
				await get_tree().physics_frame
				player._physics_process(1.0/60.0)
			controller.direction = Vector2(direction.x,direction.z)
			var trace: Array = []
			for tick in 600:
				await get_tree().physics_frame
				player._physics_process(1.0/60.0)
				trace.append([player.position.x,player.position.y,player.position.z,player.is_on_floor()])
				if (player.position-target).dot(direction) >= -0.1: break
			var passed := trace.size() < 600 and absf(player.position.y-target.y) < 0.5 and player.is_on_floor()
			var row := {"id":route.id,"reverse":reverse,"passed":passed,"start":str(start),"target":str(target),"trace":trace}
			rows.append(row)
			print("HAMLET_WALK ",route.id," reverse=",reverse," passed=",passed," end=",player.position)
	controller.direction = Vector2.ZERO
	FileAccess.open(_output_dir.path_join("walking.json"),FileAccess.WRITE).store_string(JSON.stringify(rows))
	var passed := true
	for row: Dictionary in rows: passed = passed and bool(row.passed)
	get_tree().quit(0 if passed else 1)
