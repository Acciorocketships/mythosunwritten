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

static func samples(origin: Vector2, seed: int) -> Array[PackedColorArray]:
	var a := PackedColorArray()
	var b := PackedColorArray()
	var c := PackedColorArray()
	for z in SIDE:
		for x in SIDE:
			var point := origin + Vector2(x, z) * STEP
			var w := Helper.biome_weights5(Vector3(point.x, 0, point.y), seed)
			a.append(Color(w[&"deep_forest"], w[&"highland"], w[&"blossom_grove"], w[&"twilight_marsh"]))
			b.append(Color(w[&"amber_heath"], w[&"jade_wetlands"], w[&"meadow"], 1.0))
			c.append(BiomeRegistry.substrate_color(w))
	return [a, b, c]

func update(pos: Vector3, seed: int) -> void:
	var centre := Vector2(roundf(pos.x / SCROLL), roundf(pos.z / SCROLL)) * SCROLL
	if _centre == centre and _seed == seed:
		return
	_centre = centre
	_seed = seed
	var origin := centre - Vector2.ONE * SPAN * 0.5
	var values := samples(origin, seed)
	var textures: Array[ImageTexture] = []
	for layer in 3:
		var pixels := Image.create_empty(SIDE, SIDE, false, Image.FORMAT_RGBAF)
		for i in SIDE * SIDE:
			pixels.set_pixel(i % SIDE, i / SIDE, values[layer][i])
		textures.append(ImageTexture.create_from_image(pixels))
	RenderingServer.global_shader_parameter_set("biome_ground_a", textures[0])
	RenderingServer.global_shader_parameter_set("biome_ground_b", textures[1])
	RenderingServer.global_shader_parameter_set("biome_ground_color", textures[2])
	RenderingServer.global_shader_parameter_set("biome_ground_origin", origin)
	# RenderingServer retains global texture references, but keep the resources
	# alive explicitly so the bindings cannot outlive their owning ImageTextures.
	_maps = textures

var _maps: Array[ImageTexture] = []
