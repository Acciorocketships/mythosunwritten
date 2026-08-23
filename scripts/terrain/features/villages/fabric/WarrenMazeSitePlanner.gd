class_name WarrenMazeSitePlanner
extends RefCounted

## One-pass entry point for the constructive maze-town pipeline: massif ->
## carve (unsealed) -> reserve (assets + decks) -> partition (houses, heights,
## bridges) -> seal. Every phase is pure and costs milliseconds, so
## `stop_after` simply re-runs the pipeline from scratch up to and including
## the named phase and hands back the still-unsealed plan; the debug view that
## wants a mid-pipeline snapshot calls plan() again with a different
## stop_after rather than this planner keeping any state of its own between
## calls.
const STOP_AFTER_STAGES: Array[StringName] = [
	&"carve", &"reserve", &"partition",
]

static var last_failure := ""


static func plan(world_seed: int, ground_bands: Dictionary,
		profile: WarrenVillageScaleProfile,
		stop_after: StringName = &"") -> WarrenMazeSourcePlan:
	last_failure = ""
	if stop_after != &"" and stop_after not in STOP_AFTER_STAGES:
		last_failure = "unknown stop_after stage %s" % String(stop_after)
		return null

	var massif := WarrenMassifBuilder.build(world_seed, ground_bands, profile)
	if massif == null:
		last_failure = "massif: %s" % WarrenMassifBuilder.last_failure
		return null

	var source_plan := WarrenMazeCarver.carve(world_seed, massif, profile,
		false)
	if source_plan == null:
		last_failure = "carve: %s" % WarrenMazeCarver.last_failure
		return null
	if stop_after == &"carve":
		return source_plan

	# The plot layer never fails: shortfalls are audit facts (rules become
	# repairs), so neither phase has a rejection path to translate here.
	WarrenPlotPlanner.reserve(source_plan, profile)
	if stop_after == &"reserve":
		return source_plan

	WarrenPlotPlanner.partition(source_plan, profile)
	if stop_after == &"partition":
		return source_plan

	if not source_plan.seal():
		last_failure = "seal: %s" % source_plan.last_rejection
		return null
	return source_plan
