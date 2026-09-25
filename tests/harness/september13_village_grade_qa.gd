extends "res://tests/harness/september13_path_qa.gd"
func _spots() -> Array:
	return [["P24_collar","2026-09-12 12.20.18 PM",Vector3(-270.2,16,454),Vector3(-275.1,12,444.4)],
		["P11_approach","2026-09-12 12.08.40 PM",Vector3(980.5,17,-374.7),Vector3(981.3,19.5,-377.4)]]

func _walk_corridor(_world: Node3D) -> void:
	var controller := WalkController.new()
	_character.controller = controller
	_character.set_physics_process(false)
	_character.anim_tree.active = true
	var space := _camera.get_world_3d().direct_space_state
	var excluded: Array[RID] = [_character.get_rid()]
	var origin := Vector2(980.5,-374.7) if _spot[0] == "P11_approach" else Vector2(-270.2,454)
	var destination := Vector2(981.1,-382.0) if _spot[0] == "P11_approach" else Vector2(-287,437)
	var direction := (destination-origin).normalized()
	var side := Vector2(-direction.y,direction.x)
	var survey := []
	for offset: float in [-1,0,1]:
		for index in range(101):
			var point := origin.lerp(destination,index/100.0)+side*offset
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x,24,point.y),Vector3(point.x,-4,point.y),1,excluded))
			if not hit.is_empty(): survey.append({"offset":offset,"index":index,"x":point.x,"z":point.y,"y":hit.position.y,"normal":str(hit.normal),"body":str(hit.collider.get_path())})
	FileAccess.open(_output_dir.path_join("grade-survey.json"),FileAccess.WRITE).store_string(JSON.stringify(survey,"  "))
	var reports := []
	for sign_value: float in [1,-1]:
		for offset: float in [-1,0,1]:
			var start := (origin if sign_value > 0 else destination)+side*offset
			var finish := (destination if sign_value > 0 else origin)+side*offset
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(start.x,24,start.y),Vector3(start.x,-4,start.y),1,excluded))
			assert(not hit.is_empty())
			_character.global_position = hit.position+Vector3.UP*.1
			_character.velocity = Vector3.ZERO
			controller.direction = Vector2.ZERO
			for tick in 30:
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
			var trace := []
			controller.direction = direction*sign_value*.55
			var passed := false
			for tick in 420:
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
				var p := _character.global_position
				trace.append({"tick":tick,"x":p.x,"y":p.y,"z":p.z,"floor":_character.is_on_floor()})
				if (Vector2(p.x,p.z)-finish).dot(direction*sign_value) >= 0:
					passed = true
					break
			controller.direction = Vector2.ZERO
			reports.append({"direction":sign_value,"offset":offset,"passed":passed,"trace":trace})
			print("GRADE_WALK ",_spot[0]," direction=",sign_value," offset=",offset," passed=",passed)
	FileAccess.open(_output_dir.path_join("walking.json"),FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
