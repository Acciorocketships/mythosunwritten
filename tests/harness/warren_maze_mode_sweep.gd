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
	# TASK H1. The wall tally, accumulated in the same two groups and for the
	# same reason: the corpus line is a number somebody will write down, so the
	# scales that joined the matrix at F4 get their own tagged line rather than
	# being folded into it.
	var walls_by_group: Dictionary = {
		CORPUS_STONE_GROUP: _new_wall_tally(),
		ADDED_STONE_GROUP: _new_wall_tally(),
	}
	# TASK H2. The ROOFSCAPE tally, in the same two groups and for the same
	# reason. STONE is what the massif shows, WALLS is what the town wears,
	# ROOFS is what it is covered by -- three questions about one frame, and a
	# reader who wants "did the village get its pitched roofs back" should not
	# have to infer it from the other two.
	var roofs_by_group: Dictionary = {
		CORPUS_STONE_GROUP: _new_roof_tally(),
		ADDED_STONE_GROUP: _new_roof_tally(),
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
					# TASK H1. The WALL metric on its own row directly under the
					# rock one, because they answer two different questions
					# about the same frame and neither is the other: STONE is
					# how much retained MOUNTAIN shows, WALLS is what the town
					# WEARS. `frag` is the user's named base defect, pinned at
					# zero.
					_accumulate_walls(walls_by_group[group] as Dictionary,
						fabric)
					print(("SWEEP seed=%d scale=%s WALLS faces=%d stone=%d " \
						+ "ratio=%.4f high_stone=%d high_ratio=%.4f " \
						+ "off_datum=%d min=%d max=%d frag=%d/%d " \
						+ "stone_bands=%s") % [city_seed,
						String(profile.scale_id),
						int(fabric.audit.get("exterior_wall_face_count", 0)),
						int(fabric.audit.get(
							"exterior_wall_stone_face_count", 0)),
						float(fabric.audit.get(
							"exterior_wall_stone_face_ratio", 0.0)),
						int(fabric.audit.get(
							"exterior_wall_high_stone_face_count", 0)),
						float(fabric.audit.get(
							"exterior_wall_high_stone_face_ratio", 0.0)),
						int(fabric.audit.get(
							"exterior_wall_off_datum_face_count", 0)),
						int(fabric.audit.get(
							"exterior_wall_min_band_offset", 0)),
						int(fabric.audit.get(
							"exterior_wall_max_band_offset", 0)),
						int(fabric.audit.get("fragmented_base_run_count", 0)),
						int(fabric.audit.get("base_face_run_count", 0)),
						str(fabric.audit.get(
							"exterior_wall_stone_band_histogram", {}))])
					# TASK H2. The roofscape row. `pitched` over `crowns` is
					# the share the phase exists to move; `rubble` is the
					# masonry lid pinned at zero; `dressed` is the terrace
					# furnishing the battery measured at zero before this task;
					# `boxes` is the isolated flat lineage the second reference
					# batch names; `brackets` is "we can't have floating
					# buildings" counted on the rendered side, with
					# `bare_overhangs` the ones that compiled without one.
					_accumulate_roofs(roofs_by_group[group] as Dictionary,
						fabric)
					print(("SWEEP seed=%d scale=%s ROOFS crowns=%d " \
						+ "pitched=%d share=%.4f flat=%d tiled=%d " \
						+ "refused=%d partial=%d dormers=%d dressed=%d/%d " \
						+ "chimneys=%d awnings=%d boxes=%d rails=%d " \
						+ "rubble=%d (paved=%d borne=%d bearing=%d) " \
						+ "brackets=%d " \
						+ "bare_overhangs=%d families=%s") % [city_seed,
						String(profile.scale_id),
						int(fabric.audit.get("plot_flat_roof_room_count", 0)),
						int(fabric.audit.get("maze_pitched_roof_count", 0)),
						float(int(fabric.audit.get(
							"maze_pitched_roof_count", 0))) / float(maxi(1,
							int(fabric.audit.get(
								"plot_flat_roof_room_count", 0)))),
						int(fabric.audit.get("plot_flat_roof_count", 0)),
						int(fabric.audit.get(
							"maze_partial_plate_tiled_count", 0)),
						int(fabric.audit.get(
							"maze_pitched_refused_count", 0)),
						int(fabric.audit.get(
							"maze_pitched_partial_plate_count", 0)),
						int(fabric.audit.get("dormered_roof_unit_count", 0)),
						int(fabric.audit.get("maze_dressed_crown_count", 0)),
						int(fabric.audit.get("maze_dressed_crown_count", 0)) \
							+ int(fabric.audit.get(
								"maze_bare_crown_count", 0)),
						int(fabric.audit.get("maze_crown_chimney_count", 0)),
						int(fabric.audit.get("maze_crown_awning_count", 0)),
						int(fabric.audit.get(
							"maze_isolated_flat_crown_count", 0)),
						int(fabric.audit.get(
							"maze_terrace_railing_count", 0)),
						int(fabric.audit.get(
							"maze_rubble_crown_cap_count", 0)),
						int(fabric.audit.get(
							"maze_paved_crown_cap_count", 0)),
						int(fabric.audit.get(
							"maze_borne_crown_cap_count", 0)),
						int(fabric.audit.get(
							"maze_bearing_crown_cap_count", 0)),
						int(fabric.audit.get(
							"overhang_bracket_unit_count", 0)),
						int(fabric.audit.get(
							"bracketless_overhang_feature_count", 0)),
						str(fabric.audit.get(
							"pitched_roof_family_counts", {}))])
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
	_print_wall_result(CORPUS_STONE_GROUP,
		walls_by_group[CORPUS_STONE_GROUP] as Dictionary)
	_print_wall_result(ADDED_STONE_GROUP,
		walls_by_group[ADDED_STONE_GROUP] as Dictionary)
	_print_roof_result(CORPUS_STONE_GROUP,
		roofs_by_group[CORPUS_STONE_GROUP] as Dictionary)
	_print_roof_result(ADDED_STONE_GROUP,
		roofs_by_group[ADDED_STONE_GROUP] as Dictionary)
	_write_summary(seeds, scale_ids, rows, sealed_count, attempted, total_ms)
	quit()


static func _new_stone_tally() -> Dictionary:
	return {"towns": 0, "faces": 0, "high": 0, "plot_mass_high": 0,
		"roof_high": 0, "unroomed_high": 0, "raised_high": 0, "max_offset": 0}


static func _new_wall_tally() -> Dictionary:
	return {"towns": 0, "faces": 0, "stone": 0, "high_stone": 0,
		"off_datum": 0, "runs": 0, "fragmented": 0, "worst_ratio": 0.0,
		"max_offset": 0}


static func _accumulate_walls(tally: Dictionary,
		fabric: SettlementFabricPlan) -> void:
	tally.towns += 1
	tally.faces += int(fabric.audit.get("exterior_wall_face_count", 0))
	tally.stone += int(fabric.audit.get("exterior_wall_stone_face_count", 0))
	tally.high_stone += int(fabric.audit.get(
		"exterior_wall_high_stone_face_count", 0))
	tally.off_datum += int(fabric.audit.get(
		"exterior_wall_off_datum_face_count", 0))
	tally.runs += int(fabric.audit.get("base_face_run_count", 0))
	tally.fragmented += int(fabric.audit.get("fragmented_base_run_count", 0))
	tally.worst_ratio = maxf(float(tally.worst_ratio), float(fabric.audit.get(
		"exterior_wall_stone_face_ratio", 0.0)))
	tally.max_offset = maxi(int(tally.max_offset), int(fabric.audit.get(
		"exterior_wall_max_band_offset", 0)))


static func _new_roof_tally() -> Dictionary:
	## TASK H2. The corpus roofscape tally.
	return {"towns": 0, "crowns": 0, "pitched": 0, "flat": 0, "tiled": 0,
		"refused": 0, "partial": 0, "dormers": 0, "dressed": 0, "bare": 0,
		"chimneys": 0, "awnings": 0, "boxes": 0, "rubble": 0, "paved": 0,
		"borne": 0, "bearing": 0, "brackets": 0, "bare_overhangs": 0,
		"worst_rubble": 0,
		"worst_share": 1.0}


static func _accumulate_roofs(tally: Dictionary,
		fabric: SettlementFabricPlan) -> void:
	var crowns := int(fabric.audit.get("plot_flat_roof_room_count", 0))
	var pitched := int(fabric.audit.get("maze_pitched_roof_count", 0))
	tally.towns += 1
	tally.crowns += crowns
	tally.pitched += pitched
	tally.flat += int(fabric.audit.get("plot_flat_roof_count", 0))
	tally.tiled += int(fabric.audit.get("maze_partial_plate_tiled_count", 0))
	tally.refused += int(fabric.audit.get("maze_pitched_refused_count", 0))
	tally.partial += int(fabric.audit.get(
		"maze_pitched_partial_plate_count", 0))
	tally.dormers += int(fabric.audit.get("dormered_roof_unit_count", 0))
	tally.dressed += int(fabric.audit.get("maze_dressed_crown_count", 0))
	tally.bare += int(fabric.audit.get("maze_bare_crown_count", 0))
	tally.chimneys += int(fabric.audit.get("maze_crown_chimney_count", 0))
	tally.awnings += int(fabric.audit.get("maze_crown_awning_count", 0))
	tally.boxes += int(fabric.audit.get("maze_isolated_flat_crown_count", 0))
	tally.rubble += int(fabric.audit.get("maze_rubble_crown_cap_count", 0))
	tally.paved += int(fabric.audit.get("maze_paved_crown_cap_count", 0))
	tally.borne += int(fabric.audit.get("maze_borne_crown_cap_count", 0))
	tally.bearing += int(fabric.audit.get("maze_bearing_crown_cap_count", 0))
	tally.brackets += int(fabric.audit.get("overhang_bracket_unit_count", 0))
	tally.bare_overhangs += int(fabric.audit.get(
		"bracketless_overhang_feature_count", 0))
	tally.worst_rubble = maxi(int(tally.worst_rubble), int(fabric.audit.get(
		"maze_rubble_crown_cap_count", 0)))
	tally.worst_share = minf(float(tally.worst_share),
		float(pitched) / float(maxi(1, crowns)))


func _print_roof_result(group: String, tally: Dictionary) -> void:
	## TASK H2. One share over every crown in every town that compiled, beside
	## the WORST town's share -- a corpus mean can look like a village while one
	## town is still a field of boxes. `rubble` is pinned at zero corpus-wide
	## and `worst_rubble` says whether any single town carries one.
	if int(tally.towns) == 0:
		return
	print(("SWEEP RESULT roofs%s towns=%d crowns=%d pitched=%d " \
		+ "corpus_share=%.4f worst_town_share=%.4f flat=%d tiled=%d " \
		+ "refused=%d partial=%d dormers=%d dressed=%d/%d chimneys=%d " \
		+ "awnings=%d boxes=%d rubble=%d worst_rubble=%d (paved=%d " \
		+ "borne=%d bearing=%d) brackets=%d bare_overhangs=%d") % [
		"" if group == CORPUS_STONE_GROUP else "/%s" % group,
		int(tally.towns), int(tally.crowns), int(tally.pitched),
		float(int(tally.pitched)) / float(maxi(1, int(tally.crowns))),
		float(tally.worst_share), int(tally.flat), int(tally.tiled),
		int(tally.refused), int(tally.partial), int(tally.dormers),
		int(tally.dressed), int(tally.dressed) + int(tally.bare),
		int(tally.chimneys), int(tally.awnings), int(tally.boxes),
		int(tally.rubble), int(tally.worst_rubble), int(tally.paved),
		int(tally.borne), int(tally.bearing), int(tally.brackets),
		int(tally.bare_overhangs)])


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


func _print_wall_result(group: String, tally: Dictionary) -> void:
	## TASK H1. One ratio over every exterior wall face in every town that
	## compiled, not the mean of the per-town ratios, so a big town cannot be
	## averaged away by a small one -- the same reading `_print_stone_result`
	## takes of the rock skin. `worst_town_ratio` is beside it because a corpus
	## mean can sit inside a ceiling while one town wears a fortress.
	if int(tally.towns) == 0:
		return
	print(("SWEEP RESULT walls%s towns=%d faces=%d stone=%d " \
		+ "corpus_ratio=%.4f worst_town_ratio=%.4f high_stone=%d " \
		+ "off_datum=%d base_runs=%d fragmented=%d worst_max_offset=%d") % [
		"" if group == CORPUS_STONE_GROUP else "/%s" % group,
		int(tally.towns), int(tally.faces), int(tally.stone),
		float(int(tally.stone)) / float(maxi(1, int(tally.faces))),
		float(tally.worst_ratio), int(tally.high_stone),
		int(tally.off_datum), int(tally.runs), int(tally.fragmented),
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
