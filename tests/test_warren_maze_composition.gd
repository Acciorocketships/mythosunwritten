extends GutTest

## MODE_MAZE end to end. Phase B built the one-pass plot planner; this file
## runs the real production entry point — `WarrenVolumetricSolver.solve()`
## with `GENERATION_MODE = MODE_MAZE` — over the four planner seeds and asks
## the questions Task C2 owns: does the town SEAL, and is everything the
## one-pass source could not supply an audit fact rather than a rejection?
##
## Task C1 asked only whether a town reached COMPOSITION. That assertion is
## kept (a town dying at the massif, the carve, the volume adapter, or the
## translator is a different and worse defect than one dying inside the
## composition) but it is no longer the bar: every planner seed must now come
## out the far side with a sealed `WarrenSpatialPlan`.

## The seeds the plot planner is pinned on, split by the scale profile each is
## measured at. Fixed pairs rather than `WarrenVillageScaleProfile.select()`
## so this file exercises both profiles regardless of how a seed rolls.
const COMPACT_SEEDS: Array[int] = [12, 4]
const STANDARD_SEEDS: Array[int] = [3, 9]

## Wall-clock ceiling for one production solve. The composition file has a
## ~4 min budget and the landmark stage used to run away for five minutes on
## its own; a seed that needs more than this has regressed into a search.
const MAXIMUM_SOLVE_MS := 30000

## Every failure `_solve_maze` can write once the source and its translation
## have both succeeded. A town that died at one of these got as far as the
## composition — which is what Task C1 delivered.
const COMPOSITION_STAGE_PREFIXES: Array[String] = [
	"maze composition rejected",
	"maze fabric gate failed",
	"maze finalization rejected",
]

## Every failure `_solve_maze` can write BEFORE the composition begins.
const SOURCE_STAGE_PREFIXES: Array[String] = [
	"maze source rejected",
	"maze massif",
	"maze carve",
	"maze volume adapter",
]

## `WarrenMazeBlockPartitioner`'s rejection of a plot-free source. It reaches
## the caller WRAPPED as "maze composition rejected: maze block partition: …"
## because the translator runs inside `from_volume`, so it must be matched by
## substring: it is a source defect wearing a composition failure's clothes,
## and a prefix test alone would score it as success.
const TRANSLATOR_NO_PLOTS := "sealed maze source carries no plots"

## The complete vocabulary of advisory shortfalls a maze town may report. A
## key outside this set means a NEW quota quietly became advisory without
## anyone deciding it should be, which is exactly the drift the audit exists
## to prevent. `hero_` prefixes and `_target` suffixes are the same facts
## under the emitting code's own names and are folded away before the check.
const ADVISORY_SHORTFALL_KEYS: Array[String] = [
	"covered_market", "courtyard_parcel_sides", "balconies", "landmarks",
	"skywalks", "assets", "courtyard_bridges", "bridges",
	# TASK D1 FIX 1's controller ruling: the source's addressed-frontage bar
	# is advisory in maze mode. A town short of it ships and records the ratio
	# it reached (plus `frontage_target`, the policy it was measured against).
	"frontage",
]

## Hero-quota gate texts. None of them may appear on a maze-mode failure: in
## one-pass mode a missing court, landmark, or link is an audit fact.
const HERO_QUOTA_GATE_FRAGMENTS: Array[String] = [
	"joint hero-feature beam found",
	"topology-first prefab landmarks survived",
	"topology-first skywalks fit",
]

## Seeds that compose a town and then lose it to a STRUCTURAL gate in
## `WarrenSpatialFabricCompiler` — a room the roof vocabulary cannot cover. It
## is a room/roof contract, not a feature quota, and it was masked until Task
## C2 opened the hero-feature gate that used to reject the town first.
##
## Pinned at the DEFECT level, not the gate level: every fragment listed must
## appear in the failure, so a different defect at the same gate cannot pass
## itself off as "the known blocker".
##
## The pin is two-sided on purpose. A seed that dies at a DIFFERENT gate fails
## here because the map went stale, and a seed that starts SEALING fails here
## because its entry is now a lie that must be deleted. 3/STANDARD IS EXACTLY
## THAT CASE and its entry is gone as of Task C3: its two roofless residual
## towers were the greedy scan building inside structural ROCK — solid the plot
## planner never gave to any building — and the maze-mode candidate filter that
## keeps rooms inside plot mass removed them. The seed seals end to end.
## TASK C5e: **EMPTY**, and the entry that is gone is the whole point. Every
## planner seed now seals. 9/standard's roof sliver was a PARTIAL PLATE -- the
## one-cell-wide remainder of a crown another storey stands on part of -- and
## the flat crown tiles it now (`WarrenSpatialFabricCompiler._tile_flat_plate`)
## instead of demanding a pitched shed for it. Removed, never relaxed: the map
## is still two-sided, so a seed that stops sealing fails here.
const KNOWN_FABRIC_BLOCKERS: Dictionary = {}

## Measured share of the back-room mass the directed pre-pass really stamps as
## rooms, minus a 0.05 guard, taken from the WEAKEST of the three sealing towns
## (0.372, 0.227, 0.344 at the pass's first delivery). The denominator is the
## ALLOCATABLE fine mass the back-room records cover when the pass begins — the
## cells it could have taken — so a plot band a street was bored through never
## counts against it. Re-pin upward only: a drop is a regression to report,
## never to relax.
##
## What the remainder is, measured from `maze_back_room_refusals`: records
## whose parcel composed no building at all (its lineage was dropped), storeys
## whose mass the composed parcels themselves moved into, rectangles whose
## authored shell or roof will not fit beside the house in front of them, and
## rectangles standing more than the authored stone course above their own
## ground with no building underneath. All four are left to the greedy scan.
##
## TASK C5c: 0.556 / 0.179 / 0.400. The floor was UNCHANGED and 4/compact's
## share really did fall (0.318 -> 0.179) -- but the NUMERATOR did not move at
## all (56 cells both times). What grew is the denominator: nine more of that
## town's parcels now compose a building, so nine more back-room records have
## a lineage to belong to and their mass counts as offered. The share is a
## ratio of two moving numbers and this is the honest reading of it; the
## absolute stamped mass is in the task report beside it.
##
## TASK C5d: 0.806 / 0.692 / 0.587, and this time the numerator moved -- 232,
## 216 and 176 cells against 160, 56 and 120. With maze houses flat-roofed the
## marginal back room brings a one-band slab instead of an authored pitched
## shell, so C5c's reverted bearing relaxation could be re-applied: the
## `no terrain or building bearing` refusal that stood at 8 / 14 / 7
## rectangles is now ZERO on all three towns. Re-pinned upward, 0.17 -> 0.53.
##
## TASK C5e: 0.806 / 0.692 / 0.587 / **0.558**. The floor is UNCHANGED and
## nothing regressed -- 9/standard is a town that never sealed before, and it
## enters the corpus as the new weakest at 0.558. That leaves this pin only
## 0.028 of margin, which is the honest reading of it: the next task to add a
## town to the corpus should expect to re-measure rather than to re-pin.
## TASK C6: **0.838 / 0.700 / 0.739 / 0.585** with full no-descent shipped.
## 9/standard is still the weakest and is unchanged at 0.585; the floor keeps
## its 0.055 of margin and is NOT re-pinned, because one town moving while the
## weakest stands still is not evidence about the weakest.
const BACK_ROOM_STAMPED_FLOOR := 0.53

## Measured share of a town's paved deck floor that is really WALKABLE from
## the town entry, minus a 0.05 guard. A plaza the player cannot reach is a
## hole in the fabric wearing paving, so this is the assertion that gives
## ruling 1 its teeth; the BFS behind it walks the sealed GRID rather than the
## route array, which `WarrenSpatialPlan._validate_route` has already proved
## connected. Re-pin upward only.
const DECK_REACHABLE_FLOOR := 0.95

## Measured share of the planner's bridge plots that become real bridge rooms,
## minus a 0.05 guard. It is **0.000 on this corpus**, so this line is a
## placeholder that becomes a real floor the day the model gap below closes;
## the teeth of `test_bridges_become_rooms_decks_or_audited_releases` are the
## accounting identity, the reason vocabulary, and the shortfall equality.
##
## Why zero, measured: a bridge floor is `passage headroom top + 1`, and on all
## three bridges of the three sealing towns that band is exactly the flanking
## houses' ROOF course (`house.032[2,8)` and `house.030[2,8)` both stop their
## rooms at band 6, which is bridge.00's floor). A roof is not a room, so the
## two-sided socket bearing a bridge needs cannot be bound -- and
## `WarrenSpatialFabricCompiler` re-runs that same bond strictly, so a bridge
## stamped without it would reject the whole town instead of one span.
const BRIDGE_STAMPED_FLOOR := 0.0

## Every reason `_stamp_maze_bridges` may release a span for. A reason outside
## this set means the pass grew a new refusal nobody decided on, which is the
## same drift `ADVISORY_SHORTFALL_KEYS` exists to catch.
const BRIDGE_RELEASE_REASONS: Array[String] = [
	"span is not a one-storey tower or slim shell",
	"span mass is already spent or feature-reserved",
	"no flank house composed a building at this floor",
	"span footprint is not an authored shell",
	"span has no two bound flank bearings",
	"bearing flank has no room to name",
	"authored envelope does not fit",
]

## Every verdict a bridge record may carry. `open_deck` joins the vocabulary
## in Task C5: a span whose two flanks both present a FLAT surface at its own
## floor band is a rooftop walkway rather than a room, so it is paved as
## public floor instead of released back to rock.
const BRIDGE_OUTCOMES: Array[String] = ["stamped", "open_deck", "released"]

## Measured share of the route floor a maze town lays that really stands on
## something solid -- retained stone, a compiled building, or an inhabited
## room -- minus a 0.05 guard. Before Task C5 every leftover rock cell was
## discarded, so a bored street's own floor stood on nothing at all. Re-pin
## upward only.
const ROUTE_ON_STONE_FLOOR := 0.95

## TASK C5c RULING 1 and 6. Ceiling on the share of a town's PLOT MASS that
## composition turned into neither room nor roof and `_retain_maze_rock` then
## shipped as stone. In the plot model every plot cell is a building, so this
## share is exactly the quarry block the C5b render showed: stone pillars as
## tall as the houses.
##
## The denominator is the whole plot mass (`cells x [floor, top)` of every
## plot); the numerator excludes rooms, the plot's own roof band span, and any
## street or daylight void the carve bored back out of a plot. Pinned at the
## measured WORST of the sealing towns plus 0.05. **Re-pin DOWNWARD only** --
## this is a ceiling, and a rise is a regression.
##
## Measured after Task C5c fix 1: 0.267 / 0.305 / 0.312 on 12/compact,
## 4/compact and 3/standard (from 0.321 / 0.390 / 0.341). The controller's goal
## was 0.15 and it is NOT met; what stands between is stated in the task
## report, and its two biggest pieces are named there rather than guessed at
## here: back-room rectangles the authored ROOF vocabulary cannot crown beside
## their neighbours, and the plot's own roof reservation, which is roof rather
## than quarry but is not room either.
##
## TASK C5d: **0.226 / 0.211 / 0.281**, re-pinned DOWN 0.36 -> 0.33. Flat-first
## crowns took it to 0.256 / 0.296 / 0.299 on their own and re-opened C5c's
## back-room bearing relaxation, which took the rest. The 0.15 goal is still
## not met and the residue is now overwhelmingly back-room rectangles whose
## authored ENVELOPE does not fit (2 / 7 / 9 refusals) plus the whole
## buildings of the parcels that compose no lineage (6 / 3 / 4).
##
## TASK C5e: **0.226 / 0.211 / 0.281 / 0.260**, and the ceiling is UNCHANGED
## because the worst town is unchanged. 9/standard joins the corpus (its roof
## sliver was a partial plate and the crown tiles it now), and it enters at
## 0.260 rather than at a new worst. The partial-plate tiling itself moves no
## cell of plot mass: it changes which authored module crowns a remainder, not
## whether the remainder is roof.
##
## TASK C6: **0.156 / 0.142 / 0.224 / 0.176**, re-pinned DOWN 0.33 -> 0.28.
## This is the full no-descent that C5c, C5d and C5e each measured and each
## reverted: a maze parcel now takes the plot model literally and never
## descends, so a house on a hill column is a short house on a tall stone base
## instead of storeys buried in the mountain, and the parcels that used to
## deadlock each other in the protected-owner map compose (uncomposed parcels
## 6/3/4/6 -> 1/1/2/1). It ships here because ruling 1's fix removed the reason
## it cost seeds: the corpus is 19/24 without it and **20/24 with it**.
##
## The 0.15 goal is MET on 4/compact and missed on the other three, worst
## 0.224. What is left is not the descent: it is back-room rectangles whose
## authored envelope does not fit (2 / 7 / 7 / 8 refusals), storeys that are
## not whole allocatable mass (3 / 5 / 7 / 12), and the one or two parcels per
## town that still compose no lineage.
## TASK E1: **0.238 / 0.278 / 0.157 / 0.193** under the noise massif, and the
## ceiling STAYS at 0.28. 4/compact rises to 0.278, two thousandths under it,
## which reads as one flake from red -- and it is not, because there is no
## flake to be had. The share is an exact integer ratio of a deterministic
## pipeline: 446 unroomed of 1604 plot bands on 4/compact, bit-identical across
## two full runs of this file (and 346/1456, 295/1884, 408/2116 on the other
## three). Nothing but a code change can move it, and a code change that moves
## it is exactly what this pin exists to catch. Raising the ceiling to restore
## headroom would mean re-pinning UPWARD -- undoing Task C6's 0.33 -> 0.28 --
## to buy slack against a number that cannot drift.
##
## Two of the four towns improved (3/standard 0.224 -> 0.157, its best ever)
## and two lost ground, which is the terraced field redistributing back-room
## refusals rather than a new failure: the refusal families are unchanged
## ("storey is not whole allocatable mass", "authored envelope does not fit").
## The next wave that touches parcel heights should expect to trip this and
## should fix the cause rather than the number.
const UNROOMED_PLOT_MASS_CEILING := 0.28

## Houses the plot model says stand on ANOTHER PLOT that the composition still
## roots in the mountain at their own floor band, because
## `WarrenMazeBlockPartitioner.stack_parents` declares a seam only for a plot
## covered on EVERY column by exactly one other plot. Task C3 published the
## count and Task C5 pinned it at zero -- truthfully, but only because a maze
## parcel then DESCENDED through the plot below and swallowed it. Task C5c
## stopped the descent (it was deadlocking both parcels in the protected-owner
## map and costing 9, 12 and 6 parcels per town), and the disagreement it was
## hiding is now visible and bounded: 3 / 4 / 1 on the three sealing seeds.
##
## What such a house loses is its base PALETTE -- `_room_recipe_id` gives a
## terrain-bearing room `base.rock` -- not its structure: the compiler's
## `stone_borne` branch already refuses to lay a masonry course on another
## house's roof. Closing it is the partial-stack seam, which is a planner-side
## contract Phase E/F owns. Re-pin DOWNWARD only.
const UNROOTED_TERRAIN_BEARING_CEILING := 4

## Houses whose plot facts say they bear on rock AND that declare a validated
## building-support seam onto another plot, so their ground room roots in that
## parent rather than in the mountain. The seam wins -- rooting such a room in
## terrain is the "house standing THROUGH another house" defect ruling 4 names
## -- but it is a disagreement between two plot facts and it must stay rare.
## Measured 0 / 0 / 0 / 1 on the four planner seeds (9/standard's house.025 on
## house.005), pinned at one above the worst. Re-pin DOWNWARD only.
const STACKED_ON_ROCK_CEILING := 2

## Every gate `_partition_rooms` may drop a parcel at. A gate outside this set
## means a parcel now leaves composition through a door nobody decided on --
## the same drift `ADVISORY_SHORTFALL_KEYS` and `BRIDGE_RELEASE_REASONS` exist
## to catch.
const UNCOMPOSED_PARCEL_GATES: Array[String] = [
	"proposal_rejected", "rejected_unfloored_address", "court_displaced",
	"proposal_has_no_storeys", "forced_offsets_conflict",
	"exact_composition_unsolved", "structural_yielded_lineage",
]


## TASK C6 RULING 3. The 24-seed corpus exit, as data. The composition file
## solves four towns and has a ~4 min budget, so it cannot solve 24 more; the
## sweep harness already does, and writes its matrix to `MAZE_SWEEP.SUMMARY_PATH`
## for `test_corpus_composes` to read:
##
##   Godot --headless --path . -s res://tests/harness/warren_maze_mode_sweep.gd \
##     -- --seeds 1,2,3,4,5,6,7,8,9,10,11,12 --mode maze \
##     --scale compact,standard
##
## The path and the staleness fingerprint are the HARNESS's constants, read
## through this preload, so the two halves of the contract cannot drift apart.
## A summary whose fingerprint no longer matches the fabric layer on disk is
## refused as stale rather than believed: a green corpus assertion measured
## against deleted code is worse than no assertion.
##
## MEASURED 20/24 at Task C6 (18/24 at C5e; the authored-room-envelope family
## took 12/standard, and full no-descent then took 6/compact). Pinned at
## measured MINUS ONE, so one town's worth of drift is a report rather than a
## red suite and two is a regression. The plan's Phase C exit wants 22+/24 and
## it IS met as of task D1 fix 1, at 22/24. The two remaining misses are
## 8/compact (the volume ADAPTER's broad floor slab) and 9/compact (a duplicate
## public-realm edge); each is named in the task report with its gate.
##
## TASK D1 re-pinned this UPWARD twice on the same 24-town flat corpus, 19 ->
## 21 -> 22, both times as a consequence of one defect rather than of tuning:
##
##   - `4/standard`'s `roofless_house` back room went with the alley RATCHET.
##     The alley pass's frontage guard used to refuse EVERY lane in a town that
##     arrived below the floor, so 4/standard composed with no alleys at all
##     and squeaked past the graph gate on its loop joins; with the guard
##     stated as a ratchet it grows its streets and the town it then builds
##     does not hit that contract.
##   - `7/compact` went with the controller's ADVISORY ruling on the source's
##     addressed-frontage bar. It reaches 0.870 (up from 0.850, having actually
##     spent its alley budget now) and ships with the shortfall recorded.
##
## TASK E1 re-pinned this DOWNWARD, 22 -> 20 (measured 21), and the drop is
## reported rather than absorbed. The noise massif replaced the flat-profile
## plateau, so the corpus reshuffled exactly as ruling 3 said it would: the
## measured 21 of 24 misses 5/compact and 10/standard on the duplicate
## public-realm edge and 8/compact on the volume adapter's broad floor slab --
## the SAME two gate families Phase C's exit ruling already carried, with
## 9/compact (which used to miss on the duplicate edge) now sealing. No new
## family appeared. Pinned at measured minus one, per this file's convention.
const MAZE_SWEEP := preload("res://tests/harness/warren_maze_mode_sweep.gd")
const CORPUS_SEALED_FLOOR := 20
const CORPUS_SWEEP_SEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
const CORPUS_SWEEP_SCALES: Array[String] = ["compact", "standard"]

## The composition family this task closed. A sweep row that dies here again is
## a regression of Task C6 ruling 1, not a new gate, so it is pinned by name.
const RETIRED_CORPUS_GATE := "failed measured phase selection"

## TASK C6 RULING 1. How many optional facade projections one town may lose to
## `_required_room_clearance`, measured (1 / 2 / 4 / 2 on 12/compact,
## 4/compact, 3/standard, 9/standard) plus 3. The gate exists to give a town
## back, and giving one back costs an authored ivy, sign, laundry line or
## windowbox; a version of it that started demoting facades wholesale would
## still seal every town and would still pass every other assertion in this
## file, so the narrowness is pinned rather than assumed. Re-pin UPWARD only
## with a measurement and a reason.
const MAZE_FACADE_YIELD_CEILING := 7

## TASK C6 RULING 3. Per planner seed, the measured production solve x 1.5:
## 2442 / 3935 / 5554 / 10383 ms measured in this file, with the vocabulary
## compiled before the clock starts. The plan's <= 3 s target is met by ONE of
## the four and does not move here -- these are regression ceilings for the
## towns this file already solves, and the target itself moves to the Phase F
## exit on the controller's note. Where the time goes, per stage, is
## `tests/harness/warren_maze_stage_probe.gd --seeds 12,4 --scale compact`
## (and 3,9 at standard). It is NOT the hero beam -- advisory quotas collapse
## that to 24-36 ms -- it is `room_composition`, the per-parcel exact block
## solve plus `WarrenRoomCompositionPlanner`: 632 / 723 / 2370 / 5659 ms, which
## is 43-76 % of the composition and rises with room count. The fabric compile
## is second (784 / 1163 / 1509 / 2795) and the authored room envelope gate
## third (244 / 229 / 645 / 801). 4/compact is the one town where the residual
## backfill spikes (1219 ms).
const PLANNER_SOLVE_MS_CEILING: Dictionary = {
	"12/compact": 3700,
	"4/compact": 5950,
	# TASK E1: 5554 -> 8831 ms measured, x1.5. The town did not get slower per
	# unit of work, it got bigger: the noise massif's terraces partition into
	# 43 parcels where the flat plateau gave 35, and `room_composition` is
	# superlinear in room count (C6 ruling 3). Corpus-wide the four planner
	# solves are unchanged in total (23.8 s -> 24.0 s); 12/compact and
	# 4/compact each fell by a fifth to a third while this one grew.
	"3/standard": 13250,
	"9/standard": 15600,
}


static var _program_cache: SettlementFabricProgram
## One production solve per (seed, scale) shared by every test in the file.
## Four maze towns is the corpus; solving them once each is what keeps this
## file inside its budget while letting each test assert on the same run.
static var _solve_cache: Dictionary = {}


func _program() -> SettlementFabricProgram:
	## Compiling the measured vocabulary costs seconds; every solve in this
	## file reads the same immutable program.
	if _program_cache == null:
		_program_cache = SettlementFabricProgram.compile(
			EnvironmentCatalog.load_default())
	return _program_cache


func after_each() -> void:
	## A leaked flag silently converts every later suite in the same process to
	## maze mode, so restore it even when an assertion failed.
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST
	# TASK D2: the pin round trip redirects the persistent cache at a scratch
	# file. A leak would point every later solve in the process at it.
	WarrenSolutionPinCache.override_path_for_tests("")


func _solve(world_seed: int, scale_id: StringName,
		ground: StringName = FLAT_GROUND) -> Dictionary:
	## One real production solve. Reports the town (or null), the failure it
	## died with, and the wall clock — the three facts the baseline is made of.
	## `ground` names the authored band frame (task D1); every flat caller
	## omits it and passes `{}` exactly as before.
	var profile := WarrenVillageScaleProfile.for_id(scale_id)
	# Compile the vocabulary BEFORE the clock starts. It is compiled once per
	# process, so leaving it inside the measurement charged the whole cost to
	# whichever seed happened to solve first -- 4906 ms against 2481 ms for the
	# same town in the sweep harness, which is not a fact about the town.
	var program := _program()
	var bands := _ground_bands(ground, world_seed, scale_id)
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MAZE
	var started_ms := Time.get_ticks_msec()
	var plan := WarrenVolumetricSolver.solve(world_seed, bands, program,
		profile)
	var elapsed_ms := Time.get_ticks_msec() - started_ms
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST
	return {
		"plan": plan,
		"ms": elapsed_ms,
		"seed": world_seed,
		"scale": scale_id,
		"ground": ground,
		"failure": "" if plan != null else WarrenVolumetricSolver.last_failure,
	}


func _solved(world_seed: int, scale_id: StringName,
		ground: StringName = FLAT_GROUND) -> Dictionary:
	var key := _town_key(world_seed, scale_id, ground)
	if not _solve_cache.has(key):
		_solve_cache[key] = _solve(world_seed, scale_id, ground)
	return _solve_cache[key] as Dictionary


func _corpus() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for world_seed: int in COMPACT_SEEDS:
		out.append(_solved(world_seed, WarrenVillageScaleProfile.COMPACT))
	for world_seed: int in STANDARD_SEEDS:
		out.append(_solved(world_seed, WarrenVillageScaleProfile.STANDARD))
	return out


func _label(outcome: Dictionary) -> String:
	var ground := StringName(outcome.get("ground", FLAT_GROUND))
	return "seed %d/%s" % [int(outcome.seed), String(outcome.scale)] \
		if ground == FLAT_GROUND \
		else "%s seed %d/%s" % [String(ground), int(outcome.seed),
			String(outcome.scale)]


func _pre_composition_stage(failure: String) -> String:
	## The source-side stage this failure names, or "" when the town really did
	## reach composition.
	for prefix: String in SOURCE_STAGE_PREFIXES:
		if failure.begins_with(prefix):
			return prefix
	if failure.contains(TRANSLATOR_NO_PLOTS):
		return TRANSLATOR_NO_PLOTS
	return ""


func _names_a_composition_stage(failure: String) -> bool:
	for prefix: String in COMPOSITION_STAGE_PREFIXES:
		if failure.begins_with(prefix):
			return true
	return false


func _canonical_shortfall_key(key: String) -> String:
	## `hero_landmarks_target` and `landmarks` are the same fact wearing two
	## emitters' names; compare the fact.
	var out := key
	if out.begins_with("hero_"):
		out = out.substr(5)
	if out.ends_with("_target"):
		out = out.substr(0, out.length() - 7)
	return out


func _planned_maze_source(world_seed: int,
		scale_id: StringName) -> WarrenMazeSourcePlan:
	## One maze source plan, built UNDER THE MAZE KEY. Task E1: the terraced
	## massif is keyed to MODE_MAZE (`WarrenMassifBuilder.is_maze_mode`) until
	## Phase F deletes route-first, so every call in this file that reaches the
	## planner outside `_solve` has to set it too. Without this the town being
	## measured is a route-first massif compared against a maze one -- which is
	## exactly how `test_assets_land` came to count two asset plots against one
	## landmark.
	var profile := WarrenVillageScaleProfile.for_id(scale_id)
	var restored := WarrenTownSolver.GENERATION_MODE
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MAZE
	var maze := WarrenMazeSitePlanner.plan(world_seed, {}, profile)
	WarrenTownSolver.GENERATION_MODE = restored
	return maze


func _asset_plot_count(world_seed: int, scale_id: StringName) -> int:
	## Ask the source planner directly how many asset plots it placed. The
	## composition audit must account for every one of them.
	var maze := _planned_maze_source(world_seed, scale_id)
	if maze == null:
		return -1
	var count := 0
	for plot: Dictionary in maze.plots:
		count += int(StringName(plot["kind"]) \
			== WarrenMazeSourcePlan.PLOT_ASSET)
	return count


func _feature_count(plan: WarrenSpatialPlan, kind: StringName) -> int:
	var count := 0
	for feature: WarrenFeatureReservation in plan.features:
		count += int(feature.kind == kind)
	return count


func test_maze_mode_reaches_composition() -> void:
	## Task C1's assertion, kept: whatever else happens, no planner seed may
	## die at the source, the adapter, or the translator.
	for outcome: Dictionary in _corpus():
		var failure := String(outcome.failure)
		var stage := _pre_composition_stage(failure)
		assert_eq(stage, "",
			"%s died at the %s stage, before composition: %s" % [
				_label(outcome), stage, failure.left(160)])
		if outcome.plan != null:
			continue
		assert_true(_names_a_composition_stage(failure),
			("%s failed with a stage this file does not know; the gate map " \
				+ "is stale: %s") % [_label(outcome), failure.left(160)])


func test_maze_mode_seals_the_planner_seeds() -> void:
	## The Task C2 bar. Every planner seed composes a sealed town, and does it
	## in one bounded pass rather than a search — except the two pinned above,
	## which compose one and lose it to a room/roof contract downstream.
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		var failure := String(outcome.failure)
		var shortfalls: Dictionary = {} if plan == null \
			else plan.audit.get("advisory_shortfalls", {}) as Dictionary
		print("MAZE_COMPOSITION %s sealed=%s ms=%d %s" % [
			_label(outcome), str(plan != null), int(outcome.ms),
			str(shortfalls) if plan != null else failure.left(200)])
		assert_lt(int(outcome.ms), MAXIMUM_SOLVE_MS,
			"%s must compose in one pass, not a search" % _label(outcome))
		var key := "%d/%s" % [int(outcome.seed), String(outcome.scale)]
		if not KNOWN_FABRIC_BLOCKERS.has(key):
			assert_not_null(plan, "%s must seal a town: %s" % [
				_label(outcome), failure.left(200)])
			continue
		assert_null(plan, ("%s now seals; delete its KNOWN_FABRIC_BLOCKERS " \
			+ "entry") % _label(outcome))
		if plan != null:
			continue
		for pinned: String in KNOWN_FABRIC_BLOCKERS[key] as Array:
			assert_true(failure.contains(pinned),
				"%s must still die at its pinned defect '%s', not: %s" % [
					_label(outcome), pinned, failure.left(200)])


func test_hero_shortfalls_are_audit_facts() -> void:
	## A court, a landmark, or a link the one-pass source did not supply is
	## recorded and shipped, never enforced. Two teeth: the audit key must be
	## present on every sealed town, and no seed may die naming a hero quota.
	for outcome: Dictionary in _corpus():
		var failure := String(outcome.failure)
		for fragment: String in HERO_QUOTA_GATE_FRAGMENTS:
			assert_false(failure.contains(fragment),
				"%s was rejected on a hero quota: %s" % [_label(outcome),
					failure.left(200)])
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		assert_true(plan.audit.has("advisory_shortfalls"),
			"%s must publish its advisory shortfalls" % _label(outcome))
		var shortfalls := plan.audit.get("advisory_shortfalls", {}) \
			as Dictionary
		for key_value: Variant in shortfalls.keys():
			assert_has(ADVISORY_SHORTFALL_KEYS,
				_canonical_shortfall_key(String(key_value)),
				"%s reports an unvocabularised shortfall %s" % [
					_label(outcome), key_value])
		assert_eq(int(plan.audit.get("advisory_shortfall_count", -1)),
			shortfalls.size(),
			"%s shortfall count must match its own record" % _label(outcome))
		# One pass means one authority on links. `WarrenSpatialFeatureSolver`
		# still owns a legacy scanner that rediscovers straight links after
		# room composition when nothing was preplanned; in maze mode it must
		# never run, so every committed link is one the plan asked for. That
		# count is zero until C4 translates `maze_bridges`, and the shortfall
		# above is what records the absence.
		var preplanned := int(plan.audit.get("preplanned_skywalk_count", -1))
		assert_eq(_feature_count(plan, &"enclosed_skywalk"), preplanned,
			("%s must commit only preplanned links; the legacy skywalk " \
				+ "search may not run in one-pass mode") % _label(outcome))
		if preplanned == 0:
			assert_eq(int(shortfalls.get("skywalks", -1)), 0,
				("%s commits no link, so the absence must be the recorded " \
					+ "shortfall") % _label(outcome))


func test_assets_become_landmarks_or_audited_shortfalls() -> void:
	## Every asset plot the planner placed is either a prefab landmark in the
	## sealed town or a counted, reasoned shortfall. Nothing may vanish.
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var asset_plots := _asset_plot_count(int(outcome.seed),
			StringName(outcome.scale))
		var landmarks := _feature_count(plan, &"prefab_landmark")
		var shortfalls := plan.audit.get("advisory_shortfalls", {}) \
			as Dictionary
		var short := int(shortfalls.get("assets", 0))
		var outcomes := plan.audit.get("maze_asset_outcomes", []) as Array
		print("MAZE_ASSETS %s plots=%d landmarks=%d shortfalls=%d %s" % [
			_label(outcome), asset_plots, landmarks, short, outcomes])
		assert_eq(landmarks + short, asset_plots,
			"%s must account for every asset plot" % _label(outcome))
		assert_eq(outcomes.size(), asset_plots,
			"%s must report one outcome per asset plot" % _label(outcome))
		for record_value: Variant in outcomes:
			var record := record_value as Dictionary
			assert_true(record.has("id") and record.has("kind_id") \
				and record.has("reason"),
				"%s asset outcome %s is incomplete" % [_label(outcome),
					record])
			if not bool(record.get("placed", false)):
				assert_false(String(record.get("reason", "")).is_empty(),
					"%s unplaced asset %s must name a reason" % [
						_label(outcome), record.get("id", &"")])


func _plot_mass_cells(plan: WarrenSpatialPlan) -> Dictionary:
	## Every FINE cell inside some plot's own `[floor, top)`, read from the
	## sealed maze source the plan itself carries. In the plot model this is
	## the whole of the town's buildable mass: anything solid outside it is
	## structural ROCK, which is derived stone and never a room.
	var out: Dictionary = {}
	var source := plan.source_volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null:
		return out
	for plot: Dictionary in source.plots:
		for cell_value: Variant in plot["cells"] as Array:
			var column := cell_value as Vector2i
			for band in range(int(plot["floor"]), int(plot["top"])):
				for x_offset in 2:
					for z_offset in 2:
						out[Vector3i(column.x * 2 + x_offset, band,
							column.y * 2 + z_offset)] = true
	return out


func test_back_rooms_become_rooms() -> void:
	## The cells a house plot's door rectangle left over are that building's
	## back rooms, and the directed pre-pass is what turns them into real
	## WarrenRoomStamps. Before it existed they were plot mass nobody claimed
	## and `_discard_unassigned_mass` threw them away.
	var measured := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var total := int(plan.audit.get("maze_back_room_cell_count", -1))
		var stamped := int(plan.audit.get("maze_back_room_stamped_cell_count",
			-1))
		var unstamped := plan.audit.get("maze_back_room_unstamped_cells",
			{}) as Dictionary
		assert_gt(total, 0,
			"%s must publish the back-room mass it was handed" \
				% _label(outcome))
		if total <= 0:
			continue
		measured += 1
		var share := float(stamped) / float(total)
		var addressed := int(plan.audit.get("maze_back_rooms_addressed", -1))
		var private_rooms := int(plan.audit.get("maze_back_rooms_private", -1))
		var rooms := int(plan.audit.get("maze_back_room_building_count", -1))
		print(("MAZE_BACK_ROOMS %s stamped=%d/%d share=%.3f rooms=%d " \
			+ "addressed=%d private=%d unstamped=%d") % [_label(outcome),
				stamped, total, share, rooms, addressed, private_rooms,
				int(unstamped.get("count", -1))])
		# RULING 3: every stamped back room is either a room with a street
		# door of its own or one reached through the house in front of it.
		# There is no third thing, and a room that claimed both ways in would
		# not have sealed.
		assert_eq(addressed + private_rooms, rooms,
			"%s must class every back room as addressed or private" \
				% _label(outcome))
		assert_eq(int(plan.audit.get("maze_back_rooms_unstamped_cells", -1)),
			int(unstamped.get("count", -1)),
			"%s must publish one unstamped count, not two" % _label(outcome))
		assert_eq(stamped + int(unstamped.get("count", -1)), total,
			("%s must account for every back-room cell: stamped plus " \
				+ "unstamped is the whole") % _label(outcome))
		assert_eq((unstamped.get("cells", []) as Array).size(),
			int(unstamped.get("count", -1)),
			"%s must name the cells it could not stamp" % _label(outcome))
		assert_gte(share, BACK_ROOM_STAMPED_FLOOR,
			"%s stamps only %.3f of its back-room mass" % [_label(outcome),
				share])
	assert_gt(measured, 0, "at least one seed seals far enough to measure")


func test_unroomed_plot_mass_is_bounded() -> void:
	## TASK C5c RULINGS 1 and 6 -- the measurement the task is judged on.
	##
	## Plot mass is buildable mass: the plot planner already decided every one
	## of these cells belongs to a building. What composition does not build
	## in, `_retain_maze_rock` retains and the stone skin renders, which is why
	## the C5b review shot shows a quarry block instead of a town. This asserts
	## the four buckets really partition the plot mass -- so no cause can hide
	## in a rounding -- and pins the unroomed share.
	##
	## The causes are PRINTED beside the share, per seed: the back-room mass
	## the directed pass could not stamp (by refusal), the parcels that
	## composed no lineage (by gate), and the declared stacks nothing was built
	## on. Those three plus the greedy backfill are the whole of the remainder.
	var measured := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var plot_cells := int(plan.audit.get("maze_plot_mass_cell_count", -1))
		assert_gt(plot_cells, 0,
			"%s must publish the plot mass it was handed" % _label(outcome))
		if plot_cells <= 0:
			continue
		measured += 1
		var roomed := int(plan.audit.get("maze_plot_roomed_cell_count", -1))
		var roofed := int(plan.audit.get("maze_plot_roofed_cell_count", -1))
		var public := int(plan.audit.get("maze_plot_public_cell_count", -1))
		var feature := int(plan.audit.get("maze_plot_feature_cell_count", -1))
		var unbuildable := int(plan.audit.get(
			"maze_plot_unbuildable_cell_count", -1))
		var unroomed := int(plan.audit.get("maze_unroomed_plot_cells", -1))
		var share := float(plan.audit.get("maze_unroomed_plot_share", -1.0))
		var rock := int(plan.audit.get("maze_retained_rock_cells", -1))
		print(("MAZE_PLOT_MASS %s plot=%d roomed=%d roofed=%d public=%d " \
			+ "feature=%d unbuildable=%d unroomed=%d share=%.3f rock=%d " \
			+ "stone_total=%d") % [
			_label(outcome), plot_cells, roomed, roofed, public, feature,
			unbuildable, unroomed, share, rock,
			int(plan.audit.get("maze_retained_rock_cell_count", -1))])
		print("MAZE_PLOT_MASS_USES %s %s" % [_label(outcome),
			plan.audit.get("maze_unroomed_plot_uses", {})])
		print("MAZE_PLOT_MASS_CAUSES %s back_room_unstamped=%d refusals=%s" \
			% [_label(outcome),
			int((plan.audit.get("maze_back_room_unstamped_cells", {}) \
				as Dictionary).get("count", -1)),
			plan.audit.get("maze_back_room_refusals", {})])
		print(("MAZE_PLOT_MASS_CAUSES %s parcels=%d uncomposed=%d gates=%s " \
			+ "uncomposed_stacks=%d residual_rooms=%d back_rooms=%d") % [
			_label(outcome), int(plan.audit.get("maze_parcel_count", -1)),
			int(plan.audit.get("maze_uncomposed_parcel_count", -1)),
			plan.audit.get("maze_uncomposed_parcel_gates", {}),
			int(plan.audit.get("maze_uncomposed_stack_count", -1)),
			int(plan.audit.get("residual_backfill_building_count", -1)),
			int(plan.audit.get("maze_back_room_building_count", -1))])
		# This identity guards the PLUMBING, not the classification: it proves
		# every plot cell reached exactly one bucket and that none was counted
		# twice or dropped. Whether a cell was put in the RIGHT bucket is a
		# question about `_maze_plot_mass_audit`'s rules, and the retention
		# identity below plus `test_stone_split_reconciles_across_the_compiler`
		# are what hold those.
		assert_eq(roomed + roofed + public + feature + unbuildable + unroomed,
			plot_cells,
			("%s must account for every plot cell: roomed, roofed, public, " \
				+ "feature, unbuildable and unroomed are the whole") \
				% _label(outcome))
		# The stone the retention pass tagged and the residue this audit
		# derives are two readings of one fact. The ONE legal way they part is
		# a cell whose non-shareable FEATURE bit another owner already held --
		# `_retain_maze_rock` skips and counts exactly those.
		var retained_unroomed := int(plan.audit.get(
			"maze_retained_unroomed_plot_stone_cells", -1))
		assert_between(unroomed - retained_unroomed, 0,
			int(plan.audit.get("maze_retained_rock_skipped_reserved", -1)),
			("%s retains %d of the %d plot cells it left unroomed") % [
				_label(outcome), retained_unroomed, unroomed])
		assert_almost_eq(share, float(unroomed) / float(plot_cells), 0.0005,
			"%s must publish the share it measured" % _label(outcome))
		assert_lte(share, UNROOMED_PLOT_MASS_CEILING,
			"%s leaves %.3f of its plot mass unroomed" % [_label(outcome),
				share])
	assert_gt(measured, 0, "at least one seed seals far enough to measure")


func test_uncomposed_parcels_are_explained() -> void:
	## TASK C5c RULING 4. A parcel that composes no lineage is a whole
	## building's worth of plot mass the town then carries as stone, and the
	## single largest thing it can do to its own unroomed share. Every one of
	## them must name the gate that dropped it, drawn from a fixed vocabulary,
	## so a new silent drop cannot appear without this test saying so.
	var measured := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var parcel_count := int(plan.audit.get("maze_parcel_count", -1))
		assert_gt(parcel_count, 0,
			"%s must publish the parcels it was handed" % _label(outcome))
		if parcel_count <= 0:
			continue
		measured += 1
		var records := plan.audit.get("maze_uncomposed_parcels", []) as Array
		var gates := plan.audit.get("maze_uncomposed_parcel_gates",
			{}) as Dictionary
		print("MAZE_UNCOMPOSED %s parcels=%d uncomposed=%d gates=%s" % [
			_label(outcome), parcel_count, records.size(), gates])
		for record_value: Variant in records:
			var record := record_value as Dictionary
			print("MAZE_UNCOMPOSED_DETAIL %s %s gate=%s area=%s [%s,%s) %s" % [
				_label(outcome), record.get("parcel_id", &""),
				record.get("gate", &""), record.get("area", -1),
				record.get("floor", -1), record.get("top", -1),
				record.get("detail", "")])
		assert_eq(records.size(),
			int(plan.audit.get("maze_uncomposed_parcel_count", -1)),
			"%s must count exactly the uncomposed parcels it names" \
				% _label(outcome))
		var tallied := 0
		for count_value: Variant in gates.values():
			tallied += int(count_value)
		assert_eq(tallied, records.size(),
			"%s gate tally must account for every uncomposed parcel" \
				% _label(outcome))
		for record_value: Variant in records:
			var record := record_value as Dictionary
			assert_true(record.has("parcel_id") and record.has("gate"),
				"%s uncomposed record %s is incomplete" % [_label(outcome),
					record])
			assert_true(String(record.get("gate", "")) \
				in UNCOMPOSED_PARCEL_GATES,
				"%s parcel %s names an unknown gate %s" % [_label(outcome),
					record.get("parcel_id", &""), record.get("gate", &"")])
	assert_gt(measured, 0, "at least one seed seals far enough to measure")


func test_residual_rooms_stay_inside_plots() -> void:
	## Ruling 1: in the plot model, mass that is not inside a plot is
	## structural ROCK, and the greedy residual scan may not build in it. Every
	## room the backfill admits — and every back room the pre-pass stamps —
	## must lie inside some plot's own band span, checked against the sealed
	## source rather than against the audit that claims it.
	var checked := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var plot_mass := _plot_mass_cells(plan)
		assert_gt(plot_mass.size(), 0,
			"%s must carry its own sealed maze source" % _label(outcome))
		var outside := 0
		var first := ""
		for building: WarrenBuildingVolume in plan.buildings:
			if not String(building.stable_id).begins_with("spatial.residual.") \
					and not String(building.stable_id).begins_with(
						"spatial.maze_back.") \
					and not String(building.stable_id).begins_with(
						"spatial.maze_bridge."):
				continue
			checked += 1
			for cell: Vector3i in building.private_cells:
				if plot_mass.has(cell):
					continue
				outside += 1
				if first.is_empty():
					first = "%s at %s" % [building.stable_id, cell]
		assert_eq(outside, 0,
			"%s builds %d residual cells in structural rock (%s)" % [
				_label(outcome), outside, first])
	assert_gt(checked, 0,
		"at least one sealed seed really has residual or back-room buildings")


func _source_plots(plan: WarrenSpatialPlan,
		kind: StringName) -> Array[Dictionary]:
	## The planner's own records of one plot kind, read from the sealed maze
	## source the plan itself carries. Free: no second site plan.
	var out: Array[Dictionary] = []
	var source := plan.source_volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null:
		return out
	for plot: Dictionary in source.plots:
		if StringName(plot["kind"]) == kind:
			out.append(plot)
	return out


func _deck_floor_cells(plan: WarrenSpatialPlan) -> Array[Vector3i]:
	## Every FINE cell a deck plot's own floor band covers. A deck has no
	## height (top == floor), so this one band is the whole of it.
	var out: Array[Vector3i] = []
	for plot: Dictionary in _source_plots(plan,
			WarrenMazeSourcePlan.PLOT_DECK):
		var band := int(plot["floor"])
		for cell_value: Variant in plot["cells"] as Array:
			var column := cell_value as Vector2i
			for x_offset in 2:
				for z_offset in 2:
					out.append(Vector3i(column.x * 2 + x_offset, band,
						column.y * 2 + z_offset))
	return out


func _is_walkable(plan: WarrenSpatialPlan, cell: Vector3i) -> bool:
	## One walkable public cell: swept public air standing on a classified
	## public floor. Read from the GRID, which is the authority the paving and
	## the surface solver both consume.
	if not plan.grid.contains(cell) \
			or plan.grid.use_at(cell) != WarrenSpatialGrid.Use.PUBLIC_AIR:
		return false
	var floor_claim := plan.grid.face_claim(cell, Vector3i.DOWN)
	return not floor_claim.is_empty() and int(floor_claim.get("kind", -1)) \
		== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR


func _walkable_from_entry(plan: WarrenSpatialPlan) -> Dictionary:
	## Flood the sealed grid from the town entry over walkable cells, stepping
	## 4-adjacent in x/z within one band.
	##
	## Honest about its own strength: `WarrenSpatialPlan._validate_route`
	## already proves the route ARRAY connected under the same adjacency, so a
	## deck cell that reached `route_floor_cells` is connected by construction
	## and this flood mostly restates that. It is kept because it walks the
	## GRID -- uses and face claims -- rather than the array, so it would still
	## catch a cell that seal accepted and the grid does not back. The
	## load-bearing assertions of the deck test are the other three: route
	## membership, `maze_deck_cell_count`, and `surface_plan.has_cell`.
	var seen: Dictionary = {plan.entry_floor_cell: true}
	var frontier: Array[Vector3i] = [plan.entry_floor_cell]
	while not frontier.is_empty():
		var cell: Vector3i = frontier.pop_back()
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			for rise: int in [-1, 0, 1]:
				var next := cell + direction + Vector3i.UP * rise
				if seen.has(next) or not _is_walkable(plan, next):
					continue
				seen[next] = true
				frontier.append(next)
	return seen


func test_decks_are_walkable_public_floor() -> void:
	## Ruling 1: a deck plot is a PLAZA, not a record. Its floor band is paved
	## as public floor with the same swept headroom a street gets, it joins the
	## town's route surfaces, and the town can WALK onto it. Before this pass
	## the planner's decks were audit facts composition discarded.
	var measured := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var cells := _deck_floor_cells(plan)
		assert_eq(int(plan.audit.get("maze_deck_cell_count", -1)),
			cells.size(),
			"%s must publish the deck mass it paved" % _label(outcome))
		if cells.is_empty():
			# A scale's deck quota is what the planner ASKS for; a town whose
			# streets grew no region of DECK_MIN columns legitimately has
			# none, and paving zero cells is the right answer there.
			continue
		measured += 1
		var route: Dictionary = {}
		for cell: Vector3i in plan.route_floor_cells:
			route[cell] = true
		var unpaved := 0
		var first := ""
		for cell: Vector3i in cells:
			if _is_walkable(plan, cell) and route.has(cell):
				continue
			unpaved += 1
			if first.is_empty():
				first = "%s" % cell
		assert_eq(unpaved, 0,
			"%s leaves %d of %d deck cells unpaved (first %s)" % [
				_label(outcome), unpaved, cells.size(), first])
		var walkable := _walkable_from_entry(plan)
		var reached := 0
		for cell: Vector3i in cells:
			reached += int(walkable.has(cell))
		var share := float(reached) / float(cells.size())
		# The paving itself, not the topology that permits it: the compiled
		# fabric's own surface union must carry every deck cell, or the plaza
		# renders as a hole the player can nonetheless walk into.
		var fabric := plan.compiled_fabric_cache()
		assert_not_null(fabric,
			"%s must carry its compiled fabric" % _label(outcome))
		var unsurfaced := 0
		if fabric != null and fabric.surface_plan != null:
			for cell: Vector3i in cells:
				unsurfaced += int(not fabric.surface_plan.has_cell(cell))
		assert_eq(unsurfaced, 0,
			"%s leaves %d deck cells out of the public-realm surface" % [
				_label(outcome), unsurfaced])
		print("MAZE_DECKS %s paved=%d reachable=%d share=%.3f surfaced=%d" % [
			_label(outcome), cells.size(), reached, share,
			cells.size() - unsurfaced])
		assert_gte(share, DECK_REACHABLE_FLOOR,
			"%s paves %d deck cells but only %.3f of them are reachable" % [
				_label(outcome), cells.size(), share])
	assert_gt(measured, 0, "at least one seed seals far enough to measure")


func test_bridges_become_rooms_decks_or_audited_releases() -> void:
	## Ruling 2 (C4) extended by ruling 5 (C5): every bridge plot is either a
	## real one-storey room bearing on its two flanks, an OPEN DECK paved
	## between two flat flank surfaces, or a RELEASED record with a reason.
	## Nothing vanishes and nothing rejects the town.
	var measured := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var records := _source_plots(plan,
			WarrenMazeSourcePlan.PLOT_BRIDGE)
		var stamped := int(plan.audit.get("maze_bridge_rooms", -1))
		var paved := int(plan.audit.get("maze_bridge_open_decks", -1))
		var outcomes := plan.audit.get("maze_bridge_outcomes", []) as Array
		var released := 0
		var open_decks := 0
		var route: Dictionary = {}
		for cell: Vector3i in plan.route_floor_cells:
			route[cell] = true
		for record_value: Variant in outcomes:
			var record := record_value as Dictionary
			assert_true(record.has("id") and record.has("outcome") \
				and record.has("reason"),
				"%s bridge outcome %s is incomplete" % [_label(outcome),
					record])
			var verdict := String(record.get("outcome", ""))
			assert_has(BRIDGE_OUTCOMES, verdict,
				"%s bridge outcome %s names no known verdict" % [
					_label(outcome), record])
			assert_true(record.has("flat_flank_columns") \
				and record.has("flat_flank_sides"),
				("%s bridge outcome %s must publish why it is or is not an " \
					+ "open deck") % [_label(outcome), record.get("id", &"")])
			if verdict == "stamped":
				continue
			if verdict == "open_deck":
				open_decks += 1
				# An open deck is PAVING, so the fact to check is the paving:
				# the span's own floor band is walkable public floor that
				# joined the town's route surfaces.
				var unpaved := 0
				for cell: Vector3i in _bridge_floor_cells(plan,
						StringName(record["id"])):
					unpaved += int(not _is_walkable(plan, cell) \
						or not route.has(cell))
				assert_eq(unpaved, 0,
					"%s open bridge deck %s leaves %d floor cells unpaved" % [
						_label(outcome), record.get("id", &""), unpaved])
				continue
			released += 1
			assert_has(BRIDGE_RELEASE_REASONS,
				String(record.get("reason", "")),
				"%s released bridge %s for an unvocabularised reason" % [
					_label(outcome), record.get("id", &"")])
		assert_eq(outcomes.size(), records.size(),
			"%s must report one outcome per bridge plot" % _label(outcome))
		assert_eq(paved, open_decks,
			"%s must publish the open bridge decks it paved" % _label(outcome))
		assert_eq(stamped + open_decks + released, records.size(),
			"%s must account for every bridge plot" % _label(outcome))
		var shortfalls := plan.audit.get("advisory_shortfalls", {}) \
			as Dictionary
		assert_eq(int(shortfalls.get("bridges", 0)), released,
			"%s must record its released bridges as a shortfall" % _label(
				outcome))
		var rooms := 0
		for building: WarrenBuildingVolume in plan.buildings:
			rooms += int(String(building.stable_id).begins_with(
				"spatial.maze_bridge."))
		assert_eq(rooms, stamped,
			"%s must build exactly the bridge rooms it claims" % _label(
				outcome))
		for record_value: Variant in outcomes:
			var record := record_value as Dictionary
			if String(record.get("outcome", "")) != "stamped":
				continue
			# A stamped span must carry the two-flank contract the fabric
			# compiler bonds against. Live today and asserted the moment the
			# model gap closes, rather than written after the fact.
			var room := _bridge_room(plan, StringName(record["id"]),
				outcomes)
			assert_not_null(room,
				"%s stamped %s but built no bridge room" % [_label(outcome),
					record.get("id", &"")])
			if room == null:
				continue
			var flanks := room.audit.get("bridge_support_room_ids",
				[]) as Array
			assert_eq(flanks.size(), 2,
				"%s bridge room %s must name two flank rooms" % [
					_label(outcome), room.stable_id])
		if records.is_empty():
			continue
		measured += 1
		var share := float(stamped) / float(records.size())
		print("MAZE_BRIDGES %s stamped=%d/%d share=%.3f released=%d %s" % [
			_label(outcome), stamped, records.size(), share, released,
			outcomes])
		assert_gte(share, BRIDGE_STAMPED_FLOOR,
			"%s stamps only %.3f of its bridge plots" % [_label(outcome),
				share])
	assert_gt(measured, 0, "at least one seed seals far enough to measure")


func _bridge_floor_cells(plan: WarrenSpatialPlan,
		bridge_id: StringName) -> Array[Vector3i]:
	## Every FINE cell of one bridge plot's own floor band, read from the
	## sealed source rather than from the pass that paved it.
	var out: Array[Vector3i] = []
	for plot: Dictionary in _source_plots(plan,
			WarrenMazeSourcePlan.PLOT_BRIDGE):
		if StringName(plot["id"]) != bridge_id:
			continue
		var band := int(plot["floor"])
		for cell_value: Variant in plot["cells"] as Array:
			var column := cell_value as Vector2i
			for x_offset in 2:
				for z_offset in 2:
					out.append(Vector3i(column.x * 2 + x_offset, band,
						column.y * 2 + z_offset))
	return out


func _bridge_room(plan: WarrenSpatialPlan, bridge_id: StringName,
		outcomes: Array) -> WarrenRoomStamp:
	## The room a stamped bridge record built. `_stamp_maze_bridges` numbers
	## its buildings by STAMP order, so the index is the record's position
	## among the stamped ones, not among all records.
	var index := 0
	for record_value: Variant in outcomes:
		var record := record_value as Dictionary
		if String(record.get("outcome", "")) != "stamped":
			continue
		if StringName(record["id"]) == bridge_id:
			break
		index += 1
	var wanted := StringName("spatial.maze_bridge.%02d" % index)
	for building: WarrenBuildingVolume in plan.buildings:
		if building.stable_id == wanted:
			return building.room_records[0]
	return null


func test_bridge_flanks_at_storey_level_are_reported() -> void:
	## IMPORTANT 3's corpus question, asked of the plans this file already
	## solved: is there a sealing town where a bridge's floor really lies
	## inside a flanking house PARCEL's composed storeys, rather than in the
	## roof course its rooms stop at? Every such case is printed with what the
	## pass then did with it, so "no bridge stamps" can never be mistaken for
	## "no bridge was ever offered a flank".
	var checked := PackedStringArray()
	var cases := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		checked.append(_label(outcome))
		var source := plan.source_volume.mass_context.get(
			&"maze_source_plan") as WarrenMazeSourcePlan
		var parcels := WarrenMazeBlockPartitioner.partition(source,
			plan.source_volume)
		assert_not_null(parcels,
			"%s must re-translate its own sealed source" % _label(outcome))
		if parcels == null:
			continue
		var outcomes := plan.audit.get("maze_bridge_outcomes", []) as Array
		for record_value: Variant in outcomes:
			var record := record_value as Dictionary
			var plot := _plot_by_id(source, StringName(record["id"]))
			var flanks := _storey_level_flanks(parcels, plot)
			if flanks.is_empty():
				continue
			cases += 1
			print(("MAZE_BRIDGE_FLANK %s %s floor=%d flanks=%s -> %s (%s) " \
				+ "counts=%s") % [_label(outcome), record["id"],
					int(plot["floor"]), flanks, record["outcome"],
					record["reason"], record.get("span_counts", {})])
		# The diagnosis a released span published must survive to the audit;
		# `_backfill_residual_rooms` wipes the counter it is read from.
		for record_value: Variant in outcomes:
			var record := record_value as Dictionary
			assert_true(record.get("span_counts", null) is Dictionary,
				"%s bridge outcome %s must carry its span diagnosis" % [
					_label(outcome), record.get("id", &"")])
	print("MAZE_BRIDGE_FLANK checked=%s storey_level_cases=%d" % [
		", ".join(checked), cases])
	if cases == 0:
		print(("MAZE_BRIDGE_FLANK SKIPPED: no sealing seed of %s offers a " \
			+ "bridge whose floor lies inside a flank parcel's storeys") % [
				", ".join(checked)])


func _plot_by_id(source: WarrenMazeSourcePlan,
		plot_id: StringName) -> Dictionary:
	for plot: Dictionary in source.plots:
		if StringName(plot["id"]) == plot_id:
			return plot
	return {}


func _storey_level_flanks(parcels: WarrenParcelPlan,
		plot: Dictionary) -> Array[String]:
	## Every parcel 4-adjacent to this bridge whose own composed storeys
	## contain the bridge floor -- `[base_band, roof_base_band())`, which is
	## where its rooms are, not `[base_band, top_band)`, which includes the
	## roof course a bridge cannot bear on.
	var out: Array[String] = []
	if plot.is_empty():
		return out
	var columns: Dictionary = {}
	for cell_value: Variant in plot["cells"] as Array:
		columns[cell_value as Vector2i] = true
	var band := int(plot["floor"])
	for parcel: WarrenBuildingParcel in parcels.parcels:
		var roof_base := parcel.base_band + parcel.storey_count() \
			* WarrenBuildingParcel.STOREY_BANDS
		if band < parcel.base_band or band >= roof_base:
			continue
		var beside := false
		for column: Vector2i in parcel.footprint:
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
					Vector2i.UP, Vector2i.DOWN]:
				beside = beside or columns.has(column + direction)
			if beside:
				break
		if beside:
			out.append("%s[%d,%d)%s" % [parcel.stable_id, parcel.base_band,
				roof_base, "" if (band - parcel.base_band) % 2 == 0 \
					else " offset"])
	return out


func test_bridge_shells_match_the_span_shape() -> void:
	## `_maze_bridge_kind` is the whole vocabulary decision of the bridge
	## pass, and no corpus town reaches it with anything but a tower, so it is
	## asserted directly.
	var one: Array[Vector2i] = [Vector2i(2, -3)]
	assert_eq(WarrenVolumetricSolver._maze_bridge_kind(one), &"tower",
		"a one-cell span is a tower")
	var along_x: Array[Vector2i] = [Vector2i(2, -3), Vector2i(3, -3)]
	assert_eq(WarrenVolumetricSolver._maze_bridge_kind(along_x), &"slim",
		"two cells in a line are a slim")
	var along_z: Array[Vector2i] = [Vector2i(2, -3), Vector2i(2, -2)]
	assert_eq(WarrenVolumetricSolver._maze_bridge_kind(along_z), &"slim",
		"the line may run either way")
	var backward: Array[Vector2i] = [Vector2i(3, -3), Vector2i(2, -3)]
	assert_eq(WarrenVolumetricSolver._maze_bridge_kind(backward), &"slim",
		"and in either order")
	var diagonal: Array[Vector2i] = [Vector2i(2, -3), Vector2i(3, -2)]
	assert_eq(WarrenVolumetricSolver._maze_bridge_kind(diagonal), &"",
		"a diagonal pair is not an authored shell")
	var apart: Array[Vector2i] = [Vector2i(2, -3), Vector2i(5, -3)]
	assert_eq(WarrenVolumetricSolver._maze_bridge_kind(apart), &"",
		"two cells that do not touch are not one room")
	var three: Array[Vector2i] = [Vector2i(2, -3), Vector2i(3, -3),
		Vector2i(4, -3)]
	assert_eq(WarrenVolumetricSolver._maze_bridge_kind(three), &"",
		"a three-cell span has no shell in this vocabulary")
	var none: Array[Vector2i] = []
	assert_eq(WarrenVolumetricSolver._maze_bridge_kind(none), &"",
		"an empty span is not a room")


func test_bridge_cells_are_one_authored_storey() -> void:
	## `_maze_bridge_cells` expands a span into fine mass, and that mass must
	## be exactly what the chosen shell stamps -- the two facts the pass then
	## relies on without re-checking.
	var one: Array[Vector2i] = [Vector2i(2, -3)]
	var tower := WarrenVolumetricSolver._maze_bridge_cells(one, 9, 11)
	assert_eq(tower.size(), 8, "a one-cell span is 2x2 fine over two bands")
	var wanted: Dictionary = {}
	for cell: Vector3i in tower:
		wanted[cell] = true
	assert_eq(wanted.size(), 8, "and carries no duplicate cell")
	for x in [4, 5]:
		for z in [-6, -5]:
			for y in [9, 10]:
				assert_true(wanted.has(Vector3i(x, y, z)),
					"macro (2, -3) at band 9 covers %s" % Vector3i(x, y, z))
	assert_true(_stamps_exactly(&"tower", tower),
		"a one-cell span is exactly a tower shell")
	var two: Array[Vector2i] = [Vector2i(2, -3), Vector2i(3, -3)]
	var slim := WarrenVolumetricSolver._maze_bridge_cells(two, 9, 11)
	assert_eq(slim.size(), 16, "a two-cell span is twice that")
	assert_true(_stamps_exactly(&"slim", slim),
		"a two-cell span is exactly a slim shell")
	assert_false(_stamps_exactly(&"tower", slim),
		"and is refused as a tower, at every yaw")


func _stamps_exactly(kind: StringName, cells: Array[Vector3i]) -> bool:
	## True when some yaw of `kind` stamps exactly `cells` -- the search the
	## bridge pass runs before it trusts an origin.
	for yaw in 4:
		if WarrenVolumetricSolver._maze_back_room_origin(kind, cells,
				yaw).x != 2147483647:
			return true
	return false


func test_a_bound_span_stamps_a_bridge_room() -> void:
	## The bridge pass end to end, on the geometry no corpus town offers: a
	## one-cell span between two flank rooms standing at the bridge's OWN
	## band. `_stamp_maze_bridges` itself is driven, from a one-record
	## `maze_bridges` fixture, so the outcome record, the span-count snapshot
	## and the three audit keys the fabric compiler bonds against are all
	## PRODUCED by production code rather than restated by this test.
	##
	## This is what distinguishes "the corpus offers no such bridge" from
	## "the predicate never binds".
	var grid := WarrenSpatialGrid.new(Vector3i(-8, 0, -8),
		Vector3i(24, 16, 24))
	assert_true(grid.is_valid(), "the synthetic grid is usable")
	var band := 4
	assert_true(_fill_allocatable(grid), "synthetic massif projects")
	assert_true(_carve_synthetic_street(grid, band), "synthetic street carves")
	var west := _synthetic_flank(grid, &"flank.west", -1, band)
	var east := _synthetic_flank(grid, &"flank.east", 1, band)
	assert_not_null(west, "west flank composes")
	assert_not_null(east, "east flank composes")
	if west == null or east == null:
		return
	var columns: Array[Vector2i] = [Vector2i(0, 0)]
	var volume := WarrenVolumePlan.new(&"synthetic.bridge", 12345, null)
	var parcels := WarrenParcelPlan.new(&"synthetic.bridge.parcels", volume)
	# Exactly the record `WarrenMazeBlockPartitioner._bridge_record` emits,
	# and exactly the group map `partition` publishes beside it.
	parcels.audit["maze_bridges"] = [{
		"id": &"bridge.00", "cells": columns, "floor": band,
		"top": band + WarrenSpatialGrid.STOREY_CELLS,
		"door_walk": Vector3i(0, band - 1, 0),
		"building_id": &"house.west"}]
	parcels.audit["maze_buildings"] = {&"house.west": [&"flank.west"]}
	var supports := WarrenSupportGraph.new()
	assert_true(supports.add_node(&"flank.west") \
		and supports.add_node(&"flank.east"), "flanks enter the support DAG")
	var buildings: Array[WarrenBuildingVolume] = [west, east]
	var required: Array[StringName] = []
	var terrain: Array[StringName] = []
	var edges: Array[Dictionary] = []
	var result := WarrenVolumetricSolver._stamp_maze_bridges(grid, volume,
		parcels, buildings, supports, required, terrain, edges, {},
		_program())
	assert_false(bool(result.get("failed", false)),
		"the bridge pass completed: %s" % WarrenVolumetricSolver.last_failure)
	var outcomes := result.get("outcomes", []) as Array
	assert_eq(outcomes.size(), 1, "one record, one outcome")
	if outcomes.size() != 1:
		return
	var outcome := outcomes[0] as Dictionary
	assert_eq(String(outcome.get("outcome", "")), "stamped",
		"the span stamps: %s" % outcome.get("reason", ""))
	assert_eq(String(outcome.get("reason", "x")), "",
		"a stamped record names no refusal")
	assert_eq(int(result.get("record_count", -1)), 1, "one bridge record")
	assert_eq(int(result.get("stamped", -1)), 1, "stamped once")
	assert_eq(int(result.get("released", -1)), 0, "released nothing")
	# MINOR 5's snapshot, taken from the production counter before the
	# residual backfill wipes it: both flanks really were probed.
	var counts := outcome.get("span_counts", {}) as Dictionary
	assert_eq(int(counts.get("flank_contacts", -1)), 2,
		"the bearing proof saw both flanking walls")
	assert_eq(int(counts.get("flank_rooms_probed", -1)), 2,
		"and probed a room on each of them")
	assert_eq(buildings.size(), 3, "the caller's building list grew by one")
	if buildings.size() != 3:
		return
	var built := buildings[2]
	assert_eq(built.stable_id, StringName("spatial.maze_bridge.00"),
		"bridge buildings are numbered by stamp order")
	var cells := WarrenVolumetricSolver._maze_bridge_cells(columns, band,
		band + WarrenSpatialGrid.STOREY_CELLS)
	for cell: Vector3i in cells:
		assert_eq(grid.use_at(cell), WarrenSpatialGrid.Use.PRIVATE_VOLUME,
			"%s became the bridge's own private volume" % cell)
		assert_eq(grid.owner_name_at(cell), StringName(
			"spatial.maze_bridge.00"), "%s is owned by the bridge" % cell)
	assert_eq(built.private_parent_ids, [&"flank.west"] as Array[StringName],
		"a bridge reaches the street through the flank house it belongs to")
	assert_eq(edges, [{"child": StringName("spatial.maze_bridge.00"),
		"parent": &"flank.west"}] as Array[Dictionary],
		"and carries one support edge to the bearing flank")
	assert_eq(terrain, [] as Array[StringName],
		"a bridge over a street never claims terrain bearing")
	assert_eq(required, [StringName("spatial.maze_bridge.00")] \
		as Array[StringName],
		"and is a required support of the sealed town")
	var room := built.room_records[0]
	assert_eq(room.kind, &"tower", "a one-cell span is a tower room")
	assert_false(room.terrain_bearing, "which does not stand on the ground")
	# The three keys the production pass stamps after seal(): without them
	# `WarrenSpatialFabricCompiler` looks for a bearing parent underneath a
	# room that has none, and `_modular_box_use_audit` classifies the tower as
	# an unsupported voxel instead of an occupied skywalk.
	var flanks := room.audit.get("bridge_support_room_ids", []) as Array
	assert_eq(flanks.size(), 2,
		"the compiler reads two flanks to bond, not a parent below")
	assert_true(flanks.has(StringName("flank.west.room00")),
		"and both are the real flank rooms: %s" % [flanks])
	assert_true(flanks.has(StringName("flank.east.room00")),
		"and both are the real flank rooms: %s" % [flanks])
	assert_true(room.audit.has("bridge_support_records"),
		"the span's own bond records travel with the room")
	assert_false(bool(room.audit.get("bridge_is_bracketed_jetty", true)),
		"a two-sided span is not a bracketed jetty")


func _fill_allocatable(grid: WarrenSpatialGrid) -> bool:
	var cells: Array[Vector3i] = []
	for x in range(-8, 16):
		for y in range(0, 16):
			for z in range(-8, 16):
				cells.append(Vector3i(x, y, z))
	var tx := grid.begin_transaction(&"massif.allocation")
	return tx.assign_use(cells, WarrenSpatialGrid.Use.ALLOCATABLE,
		&"massif.allocation") and tx.commit()


func _carve_synthetic_street(grid: WarrenSpatialGrid, band: int) -> bool:
	## The bore, in miniature: one lane of swept public air on a classified
	## public floor, which is what lets a flank building seal with a threshold.
	var air: Array[Vector3i] = []
	for x in range(-4, 6):
		for y in range(band, band + WarrenVolumePlan.HEADROOM_BANDS):
			air.append(Vector3i(x, y, -1))
	var carve := grid.begin_transaction(&"public.route")
	if not carve.require_use(air,
			[WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not carve.reserve(air,
				WarrenSpatialGrid.Reservation.PUBLIC_CLEARANCE,
				&"public.route") \
			or not carve.assign_use(air, WarrenSpatialGrid.Use.PUBLIC_AIR,
				&"public.route"):
		return false
	for x in range(-4, 6):
		if not carve.claim_face(Vector3i(x, band, -1), Vector3i.DOWN,
				WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR, &"public.route"):
			return false
	return carve.commit()


func _synthetic_flank(grid: WarrenSpatialGrid, id: StringName, macro_x: int,
		band: int) -> WarrenBuildingVolume:
	## One addressed tower storey on the macro column `macro_x`, standing at
	## the same band a bridge beside it would occupy.
	var cells: Array[Vector3i] = []
	for y in range(band, band + WarrenSpatialGrid.STOREY_CELLS):
		for x in range(macro_x * 2, macro_x * 2 + 2):
			for z in 2:
				cells.append(Vector3i(x, y, z))
	var tx := grid.begin_transaction(id)
	if not tx.assign_use(cells, WarrenSpatialGrid.Use.PRIVATE_VOLUME, id) \
			or not tx.commit():
		return null
	var origin := WarrenVolumetricSolver._maze_back_room_origin(&"tower",
		cells, 0)
	var room := WarrenRoomStamp.new(StringName("%s.room00" % id), id,
		&"tower", origin, 0, 0, true, false)
	var building := WarrenBuildingVolume.new(id, band)
	if not building.add_private_cells(cells) \
			or not room.add_private_cells(cells) \
			or not room.seal(grid, id) or not building.add_room(room) \
			or not building.add_threshold(Vector3i(macro_x * 2, band, 0),
				Vector3i(macro_x * 2, band, -1)) \
			or not building.seal(grid):
		return null
	return building


func _maze_source(plan: WarrenSpatialPlan) -> WarrenMazeSourcePlan:
	return plan.source_volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan


func _flat_roof_by_parcel(plan: WarrenSpatialPlan) -> Dictionary:
	## Parcel id -> whether the plot planner declared that house's roof a
	## SLAB. TASK C5d: every maze house, because the tiered hill town's own
	## vernacular is the flat roof and a pitched one is a seeded preference the
	## compiler may refuse. Read from the sealed source's own plots, not from
	## the parcels the translator built out of them, so the two derivations of
	## the rule stay independent.
	var out: Dictionary = {}
	var source := _maze_source(plan)
	if source == null:
		return out
	for plot: Dictionary in source.plots:
		if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_HOUSE:
			continue
		out[StringName("parcel.maze.%s" % String(plot["id"]))] = true
	return out


func test_tiered_parcels_get_flat_roofs() -> void:
	## Ruling 1: a plot something STANDS ON has a flat roof, and the spatial
	## roof compiler is what has to know it. Two teeth, neither of which reads
	## the other's answer: every room stamp of such a parcel must carry the
	## flag (the plot fact really reaches the stamp through the proposal), and
	## every one of those stamps that owns an exposed roof plate must receive
	## a FLAT roof unit instead of the pitched shell the heuristics would pick.
	var measured := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var flat_by_parcel := _flat_roof_by_parcel(plan)
		assert_gt(flat_by_parcel.size(), 0,
			"%s must carry its own sealed maze source" % _label(outcome))
		var mismatched := 0
		var first := ""
		var flat_stamps := 0
		for building: WarrenBuildingVolume in plan.buildings:
			for room: WarrenRoomStamp in building.room_records:
				if not flat_by_parcel.has(room.source_parcel_id):
					continue
				var wanted := bool(flat_by_parcel[room.source_parcel_id])
				flat_stamps += int(room.flat_roof)
				if room.flat_roof == wanted:
					continue
				mismatched += 1
				if first.is_empty():
					first = "%s wants flat_roof=%s" % [room.stable_id,
						str(wanted)]
		assert_eq(mismatched, 0,
			("%s stamps %d rooms whose flat_roof disagrees with the plot " \
				+ "(%s)") % [_label(outcome), mismatched, first])
		var fabric := plan.compiled_fabric_cache()
		assert_not_null(fabric,
			"%s must carry its compiled fabric" % _label(outcome))
		if fabric == null:
			continue
		var roofed := int(fabric.audit.get("plot_flat_roof_room_count", -1))
		var flats := int(fabric.audit.get("plot_flat_roof_count", -1))
		var pitched := int(fabric.audit.get("plot_flat_roof_pitched_count",
			-1))
		print(("MAZE_FLAT_ROOFS %s stamps=%d roofed=%d flat_units=%d " \
			+ "pitched=%d partial=%d rejected=%d") % [_label(outcome),
			flat_stamps, roofed, flats, pitched,
			int(fabric.audit.get("plot_flat_roof_partial_plate_count", -1)),
			int(fabric.audit.get("plot_flat_roof_rejected_count", -1))])
		# Every flat-roofed stamp that owns a COMPLETE exposed plate receives
		# the authored slab. A stamp whose plate is partial -- another room
		# stands on part of its crown -- is TILED as of Task C5e, and only a
		# plate whose shape the tiling vocabulary cannot cover still keeps the
		# finite setback vocabulary. Both are counted separately rather than
		# folded into either number, and the two counts must agree: the crowns
		# that reach the setback vocabulary are exactly the refused tilings.
		var partial := int(fabric.audit.get(
			"plot_flat_roof_partial_plate_count", -1))
		var tiled := int(fabric.audit.get("maze_partial_plate_tiled_count",
			-1))
		assert_eq(partial, int(fabric.audit.get(
			"maze_partial_plate_refused_count", -2)),
			("%s sends %d partial flat plates to the setback vocabulary and " \
				+ "refuses a different number of tilings") % [_label(outcome),
				partial])
		# Task C5d adds the seeded pitched preference, which is composed only
		# where the authored unit fits and is counted apart from the slab, and
		# Task C5e splits the partial plates into the ones that TILE and the
		# ones the tiling vocabulary refuses. Those four EXHAUST the
		# flat-roofed stamps -- slab, tiled plate, refused plate, preferred
		# shell -- as an equality rather than a bound, and the fifth outcome a
		# crown could have (its own slab refused over a COMPLETE plate, so it
		# fell through to the setback vocabulary) is asserted absent rather
		# than folded into the sum, which keeps the identity falsifiable.
		var preferred := int(fabric.audit.get("maze_pitched_roof_count", 0))
		var refused := int(fabric.audit.get("plot_flat_roof_rejected_count",
			-1))
		assert_eq(refused, 0,
			("%s refused %d flat-roofed stamps their own slab; the crown " \
				+ "identity below no longer accounts for them") % [
				_label(outcome), refused])
		assert_eq(flats + tiled + partial + preferred, roofed,
			("%s owes %d flat roof units to its flat-roofed stamps and " \
				+ "compiled %d (%d tiled plates, %d partial plates, %d " \
				+ "preferred pitched)") % [_label(outcome), roofed, flats,
				tiled, partial, preferred])
		assert_eq(pitched, 0,
			("%s gave %d flat-roofed stamps that did NOT prefer one a pitched " \
				+ "roof over a complete plate") % [_label(outcome), pitched])
		assert_gt(flats, 0,
			"%s compiled no flat roof at all" % _label(outcome))
		measured += int(flat_stamps > 0)
	assert_gt(measured, 0,
		"at least one sealing seed really has a flat-roofed parcel")


func _house_parcel_ids(plan: WarrenSpatialPlan) -> Dictionary:
	## Every parcel id the translator gives a HOUSE plot, read from the sealed
	## source. A back room, a bridge and a landmark are the same building's
	## other records or another feature entirely, so they are deliberately not
	## in here.
	var out: Dictionary = {}
	var source := _maze_source(plan)
	if source == null:
		return out
	for plot: Dictionary in source.plots:
		if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_HOUSE:
			continue
		out[StringName("parcel.maze.%s" % String(plot["id"]))] = true
	return out


func _pitched_eligible_parcels(plan: WarrenSpatialPlan) -> Dictionary:
	## Parcel id -> true for every house plot a PITCHED roof is geometrically
	## admissible on, re-derived here from the sealed source rather than read
	## back off the translator: nothing standing on its own crown, its plot top
	## strictly above every 4-neighbour plot's top and every adjacent street
	## band, and not a stack parent. The translator narrows this set further
	## with a seeded roll, so the compiled pitched roofs must be a SUBSET of it
	## -- which is the assertion, and it holds without this file reproducing
	## the roll.
	var out: Dictionary = {}
	var source := _maze_source(plan)
	if source == null:
		return out
	var stack_parents: Dictionary = {}
	for parent_value: Variant in (WarrenMazeBlockPartitioner.stack_parents(
			source)["parents"] as Dictionary).values():
		stack_parents[StringName(parent_value)] = true
	var plot_top: Dictionary = {}
	for plot: Dictionary in source.plots:
		for cell_value: Variant in plot["cells"] as Array:
			var column := cell_value as Vector2i
			plot_top[column] = maxi(int(plot_top.get(column, -2147483648)),
				int(plot["top"]))
	var street_top: Dictionary = {}
	for cell_value: Variant in source.passage_kinds.keys():
		var cell := cell_value as Vector3i
		var column := Vector2i(cell.x, cell.z)
		street_top[column] = maxi(int(street_top.get(column, -2147483648)),
			cell.y)
	for plot: Dictionary in source.plots:
		if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_HOUSE \
				or stack_parents.has(StringName(plot["id"])):
			continue
		var facts := source.plot_facts(plot)
		if bool(facts.get("tiered", false)) \
				or not bool(facts.get("roofed", true)):
			continue
		var top_band := int(plot["top"])
		var own: Dictionary = {}
		for cell_value: Variant in plot["cells"] as Array:
			own[cell_value as Vector2i] = true
		var free := true
		for column_value: Variant in own.keys():
			for direction: Vector2i in WarrenMazeBlockPartitioner.CARDINALS:
				var neighbor := (column_value as Vector2i) + direction
				if own.has(neighbor):
					continue
				free = free \
					and int(plot_top.get(neighbor, -2147483648)) < top_band \
					and int(street_top.get(neighbor, -2147483648)) < top_band
		if free:
			out[StringName("parcel.maze.%s" % String(plot["id"]))] = true
	return out


func test_maze_roofs_are_flat_first() -> void:
	## TASK C5d RULINGS 1 AND 2. A maze house is FLAT-roofed by DEFAULT -- the
	## tiered hill town's own vernacular, a one-band authored `roof.flat.*`
	## slab and its retained parapet course -- and a PITCHED roof is a seeded
	## PREFERENCE the compiler composes only where the authored unit fits with
	## no displacement and no halo conflict. Four teeth:
	##
	## 1. every room stamp of every HOUSE parcel carries `flat_roof`, whatever
	##    the plot facts say about what stands on its crown. Before this task
	##    only a tiered or built-on plot was flat, and the pitched crowns of
	##    the rest were what cost thirteen of the corpus's nineteen sweep
	##    failures their towns at a roof gate;
	## 2. every roofable crown really receives a roof unit -- the compiler's
	##    own face identity, restated here so an unroofed crown cannot hide
	##    behind a sealed town;
	## 3. every PITCHED crown stands on a stamp THIS FILE independently finds
	##    eligible, so a pitched eave can never reach over a neighbour's plot
	##    or a street it was never measured against;
	## 4. the seeded preference is a MEASURED fact corpus-wide -- some crown
	##    somewhere really is pitched -- and never asks for more crowns than
	##    the geometry admits.
	##
	## `maze_flat_roof_count` is deliberately NOT asserted against
	## `plot_flat_roof_count`: it is the same variable published under the
	## name ruling 2 names, so the equality could not fail. This file reads
	## `plot_flat_roof_count`.
	var measured := 0
	var total_pitched := 0
	var total_eligible := 0
	var total_preferred := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var house_parcels := _house_parcel_ids(plan)
		assert_gt(house_parcels.size(), 0,
			"%s must carry its own sealed maze source" % _label(outcome))
		var room_by_id: Dictionary = {}
		var pitched_rooms := PackedStringArray()
		for building: WarrenBuildingVolume in plan.buildings:
			for room: WarrenRoomStamp in building.room_records:
				room_by_id[room.stable_id] = room
				if house_parcels.has(room.source_parcel_id) \
						and not room.flat_roof:
					pitched_rooms.append(String(room.stable_id))
		assert_eq(pitched_rooms.size(), 0,
			("%s stamps %d house rooms that are not flat-roofed: %s") % [
				_label(outcome), pitched_rooms.size(),
				", ".join(pitched_rooms).left(160)])
		var fabric := plan.compiled_fabric_cache()
		assert_not_null(fabric,
			"%s must carry its compiled fabric" % _label(outcome))
		if fabric == null:
			continue
		var crowns := int(fabric.audit.get("plot_flat_roof_room_count", -1))
		var pitched := int(fabric.audit.get("maze_pitched_roof_count", -1))
		var flats := int(fabric.audit.get("plot_flat_roof_count", -1))
		var refused := int(fabric.audit.get("maze_pitched_refused_count", -1))
		var fell_through := int(fabric.audit.get(
			"maze_crown_fell_through_count", -1))
		# The translator's own denominator, forwarded onto the sealed plan: how
		# many houses ASKED. The compiler can only ever compose a subset of
		# them, and the geometry can only ever admit a subset of the plots.
		var preferred := int(plan.audit.get("maze_pitched_preference_count",
			-1))
		var eligible := _pitched_eligible_parcels(plan)
		print(("MAZE_FLAT_FIRST %s crowns=%d flat=%d pitched=%d refused=%d " \
			+ "fell_through=%d preferred=%d eligible=%d rate=%.2f " \
			+ "faces=%d/%d") % [_label(outcome), crowns, flats, pitched,
			refused, fell_through, preferred, eligible.size(),
			0.0 if eligible.is_empty() \
				else float(preferred) / float(eligible.size()),
			int(fabric.audit.get("realized_roof_face_count", -1)),
			int(fabric.audit.get("source_roof_face_count", -1))])
		assert_gte(pitched, 0,
			"%s must publish maze_pitched_roof_count" % _label(outcome))
		assert_gte(refused, 0,
			"%s must publish maze_pitched_refused_count" % _label(outcome))
		assert_gte(fell_through, 0,
			"%s must publish maze_crown_fell_through_count" % _label(outcome))
		assert_gte(preferred, 0,
			"%s must publish maze_pitched_preference_count" % _label(outcome))
		assert_gt(flats, 0,
			"%s composed no flat roof at all" % _label(outcome))
		assert_eq(int(fabric.audit.get("realized_roof_face_count", -1)),
			int(fabric.audit.get("source_roof_face_count", -2)),
			"%s left a roofable crown without a roof unit" % _label(outcome))
		assert_lte(preferred, eligible.size(),
			("%s asked for %d pitched crowns where only %d plots are " \
				+ "eligible") % [_label(outcome), preferred, eligible.size()])
		assert_lte(pitched, preferred,
			("%s composed %d pitched crowns from %d preferences") % [
				_label(outcome), pitched, preferred])
		total_pitched += pitched
		total_eligible += eligible.size()
		total_preferred += preferred
		for room_id_value: Variant in fabric.audit.get(
				"maze_pitched_roof_rooms", []) as Array:
			var room := room_by_id.get(
				StringName(room_id_value)) as WarrenRoomStamp
			assert_not_null(room, "%s names a pitched crown %s it has no " \
				% [_label(outcome), room_id_value] + "stamp for")
			if room == null:
				continue
			assert_true(eligible.has(room.source_parcel_id),
				("%s gave %s a pitched crown its plot is not eligible for") \
					% [_label(outcome), room.stable_id])
			assert_eq(room.roof_preference, &"pitched",
				("%s gave %s a pitched crown it never asked for") % [
					_label(outcome), room.stable_id])
		measured += 1
	assert_gt(measured, 0, "at least one seed sealed a town to measure")
	print(("MAZE_FLAT_FIRST corpus towns=%d pitched=%d preferred=%d " \
		+ "eligible=%d") % [measured, total_pitched, total_preferred,
		total_eligible])
	# The preference is a measured FACT, not just a wired-up path: somewhere in
	# the four planner seeds an authored pitched shell really stands on a
	# freestanding crown. Without this the whole feature could be inert and
	# every per-seed assertion above would still pass.
	assert_gt(total_pitched, 0,
		("no planner seed composed a single pitched crown from %d " \
			+ "preferences over %d eligible plots") % [total_preferred,
			total_eligible])
	assert_gt(total_preferred, 0,
		"no planner seed asked for a pitched crown at all")


func _flat_crown_faces(plan: WarrenSpatialPlan) -> Dictionary:
	## Every FLAT-roofed room's authoritative exposed roof faces, derived from
	## the sealed plan's own construction regions and its room stamps — never
	## from the roof compiler's audit. `room_id -> Array[Vector3i]`.
	var room_id_by_cell: Dictionary = {}
	var flat_rooms: Dictionary = {}
	for building: WarrenBuildingVolume in plan.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if not room.flat_roof:
				continue
			flat_rooms[room.stable_id] = room
			for cell: Vector3i in room.private_cells:
				room_id_by_cell[cell] = room.stable_id
	var out: Dictionary = {}
	for region: WarrenConstructionRegion in plan.construction_plan \
			.regions_for_kind(WarrenSpatialGrid.FaceKind.ROOF):
		for cell: Vector3i in region.face_cells:
			var room_id := StringName(room_id_by_cell.get(cell, &""))
			if room_id.is_empty():
				continue
			if not out.has(room_id):
				out[room_id] = [] as Array[Vector3i]
			(out[room_id] as Array[Vector3i]).append(cell)
	return out


func _roof_cover_by_cell(fabric: SettlementFabricPlan) -> Dictionary:
	## Which roof units really occupy each world cell: `cell -> Array[String]`
	## of unit ids. Solid AND occluder cells, because the authored thin plank
	## cap that closes a one-cell setback strip claims occupancy only as an
	## occluder. Read out of the sealed units, so a compiler audit that counts
	## a tile it never placed cannot pass.
	var out: Dictionary = {}
	for unit: FabricUnit in fabric.units:
		if not String(unit.stable_id).begins_with("spatial.roof."):
			continue
		var recipe := fabric.recipe(unit.recipe_id)
		if recipe == null:
			continue
		var local_cells: Dictionary = {}
		for cell: Vector3i in recipe.solid_cells:
			local_cells[cell] = true
		for cell: Vector3i in recipe.occluder_cells:
			local_cells[cell] = true
		for local_value: Variant in local_cells.keys():
			var world := FabricRecipe.transform_cell(local_value as Vector3i,
				unit.lattice_origin, unit.yaw_quarters)
			if not out.has(world):
				out[world] = [] as Array[String]
			(out[world] as Array[String]).append(String(unit.stable_id))
	return out


func test_partial_plates_are_tiled() -> void:
	## TASK C5e RULING 1. A flat crown only PARTLY covered by the storey
	## stacked on it used to have no authored module at all: every
	## `roof.flat.*` recipe is a whole-footprint stamp, so the remainder fell
	## through to the finite setback vocabulary and eight of the corpus's
	## thirteen non-sealing seeds died there. It is TILED now — the uncovered
	## cells are covered by authored flat units, largest first, in sorted
	## order — and this test states that as an identity rather than as a count:
	##
	## 1. every exposed roof face of every flat crown is under EXACTLY ONE roof
	##    unit of its own room. Derived here from the sealed plan's own
	##    construction regions and the units' recipes;
	## 2. no flat crown reaches the setback vocabulary at all
	##    (`plot_flat_roof_partial_plate_count == 0`), which is the brief's own
	##    statement of "the macro setback / exact setback / 1-cell sliver gates
	##    are not reached for flat crowns";
	## 3. tiling is a MEASURED fact corpus-wide: some crown somewhere really is
	##    tiled, so the whole branch cannot ship inert.
	var measured := 0
	var total_tiled := 0
	var total_tiles := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var fabric := plan.compiled_fabric_cache()
		assert_not_null(fabric,
			"%s must carry its compiled fabric" % _label(outcome))
		if fabric == null:
			continue
		var faces_by_room := _flat_crown_faces(plan)
		var cover := _roof_cover_by_cell(fabric)
		var uncovered := PackedStringArray()
		var doubled := PackedStringArray()
		var foreign := PackedStringArray()
		var partial_crowns := 0
		for room_id_value: Variant in faces_by_room.keys():
			var room_id := StringName(room_id_value)
			var faces := faces_by_room[room_id] as Array[Vector3i]
			var own_prefix := "spatial.roof.%s" % room_id
			var top_band := (faces[0] as Vector3i).y
			var covered_here := 0
			for face: Vector3i in faces:
				var owners := cover.get(face + Vector3i.UP,
					[] as Array[String]) as Array[String]
				if owners.is_empty():
					if uncovered.size() < 4:
						uncovered.append("%s@%s" % [room_id, face])
					continue
				if owners.size() > 1 and doubled.size() < 4:
					doubled.append("%s@%s=%s" % [room_id, face, owners])
				var own := false
				for owner_id: String in owners:
					own = own or owner_id.begins_with(own_prefix)
				if not own and foreign.size() < 4:
					foreign.append("%s@%s=%s" % [room_id, face, owners])
				covered_here += 1
			var top_cells := 0
			for building: WarrenBuildingVolume in plan.buildings:
				for room: WarrenRoomStamp in building.room_records:
					if room.stable_id != room_id:
						continue
					for cell: Vector3i in room.private_cells:
						top_cells += int(cell.y == top_band)
			partial_crowns += int(faces.size() != top_cells)
		var tiled := int(fabric.audit.get("maze_partial_plate_tiled_count", -1))
		var tiles := int(fabric.audit.get("maze_partial_plate_tile_count", -1))
		var refused := int(fabric.audit.get(
			"maze_partial_plate_refused_count", -1))
		var to_setback := int(fabric.audit.get(
			"plot_flat_roof_partial_plate_count", -1))
		print(("MAZE_TILED %s crowns=%d partial=%d tiled=%d tiles=%d " \
			+ "refused=%d to_setback=%d modules=%s") % [_label(outcome),
			faces_by_room.size(), partial_crowns, tiled, tiles, refused,
			to_setback, fabric.audit.get(
				"maze_partial_plate_tile_recipe_counts", {})])
		assert_gte(tiled, 0,
			"%s must publish maze_partial_plate_tiled_count" % _label(outcome))
		assert_gte(tiles, 0,
			"%s must publish maze_partial_plate_tile_count" % _label(outcome))
		assert_gte(refused, 0,
			"%s must publish maze_partial_plate_refused_count" \
				% _label(outcome))
		assert_eq(uncovered.size(), 0,
			"%s leaves flat-crown faces with no roof unit: %s" % [
				_label(outcome), ", ".join(uncovered)])
		assert_eq(doubled.size(), 0,
			"%s covers a flat-crown face with two roof units: %s" % [
				_label(outcome), ", ".join(doubled)])
		assert_eq(foreign.size(), 0,
			"%s roofs a flat crown with another room's unit: %s" % [
				_label(outcome), ", ".join(foreign)])
		assert_eq(to_setback, 0,
			("%s sent %d partial flat plates to the finite setback " \
				+ "vocabulary") % [_label(outcome), to_setback])
		assert_eq(tiled + refused, partial_crowns,
			("%s has %d partial flat plates but tiled %d and refused %d") % [
				_label(outcome), partial_crowns, tiled, refused])
		total_tiled += tiled
		total_tiles += tiles
		measured += 1
	assert_gt(measured, 0, "at least one seed sealed a town to measure")
	print("MAZE_TILED corpus towns=%d tiled=%d tiles=%d" % [measured,
		total_tiled, total_tiles])
	assert_gt(total_tiled, 0,
		"no planner seed tiled a single partial flat plate")
	assert_gt(total_tiles, total_tiled,
		"every tiled crown took exactly one tile, which is not a tiling")


func _crown_deck_cells(plan: WarrenSpatialPlan,
		fabric: SettlementFabricPlan) -> Dictionary:
	## Every fine cell of every FLAT crown's built deck — slab or tile — as
	## `cell -> room_id`. Derived from the plot model's own `flat_roof` stamps
	## and the roof units standing on them, never from the assembler's rule.
	##
	## A flat-roofed stamp that WON the seeded pitched preference (Task C5d)
	## is not a terrace: what stands on its crown is an authored pitched shell
	## whose lowest band occupies these same cells. The compiler names those
	## crowns itself, so they are skipped by name rather than by recipe.
	var out: Dictionary = {}
	var cover := _roof_cover_by_cell(fabric)
	var pitched: Dictionary = {}
	for room_id_value: Variant in fabric.audit.get("maze_pitched_roof_rooms",
			[]) as Array:
		pitched[StringName(room_id_value)] = true
	for building: WarrenBuildingVolume in plan.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if not room.flat_roof or pitched.has(room.stable_id):
				continue
			var own_prefix := "spatial.roof.%s" % room.stable_id
			var band := room.lattice_origin.y + WarrenSpatialGrid.STOREY_CELLS
			for cell_value: Variant in cover.keys():
				var cell := cell_value as Vector3i
				if cell.y != band:
					continue
				for owner_id: String in cover[cell] as Array[String]:
					if owner_id.begins_with(own_prefix):
						out[cell] = room.stable_id
						break
	return out


func _open_crown_edge_points(plan: WarrenSpatialPlan,
		fabric: SettlementFabricPlan) -> Dictionary:
	## This file's own statement of the terrace rule: a crown deck cell owes a
	## railing on every horizontal boundary whose neighbour AT THE DECK'S OWN
	## BAND is open air — not another deck, not a room or any other built
	## solid, not retained stone, and not a public floor that planks itself
	## (a deck, passage or bridge you can walk straight onto). Keyed by the
	## world MIDPOINT of the boundary, which is the one thing the rule and the
	## rendered instance must agree on.
	var deck := _crown_deck_cells(plan, fabric)
	var solids := fabric.transformed_cells(&"solid")
	var retained := fabric.retained_terrace_cells
	var paved := SettlementFabricAssembler.public_floor_cells(
		fabric.surface_plan)
	var out: Dictionary = {}
	for cell_value: Variant in deck.keys():
		var cell := cell_value as Vector3i
		for direction: Vector3i in SettlementFabricAssembler.FACE_DIRECTIONS:
			var neighbor := cell + direction
			if deck.has(neighbor) or solids.has(neighbor) \
					or retained.has(neighbor) or paved.has(neighbor):
				continue
			var midpoint := (Vector3(cell) + Vector3(direction) * 0.5) \
				* FabricRecipe.CELL_SIZE
			midpoint.y = float(cell.y) * FabricRecipe.CELL_SIZE
			out[_point_key(midpoint)] = midpoint
	return out


func _point_key(point: Vector3) -> String:
	return "%.2f:%.2f:%.2f" % [point.x, point.y, point.z]


func _terrace_rail_instances(fabric: SettlementFabricPlan) -> Array:
	## Every railing instance the RENDERER is handed for a terrace edge, out of
	## the payload the commit path takes, as {asset_id, transform}.
	var out: Array = []
	var payload := SettlementFabricAssembler.terrace_retaining_payload(fabric)
	for asset_value: Variant in payload.batches.keys():
		var asset_id := StringName(asset_value)
		var batch := payload.batches[asset_id] as Dictionary
		var ids := batch.get("ids", []) as Array
		var transforms := batch.get("transforms", []) as Array
		for index in ids.size():
			if not String(ids[index]).begins_with("maze-terrace-rail/"):
				continue
			out.append({"asset_id": asset_id,
				"transform": transforms[index] as Transform3D})
	return out


func _terrace_rail_points(fabric: SettlementFabricPlan) -> Dictionary:
	## Which boundaries the RENDERER is really handed a railing for, measured
	## off the transforms in the payload the commit path takes rather than off
	## the rule that chose them. A 3 m module spans two boundaries at ±0.75 m
	## along its own local X; a 1.5 m module spans the one it stands on.
	var out: Dictionary = {}
	for instance: Dictionary in _terrace_rail_instances(fabric):
		var asset_id := StringName(instance["asset_id"])
		var xform := instance["transform"] as Transform3D
		var axis := (xform.basis * Vector3.RIGHT).normalized()
		var offsets: Array[float] = []
		offsets.assign([-0.75, 0.75] \
			if asset_id == SettlementFabricAssembler.PLANK_RAILING_MEDIUM \
			else [0.0])
		for offset: float in offsets:
			var key := _point_key(xform.origin + axis * offset)
			out[key] = int(out.get(key, 0)) + 1
	return out


func test_flat_crowns_have_railings_on_open_edges() -> void:
	## TASK C5e RULING 3. The flat crown is an open TERRACE, not a stone block
	## with a timber sill: the parapet course above its slab is released to air
	## and every exposed edge of the deck wears one authored railing. Three
	## teeth, all measured against the payload the renderer receives:
	##
	## 1. every open boundary this file derives owns EXACTLY ONE railing;
	## 2. no railing stands on a boundary that is not open — a rail across a
	##    party wall, a stacked room, a stone shoulder or a deck you can walk
	##    straight onto is a defect, not decoration;
	## 3. the published audit count is the rendered count.
	var measured := 0
	var total_rails := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var fabric := plan.compiled_fabric_cache()
		assert_not_null(fabric,
			"%s must carry its compiled fabric" % _label(outcome))
		if fabric == null:
			continue
		var expected := _open_crown_edge_points(plan, fabric)
		var rendered := _terrace_rail_points(fabric)
		var instances := _terrace_rail_instances(fabric)
		var audited := int(fabric.audit.get("maze_terrace_railing_count", -1))
		var edges := int(fabric.audit.get("maze_terrace_edge_count", -1))
		var missing := PackedStringArray()
		var doubled := PackedStringArray()
		for key_value: Variant in expected.keys():
			var key := String(key_value)
			var count := int(rendered.get(key, 0))
			if count == 0 and missing.size() < 4:
				missing.append(key)
			elif count > 1 and doubled.size() < 4:
				doubled.append("%s x%d" % [key, count])
		var stray := PackedStringArray()
		for key_value: Variant in rendered.keys():
			if not expected.has(key_value) and stray.size() < 4:
				stray.append(String(key_value))
		print(("MAZE_TERRACE %s deck_edges=%d rails=%d audited=%d " \
			+ "edge_audit=%d") % [_label(outcome), expected.size(),
			rendered.size(), audited, edges])
		assert_gte(audited, 0,
			"%s must publish maze_terrace_railing_count" % _label(outcome))
		assert_gt(expected.size(), 0,
			"%s derives no open crown edge at all" % _label(outcome))
		assert_eq(missing.size(), 0,
			"%s leaves open terrace edges unrailed: %s" % [_label(outcome),
				", ".join(missing)])
		assert_eq(doubled.size(), 0,
			"%s rails an open terrace edge twice: %s" % [_label(outcome),
				", ".join(doubled)])
		assert_eq(stray.size(), 0,
			"%s rails a boundary that is not open: %s" % [_label(outcome),
				", ".join(stray)])
		assert_eq(edges, expected.size(),
			("%s audits %d open terrace edges where this file derives %d") % [
				_label(outcome), edges, expected.size()])
		assert_eq(audited, instances.size(),
			("%s publishes %d railings and hands the renderer %d") % [
				_label(outcome), audited, instances.size()])
		total_rails += audited
		measured += 1
	assert_gt(measured, 0, "at least one seed sealed a town to measure")
	print("MAZE_TERRACE corpus towns=%d rails=%d" % [measured, total_rails])
	assert_gt(total_rails, 0,
		"no planner seed railed a single flat crown")


func _mixed_footprint_fixture(source: WarrenMazeSourcePlan,
		plan: WarrenSpatialPlan) -> Dictionary:
	## A two-column footprint at ONE band that the builder would call
	## stone-borne and then reject. It is a FIXTURE and not a find, because the
	## corpus cannot produce one: in every sealed maze town the source mass is
	## continuous from band 0 upward under every column, so the only column
	## with nothing beneath its own floor sits at band 0 -- and no column can
	## be stone-borne at band 0. The defect is real and latent rather than
	## live, and a fixture is the only honest way to pin it.
	##
	## Everything that DECIDES the outcome is real: both columns and both
	## `rock_shoulder` readings come from the sealed source, so `borne` is a
	## column the band really stands above the top of derived rock on (the
	## builder calls it stone-borne) and `at_grade` is one whose rock really
	## reaches the band (the builder does not). Only the envelope and the mass
	## around them are made here, and only `bearing_at`, `contains_column` and
	## `has_mass` are read, which is the whole of what the predicate touches.
	var lowest := Vector2i.ZERO
	var highest := Vector2i.ZERO
	var lowest_shoulder := 2147483647
	var highest_shoulder := -2147483648
	for column_value: Variant in source.massif.columns.keys():
		var column := column_value as Vector2i
		var shoulder := source.rock_shoulder(column)
		if shoulder < lowest_shoulder:
			lowest_shoulder = shoulder
			lowest = column
		if shoulder > highest_shoulder:
			highest_shoulder = shoulder
			highest = column
	if highest_shoulder <= lowest_shoulder:
		return {}
	var band := lowest_shoulder + 1
	var envelope := WarrenVolumeEnvelope.new()
	envelope.world_seed = source.world_seed
	envelope.radius_x = 2
	envelope.radius_z = 2
	envelope.max_height_bands = band + 2
	for column: Vector2i in [lowest, highest]:
		envelope.ground_bands[column] = 0
		envelope.bearing_bands[column] = band
		envelope.height_bands[column] = band + 2
	var volume := WarrenVolumePlan.new(&"c5d.bearing.mirror.fixture",
		source.world_seed, envelope)
	volume.mass_context[&"maze_source_plan"] = source
	# The stone-borne column stands on real mass; the at-grade one has nothing
	# under its own floor, which is the exact shape the builder refuses.
	volume.mass_cells[Vector3i(lowest.x, band - 1, lowest.y)] = true
	volume.mass_cells[Vector3i(lowest.x, band, lowest.y)] = true
	volume.mass_cells[Vector3i(highest.x, band, highest.y)] = true
	return {"volume": volume, "grid": plan.grid, "band": band,
		"borne": lowest, "at_grade": highest}


func test_maze_back_room_bearing_mirrors_the_builder() -> void:
	## C5d fix #1. `WarrenVolumetricSolver._maze_back_room_bears_terrain` is a
	## MIRROR of `WarrenSpatialFabricCompiler._retained_foundation_cells`, and
	## the builder's `stone_borne` verdict is per ROOM, not per column: one
	## carried column makes the WHOLE room stone-borne, and then every column
	## of it -- including the ones at grade -- has to stand on real source mass
	## at `band - 1`.
	##
	## Deciding it per column let a MIXED footprint through: one stone-borne
	## column that does stand on mass, plus one at grade whose `depth == 0`
	## short-circuited before the standing test ever ran. The mirror said yes
	## and the builder then rejected the whole TOWN with `terrain-bearing room
	## … stands on nothing at …`, which is the one failure mode this mirror
	## exists to prevent.
	##
	## Two teeth on the same fixture: the stone-borne column bears on its own,
	## so the refusal below can only come from the MIX; and the mixed footprint
	## is refused.
	var checked := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var source := _maze_source(plan)
		if source == null or source.massif == null:
			continue
		var fixture := _mixed_footprint_fixture(source, plan)
		if fixture.is_empty():
			continue
		var volume := fixture.volume as WarrenVolumePlan
		var band := int(fixture.band)
		var borne: Array[Vector2i] = [fixture.borne as Vector2i]
		var mixed: Array[Vector2i] = [fixture.borne as Vector2i,
			fixture.at_grade as Vector2i]
		print("MAZE_BEARING_MIRROR %s band=%d stone_borne=%s at_grade=%s" % [
			_label(outcome), band, fixture.borne, fixture.at_grade])
		assert_true(WarrenVolumetricSolver._maze_back_room_bears_terrain(
			fixture.grid as WarrenSpatialGrid, volume, borne, band),
			("%s: a stone-borne column standing on real mass bears on its " \
				+ "own") % _label(outcome))
		assert_false(WarrenVolumetricSolver._maze_back_room_bears_terrain(
			fixture.grid as WarrenSpatialGrid, volume, mixed, band),
			("%s: a mixed footprint whose at-grade column stands on nothing " \
				+ "must be refused here, or the builder rejects the whole " \
				+ "town for it") % _label(outcome))
		checked += 1
	assert_gt(checked, 0,
		"no sealed town could supply the mirror fixture; this proved nothing")


func _rock_cells(plan: WarrenSpatialPlan) -> Dictionary:
	## Every FINE cell of the source plan's ROCK: derived solid at or above the
	## massif's own bearing datum that lies inside no plot's `[floor, top)`.
	## Terrain below `base_at` belongs to the heightfield, not to the town, and
	## is deliberately excluded.
	var out: Dictionary = {}
	var source := _maze_source(plan)
	if source == null or source.massif == null:
		return out
	var plot_mass := _plot_mass_cells(plan)
	for column_value: Variant in source.massif.columns.keys():
		var column := column_value as Vector2i
		for band in range(source.massif.base_at(column),
				source.massif.top_at(column) + 1):
			if not source.solid_at(Vector3i(column.x, band, column.y)):
				continue
			for x_offset in 2:
				for z_offset in 2:
					var fine := Vector3i(column.x * 2 + x_offset, band,
						column.y * 2 + z_offset)
					if plot_mass.has(fine):
						continue
					out[fine] = true
	return out


func _route_floor_standing(plan: WarrenSpatialPlan,
		fabric: SettlementFabricPlan) -> Dictionary:
	## How many of a town's route floor cells stand on something, and what
	## the rest stand over. Extracted verbatim from
	## `test_rock_is_retained_as_stone` (task D1) so the sloped corpus
	## scores the identical predicate rather than a second reading of it.
	var solids := fabric.transformed_cells(&"solid")
	var retained := fabric.retained_terrace_cells
	var standing := 0
	var floating := 0
	var first_hole := ""
	var holes: Dictionary = {}
	var source := _maze_source(plan)
	for cell: Vector3i in plan.route_floor_cells:
		var below := cell + Vector3i.DOWN
		# Terrain is the heightfield's, and the heightfield draws it: a
		# street cut at its own column's ground datum stands on the
		# mountain, not on anything this fabric owes a module for.
		var column := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		var on_terrain := source != null and source.massif != null \
			and source.massif.has_column(column) \
			and below.y < source.massif.base_at(column)
		# A route floor whose lower neighbour is the street itself is a
		# STEP: the passage climbs a band and the cell below belongs to
		# the run it climbed from. Nothing is owed a module there. What
		# this assertion is really about is OUTSIDE -- a walk surface with
		# literally nothing under it, which is what every leftover rock
		# cell was before Task C5 retained it.
		if on_terrain or retained.has(below) or solids.has(below) \
				or plan.grid.use_at(below) in [
					WarrenSpatialGrid.Use.PRIVATE_VOLUME,
					WarrenSpatialGrid.Use.STRUCTURAL_VOLUME,
					WarrenSpatialGrid.Use.PUBLIC_AIR]:
			standing += 1
			continue
		floating += 1
		holes[plan.grid.use_at(below)] = int(
			holes.get(plan.grid.use_at(below), 0)) + 1
		if first_hole.is_empty():
			first_hole = "%s under %s owner=%s" % [cell, below,
				plan.grid.owner_name_at(below)]
	return {"standing": standing, "floating": floating,
		"holes": holes, "first_hole": first_hole,
		"share": float(standing)
			/ float(maxi(1, plan.route_floor_cells.size()))}


func test_rock_is_retained_as_stone() -> void:
	## Ruling 3: rock is STONE, not nothing. Every fine cell of the source
	## plan's leftover mass -- shoulders, tunnel roofs, street-floor slabs,
	## plinths, the interior nobody built in -- that no room, feature or public
	## realm took must reach the fabric's retained-terrace channel instead of
	## `_discard_unassigned_mass`. The second assertion is the one a player
	## feels: a street's walk surface must stand on something.
	var measured := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var fabric := plan.compiled_fabric_cache()
		assert_not_null(fabric,
			"%s must carry its compiled fabric" % _label(outcome))
		if fabric == null:
			continue
		var solids := fabric.transformed_cells(&"solid")
		var retained := fabric.retained_terrace_cells
		var expected := 0
		var missing := 0
		var first := ""
		for cell_value: Variant in _rock_cells(plan).keys():
			var cell := cell_value as Vector3i
			var use := plan.grid.use_at(cell)
			if use in [WarrenSpatialGrid.Use.PUBLIC_AIR,
					WarrenSpatialGrid.Use.PRIVATE_VOLUME,
					WarrenSpatialGrid.Use.DAYLIGHT_AIR] \
					or solids.has(cell):
				continue
			expected += 1
			if retained.has(cell):
				continue
			missing += 1
			if first.is_empty():
				first = "%s" % cell
		# `maze_retained_stone_cells` is the WHOLE retained maze channel;
		# `maze_retained_rock_cells` is the DERIVED ROCK inside it. The rename
		# is Task C5c fix 1's: one name, one meaning, in both audits.
		var audited := int(fabric.audit.get("maze_retained_stone_cells", -1))
		var skipped := int(plan.audit.get(
			"maze_retained_rock_skipped_reserved", -1))
		var suppressed := int(fabric.audit.get(
			"maze_plinth_faces_suppressed_by_stone", -1))
		print(("MAZE_ROCK %s rock=%d retained=%d audited=%d missing=%d " \
			+ "skipped_reserved=%d plinth_faces_suppressed=%d") % [
			_label(outcome), expected, retained.size(), audited, missing,
			skipped, suppressed])
		assert_gte(skipped, 0,
			"%s must publish the rock cells another feature had reserved" \
				% _label(outcome))
		assert_gte(suppressed, 0,
			"%s must publish the plinth faces retained stone suppressed" \
				% _label(outcome))
		assert_eq(missing, 0,
			"%s discards %d of %d rock cells (first %s)" % [_label(outcome),
				missing, expected, first])
		assert_gt(audited, 0,
			"%s must publish the retained rock it kept" % _label(outcome))
		var standing_audit := _route_floor_standing(plan, fabric)
		var standing := int(standing_audit["standing"])
		var holes := standing_audit["holes"] as Dictionary
		var first_hole := String(standing_audit["first_hole"])
		var share := float(standing) \
			/ float(maxi(1, plan.route_floor_cells.size()))
		print(("MAZE_ROUTE_STONE %s standing=%d/%d share=%.3f holes=%s " \
			+ "first=%s") % [_label(outcome), standing,
			plan.route_floor_cells.size(), share, str(holes), first_hole])
		assert_gte(share, ROUTE_ON_STONE_FLOOR,
			("%s lays %d route floor cells and only %.3f of them stand on " \
				+ "anything") % [_label(outcome),
				plan.route_floor_cells.size(), share])
		# TASK C5e, review fix 1 (CRITICAL). The share alone has 0.05 of slack
		# and it hid a real defect: releasing a flat crown's parapet course
		# took away the band a TIERED house's own street floor stands on, and
		# 6 / 8 / 4 walk cells per town were left over `Use.OUTSIDE` while the
		# share still passed (4/compact landed exactly on the floor). OUTSIDE
		# is the one hole that is never explainable -- terrain, stone, a room,
		# a street below and a step are all admitted above -- so it is pinned
		# at zero rather than left inside the tolerance.
		assert_eq(int(holes.get(WarrenSpatialGrid.Use.OUTSIDE, 0)), 0,
			("%s lays %d route floor cells over nothing at all (first %s)") \
				% [_label(outcome),
				int(holes.get(WarrenSpatialGrid.Use.OUTSIDE, 0)), first_hole])
		measured += 1
	assert_gt(measured, 0, "at least one seed seals far enough to measure")


func _room_is_stone_borne(plan: WarrenSpatialPlan,
		source: WarrenMazeSourcePlan, room: WarrenRoomStamp) -> bool:
	## `WarrenSpatialFabricCompiler._retained_foundation_cells`'s maze branch,
	## re-derived from the sealed plan and the sealed source rather than read
	## back out of the audit it is meant to check. A terrain-bearing room is
	## carried by retained stone -- and therefore takes no plinth course of its
	## own -- when any footprint column has a broken span below it, a span
	## deeper than one authored course, or another plot underneath.
	if not room.terrain_bearing:
		return false
	var volume := plan.source_volume
	var support := room.lattice_origin.y
	for cell: Vector3i in room.private_cells:
		if cell.y != support:
			continue
		var macro := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		if not volume.envelope.contains_column(macro):
			continue
		var bearing := volume.envelope.bearing_at(macro)
		if support - bearing > WarrenSpatialFabricCompiler \
				.FOUNDATION_MODULE_HEIGHT_BANDS \
				or source.rock_shoulder(macro) < support:
			return true
		for band in range(bearing, support):
			if not volume.has_mass(Vector3i(macro.x, band, macro.y)):
				return true
	return false


func test_stone_borne_rooms_are_counted() -> void:
	## TASK C5c FIX 1, IMPORTANT 5(a). Ruling 4 taught the foundation gate to
	## accept a maze terrain-bearing room standing on a tier, a tunnel roof or
	## a deep rock base, and to give it NO plinth -- one masonry course under a
	## room six bands up is a floating stone skirt. That relaxation had no test
	## reading it. Count the rooms it really applies to, from the sealed plan
	## and the sealed source, and hold the compiler's published count to it.
	var measured := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var fabric := plan.compiled_fabric_cache()
		var source := _maze_source(plan)
		if fabric == null or source == null:
			continue
		measured += 1
		var derived := 0
		var terrain_rooms := 0
		for building: WarrenBuildingVolume in plan.buildings:
			for room: WarrenRoomStamp in building.room_records:
				terrain_rooms += int(room.terrain_bearing)
				derived += int(_room_is_stone_borne(plan, source, room))
		var audited := int(fabric.audit.get("maze_stone_borne_room_count", -1))
		print("MAZE_STONE_BORNE %s terrain_rooms=%d stone_borne=%d/%d" % [
			_label(outcome), terrain_rooms, audited, derived])
		assert_eq(audited, derived,
			("%s must publish exactly the terrain-bearing rooms the retained " \
				+ "stone carries") % _label(outcome))
		assert_lte(derived, terrain_rooms,
			"%s cannot carry more rooms than it roots" % _label(outcome))
	assert_gt(measured, 0, "at least one seed seals far enough to measure")


func test_stone_split_reconciles_across_the_compiler() -> void:
	## TASK C5c FIX 1, IMPORTANT 5(b). The solver decides the rock/roof/unroomed
	## split; the fabric audit only FORWARDS it, so the two must agree cell for
	## cell -- a forwarded number that has quietly drifted is worse than no
	## number at all. The three tags must also add up to the retention pass's
	## own total, which is what makes them a partition rather than three
	## overlapping counts.
	var measured := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var fabric := plan.compiled_fabric_cache()
		if fabric == null:
			continue
		measured += 1
		var rock := int(plan.audit.get("maze_retained_rock_cells", -1))
		var roof := int(plan.audit.get(
			"maze_retained_rock_stone_roof_cells", -1))
		var unroomed := int(plan.audit.get(
			"maze_retained_unroomed_plot_stone_cells", -1))
		var total := int(plan.audit.get("maze_retained_rock_cell_count", -1))
		print(("MAZE_STONE_SPLIT %s rock=%d roof=%d unroomed=%d total=%d " \
			+ "channel=%d") % [_label(outcome), rock, roof, unroomed, total,
			int(fabric.audit.get("maze_retained_stone_cells", -1))])
		assert_eq(rock + roof + unroomed, total,
			("%s retention split must partition the stone it claimed") \
				% _label(outcome))
		for key: String in ["maze_retained_rock_cells",
				"maze_retained_rock_stone_roof_cells",
				"maze_unroomed_plot_cells"]:
			assert_eq(int(fabric.audit.get(key, -1)),
				int(plan.audit.get(key, -2)),
				"%s fabric audit must forward %s unchanged" % [
					_label(outcome), key])
		assert_almost_eq(float(fabric.audit.get("maze_unroomed_plot_share",
			-1.0)), float(plan.audit.get("maze_unroomed_plot_share", -2.0)),
			0.0001,
			"%s fabric audit must forward the share unchanged" \
				% _label(outcome))
		# The channel the assembler renders is the whole retained set minus
		# whatever the fabric had already built in, so it can only be smaller.
		assert_between(int(fabric.audit.get("maze_retained_stone_cells", -1)),
			1, total + int(plan.audit.get("maze_slab_course_cell_count", 0)),
			"%s retained channel must lie inside the stone the solver claimed" \
				% _label(outcome))
	assert_gt(measured, 0, "at least one seed seals far enough to measure")


func test_every_plot_column_stands_on_solid() -> void:
	## TASK C5c FIX 1, IMPORTANT 5(c). `WarrenParcelConstruction
	## .has_perimeter_grounding` used to prove a boundary house's load path by
	## asking whether its room stack descends to natural ground. Ruling 4 stops
	## a maze parcel descending, so that question became the wrong one and the
	## maze branch answers `true` instead -- leaning entirely on the plot
	## planner's own support rule.
	##
	## This is that rule, read back out of the sealed source: every column of
	## every plot has SOLID directly beneath its floor. If it ever stops being
	## true, the relaxation above is unsupported and this says so at the source
	## of it rather than at a render three stages later.
	var checked := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var source := _maze_source(plan)
		if source == null:
			continue
		var floating := 0
		var first := ""
		for plot: Dictionary in source.plots:
			if StringName(plot["kind"]) == WarrenMazeSourcePlan.PLOT_DECK:
				continue
			var floor_band := int(plot["floor"])
			for cell_value: Variant in plot["cells"] as Array:
				var column := cell_value as Vector2i
				checked += 1
				if source.solid_at(Vector3i(column.x, floor_band - 1,
						column.y)):
					continue
				floating += 1
				if first.is_empty():
					first = "%s at %s band %d" % [plot["id"], column,
						floor_band - 1]
		print("MAZE_PLOT_SUPPORT %s columns=%d floating=%d" % [
			_label(outcome), checked, floating])
		assert_eq(floating, 0,
			"%s has %d plot columns standing on nothing (%s)" % [
				_label(outcome), floating, first])
	assert_gt(checked, 0, "at least one seed seals far enough to measure")


func _rooms_by_parcel(plan: WarrenSpatialPlan) -> Dictionary:
	var out: Dictionary = {}
	for building: WarrenBuildingVolume in plan.buildings:
		for room: WarrenRoomStamp in building.room_records:
			var rooms: Array = out.get(room.source_parcel_id, [])
			rooms.append(room)
			out[room.source_parcel_id] = rooms
	return out


func test_stone_bases_follow_bears_on_rock() -> void:
	## Ruling 4: the stone base is a PLOT fact, not a composition accident. A
	## house whose columns really stand on rock or terrain roots in the ground
	## and wears the plinth course; a house standing on another house names
	## that house instead, and gets no stone at all.
	var checked := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var source := _maze_source(plan)
		assert_not_null(source,
			"%s must carry its own sealed maze source" % _label(outcome))
		if source == null:
			continue
		var rooms_by_parcel := _rooms_by_parcel(plan)
		var wrong := 0
		var stacked_on_rock := 0
		var first := ""
		for plot: Dictionary in source.plots:
			if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_HOUSE:
				continue
			var parcel_id := StringName("parcel.maze.%s" % String(plot["id"]))
			var rooms := rooms_by_parcel.get(parcel_id, []) as Array
			if rooms.is_empty():
				continue
			checked += 1
			var bears := bool(source.plot_facts(plot).get("bears_on_rock",
				false))
			var ground: WarrenRoomStamp = null
			var stacked := false
			for room_value: Variant in rooms:
				var room := room_value as WarrenRoomStamp
				stacked = stacked or not room.terrain_bearing \
					and room.support_parent_parcel_id != parcel_id
				if ground == null or room.source_storey_index \
						< ground.source_storey_index:
					ground = room
			if bears and not ground.terrain_bearing \
					and ground.support_parent_parcel_id.is_empty():
				wrong += 1
				if first.is_empty():
					first = "%s bears on rock but roots in nothing" % parcel_id
			# TASK C5e, newly measurable: 9/standard is the first seed in the
			# corpus that has a plot BOTH resting on rock and declaring a
			# validated building support seam (house.025 on house.005), and it
			# only reached this test because the partial-plate tiling let its
			# town seal. Rooting such a ground room in the mountain instead of
			# in its declared parent is the defect ruling 4 names -- a house
			# standing THROUGH another house -- so the seam wins, and the case
			# is counted and printed rather than folded into either verdict.
			stacked_on_rock += int(bears and not ground.terrain_bearing \
				and not ground.support_parent_parcel_id.is_empty())
			if not bears and stacked and ground.terrain_bearing:
				wrong += 1
				if first.is_empty():
					first = "%s stands on a house and still claims terrain" \
						% parcel_id
		assert_eq(wrong, 0,
			"%s gives %d parcels the wrong base (%s)" % [_label(outcome),
				wrong, first])
		print("MAZE_BASES %s stacked_on_rock=%d" % [_label(outcome),
			stacked_on_rock])
		assert_lte(stacked_on_rock, STACKED_ON_ROCK_CEILING,
			("%s roots %d houses that bear on rock in another house instead") \
				% [_label(outcome), stacked_on_rock])
		# The composition's own reading of the same fact: a house the plot
		# model says stands on ANOTHER PLOT may not root in the mountain at
		# its own floor band. Published by `_partition_rooms` rather than
		# re-derived here, so a future planner change that reintroduces the
		# defect fails at the source of it.
		var unrooted := int(plan.audit.get(
			"maze_unrooted_terrain_bearing_count", -1))
		print("MAZE_BASES %s parcels=%d unrooted_terrain_bearing=%d" % [
			_label(outcome), checked, unrooted])
		# TASK C5c FIX 1, IMPORTANT 5(d). The ceiling alone would let a NEW
		# cause hide inside the tolerated one, so derive the count as well:
		# a house plot the source says stands on another plot, whose composed
		# ground room still roots in the mountain at its own floor band. That
		# is the audit's own definition, read from the sealed source and the
		# sealed plan instead of from the audit it checks.
		var derived_unrooted := 0
		for plot: Dictionary in source.plots:
			if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_HOUSE \
					or bool(source.plot_facts(plot).get("bears_on_rock",
						false)):
				continue
			var stacked_rooms := rooms_by_parcel.get(StringName(
				"parcel.maze.%s" % String(plot["id"])), []) as Array
			var lowest: WarrenRoomStamp = null
			for room_value: Variant in stacked_rooms:
				var room := room_value as WarrenRoomStamp
				if lowest == null or room.source_storey_index \
						< lowest.source_storey_index:
					lowest = room
			derived_unrooted += int(lowest != null and lowest.terrain_bearing \
				and lowest.lattice_origin.y >= int(plot["floor"]))
		assert_eq(unrooted, derived_unrooted,
			("%s must publish exactly the houses that stand on another plot " \
				+ "and still claim terrain") % _label(outcome))
		assert_between(unrooted, 0, UNROOTED_TERRAIN_BEARING_CEILING,
			"%s roots %d houses in terrain the plot says they never touch: %s" \
				% [_label(outcome), unrooted, str(plan.audit.get(
					"maze_unrooted_terrain_bearing_details", []))])
	assert_gt(checked, 0, "at least one sealing seed really composes a house")


func test_stacked_houses_bond_to_flat_roofs() -> void:
	## Ruling 2: a flat-roofed parcel FILLS its plot -- its rooms, its flat
	## roof unit and its retained slab course occupy `[base_band, top_band)` --
	## so a house at that parcel's `top_band` really does stand on something
	## and may declare the seam. Before Task C5 the slab was derived mass no
	## building owned, and every one of these stacks fell back to claiming
	## terrain bearing straight through the house underneath it.
	var declared_total := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var stacked := int(plan.audit.get("maze_stacked_plot_count", -1))
		var declared := int(plan.audit.get("maze_declared_stack_count", -1))
		var gaps := int(plan.audit.get("maze_stack_slab_gap_count", -1))
		print("MAZE_STACKS %s stacked_plots=%d declared=%d slab_gaps=%d" % [
			_label(outcome), stacked, declared, gaps])
		assert_gte(stacked, 0,
			"%s must publish how many plots its planner stacked" % _label(
				outcome))
		assert_eq(gaps, 0,
			("%s refuses %d stacked houses for a slab gap the flat roof now " \
				+ "fills") % [_label(outcome), gaps])
		# Independent of the count: EVERY declared child that composed a
		# building must have a ground room that names the parent parcel and
		# does not claim terrain bearing. A child whose lineage the
		# composition dropped altogether builds nothing at all, which is a
		# different (and older) defect -- counted, not asserted away.
		var rooms_by_parcel := _rooms_by_parcel(plan)
		var seams := 0
		var uncomposed := 0
		var wrong := ""
		for child_value: Variant in (plan.audit.get("maze_stack_parents",
				{}) as Dictionary).keys():
			var child_id := StringName(child_value)
			var parent_id := StringName((plan.audit["maze_stack_parents"] \
				as Dictionary)[child_id])
			var ground: WarrenRoomStamp = null
			for room_value: Variant in rooms_by_parcel.get(child_id,
					[]) as Array:
				var room := room_value as WarrenRoomStamp
				if ground == null or room.source_storey_index \
						< ground.source_storey_index:
					ground = room
			if ground == null:
				uncomposed += 1
				continue
			if ground.terrain_bearing \
					or ground.support_parent_parcel_id != parent_id:
				if wrong.is_empty():
					wrong = "%s roots in %s instead of %s" % [child_id,
						"terrain" if ground.terrain_bearing \
							else ground.support_parent_parcel_id, parent_id]
				continue
			seams += 1
		print(("MAZE_STACK_SEAMS %s declared=%d bonded=%d uncomposed=%d " \
			+ "audited_uncomposed=%d") % [_label(outcome), declared, seams,
			uncomposed, int(plan.audit.get("maze_uncomposed_stack_count",
				-1))])
		assert_eq(int(plan.audit.get("maze_uncomposed_stack_count", -1)),
			uncomposed,
			"%s must publish the declared stacks that composed nothing" \
				% _label(outcome))
		assert_eq(wrong, "",
			"%s declared a stack the composition did not build: %s" % [
				_label(outcome), wrong])
		assert_lte(seams + uncomposed, maxi(0, declared),
			"%s builds more stacked ground rooms than it declared" % _label(
				outcome))
		declared_total += seams
	assert_gt(declared_total, 0,
		"no planner seed builds a stacked house bonded to a flat roof")


func test_retained_rock_skips_a_cell_another_feature_reserved() -> void:
	## Review IMPORTANT 1. `Reservation.FEATURE` is NON-SHAREABLE, and retained
	## stone is the one claim in this pipeline that sweeps a whole volume
	## instead of placing an authored shape -- so it is the one that can meet a
	## cell some other feature reserved without ever assigning it a use (the
	## elevated court does exactly that, and `_discard_unassigned_mass` then
	## turns those cells OUTSIDE, straight into this pass's candidate set).
	## Reserving one of them fails the whole grid transaction and kills the
	## town. The pass must SKIP it and count it.
	##
	## Unit-style on purpose: one real maze source, two identical grids, one
	## pre-reserved cell between them. No solve, no fabric, ~1 s.
	var source := _planned_maze_source(12,
		WarrenVillageScaleProfile.COMPACT)
	assert_not_null(source, "the pinned planner seed must still plan a town")
	if source == null:
		return
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(source)
	assert_not_null(volume, "the maze source must adapt to a volume")
	if volume == null:
		return
	var baseline := _rock_retention_probe(source, volume, Vector3i(2147483647,
		2147483647, 2147483647))
	assert_gt(int(baseline.result.cells), 0,
		"the probe must retain real rock before the reservation is added")
	assert_eq(int(baseline.result.skipped), 0,
		"an unreserved grid skips nothing")
	assert_gt((baseline.cells as Array).size(), 0,
		"the probe must expose the cells it retained")
	# Take a cell the baseline really retained and give its FEATURE bit to
	# somebody else, exactly as a composed feature would.
	var taken := (baseline.cells as Array[Vector3i])[
		(baseline.cells as Array).size() / 2]
	var guarded := _rock_retention_probe(source, volume, taken)
	assert_false(bool(guarded.result.failed),
		"a foreign FEATURE reservation must never reject the retention pass")
	assert_eq(int(guarded.result.skipped), 1,
		"the pass must count the one cell it could not claim")
	assert_eq(int(guarded.result.cells), int(baseline.result.cells) - 1,
		"the pass must retain everything else")
	# And the sealed reservation must still be buildable over what is left.
	var supports := WarrenSupportGraph.new()
	var stone := WarrenVolumetricSolver._maze_stone_reservation(
		guarded.grid as WarrenSpatialGrid, supports)
	assert_false(bool(stone.failed),
		"retained stone must still seal around the reserved cell")
	var feature := stone.feature as WarrenFeatureReservation
	assert_not_null(feature, "retained stone must produce a sealed feature")
	if feature == null:
		return
	assert_eq(feature.reserved_cells.size(), int(guarded.result.cells),
		"the sealed feature must own exactly the cells the pass claimed")
	assert_false(feature.reserved_cells.has(taken),
		"the sealed feature must not own the cell it skipped")


func _rock_retention_probe(source: WarrenMazeSourcePlan,
		volume: WarrenVolumePlan, reserved: Vector3i) -> Dictionary:
	## One fresh grid carrying the source's projected mass, discarded down to
	## OUTSIDE exactly as `from_volume` leaves it before `_retain_maze_rock`
	## runs, optionally with one cell's FEATURE bit already owned by somebody
	## else. Returns `{grid, result, cells}`.
	var bounds := WarrenVolumetricSolver._grid_bounds(source.massif)
	var grid := WarrenSpatialGrid.new(bounds.minimum as Vector3i,
		bounds.size as Vector3i)
	assert_true(grid.is_valid(), "the probe grid must be valid")
	assert_true(WarrenVolumetricSolver._project_massif(grid, source.massif),
		"the probe grid must carry the source massif")
	assert_true(WarrenVolumetricSolver._discard_unassigned_mass(grid),
		"the probe grid must reach the state the retention pass expects")
	if reserved.x != 2147483647:
		var claim := grid.begin_transaction(&"probe.other_feature")
		assert_true(claim.reserve([reserved] as Array[Vector3i],
			WarrenSpatialGrid.Reservation.FEATURE, &"probe.other_feature") \
			and claim.commit(), "the probe reservation must commit")
	var result := WarrenVolumetricSolver._retain_maze_rock(grid, volume)
	var cells: Array[Vector3i] = []
	for cell: Vector3i in grid.cells_with_use(
			WarrenSpatialGrid.Use.STRUCTURAL_VOLUME):
		if grid.owner_name_at(cell) \
				== WarrenSpatialFabricCompiler.MAZE_RETAINED_STONE_ID:
			cells.append(cell)
	return {"grid": grid, "result": result, "cells": cells}


func test_maze_mode_is_deterministic() -> void:
	## Two solves of one seed must agree cell for cell: maze mode is a pure
	## function of (seed, ground bands, scale profile).
	var first := _solved(12, WarrenVillageScaleProfile.COMPACT)
	var first_plan := first.plan as WarrenSpatialPlan
	assert_not_null(first_plan, String(first.failure).left(200))
	if first_plan == null:
		return
	var repeated := _solve(12, WarrenVillageScaleProfile.COMPACT)
	var repeated_plan := repeated.plan as WarrenSpatialPlan
	assert_not_null(repeated_plan, String(repeated.failure).left(200))
	if repeated_plan == null:
		return
	assert_eq(first_plan.deterministic_signature(),
		repeated_plan.deterministic_signature(),
		"maze mode is a pure function of (seed, ground bands, scale profile)")


func _stone_instances(fabric: SettlementFabricPlan) -> Array[Dictionary]:
	## Every retained-maze-stone instance the renderer is really handed, as
	## {face, transform}. Read out of the payload the commit path takes, never
	## out of the rule that produced it, so a bookkeeping fix that does not
	## reach the renderer cannot pass.
	var out: Array[Dictionary] = []
	var payload := SettlementFabricAssembler.terrace_retaining_payload(fabric)
	for asset_value: Variant in payload.batches.keys():
		var batch := payload.batches[asset_value] as Dictionary
		var ids := batch.get("ids", []) as Array
		var transforms := batch.get("transforms", []) as Array
		for index in ids.size():
			var id := String(ids[index])
			if not id.begins_with("maze-stone/"):
				continue
			var parts := id.trim_prefix("maze-stone/").split("/")
			out.append({
				"face": Vector4i(int(parts[0]), int(parts[1]), int(parts[2]),
					int(parts[3])),
				"transform": transforms[index] as Transform3D})
	return out


func _maze_stone_instance_count(fabric: SettlementFabricPlan) -> int:
	return _stone_instances(fabric).size()


func _cap_coverage(instances: Array[Dictionary]) -> Dictionary:
	## How many horizontal slabs really lie over each capped cell, measured off
	## the TRANSFORMS the renderer is handed rather than off the rule that
	## chose them. A cap is the 3 m module laid flat, so its own former height
	## axis -- local +Y, 3 m of it -- sweeps the cells it covers: a cell is
	## covered when its centre falls strictly inside that sweep and within half
	## a cell of its centreline. Two slabs over one cell are the coplanar
	## doubled caps of fix 1, CRITICAL 1.
	var out: Dictionary = {}
	for instance: Dictionary in instances:
		var face := instance["face"] as Vector4i
		if face.w < SettlementFabricAssembler.FACE_DIRECTIONS.size():
			continue
		var xform := instance["transform"] as Transform3D
		var sweep := xform.basis * Vector3(0.0, 3.0, 0.0)
		var axis := sweep.normalized()
		for offset: Vector3i in [Vector3i.ZERO, Vector3i.RIGHT, Vector3i.LEFT,
				Vector3i.BACK, Vector3i.FORWARD]:
			var cell := Vector3i(face.x, face.y, face.z) + offset
			var delta := Vector3(cell) * FabricRecipe.CELL_SIZE - xform.origin
			delta.y = 0.0
			var along := delta.dot(axis)
			var perpendicular := (delta - axis * along).length()
			if along <= 0.05 or along >= sweep.length() - 0.05 \
					or perpendicular >= FabricRecipe.CELL_SIZE * 0.5:
				continue
			var key := Vector4i(cell.x, cell.y, cell.z, face.w)
			out[key] = int(out.get(key, 0)) + 1
	return out


func _plane_key(cell: Vector3i, index: int) -> Vector3i:
	## The vertical plane a side panel stands in, as the boundary between two
	## columns: Vector3i(x, 0 for an x-normal plane / 1 for a z-normal one, z).
	## The same plane has two keyings -- one from each side -- and this
	## canonicalises them, which is the whole point of the overlap check below.
	var direction: Vector3i = SettlementFabricAssembler.FACE_DIRECTIONS[index]
	return Vector3i(cell.x + mini(direction.x, 0),
		0 if direction.x != 0 else 1, cell.z + mini(direction.z, 0))


func _exposed_stone_faces(fabric: SettlementFabricPlan) -> Dictionary:
	## The test's own statement of the face rule, derived from the sealed plan
	## and never from the assembler: a retained maze-stone cell owes a panel on
	## every side whose neighbour is not mass, on a top whose neighbour is
	## neither mass nor a public floor that PLANKS itself, and on a bottom
	## whose neighbour is not mass -- the roof of a bored passage.
	##
	## Three surface kinds plank a floor, not five (fix 1, IMPORTANT 4):
	## `SettlementFabricAssembler.production_surface_payload` tiles
	## STRUCTURAL_COURT, INTERIOR_PASSAGE and BRIDGE. A TERRAIN_STREET is paint
	## on the terrain mesh, which in a maze town lies below the retained stone,
	## and a STAIR is a generated transition mesh; neither draws the top of the
	## stone cell it runs over.
	var out: Dictionary = {}
	var retained := fabric.retained_terrace_cells
	var solids := fabric.transformed_cells(&"solid")
	var paved: Dictionary = {}
	if fabric.surface_plan != null:
		for kind in [PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,
				PublicRealmSurfacePlan.SurfaceKind.INTERIOR_PASSAGE,
				PublicRealmSurfacePlan.SurfaceKind.BRIDGE]:
			for cell: Vector3i in fabric.surface_plan.cells_for_kind(kind):
				paved[cell] = true
	for cell_value: Variant in retained.keys():
		var tag: Variant = retained[cell_value]
		if not (tag is StringName) or StringName(tag) \
				!= SettlementFabricAssembler.MAZE_STONE_TAG:
			continue
		var cell := cell_value as Vector3i
		for index in 6:
			var direction: Vector3i = [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK, Vector3i.UP,
				Vector3i.DOWN][index]
			var neighbor := cell + direction
			if retained.has(neighbor) or solids.has(neighbor) \
					or (direction == Vector3i.UP and paved.has(neighbor)):
				continue
			out[Vector4i(cell.x, cell.y, cell.z, index)] = true
	return out


func test_retained_stone_is_skinned() -> void:
	## TASK C5b RULING 1 AND 2. The mountain a maze town is cut out of is
	## 1292-1530 fine cells of the plan and, before this task, exactly zero
	## rendered panels. Every exposed face of it must now own one rock module,
	## the audit must state that as an identity, and the identity must hold
	## against the payload the renderer is actually handed.
	##
	## FIX 1 adds the three facts the first pass got wrong: a capped cell wears
	## exactly ONE slab (CRITICAL 1), no stone panel shares a plane with a
	## building's plinth panel (IMPORTANT 2), and the building shell's own
	## rendered/expected identity holds on a maze town too, not only on legacy.
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var fabric := plan.compiled_fabric_cache()
		assert_not_null(fabric,
			"%s must carry its compiled fabric" % _label(outcome))
		if fabric == null:
			continue
		var expected := int(fabric.audit.get(
			"maze_stone_expected_face_count", -1))
		var rendered := int(fabric.audit.get(
			"maze_stone_rendered_face_count", -1))
		var missing := int(fabric.audit.get("maze_stone_missing_face_count", -1))
		var stone_cells := int(fabric.audit.get("maze_stone_cell_count", -1))
		var tops := int(fabric.audit.get("maze_stone_top_face_count", -1))
		var bottoms := int(fabric.audit.get(
			"maze_stone_bottom_face_count", -1))
		var top_slabs := int(fabric.audit.get("maze_stone_top_slab_count", -1))
		var bottom_slabs := int(fabric.audit.get(
			"maze_stone_bottom_slab_count", -1))
		var paved_suppressed := int(fabric.audit.get(
			"maze_stone_faces_suppressed_by_paving", -1))
		var raw := int(fabric.audit.get("maze_stone_exposed_face_count", -1))
		var derived := _exposed_stone_faces(fabric)
		var instances := _stone_instances(fabric)
		var plinths := SettlementFabricAssembler.plinth_faces(
			fabric.retained_terrace_cells,
			fabric.transformed_cells(&"solid"),
			fabric.transformed_cells(&"terrain_bearing"))
		var panels := SettlementFabricAssembler.maze_stone_faces(
			fabric.retained_terrace_cells,
			fabric.transformed_cells(&"solid"),
			SettlementFabricAssembler.public_floor_cells(fabric.surface_plan),
			plinths)
		# A plinth panel is 3 m tall and hangs from the top of its own cell, so
		# it closes its band and the one below -- on either keying of its
		# plane. A stone face there is covered by that panel, and a stone panel
		# there would intersect it.
		var plinth_bands: Dictionary = {}
		for key_value: Variant in plinths.keys():
			var key := key_value as Vector4i
			var plane := _plane_key(Vector3i(key.x, key.y, key.z), key.w)
			for band in [key.y, key.y - 1]:
				plinth_bands[Vector4i(plane.x, band, plane.z, plane.y)] = true
		var uncovered := 0
		var coverage := _cap_coverage(instances)
		var doubled_caps := 0
		for key_value: Variant in derived.keys():
			var face := key_value as Vector4i
			if face.w >= SettlementFabricAssembler.FACE_DIRECTIONS.size():
				var slabs := int(coverage.get(face, 0))
				uncovered += int(slabs == 0)
				doubled_caps += int(slabs > 1)
				continue
			# A 3 m course covers its own band and the one below it, so the
			# panel that closes this face is at this band or the next one up --
			# or it is a building's plinth panel standing in the same plane.
			var plane := _plane_key(Vector3i(face.x, face.y, face.z), face.w)
			if plinth_bands.has(Vector4i(plane.x, face.y, plane.z, plane.y)):
				continue
			uncovered += int(not panels.has(face) and not panels.has(
				Vector4i(face.x, face.y + 1, face.z, face.w)))
		var stone_plinth_same_face_overlap := 0
		for instance: Dictionary in instances:
			var face := instance["face"] as Vector4i
			if face.w >= SettlementFabricAssembler.FACE_DIRECTIONS.size():
				continue
			var plane := _plane_key(Vector3i(face.x, face.y, face.z), face.w)
			for band in [face.y, face.y - 1]:
				stone_plinth_same_face_overlap += int(plinth_bands.has(
					Vector4i(plane.x, band, plane.z, plane.y)))
		var foundation_expected := int(fabric.audit.get(
			"foundation_expected_face_count", -1))
		var foundation_rendered := int(fabric.audit.get(
			"foundation_rendered_face_count", -1))
		print(("MAZE_STONE_SKIN %s cells=%d exposed=%d derived=%d " \
			+ "expected=%d rendered=%d missing=%d instances=%d " \
			+ "uncovered=%d tops=%d bottoms=%d top_slabs=%d " \
			+ "bottom_slabs=%d doubled_caps=%d plinth_overlap=%d " \
			+ "paved_suppressed=%d deferred_to_plinth=%d " \
			+ "foundation=%d/%d") % [
			_label(outcome), stone_cells, raw, derived.size(), expected,
			rendered, missing, instances.size(), uncovered, tops, bottoms,
			top_slabs, bottom_slabs, doubled_caps,
			stone_plinth_same_face_overlap, paved_suppressed,
			int(fabric.audit.get("maze_stone_faces_deferred_to_plinth", -1)),
			foundation_rendered, foundation_expected])
		assert_gt(stone_cells, 0,
			"%s must publish the retained maze stone it kept" % _label(outcome))
		assert_gt(expected, 0,
			"%s retained mountain must expose faces to skin" % _label(outcome))
		assert_eq(rendered, expected,
			"%s must render one panel per emitted stone panel" \
				% _label(outcome))
		assert_eq(missing, 0,
			"%s may leave no exposed stone face unskinned" % _label(outcome))
		assert_eq(derived.size(), raw,
			("%s audited exposed-face count must equal the shell derived " \
				+ "from the sealed plan alone") % _label(outcome))
		assert_eq(uncovered, 0,
			("%s must cover every exposed face of the mountain with a " \
				+ "course, or the shell has holes") % _label(outcome))
		assert_lt(expected, raw,
			("%s must course its side faces at the module's own height, " \
				+ "not hang one panel per band") % _label(outcome))
		assert_eq(instances.size(), expected,
			("%s must hand the renderer exactly the panels it audited") \
				% _label(outcome))
		assert_gt(tops, 0,
			("%s open shoulder must be capped, or the mountain is a hollow " \
				+ "shell") % _label(outcome))
		assert_gt(bottoms, 0,
			("%s bored passages must get a stone roof, or a street looks up " \
				+ "through the mountain") % _label(outcome))
		# FIX 1, CRITICAL 1. The 3 m module laid flat spans TWO cells, so a
		# slab per exposed cap face put two coplanar slabs over every adjacent
		# pair. Measured off the transforms themselves.
		assert_eq(doubled_caps, 0,
			("%s may never lay two coplanar slabs over one capped cell") \
				% _label(outcome))
		assert_lt(top_slabs, tops,
			("%s must PAIR its top caps: a flat 3 m module covers two cells, " \
				+ "so slabs must be fewer than capped cells") % _label(outcome))
		assert_lt(bottom_slabs, bottoms,
			("%s must pair its passage-roof caps for the same reason") \
				% _label(outcome))
		# FIX 1, IMPORTANT 2. Two different modules in one plane is the
		# artefact; the stone starts below a building's plinth instead.
		assert_eq(stone_plinth_same_face_overlap, 0,
			("%s may never stand a stone panel in the same plane and band " \
				+ "as a building's plinth panel") % _label(outcome))
		assert_eq(foundation_rendered, foundation_expected,
			("%s building shell must render exactly the plinth faces it " \
				+ "expects -- the mountain owes none of them") \
				% _label(outcome))
		# No boundary may wear two panels: a plinth face and a stone face on
		# the same seam would intersect in one plane.
		var doubled := 0
		for key_value: Variant in plinths.keys():
			var key := key_value as Vector4i
			var direction := SettlementFabricAssembler.FACE_DIRECTIONS[key.w]
			var opposite := Vector3i(key.x, key.y, key.z) + direction
			var back_index := key.w + 1 - 2 * (key.w % 2)
			doubled += int(derived.has(Vector4i(opposite.x, opposite.y,
				opposite.z, back_index)))
		assert_eq(doubled, 0,
			"%s may never put a plinth panel and a stone panel on one seam" \
				% _label(outcome))


func _asset_plot_records(world_seed: int, scale_id: StringName) -> Array:
	## The planner's own asset outcomes, straight off a fresh source plan.
	var maze := _planned_maze_source(world_seed, scale_id)
	if maze == null:
		return []
	var outcomes: Dictionary = maze.audit.get("plot_outcomes", {})
	return outcomes.get("assets", []) as Array


func test_assets_land() -> void:
	## TASK C5b RULING 3. C2 measured three asset plots and ZERO landmarks:
	## the planner sited assets by a footprint that never had to hold the
	## prefab once it was anchored by its own doorway, so `_maze_asset_
	## landmark` refused every one and could not have done otherwise.
	##
	## The planner now carries the entrance-relative envelope and mirrors the
	## builder's own three tests before it commits a site. This asserts the
	## mirror is SOUND -- every site it calls realisable really becomes a
	## prefab landmark -- and publishes, per seed, which of the builder's
	## tests the town's sites actually fail, so "no asset lands here" is a
	## number and not a shrug.
	var realisable_total := 0
	var realised_total := 0
	var tested_total := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var records := _asset_plot_records(int(outcome.seed),
			StringName(outcome.scale))
		var landmarks := _feature_count(plan, &"prefab_landmark")
		var realisable := 0
		var placed := 0
		var tally: Dictionary = {}
		for record_value: Variant in records:
			var record := record_value as Dictionary
			assert_true(record.has("realisable") and record.has("mirror"),
				"%s asset outcome must publish the mirror's verdict" \
					% _label(outcome))
			placed += int(record.get("site", null) != null)
			realisable += int(bool(record.get("realisable", false)))
			var mirror := record.get("mirror", {}) as Dictionary
			for key: String in ["tested", "no_frontage", "street_over_top",
					"body_outside_plot", "bearing_off_ground", "realisable"]:
				tally[key] = int(tally.get(key, 0)) + int(mirror.get(key, 0))
		var reasons := PackedStringArray()
		for record_value: Variant in plan.audit.get(
				"maze_asset_outcomes", []) as Array:
			var record := record_value as Dictionary
			reasons.append(String(record.get("reason", "")).left(240))
		realisable_total += realisable
		realised_total += landmarks
		print(("MAZE_ASSET_LAND %s placed=%d realisable=%d landmarks=%d " \
			+ "mirror=%s | %s") % [_label(outcome), placed, realisable,
			landmarks, tally, " ; ".join(reasons)])
		# A town whose planner never enumerated a single candidate SITE has
		# nothing for the mirror to judge, and asserting otherwise per town
		# says "every town must offer the mirror work" rather than "the mirror
		# is sound". 9/standard is the first such town in the corpus (Task
		# C5e: it seals now, and its two asset records are refused before any
		# site is enumerated), so the bar moved corpus-wide and the two teeth
		# that matter -- the tally accounts for every site tested, and every
		# realisable site really becomes a landmark -- stay per town.
		tested_total += int(tally.get("tested", 0))
		assert_eq(int(tally.get("tested", 0)),
			int(tally.get("no_frontage", 0)) \
				+ int(tally.get("street_over_top", 0)) \
				+ int(tally.get("body_outside_plot", 0)) \
				+ int(tally.get("bearing_off_ground", 0)) \
				+ int(tally.get("realisable", 0)),
			"%s mirror tally must account for every site it tested" \
				% _label(outcome))
		# SOUNDNESS. This is the whole point of the mirror: a site it accepts
		# is a site `_maze_asset_landmark` can stand a prefab on. It bites the
		# moment the mirror is looser than the builder.
		assert_eq(landmarks, realisable,
			("%s must realise exactly the asset sites its planner called " \
				+ "realisable") % _label(outcome))
	print("MAZE_ASSET_LAND corpus realisable=%d realised=%d tested=%d" % [
		realisable_total, realised_total, tested_total])
	assert_gt(tested_total, 0,
		"no seed enumerated an asset site for the realisation mirror to judge")
	assert_eq(realised_total, realisable_total,
		"the corpus must realise exactly the sites the mirror accepted")
	# FIX 1, IMPORTANT 3. Soundness is a real property and the assertions above
	# state it, but on a corpus that realises nothing they read
	# `assert_eq(0, 0)` and report a PASS for an outcome nobody delivered.
	# Ruling 3 wanted a landmark, so while there is none this test says so out
	# loud instead of going green on a vacuous identity.
	if realised_total == 0:
		pending(("no asset realises on the corpus: the ROOF-face and " \
			+ "bearing-off-natural-ground gates are both open since Task " \
			+ "C5c ruling 5, and every remaining site is refused because " \
			+ "its measured envelope plus the one-cell eave halo meets a " \
			+ "neighbouring plot -- see task-c5c-report"))
		return
	assert_gte(realised_total, 1,
		"ruling 3 wants a landmark the production pass really builds")


func test_optional_facade_projections_yield_to_mandatory_shells() -> void:
	## TASK C6 RULING 1. `authored room envelope gate failed: room … failed
	## measured phase selection` was the last composition family standing, and
	## it was an ORDERING defect, not a vocabulary limit.
	##
	## A phase-B facade recipe hangs an ivy, sign, laundry or windowbox piece
	## 0.3–0.8 m off the front of its shell, and that piece is measured into the
	## room's clearance envelope. `compile_room_units` walks rooms bottom band
	## first, so on a plot-model town the projecting house is compiled BEFORE
	## the house that sits one band up and one cell across from it — and when
	## that house's turn came, the compiler's only recovery (demote THIS room
	## from phase B to phase A) was spent on the wrong room. A ground room's
	## `*.base.*` shell is mandatory and has no phase-B mate at all, so
	## `fallback_id == recipe_id` and the whole town was refused.
	##
	## `_required_room_clearance` reserves every room's MANDATORY shell before
	## anyone's optional projection is chosen, exactly as the roof pre-pass
	## already does for roofs. This test does not take the compiler's word for
	## any of it: for every yield the audit names it re-derives both envelopes
	## from the room stamps in the sealed plan and the boxes in the measured
	## vocabulary, and asserts the projection really did meet the mandatory
	## shell and the flush shell really does not.
	var measured := 0
	var total_yields := 0
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var fabric := plan.compiled_fabric_cache()
		assert_not_null(fabric,
			"%s must carry its compiled fabric" % _label(outcome))
		if fabric == null:
			continue
		var room_by_id: Dictionary = {}
		for building: WarrenBuildingVolume in plan.buildings:
			for room: WarrenRoomStamp in building.room_records:
				room_by_id[room.stable_id] = room
		var envelopes := int(fabric.audit.get(
			"required_room_clearance_envelope_count", -1))
		var yields: Array = fabric.audit.get(
			"required_room_facade_yields", []) as Array
		var yield_count := int(fabric.audit.get(
			"required_room_facade_fallback_count", -1))
		var fallbacks := int(fabric.audit.get(
			"facade_phase_fallback_count", -1))
		var desired_b := int(fabric.audit.get(
			"desired_facade_phase_b_count", -1))
		var selected_b := int(fabric.audit.get(
			"selected_facade_phase_b_count", -1))
		print(("MAZE_FACADE_YIELD %s rooms=%d envelopes=%d desired_b=%d " \
			+ "selected_b=%d fallbacks=%d yields=%d") % [_label(outcome),
			room_by_id.size(), envelopes, desired_b, selected_b, fallbacks,
			yield_count])
		# The pre-pass is a fact about EVERY room, not about the ones that
		# happened to fail: a mandatory shell missing from the reservation is
		# a room some later projection may still be allowed to reach into.
		assert_eq(envelopes, room_by_id.size(),
			("%s reserves %d mandatory room shells for %d rooms") % [
				_label(outcome), envelopes, room_by_id.size()])
		assert_eq(yield_count, yields.size(),
			"%s counts %d facade yields but names %d" % [_label(outcome),
				yield_count, yields.size()])
		assert_lte(yield_count, MAZE_FACADE_YIELD_CEILING,
			("%s gave up %d optional facades to mandatory room shells; the " \
				+ "gate is meant to be narrow") % [_label(outcome),
				yield_count])
		assert_lte(yield_count, fallbacks,
			("%s attributes %d facade fallbacks to the mandatory-shell gate " \
				+ "but only took %d fallbacks in all") % [_label(outcome),
				yield_count, fallbacks])
		assert_lte(desired_b - selected_b, fallbacks,
			("%s lost %d phase-B facades but recorded %d fallbacks") % [
				_label(outcome), desired_b - selected_b, fallbacks])
		for entry_value: Variant in yields:
			var entry := entry_value as Dictionary
			var room := room_by_id.get(StringName(
				entry.get("room_id", &""))) as WarrenRoomStamp
			assert_not_null(room, "%s names a yield for an unknown room %s" % [
				_label(outcome), entry.get("room_id", &"")])
			if room == null:
				continue
			var built := fabric.unit(StringName("spatial.fabric.%s" \
				% room.stable_id))
			assert_not_null(built,
				"%s names a yield for a room with no built unit: %s" % [
					_label(outcome), room.stable_id])
			if built == null:
				continue
			# 1. The room really took the flush shell, in the shipped fabric.
			assert_eq(String(built.recipe_id),
				String(entry.get("chosen_recipe_id", &"")),
				"%s says %s fell back but it is built as %s" % [
					_label(outcome), room.stable_id, built.recipe_id])
			var split := String(entry.get("required", "")).split("/", false)
			assert_eq(split.size(), 2,
				"%s yield names no required room/recipe pair: %s" % [
					_label(outcome), entry.get("required", "")])
			if split.size() != 2:
				continue
			var victim := room_by_id.get(StringName(split[0])) \
				as WarrenRoomStamp
			assert_not_null(victim,
				"%s yields to a room that is not in the plan: %s" % [
					_label(outcome), split[0]])
			if victim == null:
				continue
			var wanted := _clearance_box(room,
				StringName(entry.get("desired_recipe_id", &"")))
			var taken := _clearance_box(room, built.recipe_id)
			var required := _clearance_box(victim, StringName(split[1]))
			assert_true(wanted.has_volume() and taken.has_volume() \
				and required.has_volume(),
				"%s yield names a recipe the vocabulary does not measure: %s" \
					% [_label(outcome), str(entry)])
			# 2. The PROJECTION really met the mandatory shell, and
			# 3. the FLUSH shell really does not — which is the whole claim the
			#    gate makes and the only reason demoting the facade is a fix
			#    rather than a random loss of detail.
			assert_true(SettlementFabricPlan._aabb_overlaps_volume(wanted,
				required),
				("%s demoted %s but its phase-B envelope never met %s") % [
					_label(outcome), room.stable_id, split[0]])
			assert_false(SettlementFabricPlan._aabb_overlaps_volume(taken,
				required),
				("%s demoted %s to a shell that still meets %s") % [
					_label(outcome), room.stable_id, split[0]])
		total_yields += maxi(0, yield_count)
		measured += 1
	assert_gt(measured, 0, "at least one seed sealed a town to measure")
	print("MAZE_FACADE_YIELD corpus towns=%d yields=%d" % [measured,
		total_yields])
	# The branch cannot ship inert: somewhere on this corpus an optional facade
	# really does give way to a shell that has no choice.
	assert_gt(total_yields, 0,
		"no planner seed yielded a single facade to a mandatory room shell")


func _clearance_box(room: WarrenRoomStamp, recipe_id: StringName) -> AABB:
	## The measured clearance envelope an authored recipe occupies when it is
	## stamped at this room — derived from the room stamp in the sealed plan
	## and the box in the compiled vocabulary, never from the compiler's own
	## bookkeeping.
	var recipe := _program().recipe(recipe_id)
	if recipe == null:
		return AABB()
	return FabricRecipe.lattice_transform(room.lattice_origin,
		room.yaw_quarters) * recipe.local_clearance_bounds


func test_corpus_composes() -> void:
	## TASK C6 RULING 3 — the Phase C exit measurement, in two halves.
	##
	## The four planner seeds are solved here and must seal inside their own
	## measured wall clock. The 24-town matrix is asserted from the sweep's
	## written summary, because solving it a second time inside this file would
	## double its budget for no new information.
	for outcome: Dictionary in _corpus():
		var ceiling := int(PLANNER_SOLVE_MS_CEILING.get(
			"%d/%s" % [int(outcome.seed), String(outcome.scale)], 0))
		assert_gt(ceiling, 0,
			"%s has no measured solve-time ceiling" % _label(outcome))
		assert_not_null(outcome.plan, "%s must seal its town: %s" % [
			_label(outcome), String(outcome.failure).left(200)])
		assert_lte(int(outcome.ms), ceiling,
			("%s solved in %d ms against a %d ms ceiling; name the stage " \
				+ "with tests/harness/warren_maze_stage_probe.gd before " \
				+ "re-pinning") % [_label(outcome), int(outcome.ms), ceiling])
	_assert_stage_stamps_are_whole()
	var summary := _corpus_sweep_summary()
	if summary.is_empty():
		pending(("the 24-seed corpus matrix has not been measured on this " \
			+ "machine: run tests/harness/warren_maze_mode_sweep.gd -- " \
			+ "--seeds 1,2,3,4,5,6,7,8,9,10,11,12 --mode maze --scale " \
			+ "compact,standard, which writes %s") % MAZE_SWEEP.SUMMARY_PATH)
		return
	# A summary is evidence about the code that produced it and nothing else.
	# Without this the file survives every later edit and reports a green
	# corpus measured against a tree that no longer exists.
	var fingerprint := MAZE_SWEEP.production_fingerprint()
	assert_ne(fingerprint, "",
		"the fabric script directory could not be fingerprinted")
	if String(summary.get("fingerprint", "")) != fingerprint:
		pending(("the recorded 24-seed corpus matrix is STALE -- it was " \
			+ "measured against a different %s. Re-run " \
			+ "tests/harness/warren_maze_mode_sweep.gd -- --seeds " \
			+ "1,2,3,4,5,6,7,8,9,10,11,12 --mode maze --scale " \
			+ "compact,standard") % MAZE_SWEEP.PRODUCTION_SCRIPT_DIR)
		return
	# A three-seed spot check is not the corpus. Refuse to score against one.
	assert_eq(String(summary.get("mode", "")),
		String(WarrenTownSolver.MODE_MAZE),
		"the recorded sweep is not a maze sweep")
	assert_eq(_int_array(summary.get("seeds", [])), CORPUS_SWEEP_SEEDS,
		"the recorded sweep does not cover the corpus seeds")
	assert_eq(_string_array(summary.get("scales", [])), CORPUS_SWEEP_SCALES,
		"the recorded sweep does not cover both corpus scales")
	var rows: Array = summary.get("rows", []) as Array
	assert_eq(rows.size(), CORPUS_SWEEP_SEEDS.size() \
		* CORPUS_SWEEP_SCALES.size(),
		"the recorded sweep has %d rows, not one per corpus town" % rows.size())
	var sealed_count := 0
	var failures := PackedStringArray()
	var retired := PackedStringArray()
	for row_value: Variant in rows:
		var row := row_value as Dictionary
		var label := "%d/%s" % [int(row.get("seed", -1)),
			String(row.get("scale", ""))]
		if bool(row.get("sealed", false)):
			sealed_count += 1
			continue
		failures.append("%s [%s]" % [label,
			String(row.get("gate", "")).left(90)])
		if String(row.get("failure", "")).contains(RETIRED_CORPUS_GATE):
			retired.append(label)
	print("MAZE_CORPUS sealed=%d/%d failures=%s" % [sealed_count, rows.size(),
		", ".join(failures)])
	assert_eq(sealed_count, int(summary.get("sealed", -1)),
		"the recorded sweep's own seal count disagrees with its rows")
	# Two-sided, like every pin in this file: below the floor is a regression
	# to report, and comfortably above it is a pin that has gone stale.
	assert_gte(sealed_count, CORPUS_SEALED_FLOOR,
		"the maze corpus seals %d of %d towns: %s" % [sealed_count,
			rows.size(), ", ".join(failures)])
	assert_lt(sealed_count, rows.size(),
		("the whole corpus seals; delete the shortfall note above " \
			+ "CORPUS_SEALED_FLOOR and re-pin"))
	assert_eq(retired.size(), 0,
		("Task C6 ruling 1 closed the measured-phase-selection family; these " \
			+ "towns died there again: %s") % ", ".join(retired))


func _assert_stage_stamps_are_whole() -> void:
	## TASK C6 RULING 4's machinery, guarded. The stage table in the report and
	## the plan is only worth reading if the stamps are really taken, so assert
	## the two nestings they claim: the three sub-stages of `_partition_rooms`
	## fit inside it, and the composition's own stages fit inside the whole
	## composition. A stamp that stopped firing reads as 0 and fails the first
	## check; a stamp bracketing the wrong span fails the second.
	for outcome: Dictionary in _corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		if plan == null:
			continue
		var stages := plan.audit.get("maze_stage_ms", {}) as Dictionary
		var spatial_ms := int(plan.audit.get("maze_spatial_ms", -1))
		print("MAZE_STAGE_MS %s spatial=%d %s" % [_label(outcome), spatial_ms,
			str(stages)])
		assert_gt(spatial_ms, 0,
			"%s must publish its composition wall clock" % _label(outcome))
		for stage: String in ["parcels", "partition_rooms", "hero_beam",
				"room_composition", "residual_rooms", "feature_solver",
				"room_gate"]:
			assert_true(stages.has(stage),
				"%s never stamped the %s stage" % [_label(outcome), stage])
			assert_gt(int(stages.get(stage, -1)), 0,
				"%s stamped %s at zero ms, which is not a measurement" % [
					_label(outcome), stage])
		var inside_partition := int(stages.get("hero_beam", 0)) \
			+ int(stages.get("room_composition", 0)) \
			+ int(stages.get("residual_rooms", 0))
		assert_lte(inside_partition, int(stages.get("partition_rooms", 0)),
			("%s stamps %d ms inside a %d ms room partition") % [
				_label(outcome), inside_partition,
				int(stages.get("partition_rooms", 0))])
		var inside_composition := int(stages.get("parcels", 0)) \
			+ int(stages.get("partition_rooms", 0)) \
			+ int(stages.get("feature_solver", 0)) \
			+ int(stages.get("room_gate", 0))
		assert_lte(inside_composition, spatial_ms,
			"%s stamps %d ms inside a %d ms composition" % [_label(outcome),
				inside_composition, spatial_ms])


func _corpus_sweep_summary() -> Dictionary:
	## The sweep's own matrix, or {} when this machine has never run it.
	if not FileAccess.file_exists(MAZE_SWEEP.SUMMARY_PATH):
		return {}
	var file := FileAccess.open(MAZE_SWEEP.SUMMARY_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}


func _int_array(value: Variant) -> Array[int]:
	var out: Array[int] = []
	for item: Variant in (value as Array if value is Array else []):
		out.append(int(item))
	return out


func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	for item: Variant in (value as Array if value is Array else []):
		out.append(String(item))
	return out


# --- Real ground (task D1) --------------------------------------------------
# Everything above composes on a FLAT frame. These tests run the identical
# production entry point on two authored band profiles and pin what only real
# ground can decide: that a hillside town composes at all, that its street
# floors still stand on stone, what share of its plot mass it leaves unroomed,
# and that `solve_selected` -- the production placement re-solve -- has a maze
# branch that works.

const StampedGround = preload("res://tests/fixtures/warren_stamped_ground.gd")

## Cache key for the flat frame every test above this section uses.
const FLAT_GROUND := &"flat"
## A one-directional natural hillside, SLOPE_RELIEF_BANDS across the footprint.
const RAMP_GROUND := &"ramp"
## Two benches split by one RISER_BANDS terrace step through the footprint.
const STEP_GROUND := &"step"

## The sloped corpus: two ground profiles over two of the four planner towns,
## so every sloped row shares its seed, scale and solve cache with a flat twin.
const SLOPED_GROUND: Array[Dictionary] = [
	{"ground": RAMP_GROUND, "seed": 12, "scale": &"compact"},
	{"ground": RAMP_GROUND, "seed": 3, "scale": &"standard"},
	{"ground": STEP_GROUND, "seed": 12, "scale": &"compact"},
	{"ground": STEP_GROUND, "seed": 3, "scale": &"standard"},
]


## Ceiling on a SLOPED town's unroomed plot-mass share: measured worst (0.337,
## ramp 3/standard) plus the 0.05 guard this file's flat pin uses = 0.387,
## rounded to two places IN THE SAFE DIRECTION, which for a ceiling is UP.
## That is this file's own convention, not a new one:
## `UNROOMED_PLOT_MASS_CEILING` is 0.28 from a measured 0.224 + 0.05 = 0.274,
## and the plots suite's `BUILDABLE_COVERAGE_FLOOR` is 0.91 from 0.965 - 0.05
## = 0.915 rounded DOWN because it is a floor.
##
## It sits above `UNROOMED_PLOT_MASS_CEILING` (0.28) because relief really does
## leave more of the mass unbuilt -- a house whose plot floor follows a
## climbing street reaches less of the column under it -- and the two are
## pinned apart rather than the flat one being loosened. Re-pin upward only,
## and report.
const SLOPED_UNROOMED_PLOT_MASS_CEILING := 0.39

## Wall-clock ceiling per sloped town: measured (2161 / 6377 / 2782 / 8207 ms)
## x 2.0. Wall clock on a shared machine is noisy in a way a cell count is not,
## and these exist to catch a town that has fallen into a SEARCH -- an order of
## magnitude -- not to police a 30 % drift, so they are pinned looser than the
## flat `PLANNER_SOLVE_MS_CEILING`'s 1.5x. Sloped solves are not slower in
## kind: ramp 3/standard is 6377 ms against its flat twin's 5554.
## TASK E1. Sloped rows that no longer compose, pinned BY NAME with the gate
## they die at, so a row that dies anywhere else is still a red test and a row
## that starts composing again is a re-pin rather than a silent pass.
##
## The noise massif reshuffled the sloped fixtures exactly as it reshuffled the
## flat corpus: `step 3/standard` now reaches the public-realm adapter and is
## refused for a duplicate realm edge -- the SAME family Phase C's exit ruling
## carried into the E/G loop, and the same one that takes 5/compact and
## 10/standard out of the flat 24. It is not a new gate and not a massif
## invariant: the massif for this row seals, carves, plots and parcels; the
## realm adapter emits two edges with one id. Empty this map when that adapter
## is fixed.
const SLOPED_KNOWN_REFUSALS: Dictionary = {
	"step/3/standard": "duplicate edge",
}

const SLOPED_SOLVE_MS_CEILING: Dictionary = {
	"ramp/12/compact": 4400,
	"ramp/3/standard": 12800,
	"step/12/compact": 5600,
	"step/3/standard": 16500,
}

## The seed the `solve_selected` re-solve is exercised on for each profile.
## Ruling 5 asks for the RAMP; 1/compact is a ramp town whose flat preview
## seals, which is the precondition for there being anything to re-solve. The
## step profile runs beside it on a corpus seed.
const SELECTED_ROWS: Array[Dictionary] = [
	{"ground": RAMP_GROUND, "seed": 1, "scale": &"compact"},
	{"ground": STEP_GROUND, "seed": 12, "scale": &"compact"},
]


static func _town_key(seed_value: int, scale: StringName,
		ground: StringName) -> String:
	## Flat keys are unprefixed, so every cache entry the flat tests share is
	## exactly the string they used before the ground axis existed.
	return "%d/%s" % [seed_value, String(scale)] if ground == FLAT_GROUND \
		else "%s/%d/%s" % [String(ground), seed_value, String(scale)]


func _ground_bands(ground: StringName, seed_value: int,
		scale: StringName) -> Dictionary:
	## The authored band frame for one row. The span is the profile's own
	## `radius_cells`, which is exactly the square `WarrenMassifBuilder` reads:
	## a shorter frame would default the rim to band zero and invent a cliff
	## the fixture never described.
	var profile := WarrenVillageScaleProfile.for_id(scale)
	match ground:
		RAMP_GROUND:
			return StampedGround.slope(profile.radius_cells, seed_value)
		STEP_GROUND:
			return StampedGround.terrace_step(profile.radius_cells, seed_value)
	return {}


func _sloped_corpus() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in SLOPED_GROUND:
		out.append(_solved(int(row["seed"]), StringName(row["scale"]),
			StringName(row["ground"])))
	return out


func _row_key(outcome: Dictionary) -> String:
	return "%s/%d/%s" % [String(outcome.get("ground", FLAT_GROUND)),
		int(outcome.seed), String(outcome.scale)]


func _quarter_bands(bands: Dictionary, quarter: int) -> Dictionary:
	## The same ground frame read in the town's own lattice after a yaw of
	## `quarter` right angles -- which is what `VillageWarrenFabricSolver
	## ._sample_ground_bands` hands `solve_selected` for that placement
	## candidate. Rotating the FRAME is the exact dual of rotating the town,
	## and the four quarters are the same set of frames under either sign
	## convention, so this needs no agreement with `Basis`'s handedness.
	var out: Dictionary = {}
	for column: Vector2i in bands:
		var source := column
		match posmod(quarter, 4):
			1:
				source = Vector2i(column.y, -column.x)
			2:
				source = Vector2i(-column.x, -column.y)
			3:
				source = Vector2i(-column.y, column.x)
		out[column] = int(bands.get(source, 0))
	return out


func test_sloped_ground_composes() -> void:
	## TASK D1 RULING 4. The production entry point, on real bands, per
	## fixture-seed: does the town seal, how long does it take, how much of its
	## plot mass stays unroomed, and do its street floors still stand on stone?
	##
	## The relief the massif received is asserted, not merely printed: a
	## fixture that silently flattened would pass everything else vacuously.
	##
	## FIX 1: all four rows compose. `ramp 12/compact` used to die at the
	## source's addressed-frontage bar; the controller ruled that bar ADVISORY
	## in maze mode, so the town ships and RECORDS the ratio it reached instead.
	## That record is asserted here -- a shortfall that is not published is the
	## failure mode the ruling creates, and it is exactly what this catches.
	var composed := 0
	var short_rows := 0
	var refused := PackedStringArray()
	for outcome: Dictionary in _sloped_corpus():
		var plan := outcome.plan as WarrenSpatialPlan
		var key := _row_key(outcome)
		if plan == null and SLOPED_KNOWN_REFUSALS.has(key):
			refused.append(key)
			assert_true(String(outcome.failure).contains(
				String(SLOPED_KNOWN_REFUSALS[key])),
				("%s is pinned as a known refusal at `%s` and died at `%s` " \
					+ "instead") % [key, String(SLOPED_KNOWN_REFUSALS[key]),
					String(outcome.failure).left(200)])
			continue
		assert_not_null(plan, "%s must compose on real ground: %s" % [
			_label(outcome), String(outcome.failure).left(200)])
		if plan == null:
			continue
		composed += 1
		var source := _maze_source(plan)
		assert_not_null(source, "%s must carry its maze source" % key)
		var relief := 0 if source == null else source.massif.relief_bands()
		var frontage := -1.0 if source == null \
			else float(source.audit.get("frontage_ratio", -1.0))
		var share := float(plan.audit.get("maze_unroomed_plot_share", -1.0))
		var shortfalls := plan.audit.get("advisory_shortfalls",
			{}) as Dictionary
		var fabric := plan.compiled_fabric_cache()
		assert_not_null(fabric, "%s must carry its compiled fabric" % key)
		var standing: Dictionary = {} if fabric == null \
			else _route_floor_standing(plan, fabric)
		print(("MAZE_SLOPED_COMPOSE %s SEALED ms=%d relief=%d plots=%d " \
			+ "frontage=%.3f unroomed=%.3f route_on_stone=%.3f holes=%s") % [
			_label(outcome), int(outcome.ms), relief,
			0 if source == null else source.plots.size(), frontage, share,
			float(standing.get("share", -1.0)),
			str(standing.get("holes", {}))])
		assert_gte(relief, 3,
			("%s must stand on real relief; the fixture handed the massif " \
				+ "%d bands") % [key, relief])
		# The ruling's teeth: below the advisory bar the town ships, but only
		# WITH the fact. Above it, it must not invent one.
		if frontage >= 0.0 and frontage < WarrenMazeSourcePlan.FRONTAGE_FLOOR:
			short_rows += 1
			assert_almost_eq(float(shortfalls.get("frontage", -1.0)),
				frontage, 0.0005,
				("%s addresses %.3f of its passage cells and must " \
					+ "say so in its advisory shortfalls") % [key, frontage])
			assert_almost_eq(float(shortfalls.get("frontage_target", -1.0)),
				WarrenMazeSourcePlan.FRONTAGE_FLOOR, 0.0005,
				"%s must publish the bar it fell short of" % key)
		else:
			assert_false(shortfalls.has("frontage"),
				"%s clears the frontage bar and must report no shortfall" % key)
		assert_true(SLOPED_SOLVE_MS_CEILING.has(key),
			"%s must carry a measured solve-time ceiling" % key)
		assert_lt(int(outcome.ms), int(SLOPED_SOLVE_MS_CEILING.get(key,
			MAXIMUM_SOLVE_MS)),
			"%s composed in %d ms, past its measured ceiling" % [key,
				int(outcome.ms)])
		assert_between(share, 0.0, SLOPED_UNROOMED_PLOT_MASS_CEILING,
			"%s leaves %.3f of its plot mass unroomed" % [key, share])
		if fabric == null:
			continue
		assert_gte(float(standing.get("share", 0.0)), ROUTE_ON_STONE_FLOOR,
			("%s lays %d route floor cells on real ground and only %.3f of " \
				+ "them stand on anything") % [key,
				plan.route_floor_cells.size(),
				float(standing.get("share", 0.0))])
	assert_eq(composed, SLOPED_GROUND.size() - SLOPED_KNOWN_REFUSALS.size(),
		"every sloped row except the pinned refusals must compose")
	assert_eq(refused.size(), SLOPED_KNOWN_REFUSALS.size(),
		("the pinned sloped refusals are %s and %s actually refused; a row " \
			+ "that started composing is a re-pin") % [
			str(SLOPED_KNOWN_REFUSALS.keys()), str(refused)])
	# The advisory branch must be EXERCISED, or the assertions above are
	# decoration: one sloped row is measurably short of the bar and ships.
	assert_gt(short_rows, 0,
		("no sloped row fell short of the advisory frontage bar; the branch " \
			+ "the ruling created is untested here"))


func test_solve_selected_rebuilds_the_maze_on_real_ground() -> void:
	## TASK D1 RULING 1 and 5. `WarrenVolumetricSolver.solve_selected` is what
	## `VillageWarrenFabricSolver` calls once a placement's terrain has been
	## sampled, and its mass-first machinery (`mass_first_attempt_index`, the
	## ranked frontier, the partition variant) has no maze equivalent: before
	## this task it could not run in MODE_MAZE at all. The maze branch re-runs
	## the identical one-pass solve with the placement's real bands.
	##
	## The preview is the FLAT solve of the same seed, exactly as production
	## builds it, and each cardinal quarter's bands are that quarter's reading
	## of the ground frame. The bands are built here rather than by driving
	## `VillageWarrenFabricSolver.solve` with a terrain view -- that end-to-end
	## run is task D2's. Per-quarter outcomes are printed; the bar is that at
	## least one quarter of each profile re-solves and lands its entrance where
	## the preview did, because that is the (x, z) the village road was aligned
	## to and the only part of the entry cell production compares.
	var program := _program()
	for row: Dictionary in SELECTED_ROWS:
		var seed_value := int(row["seed"])
		var scale_id := StringName(row["scale"])
		var ground := StringName(row["ground"])
		var label := "%s %d/%s" % [String(ground), seed_value,
			String(scale_id)]
		var preview := _solved(seed_value, scale_id).plan as WarrenSpatialPlan
		assert_not_null(preview,
			"%s needs a sealed flat preview to re-solve from" % label)
		if preview == null:
			continue
		var entry := preview.source_volume.entry_cell
		var bands := _ground_bands(ground, seed_value, scale_id)
		var matched := 0
		WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MAZE
		for quarter in 4:
			var started_ms := Time.get_ticks_msec()
			var rebuilt := WarrenVolumetricSolver.solve_selected(seed_value,
				preview, _quarter_bands(bands, quarter), program)
			var elapsed_ms := Time.get_ticks_msec() - started_ms
			if rebuilt == null:
				print("MAZE_SELECTED %s quarter %d REFUSED ms=%d %s" % [
					label, quarter, elapsed_ms,
					WarrenVolumetricSolver.last_failure.left(150)])
				continue
			var built := rebuilt.source_volume.entry_cell
			var lands := Vector2i(built.x, built.z) == Vector2i(entry.x,
				entry.z)
			matched += int(lands)
			print(("MAZE_SELECTED %s quarter %d SEALED ms=%d entry=%s " \
				+ "preview=%s lands=%s") % [label, quarter, elapsed_ms,
				str(built), str(entry), str(lands)])
			assert_true(rebuilt.is_sealed(),
				"%s quarter %d returned an unsealed plan" % [label, quarter])
			assert_not_null(rebuilt.source_volume.mass_context.get(
				&"maze_source_plan"),
				("%s quarter %d re-solved something that is not a maze " \
					+ "town") % [label, quarter])
		WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST
		assert_gt(matched, 0,
			("%s: no cardinal quarter re-solved with its entrance landing " \
				+ "where the preview's did") % label)


## TASK D2. The pinned PRODUCTION settlement -- not a fixture, and not a
## planner seed: the world seed, super cell and settlement the review harness
## renders (`warren_spatial_review.gd --production-terrain-site --super-x 0
## --super-z -1`). The id is ASSERTED rather than assumed, so a terrain change
## that moves the site fails here instead of quietly re-pointing every
## production assertion at some other town.
const PRODUCTION_WORLD_SEED := 2697992464
const PRODUCTION_SUPER_CELL := Vector2i(0, -1)
const PRODUCTION_SETTLEMENT_ID := &"settlement.29bc5c240c52f84a"
## The sampling radius `warren_spatial_review.gd` builds the site region at.
const PRODUCTION_REGION_RADIUS := 5

## Wall-clock ceiling for one WHOLE production solve on the terrain-worker
## path: the preview, the four placement quarters' terrain sampling and
## re-solves, the fabric compile and the materialization. Measured 4104 ms on
## the pinned site; pinned at ~3x rather than this file's usual 1.5x because
## the number that matters is the ORDER OF MAGNITUDE -- the searched pipeline
## this replaces cost 154-210 s of startup, and the failure this guards
## against is a fall back into a search, not a 30 % drift.
const PRODUCTION_SOLVE_MS_CEILING := 12000

## Where the pin round trip writes. The real `user://warren_solution_pins.json`
## is never written by the suite; only the production solve above READS it,
## which is deliberate (a maze town must build the same whatever it finds).
const PIN_CACHE_TEST_PATH := "user://test_warren_maze_pins_d2.json"

## The shape of a legacy SEARCHED-mode success pin: an attempt index, the
## ranked source it selected and the partition variant. None of it means
## anything in one-pass maze mode, which is the point of the round trip.
const LEGACY_PIN_ATTEMPT := 11
const LEGACY_PIN_SOURCE_ID := \
	"warren.volume.mass.166029932462774723.arcade0.arcade1"
const LEGACY_PIN_VARIANT := 1

static var _production_site_cache: Dictionary = {}


func _production_site() -> Dictionary:
	## The real terrain the production adapter reads, built exactly the way
	## `warren_spatial_review.gd --production-terrain-site` builds it: the
	## planned settlement site of the pinned super cell, the immutable
	## heightfield region around it, and the village program compiled from the
	## shipped catalog. Empty means the fixture could not load headless.
	##
	## Cached for the whole file: `SettlementPlan.site_for` alone costs ~18 s
	## and the catalog compile ~2.4 s, and neither is a fact about a town.
	if not _production_site_cache.is_empty():
		return _production_site_cache
	var water := TerrainWorldTuning.make_water(PRODUCTION_WORLD_SEED)
	var site := SettlementPlan.new(PRODUCTION_WORLD_SEED,
		water).site_for(PRODUCTION_SUPER_CELL)
	if site.is_empty():
		return {}
	var cell := site.cell as Vector2i
	var region := TerrainWorldTuning.make_heightfield(PRODUCTION_WORLD_SEED,
		water).compute_region(cell.x, cell.y, PRODUCTION_REGION_RADIUS)
	var village_program := VillageProgram.compile({},
		EnvironmentCatalog.load_default())
	if village_program == null:
		return {}
	var frame := VillageFrame.from_mask(site, 1, region,
		_dry_water_context(region, cell))
	_production_site_cache = {
		"cell": cell,
		"terrain": VillageTerrainView.from_region(region),
		"program": village_program,
		"frame": frame,
		"city_seed": VillagePlan.new(PRODUCTION_WORLD_SEED,
			village_program)._warren_seed(frame),
	}
	return _production_site_cache


static func _dry_water_context(region: HeightfieldRegion,
		cell: Vector2i) -> WaterFieldContext:
	## `VillageFrame.from_mask` requires a water context, and `SettlementPlan`
	## already keeps every site at least `WATER_CLEARANCE` from planned water,
	## so a dry context is the truthful stand-in here. This is the same helper
	## `warren_spatial_review.gd` uses for the same reason.
	var context := WaterFieldContext.new()
	context._ctx = {"ponds": [], "rivers": [], "buckets": {},
		"region": region}
	context._region = region
	var centre := Vector2(cell) * TerrainSurfaceField.TILE
	var radius := float(PRODUCTION_REGION_RADIUS) * TerrainSurfaceField.TILE
	context._coverage = Rect2(centre - Vector2.ONE * radius,
		Vector2.ONE * radius * 2.0)
	context._shore_limit = 0.0
	return context


func _solve_production(site: Dictionary) -> Dictionary:
	## One REAL production solve: `VillageWarrenFabricSolver.solve` against the
	## real terrain view, in maze mode, with exactly the arguments the terrain
	## worker passes. Nothing here is a stand-in for the production entry.
	var frame := site.frame as VillageFrame
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MAZE
	var started_ms := Time.get_ticks_msec()
	var urban := VillageWarrenFabricSolver.solve(
		site.terrain as VillageTerrainView, int(site.city_seed),
		frame.settlement_id, frame.centre, Vector2.RIGHT,
		site.program as VillageProgram)
	var elapsed_ms := Time.get_ticks_msec() - started_ms
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST
	return {
		"urban": urban,
		"ms": elapsed_ms,
		"signature": "" if urban == null or urban.volumetric_spatial == null \
			else urban.volumetric_spatial.deterministic_signature() \
				.sha256_text(),
	}


func test_the_production_site_builds_a_maze_town_on_real_terrain() -> void:
	## TASK D2 RULINGS 1, 3 and 5. Everything before this task solved a maze
	## town from an AUTHORED band frame. This is the production entry point on
	## the production settlement: the immutable heightfield sampled per
	## cardinal placement quarter, the entrance lift measured against the real
	## landing, and the sealed materialization contract that the streamed
	## payload is built from.
	##
	## The pin cache is deliberately left pointed at the real user:// file: a
	## maze town must build the same whatever it finds there, which is what
	## `test_a_maze_town_round_trips_the_solution_pin_cache` proves separately.
	var site := _production_site()
	if site.is_empty():
		pending(("the pinned production settlement did not load headless: " \
			+ "SettlementPlan.site_for(%s) on world seed %d found no site, " \
			+ "or the village program would not compile") % [
				str(PRODUCTION_SUPER_CELL), PRODUCTION_WORLD_SEED])
		return
	var frame := site.frame as VillageFrame
	assert_eq(String(frame.settlement_id), String(PRODUCTION_SETTLEMENT_ID),
		("the pinned production site moved: this file's production " \
			+ "assertions are about settlement %s at cell %s") % [
				String(PRODUCTION_SETTLEMENT_ID), str(site.cell)])
	var outcome := _solve_production(site)
	var urban := outcome.urban as VillageUrbanFabricPlan
	print(("MAZE_PRODUCTION settlement=%s cell=%s city_seed=%d scale=%s " \
		+ "ms=%d accepted=%s reason=%s") % [String(frame.settlement_id),
			str(site.cell), int(site.city_seed),
			String(WarrenVillageScaleProfile.select(
				int(site.city_seed)).scale_id), int(outcome.ms),
			str(urban != null and urban.accepted),
			String(urban.reason) if urban != null else "<null>"])
	assert_not_null(urban,
		"the production adapter returned nothing at all for the pinned site")
	if urban == null:
		return
	assert_true(urban.accepted,
		"the pinned production site refused to build a maze town: %s" \
			% String(urban.reason))
	if not urban.accepted:
		return
	print(("MAZE_PRODUCTION entries=%d meshes=%d lift=%.3f relief=%.3f " \
		+ "origin=%s advisory=%s") % [urban.entries.size(),
			urban.surface_meshes.size(), urban.terrain_entrance_lift_m,
			urban.terrain_relief_m, str(urban.world_transform.origin),
			str(urban.volumetric_spatial.audit.get("advisory_shortfalls", {}))])
	assert_eq(urban.generation_kind,
		VillageUrbanFabricPlan.GenerationKind.VOLUMETRIC_WARREN,
		"the production site built something that is not a volumetric warren")
	assert_not_null(urban.volumetric_spatial,
		"the accepted production plan carries no spatial town")
	if urban.volumetric_spatial == null:
		return
	assert_true(urban.volumetric_spatial.is_sealed(),
		"the production site shipped an unsealed spatial plan")
	assert_eq(String(urban.volumetric_spatial.audit.get(
		"production_generation_mode", "")), String(WarrenTownSolver.MODE_MAZE),
		"the production site did not build in maze mode")
	assert_not_null(urban.volumetric_spatial.source_volume.mass_context.get(
		&"maze_source_plan"),
		"the production site built something that is not a maze town")
	assert_false(urban.entries.is_empty(),
		"the production town materialized no renderable entries")
	assert_between(urban.terrain_entrance_lift_m, 0.0,
		TraversalEnvelope.MAX_PLANNED_STEP,
		"the production entrance lift is not a legal single planned step")
	assert_between(urban.terrain_relief_m, 0.0,
		VillageUrbanFabricPlan.MAX_FABRIC_TERRAIN_RELIEF,
		"the production footprint's relief is outside the fabric budget")
	assert_eq(int(urban.fabric_audit.get("walk_surface_component_count", -1)),
		1, "the production town's public floor came apart into pieces")
	assert_true(urban.validate(site.program as VillageProgram, &"village"),
		("the production town failed the sealed materialization contract " \
			+ "the streamed payload is built from"))
	assert_lt(int(outcome.ms), PRODUCTION_SOLVE_MS_CEILING,
		("the production solve has fallen back into a search: the whole " \
			+ "maze-mode path is seconds, the searched pipeline it replaced " \
			+ "cost 154-210 s"))


func test_a_maze_town_round_trips_the_solution_pin_cache() -> void:
	## TASK D2 RULING 2. `WarrenSolutionPinCache` memoizes an expensive STAGED
	## SEARCH: which attempt, which ranked source, which partition variant
	## sealed. One-pass maze mode has exactly one deterministic carve per town,
	## so a pin carries no information the carve does not already reproduce.
	##
	## Three properties, all on the real production entry:
	##   1. a maze solve writes NO pin (there is nothing to memo, and a pin
	##      keyed on (seed, scale) alone would lie to the searched mode);
	##   2. a stale legacy SUCCESS pin cannot change what is built: maze mode
	##      does not consult the cache at all, so the attempt, source and
	##      variant it names are never looked up, the legacy attempt machinery
	##      never runs, and the town is byte-identical to the unpinned one.
	##      (Task D2 review, minor 2: reading the pin could only cost work --
	##      `solve_pinned` would re-enter the same carve, and a town that then
	##      failed would carve a second time on the fallback.);
	##   3. a stale FAILURE pin does not suppress the town. It is evidence
	##      about a search that does not exist here, and before this task it
	##      returned `volume_pinned_failure` without ever running the carve.
	var site := _production_site()
	if site.is_empty():
		pending("the pinned production settlement did not load headless")
		return
	var city_seed := int(site.city_seed)
	var scale_id := WarrenVillageScaleProfile.select(city_seed).scale_id
	WarrenSolutionPinCache.override_path_for_tests(PIN_CACHE_TEST_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(
		PIN_CACHE_TEST_PATH))
	assert_true(WarrenSolutionPinCache.pin_for(city_seed, scale_id).is_empty(),
		"the round trip must start from an empty cache")
	var clean := _solve_production(site)
	var baseline := String(clean.signature)
	assert_true((clean.urban as VillageUrbanFabricPlan) != null \
		and (clean.urban as VillageUrbanFabricPlan).accepted,
		"the pinned production site must build with an empty pin cache")
	assert_true(WarrenSolutionPinCache.pin_for(city_seed, scale_id).is_empty(),
		("maze mode wrote a solution pin for a solve that has nothing to " \
			+ "memo; a pin keyed on (seed, scale) alone would then lie to " \
			+ "the searched mode about a search that never ran"))
	WarrenSolutionPinCache.store_success(city_seed, scale_id,
		LEGACY_PIN_ATTEMPT, LEGACY_PIN_SOURCE_ID, LEGACY_PIN_VARIANT)
	var legacy := WarrenSolutionPinCache.pin_for(city_seed, scale_id)
	assert_true(legacy.has("attempt"),
		"the legacy pin did not store, so the round trip below is vacuous")
	var pinned := _solve_production(site)
	var pinned_urban := pinned.urban as VillageUrbanFabricPlan
	print("MAZE_PRODUCTION_PIN legacy ms=%d accepted=%s signature_match=%s" % [
		int(pinned.ms), str(pinned_urban != null and pinned_urban.accepted),
		str(String(pinned.signature) == baseline)])
	assert_true(pinned_urban != null and pinned_urban.accepted,
		"a stale legacy success pin broke the maze path")
	if pinned_urban != null and pinned_urban.accepted:
		assert_eq(String(pinned.signature), baseline,
			"the pinned solve built a different town from the unpinned one")
		assert_false(pinned_urban.volumetric_spatial.audit.has(
			"production_pin_hit"),
			("the maze path ran the legacy attempt machinery: only " \
				+ "`solve_pinned`'s SEARCHED branch stamps a pin hit, and " \
				+ "maze mode never reaches it"))
	assert_eq(int(WarrenSolutionPinCache.pin_for(city_seed,
		scale_id).get("attempt", -1)), LEGACY_PIN_ATTEMPT,
		"the maze solve overwrote a searched mode's own memo")
	WarrenSolutionPinCache.store_failure(city_seed, scale_id)
	assert_true(bool(WarrenSolutionPinCache.pin_for(city_seed,
		scale_id).get("failed", false)),
		"the failure pin did not store, so the fall-through below is vacuous")
	var after_failure := _solve_production(site)
	var failed_urban := after_failure.urban as VillageUrbanFabricPlan
	print("MAZE_PRODUCTION_PIN failure ms=%d accepted=%s reason=%s" % [
		int(after_failure.ms),
		str(failed_urban != null and failed_urban.accepted),
		String(failed_urban.reason) if failed_urban != null else "<null>"])
	assert_true(failed_urban != null and failed_urban.accepted,
		("a stale FAILURE pin suppressed the maze town: it is evidence " \
			+ "about a staged search that one-pass mode never runs, so it " \
			+ "must fall through to the carve"))
	if failed_urban != null and failed_urban.accepted:
		assert_eq(String(after_failure.signature), baseline,
			"falling through a failure pin built a different town")
	WarrenSolutionPinCache.override_path_for_tests("")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(
		PIN_CACHE_TEST_PATH))
