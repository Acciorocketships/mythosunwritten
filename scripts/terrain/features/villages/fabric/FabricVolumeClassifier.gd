class_name FabricVolumeClassifier
extends RefCounted

## Proves the exterior profile from semantic planning cells. This service does
## not add floors, open holes, or reroute a failed composition.
static var last_failure := ""
static var last_diagnostic: Dictionary = {}


static func solve(stable_id: StringName, realm: SectionalPublicRealmPlan,
		fabric_plan: SettlementFabricPlan) -> FabricVolumePlan:
	last_failure = ""
	last_diagnostic = {}
	if stable_id.is_empty() or realm == null or not realm.is_sealed() \
			or fabric_plan == null:
		last_failure = "missing classifier input"
		return null
	if realm.air_realm != PublicRealmNode.AirRealm.EXTERIOR:
		last_failure = "interior public realms are disabled in the exterior profile"
		return null
	var result := FabricVolumePlan.new(stable_id)
	if not result.seal(realm.air_claims(), realm.landing_air_cells(),
			fabric_plan.transformed_cells(&"solid"),
			fabric_plan.transformed_cells(&"inhabited")):
		last_failure = result.last_rejection
		var structural_solids := fabric_plan.transformed_cells(&"solid")
		var inhabited_volume := fabric_plan.transformed_cells(&"inhabited")
		var air_claims := realm.air_claims()
		var overlap_records: Array[Dictionary] = []
		for cell: Vector3i in result.occupied_air_overlaps:
			overlap_records.append({
				"cell": cell,
				"air_owner": air_claims.get(cell, &""),
				"structural_owner": structural_solids.get(cell, &""),
				"inhabited_owner": inhabited_volume.get(cell, &""),
			})
		last_diagnostic = {
			"unreachable_air_cells": result.unreachable_air_cells.duplicate(),
			"occupied_air_overlaps": result.occupied_air_overlaps.duplicate(),
			"occupied_air_overlap_records": overlap_records,
		}
		return null
	return result
