class_name TrampleField
extends Node

const RESOLUTION := 256
const DOMAIN_SIZE := 64.0
const TEXEL_SIZE := DOMAIN_SIZE / float(RESOLUTION)
const SCROLL_THRESHOLD := 8.0
const RECOVERY_SECONDS := 10.0
const EPOCH_SECONDS := 60.0
const UPLOAD_INTERVAL := 1.0 / 30.0
const HOLD_INTERVAL := 2.0
const STAMP_SPACING := TEXEL_SIZE
## Collection 5 spans about 2.76 m and samples each authored blade root. A
## character-width 0.45 m stamp touched too few roots to read during motion;
## this broader wake visibly parts the patch without flattening whole beds.
const PLAYER_RADIUS := 1.1
const TRAMPLE_FULL_SPEED := 4.0
const MIN_MOVING_STRENGTH := 0.72
const NEUTRAL := Color(0.5, 0.5, 0.0, 0.0)

@export var player: Node3D

var _image: Image
var _texture: ImageTexture
var _static_image: Image
var _static_texture: ImageTexture
var _static_stamps: Array[Dictionary] = []
var _origin := Vector2.ZERO
# The GPU texture and its world origin are one render-state snapshot. Scrolling
# changes the CPU image immediately, but the published origin must keep matching
# the last uploaded pixels until the scheduled texture upload occurs.
var _texture_origin := Vector2.ZERO
var _epoch_start := 0.0
var _now := 0.0
var _upload_elapsed := 0.0
var _hold_elapsed := 0.0
var _dirty := false
var _static_dirty := false
var _previous_position := Vector3.ZERO
var _previous_grounded := false
var _has_previous := false
var _last_direction := Vector2.RIGHT
var upload_count := 0

func _ready() -> void:
	_initialize(_player_xz())

func _process(delta: float) -> void:
	if _image == null:
		_initialize(_player_xz())
	_update_time(delta)
	var current := player.global_position if player != null else Vector3.ZERO
	_scroll_if_needed(Vector2(current.x, current.z))
	var body := player as CharacterBody3D
	var grounded := body != null and body.is_on_floor()
	if _has_previous and grounded:
		var horizontal := Vector2(current.x - _previous_position.x,
			current.z - _previous_position.z)
		var speed := Vector2(body.velocity.x, body.velocity.z).length()
		if horizontal.length_squared() > 0.000001 and _previous_grounded:
			_last_direction = horizontal.normalized()
			stamp_segment(_previous_position, current, PLAYER_RADIUS,
				clampf(speed / TRAMPLE_FULL_SPEED, MIN_MOVING_STRENGTH, 1.0))
			_hold_elapsed = 0.0
		else:
			_hold_elapsed += delta
			if _hold_elapsed >= HOLD_INTERVAL:
				stamp(current, _last_direction, PLAYER_RADIUS, MIN_MOVING_STRENGTH)
				_hold_elapsed = 0.0
	else:
		_hold_elapsed = 0.0
	_previous_position = current
	_previous_grounded = grounded
	_has_previous = true
	_upload_if_due(delta)
	_publish_globals()

func stamp(world_pos: Vector3, direction: Vector2, radius: float,
		strength: float) -> void:
	if _image == null or not is_finite(radius) or radius <= 0.0:
		return
	var point := Vector2(world_pos.x, world_pos.z)
	var pixel := _world_to_pixel(point)
	var pixel_radius := int(ceil(radius / TEXEL_SIZE))
	var resolved_direction := direction.normalized() \
		if direction.length_squared() > 0.000001 else _last_direction
	var new_strength := clampf(strength, 0.0, 1.0)
	for y in range(pixel.y - pixel_radius, pixel.y + pixel_radius + 1):
		if y < 0 or y >= RESOLUTION:
			continue
		for x in range(pixel.x - pixel_radius, pixel.x + pixel_radius + 1):
			if x < 0 or x >= RESOLUTION:
				continue
			var sample_world := _origin + (Vector2(x, y) + Vector2.ONE * 0.5) * TEXEL_SIZE
			if sample_world.distance_squared_to(point) > radius * radius:
				continue
			var old := _image.get_pixel(x, y)
			var old_effective := _effective(old, _now)
			var old_direction := Vector2(old.r, old.g) * 2.0 - Vector2.ONE
			var merged := old_direction * old_effective \
				+ resolved_direction * new_strength
			var merged_direction := resolved_direction if merged.length_squared() <= 0.000001 \
				else merged.normalized()
			_image.set_pixel(x, y, Color(
				merged_direction.x * 0.5 + 0.5,
				merged_direction.y * 0.5 + 0.5,
				maxf(old_effective, new_strength), _now))
	_dirty = true

func stamp_segment(from: Vector3, to: Vector3, radius: float,
		strength: float) -> void:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var delta := b - a
	var distance := delta.length()
	var direction := delta.normalized() if distance > 0.000001 else _last_direction
	var steps := maxi(1, int(ceil(distance / STAMP_SPACING)))
	for index in range(steps + 1):
		var t := float(index) / float(steps)
		var point := a.lerp(b, t)
		stamp(Vector3(point.x, lerpf(from.y, to.y, t), point.y),
			direction, radius, strength)

func sample(world_xz: Vector2) -> Color:
	if _image == null:
		return NEUTRAL
	var pixel := _world_to_pixel(world_xz)
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= RESOLUTION or pixel.y >= RESOLUTION:
		return NEUTRAL
	return _image.get_pixelv(pixel)

func effective_strength(world_xz: Vector2) -> float:
	return _effective(sample(world_xz), _now)

## Replace the persistent structural footprint set. Each stamp contains an
## ordered world-XZ polygon compiled from the asset's near-ground vertices.
## It never touches the recovering player image, so a footstep can override
## the visible bend and then blend back without a periodic reset.
func set_static_stamps(stamps: Array[Dictionary]) -> void:
	_static_stamps.clear()
	for stamp: Dictionary in stamps:
		_static_stamps.append(stamp.duplicate(true))
	if _static_image != null:
		_rebuild_static_image()

func static_sample(world_xz: Vector2) -> Color:
	if _static_image == null:
		return NEUTRAL
	var pixel := _world_to_pixel(world_xz)
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= RESOLUTION or pixel.y >= RESOLUTION:
		return NEUTRAL
	return _static_image.get_pixelv(pixel)

func static_strength(world_xz: Vector2) -> float:
	return static_sample(world_xz).b

func _initialize(centre: Vector2) -> void:
	_image = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBAH)
	_image.fill(NEUTRAL)
	_texture = ImageTexture.create_from_image(_image)
	_static_image = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBAH)
	_static_image.fill(NEUTRAL)
	_static_texture = ImageTexture.create_from_image(_static_image)
	_origin = _snapped_origin(centre)
	_texture_origin = _origin
	_epoch_start = Time.get_ticks_msec() / 1000.0
	_now = 0.0
	if not _static_stamps.is_empty():
		_rebuild_static_image()
	_publish_globals()

func _update_time(delta: float) -> void:
	_now += delta
	if _now < EPOCH_SECONDS:
		return
	for y in RESOLUTION:
		for x in RESOLUTION:
			var value := _image.get_pixel(x, y)
			value.a -= EPOCH_SECONDS
			_image.set_pixel(x, y, value)
	_now -= EPOCH_SECONDS
	_epoch_start += EPOCH_SECONDS
	_dirty = true

func _scroll_if_needed(centre: Vector2) -> void:
	var current_centre := _origin + Vector2.ONE * (DOMAIN_SIZE * 0.5)
	if current_centre.distance_to(centre) <= SCROLL_THRESHOLD:
		return
	var new_origin := _snapped_origin(centre)
	var delta := Vector2i(roundi((new_origin.x - _origin.x) / TEXEL_SIZE),
		roundi((new_origin.y - _origin.y) / TEXEL_SIZE))
	var shifted := Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBAH)
	shifted.fill(NEUTRAL)
	if absi(delta.x) < RESOLUTION and absi(delta.y) < RESOLUTION:
		var source := Rect2i(maxi(delta.x, 0), maxi(delta.y, 0),
			RESOLUTION - absi(delta.x), RESOLUTION - absi(delta.y))
		var destination := Vector2i(maxi(-delta.x, 0), maxi(-delta.y, 0))
		shifted.blit_rect(_image, source, destination)
	_image = shifted
	_origin = new_origin
	_dirty = true
	# Static footprints are inexpensive at this scale and rebuilding them from
	# world polygons fills newly exposed texels without periodic re-stamping.
	_rebuild_static_image()

func _rebuild_static_image() -> void:
	_static_image = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBAH)
	_static_image.fill(NEUTRAL)
	for stamp: Dictionary in _static_stamps:
		var points: PackedVector2Array = stamp.get("points", PackedVector2Array())
		if points.size() < 3:
			continue
		var position: Vector3 = stamp.get("position", Vector3.ZERO)
		_raster_static_polygon(points, Vector2(position.x, position.z))
	_static_dirty = true

func _raster_static_polygon(points: PackedVector2Array, centre: Vector2) -> void:
	var lo := points[0]
	var hi := points[0]
	for point: Vector2 in points:
		lo = Vector2(minf(lo.x, point.x), minf(lo.y, point.y))
		hi = Vector2(maxf(hi.x, point.x), maxf(hi.y, point.y))
	var pixel_lo := _world_to_pixel(lo)
	var pixel_hi := _world_to_pixel(hi)
	var first_x := maxi(pixel_lo.x, 0)
	var last_x := mini(pixel_hi.x, RESOLUTION - 1)
	var first_y := maxi(pixel_lo.y, 0)
	var last_y := mini(pixel_hi.y, RESOLUTION - 1)
	if first_x > last_x or first_y > last_y:
		return
	for y in range(first_y, last_y + 1):
		for x in range(first_x, last_x + 1):
			var sample_world := _origin \
				+ (Vector2(x, y) + Vector2.ONE * 0.5) * TEXEL_SIZE
			if not _point_in_polygon(sample_world, points):
				continue
			var direction := sample_world - centre
			if direction.length_squared() <= 0.000001:
				direction = Vector2.RIGHT
			else:
				direction = direction.normalized()
			var old := _static_image.get_pixel(x, y)
			var old_direction := Vector2(old.r, old.g) * 2.0 - Vector2.ONE
			var merged := old_direction * old.b + direction
			var merged_direction := direction if merged.length_squared() <= 0.000001 \
				else merged.normalized()
			_static_image.set_pixel(x, y, Color(
				merged_direction.x * 0.5 + 0.5,
				merged_direction.y * 0.5 + 0.5,
				1.0, 0.0))

static func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	var inside := false
	var previous := polygon.size() - 1
	for current in polygon.size():
		var a := polygon[current]
		var b := polygon[previous]
		if (a.y > point.y) != (b.y > point.y):
			var crossing_x := (b.x - a.x) * (point.y - a.y) \
				/ (b.y - a.y) + a.x
			if point.x < crossing_x:
				inside = not inside
		previous = current
	return inside

func _upload_if_due(delta: float) -> void:
	_upload_elapsed += delta
	if (not _dirty and not _static_dirty) or _upload_elapsed < UPLOAD_INTERVAL:
		return
	if _dirty:
		_texture.update(_image)
	if _static_dirty:
		_static_texture.update(_static_image)
	# Publish this origin only after its shifted pixels have entered the same
	# ordered RenderingServer command stream as the texture update.
	_texture_origin = _origin
	_dirty = false
	_static_dirty = false
	_upload_elapsed = 0.0
	upload_count += 1

func _publish_globals() -> void:
	if _texture == null or _static_texture == null:
		return
	RenderingServer.global_shader_parameter_set(&"grass_trample_texture", _texture)
	RenderingServer.global_shader_parameter_set(&"grass_static_trample_texture", _static_texture)
	RenderingServer.global_shader_parameter_set(&"grass_trample_origin", _texture_origin)
	RenderingServer.global_shader_parameter_set(&"grass_trample_size", DOMAIN_SIZE)
	RenderingServer.global_shader_parameter_set(&"grass_trample_epoch", _now)

func _player_xz() -> Vector2:
	return Vector2(player.global_position.x, player.global_position.z) \
		if player != null else Vector2.ZERO

static func _snapped_origin(centre: Vector2) -> Vector2:
	var raw := centre - Vector2.ONE * (DOMAIN_SIZE * 0.5)
	return Vector2(snappedf(raw.x, TEXEL_SIZE), snappedf(raw.y, TEXEL_SIZE))

func _world_to_pixel(world_xz: Vector2) -> Vector2i:
	var local := (world_xz - _origin) / TEXEL_SIZE
	return Vector2i(floori(local.x), floori(local.y))

static func _effective(value: Color, now: float) -> float:
	var age01 := clampf((now - value.a) / RECOVERY_SECONDS, 0.0, 1.0)
	return value.b * (1.0 - age01 * age01)
