extends "res://tests/harness/september16_manual_qa.gd"
const EVIDENCE = "res://docs/qa/2026-09-19-manual/106-town-path-context/after-source/plan-evidence.bin"
class RoadController extends CharacterController:
	var direction := Vector2.ZERO
	func get_move_vector(_character: CharacterBody3D, _delta: float) -> Vector2: return direction

func _capture_views(world: Node3D) -> void:
	_freeze_material_clocks(world)
	_capture_view.size = Vector2i(1600,1000)
	_character.visible = false
	for view: Array in [["route_above",Vector3(-1043,45,1032),Vector3(-1043,9,1067)], ["gate",Vector3(-1021,22,1064),Vector3(-1033,9,1083)], ["garden_side",Vector3(-1060,18,1061),Vector3(-1044,11,1066)]]:
		_camera.global_position = view[1]
		_camera.look_at(view[2])
		_camera.fov = 65
		await _shot(view[0])
	var control := "--control" in OS.get_cmdline_user_args()
	var route: Array[Vector2] = [Vector2(-1056,1056),Vector2(-1056,1064),Vector2(-1032,1064),Vector2(-1032,1082)]
	if not control:
		var data: Dictionary = FileAccess.open(EVIDENCE,FileAccess.READ).get_var()
		route.assign(data.roads[0].points)
	var centres: Array[Vector2] = []
	for shape: FeatureGroundShape in PathProgram.filleted_path_shapes(route,2,1,120,&"walk"):
		var a := shape._a
		var b := shape._b
		if shape.kind == FeatureGroundShape.Kind.ORIENTED_RECT:
			var d := Vector2(shape._half_extents.x,0).rotated(shape._angle)
			a = shape._a - d
			b = shape._a + d
		if centres.is_empty() or centres[-1].distance_to(a) > .001: centres.append(a)
		centres.append(b)
	var space := _camera.get_world_3d().direct_space_state
	var own: Array[RID] = [_character.get_rid()]
	for body: Node in _character.find_children("*","CollisionObject3D",true,false): own.append(body.get_rid())
	var player_shape := _character.get_node("CollisionShape3D") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = player_shape.shape
	query.collision_mask = 1
	query.exclude = own
	query.margin = .01
	var checked := 0
	var blocked: Array = []
	for i in range(1,centres.size()):
		var a := centres[i-1]
		var b := centres[i]
		var side := (b-a).normalized().orthogonal()
		for j in maxi(1,ceili(a.distance_to(b)/.5)):
			var p := a.lerp(b,float(j)/maxi(1,ceili(a.distance_to(b)/.5)))
			for offset: float in [-1.4,0,1.4]:
				var xz := p+side*offset
				query.transform = Transform3D(Basis.IDENTITY,Vector3(xz.x,9.05,xz.y))*player_shape.transform
				var hits := space.intersect_shape(query,16)
				checked += 1
				if not hits.is_empty(): blocked.append({"point":str(xz),"offset":offset,"hits":hits.size()})
	var report: Dictionary = {"control":control,"route":route,"capsule_samples":checked,"blocked":blocked,"walks":[]}
	_character.visible = true
	_character.process_mode = Node.PROCESS_MODE_ALWAYS
	var controller := RoadController.new()
	_character.controller = controller
	for reverse: bool in [false,true]:
		var points := centres.duplicate()
		if reverse: points.reverse()
		_character.set_physics_process(false)
		_character.global_position = Vector3(points[0].x,9.10,points[0].y)
		_character.velocity = Vector3.ZERO
		_character.set_physics_process(true)
		controller.direction = Vector2.ZERO
		for frame in 20: await get_tree().physics_frame
		var index := 1
		var ticks := 0
		var stagnant := 0
		var progress := _character.global_position
		var trace: Array = []
		while index < points.size() and ticks < 7200 and stagnant < 360:
			await get_tree().physics_frame
			var p := _character.global_position
			var delta: Vector2 = points[index]-Vector2(p.x,p.z)
			if delta.length() < .15:
				index += 1
				continue
			controller.direction = delta.normalized()*.65
			_camera.global_position = p+Vector3(0,13,-18)
			_camera.look_at(p+Vector3.UP)
			stagnant += 1
			if p.distance_to(progress) > .3:
				progress = p
				stagnant = 0
			if ticks%60 == 0: trace.append({"tick":ticks,"point":str(p),"segment":index,"floor":_character.is_on_floor()})
			ticks += 1
		controller.direction = Vector2.ZERO
		_character.set_physics_process(false)
		report.walks.append({"reverse":reverse,"passed":index == points.size(),"reached":index,"segments":points.size()-1,"ticks":ticks,"position":str(_character.global_position),"trace":trace})
		await _shot("walk_%s" % reverse)
		print("TOWN_PATH_WALK reverse=",reverse," passed=",index == points.size()," position=",_character.global_position)
	FileAccess.open(_output_dir.path_join("physics.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TOWN_PATH_CAPSULE samples=",checked," blocked=",blocked.size())
