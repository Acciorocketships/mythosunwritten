extends SceneTree
## Windowed: the main-thread cost of one biome-effect particle emitter
## (BiomeChunkFx._point_effect) built and attached, repeated, split into
## build and add_child. Run: Godot --path . -s res://tests/harness/fx_step_probe.gd

var _frame := 0
var _root: Node3D

func _initialize() -> void:
	_root = Node3D.new()
	root.add_child(_root)
	var cam := Camera3D.new()
	_root.add_child(cam)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 5:
		return false
	if _frame > 40:
		return true
	var data := {"lo": 10.0, "hi": 30.0}
	for recipe: StringName in [&"motes", &"leaves", &"fireflies"]:
		var points := PackedVector3Array([Vector3(10, 12, 10), Vector3(40, 15, 70)])
		var t0 := Time.get_ticks_usec()
		var node: Node3D = BiomeChunkFx._point_effect(recipe, points, data)
		var t1 := Time.get_ticks_usec()
		_root.add_child(node)
		var t2 := Time.get_ticks_usec()
		print("FX_PROBE frame=%d %s build=%.2f attach=%.2f" % [_frame, recipe, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0])
	return false
