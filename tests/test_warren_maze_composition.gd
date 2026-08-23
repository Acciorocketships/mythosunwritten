extends GutTest

## MODE_MAZE end to end. Phase B built the one-pass plot planner; this is the
## first test that runs the real production entry point —
## `WarrenVolumetricSolver.solve()` with `GENERATION_MODE = MODE_MAZE` — over
## the four planner seeds and asks one question: did the town reach
## COMPOSITION?
##
## Reaching composition is the whole of Task C1. Most seeds are still expected
## to die INSIDE composition, at the hero-feature beam's skywalk floor, and
## that measured shortfall is the honest Phase C baseline rather than a defect
## this file may paper over. What must never happen again is a town dying
## BEFORE composition — at the massif, the carve, the volume adapter, or the
## translator that used to be handed a plot-free source. Those four are what
## the assertions here have teeth against.

## The seeds the plot planner is pinned on, split by the scale profile each is
## measured at. Fixed pairs rather than `WarrenVillageScaleProfile.select()`
## so this file exercises both profiles regardless of how a seed rolls.
const COMPACT_SEEDS: Array[int] = [12, 4]
const STANDARD_SEEDS: Array[int] = [3, 9]

## Every failure `_solve_maze` can write once the source and its translation
## have both succeeded. A town that died at one of these got as far as the
## composition — which is exactly what this task is asked to deliver.
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

static var _program_cache: SettlementFabricProgram


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


func _solve(world_seed: int, scale_id: StringName) -> Dictionary:
	## One real production solve. Reports the town (or null), the failure it
	## died with, and the wall clock — the three facts the baseline is made of.
	var profile := WarrenVillageScaleProfile.for_id(scale_id)
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MAZE
	var started_ms := Time.get_ticks_msec()
	var plan := WarrenVolumetricSolver.solve(world_seed, {}, _program(),
		profile)
	var elapsed_ms := Time.get_ticks_msec() - started_ms
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST
	return {
		"plan": plan,
		"ms": elapsed_ms,
		"failure": "" if plan != null else WarrenVolumetricSolver.last_failure,
	}


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


func _gate_of(failure: String) -> String:
	## The first dozen words of the failure — enough to name the gate a town
	## died at without pasting a whole diagnostic into the log.
	var words := failure.split(" ", false)
	var kept := PackedStringArray()
	for index in mini(12, words.size()):
		kept.append(words[index])
	return " ".join(kept)


func _assert_reaches_composition(world_seed: int,
		scale_id: StringName) -> void:
	var outcome := _solve(world_seed, scale_id)
	var failure := String(outcome.failure)
	var sealed := outcome.plan != null
	print("MAZE_COMPOSITION seed=%d scale=%s sealed=%s ms=%d %s" % [
		world_seed, String(scale_id), str(sealed), int(outcome.ms),
		"-" if sealed else failure.left(160)])
	var stage := _pre_composition_stage(failure)
	assert_eq(stage, "",
		"seed %d/%s died at the %s stage, before composition: %s" % [
			world_seed, String(scale_id), stage, failure.left(160)])
	if sealed:
		return
	assert_true(_names_a_composition_stage(failure),
		("seed %d/%s failed with a stage this file does not know; the gate " \
			+ "map is stale: %s") % [world_seed, String(scale_id),
			failure.left(160)])
	print("MAZE_COMPOSITION gate seed=%d scale=%s %s" % [world_seed,
		String(scale_id), _gate_of(failure)])


func test_maze_mode_reaches_composition() -> void:
	for world_seed: int in COMPACT_SEEDS:
		_assert_reaches_composition(world_seed,
			WarrenVillageScaleProfile.COMPACT)
	for world_seed: int in STANDARD_SEEDS:
		_assert_reaches_composition(world_seed,
			WarrenVillageScaleProfile.STANDARD)


func test_maze_mode_is_deterministic() -> void:
	## Two solves of one seed must agree cell for cell. Maze mode does not seal
	## any town yet (Task C2 opens the hero-feature gate), so until it does
	## there is no sealed signature to compare and this reports the reason it
	## skipped rather than passing on nothing.
	var first := _solve(12, WarrenVillageScaleProfile.COMPACT)
	var first_plan := first.plan as WarrenSpatialPlan
	if first_plan == null:
		var reason := String(first.failure).left(160)
		print("MAZE_COMPOSITION determinism skipped seed=12 scale=compact ",
			reason)
		pending("seed 12 compact does not seal yet: %s" % reason)
		return
	var repeated := _solve(12, WarrenVillageScaleProfile.COMPACT)
	var repeated_plan := repeated.plan as WarrenSpatialPlan
	assert_not_null(repeated_plan, String(repeated.failure).left(160))
	if repeated_plan == null:
		return
	assert_eq(first_plan.deterministic_signature(),
		repeated_plan.deterministic_signature(),
		"maze mode is a pure function of (seed, ground bands, scale profile)")
