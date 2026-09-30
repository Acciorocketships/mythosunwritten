extends GutTest
## Owner, September 27 judging (seed 2697992464, photo 3 player (288.9, 44.7,
## 904.9)): Meadow rocks set into the bedrock sheet kept their grass top down
## to a hard seam against the bare mountain stone, and their stone was warmer
## than the cliff's. A slope rock at its contact must be exactly the surface it
## meets (bare stone or lawn), and rock and bedrock share one stone colour.
## Unshaded renders compare albedo only.

const STYLE = preload("res://scripts/terrain/field/CliffRockStyle.gd")
const CRAGS = preload("res://scripts/terrain/field/CliffRockCrags.gd")
const DRESSING = preload("res://scripts/terrain/field/CliffRockDressing.gd")
const ROCKS = preload("res://scripts/terrain/field/CliffSlopeRocks.gd")
const SEED := 2697992464
## A 50 degree slope facing +z (steeper than a tread), at the owner's site.
const ORIGIN := Vector3(291.5, 47.0, 911.5)

func after_all() -> void:
	STYLE.apply("current")

func _normal() -> Vector3:
	return Vector3(0.0, cos(deg_to_rad(50.0)), sin(deg_to_rad(50.0)))

func _unshaded(material: ShaderMaterial) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = material.shader.code.replace("shader_type spatial;", "shader_type spatial;\nrender_mode unshaded, cull_disabled;")
	var copy := material.duplicate() as ShaderMaterial
	copy.shader = shader
	return copy

## A 6 m square in the slope plane through ORIGIN.
func _square() -> PackedVector3Array:
	var n := _normal()
	var u := Vector3.RIGHT
	var v := n.cross(u).normalized()
	var vertices := PackedVector3Array()
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		vertices.append(ORIGIN + (u * c.x + v * c.y) * 3.0)
	return vertices

func _render(instance: GeometryInstance3D, eye := Vector3.INF, target := ORIGIN, size := 4.0) -> Image:
	var view := SubViewport.new()
	view.size = Vector2i(128, 128)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.add_child(instance)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size
	view.add_child(camera)
	add_child(view)
	camera.look_at_from_position(ORIGIN + _normal() * 10.0 if eye == Vector3.INF else eye, target, Vector3.UP)
	for frame in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	view.free()
	return image

## The slope sheet exactly as production draws it: a sheet placement (its
## per-vertex normal, rock exposure and moss grade) through
## CliffRockCrags.mesh_arrays and CliffRockDressing.build, so vertex tints,
## their 8-bit storage and the placement's instance colour all apply.
func _sheet(exposure: float, grade: float) -> Image:
	var faces := _square()
	var roots := {}
	for p: Vector3 in faces:
		roots[p] = [_normal(), exposure, grade]
	var placement := {"faces": faces, "green": PackedVector3Array(), "native_roots": roots,
		"transform": Transform3D.IDENTITY, "bounds": AABB(ORIGIN, Vector3.ONE), "anchor": ORIGIN + Vector3(40, 0, 25),
		"top": ORIGIN.y + 8.0, "asset": &"cliff.native_crag", "native_crag": true, "slope_sheet": true, "kind": "rock"}
	placement["render_arrays"] = CRAGS.mesh_arrays(placement, null, SEED)
	var root: Node3D = DRESSING.build({"placements": [placement]}, SEED)
	var node := root.get_child(0) as MultiMeshInstance3D
	root.remove_child(node)
	root.free()
	node.material_override = _unshaded(node.multimesh.mesh.surface_get_material(0) as ShaderMaterial)
	return await _render(node)

## A Meadow slope rock's material, instance colour and data exactly as
## CliffSlopeRocks.build sets them, drawn on a surface lying in the rock's
## support plane (height 0 above it: all contact); `lift` raises it. `face`
## (vertices, normal, eye) draws another surface of the rock instead.
func _rock(exposure: float, grade: float, lift := 0.0, face := {}) -> Image:
	var n := _normal()
	var built: Node3D = ROCKS.build({"angry_02": [{"transform": Transform3D(Basis(), ORIGIN), "normal": n,
		"point": ORIGIN, "exposure": exposure, "grade": grade}]}, SEED)
	var source := built.get_node("angry_02") as MultiMeshInstance3D
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = face.get("vertices", _square())
	var normals := PackedVector3Array()
	normals.resize(6)
	normals.fill(face.get("normal", n))
	arrays[Mesh.ARRAY_NORMAL] = normals
	var uvs := PackedVector2Array()
	var tangents := PackedFloat32Array()
	for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		var o: Vector3 = face.get("uv_origin", Vector3.INF)
		uvs.append(Vector2(p.x + p.y, p.z) * 0.1 if o == Vector3.INF else Vector2(p.x - o.x, p.y - o.y) * 0.5)
		tangents.append_array([1.0, 0.0, 0.0, 1.0])
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TANGENT] = tangents
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis(), n * lift))
	mm.set_instance_color(0, source.multimesh.get_instance_color(0))
	mm.set_instance_custom_data(0, source.multimesh.get_instance_custom_data(0))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = _unshaded(source.material_override as ShaderMaterial)
	built.free()
	return await _render(node, face.get("eye", Vector3.INF), face.get("target", ORIGIN), face.get("size", 4.0))

static func _difference(a: Image, b: Image) -> Dictionary:
	var worst := 0.0
	var total := 0.0
	var count := 0
	for y in range(8, a.get_height() - 8):
		for x in range(8, a.get_width() - 8):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			var d := maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b)))
			worst = maxf(worst, d)
			total += d
			count += 1
	return {"max": worst, "mean": total / count}

static func _mean(image: Image) -> Color:
	var sum := Color(0, 0, 0, 0)
	var count := 0
	for y in range(8, image.get_height() - 8):
		for x in range(8, image.get_width() - 8):
			sum += image.get_pixel(x, y).srgb_to_linear()
			count += 1
	return sum / count

func test_a_rock_at_its_contact_is_the_surface_it_meets() -> void:
	if DisplayServer.get_name() == "headless":
		pending("Requires native GPU colour readback")
		return
	STYLE.apply("sheet_bedrock")
	for case: Array in [[1.0, 0.36, "bare bedrock"], [0.0, 0.36, "lawn"], [120.0 / 255.0, 0.5, "patchy edge"]]:
		var sheet := await _sheet(case[0], case[1])
		var rock := await _rock(case[0], case[1])
		var d := _difference(sheet, rock)
		print("ROCK_CONTACT %s max=%.4f mean=%.4f" % [case[2], d.max, d.mean])
		assert_lt(d.mean, 0.01, "%s: the rock's contact is the sheet's own colour" % case[2])
		assert_lt(d.max, 0.12, "%s: no seam anywhere along the contact" % case[2])

func test_rock_and_bedrock_share_one_stone_colour() -> void:
	if DisplayServer.get_name() == "headless":
		pending("Requires native GPU colour readback")
		return
	STYLE.apply("sheet_bedrock")
	# Fully exposed rock (no turf anywhere on this slope), and the rock's own
	# stone two metres above its support plane.
	var cliff := _mean(await _sheet(2.0, 0.36))
	var rock := _mean(await _rock(2.0, 0.36, 2.0))
	# Native cliff stone (terrain rock texels, field rocks) shares the palette.
	var field := ShaderMaterial.new()
	field.shader = load("res://terrain/materials/field_rock.gdshader")
	field.set_shader_parameter("use_texture", false)
	field.set_shader_parameter("instance_variation", false)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _square()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _unshaded(field)
	var native := _mean(await _render(node))
	print("STONE cliff=%s rock=%s native=%s" % [cliff, rock, native])
	for other: Array in [[rock, "rock"], [native, "native cliff stone"]]:
		var c: Color = other[0]
		assert_almost_eq(c.r / c.b, cliff.r / cliff.b, 0.12, "%s: the bedrock's warmth" % other[1])
		assert_almost_eq(c.get_luminance(), cliff.get_luminance(), 0.05, "%s: the bedrock's value" % other[1])

## Coordinator review (September 27 judging): on a lawn slope the rock must
## still read as a rock. Only its contact band takes the surface's colour;
## a steep side face above that band keeps the Meadow stone, not the lawn.
func test_rock_body_keeps_stone_sides_above_the_contact_band() -> void:
	if DisplayServer.get_name() == "headless":
		pending("Requires native GPU colour readback")
		return
	STYLE.apply("sheet_bedrock")
	# The side of a low rock (slope rocks show 0.3-1.2 m above their contact
	# plane): a vertical face (normal +z) from 0.32 to 0.52 m above the 50
	# degree support plane through ORIGIN (height = (y - ORIGIN.y) cos 50),
	# the view filled by it, against the same face 2 m higher (pure stone).
	# The first pass's 0.7 m band drew such a side half as lawn.
	var k := cos(deg_to_rad(50.0))
	var faces := []
	for height: float in [0.42, 2.42]:
		var centre := ORIGIN + Vector3(0.0, height / k, 0.0)
		var vertices := PackedVector3Array()
		for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			vertices.append(centre + Vector3(c.x * 3.0, c.y * 0.1 / k, 0.0))
		faces.append(await _rock(0.0, 0.36, 0.0, {"vertices": vertices, "normal": Vector3.BACK,
			"eye": centre + Vector3.BACK * 10.0, "target": centre, "size": 0.2, "uv_origin": centre}))
	var side := _mean(faces[0])
	var d := _difference(faces[0], faces[1])
	print("ROCK_SIDE side=%s stone=%s diff mean=%.4f" % [side, _mean(faces[1]), d.mean])
	assert_gt(side.r, side.g, "the side face is warm stone, not green")
	assert_lt(d.mean, 0.01, "just above the contact band the side is the rock's own stone")
