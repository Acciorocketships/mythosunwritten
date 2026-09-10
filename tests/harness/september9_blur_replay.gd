extends "res://tests/harness/september9_orb_replay.gd"

func _sample_times() -> Array:
	return [0.0]

func _run(camera: Camera3D, fixture: String) -> void:
	var director := AtmosphereDirector.new()
	director.environment_node = _world.get_node("WorldEnvironment")
	director.sun = _world.get_node("DirectionalLight3D")
	director.camera = camera
	director._apply_grade()
	director.free()
	await super._run(camera,fixture)
