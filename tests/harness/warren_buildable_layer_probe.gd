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
##
## VISIBILITY ROUND (Wave 5 preparation) added three further modes, all
## read-only and all on the same stamped frame:
##
##   --mode fabric  How far down the composition chain each seed gets --
##                  frontier, parcel variants, WarrenTownSolver._compose_plan,
##                  WarrenAssetCompiler, WarrenFabricCompiler -- so the search
##                  for a seed that reaches a RENDERABLE sealed fabric is a
##                  measurement rather than a guess. Names the stage and the
##                  arcade-enclosure numbers for every seed that stops short.
##   --mode lanes   The lane-web census: anchors offered, anchors skipped on
##                  separation, lanes grown, lanes rolled back, and -- for
##                  every stride the growth rejected -- which of the five
##                  legality conditions refused it, counted both as "failed"
##                  and as "SOLE blocker", which is the one that identifies a
##                  binding constraint rather than a correlated one. Also the
##                  lanes-on / lanes-off A/B for addresses and houses, against
##                  the 46.5 -> 92 and 29.8 -> 73.8 the lane work measured on
##                  the tall massif.
##   --mode plinth  Where each house's support floor sits relative to the
##                  ground under its own footprint: cut into the uphill side,
##                  standing on a plinth over the downhill side, or buried
##                  below the lowest ground by the storey-parity fudge.
##
## None of the three changes any gate or constant; they only read.

const StampedGround = preload("res://tests/fixtures/warren_stamped_ground.gd")

var _seeds: Array[int] = []
var _frame := "stamped"
var _gates_only := false
var _mode := "layer"
var _ground_cache: Dictionary = {}


func _init() -> void:
	_read_args()
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	if _mode == "fabric":
		_report_fabric()
		quit()
		return
	if _mode == "lanes":
		_report_lanes()
		quit()
		return
	if _mode == "plinth":
		_report_plinth()
		quit()
		return
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
		var arc_plan := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
			excavation)
		if arc_plan != null and WarrenPublicRealmCarver.passes_topology_gate(
				arc_plan):
			var extended := WarrenGroundArcadeSolver.extend(arc_plan)
			if extended == null:
				print("    arcade: %s" % WarrenGroundArcadeSolver.last_failure)
			else:
				print("    arcade crossovers %s" % extended.audit.get(
					"ground_arcade_upper_crossover_count"))
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
		elif args[index] == "--mode" and index + 1 < args.size():
			_mode = args[index + 1]
			index += 1
		elif args[index] == "--frame" and index + 1 < args.size():
			_frame = args[index + 1]
			index += 1
		index += 1
	if _seeds.is_empty():
		for value in range(12):
			_seeds.append(value)


# --- Visibility round: how far down the chain a stamped seed gets ------------


func _report_fabric() -> void:
	## Which stamped seed, if any, reaches a SEALED SettlementFabricPlan -- the
	## thing the preview harness can actually photograph.
	##
	## The detail phases are deliberately not run: WarrenBuiltTownSolver's
	## `diagnostic_best_effort` already draws a town the visual-selection gates
	## refused, so a candidate only has to reach a sealed parcel fabric to be
	## renderable. What kills the corpus today is upstream of that, and this
	## mode's whole job is to say which stage, per seed, with the arcade
	## enclosure counts printed wherever that is the one.
	##
	## The corner-envelope diagnostic is enabled because the preview enables it,
	## so "reaches fabric" here means the same thing it will mean in the render.
	SettlementFabricPlan.DIAGNOSTIC_ALLOW_CORNER_ENVELOPE_OVERLAP = true
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	print("frame=%s mode=fabric seeds=%s" % [_frame, str(_seeds)])
	var reached: Array[int] = []
	var stages: Dictionary = {}
	for world_seed: int in _seeds:
		var bands := _ground_bands(world_seed)
		var frontier := WarrenTownSolver.mass_first_frontier(world_seed, bands)
		if frontier.is_empty():
			_tally_string(stages, "frontier")
			print("seed %2d: FRONTIER -- %s" % [world_seed,
				WarrenTownSolver.last_failure.substr(0, 150)])
			continue
		var variants := 0
		var composed := 0
		var asset_plans := 0
		var fabrics := 0
		var arcade_note := ""
		var last_note := ""
		for volume: WarrenVolumePlan in frontier:
			if fabrics > 0:
				break
			for parcels: WarrenParcelPlan in WarrenTownSolver._parcel_variants(
					volume, program):
				variants += 1
				var town := WarrenTownSolver._compose_plan(world_seed, volume,
					parcels)
				if town == null:
					last_note = WarrenTownSolver.last_failure
					if last_note.begins_with("ground arcade lacks"):
						var audit := WarrenGroundArcadeSolver \
							.arcade_enclosure_audit(parcels)
						arcade_note = ("cells %d qualified %d grounded %d "
							+ "(floors %d/%d)") % [int(audit.cell_count),
							int(audit.get("qualified_count", 0)),
							int(audit.get("grounded_count", 0)),
							WarrenGroundArcadeSolver.MIN_ENCLOSED_CELLS,
							WarrenGroundArcadeSolver.MIN_GROUNDED_FRONTAGE_CELLS]
					continue
				composed += 1
				# Bounded: asset compilation is the expensive stage and one
				# sealed fabric is all this scan is looking for.
				if composed > 4:
					continue
				var assets := WarrenAssetCompiler.solve(town, program)
				if assets == null:
					last_note = WarrenAssetCompiler.last_failure
					continue
				asset_plans += 1
				var fabric := WarrenFabricCompiler.solve(assets)
				if fabric == null or not fabric.is_sealed():
					last_note = WarrenFabricCompiler.last_failure
					continue
				fabrics += 1
				break
		var stage := "frontier"
		if fabrics > 0:
			stage = "FABRIC"
			reached.append(world_seed)
		elif asset_plans > 0:
			stage = "fabric_compile"
		elif composed > 0:
			stage = "assets"
		elif variants > 0:
			stage = "compose"
		else:
			stage = "partition"
		_tally_string(stages, stage)
		print(("seed %2d: frontier %d variants %d composed %d assets %d "
			+ "fabric %d -> %s%s%s") % [world_seed, frontier.size(), variants,
			composed, asset_plans, fabrics, stage,
			"" if arcade_note.is_empty() else " | arcade %s" % arcade_note,
			"" if last_note.is_empty() or stage == "FABRIC" \
				else " | %s" % last_note.substr(0, 110)])
	print("")
	print("STAGES %s" % _histogram(stages))
	print("SEEDS REACHING SEALED FABRIC: %s" % ("none" if reached.is_empty() \
		else str(reached)))
	SettlementFabricPlan.DIAGNOSTIC_ALLOW_CORNER_ENVELOPE_OVERLAP = false


# --- Visibility round: the lane web ------------------------------------------


func _report_lanes() -> void:
	## DIAGNOSIS ONLY. Re-runs WarrenExcavationCarver's own lane loop around the
	## carver's own statics -- `_lane_anchors`, `_too_near`, `_grow_lane`,
	## `_lane_survives` -- so the growth being measured is production's, and
	## prints the census the loop itself cannot: anchors offered, anchors
	## skipped on separation, lanes grown, lanes rolled back, and for every
	## anchor the growth refused, which of the five stride conditions refused
	## each candidate first move.
	##
	## `sole` is the column that matters. A condition can fail on most strides
	## simply because it is correlated with another; a condition that is the
	## ONLY one failing is a stride that relaxing exactly that rule would admit.
	print("frame=%s mode=lanes seeds=%s" % [_frame, str(_seeds)])
	var offered := 0
	var separation_skips := 0
	var tried := 0
	var admitted := 0
	var rolled_back := 0
	var no_legal_start := 0
	var died_mid_lane := 0
	var budget_stops := 0
	var failed: Dictionary = {}
	var sole: Dictionary = {}
	var flanks: Dictionary = {}
	var replica_agrees := 0
	var towns := 0
	var addresses_off := 0
	var addresses_on := 0
	var houses_off := 0
	var houses_on := 0
	var lane_counts: Array[int] = []
	var grade_cells := 0
	var route_cells := 0
	var reserve_columns := 0
	var massif_columns := 0
	var anchors_in_reserve := 0
	for world_seed: int in _seeds:
		var bands := _ground_bands(world_seed)
		var massif := WarrenMassifBuilder.build(world_seed, bands)
		if massif == null:
			print("seed %2d: MASSIF -- %s" % [world_seed,
				WarrenMassifBuilder.last_failure])
			continue
		var bare := _select_bore(world_seed, massif)
		if bare == null:
			print("seed %2d: BORE -- no attempt sealed" % world_seed)
			continue
		var census := _lane_census(world_seed, massif)
		if census.is_empty():
			continue
		var laned := WarrenExcavationCarver.carve(world_seed, massif)
		var production_lanes := 0 if laned == null else laned.lanes.size()
		replica_agrees += int(production_lanes == int(census.admitted))
		towns += 1
		offered += int(census.offered)
		separation_skips += int(census.separation_skips)
		tried += int(census.tried)
		admitted += int(census.admitted)
		rolled_back += int(census.rolled_back)
		no_legal_start += int(census.no_legal_start)
		died_mid_lane += int(census.died_mid_lane)
		budget_stops += int(census.budget_stop)
		lane_counts.append(int(census.admitted))
		grade_cells += int(census.grade_cells)
		route_cells += int(census.route_cells)
		reserve_columns += int(census.reserve_columns)
		massif_columns += int(census.massif_columns)
		anchors_in_reserve += int(census.anchors_in_reserve)
		for key: String in (census.failed as Dictionary):
			failed[key] = int(failed.get(key, 0)) \
				+ int((census.failed as Dictionary)[key])
		for key: String in (census.sole as Dictionary):
			sole[key] = int(sole.get(key, 0)) \
				+ int((census.sole as Dictionary)[key])
		for key: String in (census.flanks as Dictionary):
			flanks[key] = int(flanks.get(key, 0)) \
				+ int((census.flanks as Dictionary)[key])
		var off := _address_and_house_count(massif, bare)
		var on := _address_and_house_count(massif, laned)
		addresses_off += int(off.addresses)
		addresses_on += int(on.addresses)
		houses_off += int(off.houses)
		houses_on += int(on.houses)
		print(("seed %2d: anchors %3d (sep-skip %2d) tried %3d -> lanes %2d "
			+ "(rolled back %2d, no legal start %2d, died short %2d) | "
			+ "addresses %3d -> %3d | houses %2d -> %2d | production lanes %d")
			% [world_seed, int(census.offered), int(census.separation_skips),
			int(census.tried), int(census.admitted), int(census.rolled_back),
			int(census.no_legal_start), int(census.died_mid_lane),
			int(off.addresses), int(on.addresses), int(off.houses),
			int(on.houses), production_lanes])
	print("")
	print(("TOWNS %d | replica agrees with production on %d | anchors %d "
		+ "(separation skips %d) | tried %d | admitted %d | rolled back %d")
		% [towns, replica_agrees, offered, separation_skips, tried, admitted,
		rolled_back])
	print("anchors with NO legal first stride %d | anchors that started and "
		% no_legal_start + "died short of MIN_LANE_CELLS %d | budget stops %d"
		% [died_mid_lane, budget_stops])
	print("lanes per town %s" % _range(lane_counts))
	print(("route cells AT GRADE %d of %d (%.2f) | arcade-reserve columns %d "
		+ "of %d massif columns (%.2f) | anchors inside the reserve %d of %d")
		% [grade_cells, route_cells,
		float(grade_cells) / float(maxi(1, route_cells)), reserve_columns,
		massif_columns, float(reserve_columns) / float(maxi(1, massif_columns)),
		anchors_in_reserve, offered])
	print("stride conditions FAILED  %s" % _histogram(failed))
	print("stride conditions SOLE    %s" % _histogram(sole))
	print("housable-flank refusals   %s" % _histogram(flanks))
	print(("ADDRESSES lanes-off %d lanes-on %d (mean %.1f -> %.1f) | "
		+ "HOUSES lanes-off %d lanes-on %d (mean %.1f -> %.1f)")
		% [addresses_off, addresses_on,
		float(addresses_off) / float(maxi(1, towns)),
		float(addresses_on) / float(maxi(1, towns)), houses_off, houses_on,
		float(houses_off) / float(maxi(1, towns)),
		float(houses_on) / float(maxi(1, towns))])


func _select_bore(world_seed: int,
		massif: WarrenMassif) -> WarrenExcavation:
	## WarrenExcavationCarver.carve() with the lane pass left out, assembled
	## from the carver's own statics so the survivor is the same bore the
	## shipping carver selects -- lanes are grown into the winner after every
	## route gate has chosen it, so a lanes-off town is exactly this.
	var portals := WarrenExcavationCarver._portal_cells(massif)
	if portals.is_empty():
		return null
	var best: WarrenExcavation = null
	var best_score := INF
	var rejected: Dictionary = {}
	for attempt in WarrenExcavationCarver.ATTEMPTS:
		var candidate := WarrenExcavationCarver._bore(world_seed, attempt,
			massif, portals, rejected)
		if candidate == null:
			continue
		var score := WarrenExcavationCarver._candidate_score(candidate, massif)
		if best == null or score < best_score:
			best = candidate
			best_score = score
	return best


func _lane_census(world_seed: int, massif: WarrenMassif) -> Dictionary:
	## WarrenExcavationCarver._carve_lanes' loop, instrumented. The growth and
	## every legality question are production's; only the bookkeeping is here.
	var excavation := _select_bore(world_seed, massif)
	if excavation == null:
		return {}
	var reserve := WarrenExcavationCarver._arcade_reserve(massif, excavation)
	var addressed := WarrenExcavationCarver._route_addressed_count(massif,
		excavation)
	var used: Array[Vector3i] = []
	var tried: Dictionary = {}
	var total := 0
	var initial_anchors := WarrenExcavationCarver._lane_anchors(world_seed,
		excavation)
	var offered := initial_anchors.size()
	# The reserve is the one lane rule whose size is set by route grade rather
	# than by the lane: it is a four-column halo around every route cell that
	# stands at grade, preserving ground-arcade opportunities before optional
	# lane growth consumes them.
	var grade_cells := 0
	for cell: Vector3i in excavation.route:
		grade_cells += int(WarrenExcavationCarver._is_at_grade(massif, cell))
	var anchors_in_reserve := 0
	for anchor: Vector3i in initial_anchors:
		anchors_in_reserve += int(reserve.has(Vector2i(anchor.x, anchor.z)))
	var separation_skips := 0
	var admitted := 0
	var rolled_back := 0
	var no_legal_start := 0
	var died_mid_lane := 0
	var budget_stop := 0
	var failed: Dictionary = {}
	var sole: Dictionary = {}
	var flanks: Dictionary = {}
	while true:
		if excavation.lanes.size() >= WarrenExcavationCarver.MAX_LANES \
				or total >= WarrenExcavationCarver.MAX_LANE_CELLS_TOTAL:
			budget_stop += 1
			break
		var anchors := WarrenExcavationCarver._lane_anchors(world_seed,
			excavation)
		var next := Vector3i(2147483647, 0, 0)
		for anchor: Vector3i in anchors:
			if tried.has(anchor):
				continue
			if WarrenExcavationCarver._too_near(anchor, used):
				separation_skips += 1
				continue
			next = anchor
			break
		if next.x == 2147483647:
			break
		tried[next] = true
		var lane := WarrenExcavationCarver._grow_lane(world_seed, excavation,
			massif, next, reserve,
			WarrenExcavationCarver.MAX_LANE_CELLS_TOTAL - total)
		if lane.is_empty():
			var diagnosis := _diagnose_anchor(excavation, massif, next, reserve,
				WarrenExcavationCarver.MAX_LANE_CELLS_TOTAL - total)
			if int(diagnosis.legal) > 0:
				died_mid_lane += 1
			else:
				no_legal_start += 1
			for key: String in (diagnosis.failed as Dictionary):
				failed[key] = int(failed.get(key, 0)) \
					+ int((diagnosis.failed as Dictionary)[key])
			for key: String in (diagnosis.sole as Dictionary):
				sole[key] = int(sole.get(key, 0)) \
					+ int((diagnosis.sole as Dictionary)[key])
			for key: String in (diagnosis.flanks as Dictionary):
				flanks[key] = int(flanks.get(key, 0)) \
					+ int((diagnosis.flanks as Dictionary)[key])
			continue
		excavation.lanes.append(lane)
		if not WarrenExcavationCarver._lane_survives(excavation, massif,
				addressed):
			WarrenExcavationCarver._roll_back_lane(excavation)
			rolled_back += 1
			continue
		lane.erase("carved")
		used.append(next)
		admitted += 1
		total += (lane["cells"] as Array[Vector3i]).size()
	return {"offered": offered, "separation_skips": separation_skips,
		"tried": tried.size(), "admitted": admitted,
		"rolled_back": rolled_back, "no_legal_start": no_legal_start,
		"died_mid_lane": died_mid_lane, "budget_stop": budget_stop,
		"failed": failed, "sole": sole, "flanks": flanks,
		"grade_cells": grade_cells, "route_cells": excavation.route.size(),
		"reserve_columns": reserve.size(),
		"massif_columns": massif.columns.size(),
		"anchors_in_reserve": anchors_in_reserve}


func _diagnose_anchor(excavation: WarrenExcavation, massif: WarrenMassif,
		anchor: Vector3i, reserve: Dictionary, budget: int) -> Dictionary:
	## Every first move WarrenExcavationCarver._best_lane_move would consider
	## from `anchor`, with all five of _lane_stride_cells' conditions evaluated
	## independently instead of short-circuited, so a stride can be reported as
	## refused by exactly one rule.
	var public_set: Dictionary = {}
	for cell: Vector3i in excavation.public_cells():
		public_set[cell] = true
	var failed: Dictionary = {}
	var sole: Dictionary = {}
	var flanks: Dictionary = {}
	var legal := 0
	for direction: Vector2i in WarrenExcavationCarver.DIRECTIONS:
		for action: Dictionary in WarrenExcavationCarver.ACTIONS:
			var run := int(action["run"])
			var rise := int(action["rise"])
			if run > budget or run > WarrenExcavationCarver.MAX_LANE_STRAIGHT_RUN:
				continue
			var hit: Dictionary = {}
			var occupied := public_set.duplicate()
			var previous := anchor
			for offset in range(1, run + 1):
				var span := WarrenExcavationCarver._surface_band_span(rise, run,
					offset)
				var cell := Vector3i(anchor.x + direction.x * offset,
					anchor.y + span.x, anchor.z + direction.y * offset)
				if not WarrenExcavationCarver._slot_is_borable(massif,
						excavation, cell, span.y - span.x
						+ WarrenExcavationCarver.HEADROOM_BANDS):
					hit["headroom"] = true
				if reserve.has(Vector2i(cell.x, cell.z)):
					hit["arcade_reserve"] = true
				if WarrenExcavationCarver._completes_public_square(occupied,
						cell):
					hit["public_square"] = true
				if WarrenExcavationCarver._folds_onto_route(occupied, previous,
						cell):
					hit["folds_onto_route"] = true
				if WarrenExcavationCarver._addressable_sides(massif, excavation,
						cell) < 1:
					hit["no_housable_flank"] = true
					_tally_flanks(flanks, massif, excavation, cell)
				occupied[cell] = true
				previous = cell
			if hit.is_empty():
				legal += 1
				continue
			for key: String in hit:
				failed[key] = int(failed.get(key, 0)) + 1
			if hit.size() == 1:
				var only: String = (hit.keys() as Array)[0]
				sole[only] = int(sole.get(only, 0)) + 1
	return {"legal": legal, "failed": failed, "sole": sole, "flanks": flanks}


func _tally_flanks(flanks: Dictionary, massif: WarrenMassif,
		excavation: WarrenExcavation, cell: Vector3i) -> void:
	## Why each of the four columns beside a lane cell cannot carry a house, by
	## WarrenExcavationCarver._addressable_sides' own clauses in its own order.
	for direction: Vector2i in WarrenExcavationCarver.DIRECTIONS:
		var column := Vector2i(cell.x + direction.x, cell.z + direction.y)
		if not massif.has_column(column):
			_tally_string(flanks, "off_massif")
			continue
		if massif.base_at(column) > cell.y:
			_tally_string(flanks, "ground_above_street")
			continue
		if massif.top_at(column) < cell.y \
				+ WarrenExcavationCarver.MIN_LANE_HOUSE_BANDS:
			_tally_string(flanks, "too_little_mass")
			continue
		if massif.top_at(column) > cell.y \
				+ WarrenMassif.BUILDABLE_LAYER_BANDS:
			_tally_string(flanks, "taller_than_layer")
			continue
		var clear := true
		for band in range(massif.base_at(column),
				cell.y + WarrenExcavationCarver.MIN_LANE_HOUSE_BANDS):
			if excavation.carved.has(Vector3i(column.x, band, column.y)):
				clear = false
				break
		_tally_string(flanks, "already_carved" if not clear else "would_pass")


func _address_and_house_count(massif: WarrenMassif,
		excavation: WarrenExcavation) -> Dictionary:
	## The address supply and the houses partitioned out of it, defined exactly
	## as warren_mass_first_report.gd's `--stage address` defines them:
	## |route U lane cells U the adapted plan's walk cells|, which is every cell
	## WarrenBuildingParcel.seal() will accept as an address.
	if excavation == null:
		return {"addresses": 0, "houses": 0}
	var plan := WarrenExcavationVolumeAdapter.to_volume_plan(massif, excavation)
	if plan == null:
		return {"addresses": 0, "houses": 0}
	var addresses: Dictionary = {}
	for cell: Vector3i in excavation.route:
		addresses[cell] = true
	for cell: Vector3i in excavation.lane_cells():
		addresses[cell] = true
	for cell: Vector3i in plan.walk_cells:
		addresses[cell] = true
	var houses := WarrenSolidPartitioner.partition(massif, excavation, plan)
	return {"addresses": addresses.size(), "houses": houses.size()}


# --- Visibility round: plinths and burial ------------------------------------


func _report_plinth() -> void:
	## Where WarrenParcelConstruction puts a house's support floor relative to
	## the ground under its own footprint, over the stamped corpus.
	##
	## Three populations, and they are disjoint by construction: a support at
	## the footprint's HIGHEST ground cuts INTO the uphill side (depth =
	## highest - support is 0, and the downhill side gains a plinth); a support
	## below the LOWEST ground is buried; a support above the lowest ground
	## stands on a plinth that WarrenParcelConstruction.retained_terrace_cells
	## has to declare or the house floats.
	print("frame=%s mode=plinth seeds=%s" % [_frame, str(_seeds)])
	var houses := 0
	var straddling := 0
	var cut_uphill := 0
	var plinthed := 0
	var buried := 0
	var declared := 0
	var cut_depths: Dictionary = {}
	var plinth_depths: Dictionary = {}
	var burial_depths: Dictionary = {}
	var straddle_depths: Dictionary = {}
	for world_seed: int in _seeds:
		var bands := _ground_bands(world_seed)
		var massif := WarrenMassifBuilder.build(world_seed, bands)
		if massif == null:
			continue
		var excavation := WarrenExcavationCarver.carve(world_seed, massif)
		if excavation == null:
			continue
		var plan := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
			excavation)
		if plan == null:
			continue
		var parcels := WarrenSolidPartitioner.partition(massif, excavation,
			plan)
		var seed_houses := 0
		var seed_cut := 0
		var seed_plinth := 0
		var seed_buried := 0
		var deepest_cut := 0
		for parcel: WarrenBuildingParcel in parcels:
			var proposal := WarrenParcelConstruction.proposal(parcel)
			if proposal.is_empty():
				continue
			var support := (proposal.origin as Vector3i).y
			var lowest := 1 << 30
			var highest := -(1 << 30)
			for column: Vector2i in parcel.footprint:
				# The STAMPED SURFACE, not the declared bottom of the solid:
				# since the undercroft wave `ground_at` drops below the surface
				# wherever a street tunnels under a column, and this measurement
				# is about the ground a house stands on.
				var ground := plan.envelope.bearing_at(column)
				lowest = mini(lowest, ground)
				highest = maxi(highest, ground)
			houses += 1
			seed_houses += 1
			declared += WarrenParcelConstruction.retained_terrace_cells(
				parcel).size()
			if highest > lowest:
				straddling += 1
				_tally_int(straddle_depths, highest - lowest)
			if support < highest:
				cut_uphill += 1
				seed_cut += 1
				deepest_cut = maxi(deepest_cut, highest - support)
				_tally_int(cut_depths, highest - support)
			if support > lowest:
				plinthed += 1
				seed_plinth += 1
				_tally_int(plinth_depths, support - lowest)
			if support < lowest:
				buried += 1
				seed_buried += 1
				_tally_int(burial_depths, lowest - support)
		print(("seed %2d: houses %2d | cut into the uphill side %2d (deepest "
			+ "%d bands) | on a plinth %2d | buried %2d")
			% [world_seed, seed_houses, seed_cut, deepest_cut, seed_plinth,
			seed_buried])
	print("")
	print(("HOUSES %d | footprints straddling a ground step %d | cut into the "
		+ "uphill side %d | standing on a plinth %d | buried below the lowest "
		+ "ground %d | declared plinth cells %d")
		% [houses, straddling, cut_uphill, plinthed, buried, declared])
	print("straddle depth (bands) %s" % _histogram_int(straddle_depths))
	print("uphill cut depth       %s" % _histogram_int(cut_depths))
	print("plinth depth           %s" % _histogram_int(plinth_depths))
	print("burial depth           %s" % _histogram_int(burial_depths))


# --- Shared tallies ----------------------------------------------------------


func _tally_string(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


func _tally_int(counts: Dictionary, key: int) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


func _histogram(counts: Dictionary) -> String:
	var keys: Array = counts.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(counts[a]) > int(counts[b]))
	var parts := PackedStringArray()
	for key: Variant in keys:
		parts.append("%s=%d" % [str(key), int(counts[key])])
	return "none" if parts.is_empty() else " ".join(parts)


func _histogram_int(counts: Dictionary) -> String:
	var keys: Array = counts.keys()
	keys.sort()
	var parts := PackedStringArray()
	for key: Variant in keys:
		parts.append("%d:%d" % [int(key), int(counts[key])])
	return "none" if parts.is_empty() else " ".join(parts)
