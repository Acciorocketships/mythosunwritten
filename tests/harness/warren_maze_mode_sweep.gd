extends SceneTree

## The corpus sweep. Runs the real production entry point over a seed corpus
## and reports seal/failure and wall-clock per seed. The source itself is
## cheap, so a rejection is usually fast; a slow rejection means the
## composition ran and failed downstream.
##
##   Godot --headless --path . -s res://tests/harness/warren_maze_mode_sweep.gd -- \
##     --seeds 1,2,3,4,5,6,7,8,9,10,11,12 --scale compact,standard,large,grand
##
## TASK F4 added the two big scales. They were unexercised by every sweep before
## it because the elevated-courtyard floor refused all 24 of them, so the matrix
## measured half the size profiles production actually rolls (~15 % of city
## seeds roll large or grand). The full 48-town matrix costs the wall clock
## printed in `SWEEP RESULT` and is what `test_corpus_composes` scores itself
## against.
##
## THE FULL MATRIX IS MANDATORY. An earlier version of this comment offered a
## "reduced large/grand seed list ... when the full one is unaffordable", which
## this harness cannot express and the corpus gate would not accept: `--seeds`
## is global to every scale, so there is no way to give large fewer seeds than
## compact, and `test_corpus_composes` asserts `rows.size() == seeds x scales`,
## which HARD-FAILS a short matrix rather than pending it. The capability was
## not built; the promise is withdrawn. `SWEEP RESULT per_scale` below states
## the shape that was actually measured — as evidence, not as a licence to
## measure less.
##
## Each row names the GATE the town died at -- the head of the solver's own
## failure -- so a corpus-wide run reads as a disposition of gates rather than a
## count of rejections. `--scale compact,standard,large,grand` runs every seed
## at each named profile instead of the one WarrenVillageScaleProfile.select()
## rolls for it, which is how the corpus matrix is measured.
##
## TASK F1 RULING 6. `--mode` and `--constructive` died with the searched
## pipeline: there is one path, so there is nothing to select. Passing either
## is an ERROR rather than a silent no-op, so stale muscle memory surfaces at
## the first run instead of in a matrix that measured something else.

## TASK C6 RULING 3. Where the corpus matrix is left for
## `tests/test_warren_maze_composition.gd::test_corpus_composes` to assert.
## The composition suite has a ~4 min budget and cannot afford 24 more
## production solves, so the sweep — which already runs them — writes the
## matrix down and the test reads it. `user://` because that is where every
## other machine-local harness artifact in this repository lives
## (`heightfield_shot`).
const SUMMARY_PATH := "user://warren_maze_mode_sweep.json"

## The directory whose contents decide the matrix. A sweep summary is only
## evidence about the code that produced it, so it carries a fingerprint of
## every script in the village fabric layer and the test refuses a summary
## whose fingerprint no longer matches the tree it is running against. The
## whole directory rather than a hand-kept list of files: a list is a thing
## that goes stale silently, and a stale list is exactly the failure mode this
## fingerprint exists to prevent.
const PRODUCTION_SCRIPT_DIR := "res://scripts/terrain/features/villages/fabric"

## TASK F4. The two stone tallies. `CORPUS_STONE_GROUP` prints the untagged
## `SWEEP RESULT stone` line Phase E's exit number was read off; the scales that
## joined the matrix at task F4 print their own tagged line.
const CORPUS_STONE_GROUP := "compact,standard"
const ADDED_STONE_GROUP := "large,grand"


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
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--seeds" and index + 1 < args.size():
			for token: String in args[index + 1].split(",", false):
				seeds.append(int(token.strip_edges()))
		elif args[index] == "--scale" and index + 1 < args.size():
			for token: String in args[index + 1].split(",", false):
				scale_ids.append(StringName(token.strip_edges()))
		elif args[index] == "--mode" or args[index] == "--constructive":
			print("SWEEP ERROR retired flag %s: it died with the searched " % \
				args[index] + "pipeline; there is one generation path now")
			push_error("retired sweep flag %s" % args[index])
			quit(2)
			return
	if seeds.is_empty():
		seeds = [1, 2, 3, 4, 5, 6, 7, 8, 9]
	if scale_ids.is_empty():
		# The empty id means "whatever this seed rolls" — the profile
		# production would actually pick for it.
		scale_ids = [StringName()]

	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	print("SWEEP seeds=%d scales=%d" % [seeds.size(), scale_ids.size()])

	var sealed_count := 0
	var attempted := 0
	var total_ms := 0
	var rows: Array[Dictionary] = []
	# TASK F4. Seals per scale, so a matrix over four profiles reports which of
	# them the towns came from instead of one number the reader has to split by
	# hand. Compact and standard are pinned at 12/12; large and grand are pinned
	# at what they honestly measure.
	var sealed_by_scale: Dictionary = {}
	var attempted_by_scale: Dictionary = {}
	# TASK E4 ruling 1. The corpus half of the stone-band profile: this path
	# runs the REAL compile, so every sealed town carries the assembler's own
	# shell measured against its local street datum, and the corpus mean is
	# the number Phase E exits on.
	#
	# TASK F4 accumulates it PER SCALE GROUP. That `SWEEP RESULT stone` line is
	# the Phase E exit measurement over the compact/standard corpus; folding the
	# two big scales into it would silently redefine a number already written
	# down. The added scales get their own line with the same shape.
	var stone_by_group: Dictionary = {
		CORPUS_STONE_GROUP: _new_stone_tally(),
		ADDED_STONE_GROUP: _new_stone_tally(),
	}
	for city_seed: int in seeds:
		for scale_id: StringName in scale_ids:
			attempted += 1
			var profile := WarrenVillageScaleProfile.select(city_seed) \
				if scale_id == StringName() \
				else WarrenVillageScaleProfile.for_id(scale_id)
			var group := _stone_group_of(profile.scale_id)
			attempted_by_scale[String(profile.scale_id)] = 1 + int(
				attempted_by_scale.get(String(profile.scale_id), 0))
			var started := Time.get_ticks_msec()
			var plan := WarrenVolumetricSolver.solve(city_seed, {}, program,
				profile)
			var elapsed := Time.get_ticks_msec() - started
			total_ms += elapsed
			if plan != null:
				sealed_count += 1
				sealed_by_scale[String(profile.scale_id)] = 1 + int(
					sealed_by_scale.get(String(profile.scale_id), 0))
				rows.append({"seed": city_seed,
					"scale": String(profile.scale_id), "ms": elapsed,
					"sealed": true, "gate": "", "failure": ""})
				print("SWEEP seed=%d scale=%s ms=%d SEALED rooms=%s" % [
					city_seed, String(profile.scale_id), elapsed,
					str(plan.audit.get("room_storey_kind_counts", {}))])
				var fabric := plan.compiled_fabric_cache()
				if fabric != null:
					_accumulate_stone(stone_by_group[group] as Dictionary,
						fabric)
					# TASK E4 FIX 2. `trimmed=` carries BOTH halves of what the
					# trim released. It used to print the unroomed half alone
					# and so read `trimmed=0` on 4/compact, the town whose whole
					# 80-cell release was roof band -- a row that said the trim
					# had done nothing on a town where it did the most.
					var trimmed_unroomed := int(plan.audit.get(
						"maze_trimmed_unroomed_plot_stone_cells", 0))
					var trimmed_roof := int(plan.audit.get(
						"maze_trimmed_roof_band_stone_cells", 0))
					print(("SWEEP seed=%d scale=%s STONE faces=%d high=%d " \
						+ "ratio=%.4f roof_high=%d unroomed_high=%d " \
						+ "raised_high=%d grounded=%d max=%d " \
						+ "trimmed=%d (unroomed=%d roof=%d) " \
						+ "refused_trims=%d bands=%s") % [city_seed,
						String(profile.scale_id),
						int(fabric.audit.get(
							"maze_stone_profiled_face_count", 0)),
						int(fabric.audit.get(
							"maze_stone_high_face_count", 0)),
						float(fabric.audit.get(
							"maze_stone_high_face_ratio", 0.0)),
						int(fabric.audit.get(
							"maze_stone_roof_band_high_face_count", 0)),
						int(fabric.audit.get(
							"maze_stone_unroomed_high_face_count", 0)),
						int(fabric.audit.get(
							"maze_stone_raised_shoulder_high_face_count", 0)),
						int(fabric.audit.get(
							"maze_stone_grounded_face_count", 0)),
						int(fabric.audit.get(
							"maze_stone_max_band_offset", 0)),
						trimmed_unroomed + trimmed_roof, trimmed_unroomed,
						trimmed_roof,
						int(plan.audit.get(
							"maze_refused_unroomed_plot_trims", 0)),
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
	print("SWEEP RESULT sealed=%d/%d total_ms=%d" % [sealed_count, attempted,
		total_ms])
	# TASK F4. The matrix's own shape, printed beside its result: which scales
	# ran, how many seeds each got, and what each sealed. It exists so a reader
	# can tell a full corpus run from a spot check at a glance, and so the
	# per-scale seal counts the corpus gate pins are legible in the log that
	# produced them.
	var per_scale := PackedStringArray()
	for scale_name: String in attempted_by_scale.keys():
		per_scale.append("%s=%d/%d" % [scale_name,
			int(sealed_by_scale.get(scale_name, 0)),
			int(attempted_by_scale[scale_name])])
	per_scale.sort()
	print("SWEEP RESULT per_scale %s" % " ".join(per_scale))
	# The corpus mean ruling 1 asks for: one ratio over every stone face in
	# every town that compiled, not the mean of the per-town ratios, so a big
	# town cannot be averaged away by a small one.
	_print_stone_result(CORPUS_STONE_GROUP,
		stone_by_group[CORPUS_STONE_GROUP] as Dictionary)
	_print_stone_result(ADDED_STONE_GROUP,
		stone_by_group[ADDED_STONE_GROUP] as Dictionary)
	_write_summary(seeds, scale_ids, rows, sealed_count, attempted, total_ms)
	quit()


static func _new_stone_tally() -> Dictionary:
	return {"towns": 0, "faces": 0, "high": 0, "plot_mass_high": 0,
		"roof_high": 0, "unroomed_high": 0, "raised_high": 0, "max_offset": 0}


static func _stone_group_of(scale_id: StringName) -> String:
	## Which stone tally a sealed town belongs to. Compact and standard are the
	## corpus Phase E measured; large and grand joined the sweep at task F4.
	return CORPUS_STONE_GROUP if scale_id in [
		WarrenVillageScaleProfile.COMPACT,
		WarrenVillageScaleProfile.STANDARD] else ADDED_STONE_GROUP


static func _accumulate_stone(tally: Dictionary,
		fabric: SettlementFabricPlan) -> void:
	tally.towns += 1
	tally.faces += int(fabric.audit.get("maze_stone_profiled_face_count", 0))
	tally.high += int(fabric.audit.get("maze_stone_high_face_count", 0))
	tally.plot_mass_high += int(fabric.audit.get(
		"maze_stone_plot_mass_high_face_count", 0))
	tally.raised_high += int(fabric.audit.get(
		"maze_stone_raised_shoulder_high_face_count", 0))
	tally.roof_high += int(fabric.audit.get(
		"maze_stone_roof_band_high_face_count", 0))
	tally.unroomed_high += int(fabric.audit.get(
		"maze_stone_unroomed_high_face_count", 0))
	tally.max_offset = maxi(int(tally.max_offset), int(fabric.audit.get(
		"maze_stone_max_band_offset", 0)))


func _print_stone_result(group: String, tally: Dictionary) -> void:
	## The corpus group keeps the EXACT line Phase E's exit number was read off;
	## the added group is tagged and suppressed entirely when it ran no towns, so
	## a compact/standard-only sweep prints byte-identically to before task F4.
	if int(tally.towns) == 0 and group != CORPUS_STONE_GROUP:
		return
	print(("SWEEP RESULT stone%s towns=%d faces=%d above_2_storeys=%d " \
		+ "corpus_ratio=%.4f of which plot_mass=%d (roof_band=%d " \
		+ "unroomed=%d) raised_shoulder=%d worst_max_offset=%d") % [
		"" if group == CORPUS_STONE_GROUP else "/%s" % group,
		int(tally.towns), int(tally.faces), int(tally.high),
		float(int(tally.high)) / float(maxi(1, int(tally.faces))),
		int(tally.plot_mass_high), int(tally.roof_high),
		int(tally.unroomed_high), int(tally.raised_high),
		int(tally.max_offset)])


func _write_summary(seeds: Array[int],
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
