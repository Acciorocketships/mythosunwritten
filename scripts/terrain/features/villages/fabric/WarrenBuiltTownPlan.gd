class_name WarrenBuiltTownPlan
extends RefCounted

## Final worker-safe composition currently used by the volumetric proof. It
## keeps the exact asset plan, the common fabric transaction, and the accepted
## inhabited overhead motifs together so review code cannot mix stages or seed
## identities.
## Reviewed relaxation (2026-08-05): the shallow-bay contract halves what one
## flank can honestly cover, so a one-sided edge street may keep a 2 x 8 fine
## cell opening that the old 3 m-deep bays used to roof from a single facade.
## Sixteen is that exact shape; larger roof-to-ground shafts remain rejected,
## and the change was reviewed against the pinned-settlement and seed-1
## captures rather than granted to pass a test.
const MAX_UNCOVERED_ROUTE_COMPONENT_SIZE := 16
var stable_id: StringName
var world_seed: int
var assets: WarrenAssetPlan
var fabric: SettlementFabricPlan
var overhead_candidates: Array[Dictionary] = []
var audit: Dictionary = {}
var last_rejection := ""
var _sealed := false


func _init(p_stable_id: StringName, p_world_seed: int,
		p_assets: WarrenAssetPlan, p_fabric: SettlementFabricPlan) -> void:
	stable_id = p_stable_id
	world_seed = p_world_seed
	assets = p_assets
	fabric = p_fabric


func seal(p_overhead_candidates: Array[Dictionary]) -> bool:
	if _sealed or stable_id.is_empty() or assets == null \
			or not assets.is_sealed() or fabric == null or not fabric.is_sealed() \
			or fabric.public_realm != assets.town.public_realm:
		return _reject("missing or cross-transaction construction stages")
	var ids: Dictionary = {}
	var skywalk_count := 0
	var outcrop_count := 0
	for candidate: Dictionary in p_overhead_candidates:
		var candidate_id := StringName(candidate.get("stable_id", ""))
		var category := StringName(candidate.get("category", ""))
		if candidate_id.is_empty() or ids.has(candidate_id) \
				or (category != &"skywalk" and category != &"outcrop"):
			return _reject("invalid or duplicate overhead candidate")
		ids[candidate_id] = true
		overhead_candidates.append(candidate.duplicate(true))
		skywalk_count += int(category == &"skywalk")
		outcrop_count += int(category == &"outcrop")
	if not fabric.visual_envelope_conflicts().is_empty():
		return _reject("sealed detailed fabric has visual conflicts")
	audit = fabric.audit.duplicate(true)
	for key: StringName in [
		&"roof_junction_count", &"perpendicular_roof_junction_count",
		&"joined_roof_count", &"isolated_roof_count",
		&"neighbor_pair_count", &"same_theme_neighbor_count",
		&"facade_family_count", &"largest_facade_family_count",
		&"largest_facade_family_ratio",
		&"same_streetscape_neighbor_count",
		&"same_roof_material_neighbor_count", &"roof_material_family_count",
		&"roof_geometry_family_count", &"roof_feature_count",
		&"facade_detail_count",
		&"largest_roof_material_family_count",
		&"largest_roof_material_family_ratio",
	]:
		audit[key] = assets.audit.get(key, 0)
	for key: StringName in [
		&"base_band_count", &"roof_band_count", &"largest_base_band_count",
		&"largest_roof_band_count", &"largest_roof_band_ratio",
		&"largest_base_band_ratio", &"neighboring_parcel_pair_count",
		&"same_base_neighbor_pair_count", &"same_base_neighbor_ratio",
		&"repeated_row_neighbor_pair_count", &"footprint_family_count",
		&"parcel_footprint_cell_count",
		&"tower_parcel_count", &"slim_parcel_count", &"square_parcel_count",
		&"long_parcel_count", &"largest_footprint_family_count",
		&"largest_footprint_family_ratio",
		&"half_level_neighbor_pair_count", &"stepped_roof_neighbor_pair_count",
		&"tall_parcel_count", &"stepped_descent_tall_parcel_count",
		&"unstepped_tall_parcel_count", &"grounded_parcel_count",
	]:
		audit[key] = assets.town.parcels.audit.get(key, 0)
	# The common fabric audit is authoritative. These selection counters retain
	# the bounded detail-search lineage without replacing the exact tag-derived
	# counts above.
	audit["selected_skywalk_count"] = skywalk_count
	audit["selected_outcropping_count"] = outcrop_count
	audit["skywalk_count"] = int(fabric.audit.get("skywalk_count", skywalk_count))
	audit["outcropping_count"] = outcrop_count
	audit["overhead_candidate_count"] = overhead_candidates.size()
	audit["final_unit_count"] = fabric.units.size()
	audit["final_placement_count"] = fabric.expanded_placements().size()
	audit["public_air_occupied_overlap_count"] = int(fabric.audit.get(
		"public_air_occupied_overlap_count", -1))
	audit["visual_envelope_conflict_count"] = \
		fabric.visual_envelope_conflicts().size()
	var max_uncovered_route_component := int(audit.get(
		"max_uncovered_route_component_size", 2147483647))
	if max_uncovered_route_component > MAX_UNCOVERED_ROUTE_COMPONENT_SIZE:
		return _reject(("detailed public realm retains an uncovered %d-cell " \
			+ "route component; exact construction may not expose a broad " \
			+ "roof-to-ground opening") % max_uncovered_route_component)
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func deterministic_signature() -> String:
	return "%s|%s" % [assets.deterministic_signature(),
		fabric.construction_signature()]


func _reject(reason: String) -> bool:
	last_rejection = reason
	return false
