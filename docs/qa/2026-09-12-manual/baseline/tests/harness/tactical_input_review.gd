extends Node3D
class TracedCamera extends "res://scripts/camera/camera.gd":
	func _ready() -> void:
		super._ready()
		FileAccess.open("res://.artifacts/tactical-native-state.log", FileAccess.WRITE).store_line("READY native_origin=%s" % DisplayServer.window_get_position(get_window().get_window_id()))
	func _trace(line: String) -> void:
		var file := FileAccess.open("res://.artifacts/tactical-native-state.log", FileAccess.READ_WRITE)
		file.seek_end()
		file.store_line(line)
	func _input(event: InputEvent) -> void:
		var previous_mode := Input.mouse_mode
		if event is InputEventMouseMotion:
			print("EDGE_INPUT pos=", event.position, " relative=", event.relative,
				" screen_relative=", event.screen_relative, " rect=", get_viewport().get_visible_rect(),
				" transform=", get_viewport().get_screen_transform(), " pixel=", _pointer_pixel_size(), " mode=", Input.mouse_mode,
				" capture=", _edge_captured, " yaw=", _yaw)
		super._input(event)
		if Input.mouse_mode != previous_mode:
			_trace("MODE %s -> %s pointer=%s buttons=%s" % [previous_mode, Input.mouse_mode, _pointer, Input.get_mouse_button_mask()])
	func _unhandled_input(event: InputEvent) -> void:
		super._unhandled_input(event)
		if event is InputEventMouseMotion:
			print("EDGE_UNHANDLED pending=", _mouse_orbit, " capture=", _edge_captured, " mode=", Input.mouse_mode)
			if _edge_captured:
				_trace("CAPTURE relative=%s pending=%s buttons=%s" % [event.relative, _mouse_orbit, event.button_mask])
	func _notification(what: int) -> void:
		if what in [NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
			print("EDGE_FOCUS notification=", what, " captured=", _edge_captured)
		super._notification(what)

func _ready() -> void:
	get_window().title = "Tactical input test - continuous cursor"
	var actor := load("res://characters/character.tscn").instantiate() as CharacterBody3D
	add_child(actor)
	actor.controller = PlayerController.new()
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10000,1,10000)
	collision.shape = shape
	collision.position.y = -0.5
	floor.add_child(collision)
	add_child(floor)
	var camera := Camera3D.new()
	camera.set_script(TracedCamera)
	camera.target = actor
	camera.visibility_bubble_enabled = false
	add_child(camera)
	camera.make_current()
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-20,0)
	add_child(light)
	for x in range(-4,5):
		for z in range(-3,4):
			var mesh := MeshInstance3D.new()
			mesh.mesh = BoxMesh.new()
			mesh.position = Vector3(x*4,0,z*4)
			add_child(mesh)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(20,20)
	add_child(label)
	get_tree().process_frame.connect(func():
		label.text = "CONTINUOUS CURSOR TEST: move the drawn cursor to either side, then outward.\nWASD moves. F7 toggles. Escape releases; click to resume.\nYaw %.2f° | pointer %s | captured %s | player %s" % [rad_to_deg(camera._yaw),camera.pointing_position(),camera._edge_captured,actor.position])
