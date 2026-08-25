class_name WarrenTownSolver
extends RefCounted

## The parcel stage of the one-pass maze pipeline.
##
## Houses are the solid a bore left standing, so they are partitioned rather
## than searched for: `WarrenMazeBlockPartitioner` reads the sealed maze source
## carried on the volume's `mass_context` and returns the town's parcels in one
## deterministic pass. What is left in this file is that stage plus the one
## policy question the stage's callers ask about it — whether a richness quota
## is advisory.

static var last_partition_failure := ""


static func feature_quotas_are_advisory() -> bool:
	## In a searched pipeline a quota shortfall was useful: it discarded one
	## candidate and the rotation supplied another. One-pass generation has no
	## other candidate, so rejecting a fully partitioned 18-54 parcel town for
	## owning no courtyard does not yield a better village — it yields NO
	## village. Richness quotas are therefore audit facts at runtime and stay
	## hard assertions in the test corpus, where a regression must still fail.
	##
	## This never relaxes STRUCTURAL correctness (unsupported rooms, floating
	## geometry, doors onto air). Those remain fatal: shipping visibly broken
	## construction is worse than shipping none.
	return true


static func partition_parcels(volume: WarrenVolumePlan) -> WarrenParcelPlan:
	## The maze parcel stage. The retired height solver is deliberately NOT run
	## over these houses — reassigning heights would flatten exactly the
	## terracing that makes this skyline vary by construction.
	last_partition_failure = ""
	if volume == null:
		last_partition_failure = "no volume to partition"
		return null
	var maze_source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if maze_source == null:
		last_partition_failure = "volume carries no maze source plan"
		return null
	var maze_plan := WarrenMazeBlockPartitioner.partition(maze_source, volume)
	if maze_plan == null:
		last_partition_failure = "maze block partition: %s" \
			% WarrenMazeBlockPartitioner.last_failure
	return maze_plan
