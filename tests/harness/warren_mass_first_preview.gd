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
##
## TERRAIN MODE (default since Wave 2 of the terrain milestone). The flat olive
## slab this harness used to stand the town on is gone: the town is now rendered
## ON the settlement relief stamp, meshed by the REAL production mesher. The
## chain is the production one --
##
##   TerrainWorldTuning.make_water / make_relief / make_heightfield
##     -> HeightfieldPlan.compute_region   (the stamp lands inside _sample)
##     -> TerrainChunkMesher.build_chunk   (surface + aprons + KayKit cliff
##                                          dressing + collision)
##     -> VillageTerrainView -> ground bands -> the mass-first solver
##
## so the grass sheet, the cliff dressing and the collision in the image are the
## world's own, not the harness's. `--flat-ground` restores the slab for A/B.
##
## SHORTCUTS, named so nothing here is mistaken for production:
##  1. The town is PLACED by this harness -- column (0,0) is pinned to the
##     settlement cell and the fabric datum to the lowest sampled surface under
##     the footprint. Production placement (VillageWarrenFabricSolver, four
##     quarter-turn candidates, MAX_FABRIC_TERRAIN_RELIEF) is Wave 6, and the
##     4.5 m relief gate would refuse most real sites today.
##  2. No FeatureContext and no WaterFieldContext are supplied to the mesher, so
##     WORN_PATH dirt paint and shoreline banks do not appear. Both are Wave 5/6
##     concerns and neither changes the landform.
##  3. Dense grass (GrassField) is not instanced; the terrain sheet carries the
##     grass texture the mesher gives it.
##  4. `--site origin` puts the settlement at the world origin, inside the spawn
##     falloff where natural ground is flat, to isolate pure STAMP mode. The
##     default `--site production` uses the seed's real SettlementPlan site and
##     therefore its real natural relief.
const VIEW_COUNT := 4

var _output_dir := "/tmp/mythos-mass-first-preview"
var _world_seed := 3
var _detail := true
var _terrain := true
var _production_site := true
var _camera := Camera3D.new()
var _fabric: SettlementFabricPlan
var _town_origin := Vector3.ZERO
var _ground_bands: Dictionary = {}


## `--site origin`: one settlement at the world origin, where the spawn falloff
## flattens natural ground, so a render isolates pure STAMP mode from whatever
## relief the seed's real site happens to carry. Duck-typed on site_for, the one
## method SettlementReliefPlan asks a site source for.
class OriginSite:
	extends RefCounted

	func site_for(super_cell: Vector2i) -> Dictionary:
		if super_cell != Vector2i.ZERO:
			return {}
		return {"id": &"preview.origin", "cell": Vector2i.ZERO}


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
	if _terrain:
		_build_terrain()
	else:
		_build_ground()
	_solve_fabric(program)
	if _fabric == null:
		get_tree().quit(1)
		return
	var root := Node3D.new()
	root.name = "MassFirstPreview"
	root.position = _town_origin
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


func _solve_fabric(program: SettlementFabricProgram) -> void:
	## DETAIL MODE (default): run the whole WarrenBuiltTownSolver pipeline, so
	## the render shows the skywalks, outcrops, markets, prefab anchors and
	## style breadth the detail phases build. Compiling only the parcel fabric
	## -- what this harness used to do -- skips all of that and makes the town
	## look far duller and more repetitive than the pipeline actually is.
	##
	## The best-effort fabric is drawn EVEN WHEN the visual-selection gates
	## reject it, with the refusals printed. This proves nothing about
	## acceptance and must never be quoted as a town passing.
	if _detail:
		var attempt := WarrenBuiltTownSolver.diagnostic_best_effort(_world_seed,
			program, _ground_bands)
		_fabric = attempt.get("fabric") as SettlementFabricPlan
		if _fabric != null:
			print("[mass_first_preview] seed=%d detail mode: %s, %d detail %s" % [
				_world_seed,
				"SELECTED" if bool(attempt.selected) else "REJECTED BY GATES",
				int(attempt.detail_count), "candidates admitted"])
			for failure: String in attempt.gate_failures as PackedStringArray:
				print("[mass_first_preview]   gate refusal: ", failure)
			return
		printerr("[mass_first_preview] seed=%d reached no detailed fabric: %s" % [
			_world_seed, WarrenBuiltTownSolver.last_failure])
	var towns := WarrenTownSolver.ranked_candidates(_world_seed, _ground_bands,
		program, 4)
	if towns.is_empty():
		printerr("[mass_first_preview] seed=%d has no ranked candidate: %s" % [
			_world_seed, WarrenTownSolver.last_failure])
		_solve_ungated(program)
		return
	for town: WarrenTownPlan in towns:
		var assets := WarrenAssetCompiler.solve(town, program)
		if assets == null:
			continue
		var fabric := WarrenFabricCompiler.solve(assets)
		if fabric != null and fabric.is_sealed():
			_fabric = fabric
			return
	printerr("[mass_first_preview] seed=%d compiled no sealed fabric: %s" % [
		_world_seed, WarrenFabricCompiler.last_failure])


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--output" and index + 1 < args.size():
			_output_dir = args[index + 1]
		elif args[index] == "--seed" and index + 1 < args.size():
			_world_seed = int(args[index + 1])
		elif args[index] == "--no-detail":
			_detail = false
		elif args[index] == "--flat-ground":
			_terrain = false
		elif args[index] == "--site" and index + 1 < args.size():
			_production_site = args[index + 1] != "origin"


func _solve_ungated(program: SettlementFabricProgram) -> void:
	## LAST-RESORT DIAGNOSTIC, and the loudest one in this file. It composes a
	## parcel plan that WarrenTownSolver._passes_construction_gate REFUSED, so
	## the image it produces is of a town the pipeline does not admit. It exists
	## because the buildable-layer wave left mass-first composition failing on
	## every stamped seed at that gate -- a pre-existing mass-first weakness the
	## acceptance wave owns -- and "no picture at all" is a worse answer to
	## "what does the thin layer look like" than "a picture of a refused town,
	## labelled as one".
	##
	## NEVER quote an image from this path as a town passing anything.
	for volume: WarrenVolumePlan in WarrenTownSolver.mass_first_frontier(
			_world_seed, _ground_bands):
		for parcels: WarrenParcelPlan in WarrenTownSolver._parcel_variants(
				volume, program):
			var town := WarrenTownSolver._compose_plan(_world_seed, volume,
				parcels)
			if town == null:
				print("[mass_first_preview]   ungated compose: %s"
					% WarrenTownSolver.last_failure)
				continue
			var assets := WarrenAssetCompiler.solve(town, program)
			if assets == null:
				print("[mass_first_preview]   ungated assets: %s"
					% WarrenAssetCompiler.last_failure)
				continue
			var fabric := WarrenFabricCompiler.solve(assets)
			if fabric == null:
				print("[mass_first_preview]   ungated fabric: %s"
					% WarrenFabricCompiler.last_failure)
				continue
			_fabric = fabric
			print(("[mass_first_preview] seed=%d UNGATED DIAGNOSTIC: this town "
				+ "was REFUSED by the construction gate and is drawn anyway "
				+ "(parcels=%d contact=%.2f families=%d)") % [_world_seed,
				int(parcels.audit.parcel_count),
				float(parcels.audit.get(
					"largest_building_contact_component_cell_ratio", 0.0)),
				int(parcels.audit.footprint_family_count)])
			return
	printerr("[mass_first_preview] seed=%d: even the ungated diagnostic "
		% _world_seed + "reached no fabric")


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


func _build_terrain() -> void:
	## The real terrain stack, on the main thread, over the chunks the town and
	## its hill occupy. Both halves of the mesher are already separated at the
	## worker/main-thread boundary (compute_chunk is pure CPU, commit_chunk owns
	## every resource), and build_chunk is the documented offline wrapper around
	## the pair -- so nothing here reaches for a stub, and the cliff dressing,
	## the aprons and the collision are the ones the streamed world builds.
	var water := TerrainWorldTuning.make_water(_world_seed)
	var settlements := SettlementPlan.new(_world_seed, water)
	var relief: SettlementReliefPlan = null
	if _production_site:
		relief = TerrainWorldTuning.make_relief(_world_seed, water, settlements)
	elif SettlementReliefPlan.is_active():
		relief = SettlementReliefPlan.new(_world_seed, OriginSite.new(),
			TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE,
			TerrainWorldTuning.HEIGHTFIELD_MAX_STOREYS)
	if relief == null:
		printerr("[mass_first_preview] no relief stamp: mass-first is not the "
			+ "active generation mode")
		return
	var site := _site_cell(settlements)
	var plan := TerrainWorldTuning.make_heightfield(_world_seed, water, relief)
	var mesher := TerrainChunkMesher.new()
	mesher.set_seed(_world_seed)
	mesher.prepare_resources()
	var reach := relief.outer_radius_metres() + 24.0
	var centre := Vector2(float(site.x), float(site.y)) * TerrainSurfaceField.TILE
	var chunk_lo := Vector2i(
		int(floor((centre.x - reach) / TerrainChunkMesher.CHUNK_WORLD)),
		int(floor((centre.y - reach) / TerrainChunkMesher.CHUNK_WORLD)))
	var chunk_hi := Vector2i(
		int(floor((centre.x + reach) / TerrainChunkMesher.CHUNK_WORLD)),
		int(floor((centre.y + reach) / TerrainChunkMesher.CHUNK_WORLD)))
	var terrain := Node3D.new()
	terrain.name = "Terrain"
	add_child(terrain)
	var chunks := 0
	for cz in range(chunk_lo.y, chunk_hi.y + 1):
		for cx in range(chunk_lo.x, chunk_hi.x + 1):
			terrain.add_child(mesher.build_chunk(plan, Vector2i(cx, cz)))
			chunks += 1
	var region := plan.compute_region(site.x, site.y,
		TerrainChunkMesher.CELLS_PER_CHUNK)
	var sample := _sample_ground_bands(VillageTerrainView.from_region(region),
		centre)
	_ground_bands = sample.bands
	# Column (0, 0) of the massif sits at the settlement cell centre, and band 0
	# at the lowest surface under the footprint -- the same two facts the band
	# dictionary was built from, so the town lands exactly on the ground it was
	# solved against.
	_town_origin = Vector3(centre.x - FabricRecipe.CELL_SIZE * 0.5,
		float(sample.datum), centre.y - FabricRecipe.CELL_SIZE * 0.5)
	print(("[mass_first_preview] terrain seed=%d site=%s chunks=%d "
		+ "relief_budget=%.1fm stamp_radius=%.0fm bands=%d..%d "
		+ "sampled_relief=%.1fm ceiling_clamped=%s") % [_world_seed, str(site),
		chunks, relief.budget_metres(), relief.outer_radius_metres(),
		int(sample.lowest_band), int(sample.highest_band),
		float(sample.highest) - float(sample.datum),
		str(relief.ceiling_clamped)])


func _site_cell(settlements: SettlementPlan) -> Vector2i:
	if not _production_site:
		return Vector2i.ZERO
	for ring in 3:
		for sz in range(-ring, ring + 1):
			for sx in range(-ring, ring + 1):
				var site: Dictionary = settlements.site_for(Vector2i(sx, sz))
				if not site.is_empty():
					return site["cell"]
	printerr("[mass_first_preview] no settlement site near the origin; "
		+ "falling back to the origin cell")
	return Vector2i.ZERO


func _sample_ground_bands(terrain: VillageTerrainView,
		centre: Vector2) -> Dictionary:
	## VillageWarrenFabricSolver._sample_ground_bands with this harness's own
	## frame: five probes per 3 m column, ceil of the column maximum, datum at
	## the lowest surface under the footprint so every band is >= 0.
	var span := WarrenMassifBuilder.RADIUS_CELLS + 1
	var half := WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M * 0.45
	var maxima: Dictionary = {}
	var lowest := INF
	var highest := -INF
	for z in range(-span, span + 1):
		for x in range(-span, span + 1):
			var point := centre + Vector2(
				float(x) * WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M,
				float(z) * WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M)
			var column_max := -INF
			for offset: Vector2 in [Vector2.ZERO,
					Vector2(-half, -half), Vector2(half, -half),
					Vector2(-half, half), Vector2(half, half)]:
				var height := terrain.surface_y(point + offset)
				column_max = maxf(column_max, height)
				lowest = minf(lowest, height)
				highest = maxf(highest, height)
			maxima[Vector2i(x, z)] = column_max
	var bands: Dictionary = {}
	var lowest_band := 2147483647
	var highest_band := -2147483648
	for column: Vector2i in maxima:
		var value := ceili((float(maxima[column]) - lowest)
			/ WarrenVolumePlan.VERTICAL_BAND_SIZE_M)
		bands[column] = value
		lowest_band = mini(lowest_band, value)
		highest_band = maxi(highest_band, value)
	return {"bands": bands, "datum": lowest, "highest": highest,
		"lowest_band": lowest_band, "highest_band": highest_band}


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
	bounds.position += _town_origin
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
	var covered := SettlementFabricAssembler.building_ceiling(
		_fabric.transformed_cells(&"solid"))
	print(("[mass_first_preview] stone modules=%d of %d instances "
		+ "(plinth+substrate=%d courts=%d), tallest BARE stone face=%d bands")
		% [stone, whole.instance_count, plinths.instance_count,
		low.instance_count,
		SettlementFabricAssembler.tallest_bare_stone_stack_bands(whole,
			covered)])


func _covered_route_eye() -> Dictionary:
	## Standing on the street cell carrying the most mass overhead, looking along
	## the street. The fixed overview cameras cannot answer "is there a path
	## through the city", which is the question this round is judged on.
	##
	## Overhead mass is the fabric's own SOLID layer -- the rooms and galleries a
	## house puts over a street. It used to be `retained_terrace_cells`, which
	## was correct while the fabric drew the mountain: the mass over a street was
	## unbuilt massif the parcel retained. The buildable-layer wave deleted that
	## substrate, so the retained set is empty on every stamped seed and this
	## camera silently stopped existing -- the only view that answers the
	## reviewer's standing question, lost to a set that is now always empty.
	##
	## Every standable public kind is a candidate, not STRUCTURAL_COURT alone.
	## INTERIOR_PASSAGE is precisely "the street runs through the inside of a
	## building", so a camera that could not stand on one was excluding the shot
	## it exists to take.
	if _fabric == null or _fabric.surface_plan == null:
		return {}
	var floors: Array[Vector3i] = []
	var covered_kind: Dictionary = {}
	for kind: int in [PublicRealmSurfacePlan.SurfaceKind.INTERIOR_PASSAGE,
			PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,
			PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET]:
		for cell: Vector3i in _fabric.surface_plan.cells_for_kind(kind):
			if kind == PublicRealmSurfacePlan.SurfaceKind.INTERIOR_PASSAGE:
				covered_kind[cell] = true
			floors.append(cell)
	if floors.is_empty():
		return {}
	var solids := _fabric.transformed_cells(&"solid")
	var best := Vector3i(2147483647, 0, 0)
	var best_cover := 0
	for cell: Vector3i in floors:
		# An INTERIOR_PASSAGE cell is roofed by definition, so it outranks any
		# open court however much solid happens to stand above the court.
		var cover := 16 if covered_kind.has(cell) else 0
		for band in range(cell.y + 2, cell.y + 10):
			if solids.has(Vector3i(cell.x, band, cell.z)):
				cover += 1
		if cover > best_cover:
			best_cover = cover
			best = cell
	if best.x == 2147483647:
		# No street runs under a building on this seed -- which is itself worth
		# seeing. Stand on the most central floor cell instead and say so, so an
		# uncovered town produces the same view as a covered one rather than
		# silently producing none.
		var nearest := INF
		for cell: Vector3i in floors:
			var radius := Vector2(float(cell.x), float(cell.z)).length()
			if radius < nearest:
				nearest = radius
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
	var eye := Vector3(best) * FabricRecipe.CELL_SIZE + Vector3(0.0, 1.4, 0.0) \
		+ _town_origin
	print("[mass_first_preview] route eye at %s: %s, %d bands of BUILDING "
		% [best, "INTERIOR_PASSAGE" if covered_kind.has(best) else "open floor",
		best_cover % 16] + "overhead (%d floors offered)" % floors.size())
	_report_street_cover(floors, solids)
	return {"id": "route-eye", "position": eye,
		"target": eye + forward * 6.0, "fov": 75.0}


func _report_street_cover(floors: Array[Vector3i], solids: Dictionary) -> void:
	## How much of the public realm a BUILDING stands over, at fabric
	## resolution, printed beside the route-eye so "the street is covered" is a
	## number in the same place as the picture of it.
	##
	## `shared columns` is the lattice check the rest of the line depends on: if
	## surface cells and recipe solid cells did not live in one lattice this
	## would be zero and every other count here would be meaningless rather than
	## merely bad.
	var floor_columns: Dictionary = {}
	for cell: Vector3i in floors:
		floor_columns[Vector2i(cell.x, cell.z)] = true
	var solid_columns: Dictionary = {}
	for cell_value: Variant in solids.keys():
		var cell := cell_value as Vector3i
		solid_columns[Vector2i(cell.x, cell.z)] = true
	var shared := 0
	for column: Vector2i in floor_columns:
		shared += int(solid_columns.has(column))
	var roofed := 0
	for cell: Vector3i in floors:
		for band in range(cell.y + 2, cell.y + 10):
			if solids.has(Vector3i(cell.x, band, cell.z)):
				roofed += 1
				break
	print(("[mass_first_preview] street cover: %d of %d floor cells carry a "
		+ "building 2-9 bands overhead | %d of %d floor columns share a column "
		+ "with some building cell | %d solid cells in %d columns")
		% [roofed, floors.size(), shared, floor_columns.size(), solids.size(),
		solid_columns.size()])


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
