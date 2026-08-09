extends SceneTree

## BUILDABLE-LAYER INSTRUMENT (terrain milestone, Wave 4).
##
## Runs the mass-first chain -- massif, bore, lanes, partition, construction --
## over ground bands sampled from the REAL settlement relief stamp, and prints
## the readings the wave is judged on: the massif's gates, the carver's covered
## and wall ratios, and the two measures the reviewer's grounding and
## composed-face notes are about.
##
##   godot --headless --path . -s res://tests/harness/warren_buildable_layer_probe.gd \
##     -- --seeds 0-19 [--frame stamped|flat]
##
## The ground frame is produced exactly the way production produces it --
## HeightfieldPlan.compute_region through VillageTerrainView, then
## VillageWarrenFabricSolver's five-probe ceil per 3 m column -- so a number
## here is a number about the world the preview renders, not about a synthetic
## ramp. `--frame flat` is the A/B: the same chain on ground band 0 everywhere.

const StampedGround = preload("res://tests/fixtures/warren_stamped_ground.gd")

var _seeds: Array[int] = []
var _frame := "stamped"
var _gates_only := false
var _ground_cache: Dictionary = {}


func _init() -> void:
	_read_args()
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	print("frame=%s seeds=%s" % [_frame, str(_seeds)])
	var built := 0
	var carved := 0
	var partitioned := 0
	var covered_sum := 0.0
	var wall_sum := 0.0
	var faces: Array[int] = []
	var floating_total := 0
	var house_total := 0
	var plateaus: Array[int] = []
	var levels: Array[int] = []
	var developments: Array[int] = []
	for world_seed: int in _seeds:
		var bands := _ground_bands(world_seed)
		var massif := WarrenMassifBuilder.build(world_seed, bands)
		if massif == null:
			print("seed %2d: MASSIF -- %s" % [world_seed,
				WarrenMassifBuilder.last_failure])
			continue
		built += 1
		plateaus.append(massif.widest_plateau_cells())
		levels.append(massif.terrace_levels().size())
		developments.append(massif.vertical_development_bands())
		if _gates_only:
			continue
		var head := ("seed %2d: relief %2d layer %d dev %2d levels %d "
			+ "plateau %2d columns %3d") % [world_seed, massif.relief_bands(),
			massif.core_top_bands, massif.vertical_development_bands(),
			massif.terrace_levels().size(), massif.widest_plateau_cells(),
			massif.columns.size()]
		var excavation := WarrenExcavationCarver.carve(world_seed, massif)
		if excavation == null:
			print("%s | BORE -- %s" % [head,
				WarrenExcavationCarver.last_failure])
			continue
		carved += 1
		var walled := 0
		for cell: Vector3i in excavation.route:
			walled += int(WarrenExcavationCarver._wall_count(massif,
				excavation, cell) >= 2)
		var wall_ratio := float(walled) / float(maxi(1, excavation.route.size()))
		covered_sum += excavation.covered_ratio()
		wall_sum += wall_ratio
		head += " | route %d span %d covered %.2f wall %.2f lanes %d portals %d" \
			% [excavation.route.size(), excavation.route_span_bands(),
			excavation.covered_ratio(), wall_ratio, excavation.lanes.size(),
			excavation.portals.size()]
		var frontier := WarrenTownSolver.mass_first_frontier(world_seed, bands)
		head += " | frontier %d" % frontier.size()
		if frontier.is_empty():
			head += " (%s)" % WarrenTownSolver.last_failure
		var plan := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
			excavation)
		if plan == null:
			print("%s | ADAPT -- %s" % [head,
				WarrenExcavationVolumeAdapter.last_failure])
			continue
		var parcels := WarrenSolidPartitioner.partition(massif, excavation,
			plan)
		if parcels.is_empty():
			print("%s | PARTITION -- %s" % [head,
				WarrenSolidPartitioner.last_failure])
			continue
		partitioned += 1
		var measured := _house_measures(massif, excavation, parcels)
		faces.append(int(measured.face))
		floating_total += int(measured.floating)
		house_total += int(measured.houses)
		print("%s | houses %d face %d floating %d drops %s" % [head,
			int(measured.houses), int(measured.face), int(measured.floating),
			str(measured.drops)])
	print("")
	print(("SUMMARY frame=%s seeds=%d massif=%d bore=%d partition=%d | "
		+ "covered mean %.3f wall mean %.3f | face %s | floating %d of %d")
		% [_frame, _seeds.size(), built, carved, partitioned,
		covered_sum / float(maxi(1, carved)), wall_sum / float(maxi(1, carved)),
		_range(faces), floating_total, house_total])
	print("plateau %s levels %s development %s" % [_range(plateaus),
		_range(levels), _range(developments)])
	quit()


func _house_measures(massif: WarrenMassif, excavation: WarrenExcavation,
		parcels: Array[WarrenBuildingParcel]) -> Dictionary:
	## The partitioner suite's two standing measures, restated here so the
	## harness and the suite describe the same town.
	##
	## DRAWN mass is house cells plus the plinth course a house's own footprint
	## declares -- and, on a column NOBODY builds over, nothing at all. That is
	## the wave's whole point: unbuilt massif mass is no longer drawn, because
	## it is no longer the fabric's. Terrain carries it, so a house sitting on
	## its own sampled base is grounded even though the fabric draws nothing
	## beneath it, and the ground under a column is therefore seeded as drawn at
	## the band the terrain surfaces at.
	var drawn: Dictionary = {}
	for column: Vector2i in massif.columns:
		# The terrain BODY, not just its surface: everything below the sampled
		# ground band is solid hill the mesher renders and collides, so a house
		# resting anywhere at or below its own ground is carried.
		for band in range(massif.base_at(column) - 1,
				massif.base_at(column) - 9, -1):
			drawn[Vector3i(column.x, band, column.y)] = true
	var fabric: Dictionary = {}
	var houses := 0
	var floating := 0
	var drops: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels:
		var proposal := WarrenParcelConstruction.proposal(parcel)
		if proposal.is_empty():
			continue
		houses += 1
		for cell: Vector3i in WarrenParcelConstruction.retained_terrace_cells(
				parcel):
			drawn[Vector3i(cell.x / 2, cell.y, cell.z / 2)] = true
			fabric[Vector3i(cell.x / 2, cell.y, cell.z / 2)] = true
		for column: Vector2i in parcel.footprint:
			for band in range((proposal.origin as Vector3i).y, parcel.top_band):
				drawn[Vector3i(column.x, band, column.y)] = true
				fabric[Vector3i(column.x, band, column.y)] = true
	for parcel: WarrenBuildingParcel in parcels:
		var proposal := WarrenParcelConstruction.proposal(parcel)
		if proposal.is_empty():
			continue
		var underside := (proposal.origin as Vector3i).y
		var gap := 1 << 30
		for column: Vector2i in parcel.footprint:
			var column_gap := underside
			for band in range(underside - 1, -30, -1):
				if drawn.has(Vector3i(column.x, band, column.y)):
					column_gap = underside - band - 1
					break
			gap = mini(gap, column_gap)
		if gap > 2:
			floating += 1
			var lowest_base := 1 << 30
			for column: Vector2i in parcel.footprint:
				lowest_base = mini(lowest_base, massif.base_at(column))
			drops[underside - lowest_base] = int(drops.get(
				underside - lowest_base, 0)) + 1
	var runs: Dictionary = {}
	for cell_value: Variant in fabric.keys():
		var cell := cell_value as Vector3i
		for index in 4:
			var step: Vector2i = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP,
				Vector2i.DOWN][index]
			if fabric.has(Vector3i(cell.x + step.x, cell.y, cell.z + step.y)):
				continue
			var key := Vector3i(cell.x, cell.z, index)
			if not runs.has(key):
				runs[key] = {}
			(runs[key] as Dictionary)[cell.y] = true
	var tallest := 0
	for key_value: Variant in runs.keys():
		var bands: Array[int] = []
		bands.assign((runs[key_value] as Dictionary).keys())
		bands.sort()
		var index := 0
		while index < bands.size():
			var last := index
			while last + 1 < bands.size() and bands[last + 1] == bands[last] + 1:
				last += 1
			tallest = maxi(tallest, bands[last] - bands[index] + 1)
			index = last + 1
	var drop_keys: Array = drops.keys()
	drop_keys.sort()
	var drop_parts := PackedStringArray()
	for key: int in drop_keys:
		drop_parts.append("%d:%d" % [key, int(drops[key])])
	return {"houses": houses, "floating": floating, "face": tallest,
		"drops": " ".join(drop_parts)}


func _ground_bands(world_seed: int) -> Dictionary:
	if _frame == "flat":
		return {}
	if _frame == "hill":
		return StampedGround.hill(WarrenMassifBuilder.RADIUS_CELLS + 1,
			world_seed)
	if _ground_cache.has(world_seed):
		return _ground_cache[world_seed]
	var water := TerrainWorldTuning.make_water(world_seed)
	var settlements := SettlementPlan.new(world_seed, water)
	var relief := TerrainWorldTuning.make_relief(world_seed, water, settlements)
	var plan := TerrainWorldTuning.make_heightfield(world_seed, water, relief)
	var site := Vector2i.ZERO
	for ring in 3:
		var found := false
		for sz in range(-ring, ring + 1):
			for sx in range(-ring, ring + 1):
				var candidate: Dictionary = settlements.site_for(Vector2i(sx, sz))
				if candidate.is_empty():
					continue
				site = candidate["cell"] as Vector2i
				found = true
				break
			if found:
				break
		if found:
			break
	var region := plan.compute_region(site.x, site.y,
		TerrainChunkMesher.CELLS_PER_CHUNK)
	var terrain := VillageTerrainView.from_region(region)
	var centre := Vector2(float(site.x), float(site.y)) * TerrainSurfaceField.TILE
	var span := WarrenMassifBuilder.RADIUS_CELLS + 1
	var half := WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M * 0.45
	var maxima: Dictionary = {}
	var lowest := INF
	for z in range(-span, span + 1):
		for x in range(-span, span + 1):
			var point := centre + Vector2(
				float(x) * WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M,
				float(z) * WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M)
			var column_max := -INF
			for offset: Vector2 in [Vector2.ZERO, Vector2(-half, -half),
					Vector2(half, -half), Vector2(-half, half),
					Vector2(half, half)]:
				var height := terrain.surface_y(point + offset)
				column_max = maxf(column_max, height)
				lowest = minf(lowest, height)
			maxima[Vector2i(x, z)] = column_max
	var bands: Dictionary = {}
	for column: Vector2i in maxima:
		bands[column] = ceili((float(maxima[column]) - lowest)
			/ WarrenVolumePlan.VERTICAL_BAND_SIZE_M)
	_ground_cache[world_seed] = bands
	return bands


func _range(values: Array[int]) -> String:
	if values.is_empty():
		return "n/a"
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0
	for value: int in sorted:
		total += value
	return "%d..%d mean %.1f" % [sorted[0], sorted[-1],
		float(total) / float(sorted.size())]


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	var index := 0
	while index < args.size():
		if args[index] == "--seeds" and index + 1 < args.size():
			var text: String = args[index + 1]
			if text.contains("-"):
				var parts := text.split("-")
				for value in range(int(parts[0]), int(parts[1]) + 1):
					_seeds.append(value)
			else:
				for part in text.split(","):
					_seeds.append(int(part))
			index += 1
		elif args[index] == "--gates-only":
			_gates_only = true
		elif args[index] == "--frame" and index + 1 < args.size():
			_frame = args[index + 1]
			index += 1
		index += 1
	if _seeds.is_empty():
		for value in range(12):
			_seeds.append(value)
