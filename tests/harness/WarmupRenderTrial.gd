extends RefCounted
## Test-only: equal full-view coverage every four frames, in one fixed world.
const WARMER = preload("res://scripts/terrain/field/FirstViewWarmer.gd")
var _warmer: Node
var _mode := ""
var _frame := 0
var _size: Vector2i
func _init(warmer: Node, centre: Vector3) -> void:
	_warmer = warmer
	_size = warmer._viewport.size
	warmer.set_process(false)
	warmer._camera.global_position = centre + Vector3(0,WARMER.HEIGHT,WARMER.BACK)
	warmer._camera.look_at(centre,Vector3.UP)
func mode(value: String) -> void:
	_mode = value
	_frame = 0
	_warmer._viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
func step() -> void:
	var view: SubViewport = _warmer._viewport
	var camera: Camera3D = _warmer._camera
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _mode == "warm_full" and _frame % 4 == 0:
		view.size = WARMER.SIZE
		camera.set_perspective(WARMER.FOV,camera.near,camera.far)
		view.render_target_update_mode = SubViewport.UPDATE_ONCE
	elif _mode in ["warm_strips","warm_quads"]:
		var grid := Vector2i(4,1) if _mode == "warm_strips" else Vector2i(2,2)
		view.size = WARMER.SIZE / grid
		WARMER.configure_slice(camera,WARMER.FOV,_frame % 4,grid)
		view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_frame += 1
func restore() -> void:
	_warmer._viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_warmer._viewport.size = _size
	_warmer.set_process(true)
