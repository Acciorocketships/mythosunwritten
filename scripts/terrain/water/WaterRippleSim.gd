# scripts/terrain/water/WaterRippleSim.gd
# One player-centred dynamic-water domain for the unified water material:
# - a GPU wave-equation surface for interactive wakes/splashes, advected by
#   WaterSampler's current texture;
# - persistent compact asymmetric wavelets whose centres are transported by
#   that same current and turn with its vorticity around banks/obstacles.
# Both outputs are height fields sampled by vertex and fragment stages.
class_name WaterRippleSim
extends Node

const RES := 256
const DOMAIN := 96.0
const TEXEL := DOMAIN / RES
const FLOW_RES := 32
const FLOW_STEP := DOMAIN / FLOW_RES
const MAX_PACKETS := 16
const PACKET_AMPLITUDE_MIN := 0.10
const PACKET_AMPLITUDE_MAX := 0.22
const DROP_PERIOD := 0.12
const AMBIENT_PERIOD := 0.7
const PACKET_PERIOD := 0.22
const TAU := PI * 2.0

@export var player: Node3D

var _vp: Array[SubViewport] = []
var _mat: Array[ShaderMaterial] = []
var _cur: int = 0
var _origin := Vector2.ZERO
var _drop_timer := 0.0
var _ambient_timer := 0.0
var _ambient_n := 0
var _was_in_water := false
var _boot := 0

var _flow_tex: ImageTexture
var _flow_image: Image
var _flow_refresh := 0.0
var _samplers: Array[WaterSampler] = []

var _packet_vp: SubViewport
var _packet_mat: ShaderMaterial
var _packet_data_tex: ImageTexture
var _packet_data_image: Image
var _packets: Array[Dictionary] = []
var _packet_timer := 0.0
var _packet_n := 0


func _ready() -> void:
	add_to_group("water_dynamics")
	_flow_image = Image.create(FLOW_RES, FLOW_RES, false, Image.FORMAT_RGBAF)
	_flow_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	_flow_tex = ImageTexture.create_from_image(_flow_image)
	for i in 2:
		var vp := SubViewport.new()
		vp.size = Vector2i(RES, RES)
		vp.disable_3d = true
		vp.use_hdr_2d = true
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var rect := ColorRect.new()
		rect.size = Vector2(RES, RES)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://terrain/water/ripple_sim.gdshader")
		mat.set_shader_parameter("tex_size", Vector2(RES, RES))
		mat.set_shader_parameter("domain_size", DOMAIN)
		mat.set_shader_parameter("flow_tex", _flow_tex)
		rect.material = mat
		vp.add_child(rect)
		add_child(vp)
		_vp.append(vp)
		_mat.append(mat)

	_packet_data_image = Image.create(MAX_PACKETS, 2, false, Image.FORMAT_RGBAF)
	_packet_data_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	_packet_data_tex = ImageTexture.create_from_image(_packet_data_image)
	_packet_vp = SubViewport.new()
	_packet_vp.size = Vector2i(RES, RES)
	_packet_vp.disable_3d = true
	_packet_vp.use_hdr_2d = true
	_packet_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var packet_rect := ColorRect.new()
	packet_rect.size = Vector2(RES, RES)
	_packet_mat = ShaderMaterial.new()
	_packet_mat.shader = load("res://terrain/water/wave_packet_field.gdshader")
	_packet_mat.set_shader_parameter("packet_data", _packet_data_tex)
	_packet_mat.set_shader_parameter("field_size", DOMAIN)
	packet_rect.material = _packet_mat
	_packet_vp.add_child(packet_rect)
	add_child(_packet_vp)
	_origin = _snapped_origin()


func _player_xz() -> Vector2:
	if player == null:
		return Vector2.ZERO
	return Vector2(player.global_position.x, player.global_position.z)


## Snapping to the 3m current lattice makes the 64x64 flow texture exactly
## world aligned. Ripple-state shifts are still integral (four 0.75m texels).
func _snapped_origin() -> Vector2:
	var o: Vector2 = _player_xz() - Vector2.ONE * (DOMAIN * 0.5)
	return Vector2(snappedf(o.x, FLOW_STEP), snappedf(o.y, FLOW_STEP))


func _refresh_samplers() -> void:
	_samplers.clear()
	var seen: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group("water_volume"):
		if not node.has_meta("sampler"):
			continue
		var sampler: WaterSampler = node.get_meta("sampler")
		var key: int = sampler.get_instance_id()
		if seen.has(key):
			continue
		seen[key] = true
		_samplers.append(sampler)


func _sampler_at(p: Vector2) -> WaterSampler:
	for sampler: WaterSampler in _samplers:
		if not is_nan(sampler.level_at(p)):
			return sampler
	return null


## Rasterizes the frozen 3m WaterSampler currents into a small RGBAF texture.
## R/G are raw signed world-m/s velocity; B/A carry vorticity/compression for
## future GPU interaction work without another field reconstruction.
func _refresh_flow_texture() -> void:
	for j in FLOW_RES:
		for i in FLOW_RES:
			var p: Vector2 = _origin + (Vector2(i, j) + Vector2.ONE * 0.5) * FLOW_STEP
			var sampler: WaterSampler = _sampler_at(p)
			if sampler == null:
				_flow_image.set_pixel(i, j, Color(0.0, 0.0, 0.0, 0.0))
				continue
			var velocity: Vector2 = sampler.velocity_at(p)
			var diagnostics: Vector2 = sampler.flow_diagnostics_at(p)
			_flow_image.set_pixel(i, j,
				Color(velocity.x, velocity.y, diagnostics.x, diagnostics.y))
	_flow_tex.update(_flow_image)


func _hash01(n: int) -> float:
	return Helper._hash01(Helper._mix64(n))


## Finds a deterministic wet/current-bearing position anywhere in the active
## domain. New packets are born already inside water, never as a screen-space
## streak pasted over a dry or calm surface.
func _spawn_packet() -> bool:
	for attempt in 72:
		var n: int = _packet_n * 193 + attempt * 17
		var p := _origin + Vector2(_hash01(n + 11), _hash01(n + 71)) * DOMAIN
		var sampler: WaterSampler = _sampler_at(p)
		if sampler == null:
			continue
		var velocity: Vector2 = sampler.velocity_at(p)
		if velocity.length() < 0.2:
			continue
		var wavelength: float = lerpf(6.0, 10.0, _hash01(n + 113))
		var initial_direction: Vector2 = velocity.normalized().rotated(
			lerpf(-0.55, 0.55, _hash01(n + 149)))
		var packet: Dictionary = {
			"id": _packet_n,
			"p": p,
			"dir": initial_direction,
			"amp": lerpf(PACKET_AMPLITUDE_MIN, PACKET_AMPLITUDE_MAX,
				_hash01(n + 181)),
			"wavelength": wavelength,
			"radius": lerpf(wavelength * 0.75, wavelength * 1.1, _hash01(n + 233)),
			"phase": _hash01(n + 271) * TAU,
			"age": 0.0,
			"life": lerpf(13.0, 22.0, _hash01(n + 307)),
		}
		_packets.append(packet)
		_packet_n += 1
		return true
	_packet_n += 1
	return false


func _update_packets(delta: float) -> void:
	for i in range(_packets.size() - 1, -1, -1):
		var packet: Dictionary = _packets[i]
		packet.age += delta
		if packet.age >= packet.life:
			_packets.remove_at(i)
			continue
		var sampler: WaterSampler = _sampler_at(packet.p)
		if sampler == null:
			_packets.remove_at(i)
			continue
		var velocity: Vector2 = sampler.velocity_at(packet.p)
		if velocity.length() < 0.1:
			_packets.remove_at(i)
			continue
		var diagnostics: Vector2 = sampler.flow_diagnostics_at(packet.p)
		var target_dir: Vector2 = velocity.normalized().rotated(
			clampf(diagnostics.x * 2.5, -0.55, 0.55))
		packet.dir = packet.dir.lerp(target_dir,
			clampf(delta * 0.45, 0.0, 1.0)).normalized()
		packet.p += velocity * delta
		# Crests propagate downstream within the transported envelope too.
		packet.phase -= delta * lerpf(0.75, 1.25,
			clampf(velocity.length() / 4.5, 0.0, 1.0))

	_packet_timer -= delta
	if _packet_timer <= 0.0 and _packets.size() < MAX_PACKETS:
		_spawn_packet()
		_packet_timer = PACKET_PERIOD


func _upload_packets() -> void:
	_packet_data_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for i in _packets.size():
		var packet: Dictionary = _packets[i]
		var amplitude: float = _packet_amplitude(packet)
		_packet_data_image.set_pixel(i, 0, Color(packet.p.x, packet.p.y,
			amplitude, packet.wavelength))
		_packet_data_image.set_pixel(i, 1, Color(packet.dir.x, packet.dir.y,
			packet.radius, packet.phase))
	_packet_data_tex.update(_packet_data_image)
	_packet_mat.set_shader_parameter("packet_count", _packets.size())
	_packet_mat.set_shader_parameter("field_origin", _origin)
	_packet_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


static func _packet_amplitude(packet: Dictionary) -> float:
	var fade_in: float = smoothstep(0.0, 1.2, packet.age)
	var fade_out: float = smoothstep(0.0, 2.5, packet.life - packet.age)
	return packet.amp * minf(fade_in, fade_out)


## CPU mirror of wave_packet_field.gdshader for buoyancy. Interactive ripple
## height remains a small optical/contact detail; the broad transported 3D
## wavelets that a floating body must ride are mirrored exactly here.
func packet_height_at(p: Vector2) -> float:
	var height := 0.0
	for packet: Dictionary in _packets:
		height += packet_height(packet, p)
	return clampf(height, -0.48, 0.48)


static func packet_height(packet: Dictionary, p: Vector2) -> float:
	var direction: Vector2 = packet.dir.normalized()
	var side := Vector2(-direction.y, direction.x)
	var rel: Vector2 = p - packet.p
	var along: float = rel.dot(direction)
	var across: float = rel.dot(side)
	var radius: float = maxf(packet.radius, 0.1)
	var cross_radius: float = radius * 0.62
	var envelope: float = exp(-0.5 * (along * along / (radius * radius)
		+ across * across / (cross_radius * cross_radius)))
	var warped_along: float = along + sin(across / radius * PI + packet.phase) \
		* packet.wavelength * 0.12
	var warped_across: float = across + sin(along / radius * 2.1 \
		- packet.phase * 0.7) * packet.wavelength * 0.08
	var carrier_phase: float = TAU * warped_along / packet.wavelength + packet.phase
	var cross_phase: float = carrier_phase * 0.63 \
		+ warped_across / (packet.wavelength * 0.6) * PI - packet.phase * 0.4
	# A Gaussian-windowed Morlet-style carrier: several local rise/trough
	# crests with a finite envelope, never one closed refraction bubble and
	# never an infinite repeated streak train.
	var carrier: float = (sin(carrier_phase) + 0.28 * sin(cross_phase)) * 0.78
	return _packet_amplitude(packet) * carrier * envelope


## Harness-facing state: enough to falsify a visually static result without
## reaching into private buffers or inferring simulation health from a single
## beauty frame.
func debug_state() -> Dictionary:
	var ids := PackedInt32Array()
	var speeds := PackedFloat32Array()
	var positions := PackedVector2Array()
	for packet: Dictionary in _packets:
		ids.append(packet.id)
		var sampler: WaterSampler = _sampler_at(packet.p)
		speeds.append(sampler.velocity_at(packet.p).length() if sampler != null else 0.0)
		positions.append(packet.p)
	return {
		"samplers": _samplers.size(),
		"packets": _packets.size(),
		"ids": ids,
		"positions": positions,
		"speeds": speeds,
		"origin": _origin,
	}


func save_debug_images(prefix: String) -> void:
	RenderingServer.force_draw()
	_packet_vp.get_texture().get_image().save_png(prefix + "_packets.png")
	_vp[_cur].get_texture().get_image().save_png(prefix + "_ripples.png")


func _process(delta: float) -> void:
	var nxt: int = 1 - _cur
	var old_origin: Vector2 = _origin
	var new_origin: Vector2 = _snapped_origin()
	var origin_changed: bool = new_origin != old_origin
	_origin = new_origin
	_flow_refresh -= delta
	if origin_changed or _flow_refresh <= 0.0:
		_refresh_samplers()
		_refresh_flow_texture()
		_flow_refresh = 0.5

	var mat: ShaderMaterial = _mat[nxt]
	mat.set_shader_parameter("prev_tex", _vp[_cur].get_texture())
	mat.set_shader_parameter("flow_tex", _flow_tex)
	mat.set_shader_parameter("flow_dt", minf(delta, 0.05))
	mat.set_shader_parameter("shift_texels", ((new_origin - old_origin) / TEXEL).round())
	mat.set_shader_parameter("reset", _boot < 2)
	_boot += 1

	var drops: Array = [Vector4(-1, -1, 0, 0.01), Vector4(-1, -1, 0, 0.01), Vector4(-1, -1, 0, 0.01)]
	var di := 0
	var wet: bool = player != null and bool(player.get("in_water"))
	_drop_timer -= delta
	if wet and _drop_timer <= 0.0:
		var sp: float = Vector2(player.velocity.x, player.velocity.z).length()
		if sp > 0.8:
			var uv: Vector2 = (_player_xz() - new_origin) / DOMAIN
			drops[di] = Vector4(uv.x, uv.y, clampf(sp * 0.05, 0.02, 0.18), 2.5 / RES)
			di += 1
			_drop_timer = DROP_PERIOD
	if wet and not _was_in_water:
		# Preserve the old clear entry ring: this is a height impulse only. The
		# water material derives its strong normal/refraction ring from the wave
		# field and never turns the impulse into a white colour blob.
		var uv_in: Vector2 = (_player_xz() - new_origin) / DOMAIN
		drops[di] = Vector4(uv_in.x, uv_in.y,
			clampf(absf(player.velocity.y) * 0.05, 0.08, 0.3), 3.5 / RES)
		di += 1
	_was_in_water = wet
	_ambient_timer -= delta
	if _ambient_timer <= 0.0 and di < drops.size():
		_ambient_timer = AMBIENT_PERIOD
		_ambient_n += 1
		drops[di] = Vector4(_hash01(_ambient_n), _hash01(_ambient_n + 7919),
			0.012, 2.0 / RES)
	mat.set_shader_parameter("drop_a", drops[0])
	mat.set_shader_parameter("drop_b", drops[1])
	mat.set_shader_parameter("drop_c", drops[2])
	_vp[nxt].render_target_update_mode = SubViewport.UPDATE_ONCE
	_cur = nxt

	_update_packets(delta)
	_upload_packets()

	var wm: ShaderMaterial = WaterSurfaceBuilder.sheet_material()
	wm.set_shader_parameter("ripple_tex", _vp[_cur].get_texture())
	wm.set_shader_parameter("ripple_origin", _origin)
	wm.set_shader_parameter("ripple_size", DOMAIN)
	wm.set_shader_parameter("packet_tex", _packet_vp.get_texture())
	wm.set_shader_parameter("packet_origin", _origin)
	wm.set_shader_parameter("packet_size", DOMAIN)
