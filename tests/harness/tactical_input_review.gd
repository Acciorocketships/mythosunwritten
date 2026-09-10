extends Node3D
class TracedCamera extends "res://scripts/camera/camera.gd":
	func _input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			print("EDGE_INPUT pos=", event.position, " relative=", event.relative,
				" screen_relative=", event.screen_relative, " rect=", get_viewport().get_visible_rect(),
				" transform=", get_viewport().get_screen_transform(), " mode=", Input.mouse_mode,
				" capture=", _edge_captured, " yaw=", _yaw)
		super._input(event)
	func _unhandled_input(event: InputEvent) -> void:
		super._unhandled_input(event)
		if event is InputEventMouseMotion:
			print("EDGE_UNHANDLED pending=", _mouse_orbit, " capture=", _edge_captured, " mode=", Input.mouse_mode)

func _ready() -> void:
	var actor := load("res://characters/character.tscn").instantiate() as CharacterBody3D
	add_child(actor)
	actor.set_physics_process(false)
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
		label.text = "Drag beyond either edge. F7 toggles. Escape releases.\nYaw %.2f° | pointer %s | captured %s | viewport %s" % [rad_to_deg(camera._yaw),camera.pointing_position(),camera._edge_captured,get_viewport().get_visible_rect().size])
