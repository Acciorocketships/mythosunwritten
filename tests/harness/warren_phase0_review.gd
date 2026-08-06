extends Node3D

const FoldedProof = preload("res://tests/fixtures/warren_folded_proof.gd")
const PlotVoidPlanner = preload(
	"res://scripts/terrain/features/villages/fabric/WarrenPlotVoidPlanner.gd")

## Fixed visual proof for the exterior three-dimensional warren grammar. This
## scene is not a production fallback: procedural selection stays gated until
## these authored solid/void relationships pass adversarial full-resolution
## review.
var _output_dir := "/tmp/mythos-warren-town"
var _world_seed := 0
var _plot_void := false
var _camera := Camera3D.new()
var _captures: Array[Dictionary] = []
var _camera_failures: Array[String] = []
var _obscured_captures: Array[String] = []
var _plan: SettlementFabricPlan

const ROCK_WALL := &"sfv.fabric.wall.rock.plain.001"

const VIEWS: Array[Dictionary] = [
	{"id": "market_entry", "anchor": &"ring.landing",
		"target_unit": &"market.turn.north", "offset": Vector3(-4.5, 1.7, 0),
		"target_offset": Vector3(0, 1.5, 0), "fov": 66.0},
	{"id": "market_turn", "anchor": &"market.east",
		"target_unit": &"market.north", "offset": Vector3(0, 1.7, 0),
		"target_offset": Vector3(0, 1.5, 0), "fov": 64.0},
	{"id": "tunnel_underpass", "anchor": &"ring.east",
		"target_unit": &"ring.loop.stair", "offset": Vector3(0, 1.7, 3),
		"target_offset": Vector3(0, 0.5, 0), "fov": 62.0},
	{"id": "middle_alley", "anchor": &"ring.lower.turn.east",
		"target_unit": &"ring.middle.rise.half", "offset": Vector3(-2, 1.7, 2),
		"target_offset": Vector3(0, 1.5, 0), "fov": 64.0},
	{"id": "exterior_facade_stair", "anchor": &"ring.middle.west",
		"target_unit": &"ring.drop.middle", "offset": Vector3(3, 1.7, 3),
		"target_offset": Vector3(0, 2.0, 0), "fov": 68.0},
		{"id": "upper_court", "anchor": &"ring.top.court",
			"target_unit": &"ring.top.east.2", "offset": Vector3(0, 1.7, 0),
		"target_offset": Vector3(0, 1.7, 0), "fov": 72.0},
	{"id": "court_bearing", "anchor": &"ring.court.support.north.base",
		"target_unit": &"ring.top.court", "offset": Vector3(-8, 4.0, 8),
		"target_offset": Vector3(0, 0.0, 0), "fov": 62.0},
	{"id": "platform_planks", "anchor": &"ring.top.court",
		"target_unit": &"ring.top.court", "offset": Vector3(-3, 1.7, 1),
		"target_offset": Vector3(1, 0.0, -1), "fov": 64.0},
	{"id": "court_guard", "anchor": &"ring.top.court",
		"target_unit": &"ring.top.court", "offset": Vector3(0, 1.7, 0),
		"target_offset": Vector3(3, 0.7, 0), "fov": 66.0},
	{"id": "court_lightwell", "anchor": &"ring.top.court",
		"target_unit": &"ring.top.court", "offset": Vector3(-2, 6, 3),
		"target_offset": Vector3(3, 0, 0), "fov": 60.0},
		{"id": "court_address", "anchor": &"ring.top.court",
			"target_unit": &"ring.top.east.2",
		"offset": Vector3(1.5, 1.7, -1.5),
		"target_offset": Vector3(-1.5, 1.5, -1.5), "fov": 62.0},
	{"id": "court_descent", "anchor": &"ring.high.arrival",
		"target_unit": &"ring.final.rise", "offset": Vector3(2, 1.7, 0),
		"target_offset": Vector3(0, 1.0, 0), "fov": 68.0},
	{"id": "lower_exterior_return", "anchor": &"ring.return.south",
		"target_unit": &"ring.return.turn.west", "offset": Vector3(0, 1.7, 1.5),
		"target_offset": Vector3(-1.5, 2.5, 1.5), "fov": 66.0},
	{"id": "half_rise", "anchor": &"ring.lower.turn.east",
		"target_unit": &"ring.rise.full", "offset": Vector3(0, 1.7, 0),
		"target_offset": Vector3(0, 2.0, 0), "fov": 62.0},
	{"id": "upper_switchback", "anchor": &"ring.middle.turn.south",
		"target_unit": &"ring.middle.west", "offset": Vector3(-3, 2.0, 3),
		"target_offset": Vector3(0, 1.5, 0), "fov": 64.0},
	{"id": "entry_overhang", "anchor": &"ring.entry",
		"target_unit": &"ring.rise.half", "offset": Vector3(0, 2.2, 6),
		"target_offset": Vector3(0, 1.5, 0), "fov": 60.0},
	{"id": "valley_skywalk", "anchor": &"ring.middle.rise.half",
		"target_unit": &"ring.return.south", "offset": Vector3(-8, 5, 5),
		"target_offset": Vector3(0, 0.5, 0), "fov": 62.0},
	{"id": "roofline", "anchor": &"ring.middle.turn.south",
		"target_unit": &"ring.middle.turn.south", "offset": Vector3(-18, 16, 16),
		"target_offset": Vector3(0, 3, 0), "fov": 54.0,
		"require_target_visible": false},
	{"id": "sectional_profile", "anchor": &"ring.top.court",
		"target_unit": &"ring.middle.turn.south",
		"offset": Vector3(26, 13, 12),
		"target_offset": Vector3(0, 0, 0), "fov": 54.0,
		"require_target_visible": false},
	{"id": "network_overview", "anchor": &"ring.middle.turn.south",
		"target_unit": &"ring.middle.turn.south", "offset": Vector3(34, 32, 30),
		"target_offset": Vector3(0, 3, 0), "fov": 52.0,
		"require_target_visible": false},
]

const PLOT_VOID_VIEWS: Array[Dictionary] = [
	{"id": "market_entry", "anchor": &"maze.landing",
		"target_unit": &"market.turn.north", "offset": Vector3(-4.5, 1.7, 0),
		"target_offset": Vector3(0, 1.5, 0), "fov": 66.0},
	{"id": "market_turn", "anchor": &"market.east",
		"target_unit": &"market.north", "offset": Vector3(0, 1.7, 0),
		"target_offset": Vector3(0, 1.5, 0), "fov": 64.0},
	{"id": "maze_entry", "anchor": &"maze.entry",
		"target_unit": &"maze.rise.half", "offset": Vector3(-2, 1.7, 3),
		"target_offset": Vector3(0, 1.0, 0), "fov": 64.0},
	{"id": "alternate_ascent", "anchor": &"maze.east",
		"target_unit": &"maze.loop.half", "offset": Vector3(-2, 1.7, 2),
		"target_offset": Vector3(0, 1.0, 0), "fov": 64.0},
	{"id": "band1_switchback", "anchor": &"maze.band1.turn.west",
		"target_unit": &"maze.rise.full", "offset": Vector3(4, 1.7, 3),
		"target_offset": Vector3(0, 1.8, 0), "fov": 64.0},
	{"id": "band3_alley", "anchor": &"maze.band3.east",
		"target_unit": &"maze.band3.turn.south", "offset": Vector3(-3, 1.7, 3),
		"target_offset": Vector3(0, 1.4, 0), "fov": 64.0},
	{"id": "upper_arrival", "anchor": &"maze.band3.turn.west",
		"target_unit": &"maze.band3.turn.west", "offset": Vector3(-3, 1.7, 2),
		"target_offset": Vector3(0, 1.0, 0), "fov": 64.0},
	{"id": "roofline", "anchor": &"maze.band3.turn.south",
		"target_unit": &"maze.band3.turn.south", "offset": Vector3(-18, 15, 16),
		"target_offset": Vector3(0, 2, 0), "fov": 54.0,
		"require_target_visible": false},
	{"id": "sectional_profile", "anchor": &"maze.band1.turn.west",
		"target_unit": &"maze.band3.turn.south", "offset": Vector3(24, 12, 12),
		"target_offset": Vector3(0, 0, 0), "fov": 54.0,
		"require_target_visible": false},
	{"id": "network_overview", "anchor": &"maze.band1.turn.west",
		"target_unit": &"maze.band1.turn.west", "offset": Vector3(30, 28, 28),
		"target_offset": Vector3(0, 2, 0), "fov": 52.0,
		"require_target_visible": false},
]


func _ready() -> void:
	_read_args()
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(_output_dir)
	_build_environment()
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	assert(program != null)
	_plan = PlotVoidPlanner.new().solve(program, _world_seed) if _plot_void \
		else FoldedProof.solve(program, _world_seed)
	assert(_plan != null and _plan.is_sealed())
	_build_ground(_plan, catalog)
	var fabric_root := Node3D.new()
	fabric_root.name = "WarrenReviewFabric"
	add_child(fabric_root)
	var committed := SettlementFabricAssembler.commit(fabric_root, _plan,
		catalog, true)
	print(("[warren_town] placements=%d assets=%d collision_pieces=%d " \
		+ "surface_patches=%d surface_triangles=%d guards=%d") % [
		int(committed.instance_count), int(committed.asset_count),
		int(committed.collision_piece_count), int(committed.surface_patch_count),
		int(committed.surface_triangle_count),
		int(_plan.audit.derived_guard_segment_count)])
	_camera.current = true
	_camera.near = 0.08
	_camera.far = 300.0
	add_child(_camera)
	if DisplayServer.get_name() == "headless":
		_write_index()
		print("[warren_town] structural smoke passed; capture skipped headless")
		get_tree().quit()
		return
	_capture_all.call_deferred()


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--output" and index + 1 < args.size():
			_output_dir = args[index + 1]
		elif args[index] == "--seed" and index + 1 < args.size():
			_world_seed = int(args[index + 1])
		elif args[index] == "--plot-void":
			_plot_void = true


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("4c77ad")
	sky_material.sky_horizon_color = Color("b7d4dc")
	sky_material.ground_bottom_color = Color("515b51")
	sky_material.ground_horizon_color = Color("a6b79d")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color("c7bea9")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54.0, -34.0, 0.0)
	sun.light_color = Color("ffe3b7")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.55
	sun.directional_shadow_max_distance = 100.0
	add_child(sun)


func _build_ground(plan: SettlementFabricPlan,
		catalog: EnvironmentCatalog) -> void:
	_add_box("Ground", Vector3(84.0, 0.3, 84.0),
		Vector3(0.0, -0.15, -21.0), Color("758d52"), true)
	var support_heights := _support_heightfield(plan)
	var payload := EnvironmentInstancePayload.new()
	for xz_value: Variant in support_heights:
		var xz := xz_value as Vector2i
		var height_cells := int(support_heights[xz])
		var top_y := float(height_cells) * FabricRecipe.CELL_SIZE
		if top_y <= 0.0:
			continue
		var world_x := float(xz.x) * FabricRecipe.CELL_SIZE
		var world_z := float(xz.y) * FabricRecipe.CELL_SIZE
		_add_box("Support_%d_%d" % [xz.x, xz.y],
			Vector3(1.46, top_y, 1.46),
			Vector3(world_x, top_y * 0.5, world_z), Color("4e514b"), true)
		_add_box("SupportTop_%d_%d" % [xz.x, xz.y],
			Vector3(1.50, 0.05, 1.50),
			Vector3(world_x, top_y - 0.025, world_z), Color("697d4b"), false)
		_add_exposed_support_walls(payload, xz, height_cells, support_heights)
	if payload.instance_count > 0:
		assert(payload.validate())
		var cache := EnvironmentRenderCache.new(catalog)
		assert(cache.prepare([ROCK_WALL]))
		var queue := EnvironmentCommitQueue.new(cache, &"ReviewSupportWalls")
		queue.register_chunk(Vector2i.ZERO, 1)
		queue.enqueue(Vector2i.ZERO, 1, self, payload)
		while queue.pending_count() > 0:
			queue.drain(256)
	# A human-height marker keeps scale legible without introducing unrelated
	# character animation or controller state into the review harness.
	var marker := MeshInstance3D.new()
	marker.name = "HumanScale"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.38
	capsule.height = 1.75
	marker.mesh = capsule
	marker.position = Vector3(-32.0, 0.875, -1.7)
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color("594b78")
	marker.material_override = marker_material
	add_child(marker)


static func _support_heightfield(plan: SettlementFabricPlan) -> Dictionary:
	var heights: Dictionary = {}
	# This fixture has no live TerrainSurfaceField. Terrain-street claims are the
	# frozen surrogate for surveyed natural perches, so render their ground mass
	# all the way down instead of showing a tan sheet floating like a platform.
	# Structural courts and bridges remain timber and are never included here.
	for cell: Vector3i in plan.surface_plan.cells_for_kind(
			PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET):
		var xz := Vector2i(cell.x, cell.z)
		heights[xz] = maxi(int(heights.get(xz, 0)), cell.y)
	for unit_value: FabricUnit in plan.units:
		var recipe_value := plan.recipe(unit_value.recipe_id)
		if recipe_value.terrain_bearing_cells.is_empty():
			continue
		for local_cell: Vector3i in recipe_value.terrain_bearing_cells:
			var cell := FabricRecipe.transform_cell(local_cell,
				unit_value.lattice_origin, unit_value.yaw_quarters)
			var xz := Vector2i(cell.x, cell.z)
			heights[xz] = maxi(int(heights.get(xz, 0)),
				unit_value.lattice_origin.y)
	# Do not grow these exact contacts into invented terrain. The earlier review
	# harness did that to make high houses look naturally perched; screenshots
	# then appeared healthier while proving a landform the planner had never
	# surveyed. Runtime acceptance must qualify these contacts against the real
	# immutable TerrainSurfaceField (or replace them with an explicit retained
	# support). The deliberately literal fixture makes any missing terrain
	# integration visible instead of concealing it with a post-plan ziggurat.
	return heights


static func _add_exposed_support_walls(payload: EnvironmentInstancePayload,
		xz: Vector2i, height_cells: int, heights: Dictionary) -> void:
	var sides: Array[Dictionary] = [
		{"offset": Vector2i(0, -1), "position": Vector3(0, 0, -0.75), "yaw": 0.0},
		{"offset": Vector2i(0, 1), "position": Vector3(0, 0, 0.75), "yaw": PI},
		{"offset": Vector2i(-1, 0), "position": Vector3(-0.75, 0, 0), "yaw": PI * 0.5},
		{"offset": Vector2i(1, 0), "position": Vector3(0.75, 0, 0), "yaw": -PI * 0.5},
	]
	for side_index in sides.size():
		var side := sides[side_index]
		var neighbor_height := int(heights.get(xz + side.offset, 0))
		if neighbor_height >= height_cells:
			continue
		var bottom_m := float(neighbor_height) * FabricRecipe.CELL_SIZE
		var top_m := float(height_cells) * FabricRecipe.CELL_SIZE
		var level_count := ceili((top_m - bottom_m) / 3.0)
		for level in level_count:
			var y := top_m - float(level + 1) * 3.0
			var offset := side.position as Vector3
			var position := Vector3(float(xz.x) * FabricRecipe.CELL_SIZE,
				y, float(xz.y) * FabricRecipe.CELL_SIZE) + offset
			payload.add(ROCK_WALL,
				Transform3D(Basis(Vector3.UP, float(side.yaw)), position),
				Color.WHITE, StringName("support/%d/%d/%d/%d" % [xz.x, xz.y,
					side_index, level]))


func _add_box(node_name: String, size: Vector3, position: Vector3,
		color: Color, collision: bool) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	mesh_instance.material_override = material
	add_child(mesh_instance)
	if collision:
		var body := StaticBody3D.new()
		body.name = "%sCollision" % node_name
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		shape_node.position = position
		body.add_child(shape_node)
		add_child(body)


func _capture_all() -> void:
	for unused in 8:
		await get_tree().process_frame
	for view: Dictionary in _review_views():
		_camera.fov = float(view.fov)
		var requested_position := _view_point(view, &"anchor", &"offset")
		var camera_target := _view_point(view, &"target_unit", &"target_offset")
		var require_target_visible := bool(view.get("require_target_visible", true))
		var camera_resolution := _resolve_camera_position(requested_position,
			camera_target, require_target_visible)
		var camera_position := camera_resolution.position as Vector3
		if not bool(camera_resolution.valid):
			_camera_failures.append(String(view.id))
		if require_target_visible and not bool(camera_resolution.target_visible):
			_obscured_captures.append(String(view.id))
		_camera.look_at_from_position(camera_position, camera_target)
		for unused in 3:
			await get_tree().process_frame
		RenderingServer.force_draw()
		await get_tree().process_frame
		var screenshot_id := "warren-%s" % String(view.id)
		var path := "%s/%s.png" % [_output_dir, screenshot_id]
		var image := get_viewport().get_texture().get_image()
		assert(image != null and image.save_png(path) == OK)
		_captures.append({
			"screenshot_id": screenshot_id,
			"world_seed": _world_seed,
			"image": path,
			"recipe": view.id,
			"requested_camera_position": _v3(requested_position),
			"camera_position": _v3(camera_position),
			"camera_target": _v3(camera_target),
			"camera_clearance_valid": camera_resolution.valid,
			"target_visibility_valid": camera_resolution.target_visible,
			"target_visibility_fraction": camera_resolution.visibility_fraction,
			"target_visibility_required": require_target_visible,
			"camera_resolution_distance_m": camera_resolution.distance,
			"fov": view.fov,
		})
		print("[warren_town] captured ", path)
	_write_index()
	get_tree().quit()


func _review_views() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _plot_void:
		out.append_array(_procedural_plot_void_views())
	else:
		for source: Dictionary in VIEWS:
			out.append(source.duplicate(true))
	# Feature cameras are derived from semantic output instead of assuming a
	# particular seed selected a hard-coded facade. This keeps the screenshot
	# corpus capable of reviewing the thing it claims to cover as generation
	# starts varying building and tunnel identities.
	for feature: Dictionary in [
		{"tag": &"skywalk", "id": "skywalk",
			"views": [
				{"suffix": "side", "offset": Vector3(0, 2.5, 10),
					"target_offset": Vector3(0, 1.5, 0)},
				{"suffix": "beneath", "offset": Vector3(0, -1.2, 6),
					"target_offset": Vector3(0, 0.2, 0)},
				{"suffix": "end", "offset": Vector3(9, 2.5, 3),
					"target_offset": Vector3(0, 1.5, 0)},
			]},
		{"tag": &"outcropping", "id": "outcropping",
			"views": [
				{"suffix": "side", "offset": Vector3(5, 2.0, 7),
					# Aim at the shallow bay's exterior facade, not the occupied
					# room centre behind it. A correct wall must not be reported as
					# an obstruction by the review ray panel.
					"target_offset": Vector3(0, 1.2, 1.35)},
				{"suffix": "beneath", "offset": Vector3(2, -1.0, 5),
					"target_offset": Vector3(0, -0.35, 1.35)},
			]},
		{"tag": &"prefab_anchor", "id": "prefab",
			"views": [
				{"suffix": "facade", "offset": Vector3.ZERO,
					"target_offset": Vector3.ZERO},
			]},
	]:
		var feature_index := 0
		for unit_value: FabricUnit in _review_feature_units(
				StringName(feature.tag)):
			var recipe_value := _plan.recipe(unit_value.recipe_id)
			if recipe_value == null or not recipe_value.has_tag(
					StringName(feature.tag)):
				continue
			for feature_view: Dictionary in feature.views as Array:
				var view := {
					"id": "%s_%02d_%s" % [feature.id, feature_index,
						String(feature_view.suffix)],
					"anchor": unit_value.stable_id,
					"target_unit": unit_value.stable_id,
					"offset": feature_view.offset,
					"target_offset": feature_view.target_offset,
					"local_offsets": true,
					"feature_unit_id": unit_value.stable_id,
					"feature_recipe_id": unit_value.recipe_id,
					"fov": 58.0,
				}
				if StringName(feature.tag) == &"prefab_anchor":
					_set_prefab_facade_view(view, unit_value)
				else:
					# Inspect the actual authored envelope, not the recipe pivot. A
					# pivot can sit on a rear corner or beneath a long bridge, making a
					# semantically named frame point at empty air.
					var bounds := _review_feature_bounds(unit_value,
						StringName(feature.tag))
					var centre := bounds.get_center()
					view["camera_position"] = centre + unit_value.transform().basis \
						* (feature_view.offset as Vector3)
					view["camera_target"] = centre + unit_value.transform().basis \
						* (feature_view.target_offset as Vector3)
				out.append(view)
			feature_index += 1
	return out


func _review_feature_units(tag: StringName) -> Array[FabricUnit]:
	var ordinary: Array[FabricUnit] = []
	var skywalk_groups: Dictionary = {}
	for unit_value: FabricUnit in _plan.units:
		var recipe_value := _plan.recipe(unit_value.recipe_id)
		if recipe_value == null or not recipe_value.has_tag(tag):
			continue
		if tag != &"skywalk":
			ordinary.append(unit_value)
			continue
		var unit_text := String(unit_value.stable_id)
		var group_id := unit_text
		for suffix in [".arm-a", ".corner", ".arm-b"]:
			if unit_text.ends_with(suffix):
				group_id = unit_text.trim_suffix(suffix)
				break
		# Photograph the knuckle of an orthogonal tunnel, not each arm as though
		# it were a separate city link. This keeps screenshot counts consistent
		# with the semantic skywalk-link audit.
		if not skywalk_groups.has(group_id) or unit_text.ends_with(".corner"):
			skywalk_groups[group_id] = unit_value
	if tag != &"skywalk":
		return ordinary
	var group_ids: Array = skywalk_groups.keys()
	group_ids.sort()
	for group_id: String in group_ids:
		ordinary.append(skywalk_groups[group_id] as FabricUnit)
	return ordinary


func _review_feature_bounds(unit_value: FabricUnit, tag: StringName) -> AABB:
	var recipe_value := _plan.recipe(unit_value.recipe_id)
	var bounds := unit_value.transform() * recipe_value.local_clearance_bounds
	if tag != &"skywalk":
		return bounds
	var unit_text := String(unit_value.stable_id)
	var group_id := unit_text
	for suffix in [".arm-a", ".corner", ".arm-b"]:
		if unit_text.ends_with(suffix):
			group_id = unit_text.trim_suffix(suffix)
			break
	# An orthogonal link is three structural units but one semantic skywalk.
	# Review its complete envelope; using only the corner recipe made the camera
	# resolve onto a nearby roof while technically retaining a ray to the knuckle.
	for candidate: FabricUnit in _plan.units:
		if candidate == unit_value \
				or not String(candidate.stable_id).begins_with(group_id + "."):
			continue
		var candidate_recipe := _plan.recipe(candidate.recipe_id)
		if candidate_recipe != null and candidate_recipe.has_tag(&"skywalk"):
			bounds = bounds.merge(candidate.transform() \
				* candidate_recipe.local_clearance_bounds)
	return bounds


func _procedural_plot_void_views() -> Array[Dictionary]:
	## The procedural grammar deliberately has no fixed semantic coordinates.
	## Review cameras must therefore follow the sealed public itinerary too;
	## retaining fixed prototype ids silently produced empty green screenshots as
	## soon as seed variation became real.
	var out: Array[Dictionary] = []
	var itinerary := _plan.public_realm.primary_itinerary
	var sample_indices: Array[int] = [0]
	for index in itinerary.size():
		var node_value := _plan.public_realm.node(itinerary[index])
		if node_value.episode_kind == PublicRealmNode.EpisodeKind.STAIR_CANYON:
			sample_indices.append(maxi(0, index - 1))
			sample_indices.append(index)
			sample_indices.append(mini(itinerary.size() - 2, index + 1))
	for fraction in [0.25, 0.5, 0.75]:
		sample_indices.append(clampi(int(floor((itinerary.size() - 2) \
			* float(fraction))), 0, itinerary.size() - 2))
	var seen: Dictionary = {}
	for index in sample_indices:
		if seen.has(index) or index < 0 or index + 1 >= itinerary.size():
			continue
		seen[index] = true
		var from_node := _plan.public_realm.node(itinerary[index])
		var to_node := _plan.public_realm.node(itinerary[index + 1])
		var from_point := _node_surface_centre(from_node)
		var to_point := _node_surface_centre(to_node)
		var forward := Vector3(to_point.x - from_point.x, 0,
			to_point.z - from_point.z).normalized()
		if forward.is_zero_approx():
			forward = Vector3.FORWARD
		var side := Vector3(-forward.z, 0, forward.x)
		out.append({
			"id": "route_%02d_%s" % [index,
				"stair" if from_node.episode_kind == \
				PublicRealmNode.EpisodeKind.STAIR_CANYON else "passage"],
			"camera_position": from_point - forward * 3.0 + side * 1.5 \
				+ Vector3.UP * 1.7,
			"camera_target": to_point + Vector3.UP * 1.2,
			"fov": 68.0,
			"require_target_visible": true,
		})
	var bounds := _review_world_bounds()
	var centre := bounds.get_center()
	var extent := maxf(bounds.size.x, bounds.size.z)
	for overview: Dictionary in [
		{"id": "roofline", "offset": Vector3(-0.8, 0.65, 0.8),
			"fov": 54.0},
		{"id": "sectional_profile", "offset": Vector3(0.9, 0.45, 0.15),
			"fov": 56.0},
		{"id": "network_overview", "offset": Vector3(0.8, 0.9, 0.8),
			"fov": 52.0},
	]:
		out.append({
			"id": overview.id,
			"camera_position": centre + (overview.offset as Vector3) \
				* maxf(24.0, extent * 1.45),
			"camera_target": centre + Vector3.UP * 1.5,
			"fov": overview.fov,
			"require_target_visible": false,
		})
	return out


func _node_surface_centre(node_value: PublicRealmNode) -> Vector3:
	var total := Vector3.ZERO
	for cell: Vector3i in node_value.surface_cells:
		total += Vector3(cell) * FabricRecipe.CELL_SIZE
	return total / float(node_value.surface_cells.size())


func _review_world_bounds() -> AABB:
	var bounds := AABB()
	var initialized := false
	for unit_value: FabricUnit in _plan.units:
		var recipe_value := _plan.recipe(unit_value.recipe_id)
		var unit_bounds := unit_value.transform() \
			* recipe_value.local_clearance_bounds
		if not initialized:
			bounds = unit_bounds
			initialized = true
		else:
			bounds = bounds.merge(unit_bounds)
	assert(initialized)
	return bounds


func _set_prefab_facade_view(view: Dictionary, unit_value: FabricUnit) -> void:
	## Source assets do not share a useful pivot convention. The exterior
	## threshold is the one invariant a facade review actually cares about, so
	## photograph the door from its served landing and never infer "front" from
	## an AABB or a hard-coded orbit quadrant.
	for entrance: Dictionary in _plan.surface_plan.entrance_records:
		if StringName(entrance.unit_id) != unit_value.stable_id:
			continue
		var threshold := entrance.threshold_cell as Vector3i
		var facing := entrance.facing as Vector3i
		var target := Vector3(threshold) * FabricRecipe.CELL_SIZE \
			+ Vector3.UP * 1.5
		view["camera_target"] = target
		view["camera_position"] = target + Vector3(facing) * 7.5 \
			+ Vector3.UP * 0.5
		return
	assert(false, "reviewed prefab has no exterior entrance record")


func _view_point(view: Dictionary, unit_key: StringName,
		offset_key: StringName) -> Vector3:
	var explicit_key := &"camera_position" if unit_key == &"anchor" \
		else &"camera_target"
	if view.has(explicit_key):
		return view[explicit_key] as Vector3
	var unit_value := _plan.unit(StringName(view[unit_key]))
	assert(unit_value != null)
	var offset := view[offset_key] as Vector3
	if bool(view.get("local_offsets", false)):
		offset = unit_value.transform().basis * offset
	return unit_value.transform().origin + offset


func _resolve_camera_position(requested: Vector3, target: Vector3,
		require_target_visible: bool) -> Dictionary:
	## Review cameras are inspection instruments. A frame taken from inside a
	## wall can hide the very defect it is meant to reveal, so test a small sphere
	## against the committed structural collision and move deterministically to
	## the nearest clear sample. Failure remains explicit in index.json.
	var offsets: Array[Vector3] = [Vector3.ZERO]
	var directions: Array[Vector3] = [
		Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK,
		Vector3(1, 0, 1).normalized(), Vector3(-1, 0, 1).normalized(),
		Vector3(1, 0, -1).normalized(), Vector3(-1, 0, -1).normalized(),
	]
	for radius in [0.75, 1.5, 2.25, 3.0, 4.5, 6.0]:
		for rise in [0.0, 0.75, 1.5]:
			for direction: Vector3 in directions:
				offsets.append(direction * float(radius) + Vector3.UP * float(rise))
	# Dense revisions can put an old requested camera beneath a new roof
	# overhang even when a nearby public path remains valid. Add only semantic
	# exterior-air samples, then sort all candidates by displacement. This keeps
	# first-person review cameras in the same walkable outside component instead
	# of tunnelling through walls to find an unclipped frame.
	if _plan != null and _plan.volume_plan != null:
		for cell: Vector3i in _plan.volume_plan.exterior_air_cells:
			if not _plan.volume_plan.has_exterior_air(cell + Vector3i.DOWN):
				continue
			var exterior_candidate := Vector3(cell) * FabricRecipe.CELL_SIZE \
				+ Vector3.UP * 0.2
			var delta := exterior_candidate - requested
			if delta.length() <= 12.0:
				offsets.append(delta)
	# A generated bridge or prefab can move to another facade for a new seed.
	# Add deterministic orbit samples around the inspected target so a stale
	# authored offset cannot force the reviewer into an unrelated wall. These
	# samples still pass the same visual-envelope, physics, and ray tests below.
	for radius in [8.0, 12.0, 16.0, 20.0]:
		for rise in [3.0, 6.0, 9.0]:
			for direction: Vector3 in directions:
				var orbit_candidate: Vector3 = target \
					+ direction * float(radius) + Vector3.UP * float(rise)
				offsets.append(orbit_candidate - requested)
	offsets.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return a.length_squared() < b.length_squared())
	var nearest_clear: Dictionary = {}
	for offset: Vector3 in offsets:
		var candidate := requested + offset
		if Vector2(candidate.x - target.x,
				candidate.z - target.z).length() < 0.35:
			continue
		if _camera_position_is_clear(candidate):
			var visibility_fraction := _camera_target_visibility_fraction(candidate,
				target)
			var result := {
				"position": candidate,
				"valid": true,
				"distance": offset.length(),
				"target_visible": visibility_fraction >= 0.67,
				"visibility_fraction": visibility_fraction,
			}
			if not require_target_visible or bool(result.target_visible):
				return result
			if nearest_clear.is_empty():
				nearest_clear = result
	if not nearest_clear.is_empty():
		return nearest_clear
	return {"position": requested, "valid": false, "distance": 0.0,
		"target_visible": false, "visibility_fraction": 0.0}


func _camera_position_is_clear(position: Vector3) -> bool:
	# Collision proxies intentionally follow the visible shell instead of filling
	# every room. Review cameras also consult the worker's semantic occupied
	# volume so a sparse proxy cannot admit a camera inside a building and make a
	# useless interior frame look valid.
	if _plan != null:
		for bounds: AABB in _plan.transformed_visual_clearance_bounds():
			if bounds.grow(0.18).has_point(position):
				return false
	if _plan != null and _plan.volume_plan != null:
		var cell := Vector3i(
			roundi(position.x / FabricRecipe.CELL_SIZE),
			floori(position.y / FabricRecipe.CELL_SIZE),
			roundi(position.z / FabricRecipe.CELL_SIZE))
		if _plan.volume_plan.has_occupied_cell(cell):
			return false
	var sphere := SphereShape3D.new()
	sphere.radius = 0.28
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, position)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _camera_target_visibility_fraction(position: Vector3,
		target: Vector3) -> float:
	## A single centre ray let a post or wall occupy most of a screenshot while
	## the index still called it visible. Probe a small review panel around the
	## semantic target. Two thirds of it must be readable; an opaque foreground
	## edge is then reported instead of silently becoming the composition.
	var forward := target - position
	var distance := forward.length()
	if distance <= 0.5:
		return 1.0
	forward /= distance
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.5:
		right = Vector3.RIGHT
	var visible := 0
	var samples := 0
	for vertical in [-1.0, 0.0, 1.0]:
		for horizontal in [-1.0, 0.0, 1.0]:
			var sample: Vector3 = target + right * float(horizontal) * 1.1 \
				+ Vector3.UP * float(vertical) * 1.15
			var query := PhysicsRayQueryParameters3D.create(position, sample)
			query.collide_with_areas = false
			query.collide_with_bodies = true
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or (hit.position as Vector3).distance_to(sample) \
					<= minf(1.25, position.distance_to(sample) * 0.12):
				visible += 1
			samples += 1
	return float(visible) / float(samples)


func _write_index() -> void:
	var review_failures := SettlementFabricSolver.requirement_failures(
		_plan.audit, FoldedProof.REVIEW_TARGETS)
	for camera_id: String in _camera_failures:
		review_failures.append("camera %s has no collision-free sample" % camera_id)
	for camera_id: String in _obscured_captures:
		review_failures.append("camera %s is collision-clear but target-obscured" %
			camera_id)
	_write_json("%s/index.json" % _output_dir, {
		"world_seed": _world_seed,
		"source_coverage": {
			"phase_zero_complete": review_failures.is_empty(),
			"multistreet_review_complete": review_failures.is_empty(),
			"full_spec_complete": false,
		},
		"review_instruction": "Success means finding a real visual or structural issue.",
		"verification_protocol": {
			"adversarial": true,
			"issue_discovery_is_success": true,
			"required_capture_disposition": "clear, suspicion, or finding",
			"required_coverage": ["street", "exterior facade stair", "court",
				"court bearing", "authored platform planks", "guard edge",
				"guarded daylight opening", "addressed court entrance",
				"occupied overhead skywalk",
				"external return descent", "roofline", "sectional profile",
				"network overview"],
		},
		"review": {
			"passed": review_failures.is_empty(),
			"targets": FoldedProof.REVIEW_TARGETS,
			"failures": review_failures,
		},
		"camera_clearance": {
			"passed": _camera_failures.is_empty() and _obscured_captures.is_empty(),
			"failed_camera_ids": _camera_failures,
			"obscured_camera_ids": _obscured_captures,
		},
		"plan_id": String(_plan.stable_id),
		"audit": _plan.audit,
		"embedding": {
			"signature": _plan.embedding_plan.deterministic_signature() \
				if _plan.embedding_plan != null else "",
			"audit": _plan.embedding_plan.audit() \
				if _plan.embedding_plan != null else {},
		},
		"unit_count": _plan.units.size(),
		"units": _unit_records(_plan),
		"assets": _string_names(_plan.asset_ids()),
		"lattice": {
			"route_walk": _cell_records(_plan.transformed_cells(&"walk", &"route")),
			"exterior_air": _vector_cell_records(
				_plan.volume_plan.exterior_air_cells),
			"occluders": _cell_records(_plan.transformed_cells(&"occluder")),
			"derived_guards": _guard_records(_plan.surface_plan.guard_segments),
			"entrances": _entrance_records(_plan.surface_plan.entrance_records),
			"daylight_voids": _vector_cell_records(
				_plan.public_realm.daylight_void_cells),
		},
		"captures": _captures,
	})


static func _write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(value, "  ", true))


static func _string_names(values: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for value: StringName in values:
		out.append(String(value))
	return out


static func _unit_records(plan: SettlementFabricPlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for unit_value: FabricUnit in plan.units:
		out.append({
			"id": String(unit_value.stable_id),
			"recipe": String(unit_value.recipe_id),
			"origin": [unit_value.lattice_origin.x, unit_value.lattice_origin.y,
				unit_value.lattice_origin.z],
			"yaw": unit_value.yaw_quarters,
		})
	return out


static func _cell_records(cells: Dictionary) -> Array[Array]:
	var out: Array[Array] = []
	for cell_value: Variant in cells:
		var cell := cell_value as Vector3i
		out.append([cell.x, cell.y, cell.z, String(cells[cell])])
	out.sort_custom(func(a: Array, b: Array) -> bool:
		if int(a[1]) != int(b[1]):
			return int(a[1]) < int(b[1])
		if int(a[2]) != int(b[2]):
			return int(a[2]) < int(b[2])
		return int(a[0]) < int(b[0]))
	return out


static func _vector_cell_records(cells: Array[Vector3i]) -> Array[Array]:
	var out: Array[Array] = []
	for cell: Vector3i in cells:
		out.append([cell.x, cell.y, cell.z])
	out.sort_custom(func(a: Array, b: Array) -> bool:
		if int(a[1]) != int(b[1]):
			return int(a[1]) < int(b[1])
		if int(a[2]) != int(b[2]):
			return int(a[2]) < int(b[2])
		return int(a[0]) < int(b[0]))
	return out


static func _guard_records(segments: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for segment: Dictionary in segments:
		out.append({
			"key": String(segment.stable_key),
			"boundary_kind": String(segment.get("boundary_kind", "")),
			"from": _v3(segment.a as Vector3),
			"to": _v3(segment.b as Vector3),
		})
	return out


static func _entrance_records(records: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for record: Dictionary in records:
		var threshold := record.threshold_cell as Vector3i
		var landing := record.landing_cell as Vector3i
		out.append({
			"id": String(record.stable_id),
			"unit_id": String(record.unit_id),
			"threshold": [threshold.x, threshold.y, threshold.z],
			"landing": [landing.x, landing.y, landing.z],
			"served": bool(record.served),
		})
	return out


static func _v3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
