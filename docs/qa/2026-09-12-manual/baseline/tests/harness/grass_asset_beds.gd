extends Node3D

const BED_SIZE := 6.6
const CANDIDATES := [
	{
		"name": "Raw clump 2 — 340 tris\n34 cm pitch / 74 cm tall",
		"source": "res://assets/Grass/maya2sketchfab.fbx",
		"path": "Grass_Ckump02GRP",
		"pitch": 0.34,
		"height": 0.74,
	},
	{
		"name": "Wide 5 — 160 tris\n34 cm pitch / 74 cm tall",
		"source": "res://assets/Grass/maya2sketchfab.fbx",
		"path": "Grass_Ckump02GRP",
		"nodes": ["Grass_Grass_low10", "Grass_Grass_low122",
			"Grass_Grass_low8", "Grass_Grass_low13", "Grass_Grass_low7"],
		"pitch": 0.34,
		"height": 0.74,
	},
	{
		"name": "Wide 5 — tighter\n30 cm pitch / 78 cm tall",
		"source": "res://assets/Grass/maya2sketchfab.fbx",
		"path": "Grass_Ckump02GRP",
		"nodes": ["Grass_Grass_low10", "Grass_Grass_low122",
			"Grass_Grass_low8", "Grass_Grass_low13", "Grass_Grass_low7"],
		"pitch": 0.30,
		"height": 0.78,
	},
	{
		"name": "Wide 7 — 224 tris\n34 cm pitch / 74 cm tall",
		"source": "res://assets/Grass/maya2sketchfab.fbx",
		"path": "Grass_Ckump02GRP",
		"nodes": ["Grass_Grass_low10", "Grass_Grass_low122",
			"Grass_Grass_low11", "Grass_Grass_low8", "Grass_Grass_low9",
			"Grass_Grass_low13", "Grass_Grass_low7"],
		"pitch": 0.34,
		"height": 0.74,
	},
]

var _capture_path := "/tmp/grass-asset-beds.png"

func _ready() -> void:
	_read_args()
	_build_environment()
	_build_beds()
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
	environment.ambient_light_energy = 0.72
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -32.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.0, 16.0)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("#675844")
	ground_material.roughness = 0.95
	ground.material_override = ground_material
	add_child(ground)
	var camera := Camera3D.new()
	camera.fov = 48.0
	camera.position = Vector3(0.0, 8.8, 12.5)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.15, 0.0))
	add_child(camera)
	camera.current = true

func _build_beds() -> void:
	var centres := [
		Vector3(-3.65, 0.0, 3.65), Vector3(3.65, 0.0, 3.65),
		Vector3(-3.65, 0.0, -3.65), Vector3(3.65, 0.0, -3.65),
	]
	for index in CANDIDATES.size():
		_build_bed(CANDIDATES[index], centres[index], index)

func _build_bed(candidate: Dictionary, centre: Vector3, candidate_index: int) -> void:
	var packed := load(String(candidate.source)) as PackedScene
	assert(packed != null)
	var source_root := packed.instantiate()
	var selected := source_root.get_node_or_null(NodePath(String(candidate.path))) as Node3D
	assert(selected != null)
	var pieces: Array[MeshInstance3D] = []
	var node_filter: Array = candidate.get("nodes", [])
	var bounds: AABB
	var has_bounds := false
	for found: Node in selected.find_children("*", "MeshInstance3D", true, false):
		var source_mesh := found as MeshInstance3D
		if source_mesh == null or source_mesh.mesh == null:
			continue
		if not node_filter.is_empty() and not node_filter.has(source_mesh.name):
			continue
		pieces.append(source_mesh)
		var local := _relative_transform(source_mesh, selected)
		var piece_bounds := local * source_mesh.mesh.get_aabb()
		bounds = piece_bounds if not has_bounds else bounds.merge(piece_bounds)
		has_bounds = true
	assert(has_bounds and bounds.size.y > 0.0)
	var pitch := float(candidate.pitch)
	var side := int(floor(BED_SIZE / pitch))
	var count := side * side
	var authored_scale := float(candidate.height) / bounds.size.y
	var offset := Vector3(-bounds.get_center().x, -bounds.position.y,
		-bounds.get_center().z)
	for source_mesh: MeshInstance3D in pieces:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = source_mesh.mesh
		multimesh.instance_count = count
		var piece_local := _relative_transform(source_mesh, selected)
		for z in side:
			for x in side:
				var instance_index := z * side + x
				var hash := Helper._mix64(candidate_index * 19013 + instance_index * 7919)
				var yaw := Helper._hash01(hash) * TAU
				var jitter_x := (Helper._hash01(Helper._mix64(hash ^ 0x243F6A88)) - 0.5) * pitch * 0.7
				var jitter_z := (Helper._hash01(Helper._mix64(hash ^ 0x13198A2E)) - 0.5) * pitch * 0.7
				var size_variation := lerpf(0.9, 1.1,
					Helper._hash01(Helper._mix64(hash ^ 0x082EFA98)))
				var xz := Vector3(
					(float(x) + 0.5) * pitch - float(side) * pitch * 0.5 + jitter_x,
					0.0,
					(float(z) + 0.5) * pitch - float(side) * pitch * 0.5 + jitter_z)
				var placement := Transform3D(
					Basis(Vector3.UP, yaw).scaled(Vector3.ONE * authored_scale * size_variation),
					centre + xz)
				multimesh.set_instance_transform(instance_index,
					placement * Transform3D(Basis.IDENTITY, offset) * piece_local)
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	source_root.free()
	var label := Label3D.new()
	label.text = String(candidate.name)
	label.font_size = 34
	label.outline_size = 8
	label.modulate = Color.WHITE
	label.position = centre + Vector3(0.0, 1.15, -BED_SIZE * 0.5 + 0.2)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)

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
	for _frame in 16:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image == null or image.save_png(_capture_path) != OK:
		push_error("Could not save grass asset beds: %s" % _capture_path)
		get_tree().quit(1)
		return
	print("[grass_asset_beds] capture=%s" % _capture_path)
	get_tree().quit()
