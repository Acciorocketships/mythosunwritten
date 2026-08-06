class_name WarrenTownPlan
extends RefCounted

## One accepted volumetric town transaction. Stages remain inspectable, but
## consumers cannot accidentally combine a route from one attempt with parcels
## or surfaces from another.
# This is an inexpensive pre-detail viability gate.  The plan does not yet own
# stocked markets, exact outcroppings, occupied-link construction, or the final
# ray audit, so treating 55% as finished visual quality discarded otherwise
# complete candidates at 54.5% before their actual blockers could be measured.
# Final selection retains the stricter frontage, overhead, skywalk, and
# through-sightline targets in WarrenBuiltTownSolver.
const MIN_COMPOSED_WALK_ENCLOSURE_RATIO := 0.50
# Candidates at or above the former hard gate form the preferred exact-review
# tier. Near-threshold plans may fill unused review slots, but can never crowd a
# stronger preliminary composition out of the bounded asset frontier.
const PREFERRED_COMPOSED_WALK_ENCLOSURE_RATIO := 0.55
## Platform infill may bridge a narrow residual court. It may not conceal a
## failed parcel composition: a larger raw void would necessarily become a
## substantial uninhabited suspended platform when the vertical-shaft gate is
## applied. Reject it and let the bounded complete-plan search choose a town
## whose inhabited mass already divides the opening.
const MAX_RAW_DAYLIGHT_VOID_COMPONENT_SIZE := 4
var stable_id: StringName
var volume: WarrenVolumePlan
var parcels: WarrenParcelPlan
var pruning: WarrenPrunedMassPlan
var public_realm: SectionalPublicRealmPlan
var surfaces: PublicRealmSurfacePlan
var audit: Dictionary = {}
var last_rejection := ""
var _sealed := false


func _init(p_stable_id: StringName, p_volume: WarrenVolumePlan,
		p_parcels: WarrenParcelPlan, p_pruning: WarrenPrunedMassPlan,
		p_public_realm: SectionalPublicRealmPlan,
		p_surfaces: PublicRealmSurfacePlan) -> void:
	stable_id = p_stable_id
	volume = p_volume
	parcels = p_parcels
	pruning = p_pruning
	public_realm = p_public_realm
	surfaces = p_surfaces


func seal() -> bool:
	if _sealed or stable_id.is_empty() or volume == null \
			or not volume.is_sealed() or parcels == null \
			or not parcels.is_sealed() or parcels.source != volume \
			or pruning == null or not pruning.is_sealed() \
			or pruning.source != volume or pruning.parcels != parcels \
			or public_realm == null or not public_realm.is_sealed() \
			or surfaces == null or not surfaces.is_sealed() \
			or not public_realm.validate() or not surfaces.validate():
		last_rejection = "missing, invalid, or cross-attempt stage"
		return false
	var composed_enclosure := float(public_realm.audit.get(
		"composed_walk_enclosure_ratio", 0.0))
	if composed_enclosure < MIN_COMPOSED_WALK_ENCLOSURE_RATIO:
		last_rejection = "composed public route is too open (%.3f < %.3f)" % [
			composed_enclosure, MIN_COMPOSED_WALK_ENCLOSURE_RATIO]
		return false
	var raw_void_component := int(pruning.audit.get(
		"max_raw_daylight_void_component_size", 0))
	if raw_void_component > MAX_RAW_DAYLIGHT_VOID_COMPONENT_SIZE:
		last_rejection = ("raw urban void spans %d connected 3 m columns; " \
			+ "platform infill may not conceal failed building composition") % \
			raw_void_component
		return false
	var uncovered_core_columns := int(public_realm.audit.get(
		"uncovered_core_column_count", 0))
	var max_uncovered_component := int(public_realm.audit.get(
		"max_uncovered_core_component_size", 0))
	if uncovered_core_columns > 0 or max_uncovered_component > 0:
		last_rejection = ("urban core retains %d unclassified 3 m apertures " \
			+ "(largest component=%d infill=%d); only exact guarded 1.5 m " \
			+ "lightwells may look through to lower levels") % [
			uncovered_core_columns, max_uncovered_component,
			int(public_realm.audit.get("infill_platform_patch_count", 0))]
		return false
	# This is a useful coarse-lattice search signal, but not a validity gate.
	# Exact construction expands episodes, landings, and galleries onto the 1.5 m
	# public-realm lattice; only WarrenBuiltTownPlan can authoritatively bound the
	# resulting connected opening without rejecting a town that exact geometry
	# would divide.
	var uncovered_ground_component := int(public_realm.audit.get(
		"max_uncovered_ground_route_component_size", 2147483647))
	var surface_audit := surfaces.audit()
	audit = {
		"route_attempt": _attempt_from_id(volume.stable_id),
		"walk_cell_count": volume.audit.walk_cell_count,
		"elevation_band_count": volume.audit.elevation_band_count,
		"parcel_count": parcels.audit.parcel_count,
		"bounded_walk_ratio": parcels.audit.bounded_walk_ratio,
		"two_sided_walk_ratio": parcels.audit.two_sided_walk_ratio,
		"ground_primary_bounded_walk_ratio": parcels.audit.get(
			"ground_primary_bounded_walk_ratio", 0.0),
		"ground_primary_two_sided_walk_ratio": parcels.audit.get(
			"ground_primary_two_sided_walk_ratio", 0.0),
		"ground_arcade_bounded_walk_ratio": parcels.audit.get(
			"ground_arcade_bounded_walk_ratio", 0.0),
		"elevated_gallery_terminal_count": parcels.audit.get(
			"elevated_gallery_terminal_count", 0),
		"addressed_elevated_gallery_terminal_count": parcels.audit.get(
			"addressed_elevated_gallery_terminal_count", 0),
		"unaddressed_elevated_gallery_terminal_count": parcels.audit.get(
			"unaddressed_elevated_gallery_terminal_count", 0),
		"grounded_parcel_count": parcels.audit.get("grounded_parcel_count", 0),
		"half_level_neighbor_pair_count":
			parcels.audit.half_level_neighbor_pair_count,
		"footprint_family_count": parcels.audit.footprint_family_count,
		"parcel_footprint_cell_count": parcels.audit.get(
			"parcel_footprint_cell_count", 0),
		"transverse_parcel_count": parcels.audit.transverse_parcel_count,
		"visually_short_parcel_count": parcels.audit.get(
			"visually_short_parcel_count", 0),
		"stepped_roof_neighbor_pair_count": parcels.audit.get(
			"stepped_roof_neighbor_pair_count", 0),
		"tall_parcel_count": parcels.audit.get("tall_parcel_count", 0),
		"stepped_descent_tall_parcel_count": parcels.audit.get(
			"stepped_descent_tall_parcel_count", 0),
		"unstepped_tall_parcel_count": parcels.audit.get(
			"unstepped_tall_parcel_count", 0),
		"stacked_parcel_column_count": parcels.audit.stacked_parcel_column_count,
		"building_contact_component_count": parcels.audit.get(
			"building_contact_component_count", 0),
		"largest_building_contact_component_count": parcels.audit.get(
			"largest_building_contact_component_count", 0),
		"largest_building_contact_component_ratio": parcels.audit.get(
			"largest_building_contact_component_ratio", 0.0),
		"isolated_building_count": parcels.audit.get(
			"isolated_building_count", 0),
		"contacted_building_ratio": parcels.audit.get(
			"contacted_building_ratio", 0.0),
		"occupied_overpass_parcel_count": parcels.audit.occupied_overpass_parcel_count,
		"planned_skywalk_count": parcels.audit.planned_skywalk_count,
		"urban_core_open_column_ratio": parcels.audit.urban_core_open_column_ratio,
		"max_raw_daylight_void_component_size": raw_void_component,
		"composed_walk_enclosure_ratio": composed_enclosure,
		"infill_platform_patch_count": public_realm.audit.get(
			"infill_platform_patch_count", 0),
		"required_infill_platform_patch_count": public_realm.audit.get(
			"required_infill_platform_patch_count", 0),
		"optional_infill_platform_patch_count": public_realm.audit.get(
			"optional_infill_platform_patch_count", 0),
		"over_route_platform_patch_count": public_realm.audit.get(
			"over_route_platform_patch_count", 0),
		"infill_lightwell_count": public_realm.audit.get(
			"infill_lightwell_count", 0),
		"uncovered_core_column_count": uncovered_core_columns,
		"max_uncovered_core_component_size": max_uncovered_component,
		"uncovered_ground_route_cell_count": public_realm.audit.get(
			"uncovered_ground_route_cell_count", 0),
		"max_uncovered_ground_route_component_size":
			uncovered_ground_component,
		"served_entrance_count": surface_audit.served_entrance_count,
		"unserved_entrance_count": surface_audit.unserved_entrance_count,
		"transition_mesh_count": surface_audit.transition_mesh_count,
		"entrance_guard_conflict_count": surface_audit.entrance_guard_conflict_count,
		"structural_court_cell_count": surface_audit.structural_court_cell_count,
		"structural_court_interior_cell_count":
			surface_audit.structural_court_interior_cell_count,
		"exterior_public_interior_cell_count":
			surface_audit.exterior_public_interior_cell_count,
		"max_exterior_public_interior_component_size":
			surface_audit.max_exterior_public_interior_component_size,
		"public_walk_interior_cell_count":
			surface_audit.public_walk_interior_cell_count,
		"max_public_walk_interior_component_size":
			surface_audit.max_public_walk_interior_component_size,
	}
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func deterministic_signature() -> String:
	return "%s|%s" % [volume.deterministic_signature(),
		parcels.deterministic_signature()]


static func _attempt_from_id(value: StringName) -> int:
	var parts := String(value).split(".")
	for index in range(parts.size() - 1, -1, -1):
		if (parts[index] as String).is_valid_int():
			return int(parts[index])
	return -1
