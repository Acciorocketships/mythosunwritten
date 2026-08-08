extends Node3D

## Diagnostic preview of a mass-first town BEFORE the visual-selection gate.
##
## The ordinary review harness renders only towns that survive every gate.
## Mass-first towns currently seal a complete detailed fabric and are then
## rejected for overhead coverage, so nothing renders — which leaves the one
## question that matters unanswerable: does an excavated town actually look
## like a bounded warren? This harness compiles the same assets and fabric the
## built-town solver would, stopping before selection, so the geometry can be
## judged by eye. It proves nothing about acceptance and must never be used to
## claim a town passes.
##
##   Godot --path . res://tests/harness/warren_mass_first_preview.tscn -- \
##     --seed 3 --output DIR
const VIEW_COUNT := 4

var _output_dir := "/tmp/mythos-mass-first-preview"
var _world_seed := 3
var _camera := Camera3D.new()
var _fabric: SettlementFabricPlan


func _ready() -> void:
	_read_args()
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(_output_dir)
	_build_environment()
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	assert(program != null)
	WarrenTownSolver.GENERATION_MODE = &"mass_first"
	SettlementFabricPlan.DIAGNOSTIC_ALLOW_CORNER_ENVELOPE_OVERLAP = true
	var towns := WarrenTownSolver.ranked_candidates(_world_seed, {}, program, 4)
	if towns.is_empty():
		printerr("[mass_first_preview] seed=%d has no ranked candidate: %s" % [
			_world_seed, WarrenTownSolver.last_failure])
		get_tree().quit(1)
		return
	for town: WarrenTownPlan in towns:
		var assets := WarrenAssetCompiler.solve(town, program)
		if assets == null:
			continue
		var fabric := WarrenFabricCompiler.solve(assets)
		if fabric != null and fabric.is_sealed():
			_fabric = fabric
			break
	if _fabric == null:
		printerr("[mass_first_preview] seed=%d compiled no sealed fabric: %s" % [
			_world_seed, WarrenFabricCompiler.last_failure])
		get_tree().quit(1)
		return
	_build_ground()
	var root := Node3D.new()
	root.name = "MassFirstPreview"
	add_child(root)
	var committed := SettlementFabricAssembler.commit(root, _fabric, catalog,
		false)
	print("[mass_first_preview] seed=%d instances=%d" % [_world_seed,
		int(committed.instance_count)])
	_report_stone_budget()
	_camera.current = true
	_camera.near = 0.08
	_camera.far = 400.0
	add_child(_camera)
	_capture_all.call_deferred()


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--output" and index + 1 < args.size():
			_output_dir = args[index + 1]
		elif args[index] == "--seed" and index + 1 < args.size():
			_world_seed = int(args[index + 1])


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
	var instance := MeshInstance3D.new()
	instance.name = "Ground"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(160.0, 0.4, 160.0)
	instance.mesh = mesh
	instance.position = Vector3(0.0, -0.2, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("718d50")
	material.roughness = 1.0
	instance.material_override = material
	add_child(instance)


func _capture_all() -> void:
	for unused in 12:
		await get_tree().process_frame
	var bounds := _fabric_bounds()
	var center := bounds.get_center()
	var span := maxf(bounds.size.x, bounds.size.z)
	var views: Array[Dictionary] = [
		{"id": "overview-ne", "position": center + Vector3(span, span * 0.85,
			span), "target": center, "fov": 52.0},
		{"id": "overview-sw", "position": center + Vector3(-span * 0.9,
			span * 0.7, -span), "target": center, "fov": 54.0},
		{"id": "skyline-east", "position": center + Vector3(span * 1.3,
			bounds.size.y * 0.45, 0.0), "target": center, "fov": 46.0},
		{"id": "street-level", "position": center + Vector3(0.0,
			bounds.position.y + 2.0, span * 0.55), "target": center
			+ Vector3(0.0, bounds.position.y + 3.0, 0.0), "fov": 70.0},
	]
	var route_eye := _covered_route_eye()
	if not route_eye.is_empty():
		views.append(route_eye)
	for view: Dictionary in views:
		_camera.fov = float(view.fov)
		_camera.look_at_from_position(view.position as Vector3,
			view.target as Vector3)
		for unused in 3:
			await get_tree().process_frame
		RenderingServer.force_draw()
		await get_tree().process_frame
		var path := "%s/mass-first-seed-%03d-%s.png" % [_output_dir,
			_world_seed, String(view.id)]
		var image := get_viewport().get_texture().get_image()
		assert(image != null and image.save_png(path) == OK)
		print("[mass_first_preview] captured ", path)
	get_tree().quit()


func _report_stone_budget() -> void:
	## The round-3 directive is a quantity ("almost no stone should be
	## visible"), so the harness prints the quantity beside the image: how many
	## rock modules the town draws, split into the plinths this assembler places
	## and the ground storeys the recipes place, and the tallest continuous
	## masonry face anywhere in the payload.
	var whole := SettlementFabricAssembler.payload(_fabric)
	whole.append_from(SettlementFabricAssembler.structural_support_payload(
		_fabric))
	var plinths := SettlementFabricAssembler.terrace_retaining_payload(_fabric)
	var low := SettlementFabricAssembler.low_retaining_payload(_fabric)
	var stone := 0
	for asset_id: StringName in SettlementFabricAssembler.STONE_FACADE_ASSETS:
		stone += int((whole.batches.get(asset_id, {}) as Dictionary).get(
			"transforms", []).size())
	print(("[mass_first_preview] stone modules=%d of %d instances "
		+ "(plinths=%d courts=%d), tallest stone face=%d bands") % [stone,
		whole.instance_count, plinths.instance_count, low.instance_count,
		SettlementFabricAssembler.tallest_stone_stack_bands(whole)])


func _covered_route_eye() -> Dictionary:
	## Standing on the street cell carrying the most mass overhead, looking along
	## the street. The fixed overview cameras cannot answer "is there a path
	## through the city", which is the question this round is judged on.
	if _fabric == null or _fabric.surface_plan == null:
		return {}
	var floors := _fabric.surface_plan.cells_for_kind(
		PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT)
	var retained := _fabric.retained_terrace_cells
	var best := Vector3i(2147483647, 0, 0)
	var best_cover := 0
	for cell: Vector3i in floors:
		var cover := 0
		for band in range(cell.y + 2, cell.y + 10):
			if retained.has(Vector3i(cell.x, band, cell.z)):
				cover += 1
		if cover > best_cover:
			best_cover = cover
			best = cell
	if best.x == 2147483647:
		return {}
	var forward := Vector3.ZERO
	for cell: Vector3i in floors:
		if cell.y != best.y or cell == best:
			continue
		var delta := Vector3(cell - best)
		if delta.length() < 1.5 or delta.length() > 8.0:
			continue
		forward = delta.normalized()
		break
	if forward == Vector3.ZERO:
		forward = Vector3(0.0, 0.0, 1.0)
	var eye := Vector3(best) * FabricRecipe.CELL_SIZE + Vector3(0.0, 1.4, 0.0)
	print("[mass_first_preview] route eye at %s with %d bands overhead" % [
		best, best_cover])
	return {"id": "route-eye", "position": eye,
		"target": eye + forward * 6.0, "fov": 75.0}


func _fabric_bounds() -> AABB:
	var bounds := AABB()
	var first := true
	for placement: Dictionary in _fabric.expanded_placements():
		var origin := (placement.transform as Transform3D).origin
		if first:
			bounds = AABB(origin, Vector3.ZERO)
			first = false
			continue
		bounds = bounds.expand(origin)
	return bounds
