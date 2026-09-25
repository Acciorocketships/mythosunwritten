extends SceneTree

class JumpController extends CharacterController:
	var direction := Vector2.ZERO
	var jumping := false
	func get_move_vector(_body: CharacterBody3D, _delta: float) -> Vector2:
		return direction
	func wants_jump(_body: CharacterBody3D, _delta: float) -> bool:
		return jumping

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var terraces := preload("res://scripts/terrain/field/CliffTerraces.gd")
	terraces.prepare()
	var rows := []
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(50, 2, 50)
	floor_shape.shape = floor_box
	floor_shape.position.y = -1
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	var actor := (load("res://characters/character.tscn") as PackedScene).instantiate()
	root.add_child(actor)
	actor.set_physics_process(false)
	var controller := JumpController.new()
	actor.controller = controller
	for suffix in ["2x2x4", "4x2x4", "4x4x4", "8x4x4"]:
		var definition: Dictionary = terraces._definitions[StringName("kaykit.terrace.%s" % suffix)]
		var bounds: AABB = definition.bounds
		print("TERRACE_COLLISION_COST asset=",suffix," native_triangles=",definition.faces.size()/3," terrain_triangles=",definition.collision_faces.size()/3)
		for solid_control in [false, true]:
			var obstacle := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			if solid_control:
				var box := BoxShape3D.new()
				box.size = bounds.size
				shape.shape = box
				shape.position = bounds.get_center() - Vector3.UP * bounds.position.y
			else:
				var native := ConcavePolygonShape3D.new()
				native.set_faces(definition.collision_faces if "--candidate" in OS.get_cmdline_user_args() else definition.faces)
				shape.shape = native
				shape.position.y = -bounds.position.y
			obstacle.add_child(shape)
			root.add_child(obstacle)
			for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				controller.jumping = false
				controller.direction = -direction
				var edge := Vector2(bounds.get_center().x, bounds.get_center().z) + direction * Vector2(bounds.size.x, bounds.size.z) * .5
				actor.global_position = Vector3(edge.x + direction.x * .8, .03, edge.y + direction.y * .8)
				actor.velocity = Vector3.ZERO
				for tick in 40:
					await physics_frame
					actor._physics_process(1.0 / 60)
				var start: Vector3 = actor.global_position
				var highest := start.y
				var ceiling_contacts := 0
				var reached := false
				var motion_usec: Array[int] = []
				for tick in 100:
					controller.jumping = tick == 0
					await physics_frame
					var started := Time.get_ticks_usec()
					actor._physics_process(1.0 / 60)
					motion_usec.append(Time.get_ticks_usec() - started)
					highest = maxf(highest, actor.global_position.y)
					for c in actor.get_slide_collision_count():
						if actor.get_slide_collision(c).get_normal().y < -.05: ceiling_contacts += 1
					if actor.is_on_floor() and actor.global_position.y > bounds.size.y - .1:
						reached = true
						break
				motion_usec.sort()
				var row := {"asset": suffix, "solid_control": solid_control, "direction": str(direction), "start": str(start),
					"end": str(actor.global_position), "highest": highest, "ceiling_contacts": ceiling_contacts, "reached": reached,
					"motion_p50_usec":motion_usec[motion_usec.size()/2],"motion_p95_usec":motion_usec[floori((motion_usec.size()-1)*.95)]}
				rows.append(row)
				print("TERRACE_JUMP ", JSON.stringify(row))
			obstacle.free()
			await physics_frame
	var output := "res://docs/qa/2026-09-13-manual/23-terraces/jump-before.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	quit()
