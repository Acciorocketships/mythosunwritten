extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var actor := load("res://characters/character.tscn").instantiate() as CharacterBody3D
	root.add_child(actor)
	actor.set_physics_process(false)
	actor.anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	actor.anim_tree.set("parameters/BlendTree/IdleMotion/blend_amount", 1.0)
	actor.anim_tree.set("parameters/BlendTree/RunSpeed/scale", 1.0)
	var measure = load("res://tests/test_directional_locomotion.gd").new()
	var result := {}
	for mode in ["walk", "mixed", "run", "back"]:
		actor.anim_tree.set("parameters/BlendTree/Direction/0/blend_position", 0.0 if mode == "walk" else (0.5 if mode == "mixed" else 1.0))
		var angles := []
		for i in 33:
			var weight := i / 32.0
			var angle := 0.0
			for side in [-1.0, 1.0]:
				var blend := Vector2(side * weight, -(1-weight)) if mode != "back" else Vector2(side * (1-weight), weight)
				actor.anim_tree.set("parameters/BlendTree/Direction/blend_position", blend)
				var travel: Vector3 = measure.stance_travel(actor)
				angle += rad_to_deg(atan2(absf(travel.x),travel.z)) * 0.5
			angles.append(snappedf(angle,0.001))
		result[mode] = angles
	var path := "res://docs/qa/2026-09-10-tactical/retargeted-blend-angles.json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"  ") + "\n")
	var code := "extends RefCounted\n## Generated from actual retargeted skeleton contact sweeps.\n## Regenerate with tests/harness/directional_blend_calibration.gd.\n"
	for mode in ["walk", "mixed", "run", "back"]:
		var angles: Array = result[mode].duplicate()
		angles[0] = 90 if mode == "back" else 0
		angles[-1] = 180 if mode == "back" else 90
		code += "const %s := %s\n" % [mode.to_upper(), JSON.stringify(angles)]
	FileAccess.open("res://scripts/controllers/DirectionalBlendCalibration.gd",FileAccess.WRITE).store_string(code)
	print(JSON.stringify(result))
	measure.free()
	actor.free()
	quit()
