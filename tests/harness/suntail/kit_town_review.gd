extends SceneTree
## Plans warren towns on flat ground from (city seed, profile) and renders them
## with kit-built buildings. GUI only.
##   Godot --path . -s res://tests/harness/suntail/kit_town_review.gd -- \
##     --output DIR --cities 1:compact,2:standard [--legacy] [--uniform] \
##     [--views overview,orbit,street,top] [--streets N]
## --legacy renders the old recipe buildings instead of the kit (A/B).
## --uniform uses a uniform horizontal-scale frame instead of the kit-derived frame.
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")

var _out := "user://kit_town_review"
var _jobs: Array = []
var _legacy := false
var _uniform := false
var _views := PackedStringArray(["overview", "orbit", "street", "top"])
var _streets := 6
var _tint_retained := false
var _tint_prefix := ""
## Drop instances and surface meshes whose stable id begins with this prefix.
var _hide_prefix := ""
## Optional production world frame (12 floats: basis x, y, z columns, origin)
## so a flat-ground town sits exactly where it stands in-world.
var _world_frame := Transform3D()
var _has_world_frame := false
var _ground_y := -0.05
## Extra world-space shots: id:eye:target[:fov].
var _custom_views: Array[Dictionary] = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--output": _out = args[i + 1]
			"--legacy": _legacy = true
			"--tint-retained": _tint_retained = true
			"--tint": _tint_prefix = args[i + 1]
			"--hide": _hide_prefix = args[i + 1]
			"--uniform": _uniform = true
			"--views": _views = args[i + 1].split(",")
			"--streets": _streets = int(args[i + 1])
			"--frame":
				var f := args[i + 1].split(",")
				_world_frame = Transform3D(Basis(Vector3(float(f[0]), float(f[1]), float(f[2])),
					Vector3(float(f[3]), float(f[4]), float(f[5])),
					Vector3(float(f[6]), float(f[7]), float(f[8]))),
					Vector3(float(f[9]), float(f[10]), float(f[11])))
				_has_world_frame = true
			"--ground-y": _ground_y = float(args[i + 1])
			"--view":
				var parts := args[i + 1].split(":")
				var e := parts[1].split(",")
				var t := parts[2].split(",")
				_custom_views.append({"id": parts[0],
					"eye": Vector3(float(e[0]), float(e[1]), float(e[2])),
					"target": Vector3(float(t[0]), float(t[1]), float(t[2])),
					"fov": float(parts[3]) if parts.size() > 3 else 70.0})
			"--cities":
				for job in args[i + 1].split(","):
					var parts := job.split(":")
					_jobs.append([int(parts[0]), StringName(parts[1])])
	if _jobs.is_empty():
		_jobs = [[1, &"compact"]]
	DirAccess.make_dir_recursive_absolute(_out)
	call_deferred("_run")


func _stage() -> Node3D:
	var stage := Node3D.new()
	get_root().add_child(stage)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.27, 0.46, 0.75)
	sky_material.sky_horizon_color = Color(0.71, 0.82, 0.92)
	sky_material.ground_bottom_color = Color(0.42, 0.5, 0.56)
	sky_material.ground_horizon_color = Color(0.68, 0.78, 0.86)
	var sky := Sky.new()
	sky.sky_material = sky_material
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.6, 0.55)
	e.ambient_light_sky_contribution = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	env.environment = e
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.7
	sun.directional_shadow_max_distance = 250.0
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1200, 1200)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.36, 0.52, 0.24)
	ground.material_override = material
	ground.position = Vector3(_world_frame.origin.x, _ground_y, _world_frame.origin.z) \
		if _has_world_frame else Vector3(0.0, _ground_y, 0.0)
	stage.add_child(ground)
	return stage


static func town_payload(spatial: WarrenSpatialPlan, fabric: SettlementFabricPlan,
		legacy: bool) -> EnvironmentInstancePayload:
	var payload: EnvironmentInstancePayload
	if legacy:
		payload = SettlementFabricAssembler.payload(fabric)
	else:
		var built := KitVillageBuildings.build(spatial, fabric, SuntailBuildingKit.create())
		print("ROOF_AUDIT ", built.roof_audit)
		payload = KitVillageBuildings.legacy_payload_without(fabric, built.replaced_units)
		payload.append_from(built.payload)
	payload.append_from(SettlementFabricAssembler.production_surface_bundle(
		fabric.surface_plan, SettlementFabricAssembler.maze_module_footprints(fabric),
		SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),
		fabric.planned_plaza_cells))
	payload.append_from(SettlementFabricAssembler.low_retaining_payload(fabric))
	var terrace := SettlementFabricAssembler.terrace_retaining_payload(fabric, false)
	if not legacy:
		terrace = KitVillageBuildings.without_prefixes(terrace,
			KitVillageBuildings.REPLACED_TERRACE_PREFIXES)
	payload.append_from(terrace)
	if not legacy:
		payload = KitSubstitution.apply(payload)
	return payload


func _shoot(stage: Node3D, eye: Vector3, target: Vector3, name: String,
		fov := 55.0) -> void:
	var camera := Camera3D.new()
	camera.fov = fov
	camera.far = 2000.0
	stage.add_child(camera)
	camera.look_at_from_position(eye, target)
	camera.current = true
	for i in 8:
		await process_frame
	RenderingServer.force_draw(false)
	get_root().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	camera.queue_free()


func _run() -> void:
	get_root().size = Vector2i(1600, 900)
	var stage := _stage()
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var cache := EnvironmentRenderCache.new(catalog)
	var frame := Basis.from_scale(Vector3.ONE * VillageWorldScale.HORIZONTAL_SCALE) if _uniform \
		else Basis.from_scale(VillageWorldScale.frame_scale())
	for job: Array in _jobs:
		var seed_value: int = job[0]
		var scale: StringName = job[1]
		var profile := WarrenVillageScaleProfile.for_id(scale)
		var started := Time.get_ticks_msec()
		var source := WarrenMazeSitePlanner.plan(seed_value, {}, profile, &"", false)
		if source == null:
			print("PLAN_FAIL ", seed_value, " ", scale)
			continue
		print("TUNNELS ", seed_value, " ", scale, " ", source.excavation.tunnel_cells.keys())
		var spatial := FROZEN.spatial(source, program)
		var fabric := spatial.compiled_fabric_cache()
		var payload := town_payload(spatial, fabric, _legacy)
		if not _hide_prefix.is_empty():
			payload = KitVillageBuildings.without_prefixes(payload, [_hide_prefix] as Array[String])
		if not _tint_prefix.is_empty():
			for asset_id: StringName in payload.asset_ids():
				var batch: Dictionary = payload.batches[asset_id]
				for index in batch.ids.size():
					if String(batch.ids[index]).begins_with(_tint_prefix):
						batch.colors[index] = Color(1.0, 0.1, 0.1)
		if _tint_retained:
			for asset_id: StringName in payload.asset_ids():
				var batch: Dictionary = payload.batches[asset_id]
				for index in batch.ids.size():
					if String(batch.ids[index]).begins_with("kit.retained"):
						batch.colors[index] = Color(1.0, 0.3, 0.3)
		print("TOWN ", seed_value, " ", scale, " buildings=", spatial.buildings.size(),
			" instances=", payload.instance_count, " ms=", Time.get_ticks_msec() - started)
		var town := Node3D.new()
		town.transform = _world_frame if _has_world_frame else Transform3D(frame, Vector3.ZERO)
		if _has_world_frame:
			frame = _world_frame.basis
		stage.add_child(town)
		cache.prepare(payload.asset_ids())
		var queue := FeatureCommitQueue.new(cache)
		queue.enqueue(Vector2i.ZERO, 1, town, payload)
		while queue.pending_count() > 0:
			queue.drain(100000, 100000, 100000)
			await process_frame
		for view: Dictionary in _custom_views:
			await _shoot(stage, view.eye, view.target, "%d_%s_%s" % [seed_value, scale, view.id], view.fov)
		var bounds := _bounds(spatial, frame)
		var centre := bounds.get_center()
		var radius := maxf(bounds.size.x, bounds.size.z) * 0.5
		var tag := "%d_%s" % [seed_value, scale]
		var extent := AABB()
		var any := false
		for asset_id: StringName in payload.asset_ids():
			for t: Transform3D in payload.batches[asset_id].transforms:
				var p := town.transform * t.origin
				extent = AABB(p, Vector3.ZERO) if not any else extent.expand(p)
				any = true
		print("BOUNDS cells=", bounds, " payload=", extent)
		bounds = extent
		centre = bounds.get_center()
		radius = maxf(bounds.size.x, bounds.size.z) * 0.5
		if _views.has("overview"):
			await _shoot(stage, centre + Vector3(-radius * 1.1, radius * 1.0, radius * 1.5),
				centre, "%s_overview" % tag, 50)
		if _views.has("orbit"):
			for k in 4:
				var angle := PI * 0.25 + PI * 0.5 * float(k)
				var eye := centre + Vector3(cos(angle), 0, sin(angle)) * radius * 1.25 \
					+ Vector3(0, radius * 0.45, 0)
				await _shoot(stage, eye, centre + Vector3(0, 4, 0), "%s_orbit%d" % [tag, k], 55)
		if _views.has("edge"):
			# The town's outside from the lawn, eight bearings (perimeter review).
			for k in 8:
				var angle := PI * 0.125 + PI * 0.25 * float(k)
				var eye := centre + Vector3(cos(angle), 0, sin(angle)) * radius * 1.9
				eye.y = bounds.position.y + 7.0
				await _shoot(stage, eye, Vector3(centre.x, bounds.position.y + 10.0, centre.z),
					"%s_edge%d" % [tag, k], 60)
		if _views.has("far"):
			# Photo-11-like: a walker on a rise ~2 town radii away. Framed on
			# the massif footprint (not the payload), so before/after runs of
			# one town share their cameras exactly.
			var lo := Vector2(1e9, 1e9)
			var hi := Vector2(-1e9, -1e9)
			for column: Vector2i in source.massif.columns:
				lo = lo.min(Vector2(column))
				hi = hi.max(Vector2(column) + Vector2.ONE)
			var mid := town.transform * (Vector3((lo.x + hi.x), 0.0, (lo.y + hi.y)) * FabricRecipe.CELL_SIZE)
			var reach := (town.transform.basis * Vector3((hi.x - lo.x) * FabricRecipe.CELL_SIZE, 0, 0)).length()
			for k in 4:
				var angle := PI * 0.2 + PI * 0.5 * float(k)
				var eye := mid + Vector3(cos(angle), 0, sin(angle)) * reach * 1.9
				eye.y = mid.y + 20.0
				await _shoot(stage, eye, mid + Vector3.UP * 10.0, "%s_far%d" % [tag, k], 32)
		if _views.has("lane"):
			# Street-level views along each perimeter lane (September 29 edges).
			var shots := 0
			for lane: Dictionary in source.excavation.lanes:
				if StringName(lane.get("feature_kind", &"")) != &"perimeter" or shots >= 6:
					continue
				var walk: Array = [lane.anchor]
				walk.append_array(lane.cells)
				if walk.size() < 3:
					continue
				var centre_of := func(c: Vector3i) -> Vector3:
					return town.transform * Vector3((c.x * 2 + 1) * FabricRecipe.CELL_SIZE,
						c.y * WarrenVolumePlan.VERTICAL_BAND_SIZE_M,
						(c.z * 2 + 1) * FabricRecipe.CELL_SIZE)
				# From the lane's first cell along its longest straight run.
				var step: Vector3i = walk[1] - walk[0]
				var end := 1
				while end + 1 < walk.size() and walk[end + 1] - walk[end] == step:
					end += 1
				var from: Vector3 = centre_of.call(walk[0])
				var ahead: Vector3 = centre_of.call(walk[end])
				var along := (ahead - from).normalized()
				await _shoot(stage, from - along * 2.0 + Vector3.UP * 1.8,
					from + along * 30.0 + Vector3.UP * 2.0,
					"%s_lane%d" % [tag, shots], 70)
				shots += 1
		if _views.has("top"):
			await _shoot(stage, centre + Vector3(0.01, radius * 2.4, 0), centre,
				"%s_top" % tag, 50)
		if _views.has("street"):
			var cells := spatial.route_floor_cells.duplicate()
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			for k in mini(_streets, cells.size()):
				var cell: Vector3i = cells[rng.randi_range(0, cells.size() - 1)]
				var eye_local := Vector3(cell) * FabricRecipe.CELL_SIZE + Vector3(0, 1.1, 0)
				var eye := town.transform * eye_local + Vector3(0, 1.0, 0)
				# Look down the route: at a walk cell 4-10 cells away on the same level.
				var target := eye + Vector3(12.0, 0.0, 0.0)
				var best := -1.0
				for other: Vector3i in cells:
					var d := Vector2(other.x - cell.x, other.z - cell.z).length()
					if other.y == cell.y and d >= 4.0 and d <= 10.0:
						var score := rng.randf()
						if score > best:
							best = score
							target = town.transform * (Vector3(other) * FabricRecipe.CELL_SIZE) \
								+ Vector3(0, 2.2, 0)
				await _shoot(stage, eye, target, "%s_street%d" % [tag, k], 70)
		if _views.has("skywalk"):
			var k := 0
			for span: Dictionary in SettlementFabricAssembler.maze_skywalk_spans(fabric):
				var c := span.cell as Vector3i
				var step := span.step as Vector3i
				var mid := Vector3(c + step) + Vector3(step) * (float(span.gap) - 1.0) * 0.5
				if int(span.get("width", 1)) == 2:
					mid += Vector3(span.cross as Vector3i) * 0.5
				var at := town.transform * (mid * FabricRecipe.CELL_SIZE)
				var side := (town.transform.basis * Vector3(step.z, 0, step.x)).normalized()
				var street_y := town.transform.origin.y + 1.7
				await _shoot(stage, at + side * 26.0 + Vector3(0, 3.0, 0), at + Vector3(0, 3.0, 0),
					"%s_skywalk%d_side" % [tag, k], 60)
				await _shoot(stage, Vector3(at.x, street_y, at.z) + side * 12.0, at + Vector3(0, 2.5, 0),
					"%s_skywalk%d_below" % [tag, k], 70)
				await _shoot(stage, at + Vector3(0.01, 30.0, 0.0), at, "%s_skywalk%d_top" % [tag, k], 50)
				var along := town.transform.basis * Vector3(step)
				along = Vector3(along.x, 0.0, along.z).normalized()
				for sign: float in [-1.0, 1.0]:
					await _shoot(stage, at - along * 22.0 * sign + side * 6.0 + Vector3(0, 4.0, 0),
						at + Vector3(0, 2.5, 0), "%s_skywalk%d_along%d" % [tag, k, int(sign)], 70)
				k += 1
			print("SKYWALKS ", tag, " ", k)
		if _views.has("props"):
			# Human-scale props beside a player-sized capsule (2.244 m).
			var shots := 0
			for asset_id: StringName in payload.asset_ids():
				var id := String(asset_id)
				if not (id.begins_with("suntail.prop.") or id.begins_with("lpfv.fabric.prop.")):
					continue
				if id.contains("shop") or id.contains("well") or id.contains("bonfire") or id.contains("case_and_food"):
					continue
				var batch: Dictionary = payload.batches[asset_id]
				if batch.transforms.is_empty() or shots >= 8:
					continue
				var t: Transform3D = town.transform * (batch.transforms[0] as Transform3D)
				var capsule := MeshInstance3D.new()
				var mesh := CapsuleMesh.new()
				mesh.radius = TraversalEnvelope.CAPSULE_RADIUS
				mesh.height = TraversalEnvelope.CAPSULE_HEIGHT
				capsule.mesh = mesh
				var side := Vector3(t.basis.x.x, 0.0, t.basis.x.z).normalized()
				capsule.position = t.origin + side * 1.4 + Vector3.UP * mesh.height * 0.5
				stage.add_child(capsule)
				var toward := Vector3(t.basis.z.x, 0.0, t.basis.z.z).normalized()
				var at := t.origin + side * 0.7 + Vector3.UP * 1.0
				await _shoot(stage, at + toward * 6.0 + Vector3.UP * 1.5, at,
					"%s_props%d_%s" % [tag, shots, id.get_file()], 50)
				capsule.queue_free()
				shots += 1
		if _views.has("canopy"):
			# Every porch canopy from its front quarter, looking at its posts.
			var batch: Dictionary = payload.batches.get(&"suntail.decor.wooden_canopy_1", {})
			var shots := mini(8, batch.get("transforms", []).size())
			for k in shots:
				var t: Transform3D = town.transform * (batch.transforms[k] as Transform3D)
				var out := Vector3(t.basis.z.x, 0.0, t.basis.z.z).normalized()
				var side := Vector3(t.basis.x.x, 0.0, t.basis.x.z).normalized()
				var at := t.origin + out * 1.5 + Vector3.UP * 2.0
				await _shoot(stage, at + out * 4.5 + side * 1.5 + Vector3.UP * 4.0, at,
					"%s_canopy%d" % [tag, k], 75)
			print("CANOPIES ", tag, " ", batch.get("transforms", []).size())
		if _views.has("passage"):
			# Street-level views walking into each bored tunnel or under each
			# bridge-house: camera on the open street two cells before the
			# covered run, looking along the walk.
			var covered: Dictionary = source.excavation.tunnel_cells.duplicate()
			for span: Array in source.excavation.bridge_spans:
				for cell: Vector3i in span:
					covered[cell] = true
			var walks: Array = [source.excavation.route]
			for lane: Dictionary in source.excavation.lanes:
				var walk: Array = [lane.anchor]
				walk.append_array(lane.cells)
				walks.append(walk)
			var shots := 0
			for walk: Array in walks:
				for i in range(2, walk.size()):
					if shots >= 6 or not covered.has(walk[i]) or covered.has(walk[i - 1]):
						continue
					var from: Vector3i = walk[i - 1]
					var to: Vector3i = walk[i]
					var cell_centre := func(c: Vector3i) -> Vector3:
						return town.transform * Vector3((c.x * 2 + 1) * FabricRecipe.CELL_SIZE,
							c.y * WarrenVolumePlan.VERTICAL_BAND_SIZE_M,
							(c.z * 2 + 1) * FabricRecipe.CELL_SIZE)
					var along: Vector3 = (cell_centre.call(to) - cell_centre.call(from)) * Vector3(1, 0, 1)
					var eye: Vector3 = cell_centre.call(from) - along * 0.9 + Vector3.UP * 1.7
					var target: Vector3 = cell_centre.call(to) + along * 0.5 + Vector3.UP * 2.0
					await _shoot(stage, eye, target, "%s_passage%d" % [tag, shots], 75)
					shots += 1
			print("PASSAGES ", tag, " ", shots, " covered=", covered.size())
		if _views.has("platform"):
			await _shoot_platform(stage, source, town, tag)
		if _views.has("tunnel"):
			var index := 0
			for cell: Vector3i in source.excavation.tunnel_cells:
				var at := town.transform * (Vector3(cell.x * 2 + 0.5, cell.y, cell.z * 2 + 0.5) * FabricRecipe.CELL_SIZE)
				for step: Vector3i in [Vector3i.RIGHT, Vector3i.BACK]:
					if cell + step not in source.excavation.public_cells(): continue
					var direction := Vector3(step)
					await _shoot(stage, at - direction * 7 + Vector3.UP * 2.0,
						at + direction * 4 + Vector3.UP * 2.7, "%s_tunnel%d" % [tag, index], 70)
					index += 1

		town.queue_free()
		await process_frame
	print("REVIEW_DONE ", _out)
	quit()


## Raised district (WarrenTownPlatform) review: four distant views onto the
## citadel, one street-level view along each face of its plinth from the wall
## street, and two up the gate flight and through the gate.
func _shoot_platform(stage: Node3D, source: WarrenMazeSourcePlan, town: Node3D,
		tag: String) -> void:
	var massif := source.massif
	var columns := massif.platform_columns()
	if columns.is_empty():
		print("PLATFORM ", tag, " none")
		return
	var at := func(column: Vector2, band: float) -> Vector3:
		return town.transform * Vector3((column.x * 2.0 + 1.0) * FabricRecipe.CELL_SIZE,
			band * WarrenVolumePlan.VERTICAL_BAND_SIZE_M,
			(column.y * 2.0 + 1.0) * FabricRecipe.CELL_SIZE)
	var sum := Vector2.ZERO
	for column: Vector2i in columns:
		sum += Vector2(column)
	var centre: Vector2 = sum / float(columns.size())
	var bearing := float(massif.bearing_at(columns[0]))
	var middle: Vector3 = at.call(centre, bearing)
	var k := 0
	for direction: Vector2 in [Vector2(1, 0.35), Vector2(-0.35, 1), Vector2(-1, -0.35),
			Vector2(0.35, -1)]:
		var far: Vector3 = at.call(centre + direction.normalized() * 9.0, bearing + 7.0)
		await _shoot(stage, far, middle, "%s_platform_far%d" % [tag, k], 55)
		k += 1
	# Along the lane at the plinth's foot: one view per face, standing on a
	# ground street beside the wall and looking along it.
	var shot_faces: Dictionary = {}
	var cells: Array = source.passage_kinds.keys()
	cells.sort()
	for cell: Vector3i in cells:
		var column := Vector2i(cell.x, cell.z)
		if massif.is_platform(column) or cell.y != massif.base_at(column):
			continue
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			if shot_faces.has(direction) or not massif.is_platform(column + direction):
				continue
			shot_faces[direction] = true
			var tangent := Vector2(-direction.y, direction.x)
			var base := float(cell.y)
			var plinth := float(massif.plinth_at(column + direction))
			var eye: Vector3 = at.call(Vector2(column) - Vector2(direction) * 0.8
				- tangent * 0.6, base) + Vector3.UP * 1.7
			var target: Vector3 = at.call(Vector2(column) + tangent * 4.0
				+ Vector2(direction) * 0.4, base + plinth * 1.6)
			await _shoot(stage, eye, target, "%s_platform_wall%d" % [tag, shot_faces.size() - 1], 80)
			# The same face from over the lower town's roofs (the huddle
			# keeps them under the plinth top), three columns out.
			await _shoot(stage, at.call(Vector2(column) - Vector2(direction) * 3.0
				- tangent * 1.5, base + plinth + 1.5),
				at.call(Vector2(column) + Vector2(direction) + tangent * 1.5, base + plinth * 0.6),
				"%s_platform_face%d" % [tag, shot_faces.size() - 1], 60)
	# The gate: up the flight along the wall, then straight at the gate.
	for lane: Dictionary in source.excavation.lanes:
		if StringName(lane.get("feature_kind", &"")) != &"citadel_gate":
			continue
		var walk: Array = [lane.anchor]
		walk.append_array(lane.cells)
		var gate: Vector3i = walk.back()
		var landing: Vector3i = walk[walk.size() - 2]
		var foot: Vector3i = walk[0]
		var step := Vector2(landing.x - gate.x, landing.z - gate.z)
		await _shoot(stage, at.call(Vector2(foot.x, foot.z), float(foot.y)) + Vector3.UP * 1.7,
			at.call(Vector2(gate.x, gate.z), float(gate.y)) + Vector3.UP * 3.0,
			"%s_platform_gate_flight" % tag, 70)
		await _shoot(stage, at.call(Vector2(landing.x, landing.z) + step * 1.2,
			float(landing.y)) + Vector3.UP * 1.7,
			at.call(Vector2(gate.x, gate.z) - step, float(gate.y)) + Vector3.UP * 2.5,
			"%s_platform_gate" % tag, 70)
		# The gate from over the lower town's roofs, straight on.
		await _shoot(stage, at.call(Vector2(gate.x, gate.z) + step * 4.0,
			float(gate.y) + 1.5),
			at.call(Vector2(gate.x, gate.z), float(gate.y)) + Vector3.UP * 1.5,
			"%s_platform_gate_out" % tag, 55)
		break
	print("PLATFORM ", tag, " columns=", columns.size(), " plinth=", massif.platform_bands)


func _bounds(spatial: WarrenSpatialPlan, frame: Basis) -> AABB:
	var box := AABB()
	var first := true
	for building: WarrenBuildingVolume in spatial.buildings:
		for cell: Vector3i in building.private_cells:
			var p := frame * (Vector3(cell) * FabricRecipe.CELL_SIZE)
			if first:
				box = AABB(p, Vector3.ZERO)
				first = false
			else:
				box = box.expand(p)
	return box
