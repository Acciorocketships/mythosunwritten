extends Node3D

## Visual proof for the seeded volumetric warren pipeline. Unlike the older
## fixed sectional fixture, every capture in this scene is built from
## WarrenBuiltTownSolver output for the requested world seed.
var _output_dir := "/tmp/mythos-warren-volume"
var _world_seed := 0
var _attempt := -1
var _camera := Camera3D.new()
var _built: WarrenBuiltTownPlan
var _captures: Array[Dictionary] = []


func _ready() -> void:
	_read_args()
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(_output_dir)
	_build_environment()
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	assert(program != null)
	_built = WarrenBuiltTownSolver.solve_attempt(_world_seed, _attempt,
		program) if _attempt >= 0 else WarrenBuiltTownSolver.solve(
		_world_seed, program)
	if _built == null or not _built.is_sealed():
		# A rejected seed is an ordinary outcome for batch drivers; an assert
		# here hung the GUI process indefinitely instead of exiting.
		printerr("[warren_volume] seed=%d REJECTED: %s" % [_world_seed,
			WarrenBuiltTownSolver.last_failure])
		get_tree().quit(1)
		return
	_build_ground()
	var root := Node3D.new()
	root.name = "VolumetricWarrenFabric"
	add_child(root)
	var committed := SettlementFabricAssembler.commit(root, _built.fabric,
		catalog, true)
	print(("[warren_volume] seed=%d attempt=%d parcels=%d skywalks=%d " \
		+ "outcrops=%d instances=%d collisions=%d triangles=%d") % [_world_seed,
		int(_built.audit.get("route_attempt", -1)),
		int(_built.audit.parcel_count), int(_built.audit.skywalk_count),
		int(_built.audit.outcropping_count), int(committed.instance_count),
		int(committed.collision_piece_count), int(committed.surface_triangle_count)])
	_camera.current = true
	_camera.near = 0.08
	_camera.far = 400.0
	add_child(_camera)
	if DisplayServer.get_name() == "headless":
		_write_manifest()
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
		elif args[index] == "--attempt" and index + 1 < args.size():
			_attempt = int(args[index + 1])


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("527faf")
	sky_material.sky_horizon_color = Color("c5dce0")
	sky_material.ground_bottom_color = Color("596152")
	sky_material.ground_horizon_color = Color("aebd9f")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -37.0, 0.0)
	sun.light_color = Color("ffe4b9")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.55
	add_child(sun)


func _build_ground() -> void:
	_add_box("Ground", Vector3(96.0, 0.4, 96.0),
		Vector3(0.0, -0.2, 0.0), Color("718d50"))


func _add_box(node_name: String, size: Vector3, position: Vector3,
		color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	instance.material_override = material
	add_child(instance)


func _capture_all() -> void:
	for unused in 10:
		await get_tree().process_frame
	for view: Dictionary in _views():
		_camera.fov = float(view.fov)
		var requested := view.position as Vector3
		var target := view.target as Vector3
		var require_target_visible := bool(view.get("require_target_visible", true))
		var resolution := _resolve_camera_position(requested, target,
			require_target_visible, float(view.get("visibility_sample_radius", 1.1)))
		var camera_position := resolution.position as Vector3
		_camera.look_at_from_position(camera_position, target)
		for unused in 3:
			await get_tree().process_frame
		RenderingServer.force_draw()
		await get_tree().process_frame
		var path := "%s/seed-%03d-%s.png" % [_output_dir, _world_seed,
			String(view.id)]
		var image := get_viewport().get_texture().get_image()
		assert(image != null and image.save_png(path) == OK)
		_captures.append({"screenshot_id": view.id, "world_seed": _world_seed,
			"image": path, "requested_camera_position": _v3(requested),
			"camera_position": _v3(camera_position),
			"camera_target": _v3(target), "fov": view.fov,
			"camera_clearance_valid": resolution.valid,
			"target_visibility_valid": resolution.target_visible,
			"target_visibility_fraction": resolution.visibility_fraction,
			"target_visibility_required": require_target_visible,
			"camera_resolution_distance_m": resolution.distance,
			"review_disposition": "UNREVIEWED"})
		print("[warren_volume] captured ", path)
	_write_manifest()
	get_tree().quit()


func _views() -> Array[Dictionary]:
	var bounds := _fabric_bounds(_built.fabric)
	var center := bounds.get_center()
	var span := maxf(bounds.size.x, bounds.size.z)
	var high := bounds.end.y
	var out: Array[Dictionary] = [
		{"id": "overview-ne", "position": center + Vector3(span, span * 0.8,
			span), "target": center + Vector3(0, bounds.size.y * 0.15, 0),
			"fov": 52.0, "require_target_visible": false},
		{"id": "overview-sw", "position": center + Vector3(-span,
			span * 0.65, -span * 0.8), "target": center,
			"fov": 54.0, "require_target_visible": false},
		{"id": "section-east", "position": center + Vector3(span * 1.05,
			bounds.size.y * 0.35, 0), "target": center + Vector3(0,
			bounds.size.y * 0.1, 0), "fov": 58.0,
			"require_target_visible": false},
	]
	var entry := _built.assets.town.volume.entry_cell
	var entry_world := Vector3(entry.x * 3.0, entry.y * 1.5, entry.z * 3.0)
	var next := _built.assets.town.volume.primary_itinerary[1]
	var direction := Vector3(next.x - entry.x, 0, next.z - entry.z).normalized()
	var entry_target := Vector3(next.x * 3.0, next.y * 1.5 + 1.35,
		next.z * 3.0)
	out.append({"id": "entry", "position": entry_world + Vector3.UP * 1.7
		- direction * 4.0, "target": entry_target, "fov": 68.0})
	# Hostile horizontal chords deliberately try to falsify the maze reading.
	# Resolve them from actual ground-route cells: a nominal center-to-center ray
	# was frequently pushed onto a roof by camera collision and no longer tested
	# whether a player could see through the lower city.
	out.append_array(_ground_route_chord_views(_built.assets.town.volume))
	var highest := _highest_route_cell(_built.assets.town.volume)
	var high_world := Vector3(highest.x * 3.0, highest.y * 1.5,
		highest.z * 3.0)
	out.append({"id": "upper-route", "position": high_world
		+ Vector3(-5, 2.2, 5), "target": high_world + Vector3.UP,
		"fov": 66.0})
	var skywalk_bounds := _review_skywalk_bounds(_built)
	if skywalk_bounds != AABB():
		# View across the link's short axis. A fixed diagonal can line up with an
		# endpoint facade and return a perfect visibility ray while hiding the
		# bridge silhouette that this named review view is supposed to falsify.
		# Corner links are three ordinary units, so inspect the accepted motif's
		# union rather than accidentally aiming at its first cantilever arm.
		var link_runs_x := skywalk_bounds.size.x >= skywalk_bounds.size.z
		var side_direction := Vector3.FORWARD if link_runs_x else Vector3.RIGHT
		var run_direction := Vector3.RIGHT if link_runs_x else Vector3.FORWARD
		var link_length := maxf(skywalk_bounds.size.x, skywalk_bounds.size.z)
		var side_target := _horizontal_face_target(skywalk_bounds,
			side_direction, 0.58)
		out.append({"id": "skywalk-side", "position": side_target
			+ side_direction * maxf(12.0, link_length * 1.5)
			+ run_direction * minf(3.0, link_length * 0.25)
			+ Vector3.UP * 3.0,
			"target": side_target, "fov": 66.0})
		var underside_target := _horizontal_face_target(skywalk_bounds,
			side_direction, 0.0)
		underside_target.y = skywalk_bounds.position.y - 0.03
		var underside_camera := _exterior_air_beneath(skywalk_bounds,
			_built.fabric.volume_plan)
		if underside_camera == Vector3.INF:
			underside_camera = underside_target + side_direction * 12.0 \
				+ run_direction * minf(4.0, link_length * 0.35) \
				+ Vector3.DOWN
			underside_camera.y = maxf(0.8, underside_camera.y)
		out.append({"id": "skywalk-beneath", "position": underside_camera,
			"target": underside_target,
			"fov": 64.0, "visibility_sample_radius": 0.35})
	out.append({"id": "roofline", "position": center + Vector3(-span * 0.65,
		high + 10.0, span * 0.65), "target": center + Vector3(0,
		bounds.size.y * 0.35, 0), "fov": 54.0,
		"require_target_visible": false})
	out.append({"id": "network-above", "position": center
		+ Vector3(0.01, maxf(42.0, high + 18.0), 0.01),
		"target": center, "fov": 52.0, "require_target_visible": false})
	return out


static func _ground_route_chord_views(volume: WarrenVolumePlan) \
		-> Array[Dictionary]:
	var ground_cells: Array[Vector3i] = []
	# Hostile through-town views belong on the primary 3D journey. The auxiliary
	# market arcade is deliberately packed with large stocked prefabs; choosing
	# its farthest endpoint can put the review camera beneath a canopy and test a
	# stall roof instead of the city corridor.
	for cell: Vector3i in volume.primary_itinerary:
		if cell.y == volume.envelope.ground_at(Vector2i(cell.x, cell.z)):
			ground_cells.append(cell)
	if ground_cells.size() < 2:
		for cell: Vector3i in volume.walk_cells:
			if cell.y == volume.envelope.ground_at(Vector2i(cell.x, cell.z)):
				ground_cells.append(cell)
	ground_cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return "%d:%d:%d" % [a.x, a.y, a.z] < "%d:%d:%d" % [b.x, b.y, b.z])
	var primary := _longest_ground_pair(ground_cells)
	if primary.is_empty():
		return []
	var primary_delta := _horizontal_cell_direction(primary.a, primary.b)
	var secondary := _longest_ground_pair(ground_cells, primary_delta)
	if secondary.is_empty():
		secondary = {"a": primary.b, "b": primary.a}
	return [
		_ground_pair_view("ground-reverse", primary),
		_ground_pair_view("ground-cross", secondary),
	]


static func _longest_ground_pair(cells: Array[Vector3i],
		reject_parallel_to: Vector2 = Vector2.ZERO) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := -1.0
	for left_index in cells.size():
		for right_index in range(left_index + 1, cells.size()):
			var a := cells[left_index]
			var b := cells[right_index]
			var direction := _horizontal_cell_direction(a, b)
			if reject_parallel_to.length_squared() > 0.5 \
					and absf(direction.dot(reject_parallel_to)) > 0.65:
				continue
			var distance := Vector2(float(b.x - a.x), float(b.z - a.z)) \
				.length_squared()
			if distance > best_distance:
				best_distance = distance
				best = {"a": a, "b": b}
	return best


static func _horizontal_cell_direction(a: Vector3i, b: Vector3i) -> Vector2:
	return Vector2(float(b.x - a.x), float(b.z - a.z)).normalized()


static func _ground_pair_view(view_id: String, pair: Dictionary) -> Dictionary:
	var a := pair.a as Vector3i
	var b := pair.b as Vector3i
	var position := Vector3(float(a.x) * 3.0, float(a.y) * 1.5 + 1.65,
		float(a.z) * 3.0)
	var target := Vector3(float(b.x) * 3.0, float(b.y) * 1.5 + 1.65,
		float(b.z) * 3.0)
	return {"id": view_id, "position": position, "target": target,
		"fov": 62.0, "require_target_visible": false}


static func _exterior_air_beneath(bounds: AABB,
		volume: FabricVolumePlan) -> Vector3:
	if volume == null:
		return Vector3.INF
	var best := Vector3.INF
	var best_distance := INF
	var horizontal_bounds := bounds.grow(FabricRecipe.CELL_SIZE)
	for cell: Vector3i in volume.exterior_air_cells:
		var candidate := Vector3(cell) * FabricRecipe.CELL_SIZE \
			+ Vector3.UP * 0.2
		if candidate.y >= bounds.position.y - 0.35 \
				or candidate.x < horizontal_bounds.position.x \
				or candidate.x > horizontal_bounds.end.x \
				or candidate.z < horizontal_bounds.position.z \
				or candidate.z > horizontal_bounds.end.z:
			continue
		var distance := candidate.distance_squared_to(Vector3(
			bounds.get_center().x, bounds.position.y, bounds.get_center().z))
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


static func _horizontal_face_target(bounds: AABB, direction: Vector3,
		height_ratio: float) -> Vector3:
	## Visibility rays must terminate on the inspected facade, not at the centre
	## of occupied mass.  A centre target makes a perfectly visible skywalk look
	## obstructed because the ray correctly stops at its exterior wall.
	var horizontal := Vector2(direction.x, direction.z).normalized()
	var half := Vector2(bounds.size.x, bounds.size.z) * 0.5
	var distance := INF
	if absf(horizontal.x) > 0.001:
		distance = minf(distance, half.x / absf(horizontal.x))
	if absf(horizontal.y) > 0.001:
		distance = minf(distance, half.y / absf(horizontal.y))
	var center := bounds.get_center()
	return Vector3(center.x + horizontal.x * distance,
		bounds.position.y + bounds.size.y * height_ratio,
		center.z + horizontal.y * distance)


func _resolve_camera_position(requested: Vector3, target: Vector3,
		require_target_visible: bool,
		visibility_sample_radius: float = 1.1) -> Dictionary:
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
	if _built != null and _built.fabric.volume_plan != null:
		for cell: Vector3i in _built.fabric.volume_plan.exterior_air_cells:
			if not _built.fabric.volume_plan.has_exterior_air(
					cell + Vector3i.DOWN):
				continue
			var exterior_candidate := Vector3(cell) * FabricRecipe.CELL_SIZE \
				+ Vector3.UP * 0.2
			var delta := exterior_candidate - requested
			if delta.length() <= 12.0:
				offsets.append(delta)
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
				candidate.z - target.z).length() < 0.35 \
				or not _camera_position_is_clear(candidate):
			continue
		var visibility_fraction := _camera_target_visibility_fraction(candidate,
			target, visibility_sample_radius)
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
	if position.y < 0.35:
		return false
	if _built != null:
		for bounds: AABB in _built.fabric.transformed_visual_clearance_bounds():
			# A technically non-intersecting camera can still sit close enough to a
			# post, canopy, or eave for that foreground mesh to consume most of the
			# frame.  Review views represent a player's head and shoulders, not a
			# zero-radius ray, so keep a player-sized visual bubble around them.
			if bounds.grow(0.55).has_point(position):
				return false
	if _built != null and _built.fabric.volume_plan != null:
		var cell := Vector3i(roundi(position.x / FabricRecipe.CELL_SIZE),
			floori(position.y / FabricRecipe.CELL_SIZE),
			roundi(position.z / FabricRecipe.CELL_SIZE))
		if _built.fabric.volume_plan.has_occupied_cell(cell):
			return false
	var sphere := SphereShape3D.new()
	sphere.radius = 0.65
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, position)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _camera_target_visibility_fraction(position: Vector3,
		target: Vector3, sample_radius: float = 1.1) -> float:
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
			var sample: Vector3 = target + right * float(horizontal) * sample_radius \
				+ Vector3.UP * float(vertical) * sample_radius
			var query := PhysicsRayQueryParameters3D.create(position, sample)
			query.collide_with_areas = false
			query.collide_with_bodies = true
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or (hit.position as Vector3).distance_to(sample) \
					<= minf(1.25, position.distance_to(sample) * 0.12):
				visible += 1
			samples += 1
	return float(visible) / float(samples)


static func _fabric_bounds(plan: SettlementFabricPlan) -> AABB:
	var result := AABB()
	var initialized := false
	for unit_value: FabricUnit in plan.units:
		if not initialized:
			result = unit_value.bounds
			initialized = true
		else:
			result = result.merge(unit_value.bounds)
	for cell_value: Variant in plan.public_realm.surface_claims():
		var point := Vector3(cell_value as Vector3i) * FabricRecipe.CELL_SIZE
		result = AABB(point, Vector3(0.1, 0.1, 0.1)) if not initialized \
			else result.expand(point)
		initialized = true
	return result


static func _highest_route_cell(volume: WarrenVolumePlan) -> Vector3i:
	var result := volume.entry_cell
	for cell: Vector3i in volume.walk_cells:
		if cell.y > result.y:
			result = cell
	return result


static func _review_skywalk_bounds(built: WarrenBuiltTownPlan) -> AABB:
	var best := AABB()
	var best_span := -1.0
	for candidate: Dictionary in built.overhead_candidates:
		if StringName(candidate.category) != &"skywalk":
			continue
		var bounds := AABB()
		var initialized := false
		for spec: Dictionary in candidate.specs as Array:
			var unit_value := built.fabric.unit(StringName(spec.stable_id))
			if unit_value == null:
				continue
			bounds = unit_value.bounds if not initialized \
				else bounds.merge(unit_value.bounds)
			initialized = true
		if not initialized:
			continue
		var span := maxf(bounds.size.x, bounds.size.z)
		if span > best_span:
			best = bounds
			best_span = span
	return best


func _write_manifest() -> void:
	var manifest := {"world_seed": _world_seed,
		"requested_route_attempt": _attempt,
		"generation_signature": _built.deterministic_signature(),
		"audit": _built.audit, "captures": _captures,
		"selection_diagnostic":
			WarrenBuiltTownSolver.last_selection_diagnostic,
		"candidate_failure_diagnostic":
			WarrenBuiltTownSolver.last_candidate_failure_diagnostic,
		"infill_variant_diagnostic":
			WarrenBuiltTownSolver.last_infill_variant_diagnostic,
		"review_instruction": "Finding a real issue is a successful review."}
	var file := FileAccess.open("%s/manifest-%03d.json" % [_output_dir,
		_world_seed], FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(manifest, "  "))
	file.close()


static func _v3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
