class_name WarrenTownSolver
extends RefCounted

## The parcel stage of the one-pass maze pipeline.
##
## Houses are the solid a bore left standing, so they are partitioned rather
## than searched for: `WarrenMazeBlockPartitioner` reads the sealed maze source
## carried on the volume's `mass_context` and returns the town's parcels in one
## deterministic pass.
##
## THE RICHNESS-QUOTA POLICY, which used to live here as
## `feature_quotas_are_advisory()` and is recorded here because every solver
## downstream now applies it unconditionally: in a searched pipeline a quota
## shortfall was useful, because it discarded one candidate and the rotation
## supplied another. One-pass generation has no other candidate, so rejecting
## a fully partitioned 18-54 parcel town for owning no courtyard does not
## yield a better village — it yields NO village. Richness quotas (market,
## court, landmarks, links, balconies, outcroppings) are therefore audit facts
## at runtime, published in `WarrenVolumetricSolver.last_advisory_shortfalls`,
## and stay hard assertions in the test corpus where a regression must fail.
##
## This never relaxes STRUCTURAL correctness (unsupported rooms, floating
## geometry, doors onto air). Those remain fatal: shipping visibly broken
## construction is worse than shipping none.
##
## TASK F1 FIX 1 deleted the predicate itself: once every `not advisory` guard
## was removed it had no caller, and a caller-less constant is not a policy,
## it is dead code.

static var last_partition_failure := ""


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
