extends Node3D

const TARGET_HEIGHT := 0.62
const CANDIDATES := [
	{
		"name": "Maya clump 1",
		"source": "res://assets/Grass/maya2sketchfab.fbx",
		"path": "Grass_Clump01GRP",
		"group": true,
	},
	{
		"name": "Maya clump 2",
		"source": "res://assets/Grass/maya2sketchfab.fbx",
		"path": "Grass_Ckump02GRP",
		"group": true,
	},
	{
		"name": "Maya clump 3",
		"source": "res://assets/Grass/maya2sketchfab.fbx",
		"path": "Grass_Ckump03GRP",
		"group": true,
	},
	{
		"name": "Maya shape trio",
		"source": "res://assets/Grass/maya2sketchfab.fbx",
		"path": "Grass_ShapeVariantGRP",
		"group": true,
	},
	{
		"name": "Scatter tuft",
		"source": "res://assets/Grass/uploads_files_2292648_GRASS.fbx",
		"path": "GRASS 2/GRASS 2|Foliage01_col_005|Dupli|6999",
		"group": false,
	},
	{
		"name": "Collection green",
		"source": "res://assets/Grass/uploads_files_4153833_Grass+Collections.fbx",
		"path": "Grass_Type_4_grassOrnament1MeshGroup/Grass_Type_4_grassOrnament1Main7",
		"group": false,
	},
	{
		"name": "Collection short",
		"source": "res://assets/Grass/uploads_files_4153833_Grass+Collections.fbx",
		"path": "Grass_Type_4_grassOrnament1MeshGroup/Grass_Type_4_grassOrnament1Main6",
		"group": false,
	},
	{
		"name": "Collection gold",
		"source": "res://assets/Grass/uploads_files_4153833_Grass+Collections.fbx",
		"path": "Grass_Type_4_grassOrnament1MeshGroup/Grass_Type_4_grassOrnament1Main4",
		"group": false,
	},
]

var _capture_path := "/tmp/grass-asset-lineup.png"

func _ready() -> void:
	_read_args()
	_build_environment()
	_build_lineup()
	_capture.call_deferred()

func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--capture" and index + 1 < args.size():
			_capture_path = args[index + 1]

func _build_environment() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#a9c9d3")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#dce8df")
	environment.ambient_light_energy = 0.75
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
	plane.size = Vector2(14.0, 9.0)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("#6f806c")
	ground_material.roughness = 0.9
	ground.material_override = ground_material
	add_child(ground)
	var camera := Camera3D.new()
	camera.fov = 42.0
	camera.position = Vector3(0.0, 5.3, 10.2)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.45, -0.7))
	add_child(camera)
	camera.current = true

func _build_lineup() -> void:
	var positions := [
		Vector3(-4.5, 0.0, 1.0), Vector3(-1.5, 0.0, 1.0),
		Vector3(1.5, 0.0, 1.0), Vector3(4.5, 0.0, 1.0),
		Vector3(-4.5, 0.0, -2.0), Vector3(-1.5, 0.0, -2.0),
		Vector3(1.5, 0.0, -2.0), Vector3(4.5, 0.0, -2.0),
	]
	for index in CANDIDATES.size():
		var result := _extract(CANDIDATES[index])
		var visual := result.node as Node3D
		visual.position += positions[index]
		add_child(visual)
		var label := Label3D.new()
		label.text = "%s\n%d tris" % [CANDIDATES[index].name, int(result.triangles)]
		label.font_size = 38
		label.outline_size = 8
		label.modulate = Color.WHITE
		label.position = positions[index] + Vector3(0.0, 0.93, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		add_child(label)

static func _extract(candidate: Dictionary) -> Dictionary:
	var packed := load(String(candidate.source)) as PackedScene
	assert(packed != null)
	var source_root := packed.instantiate()
	var selected := source_root.get_node_or_null(NodePath(String(candidate.path)))
	assert(selected != null, "Missing candidate path: %s" % candidate.path)
	var selected_3d := selected as Node3D
	assert(selected_3d != null)
	var meshes: Array[MeshInstance3D] = []
	if bool(candidate.group):
		for found: Node in selected.find_children("*", "MeshInstance3D", true, false):
			var found_mesh := found as MeshInstance3D
			if found_mesh != null and found_mesh.mesh != null:
				meshes.append(found_mesh)
	else:
		var selected_mesh := selected as MeshInstance3D
		assert(selected_mesh != null and selected_mesh.mesh != null)
		meshes.append(selected_mesh)
	var raw := Node3D.new()
	var bounds: AABB
	var has_bounds := false
	var triangles := 0
	for source_mesh: MeshInstance3D in meshes:
		var instance := MeshInstance3D.new()
		instance.mesh = source_mesh.mesh
		var relative_root := selected if bool(candidate.group) else source_root
		instance.transform = _relative_transform(source_mesh, relative_root)
		raw.add_child(instance)
		var piece_bounds := instance.transform * instance.mesh.get_aabb()
		bounds = piece_bounds if not has_bounds else bounds.merge(piece_bounds)
		has_bounds = true
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += indices.size() / 3 if not indices.is_empty() \
				else vertices.size() / 3
	assert(has_bounds and bounds.size.y > 0.0)
	var scale := TARGET_HEIGHT / bounds.size.y
	raw.scale = Vector3.ONE * scale
	raw.position = Vector3(-bounds.get_center().x, -bounds.position.y,
		-bounds.get_center().z) * scale
	source_root.free()
	return {"node": raw, "triangles": triangles, "bounds": bounds}

static func _relative_transform(node: Node3D, root: Node) -> Transform3D:
	var out := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor != null and cursor != root:
		var node_3d := cursor as Node3D
		if node_3d != null:
			out = node_3d.transform * out
		cursor = cursor.get_parent()
	return out

func _capture() -> void:
	for _frame in 12:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image == null or image.save_png(_capture_path) != OK:
		push_error("Could not save grass asset lineup: %s" % _capture_path)
		get_tree().quit(1)
		return
	print("[grass_asset_lineup] capture=%s" % _capture_path)
	get_tree().quit()
