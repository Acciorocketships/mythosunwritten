extends Node3D

const TARGET_HEIGHT := 0.78
const MAYA_SOURCE := "res://assets/Grass/maya2sketchfab.fbx"
const SCATTER_SOURCE := "res://assets/Grass/uploads_files_2292648_GRASS.fbx"
const COLLECTION_SOURCE := "res://assets/Grass/uploads_files_4153833_Grass+Collections.fbx"
const MAPLE_SOURCE := "res://assets/Grass/uploads_files_4927605_Stylized+Japanese+Maple.fbx"

const MAYA_CANDIDATES := [
	{"name": "High-poly source blade", "source": MAYA_SOURCE,
		"path": "Grass_Grass_high"},
	{"name": "Low-poly master blade", "source": MAYA_SOURCE,
		"path": "Grass_Grass_Master"},
	{"name": "Shape variant 1", "source": MAYA_SOURCE,
		"path": "Grass_ShapeVariantGRP/Grass_Grass_low3"},
	{"name": "Shape variant 2", "source": MAYA_SOURCE,
		"path": "Grass_ShapeVariantGRP/Grass_Grass_low1"},
	{"name": "Shape variant 3", "source": MAYA_SOURCE,
		"path": "Grass_ShapeVariantGRP/Grass_Grass_low2"},
	{"name": "Clump 1", "source": MAYA_SOURCE,
		"path": "Grass_Clump01GRP", "group": true},
	{"name": "Clump 2 — selected", "source": MAYA_SOURCE,
		"path": "Grass_Ckump02GRP", "group": true},
	{"name": "Clump 3", "source": MAYA_SOURCE,
		"path": "Grass_Ckump03GRP", "group": true},
]

const COLLECTION_CANDIDATES := [
	{"name": "Collection 1", "source": COLLECTION_SOURCE,
		"path": "Grass_Type_4_grassOrnament1MeshGroup/Grass_Type_4_grassOrnament1Main"},
	{"name": "Collection 2", "source": COLLECTION_SOURCE,
		"path": "Grass_Type_4_grassOrnament1MeshGroup/Grass_Type_4_grassOrnament1Main1"},
	{"name": "Collection 3", "source": COLLECTION_SOURCE,
		"path": "Grass_Type_4_grassOrnament1MeshGroup/Grass_Type_4_grassOrnament1Main2"},
	{"name": "Collection 4", "source": COLLECTION_SOURCE,
		"path": "Grass_Type_4_grassOrnament1MeshGroup/Grass_Type_4_grassOrnament1Main3"},
	{"name": "Collection 5", "source": COLLECTION_SOURCE,
		"path": "Grass_Type_4_grassOrnament1MeshGroup/Grass_Type_4_grassOrnament1Main4"},
	{"name": "Collection 6", "source": COLLECTION_SOURCE,
		"path": "Grass_Type_4_grassOrnament1MeshGroup/Grass_Type_4_grassOrnament1Main6"},
	{"name": "Collection 7", "source": COLLECTION_SOURCE,
		"path": "Grass_Type_4_grassOrnament1MeshGroup/Grass_Type_4_grassOrnament1Main7"},
	{"name": "Collection 8", "source": COLLECTION_SOURCE,
		"path": "Grass_Type_4_grassOrnament1MeshGroup/Grass_Type_4_grassOrnament1Main8"},
]

const OTHER_CANDIDATES := [
	{"name": "Scatter GRASS 1", "source": SCATTER_SOURCE,
		"path": "GRASS 1", "target_extent": 1.4},
	{"name": "Scatter GRASS 2 shell", "source": SCATTER_SOURCE,
		"path": "GRASS 2", "target_extent": 1.4},
	{"name": "Scatter source tuft", "source": SCATTER_SOURCE,
		"path": "GRASS 2/GRASS 2|Foliage01_col_005|Dupli|6999"},
	{"name": "Full scatter — 7,000 tuft copies", "source": SCATTER_SOURCE,
		"path": "GRASS 2", "multimesh_group": true, "target_extent": 1.8},
	{"name": "Stylized Japanese Maple\n(not a grass asset)", "source": MAPLE_SOURCE,
		"path": ".", "group": true, "target_height": 1.18},
]

var _capture_path := "/tmp/grass-assets-maya.png"
var _set_name := "maya"

func _ready() -> void:
	_read_args()
	_build_environment()
	var candidates: Array = MAYA_CANDIDATES
	if _set_name == "collections":
		candidates = COLLECTION_CANDIDATES
	elif _set_name == "other":
		candidates = OTHER_CANDIDATES
	_build_lineup(candidates)
	_capture.call_deferred()

func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--capture" and index + 1 < args.size():
			_capture_path = args[index + 1]
		elif args[index] == "--set" and index + 1 < args.size():
			_set_name = args[index + 1]

func _build_environment() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#a9c9d3")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#dce8df")
	environment.ambient_light_energy = 0.78
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.0, 9.0)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("#6f806c")
	ground_material.roughness = 0.9
	ground.material_override = ground_material
	add_child(ground)
	var camera := Camera3D.new()
	camera.fov = 42.0
	camera.position = Vector3(0.0, 5.8, 11.4)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.48, -0.65))
	add_child(camera)
	camera.current = true

func _build_lineup(candidates: Array) -> void:
	var columns := 4
	var spacing := Vector2(3.35, 3.0)
	for index in candidates.size():
		var row := index / columns
		var items_in_row := mini(columns, candidates.size() - row * columns)
		var column := index % columns
		var x := (float(column) - float(items_in_row - 1) * 0.5) * spacing.x
		var z := (float(row) - 0.5) * spacing.y
		if candidates.size() <= columns:
			z = -0.4
		var position := Vector3(x, 0.0, z)
		var result := _extract(candidates[index])
		var visual := result.node as Node3D
		visual.position += position
		add_child(visual)
		var label := Label3D.new()
		label.text = "%s\n%s tris" % [candidates[index].name,
			_format_number(int(result.triangles))]
		label.font_size = 34
		label.outline_size = 8
		label.modulate = Color.WHITE
		label.position = position + Vector3(0.0, 1.15, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		add_child(label)

static func _extract(candidate: Dictionary) -> Dictionary:
	var packed := load(String(candidate.source)) as PackedScene
	assert(packed != null)
	var source_root := packed.instantiate()
	var selected := source_root.get_node_or_null(NodePath(String(candidate.path)))
	assert(selected != null, "Missing candidate path: %s" % candidate.path)
	var raw := Node3D.new()
	var bounds: AABB
	var has_bounds := false
	var triangles := 0
	if bool(candidate.get("multimesh_group", false)):
		var meshes: Array[MeshInstance3D] = []
		for found: Node in selected.find_children("*", "MeshInstance3D", true, false):
			var found_mesh := found as MeshInstance3D
			if found_mesh != null and found_mesh.mesh != null:
				meshes.append(found_mesh)
		assert(not meshes.is_empty())
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = meshes[0].mesh
		multimesh.instance_count = meshes.size()
		var per_mesh_triangles := _triangle_count(meshes[0].mesh)
		for index in meshes.size():
			var relative := _relative_transform(meshes[index], selected)
			multimesh.set_instance_transform(index, relative)
			var piece_bounds := relative * meshes[index].mesh.get_aabb()
			bounds = piece_bounds if not has_bounds else bounds.merge(piece_bounds)
			has_bounds = true
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		raw.add_child(instance)
		triangles = per_mesh_triangles * meshes.size()
	else:
		var meshes: Array[MeshInstance3D] = []
		if bool(candidate.get("group", false)):
			for found: Node in selected.find_children("*", "MeshInstance3D", true, false):
				var found_mesh := found as MeshInstance3D
				if found_mesh != null and found_mesh.mesh != null:
					meshes.append(found_mesh)
			if selected is MeshInstance3D and (selected as MeshInstance3D).mesh != null:
				meshes.push_front(selected as MeshInstance3D)
		else:
			var selected_mesh := selected as MeshInstance3D
			assert(selected_mesh != null and selected_mesh.mesh != null)
			meshes.append(selected_mesh)
		for source_mesh: MeshInstance3D in meshes:
			var instance := MeshInstance3D.new()
			instance.mesh = source_mesh.mesh
			var relative_root := selected if bool(candidate.get("group", false)) else source_root
			instance.transform = _relative_transform(source_mesh, relative_root)
			raw.add_child(instance)
			var piece_bounds := instance.transform * instance.mesh.get_aabb()
			bounds = piece_bounds if not has_bounds else bounds.merge(piece_bounds)
			has_bounds = true
			triangles += _triangle_count(instance.mesh)
	assert(has_bounds and bounds.size.y > 0.0)
	var scale := 1.0
	if candidate.has("target_extent"):
		var maximum_extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		scale = float(candidate.target_extent) / maximum_extent
	else:
		var target_height := float(candidate.get("target_height", TARGET_HEIGHT))
		scale = target_height / bounds.size.y
	raw.scale = Vector3.ONE * scale
	raw.position = Vector3(-bounds.get_center().x, -bounds.position.y,
		-bounds.get_center().z) * scale
	source_root.free()
	return {"node": raw, "triangles": triangles, "bounds": bounds}

static func _triangle_count(mesh: Mesh) -> int:
	var triangles := 0
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		triangles += indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
	return triangles

static func _relative_transform(node: Node3D, root: Node) -> Transform3D:
	var out := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor != null and cursor != root:
		var node_3d := cursor as Node3D
		if node_3d != null:
			out = node_3d.transform * out
		cursor = cursor.get_parent()
	return out

static func _format_number(value: int) -> String:
	var raw := str(value)
	var out := ""
	for index in raw.length():
		if index > 0 and (raw.length() - index) % 3 == 0:
			out += ","
		out += raw[index]
	return out

func _capture() -> void:
	for _frame in 18:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image == null or image.save_png(_capture_path) != OK:
		push_error("Could not save complete grass asset lineup: %s" % _capture_path)
		get_tree().quit(1)
		return
	print("[grass_asset_complete_lineup] set=%s capture=%s" % [_set_name, _capture_path])
	get_tree().quit()
