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
		last_diagnostic = {
			"unreachable_air_cells": result.unreachable_air_cells.duplicate(),
			"occupied_air_overlaps": result.occupied_air_overlaps.duplicate(),
		}
		return null
	return result
