class_name WarrenBuiltTownSolver
extends RefCounted

## Bounded exact detail search for the volumetric city. The base maze and
## parcels are sealed first; every optional occupied overhead motif then has to
## survive a complete rebuild of the common fabric transaction.
## Streets should pass beneath occupied links often enough that a covered
## alley is the norm; five bounded bridges over a 10-16 building town stays
## far from a canopy field while doubling tunnel opportunities.
const MAX_SKYWALKS := 7
## Complete source-pack houses are admitted only where an exact unbounded
## public-realm obligation supplies their exterior threshold. They therefore
## tighten a street wall instead of becoming detached outskirts decoration.
## Two distinct source families are enough to break the generated-room rhythm
## without letting large prefab envelopes consume the compact warren.
const TARGET_PREFAB_ANCHORS := 2
# Tall stacks expose several independent upper-storey room sockets. A budget of
# eight left otherwise valid facades uniform in 15--18 building towns; twelve is
# still bounded, and every additional bay must pass the same exact occupied,
# roof, parent-bearing, public-air, and measured-envelope transaction.
const MAX_OUTCROPS := 12
const MIN_VISUAL_SURVIVORS := 2
const MAX_VISUAL_SURVIVORS := WarrenTownSolver.COMPOSED_PLAN_FRONTIER
const TARGET_FRONTAGE_RATIO := 0.28
# Route floors visible from directly overhead are the vertical equivalent of a
# see-through street. One or two ornamental bridges were enough to clear the
# former 12% gate while leaving a broad ground-level L visible in the core.
const TARGET_OVERHEAD_RATIO := 0.35
# A two-lane fine-grid route component of twelve cells is at most a short,
# turning three-module court. Larger connected components read as one continuous
# roof-to-ground shaft even when the town's average overhead ratio is healthy.
const TARGET_MAX_UNCOVERED_ROUTE_COMPONENT_SIZE := \
	WarrenBuiltTownPlan.MAX_UNCOVERED_ROUTE_COMPONENT_SIZE
const TARGET_SIGHTLINE_COUNT := 50
# Ground-to-ground chords are the closest deterministic analogue of the
# adversarial eye-level capture. Keep their budget much tighter than the global
# multi-level ray set: the latter legitimately includes glimpses across guarded
# elevated courts, while a lower street may not see out through both sides of
# the urban mass.
const TARGET_GROUND_SIGHTLINE_COUNT := 12
# A sightline can be hidden cheaply by deleting most of the town or covering the
# void with an empty court. Keep inhabited mass in the same coupled visual gate
# so the only successful solution is a route bounded by actual buildings.
const TARGET_BUILDING_STACK_COUNT := 10
# A raw prefab count rewards 1x1 towers and visually identical rows. Preserve
# actual urban density with the sum of sealed parcel footprints instead: the
# path remains bounded by inhabited mass, while 2x2 and 2x3 buildings are free
# to replace several repeated tower stamps.
const TARGET_MIN_PARCEL_FOOTPRINT_CELLS := 24
# Structural courts may be long, but they must remain gallery-like. Interior
# cells are the exact signature of a floor broader than the two-lane route; a
# small allowance preserves deliberate square facade courts without permitting
# the large empty upper plazas found by the screenshot review.
const TARGET_MAX_STRUCTURAL_COURT_INTERIOR_CELLS := 4
# The public floor is one construction union even when terrain streets and
# structural galleries meet. This companion gate prevents a broad mixed-kind
# plaza from hiding behind the narrower structural-only count.
const TARGET_MAX_EXTERIOR_PUBLIC_INTERIOR_COMPONENT_SIZE := 4
# The rendered floor union is the authoritative breadth metric. A long winding
# route may own several isolated one-cell inside corners, but neither their
# total nor one connected group may grow into the upper-level slab seen in the
# adversarial top-down capture.
const TARGET_MAX_PUBLIC_WALK_INTERIOR_CELLS := 34
const TARGET_MAX_PUBLIC_WALK_INTERIOR_COMPONENT_SIZE := 5
## "Many bands exist" is not enough when half the houses still share one
## datum.  These coupled limits reject a barracks-like dominant level/family
## even if its roofs were painted different colours after the fact.
const TARGET_MAX_LARGEST_BASE_BAND_RATIO := 0.50
const TARGET_MIN_ROOF_BAND_COUNT := 3
const TARGET_MAX_LARGEST_ROOF_BAND_RATIO := 0.60
const TARGET_MAX_SAME_BASE_NEIGHBOR_RATIO := 0.50
const TARGET_MAX_LARGEST_FOOTPRINT_FAMILY_RATIO := 0.45
const TARGET_MIN_FOOTPRINT_FAMILY_COUNT := 3
const TARGET_MIN_ROOF_MATERIAL_FAMILY_COUNT := 2
const TARGET_MIN_ROOF_GEOMETRY_FAMILY_COUNT := 3
const TARGET_MIN_ROOF_FEATURE_COUNT := 2
const TARGET_MIN_PERPENDICULAR_ROOF_JUNCTIONS := 1
const TARGET_MIN_FACADE_FAMILY_COUNT := 3
const TARGET_MAX_LARGEST_FACADE_FAMILY_RATIO := 0.50
const TARGET_MIN_OCCUPIED_OVERPASS_PARCELS := 2
const TARGET_MAX_LARGEST_ROOF_MATERIAL_FAMILY_RATIO := 0.70
# The street-level primary journey is the part of the maze most likely to read
# as an ordinary open road.  Global enclosure can hide that failure behind dense
# upper galleries, so exact visual selection owns explicit ground-route targets.
const TARGET_GROUND_PRIMARY_BOUNDED_RATIO := 0.55
const TARGET_GROUND_PRIMARY_TWO_SIDED_RATIO := 0.10
static var last_failure := ""
## Harness-facing trace of the bounded exact survivors considered by solve().
## Keeping this outside the sealed plan avoids making diagnostics part of the
## deterministic construction signature while still making visual-selection
## tradeoffs observable instead of guessing from the winning screenshot.
static var last_selection_diagnostic: Array[Dictionary] = []
static var last_candidate_failure_diagnostic: Array[Dictionary] = []
## Exact measured roofs and details can invalidate the widest optional gallery
## variant.  Preserve the bounded fallback trace so review artifacts show which
## surface budget survived instead of making a missing deck look mysterious.
static var last_infill_variant_diagnostic: Array[Dictionary] = []
## DIAGNOSTIC ONLY. The most detailed sealed fabric any candidate reached --
## skywalks, outcrops, markets, prefabs all admitted -- regardless of whether
## the visual-selection gates then accepted the town. A preview that compiles
## only the parcel fabric shows none of those phases and reads as a duller town
## than the pipeline actually builds, so this exists to let a harness render
## what the detail phases produced. It is never a claim of acceptance: read
## last_best_effort_failures alongside it, and never route a shipped town here.
static var last_best_effort_fabric: SettlementFabricPlan
static var last_best_effort_detail_count := 0
static var last_best_effort_failures := PackedStringArray()


static func solve(world_seed: int, program: SettlementFabricProgram,
		ground_bands: Dictionary = {}) -> WarrenBuiltTownPlan:
	last_failure = ""
	last_selection_diagnostic = []
	last_candidate_failure_diagnostic = []
	last_infill_variant_diagnostic = []
	if program == null:
		last_failure = "missing compiled construction vocabulary"
		return null
	var candidate_failures := PackedStringArray()
	var best: WarrenBuiltTownPlan
	var survivor_count := 0
	var attempted_towns: Dictionary = {}
	var expanded := false
	var towns := WarrenTownSolver.ranked_candidates(world_seed, ground_bands,
		program, WarrenTownSolver.COMPOSED_PLAN_FRONTIER)
	while true:
		for town: WarrenTownPlan in towns:
			var town_key := town.deterministic_signature()
			if attempted_towns.has(town_key):
				continue
			attempted_towns[town_key] = true
			var result := _solve_candidate(world_seed, program, town)
			if result == null:
				candidate_failures.append("attempt %d: %s" % [
					int(town.audit.route_attempt), last_failure])
				last_candidate_failure_diagnostic.append({
					"route_attempt": int(town.audit.route_attempt),
					"failure": last_failure,
				})
				continue
			survivor_count += 1
			last_selection_diagnostic.append(_selection_diagnostic(result))
			if best == null or _visual_candidate_better(result, best):
				best = result
			if survivor_count >= MIN_VISUAL_SURVIVORS \
					and not _has_severe_visual_failure(best.audit):
				break
			if survivor_count >= MAX_VISUAL_SURVIVORS:
				break
		if survivor_count >= MAX_VISUAL_SURVIVORS \
				or (survivor_count >= MIN_VISUAL_SURVIVORS and best != null \
					and not _has_severe_visual_failure(best.audit)):
			break
		# Most seeds find a strong town in the 32-plan construction pass. A seed
		# with no survivor (or only a severe sightline/overhead fallback) expands
		# to the old exhaustive frontier. This keeps the quality contract while
		# avoiding three quarters of the asset work on ordinary sites.
		if expanded:
			break
		expanded = true
		towns = WarrenTownSolver.ranked_candidates(world_seed, ground_bands,
			program, WarrenTownSolver.COMPOSED_PLAN_FRONTIER,
			WarrenTownSolver.MAX_ASSET_AWARE_PARCEL_FRONTIER)
	if best != null:
		best.audit["visual_quality_target_met"] = _meets_visual_targets(best.audit)
		best.audit["visual_quality_fallback_count"] = survivor_count
		best.audit["visual_selection_candidate_count"] = survivor_count
		last_failure = ""
		return best
	last_failure = "no ranked town survived exact construction: %s" % \
		" | ".join(candidate_failures)
	return null


static func _selection_diagnostic(candidate: WarrenBuiltTownPlan) -> Dictionary:
	return {
		"route_attempt": int(candidate.assets.town.audit.get(
			"route_attempt", -1)),
		"parcel_count": int(candidate.audit.get("building_stack_count", 0)),
		"parcel_footprint_cell_count": int(candidate.audit.get(
			"parcel_footprint_cell_count", 0)),
		"grounded_parcel_count": int(candidate.audit.get(
			"grounded_parcel_count", 0)),
		"tall_parcel_count": int(candidate.audit.get("tall_parcel_count", 0)),
		"unstepped_tall_parcel_count": int(candidate.audit.get(
			"unstepped_tall_parcel_count", 0)),
		"urban_core_open_column_ratio": float(candidate.audit.get(
			"urban_core_open_column_ratio", 1.0)),
		"ground_primary_bounded_walk_ratio": float(candidate.audit.get(
			"ground_primary_bounded_walk_ratio", 0.0)),
		"ground_primary_two_sided_walk_ratio": float(candidate.audit.get(
			"ground_primary_two_sided_walk_ratio", 0.0)),
		"frontage_ratio": float(candidate.audit.get("frontage_ratio", 0.0)),
		"overhead_route_ratio": float(candidate.audit.get(
			"overhead_route_ratio", 0.0)),
		"max_uncovered_route_component_size": int(candidate.audit.get(
			"max_uncovered_route_component_size", 2147483647)),
		"through_sightline_count": int(candidate.audit.get(
			"through_sightline_count", 2147483647)),
		"ground_through_sightline_count": int(candidate.audit.get(
			"ground_through_sightline_count", 2147483647)),
		"structural_court_interior_cell_count": int(candidate.audit.get(
			"structural_court_interior_cell_count", 2147483647)),
		"exterior_public_interior_cell_count": int(candidate.audit.get(
			"exterior_public_interior_cell_count", 2147483647)),
		"max_exterior_public_interior_component_size": int(candidate.audit.get(
			"max_exterior_public_interior_component_size", 2147483647)),
		"public_walk_interior_cell_count": int(candidate.audit.get(
			"public_walk_interior_cell_count", 2147483647)),
		"max_public_walk_interior_component_size": int(candidate.audit.get(
			"max_public_walk_interior_component_size", 2147483647)),
		"largest_base_band_ratio": float(candidate.audit.get(
			"largest_base_band_ratio", 1.0)),
		"same_base_neighbor_ratio": float(candidate.audit.get(
			"same_base_neighbor_ratio", 1.0)),
		"largest_footprint_family_ratio": float(candidate.audit.get(
			"largest_footprint_family_ratio", 1.0)),
		"footprint_family_count": int(candidate.audit.get(
			"footprint_family_count", 0)),
		"roof_material_family_count": int(candidate.audit.get(
			"roof_material_family_count", 0)),
		"roof_geometry_family_count": int(candidate.audit.get(
			"roof_geometry_family_count", 0)),
		"roof_feature_count": int(candidate.audit.get("roof_feature_count", 0)),
		"perpendicular_roof_junction_count": int(candidate.audit.get(
			"perpendicular_roof_junction_count", 0)),
		"facade_family_count": int(candidate.audit.get(
			"facade_family_count", 0)),
		"largest_facade_family_ratio": float(candidate.audit.get(
			"largest_facade_family_ratio", 1.0)),
		"largest_roof_material_family_ratio": float(candidate.audit.get(
			"largest_roof_material_family_ratio", 1.0)),
		"skywalk_link_count": int(candidate.audit.get("skywalk_link_count", 0)),
		"occupied_overpass_parcel_count": int(candidate.audit.get(
			"occupied_overpass_parcel_count", 0)),
		"target_violation": _visual_target_violation(candidate.audit),
		"quality_score": _visual_quality_score(candidate.audit),
	}


static func solve_attempt(world_seed: int, attempt: int,
		program: SettlementFabricProgram,
		ground_bands: Dictionary = {}) -> WarrenBuiltTownPlan:
	last_failure = ""
	last_infill_variant_diagnostic = []
	if program == null:
		last_failure = "missing compiled construction vocabulary"
		return null
	var town := WarrenTownSolver.solve_attempt(world_seed, attempt,
		ground_bands, program)
	if town == null:
		last_failure = WarrenTownSolver.last_failure
		return null
	return _solve_candidate(world_seed, program, town)


static func _solve_candidate(world_seed: int, program: SettlementFabricProgram,
		town: WarrenTownPlan) -> WarrenBuiltTownPlan:
	var failures := PackedStringArray()
	var diagnostics: Array[Dictionary] = []
	var best: WarrenBuiltTownPlan
	for variant: WarrenTownPlan in WarrenTownSolver.infill_variants(town):
		var result := _solve_candidate_variant(world_seed, program, variant)
		if result != null:
			diagnostics.append({
				"optional_infill_limit_result": int(variant.audit.get(
					"optional_infill_platform_patch_count", 0)),
				"total_infill_patch_count": int(variant.audit.get(
					"infill_platform_patch_count", 0)),
				"accepted": true,
				"frontage_ratio": float(result.audit.get(
					"frontage_ratio", 0.0)),
				"overhead_route_ratio": float(result.audit.get(
					"overhead_route_ratio", 0.0)),
				"max_uncovered_route_component_size": int(result.audit.get(
					"max_uncovered_route_component_size", 2147483647)),
				"through_sightline_count": int(result.audit.get(
					"through_sightline_count", 2147483647)),
			})
			best = result
			# Infill variants are ordered from leanest to broadest. Once the exact
			# construction transaction proves route continuity, entrances, supports,
			# guards, headroom, and the uncovered-component ceiling, another empty
			# platform is not a different town topology: it is strictly more floor in
			# the negative space which ought to remain a street or guarded lightwell.
			# Stop at the first survivor so an optional deck can never buy frontage or
			# overhead-score credit and defeat an already complete narrower maze.
			break
		diagnostics.append({
			"optional_infill_limit_result": int(variant.audit.get(
				"optional_infill_platform_patch_count", 0)),
			"total_infill_patch_count": int(variant.audit.get(
				"infill_platform_patch_count", 0)),
			"accepted": false,
			"failure": last_failure,
			"volume_diagnostic": FabricVolumeClassifier.last_diagnostic.duplicate(
				true),
		})
		failures.append("optional-infill=%d: %s" % [int(variant.audit.get(
			"optional_infill_platform_patch_count", 0)), last_failure])
	last_infill_variant_diagnostic = diagnostics
	if best != null:
		last_failure = ""
		return best
	last_failure = "no exact optional-infill variant survived: %s" % \
		" | ".join(failures)
	return null


static func _solve_candidate_variant(world_seed: int,
		program: SettlementFabricProgram,
		town: WarrenTownPlan) -> WarrenBuiltTownPlan:
	var assets := WarrenAssetCompiler.solve(town, program)
	if assets == null:
		last_failure = WarrenAssetCompiler.last_failure
		return null
	var fabric := WarrenFabricCompiler.solve(assets)
	if fabric == null:
		last_failure = WarrenFabricCompiler.last_failure
		return null
	var accepted: Array[Dictionary] = []
	var accepted_specs: Array[Dictionary] = []
	var used_candidates: Dictionary = {}
	var used_sources: Dictionary = {}
	# A parcel-stage corridor is an occupied construction fact, not a soft score.
	# Realize that exact bridge before considering any other detail so later
	# projections cannot consume its sockets or envelope.
	for reservation: Dictionary in town.parcels.connection_reservations:
		var planned_candidate: Dictionary = {}
		for candidate: Dictionary in WarrenOverheadSolver.candidate_specs(
				program, fabric, world_seed, false):
			if StringName(candidate.category) == &"skywalk" \
					and _candidate_matches_reservation(candidate, reservation):
				planned_candidate = candidate
				break
		if planned_candidate.is_empty():
			last_failure = "planned occupied-link corridor has no exact candidate"
			return null
		var planned_specs: Array[Dictionary] = []
		planned_specs.assign(accepted_specs)
		for spec: Dictionary in planned_candidate.specs as Array:
			planned_specs.append(spec)
		var planned_trial := WarrenFabricCompiler.solve(assets, planned_specs)
		if planned_trial == null:
			last_failure = "planned occupied link failed exact transaction: %s" % \
				WarrenFabricCompiler.last_failure
			return null
		accepted.append(planned_candidate)
		accepted_specs = planned_specs
		fabric = planned_trial
		used_candidates[StringName(planned_candidate.stable_id)] = true
		for source_id: Variant in planned_candidate.get("source_ids", []):
			used_sources[StringName(source_id)] = true
	var pre_outcrop_fabric := fabric
	var pre_outcrop_specs: Array[Dictionary] = []
	pre_outcrop_specs.assign(accepted_specs)
	var pre_outcrop_accepted: Array[Dictionary] = []
	pre_outcrop_accepted.assign(accepted)
	var pre_outcrop_used_candidates := used_candidates.duplicate()
	var pre_outcrop_used_sources := used_sources.duplicate()
	# Preserve one roof-integrated facade projection before ground furnishing.
	# Market variants are then selected around the actual occupied bridge and bay,
	# so neither optional layer can erase the other's construction envelope. A
	# bay first uses a facade that cannot participate in another inhabited bridge;
	# consuming the only remaining bridge socket merely to satisfy outcrop variety
	# leaves a decorative town with one long roof-to-ground route opening.
	var required_outcrop_admitted := false
	var initial_candidates := WarrenOverheadSolver.candidate_specs(
		program, fabric, world_seed)
	var possible_skywalk_sources: Dictionary = {}
	for candidate: Dictionary in initial_candidates:
		if StringName(candidate.category) != &"skywalk":
			continue
		for source_id: Variant in candidate.get("source_ids", []):
			possible_skywalk_sources[StringName(source_id)] = true
	for preserve_skywalk_source: bool in [true, false]:
		for candidate: Dictionary in initial_candidates:
			if StringName(candidate.category) != &"outcrop" \
					or _uses_reserved_source(candidate, used_sources) \
					or (preserve_skywalk_source \
						and _uses_reserved_source(candidate,
							possible_skywalk_sources)):
				continue
			var outcrop_specs: Array[Dictionary] = []
			outcrop_specs.assign(accepted_specs)
			for spec: Dictionary in candidate.specs as Array:
				outcrop_specs.append(spec)
			var outcrop_trial := WarrenFabricCompiler.solve(assets, outcrop_specs)
			if outcrop_trial == null:
				continue
			accepted.append(candidate)
			accepted_specs = outcrop_specs
			fabric = outcrop_trial
			used_candidates[StringName(candidate.stable_id)] = true
			for source_id: Variant in candidate.get("source_ids", []):
				used_sources[StringName(source_id)] = true
			required_outcrop_admitted = true
			break
		if required_outcrop_admitted:
			break
	var market_result := _admit_markets(assets, program, town, fabric,
		accepted_specs, world_seed)
	if not bool(market_result.accepted) and required_outcrop_admitted:
		# A facade bay is preferred, not allowed to erase the ground market. Roll
		# back that one optional motif and rebuild the markets from the exact
		# parcel-reserved bridge transaction.
		fabric = pre_outcrop_fabric
		accepted_specs = pre_outcrop_specs
		accepted = pre_outcrop_accepted
		used_candidates = pre_outcrop_used_candidates
		used_sources = pre_outcrop_used_sources
		required_outcrop_admitted = false
		market_result = _admit_markets(assets, program, town, fabric,
			accepted_specs, world_seed)
	if not bool(market_result.accepted):
		last_failure = String(market_result.failure)
		return null
	fabric = market_result.fabric as SettlementFabricPlan
	accepted_specs.assign(market_result.specs as Array)
	var prefab_result := _admit_prefabs(assets, program, fabric,
		accepted_specs, world_seed)
	fabric = prefab_result.fabric as SettlementFabricPlan
	accepted_specs.assign(prefab_result.specs as Array)
	# One roofed facade bay was already attempted before the market, so remaining
	# compatible room sockets first extend the inhabited bridge network. Filling
	# every source with another shallow bay before trying skywalks produced one
	# decorative bridge and one long uncovered lower street—the exact opposite of
	# the connected multi-level city contract. Additional outcrops consume only
	# sources left after the bounded bridge pass.
	# Facade projections create new inhabited room sockets, so overhead assembly
	# is a small monotone grammar rather than two unrelated decoration passes:
	# join the base masses, articulate the surviving facades, then give those new
	# endpoints one bounded chance to close another occupied link.  Every step is
	# still rebuilt through the same exact transaction.
	for phase: StringName in [&"skywalk", &"outcrop", &"skywalk"]:
		var limit := MAX_SKYWALKS if phase == &"skywalk" else MAX_OUTCROPS
		while _count_category(accepted, phase) < limit:
			var admitted := false
			for candidate: Dictionary in WarrenOverheadSolver.candidate_specs(
					program, fabric, world_seed):
				# A bay consumes its whole building column: the stack prefix in
				# its source ids keeps a second jetty off the same stack, and a
				# facade that already ends a bridge stays a bridge facade.
				if StringName(candidate.category) != phase \
						or used_candidates.has(StringName(candidate.stable_id)) \
						or (phase == &"outcrop" \
							and _uses_reserved_source(candidate, used_sources)):
					continue
				var trial_specs: Array[Dictionary] = []
				trial_specs.assign(accepted_specs)
				for spec: Dictionary in candidate.specs as Array:
					trial_specs.append(spec)
				var trial := WarrenFabricCompiler.solve(assets, trial_specs)
				if trial == null:
					used_candidates[StringName(candidate.stable_id)] = true
					continue
				accepted.append(candidate)
				accepted_specs = trial_specs
				fabric = trial
				for source_id: Variant in candidate.get("source_ids", []):
					used_sources[StringName(source_id)] = true
				admitted = true
				break
			if not admitted:
				break
	var result := WarrenBuiltTownPlan.new(
		StringName("warren.built.%d" % world_seed), world_seed, assets, fabric)
	_record_best_effort(fabric, accepted)
	if not result.seal(accepted):
		last_failure = "%s (skywalks=%d outcrops=%d overhead=%.3f uncovered=%s)" % [
			result.last_rejection, _count_category(accepted, &"skywalk"),
			_count_category(accepted, &"outcrop"),
			float(fabric.audit.get("overhead_route_ratio", 0.0)),
			fabric.audit.get("max_uncovered_route_component_cells", [])]
		last_best_effort_failures.append(last_failure)
		return null
	return result


static func _record_best_effort(fabric: SettlementFabricPlan,
		accepted: Array[Dictionary]) -> void:
	## Read-only bookkeeping on the accepted path: it records the candidate that
	## admitted the most detail so a diagnostic harness has something to draw,
	## and cannot influence selection, ordering, or any audit.
	if fabric == null or not fabric.is_sealed():
		return
	if last_best_effort_fabric != null \
			and accepted.size() <= last_best_effort_detail_count:
		return
	last_best_effort_fabric = fabric
	last_best_effort_detail_count = accepted.size()


static func diagnostic_best_effort(world_seed: int,
		program: SettlementFabricProgram,
		ground_bands: Dictionary = {}) -> Dictionary:
	## DIAGNOSTIC ONLY -- NEVER a claim that a town passes. Runs the ordinary
	## per-candidate construction, and when the visual-selection gates reject a
	## candidate it hands back the detailed fabric those gates saw together with
	## the reason they refused it. A harness can then show the town the detail
	## phases actually built instead of the bare parcel compile.
	##
	## It stops at the FIRST candidate that reaches the gates rather than calling
	## solve(), because solve() only exits early on a survivor: a town type the
	## gates always reject therefore pays for the whole exhaustive frontier with
	## full detail assembly on every candidate, which is tens of minutes. A
	## preview needs one town, not the best of thirty-two. That also means this
	## deliberately does NOT pick the best candidate and must never be mistaken
	## for selection.
	last_best_effort_fabric = null
	last_best_effort_detail_count = 0
	last_best_effort_failures = PackedStringArray()
	for town: WarrenTownPlan in WarrenTownSolver.ranked_candidates(world_seed,
			ground_bands, program, WarrenTownSolver.COMPOSED_PLAN_FRONTIER):
		var plan := _solve_candidate(world_seed, program, town)
		if plan != null:
			return {
				"fabric": plan.fabric,
				"detail_count": plan.overhead_candidates.size(),
				"selected": true,
				"gate_failures": PackedStringArray(),
			}
		if last_best_effort_fabric != null:
			break
	return {
		"fabric": last_best_effort_fabric,
		"detail_count": last_best_effort_detail_count,
		"selected": false,
		"gate_failures": last_best_effort_failures,
	}


static func _candidate_matches_reservation(candidate: Dictionary,
		reservation: Dictionary) -> bool:
	var specs := candidate.get("specs", []) as Array
	var components := reservation.get("components", []) as Array
	if specs.size() != components.size():
		return false
	var unmatched: Array[Dictionary] = []
	for component: Dictionary in components:
		unmatched.append(component)
	for spec_value: Variant in specs:
		var spec := spec_value as Dictionary
		var found := -1
		for index in unmatched.size():
			var component := unmatched[index]
			if StringName(spec.get("recipe_id", "")) \
					== StringName(component.get("recipe_id", "")) \
					and (spec.get("origin", Vector3i()) as Vector3i) \
						== (component.get("origin", Vector3i()) as Vector3i) \
					and int(spec.get("yaw_quarters", -1)) \
						== int(component.get("yaw_quarters", -2)):
				found = index
				break
		if found < 0:
			return false
		unmatched.remove_at(found)
	return unmatched.is_empty()


static func _uses_reserved_source(candidate: Dictionary,
		used_sources: Dictionary) -> bool:
	for source_id: Variant in candidate.get("source_ids", []):
		if used_sources.has(StringName(source_id)):
			return true
	return false


static func _count_category(candidates: Array[Dictionary],
		category: StringName) -> int:
	var result := 0
	for candidate: Dictionary in candidates:
		result += int(StringName(candidate.category) == category)
	return result


static func _meets_visual_targets(audit: Dictionary) -> bool:
	return float(audit.get("frontage_ratio", 0.0)) >= TARGET_FRONTAGE_RATIO \
		and float(audit.get("ground_primary_bounded_walk_ratio", 0.0)) \
			>= TARGET_GROUND_PRIMARY_BOUNDED_RATIO \
		and float(audit.get("ground_primary_two_sided_walk_ratio", 0.0)) \
			>= TARGET_GROUND_PRIMARY_TWO_SIDED_RATIO \
		and float(audit.get("overhead_route_ratio", 0.0)) \
			>= TARGET_OVERHEAD_RATIO \
		and int(audit.get("max_uncovered_route_component_size", 2147483647)) \
			<= TARGET_MAX_UNCOVERED_ROUTE_COMPONENT_SIZE \
		and int(audit.get("through_sightline_count", 2147483647)) \
			<= TARGET_SIGHTLINE_COUNT \
		and int(audit.get("ground_through_sightline_count", 2147483647)) \
			<= TARGET_GROUND_SIGHTLINE_COUNT \
		and int(audit.get("unstepped_tall_parcel_count", 2147483647)) == 0 \
		and int(audit.get("building_stack_count", 0)) \
			>= TARGET_BUILDING_STACK_COUNT \
		and int(audit.get("parcel_footprint_cell_count", 0)) \
			>= TARGET_MIN_PARCEL_FOOTPRINT_CELLS \
		and int(audit.get("structural_court_interior_cell_count", 2147483647)) \
			<= TARGET_MAX_STRUCTURAL_COURT_INTERIOR_CELLS \
		and int(audit.get("max_exterior_public_interior_component_size", \
			2147483647)) <= TARGET_MAX_EXTERIOR_PUBLIC_INTERIOR_COMPONENT_SIZE \
		and int(audit.get("public_walk_interior_cell_count", 2147483647)) \
			<= TARGET_MAX_PUBLIC_WALK_INTERIOR_CELLS \
		and int(audit.get("max_public_walk_interior_component_size", \
			2147483647)) <= TARGET_MAX_PUBLIC_WALK_INTERIOR_COMPONENT_SIZE \
		and float(audit.get("largest_base_band_ratio", 1.0)) \
			<= TARGET_MAX_LARGEST_BASE_BAND_RATIO \
		and int(audit.get("roof_band_count", 0)) >= TARGET_MIN_ROOF_BAND_COUNT \
		and float(audit.get("largest_roof_band_ratio", 1.0)) \
			<= TARGET_MAX_LARGEST_ROOF_BAND_RATIO \
		and float(audit.get("same_base_neighbor_ratio", 1.0)) \
			<= TARGET_MAX_SAME_BASE_NEIGHBOR_RATIO \
		and float(audit.get("largest_footprint_family_ratio", 1.0)) \
			<= TARGET_MAX_LARGEST_FOOTPRINT_FAMILY_RATIO \
		and int(audit.get("footprint_family_count", 0)) \
			>= TARGET_MIN_FOOTPRINT_FAMILY_COUNT \
		and int(audit.get("roof_material_family_count", 0)) \
			>= TARGET_MIN_ROOF_MATERIAL_FAMILY_COUNT \
		and int(audit.get("roof_geometry_family_count", 0)) \
			>= TARGET_MIN_ROOF_GEOMETRY_FAMILY_COUNT \
		and int(audit.get("roof_feature_count", 0)) \
			>= TARGET_MIN_ROOF_FEATURE_COUNT \
		and int(audit.get("perpendicular_roof_junction_count", 0)) \
			>= TARGET_MIN_PERPENDICULAR_ROOF_JUNCTIONS \
		and int(audit.get("facade_family_count", 0)) \
			>= TARGET_MIN_FACADE_FAMILY_COUNT \
		and float(audit.get("largest_facade_family_ratio", 1.0)) \
			<= TARGET_MAX_LARGEST_FACADE_FAMILY_RATIO \
		and float(audit.get("largest_roof_material_family_ratio", 1.0)) \
			<= TARGET_MAX_LARGEST_ROOF_MATERIAL_FAMILY_RATIO \
		and int(audit.get("occupied_overpass_parcel_count", 0)) \
			>= TARGET_MIN_OCCUPIED_OVERPASS_PARCELS \
		and int(audit.get("repeated_row_neighbor_pair_count", 2147483647)) == 0 \
		and int(audit.get("skywalk_link_count", 0)) >= 2


static func _has_severe_visual_failure(audit: Dictionary) -> bool:
	return float(audit.get("ground_primary_bounded_walk_ratio", 0.0)) \
			< TARGET_GROUND_PRIMARY_BOUNDED_RATIO \
		or float(audit.get("overhead_route_ratio", 0.0)) \
			< TARGET_OVERHEAD_RATIO \
		or int(audit.get("max_uncovered_route_component_size", 2147483647)) \
			> TARGET_MAX_UNCOVERED_ROUTE_COMPONENT_SIZE \
		or int(audit.get("through_sightline_count", 2147483647)) \
			> TARGET_SIGHTLINE_COUNT \
		or int(audit.get("ground_through_sightline_count", 2147483647)) \
			> TARGET_GROUND_SIGHTLINE_COUNT \
		or int(audit.get("unstepped_tall_parcel_count", 2147483647)) > 0 \
		or int(audit.get("building_stack_count", 0)) \
			< TARGET_BUILDING_STACK_COUNT \
		or int(audit.get("parcel_footprint_cell_count", 0)) \
			< TARGET_MIN_PARCEL_FOOTPRINT_CELLS \
		or int(audit.get("structural_court_interior_cell_count", 2147483647)) \
			> TARGET_MAX_STRUCTURAL_COURT_INTERIOR_CELLS \
		or int(audit.get("max_exterior_public_interior_component_size", \
			2147483647)) > TARGET_MAX_EXTERIOR_PUBLIC_INTERIOR_COMPONENT_SIZE \
		or int(audit.get("public_walk_interior_cell_count", 2147483647)) \
			> TARGET_MAX_PUBLIC_WALK_INTERIOR_CELLS \
		or int(audit.get("max_public_walk_interior_component_size", \
			2147483647)) > TARGET_MAX_PUBLIC_WALK_INTERIOR_COMPONENT_SIZE \
		or float(audit.get("largest_base_band_ratio", 1.0)) \
			> TARGET_MAX_LARGEST_BASE_BAND_RATIO \
		or int(audit.get("roof_band_count", 0)) < TARGET_MIN_ROOF_BAND_COUNT \
		or float(audit.get("largest_roof_band_ratio", 1.0)) \
			> TARGET_MAX_LARGEST_ROOF_BAND_RATIO \
		or float(audit.get("largest_footprint_family_ratio", 1.0)) \
			> TARGET_MAX_LARGEST_FOOTPRINT_FAMILY_RATIO \
		or int(audit.get("roof_material_family_count", 0)) \
			< TARGET_MIN_ROOF_MATERIAL_FAMILY_COUNT \
		or int(audit.get("roof_geometry_family_count", 0)) \
			< TARGET_MIN_ROOF_GEOMETRY_FAMILY_COUNT \
		or int(audit.get("roof_feature_count", 0)) < TARGET_MIN_ROOF_FEATURE_COUNT \
		or int(audit.get("facade_family_count", 0)) \
			< TARGET_MIN_FACADE_FAMILY_COUNT \
		or float(audit.get("largest_facade_family_ratio", 1.0)) \
			> TARGET_MAX_LARGEST_FACADE_FAMILY_RATIO \
		or float(audit.get("largest_roof_material_family_ratio", 1.0)) \
			> TARGET_MAX_LARGEST_ROOF_MATERIAL_FAMILY_RATIO \
		or int(audit.get("occupied_overpass_parcel_count", 0)) \
			< TARGET_MIN_OCCUPIED_OVERPASS_PARCELS


static func _visual_candidate_better(candidate: WarrenBuiltTownPlan,
		incumbent: WarrenBuiltTownPlan) -> bool:
	var candidate_violation := _visual_target_violation(candidate.audit)
	var incumbent_violation := _visual_target_violation(incumbent.audit)
	if not is_equal_approx(candidate_violation, incumbent_violation):
		return candidate_violation < incumbent_violation
	var candidate_score := _visual_quality_score(candidate.audit)
	var incumbent_score := _visual_quality_score(incumbent.audit)
	if not is_equal_approx(candidate_score, incumbent_score):
		return candidate_score > incumbent_score
	return candidate.deterministic_signature() \
		< incumbent.deterministic_signature()


static func _visual_target_violation(audit: Dictionary) -> float:
	var frontage := float(audit.get("frontage_ratio", 0.0))
	var ground_bounded := float(audit.get(
		"ground_primary_bounded_walk_ratio", 0.0))
	var ground_two_sided := float(audit.get(
		"ground_primary_two_sided_walk_ratio", 0.0))
	var overhead := float(audit.get("overhead_route_ratio", 0.0))
	var open_component := int(audit.get(
		"max_uncovered_route_component_size", 2147483647))
	var sightlines := int(audit.get("through_sightline_count", 2147483647))
	var ground_sightlines := int(audit.get(
		"ground_through_sightline_count", 2147483647))
	var skywalk_links := int(audit.get("skywalk_link_count", 0))
	var occupied_overpasses := int(audit.get(
		"occupied_overpass_parcel_count", 0))
	var buildings := int(audit.get("building_stack_count", 0))
	var footprint_cells := int(audit.get("parcel_footprint_cell_count", 0))
	var court_interior := int(audit.get(
		"structural_court_interior_cell_count", 2147483647))
	var public_interior := int(audit.get(
		"max_exterior_public_interior_component_size", 2147483647))
	var walk_interior_count := int(audit.get(
		"public_walk_interior_cell_count", 2147483647))
	var walk_interior_component := int(audit.get(
		"max_public_walk_interior_component_size", 2147483647))
	var largest_base_ratio := float(audit.get("largest_base_band_ratio", 1.0))
	var roof_band_count := int(audit.get("roof_band_count", 0))
	var largest_roof_band_ratio := float(audit.get(
		"largest_roof_band_ratio", 1.0))
	var same_base_ratio := float(audit.get("same_base_neighbor_ratio", 1.0))
	var largest_family_ratio := float(audit.get(
		"largest_footprint_family_ratio", 1.0))
	var family_count := int(audit.get("footprint_family_count", 0))
	var roof_material_count := int(audit.get("roof_material_family_count", 0))
	var roof_geometry_count := int(audit.get("roof_geometry_family_count", 0))
	var roof_feature_count := int(audit.get("roof_feature_count", 0))
	var perpendicular_roof_junctions := int(audit.get(
		"perpendicular_roof_junction_count", 0))
	var facade_family_count := int(audit.get("facade_family_count", 0))
	var largest_facade_family_ratio := float(audit.get(
		"largest_facade_family_ratio", 1.0))
	var largest_roof_material_ratio := float(audit.get(
		"largest_roof_material_family_ratio", 1.0))
	return maxf(0.0, (TARGET_FRONTAGE_RATIO - frontage) \
			/ TARGET_FRONTAGE_RATIO) \
		+ maxf(0.0, (TARGET_GROUND_PRIMARY_BOUNDED_RATIO \
			- ground_bounded) / TARGET_GROUND_PRIMARY_BOUNDED_RATIO) \
		+ maxf(0.0, (TARGET_GROUND_PRIMARY_TWO_SIDED_RATIO \
			- ground_two_sided) / TARGET_GROUND_PRIMARY_TWO_SIDED_RATIO) \
		+ maxf(0.0, (TARGET_OVERHEAD_RATIO - overhead) \
			/ TARGET_OVERHEAD_RATIO) \
		+ maxf(0.0, float(open_component \
			- TARGET_MAX_UNCOVERED_ROUTE_COMPONENT_SIZE) \
			/ float(TARGET_MAX_UNCOVERED_ROUTE_COMPONENT_SIZE)) \
		+ maxf(0.0, float(sightlines - TARGET_SIGHTLINE_COUNT) \
			/ float(TARGET_SIGHTLINE_COUNT)) \
		+ maxf(0.0, float(ground_sightlines \
			- TARGET_GROUND_SIGHTLINE_COUNT) \
			/ float(TARGET_GROUND_SIGHTLINE_COUNT)) \
		+ float(int(audit.get("unstepped_tall_parcel_count", 0))) \
		+ maxf(0.0, float(TARGET_BUILDING_STACK_COUNT - buildings) \
			/ float(TARGET_BUILDING_STACK_COUNT)) \
		+ maxf(0.0, float(TARGET_MIN_PARCEL_FOOTPRINT_CELLS \
			- footprint_cells) / float(TARGET_MIN_PARCEL_FOOTPRINT_CELLS)) \
		+ maxf(0.0, float(court_interior \
			- TARGET_MAX_STRUCTURAL_COURT_INTERIOR_CELLS) \
			/ float(TARGET_MAX_STRUCTURAL_COURT_INTERIOR_CELLS)) \
		+ maxf(0.0, float(public_interior \
			- TARGET_MAX_EXTERIOR_PUBLIC_INTERIOR_COMPONENT_SIZE) \
			/ float(TARGET_MAX_EXTERIOR_PUBLIC_INTERIOR_COMPONENT_SIZE)) \
		+ maxf(0.0, float(walk_interior_count \
			- TARGET_MAX_PUBLIC_WALK_INTERIOR_CELLS) \
			/ float(TARGET_MAX_PUBLIC_WALK_INTERIOR_CELLS)) \
		+ maxf(0.0, float(walk_interior_component \
			- TARGET_MAX_PUBLIC_WALK_INTERIOR_COMPONENT_SIZE) \
			/ float(TARGET_MAX_PUBLIC_WALK_INTERIOR_COMPONENT_SIZE)) \
		+ maxf(0.0, (largest_base_ratio \
			- TARGET_MAX_LARGEST_BASE_BAND_RATIO) \
			/ TARGET_MAX_LARGEST_BASE_BAND_RATIO) \
		+ maxf(0.0, float(TARGET_MIN_ROOF_BAND_COUNT - roof_band_count) \
			/ float(TARGET_MIN_ROOF_BAND_COUNT)) \
		+ maxf(0.0, (largest_roof_band_ratio \
			- TARGET_MAX_LARGEST_ROOF_BAND_RATIO) \
			/ TARGET_MAX_LARGEST_ROOF_BAND_RATIO) \
		+ maxf(0.0, (same_base_ratio \
			- TARGET_MAX_SAME_BASE_NEIGHBOR_RATIO) \
			/ TARGET_MAX_SAME_BASE_NEIGHBOR_RATIO) \
		+ maxf(0.0, (largest_family_ratio \
			- TARGET_MAX_LARGEST_FOOTPRINT_FAMILY_RATIO) \
			/ TARGET_MAX_LARGEST_FOOTPRINT_FAMILY_RATIO) \
		+ maxf(0.0, float(TARGET_MIN_FOOTPRINT_FAMILY_COUNT \
			- family_count) / float(TARGET_MIN_FOOTPRINT_FAMILY_COUNT)) \
		+ maxf(0.0, float(TARGET_MIN_ROOF_MATERIAL_FAMILY_COUNT \
			- roof_material_count) / float(TARGET_MIN_ROOF_MATERIAL_FAMILY_COUNT)) \
		+ maxf(0.0, float(TARGET_MIN_ROOF_GEOMETRY_FAMILY_COUNT \
			- roof_geometry_count) / float(TARGET_MIN_ROOF_GEOMETRY_FAMILY_COUNT)) \
		+ maxf(0.0, float(TARGET_MIN_ROOF_FEATURE_COUNT - roof_feature_count) \
			/ float(TARGET_MIN_ROOF_FEATURE_COUNT)) \
		+ maxf(0.0, float(TARGET_MIN_PERPENDICULAR_ROOF_JUNCTIONS \
			- perpendicular_roof_junctions) \
			/ float(TARGET_MIN_PERPENDICULAR_ROOF_JUNCTIONS)) \
		+ maxf(0.0, float(TARGET_MIN_FACADE_FAMILY_COUNT \
			- facade_family_count) / float(TARGET_MIN_FACADE_FAMILY_COUNT)) \
		+ maxf(0.0, (largest_facade_family_ratio \
			- TARGET_MAX_LARGEST_FACADE_FAMILY_RATIO) \
			/ TARGET_MAX_LARGEST_FACADE_FAMILY_RATIO) \
		+ maxf(0.0, (largest_roof_material_ratio \
			- TARGET_MAX_LARGEST_ROOF_MATERIAL_FAMILY_RATIO) \
			/ TARGET_MAX_LARGEST_ROOF_MATERIAL_FAMILY_RATIO) \
		+ float(int(audit.get("repeated_row_neighbor_pair_count", 0))) \
		+ maxf(0.0, float(2 - skywalk_links) / 2.0) \
		+ maxf(0.0, float(TARGET_MIN_OCCUPIED_OVERPASS_PARCELS \
			- occupied_overpasses) / float(TARGET_MIN_OCCUPIED_OVERPASS_PARCELS))


static func _visual_quality_score(audit: Dictionary) -> float:
	return float(audit.get("frontage_ratio", 0.0)) * 600.0 \
		+ float(audit.get("ground_primary_bounded_walk_ratio", 0.0)) \
			* 500.0 \
		+ float(audit.get("ground_primary_two_sided_walk_ratio", 0.0)) \
			* 900.0 \
		+ minf(float(audit.get("overhead_route_ratio", 0.0)), 0.40) * 300.0 \
		- float(audit.get("max_uncovered_route_component_size", 2147483647)) \
			* 8.0 \
		- float(audit.get("through_sightline_count", 2147483647)) * 3.0 \
		- float(audit.get("ground_through_sightline_count", 2147483647)) \
			* 8.0 \
		+ float(mini(int(audit.get("building_stack_count", 0)), 18)) * 2.0 \
		+ float(mini(int(audit.get("parcel_footprint_cell_count", 0)), 32)) \
			* 2.5 \
		+ float(mini(int(audit.get("skywalk_link_count", 0)), 3)) * 30.0 \
		+ float(mini(int(audit.get("occupied_overpass_parcel_count", 0)), 3)) \
			* 55.0 \
		+ float(mini(int(audit.get("half_level_neighbor_pair_count", 0)), 16)) \
		+ float(int(audit.get("stepped_descent_tall_parcel_count", 0))) \
			* 45.0 \
		- float(int(audit.get("unstepped_tall_parcel_count", 0))) * 70.0 \
		- float(int(audit.get("structural_court_cell_count", 0))) * 0.75 \
		- float(int(audit.get("structural_court_interior_cell_count", 0))) \
			* 8.0 \
		- float(int(audit.get("exterior_public_interior_cell_count", 0))) \
			* 10.0 \
		- float(int(audit.get("public_walk_interior_cell_count", 0))) * 5.0 \
		- float(int(audit.get("max_public_walk_interior_component_size", 0))) \
			* 16.0 \
		- float(audit.get("largest_base_band_ratio", 1.0)) * 180.0 \
		+ float(mini(int(audit.get("roof_band_count", 0)), 5)) * 35.0 \
		- float(audit.get("largest_roof_band_ratio", 1.0)) * 150.0 \
		- float(audit.get("same_base_neighbor_ratio", 1.0)) * 120.0 \
		- float(audit.get("largest_footprint_family_ratio", 1.0)) * 160.0 \
		+ float(int(audit.get("footprint_family_count", 0))) * 30.0 \
		+ float(int(audit.get("roof_material_family_count", 0))) * 45.0 \
		+ float(int(audit.get("roof_geometry_family_count", 0))) * 30.0 \
		+ float(mini(int(audit.get("roof_feature_count", 0)), 5)) * 14.0 \
		+ float(mini(int(audit.get("perpendicular_roof_junction_count", 0)), 2)) \
			* 75.0 \
		+ float(int(audit.get("facade_family_count", 0))) * 55.0 \
		- float(audit.get("largest_facade_family_ratio", 1.0)) * 100.0 \
		- float(audit.get("largest_roof_material_family_ratio", 1.0)) * 120.0 \
		- float(int(audit.get("repeated_row_neighbor_pair_count", 0))) * 250.0


static func _admit_markets(assets: WarrenAssetPlan,
		program: SettlementFabricProgram, town: WarrenTownPlan,
		initial_fabric: SettlementFabricPlan,
		initial_specs: Array[Dictionary], world_seed: int) -> Dictionary:
	var fabric := initial_fabric
	var accepted_specs: Array[Dictionary] = []
	accepted_specs.assign(initial_specs)
	var market_count := 0
	var market_candidates := WarrenMarketSolver.candidate_specs(program,
		fabric, town.volume, world_seed, town.pruning.daylight_void_columns)
	var market_rejections := PackedStringArray()
	for candidate: Dictionary in market_candidates:
		if market_count >= WarrenMarketSolver.TARGET_MARKETS:
			break
		var trial_specs: Array[Dictionary] = []
		trial_specs.assign(accepted_specs)
		trial_specs.append((candidate.spec as Dictionary).duplicate(true))
		var market_trial := WarrenFabricCompiler.solve(assets, trial_specs)
		if market_trial == null:
			if market_rejections.size() < 4:
				market_rejections.append("%s: %s" % [candidate.stable_id,
					WarrenFabricCompiler.last_failure])
			continue
		market_count += 1
		accepted_specs = trial_specs
		fabric = market_trial
	if market_count < WarrenMarketSolver.REQUIRED_MARKETS:
		return {
			"accepted": false,
			"failure": ("fewer than %d stocked markets survived exact " \
				+ "construction (candidates=%d accepted=%d): %s") % [
				WarrenMarketSolver.REQUIRED_MARKETS, market_candidates.size(),
				market_count, " | ".join(market_rejections)],
		}
	return {"accepted": true, "fabric": fabric, "specs": accepted_specs}


static func _admit_prefabs(assets: WarrenAssetPlan,
		program: SettlementFabricProgram,
		initial_fabric: SettlementFabricPlan,
		initial_specs: Array[Dictionary], world_seed: int) -> Dictionary:
	## Prefabs use the same common transaction as generated rooms. Candidate
	## discovery binds each reviewed door to one currently unbounded route edge;
	## this pass merely chooses a small, source-diverse subset. Rebuilding after
	## every admission makes the next house prove clearance against the market,
	## roof joins, stairs, guards, and all previously accepted buildings.
	var fabric := initial_fabric
	var accepted_specs: Array[Dictionary] = []
	accepted_specs.assign(initial_specs)
	var candidates := WarrenPrefabSolver.candidate_specs(program, fabric,
		world_seed)
	var accepted_ids: Dictionary = {}
	var source_families: Dictionary = {}
	var accepted_count := 0
	for require_new_family: bool in [true, false]:
		for candidate: Dictionary in candidates:
			if accepted_count >= TARGET_PREFAB_ANCHORS:
				break
			var candidate_id := StringName(candidate.stable_id)
			var source_family := StringName(candidate.source_family)
			if accepted_ids.has(candidate_id) \
					or (require_new_family and source_families.has(source_family)):
				continue
			if not _prefab_fits_urban_core(candidate, assets, program):
				accepted_ids[candidate_id] = false
				continue
			var trial_specs: Array[Dictionary] = []
			trial_specs.assign(accepted_specs)
			trial_specs.append((candidate.spec as Dictionary).duplicate(true))
			var trial := WarrenFabricCompiler.solve(assets, trial_specs)
			if trial == null:
				accepted_ids[candidate_id] = false
				continue
			accepted_ids[candidate_id] = true
			source_families[source_family] = true
			accepted_count += 1
			accepted_specs = trial_specs
			fabric = trial
	return {"fabric": fabric, "specs": accepted_specs,
		"accepted_count": accepted_count,
		"source_family_count": source_families.size()}


static func _prefab_fits_urban_core(candidate: Dictionary,
		assets: WarrenAssetPlan,
		program: SettlementFabricProgram) -> bool:
	## Source-pack buildings are complete landmarks, not small facade modules.
	## A threshold may touch the public route while most of a 15 m house sits
	## outside the actual town; that produces the detached satellite exposed by
	## the overview camera. Keep its measured envelope inside the sealed urban
	## columns (with one fine-cell eave tolerance) or leave the obligation to the
	## compact modular vocabulary.
	if assets == null or assets.town == null:
		return false
	var columns := assets.town.parcels.urban_core_columns
	if columns.is_empty():
		return false
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for value: Variant in columns.keys():
		var column := value as Vector2i
		minimum = minimum.min(Vector2(column) \
			* WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M)
		maximum = maximum.max(Vector2(column + Vector2i.ONE) \
			* WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M)
	var spec := candidate.spec as Dictionary
	var recipe_value := program.recipe(StringName(spec.recipe_id))
	if recipe_value == null:
		return false
	var transform := FabricRecipe.lattice_transform(
		spec.origin as Vector3i, int(spec.yaw_quarters))
	var bounds := transform * recipe_value.local_clearance_bounds
	var tolerance := FabricRecipe.CELL_SIZE
	return bounds.position.x >= minimum.x - tolerance \
		and bounds.end.x <= maximum.x + tolerance \
		and bounds.position.z >= minimum.y - tolerance \
		and bounds.end.z <= maximum.y + tolerance
