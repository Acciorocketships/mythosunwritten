# scripts/terrain/water/WaterRippleSim.gd
# GPU interactive water ripples: two SubViewports ping-pong a damped
# wave-equation texture (RG = height, velocity) over a world-space domain
# that follows the player snapped to the texel grid. The unified water
# shader samples the height gradient for normal detail; the character
# injects impulses while swimming, and sparse ambient droplets keep still
# water alive. Viewport ping-pong technique after CBerry22's Godot ripple
# simulation; adapted to an infinite world via the moving snapped domain.
class_name WaterRippleSim
extends Node

const RES := 256
const DOMAIN := 96.0                 # metres covered by the sim texture
const TEXEL := DOMAIN / RES
const DROP_PERIOD := 0.12            # min seconds between character wake drops
const AMBIENT_PERIOD := 0.35         # seconds between ambient droplets

@export var player: Node3D

var _vp: Array = []
var _mat: Array = []
var _cur: int = 0
var _origin: Vector2 = Vector2.ZERO  # world XZ of the texture's (0,0) corner
var _drop_timer: float = 0.0
var _ambient_timer: float = 0.0
var _ambient_n: int = 0
var _was_in_water: bool = false
var _boot: int = 0   # first frames render pure rest state into both buffers


func _ready() -> void:
	for i in 2:
		var vp := SubViewport.new()
		vp.size = Vector2i(RES, RES)
		vp.disable_3d = true
		vp.use_hdr_2d = true   # 16F target: 8-bit heights band and kill small rings
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var rect := ColorRect.new()
		rect.size = Vector2(RES, RES)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://terrain/water/ripple_sim.gdshader")
		mat.set_shader_parameter("tex_size", Vector2(RES, RES))
		rect.material = mat
		vp.add_child(rect)
		add_child(vp)
		_vp.append(vp)
		_mat.append(mat)
	_origin = _snapped_origin()


func _player_xz() -> Vector2:
	if player == null:
		return Vector2.ZERO
	return Vector2(player.global_position.x, player.global_position.z)


## Domain origin centred on the player, snapped to the texel grid so the
## sampling lattice never slides relative to the world.
func _snapped_origin() -> Vector2:
	var o: Vector2 = _player_xz() - Vector2.ONE * (DOMAIN * 0.5)
	return Vector2(snappedf(o.x, TEXEL), snappedf(o.y, TEXEL))


func _process(delta: float) -> void:
	var nxt: int = 1 - _cur
	var new_origin: Vector2 = _snapped_origin()
	var mat: ShaderMaterial = _mat[nxt]
	mat.set_shader_parameter("prev_tex", _vp[_cur].get_texture())
	mat.set_shader_parameter("shift_texels", ((new_origin - _origin) / TEXEL).round())
	# Both buffers start as BLACK textures (-0.5 bias when decoded); render
	# pure rest state into each once, or every later domain shift steps the
	# border against the bias and launches straight wavefronts.
	mat.set_shader_parameter("reset", _boot < 2)
	_boot += 1

	var drops: Array = [Vector4(-1, -1, 0, 0.01), Vector4(-1, -1, 0, 0.01), Vector4(-1, -1, 0, 0.01)]
	var di: int = 0
	var wet: bool = player != null and bool(player.get("in_water"))
	_drop_timer -= delta
	if wet and _drop_timer <= 0.0:
		var sp: float = Vector2(player.velocity.x, player.velocity.z).length()
		if sp > 0.8:
			var uv: Vector2 = (_player_xz() - new_origin) / DOMAIN
			drops[di] = Vector4(uv.x, uv.y, clampf(sp * 0.05, 0.02, 0.18), 2.5 / RES)
			di += 1
			_drop_timer = DROP_PERIOD
	# ENTRY SPLASH: hitting the water must ripple even with no control held —
	# the wake gate above keys on HORIZONTAL speed and misses a plain plunge
	# (owner: jumping in without pressing a control made no ripple). One big
	# drop on the dry->wet edge, scaled by the vertical impact speed.
	if wet and not _was_in_water:
		var uv_in: Vector2 = (_player_xz() - new_origin) / DOMAIN
		drops[di] = Vector4(uv_in.x, uv_in.y,
			clampf(absf(player.velocity.y) * 0.05, 0.08, 0.3), 3.5 / RES)
		di += 1
	_was_in_water = wet
	_ambient_timer -= delta
	if _ambient_timer <= 0.0:
		_ambient_timer = AMBIENT_PERIOD
		_ambient_n += 1
		drops[di] = Vector4(
			Helper._hash01(Helper._mix64(_ambient_n)),
			Helper._hash01(Helper._mix64(_ambient_n + 7919)),
			0.035, 2.0 / RES)
	mat.set_shader_parameter("drop_a", drops[0])
	mat.set_shader_parameter("drop_b", drops[1])
	mat.set_shader_parameter("drop_c", drops[2])
	_vp[nxt].render_target_update_mode = SubViewport.UPDATE_ONCE
	_origin = new_origin
	_cur = nxt

	var wm: ShaderMaterial = WaterSurfaceBuilder.sheet_material()
	wm.set_shader_parameter("ripple_tex", _vp[_cur].get_texture())
	wm.set_shader_parameter("ripple_origin", _origin)
	wm.set_shader_parameter("ripple_size", DOMAIN)
