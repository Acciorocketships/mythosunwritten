class_name WarrenTownSolver
extends RefCounted

## Bounded composed search. Topology candidates are generated and gated without
## assets; only a small ranked frontier is parcelized. The accepted transaction
## must then pass pruning, common-realm, and physical-surface compilation.
const TOPOLOGY_ATTEMPTS := WarrenPublicRealmCarver.MAX_ATTEMPTS
# The arcade enclosure gate is evaluated only after parcelization, so preserve
# a broad but fixed composition frontier. The raw carver may search more
# orthogonal route families without multiplying asset work: the frontier below
# is balanced per family before parcelization rather than taking one global
# score prefix that could silently erase a valid route family.
const PARCEL_FRONTIER := 72
const ASSET_AWARE_PARCEL_FRONTIER := 32
const MAX_ASSET_AWARE_PARCEL_FRONTIER := WarrenPublicRealmCarver.MAX_ATTEMPTS
const COMPOSED_PLAN_FRONTIER := 8
## Optional galleries are a bounded construction choice, not an irreversible
## post-process. If their maximum cover closes exterior air once exact measured
## buildings are present, the asset solver may compare these smaller variants
## of the same route/parcel transaction.
## The full ladder stays: shallow bays cover half the route area the old deep
## bays did, and cutting the ten-gallery variant rejected a previously covered
## corpus site outright. The broad-deck reading is addressed by unplanked dirt
## ground streets, not by starving required cover.
const INFILL_VARIANT_BUDGETS: Array[int] = [10, 6, 3, 0]
const MIN_COMPLETE_PARCELS := 10
## Fixed mass-first partitions do not pass through the route-first packer's
## preselection motif. Reserve several mutually independent occupied links once
## their dense house graph is frozen, before details can spend those envelopes.
const MASS_FIRST_PLANNED_SKYWALKS := 3
# These are only cheap pre-compilation floors. Exact measured construction,
# surface continuity, overhead, frontage, and sight-line audits remain the
# acceptance authority. Keeping this preview gate at the finished-town target
# discarded compact 12-parcel candidates before roofs and outcroppings could
# prove their real enclosure, particularly once visually short fallback houses
# were removed.
const ASSET_AWARE_MIN_COMPLETE_PARCELS := 10
const ASSET_AWARE_MIN_FOOTPRINT_CELLS := 24
const ASSET_AWARE_MIN_TWO_SIDED_WALK_RATIO := 0.04
const ASSET_AWARE_MIN_BASE_BAND_COUNT := 2
const ASSET_AWARE_MIN_ROOF_BAND_COUNT := 3
const ASSET_AWARE_MAX_LARGEST_ROOF_BAND_RATIO := 0.60
## Paths divide a maze into several wall masses, so requiring one majority
## component is the wrong topology: it pressures all houses into one row or
## plaza perimeter. Require a substantial local mass plus broad participation
## in some face-contact seam; a bounded number of isolates may still terminate
## a street or own a skywalk across it.
##
## Measured as a share of built footprint CELLS, not of parcel count -- see
## WarrenParcelPlan.largest_contact_cell_ratio(). The threshold is unchanged;
## the parcel-count form simply measured the wrong thing, scoring the same
## urban mass differently depending on how finely a stage subdivided it.
const ASSET_AWARE_MIN_BUILDING_CONTACT_RATIO := 0.33
## A 45-60 house massif is intentionally split into several wall clusters by
## the public maze. Requiring one cluster to own a full third of all footprint
## cells needlessly rejects towns where 94% of houses still touch a neighbor.
## Keep route-first's reviewed 0.33 bar and use the slightly lower physical
## component floor only for the much larger excavated mass.
const MASS_FIRST_MIN_BUILDING_CONTACT_RATIO := 0.30
# The structural connection graph now includes sealed occupied bridge-house
# edges as well as shared facade boundaries. Seven of ten connected buildings,
# together with the independent substantial-component gate above, permits a few
# route-addressed corner closers without mistaking ten isolated houses for a
# town. Raising this to eight forced the last three accents into repeated rows.
const ASSET_AWARE_MIN_CONTACTED_BUILDING_RATIO := 0.70
## Detached buildings, as a share of built footprint cells rather than as an
## absolute count of houses -- the same correction, and for the same reason, as
## the contact ratio above. A cap of three DETACHED HOUSES grows stricter on its
## own as a stage subdivides the same mass more finely: route-first tolerated
## three of its ten-to-twelve parcels standing alone, roughly a quarter of the
## town, while mass-first's eighteen-to-twenty-five parcels were held to an
## eighth for no physical reason.
##
## Derived from measurement, not chosen: across route-first's ranked corpus on
## seeds 0-7 the isolated share runs 0.182, 0.182, 0.207, 0.276, 0.286 and
## 0.370. The cap sits just above that observed maximum so every town
## route-first ships today still passes -- verified by re-running its corpus
## under both forms and diffing the ranked candidates.
const ASSET_AWARE_MAX_ISOLATED_BUILDING_CELL_RATIO := 0.38
const ASSET_AWARE_MIN_NEIGHBORING_PARCEL_PAIRS := 4
const MAX_URBAN_CORE_OPEN_RATIO := 0.125
# Asset-aware search preserves a broader raw-void frontier because the two
# connected ground arcades and exact stocked-market envelopes can occupy and
# visually divide those pockets after parcelization. The later composed
# enclosure, lightwell, platform, and screenshot audits still decide whether a
# survivor reads as an enclosed town; this ratio is only an early search bound.
const ASSET_AWARE_MAX_CORE_OPEN_RATIO := 0.25
## Migration boundary (mass-first design spec). route_first is the pipeline
## this project ships: its branch in ranked_candidates() is the original code,
## unreachable from and unaffected by anything below. mass_first replaces only
## the topology frontier -- with excavated massifs instead of routes carved out
## of a Gaussian envelope -- and then hands that frontier to exactly the same
## arcade, frontage, parcel, ranking, and composition stages. A static var
## rather than a const so tests and corpus probes can flip it per call.
const MODE_ROUTE_FIRST := &"route_first"
const MODE_MASS_FIRST := &"mass_first"
static var GENERATION_MODE: StringName = MODE_ROUTE_FIRST
## One attempt is a full 256-bore WarrenExcavationCarver search over an
## already-built massif, measured at ~0.9 s (the massif itself is 6 ms and is
## built once, since WarrenMassifBuilder.build is deterministic per seed).
## Twelve attempts therefore cost ~11 s per ranked_candidates() call and,
## measured over seeds 1-12, cleared the topology gate on a median of 9 and a
## minimum of 1 volume per buildable seed -- enough that the gate, not the
## attempt budget, is what bounds the frontier. A 64-attempt sweep over four
## seeds bought proportionally more gate survivors (34-41 of 64) and no new
## downstream behaviour, so the extra minute per call buys nothing today.
const MASS_FIRST_EXCAVATION_ATTEMPTS := 12
## How many ranked bore survivors of one excavation attempt are offered to the
## topology gate before the attempt is declared a miss. The carver keeps only a
## handful of its 256 bores, so this covers them all in practice.
const TOPOLOGY_GATE_CANDIDATES := 8
## Attempts vary the CARVE seed, never the massif seed: the massif is
## deterministic per world seed, so rebuilding it per attempt would return the
## identical solid and the whole frontier would collapse to one route. A large
## prime stride keeps adjacent world seeds from sharing attempt corpora.
const MASS_FIRST_ATTEMPT_STRIDE := 1000003
static var last_failure := ""
## Non-deterministic performance trace for harnesses. Timings never enter a
## sealed plan or signature and therefore cannot affect output.
static var last_timing_diagnostic: Dictionary = {}
## Why the mass-first parcel stage last returned null. Route-first keeps
## reporting WarrenParcelizer.last_failure, which is unrelated and would be
## stale here; see last_parcelize_failure().
static var last_partition_failure := ""


static func solve(world_seed: int,
		ground_bands: Dictionary = {},
		construction_program: SettlementFabricProgram = null) -> WarrenTownPlan:
	var plans := ranked_candidates(world_seed, ground_bands,
		construction_program, 1)
	return null if plans.is_empty() else plans[0]


static func solve_attempt(world_seed: int, attempt: int,
		ground_bands: Dictionary = {},
		construction_program: SettlementFabricProgram = null) -> WarrenTownPlan:
	## Rebuild one previously selected topology attempt against a terrain-relative
	## ground field. Production placement uses this to preserve the boundary
	## entrance chosen by the flat preview while allowing every column to acquire
	## its actual local terrain band.
	last_failure = ""
	if attempt < 0 or attempt >= TOPOLOGY_ATTEMPTS:
		last_failure = "topology attempt is outside the bounded search"
		return null
	var envelope := WarrenVolumeEnvelope.build(world_seed, ground_bands)
	var volume := WarrenPublicRealmCarver.sealed_candidate(world_seed, attempt,
		envelope) if envelope != null else null
	if volume == null:
		last_failure = "selected topology attempt no longer fits local terrain"
		return null
	volume = WarrenGroundArcadeSolver.extend(volume)
	if volume == null:
		last_failure = WarrenGroundArcadeSolver.last_failure
		return null
	var best_volume: WarrenVolumePlan
	var best_parcels: WarrenParcelPlan
	var best_score := INF
	for candidate_volume: WarrenVolumePlan in \
			WarrenElevatedFrontageSolver.variants(volume):
		var candidate_parcels := _parcelize(candidate_volume,
			construction_program)
		if candidate_parcels == null or not _passes_construction_gate(
				candidate_parcels, construction_program != null):
			continue
		var candidate_score := _construction_score(candidate_volume,
			candidate_parcels, construction_program)
		if best_volume == null or candidate_score < best_score:
			best_volume = candidate_volume
			best_parcels = candidate_parcels
			best_score = candidate_score
	if best_volume == null:
		last_failure = "selected topology attempt has no complete roofed parcel plan"
		return null
	return _compose_plan(world_seed, best_volume, best_parcels)


static func infill_variants(source: WarrenTownPlan) -> Array[WarrenTownPlan]:
	var out: Array[WarrenTownPlan] = []
	if source == null or not source.is_sealed():
		return out
	var current_optional := int(source.audit.get(
		"optional_infill_platform_patch_count", 0))
	# Exact construction should prove the leanest sufficient public network, not
	# accept a broad deck merely because the maximum cosmetic budget happened to
	# be compiled first.  The hard shaft-closure patches remain in every variant;
	# optional facade courts grow only when the smaller transaction cannot pass
	# the same route, support, entrance, and enclosure audits.
	var ascending_budgets: Array[int] = []
	ascending_budgets.assign(INFILL_VARIANT_BUDGETS)
	ascending_budgets.sort()
	for budget in ascending_budgets:
		if budget >= current_optional:
			continue
		var variant := _compose_plan(source.volume.world_seed, source.volume,
			source.parcels, budget)
		if variant != null:
			out.append(variant)
	out.append(source)
	return out


static func ranked_candidates(world_seed: int,
		ground_bands: Dictionary = {},
		construction_program: SettlementFabricProgram = null,
		max_results: int = COMPOSED_PLAN_FRONTIER,
		asset_frontier_override: int = -1) -> Array[WarrenTownPlan]:
	## Preserve a small complete-plan frontier through the exact air/surface
	## stages.  Asset compilation can then reject one candidate without turning a
	## perfectly viable world seed into an empty settlement.
	last_failure = ""
	last_timing_diagnostic = {}
	var solve_started := Time.get_ticks_msec()
	var out: Array[WarrenTownPlan] = []
	if max_results <= 0:
		last_failure = "candidate frontier limit must be positive"
		return out
	var topology_frontier: Array[WarrenVolumePlan] = []
	if GENERATION_MODE == MODE_MASS_FIRST:
		topology_frontier = mass_first_frontier(world_seed, ground_bands)
		if topology_frontier.is_empty():
			return out
	else:
		var envelope := WarrenVolumeEnvelope.build(world_seed, ground_bands)
		if envelope == null:
			last_failure = "Gaussian envelope rejected"
			return out
		for attempt in TOPOLOGY_ATTEMPTS:
			var volume := WarrenPublicRealmCarver.sealed_candidate(world_seed,
				attempt, envelope)
			if volume == null:
				continue
			volume = WarrenGroundArcadeSolver.extend(volume)
			if volume == null:
				continue
			for gallery_variant: WarrenVolumePlan in \
					WarrenElevatedFrontageSolver.variants(volume):
				topology_frontier.append(gallery_variant)
	var topology_finished := Time.get_ticks_msec()
	topology_frontier.sort_custom(func(a: WarrenVolumePlan,
			b: WarrenVolumePlan) -> bool:
		return WarrenPublicRealmCarver.topology_score(a) \
			< WarrenPublicRealmCarver.topology_score(b))
	var frontier_limit := (asset_frontier_override \
		if asset_frontier_override > 0 else ASSET_AWARE_PARCEL_FRONTIER) \
		if construction_program != null else PARCEL_FRONTIER
	frontier_limit = mini(frontier_limit,
		MAX_ASSET_AWARE_PARCEL_FRONTIER if construction_program != null \
		else PARCEL_FRONTIER)
	topology_frontier = _balanced_topology_order(topology_frontier,
		frontier_limit)
	if topology_frontier.size() > frontier_limit:
		topology_frontier.resize(frontier_limit)
	var ranked: Array[Dictionary] = []
	var parcel_elapsed_ms := 0
	var parcel_max_ms := 0
	var parcel_call_count := 0
	var closest_rejected: WarrenParcelPlan
	var closest_rejected_attempt := -1
	var closest_rejected_score := INF
	var parcel_failure := ""
	var parcel_attempts := PackedInt32Array()
	var parcel_survivors := PackedInt32Array()
	for volume: WarrenVolumePlan in topology_frontier:
		parcel_attempts.append(_volume_attempt(volume))
		var parcel_started := Time.get_ticks_msec()
		var variants := _parcel_variants(volume, construction_program)
		var parcel_ms := Time.get_ticks_msec() - parcel_started
		parcel_elapsed_ms += parcel_ms
		parcel_max_ms = maxi(parcel_max_ms, parcel_ms)
		parcel_call_count += 1
		if variants.is_empty():
			parcel_failure = last_parcelize_failure()
			continue
		for parcels: WarrenParcelPlan in variants:
			if not _passes_construction_gate(parcels,
					construction_program != null):
				var rejected_score := _gate_distance(parcels,
					construction_program != null)
				if closest_rejected == null \
						or rejected_score < closest_rejected_score:
					closest_rejected = parcels
					closest_rejected_attempt = _volume_attempt(volume)
					closest_rejected_score = rejected_score
				continue
			var score := _construction_score(volume, parcels,
				construction_program)
			ranked.append({"volume": volume, "parcels": parcels,
				"score": score})
			parcel_survivors.append(_volume_attempt(volume))
	if ranked.is_empty():
		last_timing_diagnostic = {
			"topology_ms": topology_finished - solve_started,
			"parcel_ms": parcel_elapsed_ms,
			"parcel_max_ms": parcel_max_ms,
			"parcel_calls": parcel_call_count,
			"parcel_attempts": parcel_attempts,
			"parcel_survivors": parcel_survivors,
			"total_ms": Time.get_ticks_msec() - solve_started,
		}
		last_failure = "no topology survivor admitted a complete roofed parcel plan"
		if closest_rejected != null:
			last_failure += (" (closest attempt=%d: parcels=%d bands=%d " \
				+ "families=%d half=%d contact=%.2f pairs=%d " \
				+ "bounded=%.2f/%.2f open=%.2f)") % [
				closest_rejected_attempt,
				int(closest_rejected.audit.parcel_count),
				int(closest_rejected.audit.base_band_count),
				int(closest_rejected.audit.footprint_family_count),
				int(closest_rejected.audit.half_level_neighbor_pair_count),
				# The cell-weighted share, because that is what the gate above
				# actually tested; quoting the parcel-count one here sent a
				# reader chasing a number no threshold reads.
				float(closest_rejected.audit.get(
					"largest_building_contact_component_cell_ratio", 0.0)),
				int(closest_rejected.audit.get(
					"neighboring_parcel_pair_count", 0)),
				float(closest_rejected.audit.bounded_walk_ratio),
				float(closest_rejected.audit.all_two_sided_walk_ratio),
				float(closest_rejected.audit.urban_core_open_column_ratio)]
		elif not parcel_failure.is_empty():
			last_failure += " (%s)" % parcel_failure
		return out
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.score), float(b.score)):
			return float(a.score) < float(b.score)
		return String((a.volume as WarrenVolumePlan).stable_id) \
			< String((b.volume as WarrenVolumePlan).stable_id))
	if construction_program != null:
		ranked = _asset_composition_order(ranked, max_results)
	var downstream_failure := ""
	var compose_started := Time.get_ticks_msec()
	var preferred_out: Array[WarrenTownPlan] = []
	var fallback_out: Array[WarrenTownPlan] = []
	for candidate: Dictionary in ranked:
		var volume := candidate.volume as WarrenVolumePlan
		var parcels := candidate.parcels as WarrenParcelPlan
		var plan := _compose_plan(world_seed, volume, parcels)
		if plan == null:
			downstream_failure = last_failure
			continue
		if float(plan.audit.get("composed_walk_enclosure_ratio", 0.0)) \
				>= WarrenTownPlan.PREFERRED_COMPOSED_WALK_ENCLOSURE_RATIO:
			preferred_out.append(plan)
		else:
			fallback_out.append(plan)
	for plan: WarrenTownPlan in preferred_out:
		if out.size() >= max_results:
			break
		out.append(plan)
	for plan: WarrenTownPlan in fallback_out:
		if out.size() >= max_results:
			break
		out.append(plan)
	if out.is_empty():
		last_failure = downstream_failure if not downstream_failure.is_empty() \
			else "no ranked parcel plan survived composed compilation"
	last_timing_diagnostic = {
		"topology_ms": topology_finished - solve_started,
		"parcel_ms": parcel_elapsed_ms,
		"parcel_max_ms": parcel_max_ms,
		"parcel_calls": parcel_call_count,
		"parcel_attempts": parcel_attempts,
		"parcel_survivors": parcel_survivors,
		"compose_ms": Time.get_ticks_msec() - compose_started,
		"total_ms": Time.get_ticks_msec() - solve_started,
	}
	return out


static func mass_first_frontier(world_seed: int,
		ground_bands: Dictionary = {},
		scale_profile: WarrenVillageScaleProfile = null,
		maximum_surviving_attempts: int = -1,
		first_attempt: int = 0) \
		-> Array[WarrenVolumePlan]:
	## The mass-first topology frontier: one terraced solid, bored repeatedly,
	## each bore adapted into the same sealed WarrenVolumePlan the route-first
	## carver emits, then extended by the same arcade and frontage solvers.
	##
	## Public because it is a stage seam, not an implementation detail: mode
	## corpora and the mass-first tests audit the frontier and the parcel stage
	## (partition_parcels) independently, rather than inferring both from
	## whether a whole town composed.
	##
	## Every stage here returns null for ordinary reasons and none of them are
	## errors: the massif gates reject ~2% of world seeds outright, a bounded
	## bore search legitimately finds nothing on some massifs, and the adapter's
	## plan seal rejects the occasional same-datum 2x2 block that the carver's
	## soft fold penalty could not price away (~2%, documented in Task 3). A
	## null is skipped and the search continues; only an empty frontier fails,
	## and it reports where the corpus was lost rather than that it was.
	var out: Array[WarrenVolumePlan] = []
	last_failure = ""
	last_timing_diagnostic = {}
	if first_attempt < 0 or first_attempt >= MASS_FIRST_EXCAVATION_ATTEMPTS \
			or maximum_surviving_attempts == 0:
		last_failure = "invalid staged mass-first frontier range"
		return out
	var solve_started := Time.get_ticks_msec()
	var profile := scale_profile if scale_profile != null \
		else WarrenVillageScaleProfile.review_fixture()
	var massif := WarrenMassifBuilder.build(world_seed, ground_bands, profile)
	if massif == null:
		last_failure = "massif rejected: %s" % WarrenMassifBuilder.last_failure
		return out
	var carved := 0
	var adapted := 0
	var gated := 0
	var arcaded := 0
	var gallery_variant_count := 0
	var regated := 0
	var excavation_failure := ""
	var arcade_failure := ""
	var frontage_failures := PackedStringArray()
	var post_gallery_failures := PackedStringArray()
	var attempted := 0
	var surviving_attempts := 0
	var last_attempt_index := first_attempt - 1
	var attempt_timings: Array[Dictionary] = []
	for attempt in range(first_attempt, MASS_FIRST_EXCAVATION_ATTEMPTS):
		var attempt_started_ms := Time.get_ticks_msec()
		var stage_started_ms := attempt_started_ms
		var attempt_timing := {"attempt": attempt}
		attempted += 1
		last_attempt_index = attempt
		var output_count_before_attempt := out.size()
		var excavations := WarrenExcavationCarver.carve_ranked(
			world_seed + attempt * MASS_FIRST_ATTEMPT_STRIDE, massif, profile,
			TOPOLOGY_GATE_CANDIDATES)
		attempt_timing["excavation_ms"] = Time.get_ticks_msec() - stage_started_ms
		stage_started_ms = Time.get_ticks_msec()
		if excavations.is_empty():
			excavation_failure = "%s diagnostic=%s" % [
				WarrenExcavationCarver.last_failure,
				WarrenExcavationCarver.last_diagnostic]
			attempt_timing["outcome"] = &"excavation"
			attempt_timing["total_ms"] = Time.get_ticks_msec() - attempt_started_ms
			attempt_timings.append(attempt_timing)
			continue
		carved += 1
		# Route-first candidates can only reach this frontier through
		# WarrenPublicRealmCarver.sealed_candidate, which applies the carver's
		# topology gate. Excavated candidates are held to that same bar instead
		# of an implicit weaker one, so both modes hand the downstream stages
		# topology of the same measured quality. Two of its criteria genuinely
		# bite here -- a complete six-band frontage on 55% of route cells, and
		# at least one ramp -- because the excavation carver's own gates ask
		# only for street-height flanking walls and no ramp at all. The carver
		# ranks its survivors by its own score, which knows nothing of these
		# criteria, so the first survivor that passes the gate is taken rather
		# than discarding the attempt because the score-best one missed.
		var volume := _gate_preferred_volume(excavations, massif, profile)
		attempt_timing["adapter_ms"] = Time.get_ticks_msec() - stage_started_ms
		stage_started_ms = Time.get_ticks_msec()
		if volume == null:
			attempt_timing["outcome"] = &"adapter"
			attempt_timing["total_ms"] = Time.get_ticks_msec() - attempt_started_ms
			attempt_timings.append(attempt_timing)
			continue
		adapted += 1
		var mass_context := volume.mass_context
		var frontage_cells := volume.frontage_cells
		var passes_topology := WarrenPublicRealmCarver.passes_topology_gate(volume)
		attempt_timing["topology_gate_ms"] = \
			Time.get_ticks_msec() - stage_started_ms
		stage_started_ms = Time.get_ticks_msec()
		if not passes_topology:
			attempt_timing["outcome"] = &"topology_gate"
			attempt_timing["total_ms"] = Time.get_ticks_msec() - attempt_started_ms
			attempt_timings.append(attempt_timing)
			continue
		gated += 1
		volume = WarrenGroundArcadeSolver.extend_preserving_topology(volume)
		attempt_timing["arcade_ms"] = Time.get_ticks_msec() - stage_started_ms
		stage_started_ms = Time.get_ticks_msec()
		if volume == null:
			arcade_failure = WarrenGroundArcadeSolver.last_failure
			attempt_timing["outcome"] = &"arcade"
			attempt_timing["total_ms"] = Time.get_ticks_msec() - attempt_started_ms
			attempt_timings.append(attempt_timing)
			continue
		arcaded += 1
		var gallery_variants := WarrenElevatedFrontageSolver.variants(volume,
			profile.requires_elevated_courtyard)
		attempt_timing["gallery_ms"] = Time.get_ticks_msec() - stage_started_ms
		stage_started_ms = Time.get_ticks_msec()
		gallery_variant_count += gallery_variants.size()
		if gallery_variants.is_empty():
			var frontage_failure := WarrenElevatedFrontageSolver.last_failure
			if not frontage_failure.is_empty() \
					and not frontage_failures.has(frontage_failure):
				frontage_failures.append(frontage_failure)
		for gallery_variant: WarrenVolumePlan in gallery_variants:
			# The arcade and gallery stages rebuild the plan from geometry
			# alone and deliberately drop non-geometric provenance, so the
			# frontier -- the one place that still holds the massif this
			# variant descends from -- re-attaches it. _parcelize() needs
			# mass_context to partition the standing solid, and frontage_cells
			# so WarrenBuildingParcel.seal() recognises a house addressed at a
			# STAIR/RAMP intermediate cell; without either a mass-first
			# candidate is simply not parcelizable and is skipped like any
			# other.
			gallery_variant.mass_context = mass_context
			gallery_variant.frontage_cells = frontage_cells
			# Arcades and gallery variants remove additional mass after the first
			# topology gate. Recheck the common contract so a branch cannot consume
			# one of the opposing ground facades the inward bore was selected for.
			var gate_failure := WarrenPublicRealmCarver \
				.topology_gate_failure(gallery_variant)
			if not gate_failure.is_empty():
				if not post_gallery_failures.has(gate_failure):
					post_gallery_failures.append(gate_failure)
				continue
			regated += 1
			out.append(gallery_variant)
		attempt_timing["regate_ms"] = Time.get_ticks_msec() - stage_started_ms
		attempt_timing["survivor_count"] = out.size() - output_count_before_attempt
		attempt_timing["outcome"] = &"survived" \
			if out.size() > output_count_before_attempt else &"gallery_gate"
		attempt_timing["total_ms"] = Time.get_ticks_msec() - attempt_started_ms
		attempt_timings.append(attempt_timing)
		if out.size() > output_count_before_attempt:
			surviving_attempts += 1
			if maximum_surviving_attempts > 0 \
					and surviving_attempts >= maximum_surviving_attempts:
				break
	last_timing_diagnostic = {
		"first_attempt_index": first_attempt,
		"last_attempt_index": last_attempt_index,
		"attempt_count": attempted,
		"surviving_attempt_count": surviving_attempts,
		"frontier_count": out.size(),
		"attempt_timings": attempt_timings,
		"total_ms": Time.get_ticks_msec() - solve_started,
	}
	if out.is_empty():
		# Naming the stage that ate the corpus is the whole diagnostic value
		# here: a bare "nothing survived" sends the next reader back to
		# re-instrumenting these same four stages by hand. Today every gated
		# candidate is lost at the arcade, which wants two terrain-level route
		# cells at least MIN_BRANCH_SEPARATION_CELLS apart, while an excavated
		# route climbs away from its single portal and touches grade twice,
		# adjacently. Task 5's solid partitioner is where that is answered.
		last_failure = ("no excavated topology reached the frontier " \
			+ ("(%d/%d bores carved, %d adapted, %d passed the topology " \
			+ "gate, %d arcaded, %d gallery variants, %d passed the " \
			+ "post-gallery gate%s)")) \
			% [carved, attempted, adapted, gated,
				arcaded, gallery_variant_count, regated,
			"; post-gallery: %s" % " | ".join(post_gallery_failures) \
				if not post_gallery_failures.is_empty() \
				else "; elevated frontage: %s" % " | ".join(frontage_failures) \
				if not frontage_failures.is_empty() \
				else "; ground arcade: %s" % arcade_failure \
				if not arcade_failure.is_empty() \
				else "; excavation: %s" % excavation_failure \
				if not excavation_failure.is_empty() else ""]
	return out


static func mass_first_attempt_frontier(world_seed: int, attempt_index: int,
		ground_bands: Dictionary = {},
		scale_profile: WarrenVillageScaleProfile = null) \
		-> Array[WarrenVolumePlan]:
	## Terrain-placement rebuild seam for one source selected by the complete flat
	## preview.  It runs the identical massif -> excavation -> topology gate ->
	## arcade -> third-storey-court/gallery transaction as mass_first_frontier(),
	## but never explores a different bore.  The returned stable IDs therefore
	## let the caller demand the same gallery alternative exactly.
	last_failure = ""
	var out: Array[WarrenVolumePlan] = []
	if attempt_index < 0 or attempt_index >= MASS_FIRST_EXCAVATION_ATTEMPTS:
		last_failure = "mass-first excavation attempt is outside the bounded search"
		return out
	var profile := scale_profile if scale_profile != null \
		else WarrenVillageScaleProfile.review_fixture()
	var massif := WarrenMassifBuilder.build(world_seed, ground_bands, profile)
	if massif == null:
		last_failure = "massif rejected: %s" % WarrenMassifBuilder.last_failure
		return out
	var excavations := WarrenExcavationCarver.carve_ranked(
		world_seed + attempt_index * MASS_FIRST_ATTEMPT_STRIDE, massif, profile,
		TOPOLOGY_GATE_CANDIDATES)
	if excavations.is_empty():
		last_failure = "selected excavation no longer carves local terrain"
		return out
	var volume := _gate_preferred_volume(excavations, massif, profile)
	if volume == null:
		last_failure = WarrenExcavationVolumeAdapter.last_failure
		return out
	if not WarrenPublicRealmCarver.passes_topology_gate(volume):
		last_failure = "selected excavation no longer passes the topology gate: %s" \
			% WarrenPublicRealmCarver.topology_gate_failure(volume)
		return out
	var mass_context := volume.mass_context
	var frontage_cells := volume.frontage_cells
	volume = WarrenGroundArcadeSolver.extend_preserving_topology(volume)
	if volume == null:
		last_failure = WarrenGroundArcadeSolver.last_failure
		return out
	for candidate: WarrenVolumePlan in WarrenElevatedFrontageSolver.variants(
			volume, profile.requires_elevated_courtyard):
		candidate.mass_context = mass_context
		candidate.frontage_cells = frontage_cells
		if not WarrenPublicRealmCarver.passes_topology_gate(candidate):
			continue
		out.append(candidate)
	if out.is_empty():
		last_failure = WarrenElevatedFrontageSolver.last_failure
	return out


## The one selection rule shared by the staged frontier and the selected-
## attempt rebuild, so a pinned town re-derives the exact bore it was sealed
## from. Adapts the carver's ranked survivors in order and returns the first
## whose volume passes the public-realm topology gate; when none passes, the
## best-ranked adapted volume is returned so callers report its gate failure
## exactly as before. Null only when nothing adapts.
static func _gate_preferred_volume(excavations: Array[WarrenExcavation],
		massif: WarrenMassif, profile: WarrenVillageScaleProfile) \
		-> WarrenVolumePlan:
	var fallback: WarrenVolumePlan = null
	for excavation: WarrenExcavation in excavations:
		var volume := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
			excavation)
		if volume == null:
			continue
		_attach_scale_profile(volume, profile)
		if WarrenPublicRealmCarver.passes_topology_gate(volume):
			return volume
		if fallback == null:
			fallback = volume
	return fallback


static func _attach_scale_profile(volume: WarrenVolumePlan,
		profile: WarrenVillageScaleProfile) -> void:
	assert(volume != null and profile != null and profile.validate())
	volume.mass_context[&"scale_profile_id"] = profile.scale_id
	volume.mass_context[&"scale_profile_signature"] = \
		profile.deterministic_signature()


static func mass_first_attempt_index(world_seed: int,
		volume: WarrenVolumePlan) -> int:
	## The excavation seed is the source volume's seed.  Semantic `.arcade` and
	## `.gallery` suffixes never alter it, so this identity survives every
	## topology clone without parsing a presentation-oriented stable ID.
	if volume == null:
		return -1
	var delta := volume.world_seed - world_seed
	if delta < 0 or delta % MASS_FIRST_ATTEMPT_STRIDE != 0:
		return -1
	var attempt := delta / MASS_FIRST_ATTEMPT_STRIDE
	return attempt if attempt >= 0 \
		and attempt < MASS_FIRST_EXCAVATION_ATTEMPTS else -1


static func _asset_composition_order(ranked: Array[Dictionary],
		max_results: int) -> Array[Dictionary]:
	## Cheap parcel scores cannot compare the exterior-air behavior of measured
	## buildings. Preserve an equal bounded slice from every route family through
	## the exact frontier, then visit every remainder in its original total order
	## if a composed candidate fails before filling the frontier. The policy is
	## derived from the grammar, so adding a family cannot require another special
	## case here.
	var family_count := WarrenPublicRealmCarver.ROUTE_CELL_FAMILIES.size()
	if family_count <= 1:
		return ranked
	var families: Array = []
	for family_index in family_count:
		families.append([])
	for candidate: Dictionary in ranked:
		var attempt := _volume_attempt(candidate.volume as WarrenVolumePlan)
		var family_index := _route_family_index(attempt)
		if family_index >= 0:
			families[family_index].append(candidate)
	var out: Array[Dictionary] = []
	var slots_per_family := _fair_family_slot_count(max_results, family_count)
	for family: Array in families:
		for index in mini(slots_per_family, family.size()):
			out.append(family[index])
	for candidate: Dictionary in ranked:
		if not out.has(candidate):
			out.append(candidate)
	return out


static func _balanced_topology_order(ranked: Array[WarrenVolumePlan],
		frontier_limit: int) -> Array[WarrenVolumePlan]:
	## Expensive parcelization receives an explicit share from each independently
	## generated route-length family. Remainders retain the global quality order
	## and are still visited if any family has fewer valid survivors.
	var family_count := WarrenPublicRealmCarver.ROUTE_CELL_FAMILIES.size()
	if family_count <= 1:
		return ranked
	var families: Array = []
	for family_index in family_count:
		families.append([])
	for volume: WarrenVolumePlan in ranked:
		var family_index := _route_family_index(_volume_attempt(volume))
		if family_index >= 0:
			families[family_index].append(volume)
	var out: Array[WarrenVolumePlan] = []
	var slots_per_family := _fair_family_slot_count(frontier_limit, family_count)
	for family: Array in families:
		for index in mini(slots_per_family, family.size()):
			out.append(family[index])
	for volume: WarrenVolumePlan in ranked:
		if not out.has(volume):
			out.append(volume)
	return out


static func _route_family_index(attempt: int) -> int:
	if attempt < 0 or attempt >= WarrenPublicRealmCarver.MAX_ATTEMPTS:
		return -1
	return attempt / WarrenPublicRealmCarver.ATTEMPTS_PER_ROUTE_FAMILY


static func _fair_family_slot_count(frontier_limit: int,
		family_count: int) -> int:
	## Reserve a sublinear sample for every independent grammar, then let the
	## globally ranked remainder compete normally. Equal partitioning made a weak
	## experimental family consume half of the expensive measured-asset budget;
	## a single token per family was too brittle. sqrt(frontier) grows the audit
	## sample without letting vocabulary size multiply construction cost.
	if frontier_limit <= 0 or family_count <= 0:
		return 0
	return maxi(1, mini(ceili(sqrt(float(frontier_limit))),
		frontier_limit / family_count))


static func _volume_attempt(volume: WarrenVolumePlan) -> int:
	var parts := String(volume.stable_id).split(".")
	for index in range(parts.size() - 1, -1, -1):
		var token := parts[index] as String
		if token.is_valid_int():
			return int(token)
	return -1


static func route_attempt(volume: WarrenVolumePlan) -> int:
	## Public diagnostic for the canonical attempt identity. Derived volumes append
	## semantic suffixes such as `.arcade`, so the attempt is the last numeric
	## token rather than necessarily the last token.
	return -1 if volume == null else _volume_attempt(volume)


static func _parcelize(volume: WarrenVolumePlan,
		construction_program: SettlementFabricProgram) -> WarrenParcelPlan:
	if volume == null:
		return null
	if GENERATION_MODE == MODE_MASS_FIRST:
		# Everything below this line is the route-first packing search, reached
		# only under the shipped default. In mass-first the search is the wrong
		# question: the leftover solid already IS the buildings, so nothing has
		# to be fitted around the route.
		return partition_parcels(volume)
	var compatibility := Callable()
	var connection_pair := Callable()
	var reservation_compatibility := Callable()
	var connection_broad_phase := Callable()
	if construction_program != null:
		# One topology creates many repeated pair/lookahead queries over the same
		# immutable parcel proposals. Share their compiled component envelopes and
		# room sockets across all three predicates. This changes cost only: cache
		# keys are live parcel identities and the cache dies with this solve.
		var asset_cache: Dictionary = {&"enabled": true}
		compatibility = Callable(WarrenAssetCompiler,
			"parcels_are_visually_compatible").bind(construction_program,
				asset_cache)
		var exact_realm := WarrenVolumePublicRealmAdapter.from_volume(volume)
		if exact_realm == null:
			return null
		connection_pair = Callable(WarrenAssetCompiler,
			"skywalk_reservation").bind(construction_program,
				exact_realm.air_claims(), asset_cache)
		connection_broad_phase = Callable(WarrenAssetCompiler,
			"parcels_may_form_skywalk").bind(construction_program,
				asset_cache)
		reservation_compatibility = Callable(WarrenAssetCompiler,
			"parcel_preserves_skywalk_reservation").bind(construction_program,
				asset_cache)
	return WarrenParcelizer.solve(volume, compatibility, connection_pair,
		reservation_compatibility, connection_broad_phase)


static func _parcel_variants(volume: WarrenVolumePlan,
		construction_program: SettlementFabricProgram) -> Array[WarrenParcelPlan]:
	## One volume, several arrangements -- the slack route-first got from
	## searching a pre-filtered candidate space, restored where mass-first can
	## provide it.
	##
	## Mass-first constructs an arrangement rather than searching for one, so a
	## single unbuildable adjacency anywhere used to cost the whole town. The
	## partitioner can already re-serve the same street walls in several
	## deterministic orders; emitting those as separate candidates lets the
	## frontier reject on every gate at once instead of this stage guessing
	## which arrangement will survive stages it cannot see. Duplicates are
	## dropped because different orders often converge on the same partition.
	var out: Array[WarrenParcelPlan] = []
	if GENERATION_MODE != MODE_MASS_FIRST:
		var single := _parcelize(volume, construction_program)
		if single != null:
			out.append(single)
		return out
	var seen: Dictionary = {}
	for variant in WarrenSolidPartitioner.PARTITION_VARIANTS:
		var plan := partition_parcels(volume, variant, construction_program)
		if plan == null:
			continue
		var signature := plan.deterministic_signature()
		if seen.has(signature):
			continue
		seen[signature] = true
		out.append(plan)
	return out


static func partition_parcels(volume: WarrenVolumePlan,
		variant: int = -1,
		construction_program: SettlementFabricProgram = null) -> WarrenParcelPlan:
	## The mass-first parcel stage: houses are the solid a bore left standing,
	## so they are partitioned rather than searched for, and their tops already
	## follow the massif's terraces. WarrenParcelHeightSolver is deliberately
	## NOT run over them -- reassigning heights would flatten exactly the
	## terracing that makes this skyline vary by construction.
	##
	## Every rejection here is ordinary attrition: an unparcelizable candidate
	## is skipped and the frontier continues, the same as a route-first volume
	## whose packing search stopped short. Public for the same reason
	## mass_first_frontier() is -- so this stage's real yield is measurable
	## without composing a town around it.
	last_partition_failure = ""
	if volume == null:
		last_partition_failure = "no volume to partition"
		return null
	var maze_source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if maze_source != null:
		var maze_plan := WarrenMazeBlockPartitioner.partition(maze_source, volume)
		if maze_plan == null:
			last_partition_failure = "maze block partition: %s" \
				% WarrenMazeBlockPartitioner.last_failure
		return maze_plan
	var massif := volume.mass_context.get(&"massif") as WarrenMassif
	var bore := volume.mass_context.get(&"excavation") as WarrenExcavation
	if massif == null or bore == null:
		last_partition_failure = "volume carries no excavated mass context"
		return null
	var excavation := WarrenExcavationVolumeAdapter.excavation_for_volume(bore,
		volume)
	if excavation == null:
		last_partition_failure = WarrenExcavationVolumeAdapter.last_failure
		return null
	var houses := WarrenSolidPartitioner.partition(massif, excavation, volume,
		variant)
	if houses.size() < WarrenSolidPartitioner.MIN_PARCELS:
		last_partition_failure = "solid partition: %s" \
			% WarrenSolidPartitioner.last_failure
		return null
	# The partition's own admission rules decided which walls were housable.
	# street_wall_audit re-derives both the wall set and the reasons a wall may
	# go unhoused from the raw route, massif and void, so a wall this partition
	# stranded lands in `unowned` even when the partitioner agrees with itself.
	# A street with a hole in its wall is not the canyon this mode exists to
	# build, so that is a rejection rather than a diagnostic.
	var wall_audit := WarrenSolidPartitioner.street_wall_audit(houses,
		excavation, massif, volume)
	var unowned := wall_audit["unowned"] as Array[Vector3i]
	if not unowned.is_empty():
		last_partition_failure = "%d of %d street walls belong to no house" \
			% [unowned.size(), int(wall_audit["wall_count"])]
		return null
	var plan := WarrenParcelPlan.new(
		StringName("%s.parcels%s" % [volume.stable_id,
			"" if variant < 0 else ".v%d" % variant]), volume)
	var reservations: Array[Dictionary] = []
	if construction_program != null:
		var exact_realm := WarrenVolumePublicRealmAdapter.from_volume(volume)
		if exact_realm == null:
			last_partition_failure = WarrenVolumePublicRealmAdapter.last_failure
			return null
		var asset_cache := WarrenAssetCompiler.massif_partition_asset_cache(
			houses, volume.world_seed, construction_program)
		if not bool(asset_cache.get(&"enabled", false)):
			last_partition_failure = "could not classify fixed-partition assets: %s" \
				% String(asset_cache.get(&"failure", "unknown failure"))
			return null
		var connection_pair := Callable(WarrenAssetCompiler,
			"skywalk_reservation").bind(construction_program,
				exact_realm.air_claims(), asset_cache)
		var connection_broad_phase := Callable(WarrenAssetCompiler,
			"parcels_may_form_skywalk").bind(construction_program,
				asset_cache)
		var reservation_compatibility := Callable(WarrenAssetCompiler,
			"parcel_preserves_skywalk_reservation").bind(construction_program,
				asset_cache)
		reservations = WarrenParcelizer.fixed_parcel_connection_reservations(
			volume, houses, MASS_FIRST_PLANNED_SKYWALKS, connection_pair,
			reservation_compatibility, connection_broad_phase)
	if not plan.seal(houses, reservations):
		last_partition_failure = "parcel plan rejected after partitioning: %s" \
			% plan.last_rejection
		return null
	return plan


static func last_parcelize_failure() -> String:
	## Whichever parcel stage the current mode actually ran. Reading
	## WarrenParcelizer.last_failure unconditionally would report a stale
	## packing-search message -- or none at all -- for a mass-first rejection.
	return last_partition_failure if GENERATION_MODE == MODE_MASS_FIRST \
		else WarrenParcelizer.last_failure


static func _compose_plan(world_seed: int, volume: WarrenVolumePlan,
		parcels: WarrenParcelPlan,
		optional_infill_limit: int = \
			WarrenPlatformInfillSolver.MAX_OPTIONAL_PATCH_COUNT) -> WarrenTownPlan:
	if not WarrenGroundArcadeSolver.parcels_enclose_arcade(parcels):
		var arcade_audit := WarrenGroundArcadeSolver.arcade_enclosure_audit(parcels)
		last_failure = ("ground arcade lacks exact facade or overhead enclosure " \
			+ "(cells=%d qualified=%.2f grounded=%.2f)") % [
			int(arcade_audit.cell_count), float(arcade_audit.qualified_ratio),
			float(arcade_audit.grounded_ratio)]
		return null
	var pruning := WarrenMassPruner.solve(volume, parcels)
	var realm := WarrenVolumePublicRealmAdapter.from_volume(volume,
		parcels, pruning, optional_infill_limit)
	var surfaces := WarrenVolumeSurfaceCompiler.solve(volume, realm,
		parcels, pruning)
	if pruning == null or realm == null or surfaces == null:
		last_failure = "route failed downstream compilation: %s / %s" % [
			WarrenVolumePublicRealmAdapter.last_failure,
			WarrenVolumeSurfaceCompiler.last_failure]
		return null
	var plan := WarrenTownPlan.new(
		StringName("warren.town.%d" % world_seed), volume, parcels,
		pruning, realm, surfaces)
	if not plan.seal():
		last_failure = plan.last_rejection
		return null
	return plan


static func _passes_construction_gate(parcels: WarrenParcelPlan,
		asset_aware: bool = false) -> bool:
	var maximum_open := ASSET_AWARE_MAX_CORE_OPEN_RATIO \
		if asset_aware else MAX_URBAN_CORE_OPEN_RATIO
	var minimum_parcels := ASSET_AWARE_MIN_COMPLETE_PARCELS \
		if asset_aware else MIN_COMPLETE_PARCELS
	var minimum_contact := MASS_FIRST_MIN_BUILDING_CONTACT_RATIO \
		if parcels.source.mass_context.has(&"massif") \
		else ASSET_AWARE_MIN_BUILDING_CONTACT_RATIO
	return parcels.is_sealed() \
		and int(parcels.audit.parcel_count) >= minimum_parcels \
		and (not asset_aware or int(parcels.audit.get(
			"parcel_footprint_cell_count", 0)) \
			>= ASSET_AWARE_MIN_FOOTPRINT_CELLS) \
		and int(parcels.audit.base_band_count) >= (
			ASSET_AWARE_MIN_BASE_BAND_COUNT if asset_aware else 3) \
		and (not asset_aware or int(parcels.audit.get("roof_band_count", 0)) \
			>= ASSET_AWARE_MIN_ROOF_BAND_COUNT) \
		and (not asset_aware or float(parcels.audit.get(
			"largest_roof_band_ratio", 1.0)) \
			<= ASSET_AWARE_MAX_LARGEST_ROOF_BAND_RATIO) \
		and (not asset_aware or float(parcels.audit.get(
			"largest_building_contact_component_cell_ratio", 0.0)) \
			>= minimum_contact) \
		and (not asset_aware or float(parcels.audit.get(
			"contacted_building_ratio", 0.0)) \
			>= ASSET_AWARE_MIN_CONTACTED_BUILDING_RATIO) \
		and (not asset_aware or float(parcels.audit.get(
			"isolated_building_cell_ratio", 1.0)) \
			<= ASSET_AWARE_MAX_ISOLATED_BUILDING_CELL_RATIO) \
		and (not asset_aware or int(parcels.audit.get(
			"neighboring_parcel_pair_count", 0)) \
			>= ASSET_AWARE_MIN_NEIGHBORING_PARCEL_PAIRS) \
		and int(parcels.audit.footprint_family_count) >= 3 \
		# The route itself proves physical half-band transitions. Logical-only
		# plans additionally demand touching half-offset parcels; measured pitched
		# roofs may legitimately forbid that adjacency when their eaves intersect.
		and (asset_aware \
			or int(parcels.audit.half_level_neighbor_pair_count) >= 1) \
		and (not asset_aware or float(parcels.audit.all_two_sided_walk_ratio) \
			>= ASSET_AWARE_MIN_TWO_SIDED_WALK_RATIO) \
		and int(parcels.audit.get(
			"unaddressed_elevated_gallery_terminal_count", 0)) == 0 \
		and float(parcels.audit.urban_core_open_column_ratio) <= maximum_open


static func _construction_score(volume: WarrenVolumePlan,
		parcels: WarrenParcelPlan,
		construction_program: SettlementFabricProgram = null) -> float:
	var skywalk_opportunities := WarrenAssetCompiler.skywalk_opportunity_count(
		parcels, construction_program) if construction_program != null else 0
	# Logical corpora can prefer raw vertically shared columns aggressively. In
	# measured construction, roof/eave clearance and exterior-air continuity are
	# stronger facts, so stacking remains a preference rather than dominating a
	# complete compatible town.
	var stacked_column_weight := 230.0 if construction_program != null else 1200.0
	var occupied_overpass_weight := 120.0 \
		if construction_program != null else 900.0
	# Opposing fronts are the construction-level difference between a maze alley
	# and isolated buildings beside open space. One additional parcel is not
	# worth discarding a topology which can make several such corridors.
	return WarrenPublicRealmCarver.topology_score(volume) * 0.08 \
		- float(parcels.audit.parcel_count) * 90.0 \
		- float(parcels.audit.get("parcel_footprint_cell_count", 0)) * 75.0 \
		- float(parcels.audit.get("base_band_count", 0)) * 650.0 \
		+ float(parcels.audit.get("largest_base_band_ratio", 1.0)) * 4200.0 \
		+ float(parcels.audit.get("largest_roof_band_ratio", 1.0)) * 2800.0 \
		+ float(parcels.audit.get("same_base_neighbor_ratio", 1.0)) * 5200.0 \
		+ float(parcels.audit.get("repeated_row_neighbor_pair_count", 0)) \
			* 9000.0 \
		- float(parcels.audit.bounded_walk_ratio) * 950.0 \
		- float(parcels.audit.two_sided_walk_ratio) * 6000.0 \
		- float(parcels.audit.get("ground_primary_bounded_walk_ratio", 0.0)) \
			* 6000.0 \
		- float(parcels.audit.get("ground_primary_two_sided_walk_ratio", 0.0)) \
			* 12000.0 \
		- float(parcels.audit.get("stepped_roof_neighbor_pair_count", 0)) \
			* 420.0 \
		- float(parcels.audit.get("stepped_descent_tall_parcel_count", 0)) \
			* 900.0 \
		- float(parcels.audit.get("planned_skywalk_count", 0)) * 14000.0 \
		- float(parcels.audit.get(
			"largest_building_contact_component_ratio", 0.0)) * 4200.0 \
		- float(parcels.audit.get("neighboring_parcel_pair_count", 0)) * 320.0 \
		+ float(parcels.audit.get("unstepped_tall_parcel_count", 0)) \
			* 1800.0 \
		- float(parcels.audit.half_level_neighbor_pair_count) * 24.0 \
		- float(parcels.audit.stacked_parcel_column_count) \
			* stacked_column_weight \
		- float(parcels.audit.occupied_overpass_parcel_count) \
			* (occupied_overpass_weight + 500.0) \
		- float(volume.audit.get("elevated_gallery_walk_cell_count", 0)) \
			* 560.0 \
		- float(mini(skywalk_opportunities, 3)) * 520.0 \
		+ float(parcels.audit.get("visually_short_parcel_count", 0)) \
			* 5000.0 \
		+ float(parcels.audit.urban_core_open_column_ratio) * 500.0


static func _gate_distance(parcels: WarrenParcelPlan,
		asset_aware: bool = false) -> float:
	var maximum_open := ASSET_AWARE_MAX_CORE_OPEN_RATIO \
		if asset_aware else MAX_URBAN_CORE_OPEN_RATIO
	var minimum_parcels := ASSET_AWARE_MIN_COMPLETE_PARCELS \
		if asset_aware else MIN_COMPLETE_PARCELS
	return float(maxi(0, minimum_parcels \
		- int(parcels.audit.parcel_count))) * 1000.0 \
		+ (float(maxi(0, ASSET_AWARE_MIN_FOOTPRINT_CELLS \
			- int(parcels.audit.get("parcel_footprint_cell_count", 0)))) \
			* 500.0 if asset_aware else 0.0) \
		+ float(maxi(0, (ASSET_AWARE_MIN_BASE_BAND_COUNT if asset_aware else 3) \
			- int(parcels.audit.base_band_count))) * 600.0 \
		+ (float(maxi(0, ASSET_AWARE_MIN_ROOF_BAND_COUNT \
			- int(parcels.audit.get("roof_band_count", 0)))) * 600.0 \
			if asset_aware else 0.0) \
		+ (maxf(0.0, float(parcels.audit.get(
			"largest_roof_band_ratio", 1.0)) \
			- ASSET_AWARE_MAX_LARGEST_ROOF_BAND_RATIO) * 1000.0 \
			if asset_aware else 0.0) \
		+ (maxf(0.0, ASSET_AWARE_MIN_BUILDING_CONTACT_RATIO \
			- float(parcels.audit.get(
				"largest_building_contact_component_cell_ratio", 0.0))) \
			* 4000.0 if asset_aware else 0.0) \
		+ (maxf(0.0, ASSET_AWARE_MIN_CONTACTED_BUILDING_RATIO \
			- float(parcels.audit.get("contacted_building_ratio", 0.0))) \
			* 4000.0 if asset_aware else 0.0) \
		+ (maxf(0.0, float(parcels.audit.get("isolated_building_cell_ratio",
			1.0)) - ASSET_AWARE_MAX_ISOLATED_BUILDING_CELL_RATIO) * 4000.0 \
			if asset_aware else 0.0) \
		+ (float(maxi(0, ASSET_AWARE_MIN_NEIGHBORING_PARCEL_PAIRS \
			- int(parcels.audit.get("neighboring_parcel_pair_count", 0)))) \
			* 800.0 if asset_aware else 0.0) \
		+ float(maxi(0, 3 - int(parcels.audit.footprint_family_count))) * 500.0 \
		+ float(int(parcels.audit.half_level_neighbor_pair_count) < 1) * 400.0 \
		+ float(parcels.audit.get(
			"unaddressed_elevated_gallery_terminal_count", 0)) * 1800.0 \
		+ (maxf(0.0, ASSET_AWARE_MIN_TWO_SIDED_WALK_RATIO \
			- float(parcels.audit.all_two_sided_walk_ratio)) * 4000.0 \
			if asset_aware else 0.0) \
		+ maxf(0.0, float(parcels.audit.urban_core_open_column_ratio) \
			- maximum_open) \
			* 1000.0
