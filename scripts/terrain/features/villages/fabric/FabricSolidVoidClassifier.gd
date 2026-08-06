class_name FabricSolidVoidClassifier
extends RefCounted

## Pure adapter that freezes solid/void obligations for one complete candidate.
## It intentionally records incomplete candidates: requirements and the future
## bounded embedder use the audit to reject them without special-case geometry.
static var last_failure := ""


static func solve(stable_id: StringName, realm: SectionalPublicRealmPlan,
		fabric_plan: SettlementFabricPlan) -> FabricSolidVoidPlan:
	last_failure = ""
	var result := FabricSolidVoidPlan.new(stable_id)
	if not result.seal(realm, fabric_plan):
		last_failure = "could not classify public boundary and occupied bands"
		return null
	return result
