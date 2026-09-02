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
	var air_claims := realm.air_claims()
	var structural_solids := fabric_plan.transformed_cells(&"solid")
	var reconciled_roof_cells := _reconcile_measured_roof_air(
		air_claims, structural_solids, realm, fabric_plan)
	if not result.seal(air_claims, realm.landing_air_cells(),
			structural_solids,
			fabric_plan.transformed_cells(&"inhabited")):
		last_failure = result.last_rejection
		var inhabited_volume := fabric_plan.transformed_cells(&"inhabited")
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
			"measured_roof_air_reconciliation_count": reconciled_roof_cells,
		}
		return null
	last_diagnostic = {
		"measured_roof_air_reconciliation_count": reconciled_roof_cells,
	}
	return result


static func _reconcile_measured_roof_air(air_claims: Dictionary,
		structural_solids: Dictionary, realm: SectionalPublicRealmPlan,
		fabric_plan: SettlementFabricPlan) -> int:
	## Public-air and roof solid cells are conservative topology bands. A gable at
	## a 3 m storey seam can share such a band with a 2.4 m passage without its
	## authored mesh entering the passage. Reconcile only roof-owned overlaps and
	## only after every measured placement clears every exact public walk prism;
	## inhabited volume and non-roof structure remain unconditional hard conflicts.
	var public_surfaces: Dictionary = {}
	for node_value: PublicRealmNode in realm.nodes:
		for cell: Vector3i in node_value.surface_cells:
			public_surfaces[cell] = true
	var safe_owner: Dictionary = {}
	var reconciled := 0
	var overlap_cells: Array[Vector3i] = []
	for cell_value: Variant in air_claims.keys():
		var cell := cell_value as Vector3i
		if structural_solids.has(cell):
			overlap_cells.append(cell)
	overlap_cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x)
	for cell: Vector3i in overlap_cells:
		var owner := StringName(structural_solids.get(cell, &""))
		if owner.is_empty():
			continue
		if not safe_owner.has(owner):
			safe_owner[owner] = _roof_owner_clears_public_surfaces(owner,
				public_surfaces, fabric_plan)
		if not bool(safe_owner[owner]):
			continue
		structural_solids.erase(cell)
		reconciled += 1
	return reconciled


static func _roof_owner_clears_public_surfaces(owner: StringName,
		public_surfaces: Dictionary,
		fabric_plan: SettlementFabricPlan) -> bool:
	var unit_value := fabric_plan.unit(owner)
	var recipe := fabric_plan.recipe(unit_value.recipe_id) \
		if unit_value != null else null
	if unit_value == null or recipe == null or not recipe.has_tag(&"roof"):
		return false
	var unit_transform := unit_value.transform()
	for placement_index in recipe.placement_bounds.size():
		var box: AABB = unit_transform * recipe.placement_bounds[placement_index]
		if not box.has_volume():
			continue
		for surface_value: Variant in public_surfaces.keys():
			var surface := surface_value as Vector3i
			var prism := TraversalEnvelope.clearance_prism(surface,
				FabricRecipe.CELL_SIZE)
			if _boxes_share_volume(box, prism):
				return false
	return true


static func _boxes_share_volume(left: AABB, right: AABB) -> bool:
	const EPSILON := 0.0001
	return left.end.x - right.position.x > EPSILON \
		and right.end.x - left.position.x > EPSILON \
		and left.end.y - right.position.y > EPSILON \
		and right.end.y - left.position.y > EPSILON \
		and left.end.z - right.position.z > EPSILON \
		and right.end.z - left.position.z > EPSILON
