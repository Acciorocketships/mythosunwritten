extends SceneTree
## Plans warren towns on flat ground from (city seed, profile) and renders them
## with kit-built buildings. GUI only.
##   Godot --path . -s res://tests/harness/suntail/kit_town_review.gd -- \
##     --output DIR --cities 1:compact,2:standard [--legacy] [--uniform] \
##     [--views overview,orbit,street,top] [--streets N]
## --legacy renders the old recipe buildings instead of the kit (A/B).
## --uniform uses the old uniform 2x frame instead of the kit-derived frame.
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")

var _out := "user://kit_town_review"
var _jobs: Array = []
var _legacy := false
var _uniform := false
var _views := PackedStringArray(["overview", "orbit", "street", "top"])
var _streets := 6
var _tint_retained := false
var _tint_prefix := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--output": _out = args[i + 1]
			"--legacy": _legacy = true
			"--tint-retained": _tint_retained = true
			"--tint": _tint_prefix = args[i + 1]
			"--uniform": _uniform = true
			"--views": _views = args[i + 1].split(",")
			"--streets": _streets = int(args[i + 1])
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
	ground.position.y = -0.05
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
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	camera.queue_free()


func _run() -> void:
	get_root().size = Vector2i(1600, 900)
	var stage := _stage()
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var cache := EnvironmentRenderCache.new(catalog)
	var frame := Basis.from_scale(Vector3.ONE * 2.0) if _uniform \
		else Basis.from_scale(Vector3(2.0, 1.5, 2.0))
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
		town.transform = Transform3D(frame, Vector3.ZERO)
		stage.add_child(town)
		cache.prepare(payload.asset_ids())
		var queue := FeatureCommitQueue.new(cache)
		queue.enqueue(Vector2i.ZERO, 1, town, payload)
		while queue.pending_count() > 0:
			queue.drain(100000, 100000, 100000)
			await process_frame
		var bounds := _bounds(spatial, frame)
		var centre := bounds.get_center()
		var radius := maxf(bounds.size.x, bounds.size.z) * 0.5
		var tag := "%d_%s" % [seed_value, scale]
		var extent := AABB()
		var any := false
		for asset_id: StringName in payload.asset_ids():
			for t: Transform3D in payload.batches[asset_id].transforms:
				var p := frame * t.origin
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
				var at := town.transform * (mid * FabricRecipe.CELL_SIZE)
				var side := Vector3(step.z, 0, step.x).normalized()
				await _shoot(stage, at + side * 16.0 + Vector3(0, 2.0, 0), at + Vector3(0, 2.0, 0),
					"%s_skywalk%d_side" % [tag, k], 60)
				await _shoot(stage, at + side * 7.0 + Vector3(0, -5.0, 0), at + Vector3(0, 2.5, 0),
					"%s_skywalk%d_below" % [tag, k], 70)
				k += 1
			print("SKYWALKS ", tag, " ", k)
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
