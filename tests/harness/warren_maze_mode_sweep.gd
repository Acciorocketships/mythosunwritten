extends SceneTree

## Does MODE_MAZE seal ANY town yet? Runs the real production entry point over a
## seed corpus and reports seal/failure and wall-clock per seed. The maze source
## itself is cheap, so a rejection is usually fast; a slow rejection means the
## composition ran and failed downstream.
##
##   Godot --headless --path . -s res://tests/harness/warren_maze_mode_sweep.gd -- \
##     --seeds 1,2,3,4,5,6,7,8,9 --mode maze
##
## Each row names the GATE the town died at — the head of the solver's own
## failure — so a corpus-wide run reads as a disposition of gates rather than a
## count of rejections. `--scale compact,standard` runs every seed at each
## named profile instead of the one WarrenVillageScaleProfile.select() rolls
## for it, which is how the Phase C baseline matrix is measured.
##
## --constructive switches to the plot-model exit-criteria matrix instead: for
## every seed x {compact, standard} it runs the real pipeline --
## WarrenMazeSitePlanner.plan() (massif -> carve -> reserve -> partition ->
## seal) -> WarrenMazeVolumeAdapter.to_volume_plan() ->
## WarrenMazeBlockPartitioner.partition() -- and reports the metrics Phase B is
## measured against (see docs/superpowers/specs/2026-08-21-plot-model-design.md,
## "Success criteria"). --mode is irrelevant to this path and is accepted (and
## ignored) in either order.
##
##   Godot --headless --path . -s res://tests/harness/warren_maze_mode_sweep.gd -- \
##     --seeds 1,2,3,4,5,6,7,8,9,10,11,12 --mode maze --constructive

const CONSTRUCTIVE_SCALES: Array[StringName] = [
	WarrenVillageScaleProfile.COMPACT, WarrenVillageScaleProfile.STANDARD,
]

## TASK C6 RULING 3. Where the corpus matrix is left for
## `tests/test_warren_maze_composition.gd::test_corpus_composes` to assert.
## The composition suite has a ~4 min budget and cannot afford 24 more
## production solves, so the sweep — which already runs them — writes the
## matrix down and the test reads it. `user://` because that is where every
## other machine-local harness artifact in this repository lives
## (`WarrenSolutionPinCache`, `heightfield_shot`).
const SUMMARY_PATH := "user://warren_maze_mode_sweep.json"

## The directory whose contents decide the matrix. A sweep summary is only
## evidence about the code that produced it, so it carries a fingerprint of
## every script in the village fabric layer and the test refuses a summary
## whose fingerprint no longer matches the tree it is running against. The
## whole directory rather than a hand-kept list of files: a list is a thing
## that goes stale silently, and a stale list is exactly the failure mode this
## fingerprint exists to prevent.
const PRODUCTION_SCRIPT_DIR := "res://scripts/terrain/features/villages/fabric"


static func production_fingerprint() -> String:
	## One hex digest over the sorted (path, content hash) pairs of every
	## `.gd` file in the fabric layer. Content rather than modification time,
	## so a checkout or a `touch` does not invalidate a still-valid sweep and
	## an edit-and-revert does not leave one falsely invalid.
	var directory := DirAccess.open(PRODUCTION_SCRIPT_DIR)
	if directory == null:
		return ""
	var names := PackedStringArray()
	for file_name: String in directory.get_files():
		if file_name.ends_with(".gd"):
			names.append(file_name)
	names.sort()
	var joined := PackedStringArray()
	for file_name: String in names:
		joined.append("%s:%s" % [file_name, FileAccess.get_sha256(
			"%s/%s" % [PRODUCTION_SCRIPT_DIR, file_name])])
	return "\n".join(joined).sha256_text()


func _init() -> void:
	var seeds: Array[int] = []
	var scale_ids: Array[StringName] = []
	var mode := WarrenTownSolver.MODE_MAZE
	var constructive := false
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--seeds" and index + 1 < args.size():
			for token: String in args[index + 1].split(",", false):
				seeds.append(int(token.strip_edges()))
		elif args[index] == "--scale" and index + 1 < args.size():
			for token: String in args[index + 1].split(",", false):
				scale_ids.append(StringName(token.strip_edges()))
		elif args[index] == "--mode" and index + 1 < args.size():
			mode = StringName(args[index + 1])
		elif args[index] == "--constructive":
			constructive = true
	if seeds.is_empty():
		seeds = [1, 2, 3, 4, 5, 6, 7, 8, 9]
	if scale_ids.is_empty():
		# The empty id means "whatever this seed rolls" — the profile
		# production would actually pick for it.
		scale_ids = [StringName()]

	if constructive:
		_run_constructive(seeds)
		quit()
		return

	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	WarrenTownSolver.GENERATION_MODE = mode
	print("SWEEP mode=%s seeds=%d scales=%d" % [String(mode), seeds.size(),
		scale_ids.size()])

	var sealed_count := 0
	var attempted := 0
	var total_ms := 0
	var rows: Array[Dictionary] = []
	# TASK E4 ruling 1. The corpus half of the stone-band profile: this path
	# runs the REAL compile, so every sealed town carries the assembler's own
	# shell measured against its local street datum, and the corpus mean is
	# the number Phase E exits on.
	var stone_faces := 0
	var stone_high_faces := 0
	var stone_plot_mass_high := 0
	var stone_raised_high := 0
	var stone_towns := 0
	for city_seed: int in seeds:
		for scale_id: StringName in scale_ids:
			attempted += 1
			var profile := WarrenVillageScaleProfile.select(city_seed) \
				if scale_id == StringName() \
				else WarrenVillageScaleProfile.for_id(scale_id)
			var started := Time.get_ticks_msec()
			var plan := WarrenVolumetricSolver.solve(city_seed, {}, program,
				profile)
			var elapsed := Time.get_ticks_msec() - started
			total_ms += elapsed
			if plan != null:
				sealed_count += 1
				rows.append({"seed": city_seed,
					"scale": String(profile.scale_id), "ms": elapsed,
					"sealed": true, "gate": "", "failure": ""})
				print("SWEEP seed=%d scale=%s ms=%d SEALED rooms=%s" % [
					city_seed, String(profile.scale_id), elapsed,
					str(plan.audit.get("room_storey_kind_counts", {}))])
				var fabric := plan.compiled_fabric_cache()
				if fabric != null:
					stone_towns += 1
					stone_faces += int(fabric.audit.get(
						"maze_stone_profiled_face_count", 0))
					stone_high_faces += int(fabric.audit.get(
						"maze_stone_high_face_count", 0))
					stone_plot_mass_high += int(fabric.audit.get(
						"maze_stone_plot_mass_high_face_count", 0))
					stone_raised_high += int(fabric.audit.get(
						"maze_stone_raised_shoulder_high_face_count", 0))
					print(("SWEEP seed=%d scale=%s STONE faces=%d high=%d " \
						+ "ratio=%.4f plot_mass_high=%d raised_high=%d " \
						+ "max=%d bands=%s") % [city_seed,
						String(profile.scale_id),
						int(fabric.audit.get(
							"maze_stone_profiled_face_count", 0)),
						int(fabric.audit.get(
							"maze_stone_high_face_count", 0)),
						float(fabric.audit.get(
							"maze_stone_high_face_ratio", 0.0)),
						int(fabric.audit.get(
							"maze_stone_plot_mass_high_face_count", 0)),
						int(fabric.audit.get(
							"maze_stone_raised_shoulder_high_face_count", 0)),
						int(fabric.audit.get(
							"maze_stone_max_band_offset", 0)),
						str(fabric.audit.get(
							"maze_stone_band_histogram", {}))])
				continue
			var failure := WarrenVolumetricSolver.last_failure
			rows.append({"seed": city_seed, "scale": String(profile.scale_id),
				"ms": elapsed, "sealed": false, "gate": _gate_of(failure),
				"failure": failure.left(240)})
			print("SWEEP seed=%d scale=%s ms=%d FAILED gate=[%s] reason=%s" % [
				city_seed, String(profile.scale_id), elapsed,
				_gate_of(failure), failure.left(160)])
	print("SWEEP RESULT mode=%s sealed=%d/%d total_ms=%d" % [String(mode),
		sealed_count, attempted, total_ms])
	# The corpus mean ruling 1 asks for: one ratio over every stone face in
	# every town that compiled, not the mean of the per-town ratios, so a big
	# town cannot be averaged away by a small one.
	print(("SWEEP RESULT stone towns=%d faces=%d above_2_storeys=%d " \
		+ "corpus_ratio=%.4f of which plot_mass=%d raised_shoulder=%d") % [
		stone_towns, stone_faces, stone_high_faces,
		float(stone_high_faces) / float(maxi(1, stone_faces)),
		stone_plot_mass_high, stone_raised_high])
	_write_summary(mode, seeds, scale_ids, rows, sealed_count, attempted,
		total_ms)
	quit()


func _write_summary(mode: StringName, seeds: Array[int],
		scale_ids: Array[StringName], rows: Array[Dictionary],
		sealed_count: int, attempted: int, total_ms: int) -> void:
	## The matrix as data. `seeds` and `scales` are written so a reader can tell
	## a full 24-town corpus run from a three-seed spot check and refuse to
	## score itself against the wrong one, and `fingerprint` so it can tell a
	## matrix measured on THIS code from one left behind by an earlier tree.
	var scales := PackedStringArray()
	for scale_id: StringName in scale_ids:
		scales.append(String(scale_id))
	var file := FileAccess.open(SUMMARY_PATH, FileAccess.WRITE)
	if file == null:
		print("SWEEP SUMMARY unwritable path=%s" % SUMMARY_PATH)
		return
	file.store_string(JSON.stringify({
		"mode": String(mode),
		"fingerprint": production_fingerprint(),
		"seeds": seeds,
		"scales": scales,
		"sealed": sealed_count,
		"attempted": attempted,
		"total_ms": total_ms,
		"unix_time": int(Time.get_unix_time_from_system()),
		"rows": rows,
	}, "\t"))
	file.close()
	print("SWEEP SUMMARY written path=%s sealed=%d/%d" % [SUMMARY_PATH,
		sealed_count, attempted])


func _gate_of(failure: String) -> String:
	## The head of a failure — enough words to name the gate a town died at
	## without pasting a whole diagnostic into every row of the matrix.
	var words := failure.split(" ", false)
	var kept := PackedStringArray()
	for index in mini(12, words.size()):
		kept.append(words[index])
	return " ".join(kept)


func _run_constructive(seeds: Array[int]) -> void:
	# TASK E4 FOUND THIS. `_init` sets the generation mode only on the path
	# BELOW the `--constructive` branch, so every constructive row since task
	# E1 was measured against the ROUTE-FIRST massif: `WarrenMassifBuilder
	# .is_maze_mode` keys E1's terraced massif to MODE_MAZE until Phase F
	# deletes route-first, and this path never set it. Measured on seed
	# 12/compact, that is a different town -- 28 plots and 144 exterior stone
	# faces route-first against 32 and 180 in maze mode -- so the matrix was
	# describing a generator nobody ships. This path only ever runs
	# `WarrenMazeSitePlanner`, so the mode is unconditional here; `--mode` is
	# documented as irrelevant to it and stays so.
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MAZE
	print("SWEEP constructive seeds=%d scales=%d total=%d" % [seeds.size(),
		CONSTRUCTIVE_SCALES.size(), seeds.size() * CONSTRUCTIVE_SCALES.size()])
	var sealed_count := 0
	var translated_count := 0
	var attempted := 0
	var stone_faces := 0
	var stone_high_faces := 0
	var stone_raised_high := 0
	var raised_shoulders := 0
	for city_seed: int in seeds:
		for scale_id: StringName in CONSTRUCTIVE_SCALES:
			attempted += 1
			var outcome := _constructive_outcome(city_seed, scale_id)
			if outcome.sealed:
				sealed_count += 1
				stone_faces += int(outcome.get("faces", 0))
				stone_high_faces += int(outcome.get("high_faces", 0))
				stone_raised_high += int(outcome.get("raised_high_faces", 0))
				raised_shoulders += int(outcome.get("raised_shoulders", 0))
			if outcome.translated:
				translated_count += 1
			print(String(outcome.line))
	print("SWEEP RESULT constructive sealed=%d/%d translated=%d/%d" % [
		sealed_count, attempted, translated_count, sealed_count])
	# TASK E4 ruling 1's corpus mean on the source side: one ratio over every
	# derived-stone face in every sealed town, not the mean of the per-town
	# ratios. Ruling 2's instrumentation rides beside it.
	print(("SWEEP RESULT constructive stone faces=%d above_2_storeys=%d " \
		+ "corpus_ratio=%.4f raised_shoulder_high=%d raised_shoulders=%d") % [
		stone_faces, stone_high_faces,
		float(stone_high_faces) / float(maxi(1, stone_faces)),
		stone_raised_high, raised_shoulders])


func _constructive_outcome(city_seed: int, scale_id: StringName) -> Dictionary:
	## Runs the real one-pass pipeline for one (seed, scale) cell of the matrix
	## -- WarrenMazeSitePlanner.plan() (massif -> carve -> reserve -> partition
	## -> seal) then, only if that sealed, WarrenMazeVolumeAdapter and
	## WarrenMazeBlockPartitioner (the same production entry points the debug
	## view and the plot tests exercise) -- and reports the plot-model exit
	## metrics. Every source-side number comes off the sealed plan's own plots
	## and audit; every translated number off the parcel plan's audit.
	var profile := WarrenVillageScaleProfile.for_id(scale_id)
	var plan := WarrenMazeSitePlanner.plan(city_seed, {}, profile)
	if plan == null:
		var reason := WarrenMazeSitePlanner.last_failure
		var colon := reason.find(":")
		var stage := reason.left(colon) if colon >= 0 else "unknown"
		return {"sealed": false, "translated": false,
			"line": "SWEEP seed=%d scale=%s sealed=false stage=%s reason=%s" % [
				city_seed, String(scale_id), stage, reason.left(160)]}

	# The source's own stone-band counts ride out on every sealed row, whatever
	# happens downstream, so the corpus mean is measured over every town that
	# SEALED rather than only over the ones that also translated.
	var source := _source_metrics(plan)
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(plan)
	if volume == null:
		var adapter_row := source.duplicate()
		adapter_row.merge({"sealed": true, "translated": false,
			"line": "%s translated=false stage=adapter reason=%s" % [
				String(source.line),
				WarrenMazeVolumeAdapter.last_failure.left(120)]}, true)
		return adapter_row

	var parcels := WarrenMazeBlockPartitioner.partition(plan, volume)
	if parcels == null:
		var partition_row := source.duplicate()
		partition_row.merge({"sealed": true, "translated": false,
			"line": "%s translated=false stage=partition reason=%s" % [
				String(source.line),
				WarrenMazeBlockPartitioner.last_failure.left(120)]}, true)
		return partition_row

	var signature := plan.deterministic_signature().sha256_text().left(12)
	var row := source.duplicate()
	row.merge({"sealed": true, "translated": true,
		"line": ("%s translated=true parcels=%d back_room_cells=%d "
			+ "ownership=%.4f signature=%s") % [
			String(source.line), parcels.parcels.size(),
			int(parcels.audit.get("maze_back_room_cells", 0)),
			float(parcels.audit.get("maze_ownership_ratio", 0.0)), signature]},
		true)
	return row


func _source_metrics(plan: WarrenMazeSourcePlan) -> Dictionary:
	## The sealed plan's own half of a row: what the plot layer built, and how
	## much of the town's skin it left as bare rock. Counted off `plots` and
	## `plot_facts` directly rather than off the planner's own bookkeeping, so
	## a row reports the town that really sealed.
	var counts: Dictionary = {}
	for kind: StringName in WarrenMazeSourcePlan.PLOT_KINDS:
		counts[kind] = 0
	var tiered := 0
	var house_columns := 0
	for plot: Dictionary in plan.plots:
		var kind := StringName(plot["kind"])
		counts[kind] = int(counts.get(kind, 0)) + 1
		tiered += int(bool(plan.plot_facts(plot).tiered))
		if kind == WarrenMazeSourcePlan.PLOT_HOUSE:
			house_columns += (plot["cells"] as Array).size()
	var houses := int(counts[WarrenMazeSourcePlan.PLOT_HOUSE])
	var exterior := plan.audit.get("exterior_rock_ratio", {}) as Dictionary
	# TASK E4 ruling 1's source half: where the town's DERIVED stone stands,
	# relative to the street beside it rather than to the town's own foot.
	# `stone_high` is the share of its exterior stone faces standing more than
	# two storeys over their local public floor. The other half of the same
	# metric -- retained PLOT mass, which the source cannot see -- rides on the
	# compiled fabric and is printed by the plain (non-constructive) sweep.
	var stone := plan.audit.get("exterior_stone_band_profile", {}) as Dictionary
	# `raised_shoulders`: no-plot columns whose sealed rock shoulder stands
	# ABOVE their own massif envelope (review finding 2026-08-23, minor 5).
	# `rock_shoulder` has no upper clamp; this is the measurement that says
	# whether it needs one, and no rule is pinned on it yet.
	return {"faces": int(stone.get("faces", 0)),
		"high_faces": int(stone.get("high_faces", 0)),
		"raised_high_faces": int(stone.get("raised_shoulder_high_faces", 0)),
		"raised_shoulders": plan.raised_shoulder_columns().size(),
		"line": ("SWEEP seed=%d scale=%s sealed=true plots=%d houses=%d "
		+ "assets=%d decks=%d bridges=%d tiered=%d mean_footprint=%.2f "
		+ "exterior_rock=%.4f raised_shoulders=%d stone_faces=%d "
		+ "stone_high=%d stone_high_ratio=%.4f raised_high=%d "
		+ "stone_bands=%s") % [
		plan.world_seed, String(plan.scale_profile.scale_id),
		plan.plots.size(), houses,
		int(counts[WarrenMazeSourcePlan.PLOT_ASSET]),
		int(counts[WarrenMazeSourcePlan.PLOT_DECK]),
		int(counts[WarrenMazeSourcePlan.PLOT_BRIDGE]), tiered,
		float(house_columns) / float(maxi(1, houses)),
		float(exterior.get("ratio", 0.0)),
		plan.raised_shoulder_columns().size(),
		int(stone.get("faces", 0)), int(stone.get("high_faces", 0)),
		float(stone.get("high_face_ratio", 0.0)),
		int(stone.get("raised_shoulder_high_faces", 0)),
		str(stone.get("band_histogram", {}))]}
