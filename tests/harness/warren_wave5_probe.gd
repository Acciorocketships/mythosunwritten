extends SceneTree

## WAVE-5 INSTRUMENT (terrain milestone): the three readings this wave is
## judged on, measured on the synthetic stamped hill so a sweep costs seconds
## rather than the twenty-one per seed the real relief stamp costs.
##
##   godot --headless --path . -s res://tests/harness/warren_wave5_probe.gd \
##     -- --seeds 0-19
##
## Reported per seed and in total:
##   sink      route/lane cells standing below their own column's stamped
##             ground -- the sunken street -- and the mass left over them;
##   over      footprint columns of a house that stand over a public cell, and
##             the deepest such overlap;
##   ground    where each house's support floor sits against the ground under
##             its own footprint: cut in, flush, or on a plinth;
##   lanes     lanes and lane cells admitted, and the address/house A/B.
##
## Read-only: it changes no gate and no constant. The instrument of record for
## anything measured against the REAL stamp remains
## tests/harness/warren_buildable_layer_probe.gd.

const StampedGround = preload("res://tests/fixtures/warren_stamped_ground.gd")

var _seeds: Array[int] = []
var _lane_ab := false


func _init() -> void:
	_read_args()
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	var sunk := 0
	var sunk_towns := 0
	var deepest_sink := 0
	var housable_sunk := 0
	var covered_sum := 0.0
	var over_cells := 0
	var over_towns := 0
	var houses := 0
	var cut := 0
	var flush := 0
	var plinth := 0
	var buried := 0
	var plinth_depths: Dictionary = {}
	var lanes := 0
	var lane_cells := 0
	var carved_towns := 0
	var addresses_on := 0
	var addresses_off := 0
	var houses_off := 0
	for world_seed: int in _seeds:
		var bands := StampedGround.hill(WarrenMassifBuilder.RADIUS_CELLS + 4,
			world_seed)
		var massif := WarrenMassifBuilder.build(world_seed, bands)
		if massif == null:
			print("seed %2d: MASSIF -- %s" % [world_seed,
				WarrenMassifBuilder.last_failure])
			continue
		var excavation := WarrenExcavationCarver.carve(world_seed, massif)
		if excavation == null:
			print("seed %2d: BORE -- %s" % [world_seed,
				WarrenExcavationCarver.last_failure])
			continue
		carved_towns += 1
		var seed_sunk := 0
		var seed_deepest := 0
		var seed_housable := 0
		for cell: Vector3i in excavation.public_cells():
			var column := Vector2i(cell.x, cell.z)
			if not massif.has_column(column):
				continue
			var depth := massif.base_at(column) - cell.y
			if depth <= 0:
				continue
			seed_sunk += 1
			seed_deepest = maxi(seed_deepest, depth)
			seed_housable += int(cell.y + excavation.slot_bands(cell)
				<= massif.base_at(column))
		housable_sunk += seed_housable
		covered_sum += excavation.covered_ratio()
		sunk += seed_sunk
		deepest_sink = maxi(deepest_sink, seed_deepest)
		sunk_towns += int(seed_sunk > 0)
		lanes += excavation.lanes.size()
		lane_cells += excavation.lane_cells().size()
		var plan := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
			excavation)
		var extended: WarrenVolumePlan = null
		if plan != null and WarrenPublicRealmCarver.passes_topology_gate(plan):
			extended = WarrenGroundArcadeSolver.extend(plan)
		var parcels := WarrenSolidPartitioner.partition(massif, excavation,
			extended if extended != null else plan)
		houses += parcels.size()
		var public_columns: Dictionary = {}
		if extended != null:
			for cell: Vector3i in extended.walk_cells:
				var column := Vector2i(cell.x, cell.z)
				public_columns[column] = maxi(int(public_columns.get(column,
					-(1 << 30))), cell.y)
		for cell: Vector3i in excavation.public_cells():
			var column := Vector2i(cell.x, cell.z)
			public_columns[column] = maxi(int(public_columns.get(column,
				-(1 << 30))), cell.y)
		var seed_over := 0
		for parcel: WarrenBuildingParcel in parcels:
			var highest := -(1 << 30)
			var lowest := 1 << 30
			for column: Vector2i in parcel.footprint:
				highest = maxi(highest, massif.bearing_at(column))
				lowest = mini(lowest, massif.bearing_at(column))
				if public_columns.has(column) \
						and int(public_columns[column]) < parcel.base_band:
					seed_over += 1
			var support := WarrenParcelConstruction.resolve_support_band(
				highest, lowest, parcel.base_band,
				WarrenMassif.PLINTH_BUDGET_BANDS)
			if support < lowest:
				buried += 1
			elif support < highest:
				cut += 1
			elif support == lowest:
				flush += 1
			else:
				plinth += 1
				plinth_depths[support - lowest] = int(plinth_depths.get(
					support - lowest, 0)) + 1
		over_cells += seed_over
		over_towns += int(seed_over > 0)
		print(("seed %2d: sunk %3d (deepest %d, housable %2d) | covered %.2f |"
			+ " lanes %2d | houses %3d | over-street columns %3d") % [
			world_seed, seed_sunk, seed_deepest, seed_housable,
			excavation.covered_ratio(), excavation.lanes.size(),
			parcels.size(), seed_over])
		if _lane_ab and plan != null:
			addresses_on += int(plan.audit.get("addressed_walk_cell_count", 0))
	print("")
	print(("TOWNS carved %d | sunk in %d towns, %d cells (housable %d),"
		+ " deepest %d | covered mean %.3f | lanes %d (%d cells) | houses %d"
		+ " | over-street columns %d in %d towns") % [carved_towns, sunk_towns,
		sunk, housable_sunk, deepest_sink,
		covered_sum / float(maxi(1, carved_towns)), lanes, lane_cells, houses,
		over_cells, over_towns])
	print("GROUNDING cut %d | flush %d | on a plinth %d | buried %d" % [
		cut, flush, plinth, buried])
	var depths: Array = plinth_depths.keys()
	depths.sort()
	var parts: Array[String] = []
	for depth: int in depths:
		parts.append("%d:%d" % [depth, int(plinth_depths[depth])])
	print("plinth depth (bands) %s" % ("none" if parts.is_empty()
		else " ".join(parts)))
	print("addresses(on) %d off %d houses(off) %d" % [addresses_on,
		addresses_off, houses_off])
	quit()


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--seeds" and index + 1 < args.size():
			var spec: String = args[index + 1]
			if spec.contains("-"):
				var halves := spec.split("-")
				for value in range(int(halves[0]), int(halves[1]) + 1):
					_seeds.append(value)
			else:
				_seeds.append(int(spec))
		elif args[index] == "--lane-ab":
			_lane_ab = true
	if _seeds.is_empty():
		for value in 20:
			_seeds.append(value)
