class_name WarrenMassPruner
extends RefCounted

## Transaction boundary between provisional Gaussian mass and real construction
## opportunities.  It never changes the sealed public route or invents render
## geometry; it only classifies source mass relative to accepted parcels.


static func solve(source: WarrenVolumePlan,
		parcels: WarrenParcelPlan) -> WarrenPrunedMassPlan:
	if source == null or not source.is_sealed() or parcels == null \
			or not parcels.is_sealed() or parcels.source != source:
		return null
	var plan := WarrenPrunedMassPlan.new(
		StringName("%s.pruned" % source.stable_id), source, parcels)
	return plan if plan.seal() else null
