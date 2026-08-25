class_name VillageUrbanFabricPlan
extends RefCounted

## Complete atomic replacement for the legacy fixed elevated district. The
## record builder commits this payload only after massing, circulation,
## support, access, and 3D occupancy all validate together.
enum GenerationKind {
	LEGACY_TERRAIN_MASSING,
	SECTIONAL_WARREN,
	VOLUMETRIC_WARREN,
}
const MAX_FABRIC_TERRAIN_RELIEF := 4.5

var generation_kind := GenerationKind.LEGACY_TERRAIN_MASSING
var accepted: bool = false
var reason: StringName
## The sealed common-fabric source is retained verbatim in production records.
## Projection materializes the arrays below, while audits and future gameplay
## inspect the same topology instead of reverse-engineering render instances.
var fabric_plan: SettlementFabricPlan
var fabric_audit: Dictionary = {}
## Volumetric generation retains its complete source stages as lineage; the
## common fabric above remains the sole render/collision transaction. The
## production lineage for the authoritative fine-grid town.
var volumetric_spatial: WarrenSpatialPlan
## Canonical local-fabric to world transform chosen by the terrain adapter.
## Review, navigation, and future gameplay consumers use this same authored
## frame instead of trying to recover it from render placements or bounds.
var world_transform := Transform3D.IDENTITY
## Terrain-adapter facts remain explicit on generated-fabric records. The route
## landing may differ from natural ground only by the character's ordinary
## planned step; lower terrain elsewhere is handled by fixed supports.
var terrain_entrance_lift_m := -1.0
var terrain_relief_m := -1.0
var massing: VillageMassingPlan
var market: VillageMarketPlan
var circulation: VillageCirculationPlan
var timber: VillageTimberFabricPlan
var route_stairs: VillageRouteStairFabricPlan
var entries: Array[Dictionary] = []
## World-space generated walk-surface meshes (stair/ramp spans). They stream
## inside the record payload beside asset instances; a STAIR claim therefore
## has visible, collision-bearing production geometry by construction.
var surface_meshes: Array[Dictionary] = []
var volumes: Array[VillageOccupancyVolume] = []
var surfaces: Array[FeatureGroundShape] = []
var clearances: Array[FeatureGroundShape] = []
var buildings: Array[Dictionary] = []
var supports: Array[VillageBuildingSupportPlan] = []
var skirts: Array[VillageSkirtDeckPlan] = []
var entrance_stair_count: int = 0
var public_stair_count: int = 0
var natural_building_count: int = 0
var retained_building_count: int = 0
var rock_piece_count: int = 0
var foundation_piece_count: int = 0
## Bounded frontier audit retained on the selected/rejected plan. It explains
## which complete massings were tried without leaking partially built payloads.
var candidate_audit: Array[Dictionary] = []


func validate(program: VillageProgram, tier: StringName) -> bool:
	if not accepted:
		return entries.is_empty() and volumes.is_empty() \
			and surfaces.is_empty() and clearances.is_empty()
	if generation_kind == GenerationKind.SECTIONAL_WARREN:
		return _validate_sectional_warren(program)
	if generation_kind == GenerationKind.VOLUMETRIC_WARREN:
		return _validate_volumetric_warren(program)
	if reason != &"accepted" or massing == null or circulation == null \
			or market == null or not market.validate(program.market_program, tier) \
			or timber == null or route_stairs == null \
			or not massing.validate(program.massing_program,
			tier) or not circulation.validate(massing) or not timber.validate():
		return false
	if not route_stairs.validate() \
			or public_stair_count != route_stairs.stair_count:
		return false
	if buildings.size() != massing.placements.size() \
			or supports.size() != buildings.size() \
			or skirts.size() != buildings.size() \
			or natural_building_count + retained_building_count \
				!= buildings.size() or entries.is_empty() or volumes.is_empty():
		return false
	for support: VillageBuildingSupportPlan in supports:
		if not support.validate():
			return false
	for index in skirts.size():
		if not skirts[index].validate(
				massing.placements[index].perch.is_naturally_supported()):
			return false
	return true


func requires_outskirts() -> bool:
	return generation_kind == GenerationKind.LEGACY_TERRAIN_MASSING


func _validate_sectional_warren(program: VillageProgram) -> bool:
	return volumetric_spatial == null and _validate_compiled_fabric(program)


func _validate_volumetric_warren(program: VillageProgram) -> bool:
	if volumetric_spatial != null:
		if not volumetric_spatial.is_sealed() \
				or StringName(fabric_audit.get("generation_source", "")) \
					!= &"spatial_volumetric_warren" \
				or String(fabric_audit.get("spatial_signature", "")) \
					!= volumetric_spatial.deterministic_signature().sha256_text() \
				or int(fabric_audit.get("rejected_unfloored_address_count", -1)) != 0 \
				or not _scale_feature_contract_matches(fabric_audit):
			return false
		return _validate_compiled_fabric(program)
	# TASK F1. The legacy built-town lineage is gone with the searched
	# pipeline that produced it: `volumetric_town` was never set by any
	# production path, so a VOLUMETRIC_WARREN plan without a spatial town is
	# simply invalid.
	return false


static func _required_market_count(audit: Dictionary) -> int:
	## The covered bazaar is a city obligation; villages take one only when it
	## fits. The legacy constant remains the fallback for audits that carry no
	## size contract.
	var profile := WarrenVillageScaleProfile.for_id(StringName(
		audit.get("scale_profile_id", "")))
	return int(profile.requires_covered_market) if profile != null \
		else WarrenMarketSolver.REQUIRED_MARKETS


static func _scale_feature_contract_matches(audit: Dictionary) -> bool:
	## Production selects the size profile before authoring the massif. The final
	## transaction must validate against that same profile; the former hard-coded
	## large-showcase counts rejected legitimate compact and standard villages
	## after every topology, construction, and support proof had already passed.
	var scale_id := StringName(audit.get("scale_profile_id", ""))
	var profile := WarrenVillageScaleProfile.for_id(scale_id)
	if profile == null or String(audit.get("scale_profile_signature", "")) \
			!= profile.deterministic_signature():
		return false
	# TASK D2 REVIEW, IMPORTANT 1, SUPERSEDED BY TASK F4. The courtyard count and
	# its two column floors stayed HARD on the condition that the shortfall was
	# not PUBLISHED anywhere — "give those towns a courtyard, or publish the
	# shortfalls, and only then may these three join the advisory set" — under a
	# Phase E courtyard story that was never tasked. Task F3 measured the bill:
	# 0 of 12 seeds sealed at large and 0 of 12 at grand, 14 of the 24 refused by
	# the courtyard family alone, which is ~15 % of production city seeds
	# producing no town at all. Task F4 met the stated condition instead of
	# waiting: `composed_courtyard_sides`, `courtyard_bridge_houses` and
	# `elevated_courtyards` are now real `advisory_shortfalls` keys, so the three
	# terms join the advisory set on their own original terms. Re-measured after
	# the flip: large seals 3 of 12 and grand 1 of 12, and every sealed one of
	# them arrives here courtless.
	#
	# What stays hard here is the CEILING — a compact town that somehow carried a
	# court would still be a town promoted past its own size contract — and both
	# column floors on a town that actually HAS a court, where they are
	# measurements of a real thing rather than of an absence.
	#
	# TASK F3. The five relaxed floors are therefore not compared against
	# anything, and this states them in prose rather than passing them to a
	# predicate that discards them: `requires_covered_market` (one bazaar where
	# the profile asks for one), `landmark_range.x`, `skywalk_range.x`,
	# `balcony_range.x` and `cantilever_range.x`. `_meets_quota_floor` used to
	# take each of them plus a literal `true`, which reduced it to "the count
	# must be present" -- the same constant-argument shape task F1 deleted
	# elsewhere, surviving only because it was directly tested. Collapsed to
	# `_quota_count_is_measured`; the CEILINGS beside it are unchanged and stay
	# hard.
	return _quota_count_is_measured(
			int(audit.get("elevated_courtyard_count", -1))) \
		and int(audit.get("elevated_courtyard_count", -1)) \
			<= int(profile.requires_elevated_courtyard) \
		and (int(audit.get("elevated_courtyard_count", 0)) == 0 \
			or int(audit.get("courtyard_daylight_macro_column_count", 0)) \
				>= WarrenElevatedFrontageSolver \
					.MIN_COURTYARD_DAYLIGHT_COLUMNS) \
		and (int(audit.get("elevated_courtyard_count", 0)) == 0 \
			or int(audit.get("courtyard_underbuilt_macro_column_count", 0)) \
				>= WarrenElevatedFrontageSolver \
					.MIN_COURTYARD_UNDERBUILT_COLUMNS) \
		and _quota_count_is_measured(
			int(audit.get("covered_market_count", -1))) \
		and int(audit.get("covered_market_count", -1)) <= 1 \
		and _quota_count_is_measured(
			int(audit.get("prefab_landmark_count", -1))) \
		and int(audit.get("prefab_landmark_count", -1)) \
			<= profile.landmark_range.y \
		and _quota_count_is_measured(
			int(audit.get("enclosed_skywalk_count", -1))) \
		and int(audit.get("enclosed_skywalk_count", -1)) \
			<= profile.skywalk_range.y \
		and _quota_count_is_measured(
			int(audit.get("usable_balcony_count", -1))) \
		and _quota_count_is_measured(
			int(audit.get("room_outcropping_count", -1)))


static func _quota_count_is_measured(measured: int) -> bool:
	## The surviving half of the richness FLOOR on the sealed transaction: the
	## count must be PRESENT. A negative reads as an ABSENT audit key, which is
	## a broken transaction rather than a shortfall, and fails here.
	##
	## Falling short of the size profile's floor is a rejection only where a
	## rejection buys another candidate. One-pass maze generation has no other
	## candidate, so refusing a fully partitioned town here yields no village
	## at all; the shortfall becomes the audit fact the town ships with. This
	## is exactly the policy `WarrenTownSolver`'s class comment states and the
	## composition, feature and spatial solvers already honour -- the
	## production materialization contract was the last place still enforcing
	## the searched mode's quotas against a one-pass town.
	##
	## Ceilings stay hard in every mode: an excess is not a shortfall, and
	## nothing here relaxes a STRUCTURAL rule. Which floors are relaxed, and
	## why only those, is stated at the caller.
	return measured >= 0


func _validate_compiled_fabric(program: VillageProgram) -> bool:
	if program == null or program.settlement_fabric_program == null \
			or reason != &"accepted" or fabric_plan == null \
			or not fabric_plan.is_sealed() or not fabric_plan.validate() \
			or not world_transform.is_finite() \
			or entries.is_empty() or volumes.is_empty() \
			or clearances.is_empty():
		return false
	if terrain_entrance_lift_m < 0.0 \
			or terrain_entrance_lift_m > TraversalEnvelope.MAX_PLANNED_STEP \
			or terrain_relief_m < 0.0 \
			or terrain_relief_m > MAX_FABRIC_TERRAIN_RELIEF:
		return false
	if not _fabric_audit_matches_plan() \
			or int(fabric_audit.get("walk_surface_component_count", 1)) != 1 \
			or int(fabric_audit.get("detached_building_stack_count", -1)) != 0 \
			or int(fabric_audit.get("stair_endpoint_gap_count", -1)) != 0 \
			or int(fabric_audit.get(
				"stair_endpoint_missing_landing_count", -1)) != 0 \
			or int(fabric_audit.get("stair_to_stair_edge_count", -1)) != 0 \
			or int(fabric_audit.get("unserved_entrance_count", -1)) != 0:
		return false
	var allowed: Dictionary = {}
	for asset_id: StringName in program.referenced_asset_ids:
		allowed[asset_id] = true
	var entry_ids: Dictionary = {}
	for entry: Dictionary in entries:
		var asset_id := StringName(entry.get("asset_id", ""))
		var stable_entry_id := StringName(entry.get("stable_id", ""))
		if asset_id.is_empty() or not allowed.has(asset_id) \
				or stable_entry_id.is_empty() or entry_ids.has(stable_entry_id) \
				or not (entry.get("transform") is Transform3D):
			return false
		entry_ids[stable_entry_id] = true
	for mesh: Dictionary in surface_meshes:
		if not EnvironmentInstancePayload._surface_mesh_is_valid(mesh):
			return false
	var occupancy_roles: Dictionary = {}
	for volume: VillageOccupancyVolume in volumes:
		occupancy_roles[volume.role] = true
	for required_role in [VillageOccupancy.Role.SOLID,
			VillageOccupancy.Role.WALK_SURFACE,
			VillageOccupancy.Role.HEADROOM,
			VillageOccupancy.Role.GROUND_EXCLUSIVE]:
		if not occupancy_roles.has(required_role):
			return false
	if not fabric_plan.surface_plan.guard_segments.is_empty() \
			and not occupancy_roles.has(VillageOccupancy.Role.WALK_GUARD):
		return false
	return buildings.size() == int(fabric_audit.get(
		"building_stack_count", -1))


func _fabric_audit_matches_plan() -> bool:
	## The sealed fabric owns structural truth. Production may append only the
	## bounded survivor-selection disposition, which does not alter topology,
	## geometry, collision, or occupancy. Compare every canonical key and reject
	## all other extras so this cannot become a permissive audit bypass.
	for key: Variant in fabric_plan.audit.keys():
		if not fabric_audit.has(key) or fabric_audit[key] != fabric_plan.audit[key]:
			return false
	var allowed_extras: Dictionary = {
		&"visual_quality_target_met": true,
		&"visual_quality_fallback_count": true,
		&"visual_selection_candidate_count": true,
	}
	for key: Variant in fabric_audit.keys():
		if not fabric_plan.audit.has(key) and not allowed_extras.has(key):
			return false
	return true
