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

## TASK H2c FIX 1. THE CLEARANCE ROW's dimensions.
##
## The player's own capsule, copied from `characters/character.tscn`'s
## `Character/CollisionShape3D` (the body shape; the 0.390 x 2.092 capsule in
## that scene is the `Spine/SpineHitbox` area, not the body). Copied rather than
## loaded because loading the scene here would drag four character models into
## a headless sweep to learn two floats -- but it is a COPY, so a body that
## grows needs these two lines changed with it.
const PLAYER_CAPSULE_RADIUS := 0.39746094
const PLAYER_CAPSULE_HEIGHT := 2.244
## Godot's `PhysicsShapeQueryParameters3D.margin` defaults to 0.0, which counts
## a cell free when a body clears it by a micron. Two centimetres is the
## smallest gap worth calling a gap.
const CLEARANCE_MARGIN := 0.02
## How far the capsule's underside sits above the cell floor, ON TOP of the
## margin: the margin grows the query shape in every direction, so without this
## the green cap's own floor plate would be the thing reporting a blockage.
const CLEARANCE_FLOOR_LIFT := 0.02
## The lattice tried inside a cell once its centreline is blocked, so a street
## that is merely NARROWED reads differently from one that is shut.
const CLEARANCE_OFFSET_STEPS := 7
## How many offending cells or boundaries the corpus line names before it stops
## listing. A pin that fires wants a place to look, not a full inventory.
const CLEARANCE_WORST_LIMIT := 8
## The town's own route graph, as steps between walked cells: the four lateral
## neighbours at the same band, and the same four one band up or down -- which is
## how this fabric climbs. A component analysis that omitted the vertical steps
## would report a town in pieces because of its STAIRS and call it a broken
## street; including them is what makes "did a collider split this town" a
## question about the collider.
const CLEARANCE_ROUTE_STEPS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	Vector3i(1, 1, 0), Vector3i(-1, 1, 0), Vector3i(0, 1, 1), Vector3i(0, 1, -1),
	Vector3i(1, -1, 0), Vector3i(-1, -1, 0), Vector3i(0, -1, 1),
	Vector3i(0, -1, -1),
]
## The most cell boundaries any ONE town may shut. MEASURED, not designed: the
## corpus shuts some, and pretending otherwise would mean pinning a zero that
## has never been true. The shard's lobe stands 0.155-0.595 m proud of its
## boundary and where two of them meet across a crossing, or one wide one lies
## along it, a body cannot pass -- exactly the risk task H2c's report raised as
## its first concern and could only measure on four towns by hand. Per TOWN
## rather than per corpus so the number means the same thing whatever seed set
## a sweep is given. A RISE means the skin has pinched more streets than it did
## and wants looking at. The number is the worst town of the 48-town matrix
## (12 seeds x compact,standard,large,grand) and it is now ZERO: after task H2c
## fix round 1 not one crossing in the corpus is shut. It was 18 on 9/grand
## against 139 shut crossings before the rock cut, and 2 against 4 before the
## coursed trim that followed it.
##
## `splits` and `cells_unreachable` are pinned at ZERO beside it, and those two
## ARE the serious pins: a shut crossing with a way round narrows a street, a
## shut crossing without one breaks it.
##
## ALL FOUR PINS ARE GREEN AND MEASURED, which is the state task H2c fix round 1
## left. Getting here took two passes over the same defect in two materials:
## `SettlementFabricAssembler`'s ROCK CUT took the corpus from 43 split route
## components and 988 stranded walked cells to 2 and 16, and the COURSED TRIM
## that followed took the last two towns to zero. Both are the same mechanism --
## a module taller than the band it clads, hanging into a street that runs under
## it -- so if a future skin module is introduced with the same habit, look here
## first.
##
## A red here is therefore a REGRESSION, not a known debt. The matrix summary is
## written before any exit, so the corpus gate reads its matrix either way.
##
## TASK I1: 0 -> 2 AND BACK TO 0, AND THE ROUND TRIP IS THE RECORD WORTH
## KEEPING. The halved footprints put three walked cells of the 45 sealed towns
## under a skin module that stands in them — `3/compact` (-5,3,-2), `6/grand`
## (-1,4,6) and `10/grand` (3,2,8), four shut crossings between them — and task
## I1's first landing PINNED that at 2 instead of fixing it.
##
## Fix round 1 named the mechanism and closed it. It is not the shard's lobe
## this file's note above suspected: it is an UNPAIRED CAP, the same 3 m masonry
## module laid FLAT over a 1.5 m cell, reaching 0.75 m past the run it closes
## and into the street beside it — 0.750 m left of a 1.5 m cell against a
## 0.795 m body, so the capsule fits nowhere. The skin's own trim machinery now
## covers that third axis (`SettlementFabricAssembler
## .maze_stone_cap_juts_over_walk`), and the 48-town matrix measures ZERO
## blocked cells, ZERO shut crossings, ZERO splits and ZERO unreachable cells.
## `CLEARANCE_BLOCKED_CELL_CEILING`, which existed for exactly one matrix run,
## is gone with the defect it recorded.
##
## Pinned at the measured worst town rather than at the corpus total, for the
## reason the offset ceilings below are: a per-corpus number means one thing on
## this matrix and another on a spot check. ONE shut crossing anywhere is red.
const CLEARANCE_TOWN_GATE_CEILING := 0
## TASK H2c FIX 2, MINOR 5. THE TWO COSTS, PINNED -- because a collapse has to
## be visible in reverse. The rock cut took `offset_free` from 1096 walked cells
## (12.57 %) to 69 (0.79 %) and `gates_offset` from 877 crossings (7.10 %) to
## 147 (1.19 %), and until now those were REPORTED and nothing more: revert the
## cut and both numbers walk back up in silence while every pin stays green,
## because the pins below them only count what is fully shut.
##
## Per TOWN and not per corpus, for the same reason the gate ceiling above is:
## a corpus total means one thing on the 48-town matrix and something else on
## any other seed set, and a pin that fires on a spot check is a pin people
## learn to ignore. The two numbers are the WORST TOWN of that matrix -- 9/grand
## both times, 9 cells and 15 crossings -- and the corpus they roll up to is 69
## and 147, printed on the result line beside them.
##
## These are COSTS, not damage. A cell counted here still admits a body and a
## crossing counted here can still be walked; what they say is that the shard's
## lobe is in the way of the exact centreline. A rise means the skin leans into
## more streets than it did, which is worth a look and is not by itself a bug.
##
## TASK I2 TAKES BOTH TO ZERO, and it is the shard leaving that does it. The
## 48-town matrix on the shipped tree measures `offset_free = 0` of 9152 walked
## cells and `gates_offset = 0` of 13042 crossings, against 69 and 147 at task
## I1's baseline: every walked cell in the corpus now admits a body on its exact
## centreline. The mechanism is one line of `_maze_facade_transform` -- a facade
## panel is pinned by its OUTER face to the boundary and stands 0.000 m into the
## cell it faces, where the shard stood 0.375 m plus its relief -- and the
## panels it replaced are 58 % of every exposed vertical face in the corpus.
##
## THE MARGIN THAT IS LEFT IS 1.2 MILLIMETRES, and a reader who sees this row go
## red should look here before anywhere else. What still straddles a boundary is
## the coursed retaining course: the module is 0.66389 m deep and centred, so two
## of them facing each other across a one-cell street leave
## 1.5 - 2 x 0.33194 = 0.83612 m against a capsule that needs
## 0.79492 + 2 x 0.02 = 0.83492 m. It fits by 0.00120 m. Nothing in the corpus
## is tighter and nothing in the corpus fails, but a re-bake that deepened
## `sfv.fabric.wall.rock.plain.001` by a centimetre would put this row red
## without any code changing -- and that is the tripwire firing correctly, not a
## false alarm. The fix THEN is the trim machinery this file already documents,
## applied to the coursed panel's depth rather than its height.
const CLEARANCE_TOWN_OFFSET_FREE_CEILING := 0
const CLEARANCE_TOWN_GATES_OFFSET_CEILING := 0

## TASK I3 FIX 1, IMPORTANT 1. THE SKYWALK CHANNEL'S FLOOR, per scale group, and
## it is a RATCHET rather than a safety pin: the two above say a street is
## passable, and these say the town still flies bridges over it.
##
## Why the channel needs one at all. A span is six structural facts and a seeded
## tie-break, so nothing in the corpus PROMISES a bridge -- and the composition
## suite's own corpus honestly contains a town (12/compact) that builds none.
## Without a floor, a change that made any one of the six facts unsatisfiable --
## a walked set that stopped including crown decks, a headroom rule off by a
## band, an occluder map that grew -- would take every bridge in all 45 sealed
## towns and leave every other pin in this file green, because every other pin
## counts what is THERE. The outcropping channel and the plaza already have
## their equivalents in the composition suite; this is the skywalk's.
##
## MEASURED, not designed, and pinned AT the measurement rather than under it:
## the 48-town matrix flies 42 spans over its 24 sealed compact/standard towns
## and 192 over its 21 sealed large/grand ones. The towns are a pure function of
## their seeds -- `warren_maze_identity_probe` repeats the same fabric on every
## run of the same seed, and the corpus matrix has reproduced these two numbers
## across machines -- so there is no per-machine variation to guard against and
## no honest reason to leave slack under the number. A fall is a report to
## write, not a tolerance to have budgeted for.
const LIFE_SPAN_FLOOR_BY_GROUP: Dictionary = {
	CORPUS_STONE_GROUP: 42,
	ADDED_STONE_GROUP: 192,
}
## The matrix those floors were measured on. A corpus TOTAL means nothing on a
## three-seed spot check, so unlike the clearance ceilings (which are per-town
## and therefore mean the same thing on any seed set) these are judged only when
## the run actually covered the seeds and the scales they were measured over.
## A bigger run than this one still gets judged: more towns cannot fly fewer
## bridges than the corpus this floor came from.
const LIFE_FLOOR_SEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]


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
	## TASK H2c FIX 1. The body moved to `_run` so the sweep can `await`. The
	## clearance row asks the REAL physics server, and a shape query only sees
	## bodies that a physics frame has registered -- which cannot happen while
	## `_init` still holds the main loop. Nothing else about the run changed:
	## every line below prints in the order it always did.
	call_deferred("_run")


func _run() -> void:
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
	# TASK H2b. The SKIN tally -- what the massif WEARS, in the same two groups.
	# STONE says how much mountain shows, and this says what material it shows
	# it in.
	var skin_by_group: Dictionary = {
		CORPUS_STONE_GROUP: _new_skin_tally(),
		ADDED_STONE_GROUP: _new_skin_tally(),
	}
	# TASK H2c FIX 1. The clearance tally, corpus-wide rather than split by scale
	# group: the two groups exist because somebody wrote a per-group number down
	# for a phase exit, and nobody ever read one off this row. It is a physics
	# safety pin, and one violated cell anywhere in the matrix is the answer.
	var cache := EnvironmentRenderCache.new(catalog)
	var clearance := _new_clearance_tally()
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
					# TASK H2b. The SKIN row: what the retained massif WEARS,
					# beside how tall its banks are. `tall_masonry` is coursed
					# ashlar above the retaining budget and `free_bench_stone`
					# is a stone slab on a bench nobody walks -- the two pins,
					# both zero. `low/tall` is the bank split the treatment
					# turns on, and it is a property of the SHELL, so it is
					# also the before-picture: task H2b did not move it.
					_accumulate_skin(skin_by_group[group] as Dictionary,
						fabric)
					print(("SWEEP seed=%d scale=%s SKIN panels=%d masonry=%d " \
						+ "natural=%d green=%d tall_masonry=%d " \
						+ "free_bench_stone=%d shared_street=%d low=%d " \
						+ "tall=%d tallest=%d cut=%d cut_coursed=%d " \
						+ "tail_candidates=%d tail_unclearable=%d " \
						+ "coursed_trim=%d cap_juts=%d cap_trim=%d " \
						+ "banks=%s") % [city_seed,
						String(profile.scale_id),
						int(fabric.audit.get(
							"maze_stone_expected_face_count", 0)),
						int(fabric.audit.get(
							"maze_skin_masonry_panel_count", 0)),
						int(fabric.audit.get(
							"maze_skin_natural_panel_count", 0)),
						int(fabric.audit.get("maze_skin_green_cap_count", 0)),
						int(fabric.audit.get(
							"maze_tall_bank_masonry_panel_count", 0)),
						int(fabric.audit.get(
							"maze_free_bench_stone_cap_count", 0)),
						int(fabric.audit.get(
							"maze_shared_street_cap_count", 0)),
						int(fabric.audit.get("maze_low_bank_face_count", 0)),
						int(fabric.audit.get("maze_tall_bank_face_count", 0)),
						int(fabric.audit.get("maze_tallest_bank_bands", 0)),
						int(fabric.audit.get("maze_skin_cut_panel_count", 0)),
						int(fabric.audit.get(
							"maze_skin_cut_fallback_masonry_count", 0)),
						int(fabric.audit.get(
							"maze_skin_cut_tail_candidate_count", 0)),
						int(fabric.audit.get(
							"maze_skin_cut_tail_unclearable_count", 0)),
						int(fabric.audit.get(
							"maze_skin_coursed_trim_count", 0)),
						int(fabric.audit.get(
							"maze_stone_cap_jut_cell_count", 0)),
						int(fabric.audit.get(
							"maze_skin_cap_trim_count", 0)),
						str(fabric.audit.get(
							"maze_bank_height_histogram", {}))])
					# TASK H2c FIX 1. The CLEARANCE row. Every other row above is
					# read off the audit; this one is the only measurement in the
					# sweep that asks the physics server, because the question it
					# answers cannot be read off a count: giving the cliff shard a
					# convex collider turned a bulge a body could see into one it
					# cannot pass, and the shard stands 0.155-0.595 m proud of its
					# boundary depending on seeded relief. Two facing shards in a
					# one-cell street could pinch it shut, and H2c measured only
					# four towns by hand.
					await _measure_clearance(clearance, city_seed,
						profile.scale_id, fabric, cache)
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
	_print_skin_result(CORPUS_STONE_GROUP,
		skin_by_group[CORPUS_STONE_GROUP] as Dictionary)
	_print_skin_result(ADDED_STONE_GROUP,
		skin_by_group[ADDED_STONE_GROUP] as Dictionary)
	_print_clearance_result(clearance)
	# The matrix is written BEFORE the clearance pin is judged. The summary is
	# evidence about composition and the corpus gate reads it; a shut street is
	# a separate question and must not cost the gate its matrix.
	_write_summary(seeds, scale_ids, rows, sealed_count, attempted, total_ms)
	if int(clearance.blocked) > 0 \
			or int(clearance.splits) > 0 \
			or int(clearance.unreachable) > 0 \
			or int(clearance.worst_gates_blocked) > CLEARANCE_TOWN_GATE_CEILING \
			or int(clearance.worst_offset_free) \
				> CLEARANCE_TOWN_OFFSET_FREE_CEILING \
			or int(clearance.worst_gates_offset) \
				> CLEARANCE_TOWN_GATES_OFFSET_CEILING:
		# WHAT THIS PIN DOES AND DOES NOT SAY. The scene measured is
		# `SettlementFabricAssembler.terrace_retaining_payload` and NOTHING
		# else: the retained massif's skin plus everything the crown wears --
		# green rims, garden and plaza dressing, terrace railings, skywalks and
		# facade outcroppings -- with no BUILDINGS in it (fix 1, minor 5; this
		# used to say "no railings", which stopped being true at task C5e). That
		# isolation is the point: it is the only way to ask "did the fabric's
		# own colliders shut anything" and get an answer about the fabric rather
		# than about the town. It is NOT a walkability guarantee for a finished
		# settlement, and a green row here does not mean every street is
		# passable once the buildings are committed.
		print(("SWEEP ERROR clearance %d walked cell(s) admit no player " \
			+ "capsule anywhere inside them; %d route component(s) split and " \
			+ "%d cell(s) were cut off [%s]; the worst town shuts %d cell " \
			+ "boundary(ies) against a ceiling of %d, and costs %d off-centre " \
			+ "cell(s) against %d and %d off-centre crossing(s) against %d. " \
			+ "Scope: the scene is " \
			+ "terrace_retaining_payload ALONE (the massif's skin and what " \
			+ "the crown wears -- rims, garden and plaza dressing, railings, " \
			+ "skywalks, outcroppings -- but NO buildings or props), which " \
			+ "isolates the fabric's own colliders and is NOT a " \
			+ "town walkability guarantee. A SPLIT is the serious one -- it " \
			+ "means a shut crossing had no way round and the street is " \
			+ "genuinely broken, not merely narrowed; the two off-centre " \
			+ "ceilings are COSTS, and a rise in them means the skin leans " \
			+ "into more streets than the rock cut left it leaning into. %s") % [
			int(clearance.blocked), int(clearance.splits),
			int(clearance.unreachable),
			", ".join(PackedStringArray(clearance.split_towns)),
			int(clearance.worst_gates_blocked), CLEARANCE_TOWN_GATE_CEILING,
			int(clearance.worst_offset_free),
			CLEARANCE_TOWN_OFFSET_FREE_CEILING,
			int(clearance.worst_gates_offset),
			CLEARANCE_TOWN_GATES_OFFSET_CEILING,
			_clearance_worst_text(clearance)])
		push_error(("clearance pin violated: blocked=%d splits=%d " \
			+ "cells_unreachable=%d worst_gates_blocked=%d " \
			+ "worst_offset_free=%d worst_gates_offset=%d") % [
			int(clearance.blocked), int(clearance.splits),
			int(clearance.unreachable), int(clearance.worst_gates_blocked),
			int(clearance.worst_offset_free),
			int(clearance.worst_gates_offset)])
		quit(3)
		return
	# TASK I3 FIX 1, IMPORTANT 1. The skywalk ratchet, judged after the physics
	# pin and never instead of it: a shut street is a bug in a town that shipped,
	# and a lost bridge is a channel that stopped working. Both are red, and if
	# a run manages both the shut street is the one to read first.
	var life_shortfalls := PackedStringArray()
	for group: String in [CORPUS_STONE_GROUP, ADDED_STONE_GROUP]:
		if not _life_floor_group_ran(seeds, scale_ids, group):
			continue
		var life_tally := skin_by_group[group] as Dictionary
		var floor_value := int(LIFE_SPAN_FLOOR_BY_GROUP[group])
		if int(life_tally.spans) >= floor_value:
			continue
		life_shortfalls.append("%s flies %d span(s) over %d town(s), floor %d" % [
			group, int(life_tally.spans), int(life_tally.towns), floor_value])
	if not life_shortfalls.is_empty():
		print(("SWEEP ERROR life the skywalk channel fell below its measured " \
			+ "floor: %s. The floor is a RATCHET on the corpus totals of " \
			+ "`SWEEP RESULT life`, and it exists because every other pin in " \
			+ "this file counts what is THERE: a siting rule that stopped " \
			+ "finding sites would take every bridge in the corpus and turn " \
			+ "nothing else red. Read the per-town `SWEEP seed=... SEALED` " \
			+ "rows against the last matrix to see which towns lost theirs, " \
			+ "and if the loss is intended, re-pin at the new measurement " \
			+ "with the reason written down.") % ", ".join(life_shortfalls))
		push_error("life span floor violated: %s" % ", ".join(life_shortfalls))
		quit(4)
		return
	quit()


static func _life_floor_group_ran(seeds: Array[int],
		scale_ids: Array[StringName], group: String) -> bool:
	## Whether this run covered the matrix `LIFE_SPAN_FLOOR_BY_GROUP` was
	## measured on for one scale group. A corpus total is only comparable
	## against the corpus it came from, so a spot check is not judged at all
	## rather than judged and failed.
	for seed_value: int in LIFE_FLOOR_SEEDS:
		if not seeds.has(seed_value):
			return false
	for scale_name: String in group.split(",", false):
		if not scale_ids.has(StringName(scale_name)):
			return false
	return true


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


static func _new_skin_tally() -> Dictionary:
	## TASK H2b. The corpus skin tally.
	return {"towns": 0, "panels": 0, "masonry": 0, "natural": 0, "green": 0,
		"facade": 0, "facade_windows": 0, "facade_blue": 0, "facade_orange": 0,
		"facade_amber": 0, "above_ground_stone": 0, "garden": 0,
		"village_green": 0, "planting": 0, "paved_bench": 0,
		"tall_masonry": 0, "free_bench_stone": 0, "shared_street": 0,
		"low": 0, "tall": 0, "tallest": 0, "cut": 0, "cut_coursed": 0,
		"tail_candidates": 0, "tail_unclearable": 0, "coursed_trim": 0,
		"cap_juts": 0, "cap_trim": 0,
		"spans": 0, "span_cells": 0, "span_instances": 0, "bays": 0,
		"bumps": 0, "outcrop_brackets": 0, "dormers": 0, "plaza_entries": 0,
		"plaza_features": 0, "plaza_towns": 0}


static func _accumulate_skin(tally: Dictionary,
		fabric: SettlementFabricPlan) -> void:
	tally.towns += 1
	tally.panels += int(fabric.audit.get("maze_stone_expected_face_count", 0))
	tally.masonry += int(fabric.audit.get("maze_skin_masonry_panel_count", 0))
	tally.natural += int(fabric.audit.get("maze_skin_natural_panel_count", 0))
	tally.green += int(fabric.audit.get("maze_skin_green_cap_count", 0))
	# TASK I2. The clad mass, its family split and its yards, so the corpus line
	# states what the town's own walls are made of and not only what is left of
	# the rock. `natural` above is the pin that goes with them: it is zero, and
	# `facade` is where those panels went.
	tally.facade += int(fabric.audit.get("maze_skin_facade_panel_count", 0))
	tally.facade_windows += int(fabric.audit.get(
		"maze_skin_facade_window_panel_count", 0))
	tally.facade_blue += int(fabric.audit.get(
		"maze_skin_facade_blue_panel_count", 0))
	tally.facade_orange += int(fabric.audit.get(
		"maze_skin_facade_orange_panel_count", 0))
	tally.facade_amber += int(fabric.audit.get(
		"maze_skin_facade_amber_panel_count", 0))
	tally.above_ground_stone += int(fabric.audit.get(
		"maze_skin_above_ground_stone_face_count", 0))
	tally.garden += int(fabric.audit.get("maze_garden_cell_count", 0))
	tally.village_green += int(fabric.audit.get(
		"maze_village_green_cell_count", 0))
	tally.planting += int(fabric.audit.get("maze_garden_planting_count", 0))
	tally.paved_bench += int(fabric.audit.get("maze_paved_bench_cap_count", 0))
	tally.tall_masonry += int(fabric.audit.get(
		"maze_tall_bank_masonry_panel_count", 0))
	tally.free_bench_stone += int(fabric.audit.get(
		"maze_free_bench_stone_cap_count", 0))
	tally.shared_street += int(fabric.audit.get(
		"maze_shared_street_cap_count", 0))
	tally.low += int(fabric.audit.get("maze_low_bank_face_count", 0))
	tally.tall += int(fabric.audit.get("maze_tall_bank_face_count", 0))
	tally.tallest = maxi(int(tally.tallest),
		int(fabric.audit.get("maze_tallest_bank_bands", 0)))
	tally.cut += int(fabric.audit.get("maze_skin_cut_panel_count", 0))
	tally.cut_coursed += int(fabric.audit.get(
		"maze_skin_cut_fallback_masonry_count", 0))
	tally.tail_candidates += int(fabric.audit.get(
		"maze_skin_cut_tail_candidate_count", 0))
	tally.tail_unclearable += int(fabric.audit.get(
		"maze_skin_cut_tail_unclearable_count", 0))
	tally.coursed_trim += int(fabric.audit.get(
		"maze_skin_coursed_trim_count", 0))
	tally.cap_juts += int(fabric.audit.get(
		"maze_stone_cap_jut_cell_count", 0))
	tally.cap_trim += int(fabric.audit.get("maze_skin_cap_trim_count", 0))
	# TASK I3. THE LIFE, on the same tally and for the same reason the facade
	# split rides here: a reader asking "did the town get its skywalks, its bays
	# and its square" should get a corpus number off one row rather than infer it
	# from the panel counts above.
	tally.spans += int(fabric.audit.get("maze_skywalk_span_count", 0))
	tally.span_cells += int(fabric.audit.get("maze_skywalk_deck_cell_count", 0))
	tally.span_instances += int(fabric.audit.get(
		"maze_skywalk_instance_count", 0))
	tally.bays += int(fabric.audit.get("maze_facade_bay_count", 0))
	tally.bumps += int(fabric.audit.get("maze_facade_bump_out_count", 0))
	tally.outcrop_brackets += int(fabric.audit.get(
		"maze_facade_outcrop_bracket_count", 0))
	tally.dormers += int(fabric.audit.get("dormered_roof_unit_count", 0))
	tally.plaza_entries += int(fabric.audit.get("maze_plaza_entry_count", 0))
	tally.plaza_features += int(fabric.audit.get(
		"maze_plaza_centre_feature_count", 0))
	tally.plaza_towns += int(int(fabric.audit.get(
		"maze_village_green_cell_count", 0)) > 0)


func _print_skin_result(group: String, tally: Dictionary) -> void:
	## TASK H2b. The corpus answer to "what is the mountain made of". Both
	## pins are sums rather than worsts because both are zero: one masonry
	## panel above the retaining budget anywhere in the corpus shows up here.
	if int(tally.towns) == 0:
		return
	print(("SWEEP RESULT skin%s towns=%d panels=%d masonry=%d natural=%d " \
		+ "green=%d facade=%d facade_share=%.4f windows=%d " \
		+ "families=%d/%d/%d above_ground_stone=%d reclad_share=%.4f " \
		+ "tall_masonry=%d free_bench_stone=%d " \
		+ "shared_street=%d low_faces=%d tall_faces=%d tall_share=%.4f " \
		+ "tallest_bank=%d cut=%d cut_share=%.4f cut_coursed=%d " \
		+ "tail_candidates=%d tail_unclearable=%d coursed_trim=%d " \
		+ "cap_juts=%d cap_trim=%d garden=%d village_green=%d planting=%d " \
		+ "paved_bench=%d") % [
		"" if group == CORPUS_STONE_GROUP else "/%s" % group,
		int(tally.towns), int(tally.panels), int(tally.masonry),
		int(tally.natural), int(tally.green), int(tally.facade),
		float(int(tally.facade)) / float(maxi(1, int(tally.panels))),
		int(tally.facade_windows), int(tally.facade_blue),
		int(tally.facade_orange), int(tally.facade_amber),
		int(tally.above_ground_stone),
		float(int(tally.natural) + int(tally.green)) \
			/ float(maxi(1, int(tally.panels))),
		int(tally.tall_masonry), int(tally.free_bench_stone),
		int(tally.shared_street), int(tally.low), int(tally.tall),
		float(int(tally.tall)) / float(maxi(1, int(tally.low) \
			+ int(tally.tall))),
		int(tally.tallest), int(tally.cut),
		float(int(tally.cut)) / float(maxi(1, int(tally.natural))),
		int(tally.cut_coursed), int(tally.tail_candidates),
		int(tally.tail_unclearable), int(tally.coursed_trim),
		int(tally.cap_juts), int(tally.cap_trim), int(tally.garden),
		int(tally.village_green), int(tally.planting),
		int(tally.paved_bench)])
	# TASK I3. THE LIFE, on its own row rather than folded into the one above:
	# SKIN says what the mass wears, and this says what the town DOES with it --
	# the bridges over its streets, the projections on its faces and whether its
	# green is a square somebody can walk into.
	#
	# `bare_outcrops` is ZERO by construction (two bearers per projection, no
	# branch that can skip them) and printed anyway, beside the roofscape row's
	# own `bare_overhangs`, because "every overhang shows its bracket" is the
	# promise both rows exist to make checkable.
	print(("SWEEP RESULT life%s towns=%d spans=%d span_cells=%d " \
		+ "span_instances=%d bays=%d bumps=%d outcrops=%d brackets=%d " \
		+ "bare_outcrops=%d dormers=%d plaza_towns=%d plaza_entries=%d " \
		+ "plaza_features=%d") % [
		"" if group == CORPUS_STONE_GROUP else "/%s" % group,
		int(tally.towns), int(tally.spans), int(tally.span_cells),
		int(tally.span_instances), int(tally.bays), int(tally.bumps),
		int(tally.bays) + int(tally.bumps), int(tally.outcrop_brackets),
		int(tally.outcrop_brackets) - 2 * (int(tally.bays) + int(tally.bumps)),
		int(tally.dormers), int(tally.plaza_towns), int(tally.plaza_entries),
		int(tally.plaza_features)])


static func _new_clearance_tally() -> Dictionary:
	## TASK H2c FIX 1. The corpus clearance tally.
	return {"towns": 0, "cells": 0, "centre_free": 0, "offset_free": 0,
		"blocked": 0, "gates": 0, "gates_offset": 0, "gates_blocked": 0,
		"worst_gates_blocked": 0, "worst_offset_free": 0,
		"worst_gates_offset": 0, "gates_blocked_required": 0, "splits": 0,
		"unreachable": 0, "split_towns": [], "worst": []}


func _measure_clearance(tally: Dictionary, city_seed: int,
		scale_id: StringName, fabric: SettlementFabricPlan,
		cache: EnvironmentRenderCache) -> void:
	## Sweeps the player's own capsule through the massif skin with the REAL
	## physics server, on the plan this sweep already solved. The solve is the
	## dominant cost of a corpus run and re-solving here would double it, so the
	## row rides the sweep's own `fabric` rather than owning a probe.
	##
	## SCOPE, AND THE ROW'S OWN LABEL SAYS IT (fix 1, minor 5). The committed
	## scene is `terrace_retaining_payload` and nothing else, and what that
	## payload holds has GROWN since this row was written: the plinths and the
	## massif's skin, the green rim walls, the garden dressing with the plaza's
	## thresholds and centre feature in it, the terrace railings (since task
	## C5e), and task I3's skywalks and facade outcroppings. It is therefore the
	## town's whole FABRIC DRESSING -- which is what the row now prints -- and
	## not the `skin_only` it claimed for three tasks after that stopped being
	## true. What it still excludes is the BUILDINGS: no room shells, no doors,
	## no props. So it remains an isolation rather than a walkability guarantee
	## for a finished town, and it is now an honest one: every collider it
	## commits is one the retained crown really carries, including the bearers a
	## bridge or a bay hangs over a street.
	##
	## THREE MEASUREMENTS, because a per-cell fit is not walkability:
	##
	## * `centre_free` -- a body stands on the cell's own centreline;
	## * `offset_free` -- it fits somewhere inside the cell but not there, which
	##   is the honest cost of giving the shard a collider (the body walks round
	##   the lobe) and is REPORTED rather than pinned;
	## * `gates_blocked` -- NO point along the boundary between two adjacent
	##   walked cells admits a body. This is the one that turns per-cell fit
	##   into passage: two cells can each be free at some offset while the
	##   doorway between them is shut, and that street is still shut.
	##
	## The gate is swept along its own width rather than probed at its midpoint
	## alone, because the midpoint alone repeats exactly the mistake the cell
	## centreline makes. The shard's lobe covers 0.53-0.70 m of a 1.5 m boundary,
	## so a midpoint-only test called 194 of 2439 gates shut over the eight-town
	## run this was validated on, when a body walks through 187 of those 194 a
	## handspan to one side; `gates_offset` is that population, reported, and
	## `gates_blocked` is what is genuinely left.
	##
	## AND THEN THE ROUTE GRAPH, because a shut crossing is not yet a broken
	## street. Two cells with another way round are NARROWED; two cells without
	## one are CUT APART, and only the second is a bug a player would ever meet.
	## `gates_blocked_required` counts the shut crossings that turned out to be
	## load-bearing, `splits` counts the route components that fell apart, and
	## `cells_unreachable` counts the cells left stranded. The last two are the
	## pins that matter.
	var payload := SettlementFabricAssembler.terrace_retaining_payload(fabric)
	cache.prepare(payload.asset_ids())
	var root := Node3D.new()
	get_root().add_child(root)
	var shapes := EnvironmentCollisionBuilder.commit(root, payload, cache,
		&"SweepClearance")
	# The commit creates the bodies; a physics frame is what registers them with
	# the space. Querying before one runs reads an EMPTY world and calls every
	# street clear -- the row would be green and meaningless.
	await physics_frame
	await physics_frame
	var space := get_root().world_3d.direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_CAPSULE_RADIUS
	capsule.height = PLAYER_CAPSULE_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.margin = CLEARANCE_MARGIN
	var walked := SettlementFabricAssembler.walked_floor_cells(
		fabric.surface_plan)
	var cells: Array[Vector3i] = []
	cells.assign(walked.keys())
	cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return "%d/%d/%d" % [a.x, a.y, a.z] < "%d/%d/%d" % [b.x, b.y, b.z])
	var centre_free := 0
	var offset_free := 0
	var blocked := 0
	var gates := 0
	var gates_offset := 0
	var gates_blocked := 0
	# Edge key -> the pair it joins, for the route-graph pass below.
	var shut: Dictionary = {}
	# Untyped on purpose: this is the tally's OWN array by reference, and a typed
	# local would silently take a copy that nothing ever reads.
	var worst: Array = tally.worst
	var label := "%d/%s" % [city_seed, String(scale_id)]
	for cell: Vector3i in cells:
		var fit := _clearance_of_cell(space, query, cell)
		if fit == 0:
			centre_free += 1
		elif fit > 0:
			offset_free += 1
		else:
			blocked += 1
			if worst.size() < CLEARANCE_WORST_LIMIT:
				worst.append("%s cell(%d,%d,%d)" % [label, cell.x, cell.y,
					cell.z])
		# Each lateral pair once, from its lower-x / lower-z side. Only same-band
		# neighbours: a stair's cells are not x/z-adjacent at one y, so the row
		# says nothing about vertical passage and does not pretend to.
		for direction: Vector3i in [Vector3i(1, 0, 0), Vector3i(0, 0, 1)]:
			if not walked.has(cell + direction):
				continue
			gates += 1
			var crossing := _clearance_of_gate(space, query, cell, direction)
			if crossing > 0:
				gates_offset += 1
			elif crossing < 0:
				gates_blocked += 1
				shut[_clearance_edge_key(cell, cell + direction)] = [cell,
					cell + direction]
				if worst.size() < CLEARANCE_WORST_LIMIT:
					worst.append("%s gate(%d,%d,%d)->(%d,%d,%d) by[%s]" % [
						label, cell.x, cell.y, cell.z, cell.x + direction.x,
						cell.y + direction.y, cell.z + direction.z,
						_clearance_blockers(space, query,
							_clearance_stance(cell) + Vector3(direction) \
								* (FabricRecipe.CELL_SIZE * 0.5))])
	# THE ROUTE GRAPH. A shut crossing only matters if the town NEEDED it: two
	# cells with another way round are narrowed, two cells without one are cut
	# apart, and those are different bugs. Read as DAMAGE against the town's own
	# design connectivity rather than against an assumption of one piece -- so a
	# town that is already several pieces for reasons of its own (a plaza the
	# public realm reaches only by a route this graph does not model) cannot be
	# mistaken for a town a collider broke.
	var design := _clearance_components(walked, {})
	var open := _clearance_components(walked, shut)
	var splits := _clearance_component_count(open) \
		- _clearance_component_count(design)
	var unreachable := _clearance_cells_cut_off(walked, design, open)
	var required := 0
	for pair: Array in shut.values():
		if int(open.get(pair[0], -1)) != int(open.get(pair[1], -2)):
			required += 1
	print(("SWEEP seed=%d scale=%s CLEARANCE payload=fabric_dressing shapes=%d " \
		+ "walked=%d centre_free=%d offset_free=%d blocked=%d gates=%d " \
		+ "gates_offset=%d gates_blocked=%d gates_blocked_required=%d " \
		+ "route_components=%d splits=%d cells_unreachable=%d") % [city_seed,
		String(scale_id), shapes, cells.size(), centre_free, offset_free,
		blocked, gates, gates_offset, gates_blocked, required,
		_clearance_component_count(design), splits, unreachable])
	if splits > 0 or unreachable > 0:
		# Named on its own line so a split is greppable without reading the row.
		tally.split_towns.append("%s (splits=%d cells_unreachable=%d)" % [label,
			splits, unreachable])
	tally.splits += splits
	tally.unreachable += unreachable
	tally.gates_blocked_required += required
	tally.towns += 1
	tally.cells += cells.size()
	tally.centre_free += centre_free
	tally.offset_free += offset_free
	tally.blocked += blocked
	tally.gates += gates
	tally.gates_offset += gates_offset
	tally.gates_blocked += gates_blocked
	tally.worst_gates_blocked = maxi(int(tally.worst_gates_blocked),
		gates_blocked)
	# FIX 2, MINOR 5. The two costs, per town, so the corpus pin on them means
	# the same thing whatever seed set this sweep is given.
	tally.worst_offset_free = maxi(int(tally.worst_offset_free), offset_free)
	tally.worst_gates_offset = maxi(int(tally.worst_gates_offset), gates_offset)
	root.queue_free()
	await process_frame


func _clearance_stance(cell: Vector3i) -> Vector3:
	## Where the capsule's own CENTRE goes to stand in a cell.
	return Vector3(float(cell.x) * FabricRecipe.CELL_SIZE,
		float(cell.y) * FabricRecipe.CELL_SIZE + PLAYER_CAPSULE_HEIGHT * 0.5 \
			+ CLEARANCE_MARGIN + CLEARANCE_FLOOR_LIFT,
		float(cell.z) * FabricRecipe.CELL_SIZE)


func _clearance_of_cell(space: PhysicsDirectSpaceState3D,
		query: PhysicsShapeQueryParameters3D, cell: Vector3i) -> int:
	## 0 when a body fits standing on the cell's centreline, 1 when it fits
	## somewhere else inside the cell, -1 when nowhere in the cell is clear.
	var base := _clearance_stance(cell)
	query.transform = Transform3D(Basis.IDENTITY, base)
	if space.intersect_shape(query, 1).is_empty():
		return 0
	var reach := FabricRecipe.CELL_SIZE * 0.5 - PLAYER_CAPSULE_RADIUS
	if reach <= 0.0:
		return -1
	for ix in CLEARANCE_OFFSET_STEPS:
		for iz in CLEARANCE_OFFSET_STEPS:
			var offset := Vector3(
				lerpf(-reach, reach,
					float(ix) / float(CLEARANCE_OFFSET_STEPS - 1)), 0.0,
				lerpf(-reach, reach,
					float(iz) / float(CLEARANCE_OFFSET_STEPS - 1)))
			query.transform = Transform3D(Basis.IDENTITY, base + offset)
			if space.intersect_shape(query, 1).is_empty():
				return 1
	return -1


func _clearance_of_gate(space: PhysicsDirectSpaceState3D,
		query: PhysicsShapeQueryParameters3D, cell: Vector3i,
		direction: Vector3i) -> int:
	## Can a body stand ON the boundary plane the two cells share? 0 at the
	## boundary's midpoint, 1 somewhere else along its width, -1 nowhere -- in
	## which case the passage between the two cells is shut whatever either cell
	## measures on its own.
	var base := _clearance_stance(cell) \
		+ Vector3(direction) * (FabricRecipe.CELL_SIZE * 0.5)
	query.transform = Transform3D(Basis.IDENTITY, base)
	if space.intersect_shape(query, 1).is_empty():
		return 0
	# The boundary's own width: the axis perpendicular to the crossing, in the
	# horizontal plane. The capsule may slide along it and no further -- sliding
	# ACROSS would be standing in one of the cells rather than in the doorway.
	var along := Vector3(float(direction.z), 0.0, float(direction.x))
	var reach := FabricRecipe.CELL_SIZE * 0.5 - PLAYER_CAPSULE_RADIUS
	if reach <= 0.0:
		return -1
	for step in CLEARANCE_OFFSET_STEPS:
		var slide := lerpf(-reach, reach,
			float(step) / float(CLEARANCE_OFFSET_STEPS - 1))
		query.transform = Transform3D(Basis.IDENTITY, base + along * slide)
		if space.intersect_shape(query, 1).is_empty():
			return 1
	return -1


static func _clearance_edge_key(a: Vector3i, b: Vector3i) -> String:
	## One key per unordered pair, so the route pass can ask "is this crossing
	## shut" without caring which side it walked in from.
	var lo := a
	var hi := b
	if [b.x, b.y, b.z] < [a.x, a.y, a.z]:
		lo = b
		hi = a
	return "%d,%d,%d|%d,%d,%d" % [lo.x, lo.y, lo.z, hi.x, hi.y, hi.z]


static func _clearance_components(walked: Dictionary,
		shut: Dictionary) -> Dictionary:
	## Component id per walked cell, by BFS over `CLEARANCE_ROUTE_STEPS`. A
	## same-band crossing named in `shut` is not an edge; a one-band step always
	## is, because the shard is a wall on a bank face and a step's riser is not
	## something this payload can be asked about meaningfully.
	##
	## Called TWICE per town: with an empty `shut` for the town's design
	## connectivity, and with the measured set for what a body can actually
	## reach. The difference is the only honest reading of the damage.
	##
	## FIX 2, MINOR 9 -- WHAT THE ONE-BAND STEP ASSUMES, said out loud. A step
	## with `step.y != 0` is treated as OPEN whatever the shape query measured,
	## because the two cells are not x/z-adjacent and the boundary sweep has no
	## plane to stand on: a riser is not a doorway. That is a real simplification
	## and it UNDER-REPORTS splits -- a stair shut by a collider would still join
	## its two components here. It is symmetric across the design graph and the
	## open one, so it never invents damage, only misses some; and it is moot on
	## a corpus measuring `gates_blocked = 0`, where the open graph and the
	## design graph are the same graph. The day `gates_blocked` leaves zero on a
	## stair, this is the line to revisit.
	var component_of: Dictionary = {}
	var cells: Array = walked.keys()
	cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return "%d/%d/%d" % [a.x, a.y, a.z] < "%d/%d/%d" % [b.x, b.y, b.z])
	var next_id := 0
	for start: Vector3i in cells:
		if component_of.has(start):
			continue
		var id := next_id
		next_id += 1
		component_of[start] = id
		var queue: Array[Vector3i] = [start]
		while not queue.is_empty():
			var cell: Vector3i = queue.pop_back()
			for step: Vector3i in CLEARANCE_ROUTE_STEPS:
				var neighbour: Vector3i = cell + step
				if not walked.has(neighbour) or component_of.has(neighbour):
					continue
				if step.y == 0 and shut.has(_clearance_edge_key(cell, neighbour)):
					continue
				component_of[neighbour] = id
				queue.append(neighbour)
	return component_of


static func _clearance_component_count(component_of: Dictionary) -> int:
	var seen: Dictionary = {}
	for id: int in component_of.values():
		seen[id] = true
	return seen.size()


static func _clearance_cells_cut_off(walked: Dictionary, design: Dictionary,
		open: Dictionary) -> int:
	## How many cells the shut crossings put out of reach. Within each DESIGN
	## component, the largest surviving open piece is "where the town still is"
	## and everything else in that component has been cut off from it. Counted
	## per design component so a town that was already several pieces is judged
	## on what this change did to each of them, not on being several pieces.
	var open_size: Dictionary = {}
	var design_size: Dictionary = {}
	for cell: Vector3i in walked:
		var open_id := int(open[cell])
		var design_id := int(design[cell])
		open_size[open_id] = 1 + int(open_size.get(open_id, 0))
		design_size[design_id] = 1 + int(design_size.get(design_id, 0))
	var largest_in_design: Dictionary = {}
	for cell: Vector3i in walked:
		var design_id := int(design[cell])
		largest_in_design[design_id] = maxi(
			int(largest_in_design.get(design_id, 0)),
			int(open_size[int(open[cell])]))
	var cut_off := 0
	for design_id: int in design_size:
		cut_off += int(design_size[design_id]) \
			- int(largest_in_design.get(design_id, 0))
	return cut_off


func _clearance_blockers(space: PhysicsDirectSpaceState3D,
		query: PhysicsShapeQueryParameters3D, at: Vector3) -> String:
	## WHAT is standing there, named by the asset its shape was baked from. A
	## fired pin should say what to look at and not only where: "two facing
	## cliff shards" and "a green cap in the wrong place" are different bugs and
	## the coordinates alone do not tell them apart.
	query.transform = Transform3D(Basis.IDENTITY, at)
	var names: Dictionary = {}
	for hit: Dictionary in space.intersect_shape(query, 8):
		var body := hit.get("collider") as CollisionObject3D
		if body == null:
			continue
		var owner_id := body.shape_find_owner(int(hit.get("shape", 0)))
		var owner := body.shape_owner_get_owner(owner_id) as Node
		if owner != null:
			names[String(owner.name)] = true
	var listed: Array = names.keys()
	listed.sort()
	return ",".join(PackedStringArray(listed))


func _clearance_worst_text(tally: Dictionary) -> String:
	var worst: Array = tally.worst
	if worst.is_empty():
		return ""
	return "first offenders: " + "; ".join(PackedStringArray(worst))


func _print_clearance_result(tally: Dictionary) -> void:
	## TASK H2c FIX 1. One corpus answer to "can a body still walk the streets
	## the massif skin lines". Three pins at ZERO -- `blocked` (no walked cell
	## may refuse a body everywhere inside it), `splits` and `cells_unreachable`
	## (no shut crossing may be the only way between two parts of a town) --
	## and `gates_blocked` against a MEASURED per-town ceiling instead, because
	## the corpus shuts crossings that have a way round and a zero there would
	## be a pin that has never been true. The two `*_share` numbers are the
	## reported COST -- the share of
	## walked cells, and of crossings between them, that no longer admit a body
	## on the exact centreline because the shard's lobe is in the way. That is
	## correct behaviour (before H2c a player walked through visible rock) and a
	## real change in how a street feels, so it is stated rather than hidden.
	##
	## FIX 2, MINOR 5: those two costs now carry per-town ceilings of their own
	## (`worst_town_offset_free` and `worst_town_gates_offset` against
	## CLEARANCE_TOWN_OFFSET_FREE_CEILING / _GATES_OFFSET_CEILING), so a revert
	## of the rock cut cannot walk 69 back up to 1096 with every other pin still
	## green.
	if int(tally.towns) == 0:
		return
	print(("SWEEP RESULT clearance towns=%d payload=fabric_dressing " \
		+ "capsule=r%.5f/h%.3f margin=%.2f walked=%d centre_free=%d " \
		+ "offset_free=%d offset_share=%.4f blocked=%d gates=%d " \
		+ "gates_offset=%d gates_offset_share=%.4f gates_blocked=%d " \
		+ "worst_town_gates_blocked=%d ceiling=%d " \
		+ "worst_town_offset_free=%d offset_ceiling=%d " \
		+ "worst_town_gates_offset=%d gates_offset_ceiling=%d " \
		+ "gates_blocked_required=%d splits=%d cells_unreachable=%d " \
		+ "split_towns=[%s] %s") % [
		int(tally.towns), PLAYER_CAPSULE_RADIUS,
		PLAYER_CAPSULE_HEIGHT, CLEARANCE_MARGIN, int(tally.cells),
		int(tally.centre_free), int(tally.offset_free),
		float(int(tally.offset_free)) / float(maxi(1, int(tally.cells))),
		int(tally.blocked), int(tally.gates), int(tally.gates_offset),
		float(int(tally.gates_offset)) / float(maxi(1, int(tally.gates))),
		int(tally.gates_blocked), int(tally.worst_gates_blocked),
		CLEARANCE_TOWN_GATE_CEILING, int(tally.worst_offset_free),
		CLEARANCE_TOWN_OFFSET_FREE_CEILING, int(tally.worst_gates_offset),
		CLEARANCE_TOWN_GATES_OFFSET_CEILING,
		int(tally.gates_blocked_required),
		int(tally.splits), int(tally.unreachable),
		", ".join(PackedStringArray(tally.split_towns)),
		_clearance_worst_text(tally)])


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
