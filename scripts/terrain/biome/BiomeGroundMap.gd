class_name BiomeGroundMap
extends RefCounted

## Rendering lookup for the SAME CPU biome field. The canonical 48m samples
## overlap exactly when the window scrolls by 768m; the observer never changes
## a world's colour. The 3km window contains the complete terrain keep ring.
const STEP := 48.0
const SIDE := 65
const SPAN := STEP * (SIDE - 1)
const SCROLL := 768.0
var _centre := Vector2.INF
var _seed := -1
const SCROLL_BUDGET_USEC := 1000
var _pending_centre := Vector2.INF
var _pending_row := 0
var _pending_values: Array[PackedColorArray] = []
var _values: Array[PackedColorArray] = []

static func samples(origin: Vector2, seed: int) -> Array[PackedColorArray]:
	var a := PackedColorArray()
	var b := PackedColorArray()
	var c := PackedColorArray()
	var surface := PackedColorArray()
	for z in SIDE:
		for x in SIDE:
			var point := origin + Vector2(x, z) * STEP
			var w := Helper.biome_weights5(Vector3(point.x, 0, point.y), seed)
			a.append(Color(w[&"deep_forest"], w[&"highland"], w[&"blossom_grove"], w[&"twilight_marsh"]))
			b.append(Color(w[&"amber_heath"], w[&"jade_wetlands"], w[&"meadow"], 1.0))
			c.append(BiomeRegistry.substrate_color(w))
			surface.append(BiomeRegistry.surface_response(w))
	return [a, b, c, surface]

func update(pos: Vector3, seed: int) -> void:
	var centre := Vector2(roundf(pos.x / SCROLL), roundf(pos.z / SCROLL)) * SCROLL
	if not _prepare(centre, seed):
		return
	_publish()

## The previous 3 km window still covers the keep ring at a scroll boundary.
## Build its successor a row at a time; publish all maps and their origin
## together so a frame never combines old coordinates with new pixels.
func _prepare(centre: Vector2, seed: int) -> bool:
	if _centre == centre and _seed == seed:
		_pending_centre = Vector2.INF
		_pending_values.clear()
		return false
	var origin := centre - Vector2.ONE * SPAN * 0.5
	# The first map (and a different world's seed) must exist immediately.
	if _values.is_empty() or seed != _seed:
		_values = samples(origin, seed)
	else:
		if _pending_centre != centre:
			_pending_centre = centre
			_pending_row = 0
			_pending_values = [PackedColorArray(), PackedColorArray(), PackedColorArray(), PackedColorArray()]
		var started := Time.get_ticks_usec()
		while _pending_row < SIDE:
			for x in SIDE:
				var point := origin + Vector2(x, _pending_row) * STEP
				var w := Helper.biome_weights5(Vector3(point.x, 0, point.y), seed)
				_pending_values[0].append(Color(w[&"deep_forest"], w[&"highland"], w[&"blossom_grove"], w[&"twilight_marsh"]))
				_pending_values[1].append(Color(w[&"amber_heath"], w[&"jade_wetlands"], w[&"meadow"], 1.0))
				_pending_values[2].append(BiomeRegistry.substrate_color(w))
				_pending_values[3].append(BiomeRegistry.surface_response(w))
			_pending_row += 1
			if Time.get_ticks_usec() - started >= SCROLL_BUDGET_USEC:
				break
		if _pending_row < SIDE:
			return false
		_values = _pending_values
	_centre = centre
	_seed = seed
	_pending_centre = Vector2.INF
	_pending_values = []
	return true

func _publish() -> void:
	var textures: Array[ImageTexture] = []
	for layer in _values.size():
		var pixels := Image.create_empty(SIDE, SIDE, false, Image.FORMAT_RGBAF)
		for i in SIDE * SIDE:
			pixels.set_pixel(i % SIDE, i / SIDE, _values[layer][i])
		textures.append(ImageTexture.create_from_image(pixels))
	RenderingServer.global_shader_parameter_set("biome_ground_a", textures[0])
	RenderingServer.global_shader_parameter_set("biome_ground_b", textures[1])
	RenderingServer.global_shader_parameter_set("biome_ground_color", textures[2])
	RenderingServer.global_shader_parameter_set("biome_surface_map", textures[3])
	RenderingServer.global_shader_parameter_set("biome_ground_origin", _centre - Vector2.ONE * SPAN * 0.5)
	# RenderingServer retains global texture references, but keep the resources
	# alive explicitly so the bindings cannot outlive their owning ImageTextures.
	_maps = textures

var _maps: Array[ImageTexture] = []
