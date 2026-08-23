class_name WarrenVolumetricSolver
extends RefCounted

## First production front end for the fine-grid volumetric architecture.  It
## reuses the proven terrain-grounded massif and bore as topology input, then
## abandons the old extrusion interpretation: remaining mass is assigned to
## offset 3D room volumes, exact interfaces, and an explicit support DAG.
## Village-scale floor: a rescaled compact hamlet legitimately forms six to
## eight buildings; anything below this still reads as a farmstead, not a town.
const MIN_BUILDINGS := 6
const GRID_PADDING_CELLS := 2
const ROOF_CLEARANCE_CELLS := 2
const MAX_PARTITION_VARIANTS := WarrenSolidPartitioner.PARTITION_VARIANTS
const MAX_LANDMARK_SET_ATTEMPTS := 12
## Complete-building selection used to enumerate only pairs/triples. A bounded
## deterministic beam admits richer four-to-eight building sets without the
## O(candidate_count^N) explosion that would prevent real-time generation.
const MAX_LANDMARK_SET_BEAM := 192
## Bounded exact hero-feature frontier. Endpoint-compatible skywalk
## combinations are proved through the exact room composition and the sealed
## survivors are ranked by final recipe occluder route coverage; these bounds
## keep that proof affordable while still offering genuinely diverse sets.
const MAX_OCCLUDER_RANK_TRIALS := 3
const MAX_OCCLUDER_RANK_SCAN := 24
const RESIDUAL_OVERHEAD_ROUTE_CELL_SCORE := 50000
const RESIDUAL_FRONTAGE_SIDE_SCORE := 15000
const RESIDUAL_TERRAIN_ROOT_SCORE := 35000
## Formerly 8000: rewarding massif-edge contact scattered freestanding rim
## houses around the village. Edge taper is welcome only when a candidate
## also leans on the town, which the mandatory established-contact rule now
## enforces, so the edge itself earns nothing.
const RESIDUAL_MASSIF_EDGE_COLUMN_SCORE := 0
## A roof court is selected from already-inhabited, coplanar room crowns before
## composed features or roofs spend the same air.  These are deliberately broad
## rectangles: a two-cell strip is a gallery, not the elevated civic space this
## pass is meant to create.  Larger shapes rank first, with the two orientations
## kept explicit so the deterministic search can fit either street bearing.
const ROOFTOP_COURT_SHAPES: Array[Vector2i] = [
	Vector2i(5, 4), Vector2i(4, 5), Vector2i(4, 4),
	Vector2i(4, 3), Vector2i(3, 4),
]
const MIN_ROOFTOP_COURT_LIFT_CELLS := WarrenSpatialGrid.STOREY_CELLS
## Screenshot-backed production gates. A town with every requested feature can
## still read as isolated facades around an open plaza; require the compiled
## exterior realm to keep most long views broken and a substantial fraction of
## the route physically under inhabited mass.
const MIN_PRODUCTION_OVERHEAD_ROUTE_RATIO := 0.38
## Enclosure GUIDANCE, not a production gate (2026-08-16). These are the
## through/ground sightline counts a town should read with; the precomposition
## ranking already penalises the proxy counts (_precomposition_quality_score),
## and reviewed enclosure comes from housing density (lanes reaching the
## interior), not from discarding a composed town after the fact. Profiling
## showed ~200 s of a 365 s search spent on towns rejected by this check at
## the very end. Kept as the reference values tests and audits compare against.
const MAX_PRODUCTION_THROUGH_SIGHTLINES := 48
const MAX_PRODUCTION_GROUND_THROUGH_SIGHTLINES := 20
## A bazaar must read as a chamber in the inhabited maze, not a canopy beside
## the town. Every aisle sight ray must meet market body or future building mass
## within this many 1.5 m cells.
const MAX_MARKET_OPEN_HORIZON_CELLS := 4
const LARGE_MARKET_OPEN_HORIZON_CELLS := 8
const GRAND_MARKET_OPEN_HORIZON_CELLS := 10
## Landmark halls are allowed to replace ordinary parcels, but they must still
## read as part of the inhabited mountain. Measure surviving private mass just
## beyond the landmark's authored visual envelope; the exact gap remains a
## ranking fact while the later typed public-realm transaction decides whether
## the space is a street rather than rejecting complete buildings prematurely.
const LANDMARK_CITY_CONTACT_RADIUS_CELLS := 4
## One fine cell of actual public circulation may sit between a complete
## authored building and the retained mass: that is a 1.5 m carved alley, not
## open lawn. The embeddedness probe validates that intervening cell against
## the sealed public-air/public-floor graph before this distance is credited.
const MAX_LANDMARK_CITY_GAP_CELLS := 2
const COURTYARD_BRIDGE_FEATURE_ID := \
	&"spatial.feature.courtyard_bridge_house.00"
## The third courtyard side may be a real occupied bridge-house selected by the
## joint 3D feature transaction.  The parcel partition must still supply two
## independent room walls; the complete spatial proof below requires all three.
const MIN_COURT_PARCEL_SIDE_COUNT := 2
## Macro composition may grow the court's own endpoint room across the authored
## attachment socket.  The joint exact solve is allowed to recompose only that
## one fine-grid (3 m x 1.5 m) socket strip; unrelated room mass remains a hard
## conflict and larger self-conflicts are not waved through.
const MAX_COURT_OWNER_SOCKET_RECOMPOSITION_CELLS := 2
## The five authored room shells as MACRO footprints, largest first. `width`
## runs across the parcel's frontage and `depth` along it, which is exactly the
## reading `WarrenBuildingParcel.seal` and `WarrenParcelConstruction`'s own
## `profile_for` give a parcel's rectangle -- so a back room's kind means the
## same thing as the kind of the house standing in front of it. Used only by
## the directed maze back-room pass; the greedy residual scan enumerates
## `WarrenRoomStamp.KINDS` directly because it has no frontage to reckon from.
const MAZE_BACK_ROOM_KINDS: Array[Dictionary] = [
	{"kind": &"long", "width": 2, "depth": 3},
	{"kind": &"building", "width": 2, "depth": 2},
	{"kind": &"slim", "width": 1, "depth": 2},
	{"kind": &"row", "width": 2, "depth": 1},
	{"kind": &"tower", "width": 1, "depth": 1},
]

static var last_failure := ""
## Facts about the most recent staged production search: whether it visited
## every attempt in the rotation (false when a time budget stopped it early)
## and how many attempts have been tried including skipped prefixes, so a
## budgeted caller can resume the deterministic rotation without repetition.
static var last_search_exhausted := true
static var last_search_attempts_tried := 0
## Deadline for the current budgeted search in Time.get_ticks_msec() terms,
## or -1 for unbudgeted solves. _solve_frontier honors it between ranked
## candidates and reports crossing it through _frontier_budget_hit.
static var _search_deadline_ms := -1
static var _frontier_budget_hit := false
static var last_diagnostic: Dictionary = {}
static var last_preplan_skywalk_diagnostic: Dictionary = {}
static var last_preplan_market_diagnostic: Dictionary = {}
static var last_preplan_landmark_diagnostic: Dictionary = {}
static var _last_skywalk_selection_failure := ""
## Harness-only performance seam. Production never sets this; it lets a probe
## stop after geometric/fixed-block skywalk filtering instead of paying for the
## endpoint-composition beam while diagnosing candidate growth.
## Richness quotas a one-pass solve fell short of but shipped anyway. Empty in
## every searched mode. Merged into the sealed plan's audit so a plain town is
## a visible, reviewable fact rather than a silent one.
static var last_advisory_shortfalls: Dictionary = {}
static var diagnostic_stop_after_skywalk_candidates := false
static var diagnostic_stop_after_skywalk_individual := false
static var diagnostic_skywalk_candidate_limit := -1
static var diagnostic_trace_skywalk_timing := false
static var diagnostic_trace_room_gate := false
static var diagnostic_feature_market_limit := -1
static var diagnostic_partition_limit := -1
static var diagnostic_partition_first := 0
## Compact/standard towns may form a broad route-connected roof court only
## after the exact room fixed point. The cheap parcel proxy cannot predict it,
## so inspect a small deterministic prefix of otherwise valid variants before
## accepting the first courtless fallback. Three reaches the complete alternate
## serving phase without turning the eight-variant family into an exhaustive
## in-game search.
const ROUTE_COURT_VARIANT_PROBE_COUNT := 3
## Bridge-room admission telemetry for the residual backfill pass; reset per
## backfill run and surfaced through the residual audit keys.
static var _residual_bridge_counts: Dictionary = {}


static func solve(world_seed: int,
		ground_bands: Dictionary = {},
		construction_program: SettlementFabricProgram = null,
		scale_profile: WarrenVillageScaleProfile = null,
		max_solve_ms: int = -1, skip_attempts: int = 0) -> WarrenSpatialPlan:
	last_failure = ""
	last_diagnostic = {}
	last_preplan_skywalk_diagnostic = {}
	last_preplan_market_diagnostic = {}
	last_preplan_landmark_diagnostic = {}
	if construction_program == null:
		last_failure = "volumetric feature search requires measured construction vocabulary"
		return null
	var profile := scale_profile if scale_profile != null \
		else WarrenVillageScaleProfile.review_fixture()
	if WarrenTownSolver.GENERATION_MODE == WarrenTownSolver.MODE_MAZE:
		# Solid-first: one deterministic carve, no attempt rotation, no ranked
		# candidate corpus. There is nothing to resume, so a budgeted caller's
		# slice bookkeeping collapses to a single completed attempt.
		last_search_exhausted = true
		last_search_attempts_tried = 1
		return _solve_maze(world_seed, ground_bands, construction_program,
			profile)
	# A bore is itself an expensive bounded search. Visit every attempt exactly
	# once in a seed-rotated coprime cycle and exact-solve each surviving family
	# immediately. This preserves the complete fallback corpus, prevents every
	# town from sharing attempt-zero's street grammar, and avoids paying for three
	# full bores before construction has had a chance to accept the first one.
	var batch_count := 0
	var attempted_count := 0
	var batch_failures := PackedStringArray()
	var search_started_ms := Time.get_ticks_msec()
	last_search_exhausted = true
	last_search_attempts_tried = skip_attempts
	var attempt_order := _production_attempt_order(world_seed)
	for attempt_index in attempt_order.size():
		# A budgeted caller (the in-game terrain worker) resumes a sliced
		# search exactly where the previous slice stopped: the rotation is
		# deterministic, so skipping the already-tried prefix repeats no work.
		if attempt_index < skip_attempts:
			continue
		if max_solve_ms >= 0 and attempt_index > skip_attempts \
				and Time.get_ticks_msec() - search_started_ms > max_solve_ms:
			last_search_exhausted = false
			last_failure = ("production search budget %d ms exhausted after " \
				+ "%d of %d attempts") % [max_solve_ms,
				last_search_attempts_tried, attempt_order.size()]
			return null
		var attempt: int = attempt_order[attempt_index]
		attempted_count += 1
		last_search_attempts_tried = attempt_index + 1
		# The first attempt of a budgeted slice always runs to completion so
		# every visit makes real progress and no candidate is ever skipped;
		# later attempts honor the deadline mid-frontier and are re-run whole
		# on the next visit.
		var first_of_slice := attempt_index == skip_attempts
		_search_deadline_ms = -1 if max_solve_ms < 0 or first_of_slice \
			else search_started_ms + max_solve_ms
		_frontier_budget_hit = false
		var frontier_started_ms := Time.get_ticks_msec()
		var frontier := WarrenTownSolver.mass_first_attempt_frontier(world_seed,
			attempt, ground_bands, profile)
		if diagnostic_trace_skywalk_timing:
			print("SKYWALK_TIMING frontier_attempt index=", attempt,
				" ms=", Time.get_ticks_msec() - frontier_started_ms,
				" candidates=", frontier.size())
		if frontier.is_empty():
			batch_failures.append("attempt %d: %s" % [attempt,
				WarrenTownSolver.last_failure])
			continue
		batch_count += 1
		var result := _solve_frontier(frontier, construction_program)
		_search_deadline_ms = -1
		if result != null:
			result.audit["production_excavation_attempt_count"] = attempted_count
			result.audit["production_frontier_batch_count"] = batch_count
			result.audit["production_staged_frontier_count"] = frontier.size()
			result.audit["production_selected_attempt"] = attempt
			return result
		if _frontier_budget_hit:
			last_search_exhausted = false
			last_search_attempts_tried = attempt_index
			last_failure = ("production search budget %d ms reached inside " \
				+ "attempt %d; it reruns whole next visit") % [max_solve_ms,
				attempt]
			return null
		batch_failures.append("attempt %d: %s" % [attempt, last_failure])
	last_failure = "no staged volumetric frontier sealed: %s" % \
		" | ".join(batch_failures)
	return null


static func _solve_maze(world_seed: int, ground_bands: Dictionary,
		construction_program: SettlementFabricProgram,
		profile: WarrenVillageScaleProfile) -> WarrenSpatialPlan:
	## MODE_MAZE production entry. The whole point of the solid-first front end
	## is that the source is correct by construction, so there is exactly one
	## source, one partition, and one composition. A rejection here is a real
	## defect in the site plan or a gate it has not yet learned to satisfy — it
	## is never retried with a different bore.
	##
	## The source is the site planner's whole one-pass pipeline (massif ->
	## carve -> reserve -> partition -> seal), never the bare bore: a plan
	## without plots carries no town to translate, and the block partitioner
	## rightly refuses one.
	var started_ms := Time.get_ticks_msec()
	last_advisory_shortfalls = {}
	var maze := WarrenMazeSitePlanner.plan(world_seed, ground_bands, profile)
	if maze == null:
		last_failure = "maze source rejected: %s" \
			% WarrenMazeSitePlanner.last_failure
		return null
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(maze)
	if volume == null:
		last_failure = "maze volume adapter rejected: %s" \
			% WarrenMazeVolumeAdapter.last_failure
		return null
	var source_ms := Time.get_ticks_msec() - started_ms
	var spatial_started_ms := Time.get_ticks_msec()
	# The maze partitioner is deterministic and ignores the variant index, so
	# the eight-variant rotation is meaningless here: pass -1 for "the one".
	var plan := from_volume(volume, -1, construction_program,
		profile.requires_elevated_courtyard)
	var spatial_ms := Time.get_ticks_msec() - spatial_started_ms
	if plan == null:
		last_failure = "maze composition rejected: %s" % last_failure
		return null
	var fabric_started_ms := Time.get_ticks_msec()
	var fabric := WarrenSpatialFabricCompiler.solve(plan, construction_program)
	var fabric_ms := Time.get_ticks_msec() - fabric_started_ms
	if fabric == null:
		last_failure = "maze fabric gate failed: %s" \
			% WarrenSpatialFabricCompiler.last_failure
		return null
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING maze_source ms=", source_ms)
		print("SKYWALK_TIMING partition_spatial source=", volume.stable_id,
			" variant=-1 ms=", spatial_ms, " accepted=", true)
		print("SKYWALK_TIMING partition_fabric source=", volume.stable_id,
			" variant=-1 ms=", fabric_ms, " accepted=", true)
	var finalized := _finalize_ranked_candidate(volume, -1,
		construction_program, {}, plan, fabric)
	if finalized == null:
		last_failure = "maze finalization rejected: %s" % last_failure
		return null
	finalized.audit["production_generation_mode"] = String(
		WarrenTownSolver.MODE_MAZE)
	finalized.audit["production_excavation_attempt_count"] = 1
	finalized.audit["production_frontier_batch_count"] = 1
	finalized.audit["production_staged_frontier_count"] = 1
	finalized.audit["production_selected_attempt"] = 0
	finalized.audit["route_court_variant_probe_count"] = 1
	finalized.audit["route_court_variant_fallback_used"] = false
	finalized.audit["maze_source_ms"] = source_ms
	finalized.audit["advisory_shortfalls"] = last_advisory_shortfalls.duplicate()
	finalized.audit["advisory_shortfall_count"] = last_advisory_shortfalls.size()
	return finalized


static func solve_pinned(world_seed: int, ground_bands: Dictionary,
		construction_program: SettlementFabricProgram, pin: Dictionary,
		scale_profile: WarrenVillageScaleProfile = null) -> WarrenSpatialPlan:
	## Deterministic fast path: re-seal a previously selected candidate without
	## repeating the staged search. The pin is a hint, never trusted state:
	## the complete pipeline — composition, fabric compile, production quality
	## gates, finalization — reruns from scratch, and any mismatch or failure
	## returns null so the caller falls back to the full search. A stale pin
	## can therefore cost only time, never correctness.
	last_failure = ""
	if construction_program == null:
		last_failure = "pinned volumetric solve requires measured vocabulary"
		return null
	if WarrenTownSolver.GENERATION_MODE == WarrenTownSolver.MODE_MAZE:
		# Solid-first generation has one source per town, so a pin carries no
		# information the carve does not already reproduce. Re-solve directly
		# rather than failing and driving the caller into a search that does
		# not exist in this mode.
		return _solve_maze(world_seed, ground_bands, construction_program,
			scale_profile if scale_profile != null \
				else WarrenVillageScaleProfile.review_fixture())
	if pin.is_empty() or not pin.has("attempt") or not pin.has("source_id") \
			or not pin.has("variant"):
		last_failure = "pinned volumetric solve requires attempt/source/variant"
		return null
	var profile := scale_profile if scale_profile != null \
		else WarrenVillageScaleProfile.review_fixture()
	var frontier := WarrenTownSolver.mass_first_attempt_frontier(world_seed,
		int(pin.attempt), ground_bands, profile)
	for volume: WarrenVolumePlan in frontier:
		if String(volume.stable_id) != String(pin.source_id):
			continue
		var variant := int(pin.variant)
		var proxy := _precomposition_enclosure_audit(volume, variant,
			construction_program)
		var plan := from_volume(volume, variant, construction_program, false)
		if plan == null:
			return null
		for key: Variant in proxy.keys():
			plan.audit["precomposition_%s" % String(key)] = proxy[key]
		var fabric := WarrenSpatialFabricCompiler.solve(plan,
			construction_program)
		if fabric == null:
			last_failure = "pinned fabric gate failed: %s" \
				% WarrenSpatialFabricCompiler.last_failure
			return null
		var finalized := _finalize_selected_candidate(volume, variant,
			construction_program, proxy, plan, fabric)
		if finalized != null:
			finalized.audit["production_selected_attempt"] = int(pin.attempt)
			finalized.audit["production_selected_source_id"] = \
				String(pin.source_id)
			finalized.audit["production_selected_variant"] = variant
			finalized.audit["production_pin_hit"] = true
		return finalized
	last_failure = "pinned source %s absent from attempt %d frontier" % [
		String(pin.get("source_id", "")), int(pin.get("attempt", -1))]
	return null


static func _production_attempt_order(world_seed: int) -> Array[int]:
	var out: Array[int] = []
	var count := WarrenTownSolver.MASS_FIRST_EXCAVATION_ATTEMPTS
	var start := posmod(Helper._mix64(world_seed ^ 2), count)
	# Five is coprime with the twelve-attempt production corpus, so the cycle
	# cannot repeat or omit an attempt before exhausting the bounded fallback.
	for offset in count:
		out.append(posmod(start + offset * 5, count))
	return out


static func _solve_frontier(frontier: Array[WarrenVolumePlan],
		construction_program: SettlementFabricProgram) -> WarrenSpatialPlan:
	# Rank complete (topology, parcel-variant) pairs by the mass that will survive
	# as actual rooms. The macro massif's overhang score includes allocation later
	# discarded by _discard_unassigned_mass(), which is why a nominally 78%-covered
	# source produced the visually open 34% town caught by screenshot review.
	# This proxy uses exact fine route floors and proposed private cells, but no
	# market/landmark/skywalk search or authored resource construction, so weak
	# street canyons are rejected cheaply before the expensive 3D composition.
	var ranked_variants := _ranked_precomposition_variants(frontier,
		construction_program)
	if ranked_variants.is_empty():
		last_failure = "no volumetric parcel variant retained inhabited mass"
		return null
	var failures := PackedStringArray()
	var partition_attempt_count := 0
	var courtless_fallback_plan: WarrenSpatialPlan
	var courtless_fallback_fabric: SettlementFabricPlan
	var courtless_fallback_volume: WarrenVolumePlan
	var courtless_fallback_audit: Dictionary = {}
	var courtless_fallback_variant := -1
	var courtless_fallback_rank := -1
	for ranked_index in ranked_variants.size():
		if ranked_index < diagnostic_partition_first:
			continue
		if _search_deadline_ms >= 0 and partition_attempt_count > 0 \
				and Time.get_ticks_msec() > _search_deadline_ms:
			if courtless_fallback_plan != null:
				var timed_fallback := _finalize_ranked_candidate(
					courtless_fallback_volume, courtless_fallback_variant,
					construction_program, courtless_fallback_audit,
					courtless_fallback_plan, courtless_fallback_fabric)
				if timed_fallback != null:
					timed_fallback.audit["route_court_variant_probe_count"] = \
						partition_attempt_count
					timed_fallback.audit[
						"route_court_variant_fallback_used"] = true
					return timed_fallback
			_frontier_budget_hit = true
			last_failure = "search budget reached after %d ranked candidates" \
				% partition_attempt_count
			return null
		var ranked := ranked_variants[ranked_index] as Dictionary
		if diagnostic_partition_limit >= 0 \
				and partition_attempt_count >= diagnostic_partition_limit:
			break
		var volume := ranked.volume as WarrenVolumePlan
		var variant := int(ranked.variant)
		if courtless_fallback_plan != null and (volume \
				!= courtless_fallback_volume or ranked_index \
				>= courtless_fallback_rank + ROUTE_COURT_VARIANT_PROBE_COUNT):
			var fallback := _finalize_ranked_candidate(
				courtless_fallback_volume, courtless_fallback_variant,
				construction_program, courtless_fallback_audit,
				courtless_fallback_plan, courtless_fallback_fabric)
			if fallback != null:
				fallback.audit["route_court_variant_probe_count"] = \
					partition_attempt_count
				fallback.audit["route_court_variant_fallback_used"] = true
				return fallback
		partition_attempt_count += 1
		if diagnostic_trace_room_gate:
			print("SKYWALK_TIMING partition_begin source=", volume.stable_id,
				" variant=", variant, " proxy=", ranked.audit)
		# Candidate search uses the cheaper serial fixed point. The paired
		# silhouette cleanup changes no hero-feature topology, so paying for it in
		# every rejected topology/partition trial only multiplies exact room work.
		var spatial_started_ms := Time.get_ticks_msec()
		var plan := from_volume(volume, variant, construction_program, false)
		if diagnostic_trace_skywalk_timing:
			print("SKYWALK_TIMING partition_spatial source=", volume.stable_id,
				" variant=", variant, " ms=",
				Time.get_ticks_msec() - spatial_started_ms,
				" accepted=", plan != null)
		if plan != null:
			for key: Variant in (ranked.audit as Dictionary).keys():
				plan.audit["precomposition_%s" % String(key)] = ranked.audit[key]
			var fabric_started_ms := Time.get_ticks_msec()
			var fabric := WarrenSpatialFabricCompiler.solve(plan,
				construction_program)
			if diagnostic_trace_skywalk_timing:
				print("SKYWALK_TIMING partition_fabric source=", volume.stable_id,
					" variant=", variant, " ms=",
					Time.get_ticks_msec() - fabric_started_ms,
					" accepted=", fabric != null)
			if fabric == null:
				last_failure = "production fabric gate failed: %s" \
					% WarrenSpatialFabricCompiler.last_failure
			else:
				# Enclosure and size metrics (sightlines, overhead, alley ratio,
				# room count) are guidance carried in the audit and the ranking,
				# never a reason to discard a compiled town here.
				var profile := _scale_profile_for_volume(volume)
				var prefer_route_court := profile != null \
					and not profile.requires_elevated_courtyard
				var has_route_court := int(plan.audit.get(
					"route_connected_rooftop_court_count", 0)) > 0
				if prefer_route_court and not has_route_court:
					if courtless_fallback_plan == null:
						courtless_fallback_plan = plan
						courtless_fallback_fabric = fabric
						courtless_fallback_volume = volume
						courtless_fallback_audit = (ranked.audit \
							as Dictionary).duplicate(true)
						courtless_fallback_variant = variant
						courtless_fallback_rank = ranked_index
					continue
				var finalize_started_ms := Time.get_ticks_msec()
				var finalized := _finalize_ranked_candidate(volume,
					variant, construction_program, ranked.audit as Dictionary,
					plan, fabric)
				if diagnostic_trace_skywalk_timing:
					print("SKYWALK_TIMING partition_finalize source=",
						volume.stable_id, " variant=", variant, " ms=",
						Time.get_ticks_msec() - finalize_started_ms,
						" accepted=", finalized != null)
				if finalized != null:
					finalized.audit["route_court_variant_probe_count"] = \
						partition_attempt_count
					finalized.audit["route_court_variant_fallback_used"] = false
					return finalized
		if diagnostic_trace_room_gate:
			print("SKYWALK_TIMING partition_rejected source=", volume.stable_id,
				" variant=", variant, " failure=", last_failure.left(1200))
		failures.append("%s/v%d: %s" % [String(volume.stable_id),
			variant, last_failure])
	if courtless_fallback_plan != null:
		var fallback := _finalize_ranked_candidate(courtless_fallback_volume,
			courtless_fallback_variant, construction_program,
			courtless_fallback_audit, courtless_fallback_plan,
			courtless_fallback_fabric)
		if fallback != null:
			fallback.audit["route_court_variant_probe_count"] = \
				partition_attempt_count
			fallback.audit["route_court_variant_fallback_used"] = true
			return fallback
	last_failure = "no volumetric partition sealed: %s" % " | ".join(failures)
	return null


static func _finalize_ranked_candidate(volume: WarrenVolumePlan, variant: int,
		construction_program: SettlementFabricProgram,
		precomposition_audit: Dictionary, plan: WarrenSpatialPlan,
		fabric: SettlementFabricPlan) -> WarrenSpatialPlan:
	var finalized := _finalize_selected_candidate(volume, variant,
		construction_program, precomposition_audit, plan, fabric)
	if finalized != null:
		last_failure = ""
		finalized.audit["production_selected_source_id"] = \
			String(volume.stable_id)
		finalized.audit["production_selected_variant"] = variant
	return finalized


static func _finalize_selected_candidate(volume: WarrenVolumePlan,
		variant: int, construction_program: SettlementFabricProgram,
		precomposition_audit: Dictionary, proven_serial: WarrenSpatialPlan,
		proven_serial_fabric: SettlementFabricPlan) -> WarrenSpatialPlan:
	## Search proves hero topology and production sightline quality with the
	## serial room fixed point. Prefer one bounded paired silhouette cleanup, then
	## rerun every authored-envelope and compiled quality gate. A paired exchange
	## is optional construction refinement, however: if it makes a previously
	## borne exact interface unrepairable, retain the already-proven serial
	## composition instead of throwing away the entire town. Both alternatives
	## pass the same support, overlap, feature, and production-quality gates.
	var profile := _scale_profile_for_volume(volume)
	if profile != null and not profile.requires_elevated_courtyard:
		# Compact/standard composition already ran merge, coupling, volumetric
		# variation, tower relief, and the complete exact fabric gate. The paired
		# pass changes at most a bounded optional pair, but previously rebuilt the
		# whole market/skywalk/room transaction and doubled first-load time. Keep it
		# for the large court silhouettes it was introduced to repair.
		for key: StringName in [&"frontage_ratio", &"overhead_route_ratio",
				&"through_sightline_count", &"ground_through_sightline_count"]:
			proven_serial.audit[key] = proven_serial_fabric.audit.get(key, 0)
		proven_serial.audit["paired_registration_finalization_count"] = 0
		proven_serial.audit[
			"paired_registration_scale_skip_count"] = 1
		proven_serial.audit["serial_finalization_reuse_count"] = 1
		proven_serial.cache_compiled_fabric(proven_serial_fabric)
		return proven_serial
	var failures := PackedStringArray()
	var finalized := from_volume(volume, variant, construction_program, true)
	if finalized == null:
		failures.append("paired room seal: %s" % last_failure)
	else:
		for key: Variant in precomposition_audit.keys():
			finalized.audit["precomposition_%s" % String(key)] = \
				precomposition_audit[key]
		var fabric := WarrenSpatialFabricCompiler.solve(finalized,
			construction_program)
		if fabric == null:
			failures.append("paired fabric gate: %s" % \
				WarrenSpatialFabricCompiler.last_failure)
		else:
			for key: StringName in [&"frontage_ratio", &"overhead_route_ratio",
					&"through_sightline_count",
					&"ground_through_sightline_count"]:
				finalized.audit[key] = fabric.audit.get(key, 0)
			finalized.audit[
				"paired_registration_finalization_count"] = 1
			finalized.audit["serial_finalization_fallback_count"] = 0
			finalized.audit["paired_registration_scale_skip_count"] = 0
			finalized.cache_compiled_fabric(fabric)
			return finalized
	# The serial candidate passed the exact fabric gate
	# immediately before this call. Rebuilding it after an optional paired pass
	# fails is output-identical but was one of the largest first-load costs.
	if proven_serial != null and proven_serial_fabric != null:
		for key: StringName in [&"frontage_ratio", &"overhead_route_ratio",
				&"through_sightline_count", &"ground_through_sightline_count"]:
			proven_serial.audit[key] = proven_serial_fabric.audit.get(key, 0)
		proven_serial.audit["paired_registration_finalization_count"] = 0
		proven_serial.audit["serial_finalization_fallback_count"] = 1
		proven_serial.audit["paired_registration_scale_skip_count"] = 0
		proven_serial.audit["serial_finalization_reuse_count"] = 1
		proven_serial.cache_compiled_fabric(proven_serial_fabric)
		return proven_serial
	last_failure = "final room cleanup rejected: %s" % " | ".join(failures)
	return null


## Guidance values (never gates — see the note above
## MAX_PRODUCTION_THROUGH_SIGHTLINES): the reviewed alley-bounded walk ratio a
## scale's towns should read with, for ranking and audits.
static func minimum_production_alley_ratio(audit: Dictionary) -> float:
	## The reviewed street character: walk cells inside an alley at most
	## three cells wide with real built edges on both flanks. Floors are
	## corpus-measured, never aspirational: standard villages measured
	## 0.30-0.53 at precomposition across six seeds and 0.33 sealed on the
	## pinned fixture, so 0.30 gates regressions without rejecting any
	## measured survivor. Other scales stay ungated until their corpus is
	## measured.
	var profile := WarrenVillageScaleProfile.for_id(StringName(
		audit.get("scale_profile_id", "")))
	if profile == null:
		return 0.0
	return 0.30 if profile.scale_id == WarrenVillageScaleProfile.STANDARD \
		else 0.0


static func minimum_production_overhead_ratio(audit: Dictionary) -> float:
	## One occupied skywalk covers a nearly fixed number of fine route cells,
	## while route length and the required feature count scale independently.
	## Treating the large showcase's 38% target as a compact-town invariant made
	## an otherwise tight 45-cell covered alley fail solely because it did not own
	## the large profile's third bridge and elevated court. Long/ground sightline
	## gates remain identical at every scale, so this changes town extent rather
	## than allowing open streets or decorative overhead to masquerade as mass.
	var profile_id := StringName(audit.get("scale_profile_id", &""))
	var profile := WarrenVillageScaleProfile.for_id(profile_id)
	return profile.minimum_inhabited_overhead_ratio if profile != null \
		else MIN_PRODUCTION_OVERHEAD_ROUTE_RATIO


static func solve_selected(world_seed: int, selected: WarrenSpatialPlan,
		ground_bands: Dictionary = {},
		construction_program: SettlementFabricProgram = null) -> WarrenSpatialPlan:
	## Rebuild exactly one flat-preview topology against local terrain.  Production
	## placement must not pay for the complete twelve-bore and eight-partition
	## search again for every yaw, nor silently switch to a different maze after
	## the road has already been aligned to the preview entrance.
	last_failure = ""
	if selected == null or not selected.is_sealed() \
			or selected.source_volume == null or construction_program == null:
		last_failure = "selected volumetric preview is missing or unsealed"
		return null
	var attempt := WarrenTownSolver.mass_first_attempt_index(world_seed,
		selected.source_volume)
	if attempt < 0:
		last_failure = "selected preview has no mass-first excavation identity"
		return null
	var profile_id := StringName(selected.source_volume.mass_context.get(
		&"scale_profile_id", WarrenVillageScaleProfile.LARGE))
	var profile := WarrenVillageScaleProfile.for_id(profile_id)
	if profile == null:
		last_failure = "selected preview has an invalid scale profile"
		return null
	var candidates := WarrenTownSolver.mass_first_attempt_frontier(world_seed,
		attempt, ground_bands, profile)
	if candidates.is_empty():
		last_failure = WarrenTownSolver.last_failure
		return null
	var source: WarrenVolumePlan
	for candidate: WarrenVolumePlan in candidates:
		if candidate.stable_id == selected.source_volume.stable_id:
			source = candidate
			break
	if source == null:
		last_failure = "selected gallery topology no longer fits local terrain"
		return null
	var partition_variant := int(selected.audit.get("partition_variant", -1))
	if partition_variant < 0 or partition_variant >= MAX_PARTITION_VARIANTS:
		last_failure = "selected preview has no partition identity"
		return null
	var rebuilt := from_volume(source, partition_variant, construction_program)
	if rebuilt == null:
		return null
	if rebuilt.source_volume.entry_cell != selected.source_volume.entry_cell:
		last_failure = "selected terrain rebuild changed its route entrance"
		return null
	return rebuilt


static func _spatial_topology_less(a: WarrenVolumePlan,
		b: WarrenVolumePlan) -> bool:
	var a_walk := int(a.audit.get("walk_cell_count", 2147483647))
	var b_walk := int(b.audit.get("walk_cell_count", 2147483647))
	if a_walk != b_walk:
		return a_walk < b_walk
	var a_interior := int(a.audit.get("exact_route_interior_cell_count",
		2147483647))
	var b_interior := int(b.audit.get("exact_route_interior_cell_count",
		2147483647))
	if a_interior != b_interior:
		return a_interior < b_interior
	return WarrenPublicRealmCarver.topology_score(a) \
		< WarrenPublicRealmCarver.topology_score(b)


static func _ranked_precomposition_variants(
		frontier: Array[WarrenVolumePlan],
		construction_program: SettlementFabricProgram) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	for volume: WarrenVolumePlan in frontier:
		# Partition rotations alter local room choices but not the street network;
		# one canonical VALID projection is sufficient to rank source volumes.
		# Measuring all eight routinely cost almost a minute, but assuming variant
		# zero existed became incorrect once the tapered buildable frontier gained a
		# hard grounding audit: a serving order can strand a raised edge parcel even
		# when another order grounds the identical street topology. Probe later
		# variants only as a bounded fallback, then reuse the first survivor's cheap
		# enclosure metric for the complete variant family.
		var audit: Dictionary = {}
		var first_valid_variant := -1
		for audit_variant in MAX_PARTITION_VARIANTS:
			audit = _precomposition_enclosure_audit(volume, audit_variant,
				construction_program)
			if not audit.is_empty():
				first_valid_variant = audit_variant
				break
		if audit.is_empty():
			continue
		# Partition variants are genuinely different macroscopic decompositions,
		# not progressively better retries. A fixed zero-first order made every seed
		# pay for (and, when valid, select) the same serving phase. Rotate the complete
		# coprime cycle from the town seed: all eight remain reachable exactly once,
		# while production gains deterministic facade/roof cadence variety.
		var massif := volume.mass_context.get(&"massif") as WarrenMassif
		var variant_seed := massif.world_seed if massif != null \
			else volume.world_seed
		var variant_start := posmod(Helper._mix64(variant_seed ^ 31),
			MAX_PARTITION_VARIANTS)
		for variant_offset in MAX_PARTITION_VARIANTS:
			var variant := posmod(variant_start + variant_offset * 3,
				MAX_PARTITION_VARIANTS)
			ranked.append({"volume": volume, "variant": variant,
				"audit": audit,
				"variant_rank": variant_offset,
				"score": _precomposition_quality_score(volume, audit)})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_score := float(a.score)
		var b_score := float(b.score)
		if not is_equal_approx(a_score, b_score):
			return a_score > b_score
		var a_volume := a.volume as WarrenVolumePlan
		var b_volume := b.volume as WarrenVolumePlan
		if a_volume.stable_id != b_volume.stable_id:
			return _spatial_topology_less(a_volume, b_volume)
		return int(a.variant_rank) < int(b.variant_rank))
	return ranked


static func _precomposition_enclosure_audit(volume: WarrenVolumePlan,
		partition_variant: int,
		construction_program: SettlementFabricProgram) -> Dictionary:
	var massif := volume.mass_context.get(&"massif") as WarrenMassif
	if massif == null or not massif.is_sealed():
		return {}
	var grid := WarrenSpatialGrid.new(_grid_bounds(massif).minimum,
		_grid_bounds(massif).size)
	if not grid.is_valid() or not _project_massif(grid, massif):
		return {}
	var projected_mass_cell_count := grid.cells_with_use(
		WarrenSpatialGrid.Use.ALLOCATABLE).size()
	var route_floors := _carve_public_volume(grid, volume)
	if route_floors.is_empty():
		return {}
	var parcels := WarrenTownSolver.partition_parcels(volume,
		partition_variant, construction_program)
	if parcels == null:
		return {}
	var occupied: Dictionary = {}
	var proposal_count := 0
	for parcel: WarrenBuildingParcel in parcels.parcels:
		if not _parcel_address_has_public_floor(grid, parcel):
			continue
		var proposal := WarrenParcelConstruction.proposal(parcel)
		if proposal.is_empty():
			continue
		proposal_count += 1
		for cell: Vector3i in StaggeredFabricCompiler \
				.proposal_occupied_cells(proposal):
			occupied[cell] = parcel.stable_id
	if proposal_count < MIN_BUILDINGS or occupied.is_empty():
		return {}
	# Cohesion is a first-class selection objective: a parcel none of whose
	# occupied cells touch another parcel's mass reads as a building standing
	# awkwardly alone, however legal its address is.
	var parcel_owners: Dictionary = {}
	var contact_parcels: Dictionary = {}
	for cell_value: Variant in occupied:
		var cell := cell_value as Vector3i
		var owner := StringName(occupied[cell])
		parcel_owners[owner] = true
		if contact_parcels.has(owner):
			continue
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor_owner: Variant = occupied.get(cell + direction)
			if neighbor_owner != null and StringName(neighbor_owner) != owner:
				contact_parcels[owner] = true
				break
	var detached_parcel_count := parcel_owners.size() - contact_parcels.size()
	var route: Dictionary = {}
	var ground_route: Dictionary = {}
	for cell: Vector3i in route_floors:
		route[cell] = true
		var macro_column := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		if cell.y == volume.envelope.ground_at(macro_column):
			ground_route[cell] = true
	var eligible_sides := 0
	var enclosed_sides := 0
	var overhead_count := 0
	var bounded_count := 0
	var route_bands: Dictionary = {}
	for cell: Vector3i in route_floors:
		route_bands[cell.y] = true
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			if route.has(cell + direction):
				continue
			eligible_sides += 1
			enclosed_sides += int(occupied.has(cell + direction) \
				or occupied.has(cell + direction + Vector3i.UP))
		# A street reads as negative space between buildings when it runs at
		# most an alley's width and BOTH far edges of one axis are held by
		# proposed mass (or the proposed mass one band up on a half-storey
		# flank). This mirrors the sealed alley_bounded_walk_ratio corridor
		# march; per-flank 1-cell strictness measured 0.0 corpus-wide because
		# carved streets are two cells wide.
		var alley := false
		for axis: Array in [[Vector3i.LEFT, Vector3i.RIGHT],
				[Vector3i.FORWARD, Vector3i.BACK]]:
			var crossed := 0
			var held := true
			for direction: Vector3i in axis:
				var edge := cell
				while crossed <= FabricSolidVoidPlan.MAX_ALLEY_SPAN_CELLS \
						and route.has(edge + direction):
					edge += direction
					crossed += 1
				if crossed > FabricSolidVoidPlan.MAX_ALLEY_SPAN_CELLS \
						or not (occupied.has(edge + direction) \
							or occupied.has(edge + direction + Vector3i.UP)):
					held = false
					break
			if held:
				alley = true
				break
		bounded_count += int(alley)
		for rise in range(2, 7):
			if occupied.has(cell + Vector3i.UP * rise):
				overhead_count += 1
				break
	var sightline := SettlementFabricSolver._audit_sightlines(route, occupied)
	var ground_sightline := SettlementFabricSolver._audit_sightlines(
		ground_route, occupied)
	var court_supply := _precomposition_rooftop_court_supply(occupied, route,
		volume)
	return {
		"proposal_count": proposal_count,
		"projected_mass_cell_count": projected_mass_cell_count,
		"occupied_cell_count": occupied.size(),
		"proposed_mass_ratio": float(occupied.size()) \
			/ float(maxi(1, projected_mass_cell_count)),
		"frontage_ratio": float(enclosed_sides) / float(maxi(1, eligible_sides)),
		"overhead_route_ratio": float(overhead_count) \
			/ float(maxi(1, route.size())),
		"through_sightline_count": int(sightline.through_count),
		"ground_through_sightline_count": int(ground_sightline.through_count),
		"detached_parcel_count": detached_parcel_count,
		"bounded_route_ratio": float(bounded_count) \
			/ float(maxi(1, route.size())),
		"route_band_span": route_bands.size(),
		"broad_rooftop_court_cell_count": int(court_supply.get(
			"broad_cell_count", 0)),
		"broad_rooftop_court_short_span_cells": int(court_supply.get(
			"short_span_cells", 0)),
		"broad_rooftop_court_route_seam_count": int(court_supply.get(
			"route_seam_count", 0)),
	}


static func _precomposition_rooftop_court_supply(occupied: Dictionary,
		route: Dictionary, volume: WarrenVolumePlan) -> Dictionary:
	## Cheap selection proxy for the later exact roof-court carve. Count only
	## supported room crowns that are at least three cells broad on BOTH axes and
	## meet the already carved route. A long two-cell strip is a gallery and earns
	## no court credit, even when it has more cells than a small square.
	var crowns: Dictionary = {}
	for cell_value: Variant in occupied.keys():
		var cell := cell_value as Vector3i
		if occupied.has(cell + Vector3i.UP):
			continue
		var surface := cell + Vector3i.UP
		var macro_column := Vector2i(floori(float(surface.x) / 2.0),
			floori(float(surface.z) / 2.0))
		if surface.y - volume.envelope.ground_at(macro_column) \
				< MIN_ROOFTOP_COURT_LIFT_CELLS:
			continue
		crowns[surface] = true
	var remaining := crowns.duplicate()
	var best := {"broad_cell_count": 0, "short_span_cells": 0,
		"route_seam_count": 0}
	while not remaining.is_empty():
		var start := remaining.keys()[0] as Vector3i
		var frontier: Array[Vector3i] = [start]
		var component: Array[Vector3i] = []
		remaining.erase(start)
		while not frontier.is_empty():
			var current: Vector3i = frontier.pop_back()
			component.append(current)
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				var neighbor := current + direction
				if remaining.erase(neighbor):
					frontier.append(neighbor)
		if component.size() < 12:
			continue
		var minimum := Vector2i(2147483647, 2147483647)
		var maximum := Vector2i(-2147483648, -2147483648)
		var seam_count := 0
		for cell: Vector3i in component:
			minimum = minimum.min(Vector2i(cell.x, cell.z))
			maximum = maximum.max(Vector2i(cell.x, cell.z))
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				seam_count += int(route.has(cell + direction))
		var spans := maximum - minimum + Vector2i.ONE
		var short_span := mini(spans.x, spans.y)
		if short_span < 3 or seam_count == 0:
			continue
		if component.size() > int(best.broad_cell_count) \
				or (component.size() == int(best.broad_cell_count) \
					and short_span > int(best.short_span_cells)):
			best = {"broad_cell_count": component.size(),
				"short_span_cells": short_span,
				"route_seam_count": seam_count}
	return best


static func _precomposition_quality_score(volume: WarrenVolumePlan,
		audit: Dictionary) -> float:
	# Actual proposed street walls dominate; macro metrics only break ties between
	# similarly dense fine-grid projections. Detached parcels cost real score:
	# a village reads cohesive when its houses lean on one another. Streets held
	# on both flanks and routes that climb across bands are the reviewed alley
	# character, so they earn score directly.
	return float(audit.overhead_route_ratio) * 1000.0 \
		+ float(audit.frontage_ratio) * 450.0 \
		+ float(audit.get("bounded_route_ratio", 0.0)) * 500.0 \
		+ float(maxi(0, int(audit.get("route_band_span", 1)) - 1)) * 60.0 \
		- float(audit.through_sightline_count) * 3.0 \
		- float(audit.ground_through_sightline_count) * 7.0 \
		- float(audit.get("detached_parcel_count", 0)) * 55.0 \
		+ minf(24.0, float(audit.get(
			"broad_rooftop_court_cell_count", 0))) * 4.0 \
		+ (180.0 if int(audit.get("broad_rooftop_court_cell_count", 0)) \
			>= 12 else 0.0) \
		+ float(volume.audit.get("all_overhang_walk_ratio", 0.0)) * 80.0 \
		+ float(volume.audit.get("route_crossover_count", 0)) * 60.0


static func from_volume(volume: WarrenVolumePlan,
		partition_variant: int = 0,
		construction_program: SettlementFabricProgram = null,
		enable_paired_registration_relief: bool = true) -> WarrenSpatialPlan:
	last_failure = ""
	if volume == null or not volume.is_sealed() or construction_program == null:
		last_failure = "missing sealed macro volume or measured vocabulary"
		return null
	var massif := volume.mass_context.get(&"massif") as WarrenMassif
	if massif == null or not massif.is_sealed():
		last_failure = "macro volume carries no sealed inhabited massif"
		return null
	var bounds := _grid_bounds(massif)
	var grid := WarrenSpatialGrid.new(bounds.minimum, bounds.size)
	if not grid.is_valid() or not _project_massif(grid, massif):
		last_failure = "spatial grid invalid or massif projection failed"
		return null
	var projected_mass_cell_count := grid.cells_with_use(
		WarrenSpatialGrid.Use.ALLOCATABLE).size()
	var route_floors := _carve_public_volume(grid, volume)
	if route_floors.is_empty():
		last_failure = "public volume carve produced no route floor"
		return null
	# Maze mode: a DECK plot is a PLAZA, and a plaza is paved public floor.
	# Carved here, beside the bore's own streets and before any parcel or room
	# is composed, so a deck can never be mass some later pass claims. Empty on
	# every searched volume, which is what keeps legacy composition identical.
	var deck_cell_count := _pave_maze_decks(grid, volume, route_floors)
	if deck_cell_count < 0:
		return null
	# Maze mode: a flat-roofed plot's SLAB is construction, not leftover mass.
	# Retained before composition because a house stacked on that plot proves
	# its bearing against the grid, and the band under it has to be structure
	# by then (Task C5 ruling 2). Zero on every searched volume.
	var slab_courses := _retain_maze_slab_courses(grid, volume)
	if bool(slab_courses.failed):
		return null
	var parcel_plan := WarrenTownSolver.partition_parcels(volume,
		partition_variant, construction_program)
	if parcel_plan == null:
		last_failure = WarrenTownSolver.last_partition_failure
		return null
	var courtyard_parcel_sides := _parcel_courtyard_address_side_count(grid,
		volume, parcel_plan)
	var scale_profile := _scale_profile_for_volume(volume)
	if scale_profile == null:
		last_failure = "macro volume carries an invalid scale profile"
		return null
	var quotas_advisory := WarrenTownSolver.feature_quotas_are_advisory()
	if scale_profile.requires_elevated_courtyard \
			and courtyard_parcel_sides < MIN_COURT_PARCEL_SIDE_COUNT:
		if not quotas_advisory:
			last_failure = "courtyard partition forms only %d exact room sides" \
				% courtyard_parcel_sides
			return null
		last_advisory_shortfalls["courtyard_parcel_sides"] = \
			courtyard_parcel_sides
	var partition := _partition_rooms(grid, volume, parcel_plan,
		construction_program, enable_paired_registration_relief)
	if partition.is_empty():
		if last_failure.is_empty():
			last_failure = "room partition produced no result"
		return null
	# room_volume_budget is guidance recorded in the audit below, not a gate:
	# village-scale massifs compose 31-48 (compact) / 61-66 (standard) rooms,
	# and the massif radius already bounds the town's size (docs §8.8).
	var room_count := int(partition.room_count)
	for cell_value: Variant in (partition.market_reservation.get(
			"public_cells", {}) as Dictionary).keys():
		var market_floor := cell_value as Vector3i
		if not route_floors.has(market_floor):
			route_floors.append(market_floor)
	# Maze mode: an OPEN BRIDGE DECK is paving, and paving reaches the surface
	# solver through `route_floors` exactly as a deck plot's does (ruling 5).
	# Empty on every searched volume.
	for deck_floor: Vector3i in partition.get(
			"open_bridge_deck_floor_cells", []) as Array[Vector3i]:
		if not route_floors.has(deck_floor):
			route_floors.append(deck_floor)
	route_floors.sort_custom(_cell_less)
	var buildings := partition.buildings as Array[WarrenBuildingVolume]
	var supports := partition.supports as WarrenSupportGraph
	if buildings.size() < MIN_BUILDINGS:
		last_failure = "only %d volumetric buildings formed" % buildings.size()
		return null
	# A common roof court is a path decision, not a decorative roof prop. Carve
	# its walk and full headroom now, while the final room crowns are known but
	# before balconies, outcroppings, and roofs reserve the same volume. Large and
	# grand profiles already carry their stricter authored third-storey court;
	# compact and standard towns receive one route-connected roof court whenever
	# their actual supported mass can form a broad, coplanar patch.
	var rooftop_court := {"failed": false, "court_count": 0,
		"floor_cells": [] as Array[Vector3i], "audit": {}}
	if not scale_profile.requires_elevated_courtyard:
		rooftop_court = _carve_route_connected_rooftop_court(grid, volume,
			route_floors, buildings)
		if bool(rooftop_court.get("failed", false)):
			last_failure = "route-connected rooftop court carve failed: %s" \
				% JSON.stringify(rooftop_court.get("audit", {}))
			return null
		for court_cell: Vector3i in rooftop_court.floor_cells \
				as Array[Vector3i]:
			if not route_floors.has(court_cell):
				route_floors.append(court_cell)
		route_floors.sort_custom(_cell_less)
	var features := WarrenSpatialFeatureSolver.solve(grid, volume, buildings,
		supports, partition.skywalk_reservations as Array[Dictionary],
		partition.courtyard_bridge_reservation as Dictionary,
		partition.market_reservation as Dictionary,
		partition.landmark_reservations as Array[Dictionary],
		construction_program, partition.composition_audit as Dictionary)
	if features.is_empty():
		last_failure = WarrenSpatialFeatureSolver.last_failure
		return null
	var unassigned_mass_cell_count := grid.cells_with_use(
		WarrenSpatialGrid.Use.ALLOCATABLE).size()
	var trim_audit := _unassigned_mass_audit(grid)
	trim_audit.merge(_uncovered_route_overhead_supply_audit(grid, volume),
		true)
	var retained_private_cell_count := grid.cells_with_use(
		WarrenSpatialGrid.Use.PRIVATE_VOLUME).size()
	if not _discard_unassigned_mass(grid) or not _derive_shell(grid, buildings):
		last_failure = "unassigned-mass discard or shell derivation failed: %s" \
			% grid.last_rejection
		return null
	# Maze mode: what the discard above just threw away is the MOUNTAIN. Take
	# back every cell of it the source calls solid (Task C5 ruling 3), after
	# the shell so no room's facade changes, and give it one sealed feature
	# owner so the sealed plan can carry it as structure.
	var retained_rock := _retain_maze_rock(grid, volume)
	if bool(retained_rock.failed):
		return null
	# Ruling 1: with every use settled, ask the plot mass what became of it.
	var plot_mass_audit := _maze_plot_mass_audit(grid, volume)
	var stone_result := _maze_stone_reservation(grid, supports)
	if bool(stone_result.failed):
		return null
	var retained_stone := stone_result.feature as WarrenFeatureReservation
	var plan := WarrenSpatialPlan.new(
		StringName("warren.spatial.%d.v%d" % [volume.world_seed,
			partition_variant]), volume.world_seed, grid)
	plan.source_volume = volume
	for cell: Vector3i in route_floors:
		if not plan.add_route_floor(cell):
			last_failure = "duplicate or invalid fine route floor %s" % cell
			return null
	for building: WarrenBuildingVolume in buildings:
		if not plan.add_building(building):
			last_failure = "could not add volumetric building %s" % building.stable_id
			return null
	for feature: WarrenFeatureReservation in features:
		if not plan.add_feature(feature):
			last_failure = "could not add composed feature %s" % feature.stable_id
			return null
	if retained_stone != null and not plan.add_feature(retained_stone):
		last_failure = "could not add retained maze stone"
		return null
	if not plan.set_support_graph(supports):
		last_failure = "could not attach sealed support DAG"
		return null
	var entry := _fine_square(volume.entry_cell)[0]
	if not plan.seal(entry):
		last_failure = plan.last_rejection
		return null
	var minimum_route_y := 2147483647
	var maximum_route_y := -2147483648
	for cell: Vector3i in route_floors:
		minimum_route_y = mini(minimum_route_y, cell.y)
		maximum_route_y = maxi(maximum_route_y, cell.y)
	plan.audit["route_vertical_span_bands"] = maximum_route_y - minimum_route_y
	plan.audit["source_macro_walk_count"] = volume.walk_cells.size()
	plan.audit["source_courtyard_macro_cell_count"] = \
		volume.courtyard_cells.size()
	plan.audit["source_courtyard_parcel_side_count"] = courtyard_parcel_sides
	plan.audit["scale_profile_id"] = StringName(volume.mass_context.get(
		&"scale_profile_id", WarrenVillageScaleProfile.LARGE))
	plan.audit["scale_profile_signature"] = String(volume.mass_context.get(
		&"scale_profile_signature", ""))
	plan.audit["projected_mass_cell_count"] = projected_mass_cell_count
	plan.audit["unassigned_mass_cell_count"] = unassigned_mass_cell_count
	plan.audit["retained_private_mass_cell_count"] = retained_private_cell_count
	plan.audit["retained_private_mass_ratio"] = \
		float(retained_private_cell_count) \
		/ float(maxi(1, projected_mass_cell_count))
	plan.audit.merge(trim_audit, true)
	plan.audit["partition_variant"] = partition_variant
	plan.audit["room_stamp_count"] = room_count
	plan.audit["room_volume_budget_min"] = scale_profile.room_volume_budget.x
	plan.audit["room_volume_budget_max"] = scale_profile.room_volume_budget.y
	plan.audit["route_connected_rooftop_court_count"] = int(
		rooftop_court.get("court_count", 0))
	plan.audit["route_connected_rooftop_court_floor_cell_count"] = (
		rooftop_court.floor_cells as Array).size()
	plan.audit["route_connected_rooftop_court_audit"] = (
		rooftop_court.audit as Dictionary).duplicate(true)
	for key: StringName in [&"perimeter_parcel_count",
			&"grounded_perimeter_parcel_count",
			&"gateway_supported_perimeter_parcel_count",
			&"ungrounded_perimeter_parcel_count",
			&"unsupported_perimeter_parcel_count",
			&"grounded_perimeter_parcel_ratio",
			&"perimeter_load_path_ratio"]:
		plan.audit[key] = parcel_plan.audit.get(key, 0)
	plan.audit["offset_composition_block_count"] = int(partition.offset_blocks)
	plan.audit["ownership_handoff_count"] = int(partition.handoffs)
	plan.audit["rejected_unfloored_address_count"] = int(
		partition.rejected_unfloored_address_count)
	plan.audit.merge(partition.composition_audit as Dictionary, true)
	plan.audit["preplanned_skywalk_count"] = int(
		partition.preplanned_skywalk_count)
	plan.audit["preplanned_landmark_count"] = (
		partition.landmark_reservations as Array).size()
	plan.audit.merge(WarrenSpatialFeatureSolver.last_audit, true)
	if volume.mass_context.has(&"maze_source_plan"):
		plan.audit["maze_deck_cell_count"] = deck_cell_count
		plan.audit["maze_slab_course_cell_count"] = int(slab_courses.cells)
		plan.audit["maze_retained_rock_cell_count"] = int(retained_rock.cells)
		plan.audit["maze_retained_rock_skipped_reserved"] = \
			int(slab_courses.skipped) + int(retained_rock.skipped)
		# Ruling 1: the same stone, told apart. `maze_retained_rock_cells` is
		# DERIVED rock -- solid the plot planner gave to nobody, which the plot
		# model wants as a modest base. `maze_unroomed_plot_cells` is plot mass
		# the composition never built in, which is the quarry block, and
		# `maze_unroomed_plot_share` is its share of the whole plot mass.
		plan.audit["maze_retained_rock_cells"] = int(retained_rock.rock_cells)
		plan.audit["maze_retained_rock_stone_roof_cells"] = int(
			retained_rock.roof_cells)
		plan.audit["maze_retained_unroomed_plot_stone_cells"] = int(
			retained_rock.unroomed_plot_cells)
		# TASK C5e RULING 2. The parapet course above a flat crown's slab,
		# left as AIR instead of retained as stone, so the crown is an open
		# terrace rather than a masonry block with a timber sill. Counted here
		# rather than inferred from the drop in the stone total, because a
		# stack parent deliberately KEEPS its parapet -- see
		# `_maze_released_parapet_cells`.
		plan.audit["maze_released_parapet_cell_count"] = int(
			retained_rock.released_parapet_cells)
		plan.audit["maze_plot_mass_cell_count"] = int(
			plot_mass_audit.plot_cells)
		plan.audit["maze_plot_roomed_cell_count"] = int(plot_mass_audit.roomed)
		plan.audit["maze_plot_roofed_cell_count"] = int(plot_mass_audit.roofed)
		plan.audit["maze_plot_public_cell_count"] = int(plot_mass_audit.public)
		plan.audit["maze_plot_feature_cell_count"] = int(
			plot_mass_audit.feature)
		plan.audit["maze_plot_unbuildable_cell_count"] = int(
			plot_mass_audit.unbuildable)
		plan.audit["maze_unroomed_plot_cells"] = int(plot_mass_audit.unroomed)
		plan.audit["maze_unroomed_plot_uses"] = (
			plot_mass_audit.unroomed_uses as Dictionary).duplicate()
		plan.audit["maze_unroomed_plot_share"] = float(plot_mass_audit.share)
		plan.audit["maze_retained_stone_cell_count"] = 0 \
			if retained_stone == null \
			else retained_stone.reserved_cells.size()
		for key: StringName in [&"maze_stacked_plot_count",
				&"maze_declared_stack_count", &"maze_stack_refusal_count",
				&"maze_stack_slab_gap_count", &"maze_partial_stack_count",
				&"maze_stack_parents", &"maze_stack_refusals",
				# TASK C5d -- how many houses ASKED for a pitched roof, which
				# is the denominator the fabric's own
				# `maze_pitched_roof_count` is read against.
				&"maze_pitched_preference_count",
				&"maze_pitched_preference_parcels"]:
			plan.audit[key] = parcel_plan.audit.get(key, -1)
	# A spatial topology is not production-valid until the authored construction
	# shells for its final recomposed rooms clear every unrelated hero feature.
	# This exact, bounded gate runs once per complete partition survivor.  It lets
	# the existing topology/partition frontier advance past a courtyard placement
	# whose measured eaves collide, without inflating every 3D search cell with a
	# conservative halo or teaching the renderer to forgive the intersection.
	var room_units := WarrenSpatialFabricCompiler.compile_room_units(plan,
		construction_program)
	if room_units.is_empty():
		last_failure = "authored room envelope gate failed: %s" \
			% WarrenSpatialFabricCompiler.last_failure
		if diagnostic_trace_room_gate:
			print("SKYWALK_TIMING authored_room_gate source=",
				volume.stable_id, " variant=", partition_variant, " failure=",
				last_failure, " audit=", WarrenSpatialFabricCompiler.last_audit)
		return null
	plan.cache_compiled_room_units(room_units,
		WarrenSpatialFabricCompiler.last_audit)
	plan.audit["authored_room_envelope_gate_count"] = room_units.size()
	last_diagnostic = plan.audit.duplicate(true)
	return plan


static func _parcel_courtyard_address_side_count(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, parcels: WarrenParcelPlan) -> int:
	var floors: Dictionary = {}
	for macro: Vector3i in volume.courtyard_cells:
		for floor: Vector3i in _fine_square(macro):
			floors[floor] = true
	var occupied: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels.parcels:
		if not _parcel_address_has_public_floor(grid, parcel):
			continue
		var proposal := WarrenParcelConstruction.proposal(parcel)
		if proposal.is_empty():
			continue
		for cell: Vector3i in _proposal_private_cells(proposal):
			occupied[cell] = parcel.stable_id
	var side_count := 0
	for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
			Vector3i.FORWARD, Vector3i.BACK]:
		var addressed := false
		for floor_value: Variant in floors.keys():
			var floor := floor_value as Vector3i
			if floors.has(floor + direction):
				continue
			for y_offset in WarrenSpatialGrid.STOREY_CELLS:
				if occupied.has(floor + direction + Vector3i.UP * y_offset):
					addressed = true
					break
			if addressed:
				break
		side_count += int(addressed)
	return side_count


static func _grid_bounds(massif: WarrenMassif) -> Dictionary:
	var minimum_x := 2147483647
	var maximum_x := -2147483648
	var minimum_z := 2147483647
	var maximum_z := -2147483648
	var minimum_y := 2147483647
	var maximum_y := -2147483648
	for column: Vector2i in massif.columns:
		minimum_x = mini(minimum_x, column.x * 2)
		maximum_x = maxi(maximum_x, column.x * 2 + 1)
		minimum_z = mini(minimum_z, column.y * 2)
		maximum_z = maxi(maximum_z, column.y * 2 + 1)
		minimum_y = mini(minimum_y, massif.base_at(column))
		maximum_y = maxi(maximum_y, massif.top_at(column))
	var minimum := Vector3i(minimum_x - GRID_PADDING_CELLS, minimum_y,
		minimum_z - GRID_PADDING_CELLS)
	var maximum := Vector3i(maximum_x + GRID_PADDING_CELLS,
		maximum_y + ROOF_CLEARANCE_CELLS,
		maximum_z + GRID_PADDING_CELLS)
	return {"minimum": minimum, "size": maximum - minimum + Vector3i.ONE}


static func _project_massif(grid: WarrenSpatialGrid,
		massif: WarrenMassif) -> bool:
	var cells: Array[Vector3i] = []
	for column: Vector2i in massif.columns:
		for y in range(massif.base_at(column), massif.top_at(column)):
			cells.append_array(_fine_square(Vector3i(column.x, y, column.y)))
	var tx := grid.begin_transaction(&"massif.allocation")
	if not tx.assign_use(cells, WarrenSpatialGrid.Use.ALLOCATABLE,
			&"massif.allocation") or not tx.commit():
		last_failure = "could not project allocation massif: %s" % tx.last_rejection
		return false
	return true


static func _carve_public_volume(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan) -> Array[Vector3i]:
	var air: Dictionary = {}
	for macro_cell: Vector3i in volume.public_air_cells:
		for fine_cell: Vector3i in _fine_square(macro_cell):
			air[fine_cell] = true
	var route: Dictionary = {}
	for macro_floor: Vector3i in volume.walk_cells:
		for fine_floor: Vector3i in _fine_square(macro_floor):
			route[fine_floor] = true
	for transition: WarrenVolumeTransition in volume.transitions:
		for fine_floor: Vector3i in transition.surface_cells():
			route[fine_floor] = true
	for floor_value: Variant in route.keys():
		var floor_cell := floor_value as Vector3i
		for y_offset in WarrenVolumePlan.HEADROOM_BANDS:
			air[floor_cell + Vector3i.UP * y_offset] = true
	var air_cells: Array[Vector3i] = []
	air_cells.assign(air.keys())
	var carve := grid.begin_transaction(&"public.route")
	if not carve.require_use(air_cells, [WarrenSpatialGrid.Use.OUTSIDE,
			WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not carve.reserve(air_cells,
				WarrenSpatialGrid.Reservation.PUBLIC_CLEARANCE,
				&"public.route") \
			or not carve.assign_use(air_cells, WarrenSpatialGrid.Use.PUBLIC_AIR,
				&"public.route"):
		last_failure = "could not stage public-air carve"
		return [] as Array[Vector3i]
	for floor_value: Variant in route.keys():
		if not carve.claim_face(floor_value as Vector3i, Vector3i.DOWN,
				WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR, &"public.route"):
			last_failure = "could not stage public floor"
			return [] as Array[Vector3i]
	if not carve.commit():
		last_failure = "public-air carve rejected: %s" % carve.last_rejection
		return [] as Array[Vector3i]
	var daylight: Dictionary = {}
	for macro_cell: Vector3i in volume.daylight_void_cells:
		for fine_cell: Vector3i in _fine_square(macro_cell):
			daylight[fine_cell] = true
	if not daylight.is_empty():
		var daylight_cells: Array[Vector3i] = []
		daylight_cells.assign(daylight.keys())
		var subtract := grid.begin_transaction(&"public.daylight")
		if not subtract.require_use(daylight_cells,
				[WarrenSpatialGrid.Use.OUTSIDE,
					WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
				or not subtract.reserve(daylight_cells,
					WarrenSpatialGrid.Reservation.DAYLIGHT,
					&"public.daylight") \
				or not subtract.assign_use(daylight_cells,
					WarrenSpatialGrid.Use.DAYLIGHT_AIR, &"public.daylight") \
				or not subtract.commit():
			last_failure = "daylight subtraction rejected: %s" \
				% subtract.last_rejection
			return [] as Array[Vector3i]
	var out: Array[Vector3i] = []
	out.assign(route.keys())
	out.sort_custom(_cell_less)
	return out


static func _pave_maze_decks(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, route_floors: Array[Vector3i]) -> int:
	## Maze mode's deck plots, paved. Returns the fine floor cells paved, or
	## -1 with `last_failure` set.
	##
	## A deck is the one plot kind with no height (`top == floor`): a
	## courtyard, plaza or terrace the plot planner grew off a street at that
	## street's own datum. Its surface is the top of whatever is solid at
	## `floor - 1` -- rock, or a house roof -- so paving it is exactly what
	## `_carve_public_volume` does for a bored street: the band itself and the
	## headroom above it become PUBLIC_AIR, and the floor band claims a
	## PUBLIC_FLOOR face. Folding the result into `route_floors` is what
	## carries it to `WarrenSpatialPlan`, and from there to the public-realm
	## adapter and the surface solver that actually lay the paving.
	##
	## The carve is deliberately STRICT about what it may take: a deck column
	## is refused upstream unless `plot_support_ok` finds solid at `floor - 1`
	## and no carved band in the MIN_HOUSE_BANDS above it, so a deck can never
	## overlap a street's own air, and a collision here is a generator defect
	## that must be loud rather than silently absorbed.
	##
	## DECK COUPLINGS. A deck cell is indistinguishable from a bored street
	## cell to everything that reads the grid, which is the point -- it is a
	## public floor -- but three later stages change their answer because of
	## it, and each is a real behaviour change rather than a formality:
	##
	## (a) `_parcel_address_has_public_floor` accepts a parcel whose door
	##     landing is a deck cell, so a parcel that used to be counted in
	##     `rejected_unfloored_address_count` can now enter composition. Decks
	##     ADD parcels, and an empty proposal list is a hard rejection, so this
	##     coupling can only help a town -- but it does move the room set.
	##     Counted as `maze_deck_addressed_parcel_count`.
	## (b) `_carve_route_connected_rooftop_court` skips any crown that already
	##     carries a face claim or a reservation, so a deck lying on a house
	##     roof removes that crown from the roof-court candidates. (Its seam
	##     set is separately restricted to cells owned by `public.route`, so a
	##     deck can never SUPPLY the seam either.)
	## (c) `_backfill_residual_rooms` builds its route set from every
	##     PUBLIC_AIR cell carrying a PUBLIC_FLOOR face, ignoring owner, so
	##     deck cells count as uncovered route floors and as frontage sides.
	##     The greedy scan is therefore biased toward roofing and fronting the
	##     plazas, exactly as it is toward streets.
	var floors := _maze_deck_floor_cells(volume)
	if floors.is_empty():
		return 0
	var air: Dictionary = {}
	for floor_value: Variant in floors.keys():
		var floor_cell := floor_value as Vector3i
		for y_offset in WarrenVolumePlan.HEADROOM_BANDS:
			air[floor_cell + Vector3i.UP * y_offset] = true
	var air_cells: Array[Vector3i] = []
	air_cells.assign(air.keys())
	var carve := grid.begin_transaction(&"public.maze_deck")
	if not carve.require_use(air_cells, [WarrenSpatialGrid.Use.OUTSIDE,
			WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not carve.reserve(air_cells,
				WarrenSpatialGrid.Reservation.PUBLIC_CLEARANCE,
				&"public.maze_deck") \
			or not carve.assign_use(air_cells,
				WarrenSpatialGrid.Use.PUBLIC_AIR, &"public.maze_deck"):
		last_failure = "could not stage maze deck carve"
		return -1
	for floor_value: Variant in floors.keys():
		if not carve.claim_face(floor_value as Vector3i, Vector3i.DOWN,
				WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR, &"public.maze_deck"):
			last_failure = "could not stage maze deck floor"
			return -1
	if not carve.commit():
		last_failure = "maze deck carve rejected: %s" % carve.last_rejection
		return -1
	for floor_value: Variant in floors.keys():
		route_floors.append(floor_value as Vector3i)
	route_floors.sort_custom(_cell_less)
	return floors.size()


## Owner of every fine cell maze mode keeps as STONE: the flat-roof slab
## courses a stacked house bears on (Task C5 ruling 2) and the leftover rock
## the town was cut out of (ruling 3). One owner because they are one fact --
## mass the plot model kept, which is neither room nor public air -- and one
## material, the assembler's `sfv.foundation.rock.001` course.
##
## It is a FEATURE owner because `WarrenSpatialPlan._validate_building_ownership`
## requires every STRUCTURAL_VOLUME cell to name a sealed feature reservation.
## The reservation carries NO construction record, so
## `WarrenSpatialFabricCompiler.compile_feature_units` skips it and
## `_constructed_feature_count` does not count it: nothing new is compiled and
## the existing retained-terrace channel is what renders the stone.
##
## The name itself lives on the compiler, which is what CONSUMES it.
const MAZE_STONE_FEATURE_ID := WarrenSpatialFabricCompiler \
	.MAZE_RETAINED_STONE_ID
## Column-space cardinals, for the maze passes that ask what is beside a plot.
const CARDINAL_COLUMNS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
]


static func _maze_flat_slab_cells(volume: WarrenVolumePlan) -> Dictionary:
	## Every FINE cell of a STACK PARENT's flat-roof SLAB: the bands between
	## the storeys its rooms fill and its own `top_band`.
	##
	## A flat parcel's `storey_count()` is `(height - 1) / STOREY_BANDS`, so
	## its rooms stop at `roof_base_band()` and one or two bands are left over.
	## The FIRST of them carries the authored one-band `roof.flat.*` unit the
	## roof compiler now places (ruling 1); a second, where the plot's height
	## is even, is a stone parapet course. Both are claimed here, because what
	## a child at `top_band` stands on is the whole slab and
	## `WarrenRoomCompositionPlanner` proves that bearing by asking the grid
	## whether the band below the child is STRUCTURAL_VOLUME.
	##
	## ONLY A PARENT'S SLAB, and the restriction is deliberate. Claiming mass
	## before composition takes it away from the greedy residual scan, and a
	## flat plot nobody stands on has no bearing to prove: its slab is retained
	## by `_retain_maze_rock` AFTER composition instead, with every other cell
	## the town did not build in. Retaining early where nothing needs it cost
	## seed 4/compact its whole town (measured: the scan lost the rooms whose
	## crowns closed a neighbouring roof remainder).
	##
	## The stacking rule itself is asked of `WarrenMazeBlockPartitioner`, which
	## owns it; restating it here is how a translator and a solver come to
	## disagree about which plot is a parent.
	##
	## Empty for a searched volume, which is what keeps every reader maze-only.
	var out: Dictionary = {}
	var source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null:
		return out
	var parents: Dictionary = {}
	for parent_value: Variant in (WarrenMazeBlockPartitioner.stack_parents(
			source)["parents"] as Dictionary).values():
		parents[StringName(parent_value)] = true
	if parents.is_empty():
		return out
	for plot: Dictionary in source.plots:
		if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_HOUSE \
				or not parents.has(StringName(plot["id"])):
			continue
		if not WarrenMazeBlockPartitioner.plot_is_flat_roofed(source, plot):
			continue
		var top_band := int(plot["top"])
		var roof_base := WarrenBuildingParcel.flat_roof_base_band(
			int(plot["floor"]), top_band)
		for band in range(roof_base, top_band):
			for cell_value: Variant in plot["cells"] as Array:
				var column := cell_value as Vector2i
				for fine: Vector3i in _fine_square(Vector3i(column.x, band,
						column.y)):
					out[fine] = true
	return out


static func _retain_maze_slab_courses(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan) -> Dictionary:
	## Ruling 2, and the reason it runs HERE -- before any parcel or room is
	## composed. A stacked child's bearing is proved by
	## `WarrenRoomCompositionPlanner._floorplate_transition_is_structurally_legible`,
	## which reads the grid, so the slab has to be structure before the
	## composition asks. The mass it takes is mass a flat parcel's own rooms
	## can never reach (they stop at `roof_base_band()`), so claiming it early
	## costs the composition nothing it could otherwise have built.
	##
	## Returns `{failed, cells, skipped}`; `skipped` counts cells another
	## feature already holds the non-shareable FEATURE bit on -- see
	## `_feature_bit_is_taken`.
	var slab := _maze_flat_slab_cells(volume)
	if slab.is_empty():
		return {"failed": false, "cells": 0, "skipped": 0}
	var cells: Array[Vector3i] = []
	var skipped := 0
	for cell_value: Variant in slab.keys():
		var cell := cell_value as Vector3i
		if not grid.contains(cell) or grid.use_at(cell) \
				!= WarrenSpatialGrid.Use.ALLOCATABLE:
			continue
		if _feature_bit_is_taken(grid, cell):
			skipped += 1
			continue
		cells.append(cell)
	if cells.is_empty():
		return {"failed": false, "cells": 0, "skipped": skipped}
	cells.sort_custom(_cell_less)
	if not _claim_maze_stone(grid, cells):
		return {"failed": true, "cells": 0, "skipped": skipped}
	return {"failed": false, "cells": cells.size(), "skipped": skipped}


static func _retain_maze_rock(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan) -> Dictionary:
	## Ruling 3. Every fine cell the SOURCE calls solid at or above its own
	## column's terrain datum that the composed town did not build in is
	## retained as stone instead of being thrown away: shoulders, tunnel roofs,
	## street-floor slabs, the interior nobody roofed, and the span mass a
	## released bridge left behind. Terrain BELOW `base_at` is excluded -- that
	## is the heightfield's ground, and drawing masonry inside it is the
	## monument two review rounds already rejected.
	##
	## It runs AFTER `_discard_unassigned_mass` and after `_derive_shell`, so
	## every shell face this town classifies is byte-identical to the one it
	## classified before rock became stone: a room wall facing rock is still
	## the FACADE it has always been, and deciding otherwise is a visual
	## question this task does not own.
	##
	## Returns SIX keys:
	##
	## - `failed` -- the grid transaction was rejected; the town is lost.
	## - `cells` -- how many cells this pass claimed, all tags together. It is
	##   `rock_cells + roof_cells + unroomed_plot_cells`.
	## - `skipped` -- cells another feature already holds the non-shareable
	##   FEATURE bit on, which this pass steps around rather than fighting for;
	##   see `_feature_bit_is_taken`.
	## - `rock_cells` -- DERIVED ROCK: claimed cells inside no plot at all. The
	##   modest stone base the plot model asks for.
	## - `roof_cells` -- claimed cells inside a plot's own roof band span
	##   (`_maze_plot_roof_cells`). Roof by the height contract, so stone here
	##   is the parapet course rather than a shortfall.
	## - `unroomed_plot_cells` -- the rest: plot mass the composition made
	##   neither room nor roof. The quarry block, and the number Task C5c
	##   exists to move.
	var source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null or source.massif == null:
		return {"failed": false, "cells": 0, "skipped": 0, "rock_cells": 0,
			"unroomed_plot_cells": 0, "roof_cells": 0}
	# TASK C5c RULING 1 -- the TAG. Retained stone is one material and one
	# owner, but it is two different facts about the town: `rock` is derived
	# stone the plot planner never gave to anybody, and `unroomed_plot_mass`
	# is a building the composition failed to build. The first is the modest
	# base the plot model asks for; the second is the quarry block. Counting
	# them apart is what makes the difference measurable.
	var plot_mass := _maze_plot_mass_cells(volume)
	var plot_roof := _maze_plot_roof_cells(volume)
	var released := _maze_released_parapet_cells(volume)
	var cells: Array[Vector3i] = []
	var skipped := 0
	var rock_cells := 0
	var unroomed_plot_cells := 0
	var roof_cells := 0
	var released_cells := 0
	var lowest := grid.minimum.y
	var highest := grid.minimum.y + grid.size.y
	for column_value: Variant in source.massif.columns.keys():
		var column := column_value as Vector2i
		for band in range(maxi(lowest, source.massif.base_at(column)),
				highest):
			if not source.solid_at(Vector3i(column.x, band, column.y)):
				continue
			for fine: Vector3i in _fine_square(Vector3i(column.x, band,
					column.y)):
				if not grid.contains(fine) or grid.use_at(fine) \
						!= WarrenSpatialGrid.Use.OUTSIDE:
					continue
				if released.has(fine):
					released_cells += 1
					continue
				if _feature_bit_is_taken(grid, fine):
					skipped += 1
					continue
				if not plot_mass.has(fine):
					rock_cells += 1
				elif plot_roof.has(fine):
					roof_cells += 1
				else:
					unroomed_plot_cells += 1
				cells.append(fine)
	if cells.is_empty():
		return {"failed": false, "cells": 0, "skipped": skipped,
			"rock_cells": 0, "unroomed_plot_cells": 0, "roof_cells": 0,
			"released_parapet_cells": released_cells}
	cells.sort_custom(_cell_less)
	if not _claim_maze_stone(grid, cells):
		return {"failed": true, "cells": 0, "skipped": skipped,
			"rock_cells": 0, "unroomed_plot_cells": 0, "roof_cells": 0,
			"released_parapet_cells": released_cells}
	return {"failed": false, "cells": cells.size(), "skipped": skipped,
		"rock_cells": rock_cells,
		"unroomed_plot_cells": unroomed_plot_cells, "roof_cells": roof_cells,
		"released_parapet_cells": released_cells}


static func _maze_released_parapet_cells(volume: WarrenVolumePlan) \
		-> Dictionary:
	## TASK C5e RULING 2 -- THE PARAPET IS RELEASED TO AIR.
	##
	## A flat-roofed plot's crown is `[flat_roof_base_band, top)`: the first
	## band carries the authored one-band `roof.flat.*` slab the roof compiler
	## builds, and on the EVEN heights the planner produces one more band is
	## left over. That leftover band used to be retained STONE, and it is why
	## every crown in the C5d captures reads from above as a stone block with
	## a timber sill: the slab is BENEATH a solid course of masonry that
	## covers the whole footprint, not a terrace.
	##
	## It is released here -- claimed by nobody, left as air -- so the built
	## crown is slab plus open sky and `SettlementFabricAssembler
	## .maze_terrace_railings` can guard its edges.
	##
	## THE DESIGN DECISION RULING 2 LEAVES OPEN, and which way it went.
	## A child of a stacked house stands at `parent.top_band`, which is one
	## band ABOVE the slab: what it really rests on is that parapet course.
	## The two admissible answers were to release the band anyway and teach
	## the seam to accept a floor one band clear of the slab, or to keep the
	## parcel's built top AT the slab wherever nothing stands on it. This is
	## the second: a plot that is a STACK PARENT keeps its parapet, because
	## something really does stand on it and `WarrenRoomCompositionPlanner
	## ._floorplate_transition_is_structurally_legible` proves that bearing by
	## asking the grid whether the band below the child is STRUCTURAL_VOLUME.
	## Every other flat plot -- 34 of 36, 39 of 39 and 37 of 40 house plots on
	## the three sealing seeds -- ends at its slab.
	##
	## The choice costs nothing and changes no seam: `WarrenParcelPlan
	## .building_support_is_valid`, `WarrenBuildingParcel.top_band` and every
	## deterministic signature are untouched, so the plot's `top` remains the
	## massing envelope it always was while the BUILT crown stops one band
	## lower. Releasing it under a child instead would have put a band of air
	## between a house and the house it stands on.
	##
	## Precisely the complement of `_maze_flat_slab_cells`, which claims the
	## same bands for the stack parents this function skips.
	##
	## Empty for a searched volume, which is what keeps every reader maze-only.
	var out: Dictionary = {}
	var source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null:
		return out
	var parents: Dictionary = {}
	for parent_value: Variant in (WarrenMazeBlockPartitioner.stack_parents(
			source)["parents"] as Dictionary).values():
		parents[StringName(parent_value)] = true
	for plot: Dictionary in source.plots:
		if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_HOUSE \
				or parents.has(StringName(plot["id"])) \
				or not WarrenMazeBlockPartitioner.plot_is_flat_roofed(source,
					plot):
			continue
		var top_band := int(plot["top"])
		var roof_base := WarrenBuildingParcel.flat_roof_base_band(
			int(plot["floor"]), top_band)
		for band in range(roof_base + 1, top_band):
			for cell_value: Variant in plot["cells"] as Array:
				var column := cell_value as Vector2i
				for fine: Vector3i in _fine_square(Vector3i(column.x, band,
						column.y)):
					out[fine] = true
	return out


static func _maze_plot_roof_cells(volume: WarrenVolumePlan) -> Dictionary:
	## Every FINE cell of a house plot's own ROOF band span. A flat-roofed plot
	## keeps `[flat_roof_base_band, top)` -- the authored one-band `roof.flat.*`
	## unit Task C5 compiles plus, on an even height, its stone parapet course.
	## Every other house plot keeps the authored pitched reservation,
	## `[top - ROOF_RESERVATION_BANDS, top)`. Both spans are roof BY THE HEIGHT
	## CONTRACT `WarrenBuildingParcel._height_is_legal` states, so no room may
	## ever stand there and this mass must not count against the unroomed
	## share.
	##
	## House plots only: an asset plot is a prefab that carries its own crown,
	## a bridge is one storey of deck, and a deck has no height at all.
	##
	## Empty for a searched volume, which is what keeps every reader maze-only.
	var out: Dictionary = {}
	var source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null:
		return out
	for plot: Dictionary in source.plots:
		if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_HOUSE:
			continue
		var floor_band := int(plot["floor"])
		var top_band := int(plot["top"])
		var roof_base := WarrenBuildingParcel.flat_roof_base_band(floor_band,
			top_band) \
			if WarrenMazeBlockPartitioner.plot_is_flat_roofed(source, plot) \
			else top_band - WarrenBuildingParcel.ROOF_RESERVATION_BANDS
		for band in range(maxi(floor_band, roof_base), top_band):
			for cell_value: Variant in plot["cells"] as Array:
				var column := cell_value as Vector2i
				for fine: Vector3i in _fine_square(Vector3i(column.x, band,
						column.y)):
					out[fine] = true
	return out


static func _maze_plot_mass_audit(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan) -> Dictionary:
	## TASK C5c RULING 1 -- the measurement this whole task is judged on.
	##
	## Every fine cell of every plot's own `[floor, top)` is classified exactly
	## once, so `roomed + roofed + public + unroomed == plot_cells` is an
	## identity and nothing hides in a rounding:
	##
	## - ROOMED: `PRIVATE_VOLUME` -- a room, a back room, a bridge room, a
	##   landmark body. What the town actually built.
	## - ROOFED: inside `_maze_plot_roof_cells`. Roof is not a room, and the
	##   plot model asked for it (Task C5 built these bands), so it never
	##   counts against the share.
	## - PUBLIC: a street, a deck or a daylight void the carve bored back out
	##   of the plot. The realm's, not a shortfall.
	## - FEATURE: structure some OTHER feature built inside the plot -- a
	##   market post, a link's bearing. Built, and not this pass's stone.
	## - UNBUILDABLE: mass the SOURCE itself does not offer -- a bore ran
	##   through it, or it lies below its own column's `massif.base_at`, where
	##   the heightfield draws the ground and `_retain_maze_rock` deliberately
	##   draws nothing. Exactly the complement of the retention pass's own
	##   candidate domain, which is what makes UNROOMED and the stone that pass
	##   claims the same number.
	## - UNROOMED: the residue -- the quarry block. Plot mass composition made
	##   neither room nor roof, which `_retain_maze_rock` then ships as stone.
	##
	## Empty for a searched volume.
	var out: Dictionary = {"plot_cells": 0, "roomed": 0, "roofed": 0,
		"public": 0, "feature": 0, "unbuildable": 0, "unroomed": 0,
		"share": 0.0, "unroomed_uses": {}}
	var source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null or source.massif == null:
		return out
	var roof := _maze_plot_roof_cells(volume)
	var plot_cells := 0
	var roomed := 0
	var roofed := 0
	var public := 0
	var feature := 0
	var unbuildable := 0
	var unroomed := 0
	var unroomed_uses: Dictionary = {}
	for cell_value: Variant in _maze_plot_mass_cells(volume).keys():
		var cell := cell_value as Vector3i
		plot_cells += 1
		var use := grid.use_at(cell) if grid.contains(cell) \
			else WarrenSpatialGrid.Use.OUTSIDE
		var macro := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		if use == WarrenSpatialGrid.Use.PRIVATE_VOLUME:
			roomed += 1
		elif use in [WarrenSpatialGrid.Use.PUBLIC_AIR,
				WarrenSpatialGrid.Use.DAYLIGHT_AIR]:
			public += 1
		elif use == WarrenSpatialGrid.Use.STRUCTURAL_VOLUME \
				and grid.owner_name_at(cell) != MAZE_STONE_FEATURE_ID:
			feature += 1
		elif roof.has(cell):
			roofed += 1
		elif not grid.contains(cell) \
				or cell.y < source.massif.base_at(macro) \
				or not source.solid_at(Vector3i(macro.x, cell.y, macro.y)):
			unbuildable += 1
		else:
			unroomed += 1
			# Which USE the residue wears. Every cell here should be the
			# retained stone `_retain_maze_rock` claimed; a different use is a
			# cell the retention pass never saw, and naming it is cheaper than
			# guessing at it later.
			unroomed_uses[use] = int(unroomed_uses.get(use, 0)) + 1
	out["plot_cells"] = plot_cells
	out["roomed"] = roomed
	out["roofed"] = roofed
	out["public"] = public
	out["feature"] = feature
	out["unbuildable"] = unbuildable
	out["unroomed"] = unroomed
	out["unroomed_uses"] = unroomed_uses
	out["share"] = float(unroomed) / float(maxi(1, plot_cells))
	return out


static func _feature_bit_is_taken(grid: WarrenSpatialGrid,
		cell: Vector3i) -> bool:
	## Does some OTHER owner already hold this cell's non-shareable FEATURE
	## reservation bit?
	##
	## Retained stone is the only claim in this pipeline that sweeps a whole
	## volume rather than placing one authored shape, so it is the only one
	## that can meet a reservation somebody else made for a cell they never
	## assigned a use to -- `WarrenSpatialFeatureSolver`'s elevated-court
	## protection is exactly that, and `_discard_unassigned_mass` then turns
	## those cells OUTSIDE, straight into this pass's candidate set. Reserving
	## one of them fails the whole grid transaction, which would kill the town
	## for a cell nobody was going to see. Skipping it is the answer, and it is
	## COUNTED (`maze_retained_rock_skipped_reserved`) rather than silent.
	return (grid.reservation_bits_at(cell)
		& WarrenSpatialGrid.Reservation.FEATURE) != 0 \
		and not grid.reservation_owned_by(cell,
			WarrenSpatialGrid.Reservation.FEATURE, MAZE_STONE_FEATURE_ID)


static func _claim_maze_stone(grid: WarrenSpatialGrid,
		cells: Array[Vector3i]) -> bool:
	## One transaction claims the use AND the reservation together, so a cell
	## is never ours-by-use and unreserved: the sealed plan requires every
	## STRUCTURAL_VOLUME cell to name a feature that really reserved it, and
	## reserving in a second pass would leave a window in which another feature
	## could take the bit out from under a cell we already own.
	var retain := grid.begin_transaction(MAZE_STONE_FEATURE_ID)
	if not retain.assign_use(cells, WarrenSpatialGrid.Use.STRUCTURAL_VOLUME,
			MAZE_STONE_FEATURE_ID) \
			or not retain.reserve(cells,
				WarrenSpatialGrid.Reservation.FEATURE,
				MAZE_STONE_FEATURE_ID) \
			or not retain.commit():
		last_failure = "could not retain maze stone: %s" % retain.last_rejection
		return false
	return true


static func _maze_stone_reservation(grid: WarrenSpatialGrid,
		supports: WarrenSupportGraph) -> Dictionary:
	## One sealed reservation over every retained stone cell, which is what
	## lets `WarrenSpatialPlan.seal` accept them as STRUCTURAL_VOLUME. The two
	## retention passes already hold the FEATURE bit on every cell here (see
	## `_claim_maze_stone`), so this only gathers and seals.
	##
	## Returns `{feature, failed}`: a town that retained NOTHING is
	## `{null, false}`, which is a legitimate answer and not a failure.
	var cells: Array[Vector3i] = []
	for cell: Vector3i in grid.cells_with_use(
			WarrenSpatialGrid.Use.STRUCTURAL_VOLUME):
		if grid.owner_name_at(cell) == MAZE_STONE_FEATURE_ID:
			cells.append(cell)
	if cells.is_empty():
		return {"feature": null, "failed": false}
	var feature := WarrenFeatureReservation.new(MAZE_STONE_FEATURE_ID,
		&"maze_retained_stone")
	if not feature.add_reserved_cells(cells) or not feature.seal(grid,
			supports):
		last_failure = "retained maze stone did not seal: %s" \
			% feature.last_rejection
		return {"feature": null, "failed": true}
	return {"feature": feature, "failed": false}


static func _maze_deck_floor_cells(volume: WarrenVolumePlan) -> Dictionary:
	## Every FINE cell a deck plot's own floor band covers, as a set. A deck
	## has no height (`top == floor`), so this one band is the whole of it.
	## Empty for a searched volume, which is what keeps every reader of it
	## maze-only.
	var out: Dictionary = {}
	var source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null:
		return out
	for plot: Dictionary in source.plots:
		if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_DECK:
			continue
		var band := int(plot["floor"])
		for cell_value: Variant in plot["cells"] as Array:
			var column := cell_value as Vector2i
			for fine: Vector3i in _fine_square(Vector3i(column.x, band,
					column.y)):
				out[fine] = true
	return out


static func _maze_open_bridge_flanks(source: WarrenMazeSourcePlan,
		span: Array[Vector2i], floor_band: int) -> Dictionary:
	## The columns beside a bridge span that present a FLAT WALKABLE SURFACE at
	## the span's own floor band -- a flat-roofed house whose `top_band` IS that
	## band (its slab is the roof the walkway continues across) or a deck plot
	## paved at it -- and whether two of them face each other.
	##
	## `{columns: int, sides: int, opposite: bool}`.
	##
	## OPPOSITE SIDES, not merely two columns. Two flat columns on the SAME
	## side of a span are one roof, and a walkway needs a roof at each end.
	## `WarrenExcavation.seal` derives a bridge's flanks the same way -- the
	## span's own cells run ALONG the passage it covers, so the flanks are the
	## perpendicular pair -- and a one-column span, having no axis of its own,
	## may be crossed on either axis.
	var span_set: Dictionary = {}
	for column: Vector2i in span:
		span_set[column] = true
	var flat_by_side: Dictionary = {}
	var seen: Dictionary = {}
	for column: Vector2i in span:
		for direction: Vector2i in CARDINAL_COLUMNS:
			var neighbor := column + direction
			if span_set.has(neighbor) or seen.has(neighbor):
				continue
			if not _maze_column_is_flat_at(source, neighbor, floor_band):
				continue
			seen[neighbor] = true
			flat_by_side[direction] = int(
				flat_by_side.get(direction, 0)) + 1
	var axes: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN]
	if span.size() == 2:
		var travel := span[1] - span[0]
		axes = [Vector2i(-travel.y, travel.x)]
	var opposite := false
	for axis: Vector2i in axes:
		opposite = opposite or flat_by_side.has(axis) \
			and flat_by_side.has(-axis)
	return {"columns": seen.size(), "sides": flat_by_side.size(),
		"opposite": opposite}


static func _maze_column_is_flat_at(source: WarrenMazeSourcePlan,
		column: Vector2i, band: int) -> bool:
	for plot: Dictionary in source.plots:
		if not (plot["cells"] as Array).has(column):
			continue
		var kind := StringName(plot["kind"])
		if kind == WarrenMazeSourcePlan.PLOT_DECK:
			if int(plot["floor"]) == band:
				return true
		elif kind == WarrenMazeSourcePlan.PLOT_HOUSE \
				and int(plot["top"]) == band \
				and WarrenMazeBlockPartitioner \
					.plot_crown_carries_public_realm(source, plot):
			return true
	return false


static func _pave_open_bridge_decks(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, records: Array,
		unstamped_ids: Dictionary) -> Dictionary:
	## Ruling 5, beside `_pave_maze_decks` because it is the same act: a span
	## nobody could stand a ROOM on, between two flat roofs at its own floor,
	## is an OPEN BRIDGE DECK -- a walkway across the rooftops rather than a
	## record released back to rock. The plot's own `[floor, top)` becomes
	## PUBLIC_AIR with a PUBLIC_FLOOR face at `floor`, exactly as a deck plot
	## does, and the retained slab at `floor - 1` stays stone.
	##
	## Returns `{failed, paved_ids, floor_cells}`. A span whose mass is no
	## longer free, or whose flanks are not both flat, is left to its release.
	var out := {"failed": false, "paved_ids": {} as Dictionary,
		"flanks": {} as Dictionary,
		"floor_cells": [] as Array[Vector3i]}
	var source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null or records.is_empty() or unstamped_ids.is_empty():
		return out
	var floors: Array[Vector3i] = []
	var air: Array[Vector3i] = []
	var paved: Dictionary = {}
	for record_value: Variant in records:
		var record := record_value as Dictionary
		var id := StringName(record["id"])
		if not unstamped_ids.has(id):
			continue
		var columns: Array[Vector2i] = []
		columns.assign(record["cells"] as Array)
		var floor_band := int(record["floor"])
		var flanks := _maze_open_bridge_flanks(source, columns, floor_band)
		(out["flanks"] as Dictionary)[id] = flanks
		if not bool(flanks.opposite):
			continue
		var record_floors: Array[Vector3i] = []
		var record_air: Array[Vector3i] = []
		var free := true
		for column: Vector2i in columns:
			for band in range(floor_band, int(record["top"])):
				for fine: Vector3i in _fine_square(Vector3i(column.x, band,
						column.y)):
					if not grid.contains(fine) or grid.use_at(fine) \
							!= WarrenSpatialGrid.Use.ALLOCATABLE:
						free = false
						break
					record_air.append(fine)
					if band == floor_band:
						record_floors.append(fine)
				if not free:
					break
			if not free:
				break
		if not free:
			continue
		paved[id] = true
		floors.append_array(record_floors)
		air.append_array(record_air)
	if paved.is_empty():
		return out
	var carve := grid.begin_transaction(&"public.maze_bridge_deck")
	if not carve.require_use(air,
			[WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not carve.reserve(air,
				WarrenSpatialGrid.Reservation.PUBLIC_CLEARANCE,
				&"public.maze_bridge_deck") \
			or not carve.assign_use(air, WarrenSpatialGrid.Use.PUBLIC_AIR,
				&"public.maze_bridge_deck"):
		last_failure = "could not stage open bridge deck carve"
		out["failed"] = true
		return out
	for floor_cell: Vector3i in floors:
		if not carve.claim_face(floor_cell, Vector3i.DOWN,
				WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR,
				&"public.maze_bridge_deck"):
			last_failure = "could not stage open bridge deck floor"
			out["failed"] = true
			return out
	if not carve.commit():
		last_failure = "open bridge deck carve rejected: %s" \
			% carve.last_rejection
		out["failed"] = true
		return out
	floors.sort_custom(_cell_less)
	out["paved_ids"] = paved
	out["floor_cells"] = floors
	return out


static func _partition_rooms(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, parcels: WarrenParcelPlan,
		construction_program: SettlementFabricProgram,
		enable_paired_registration_relief: bool = true) -> Dictionary:
	# Breadcrumb: several stages below call helpers that reset last_failure on
	# entry, so a real rejection reason could be cleared before it reached the
	# caller and surfaced as a bare "no result". Any path that returns {} without
	# writing its own reason now carries this instead of nothing.
	last_failure = "room partition: no stage reported a reason"
	var scale_profile := _scale_profile_for_volume(volume)
	if scale_profile == null:
		last_failure = "room partition has an invalid scale profile"
		return {}
	var requires_courtyard := scale_profile.requires_elevated_courtyard
	# Request the richest end of the profile's skywalk range; the sealed
	# occluder ranking may keep a reduced plan only when it proves the extra
	# link adds no distinct inhabited route coverage, and the profile minimum
	# (skywalk_range.x) still gates every accepted plan.
	var target_skywalks := scale_profile.skywalk_range.y
	var target_landmarks := scale_profile.landmark_range.x
	if WarrenTownSolver.feature_quotas_are_advisory():
		# One-pass mode: a quota the carver cannot yet supply must not become a
		# constraint the beam then fails to satisfy. Ask for zero so the beam
		# commits through its ORDINARY success branch — every downstream stage
		# then sees a properly committed (if empty) feature set instead of a
		# bypassed one. What the town lacks is recorded, not enforced.
		target_skywalks = 0
		target_landmarks = 0
	var proposals: Array[Dictionary] = []
	var rejected_unfloored_addresses := 0
	# Coupling (a) of `_pave_maze_decks`: a paved deck is a legal address
	# landing, so a maze parcel can enter composition on a plaza that no bore
	# reaches. Empty in every searched mode, and counted rather than assumed.
	var deck_floors := _maze_deck_floor_cells(volume)
	var deck_addressed_parcels := 0
	# TASK C5c RULING 4. Parcel id -> the gate that dropped it, written at
	# every point a parcel can leave the composition, so a plot that composes
	# no lineage says WHY instead of vanishing. Recorded for every mode and
	# published for a maze town only, where a dropped parcel is a whole
	# building's worth of stone the town then has to carry.
	var parcel_gate_by_id: Dictionary = {}
	var parcel_gate_detail_by_id: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels.parcels:
		var proposal := WarrenParcelConstruction.proposal(parcel)
		if proposal.is_empty():
			parcel_gate_by_id[parcel.stable_id] = &"proposal_rejected"
			continue
		# Mass-first frontage includes intermediate stair/ramp macro cells. Only
		# two fine lanes inside such a square carry the actual transition surface;
		# a door aimed at either unused half opens into swept public air with no
		# floor. Reject that parcel before it can reserve hero features or enter the
		# room composition, and keep the same fact as a final room/building seal.
		if not _parcel_address_has_public_floor(grid, parcel):
			rejected_unfloored_addresses += 1
			parcel_gate_by_id[parcel.stable_id] = \
				&"rejected_unfloored_address"
			if volume.mass_context.has(&"maze_source_plan"):
				parcel_gate_detail_by_id[parcel.stable_id] = \
					_maze_unfloored_address_detail(grid, volume, parcel)
			continue
		if not deck_floors.is_empty():
			deck_addressed_parcels += int(deck_floors.has(
				WarrenParcelConstruction.threshold_cell(parcel) \
					+ Vector3i(parcel.frontage_direction.x, 0,
						parcel.frontage_direction.y)))
		proposal["parcel"] = parcel
		proposals.append(proposal)
	if proposals.is_empty():
		last_failure = "parcel seed produced no complete room proposals"
		return {}
	proposals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.stable_id) < String(b.stable_id))
	var court_floors := _courtyard_floor_cells(volume)
	var court_neighbor_cells := _courtyard_neighbor_cells(court_floors)
	var court_fixed_blocks_by_parcel: Dictionary = {}
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		var fixed := _proposal_court_fixed_blocks(proposal,
			court_neighbor_cells)
		if not fixed.is_empty():
			court_fixed_blocks_by_parcel[parcel.stable_id] = fixed
	# Conservative source envelopes may intentionally share authored roof seams.
	# Retain every claimant: a last-writer map made residual shift legality depend
	# on the parcel array's incidental construction order.
	var protected_owners: Dictionary = {}
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		for cell: Vector3i in StaggeredFabricCompiler.proposal_occupied_cells(
				proposal):
			if not protected_owners.has(cell):
				protected_owners[cell] = {}
			(protected_owners[cell] as Dictionary)[parcel.stable_id] = true
	# The room vocabulary is the primary structure. Prove that the unadorned
	# parcel mass can be decomposed into supported long/building/slim/tower stamps
	# before markets, landmark pairs, and connector beams spend their much larger
	# search budgets. Hero features may constrain a viable macro plan; they may not
	# be relied on to accidentally rescue an unsupported micro-box arrangement.
	var macro_preflight: Dictionary = {}
	if requires_courtyard:
		# The large/grand court search needs an already-sealed composition to rank
		# candidate sides. Smaller profiles have no court consumer, and the final
		# post-skywalk composition below proves the identical macro/support/roof
		# contract. Running it twice added several seconds to every compact trial
		# without changing a single accepted room.
		macro_preflight = _macro_composition_preflight(grid, volume, proposals,
			protected_owners, court_fixed_blocks_by_parcel)
		if macro_preflight.is_empty():
			last_failure = "macro room decomposition rejected before hero search: %s" \
				% WarrenRoomCompositionPlanner.last_failure
			return {}
	# The covered bazaar is town topology, not a late prop pass. Select and
	# reserve its exact canopy/posts, under-canopy public aisle, measured visual
	# envelope, and backing-room socket before generic composition blocks move.
	var market_plan := _preplan_spatial_market(grid, volume, proposals,
		construction_program, protected_owners)
	var market_candidates: Array[Dictionary] = []
	market_candidates.assign(market_plan.get("candidates", []) as Array)
	if market_candidates.is_empty():
		if scale_profile.requires_covered_market \
				and not WarrenTownSolver.feature_quotas_are_advisory():
			last_failure = "no topology-first covered market fits the connected ground street"
			return {}
		if scale_profile.requires_covered_market:
			last_advisory_shortfalls["covered_market"] = 0
		# The covered bazaar is a city feature. A village takes one whenever
		# its ground street can actually hold the measured canopy, aisle, and
		# backing; when none fits, the hero-feature beam runs once with the
		# market deliberately absent instead of rejecting the whole town. The
		# sentinel is non-empty so a committed selection still reads as one;
		# it is normalized back to a truly absent market after the beam.
		market_candidates = [{"optional_absent": true}]
	# Select three measured straight links *before* upper composition blocks are
	# frozen. Each candidate shifts both endpoint blocks together by one fine
	# cell, creating a genuine floorplate break while preserving exact sockets.
	# Unrelated generic blocks must move around the reserved connector volume.
	# Market and skywalks are one bounded compatible feature-set search. A valid
	# bazaar in isolation may consume the only measured bridge endpoint; try the
	# finite ranked market corpus until the complete hero-feature set survives.
	var market_reservation: Dictionary = {}
	var courtyard_bridge_candidate: Dictionary = {}
	var courtyard_bridge_reservation: Dictionary = {}
	var skywalk_plan: Dictionary = {}
	var landmark_reservations: Array[Dictionary] = []
	var selected_exact_composition: Dictionary = {}
	var selected_occluder_rank: Dictionary = {}
	var feature_set_attempts: Array[Dictionary] = []
	var realm := WarrenVolumePublicRealmAdapter.from_volume(volume)
	if realm == null:
		last_failure = "could not recover exact public air for joint hero features"
		return {}
	var public_air := realm.air_claims()
	# Use the exact same public-surface subset as the final enclosure audit. A
	# bridge over supplemental air, a court, or an approach landing may still be
	# structurally useful, but it cannot satisfy the inhabited-overhead target.
	var route_walk := _enclosure_route_walk(realm)
	var macro_route_covered := _composition_route_covered_cells(
		macro_preflight, route_walk)
	var market_attempt_count := 0
	var exact_room_preflight_cache_hit_count := 0
	var selected_court_alternatives: Array[Dictionary] = []
	var selected_market_landmark_owners: Dictionary = {}
	var maze_asset_outcomes: Array[Dictionary] = []
	# One pass, no search. In maze mode the plot planner already decided this
	# town's features, so the four nested loops below have nothing left to
	# choose: `_maze_feature_pass` fills exactly the locals their commit fills
	# and then empties the market corpus, so they iterate zero times. Every
	# searched mode reaches them with the corpus untouched, byte for byte.
	if volume.mass_context.has(&"maze_source_plan"):
		var maze_features := _maze_feature_pass(grid, volume, parcels,
			proposals, construction_program, protected_owners,
			court_fixed_blocks_by_parcel, public_air, market_candidates,
			enable_paired_registration_relief)
		market_reservation = maze_features.market_reservation as Dictionary
		courtyard_bridge_candidate = \
			maze_features.courtyard_bridge_candidate as Dictionary
		courtyard_bridge_reservation = \
			maze_features.courtyard_bridge_reservation as Dictionary
		skywalk_plan = maze_features.skywalk_plan as Dictionary
		landmark_reservations.assign(
			maze_features.landmark_reservations as Array)
		selected_exact_composition = \
			maze_features.selected_exact_composition as Dictionary
		selected_occluder_rank = \
			maze_features.selected_occluder_rank as Dictionary
		selected_court_alternatives.assign(
			maze_features.selected_court_alternatives as Array)
		selected_market_landmark_owners = \
			maze_features.selected_market_landmark_owners as Dictionary
		maze_asset_outcomes.assign(maze_features.asset_outcomes as Array)
		market_candidates.clear()
	for candidate: Dictionary in market_candidates:
		if diagnostic_feature_market_limit >= 0 \
				and market_attempt_count >= diagnostic_feature_market_limit:
			break
		market_attempt_count += 1
		var market_attempt_started := Time.get_ticks_msec()
		if diagnostic_trace_skywalk_timing:
			print("SKYWALK_TIMING market_begin parcel=",
				candidate.get("backing_parcel_id", &""))
		var market_owners := _protected_owners_with_market(protected_owners,
			candidate)
		# Cosmetic prefab alternatives often share the exact same protected
		# volumes and room/skywalk obligations. Cache only failed exact preflights,
		# scoped to this market, by those structural facts; recipe names alone never
		# alias a proof and a success is selected immediately anyway.
		var exact_room_preflight_failures: Dictionary = {}
		var raw_court_candidates: Array[Dictionary] = []
		if requires_courtyard:
			raw_court_candidates = _courtyard_cantilever_room_candidates(grid,
				volume, proposals, construction_program, market_owners, public_air)
		else:
			raw_court_candidates.append(_absent_courtyard_bridge_candidate())
		_rank_courtyard_candidates_for_macro(raw_court_candidates,
				court_floors, macro_preflight)
		if diagnostic_trace_skywalk_timing:
			var macro_preview: Array[Dictionary] = []
			for preview_index in mini(12, raw_court_candidates.size()):
				var preview := raw_court_candidates[preview_index] as Dictionary
				macro_preview.append({
					"side_count": int(preview.get(
						"macro_court_side_count", 0)),
					"conflict_owner_count": int(preview.get(
						"macro_room_conflict_count", 0)),
					"conflict_cell_count": int(preview.get(
						"macro_room_conflict_cell_count", 0)),
					"owner_socket_cell_count": int(preview.get(
						"macro_owner_socket_conflict_cell_count", 0)),
					"unrelated_owner_count": int(preview.get(
						"macro_unrelated_room_conflict_count", 0)),
					"origin": (preview.get("reservation", {}) \
						as Dictionary).get("origin", Vector3i()),
					"owners": (preview.get("reservation", {}) \
						as Dictionary).get("owner_parcel_ids", []),
				})
			print("SKYWALK_TIMING court_macro_candidates ", macro_preview)
		if raw_court_candidates.is_empty():
			feature_set_attempts.append({
				"market_parcel": candidate.get("backing_parcel_id", &""),
				"market_origin": candidate.get("origin", Vector3i.ZERO), "landmark_count": 0,
				"landmark_recipes": [] as Array[StringName],
				"courtyard_bridge_count": 0,
				"skywalk_count": 0, "skywalk_candidate_count": 0})
			continue
		var court_candidate_limit := 1 if diagnostic_stop_after_skywalk_candidates \
			or diagnostic_stop_after_skywalk_individual \
			else raw_court_candidates.size()
		var failed_court_tower_obligations: Dictionary = {}
		var landmark_sets_by_corpus: Dictionary = {}
		for court_candidate_index in court_candidate_limit:
			var court_has_intrinsic_tall_tower := false
			var repeated_exact_failure_counts: Dictionary = {}
			var court_has_repeated_exact_failure := false
			var raw_court_candidate := raw_court_candidates[court_candidate_index]
			var court_obligation_key := _feature_forced_offset_key(
				raw_court_candidate)
			if failed_court_tower_obligations.has(court_obligation_key):
				continue
			var court_candidate := raw_court_candidate.duplicate(true)
			var court_reservation := (raw_court_candidate.reservation \
				as Dictionary).duplicate(true)
			court_reservation["feature_id"] = COURTYARD_BRIDGE_FEATURE_ID
			court_candidate["reservation"] = court_reservation
			var court_owners := _protected_owners_with_courtyard_bridge(
				market_owners, court_candidate)
			# Court frontage is a property of the one sealed macro room pattern. A
			# late hero asset may complete that pattern, but may not cut through it
			# and ask a fresh 3D solve to invent replacement walls. The final exact
			# composition below still proves market, landmark, and bridge envelopes
			# together; this gate removes a redundant full macro solve per court.
			if requires_courtyard and (int(court_candidate.get(
					"macro_court_side_count", 0)) \
					< WarrenSpatialFeatureSolver.MIN_COURT_SIDE_COUNT \
					or not _court_macro_conflict_is_recomposable(
						court_candidate)):
				feature_set_attempts.append({
					"market_parcel": candidate.get("backing_parcel_id", &""),
					"market_origin": candidate.get("origin", Vector3i.ZERO),
					"courtyard_bridge_count": 0,
					"court_macro_fit": false,
					"court_macro_side_count": int(court_candidate.get(
						"macro_court_side_count", 0)),
					"court_macro_room_conflict_count": int(court_candidate.get(
						"macro_room_conflict_count", 0)),
					"court_macro_owner_socket_conflict_cell_count": int(
						court_candidate.get(
							"macro_owner_socket_conflict_cell_count", 0)),
					"court_macro_unrelated_room_conflict_count": int(
						court_candidate.get(
							"macro_unrelated_room_conflict_count", 0)),
					"landmark_count": 0,
					"landmark_recipes": [] as Array[StringName],
					"skywalk_count": 0, "skywalk_candidate_count": 0,
				})
				continue
			var macro_required_court_parcels := \
				_composition_courtyard_side_owner_ids(court_floors,
					macro_preflight)
			court_candidate["macro_required_parcel_ids"] = \
				macro_required_court_parcels
			var baseline_skywalk_plan := _preplan_spatial_skywalks(grid, volume,
				proposals, construction_program, court_owners,
				target_skywalks,
				raw_court_candidates.size())
			var skywalk_corpus: Array[Dictionary] = []
			skywalk_corpus.assign(baseline_skywalk_plan.get("candidate_corpus", []) \
				as Array)
			skywalk_corpus = _skywalk_candidates_preserving_parcels(
				skywalk_corpus, macro_required_court_parcels)
			if diagnostic_trace_skywalk_timing:
				print("SKYWALK_TIMING market_baseline ms=",
					Time.get_ticks_msec() - market_attempt_started, " corpus=",
					skywalk_corpus.size())
			if skywalk_corpus.is_empty():
				feature_set_attempts.append({
					"market_parcel": candidate.get("backing_parcel_id", &""),
					"market_origin": candidate.get("origin", Vector3i.ZERO),
					"courtyard_bridge_count": 1,
					"landmark_count": 0,
					"landmark_recipes": [] as Array[StringName],
					"skywalk_count": 0, "skywalk_candidate_count": 0})
				continue
			var landmark_candidates: Array[Dictionary] = []
			var landmark_stage_started := Time.get_ticks_msec()
			# Every scale now integrates several complete authored buildings. Build
			# the shared candidate corpus once, then let the bounded compatible-set
			# search compare the selected scale's richest-to-minimum counts.
			if scale_profile.landmark_range.y > 0:
				var landmark_plan := _preplan_spatial_landmarks(grid, volume,
					construction_program, court_owners, candidate,
					[] as Array[Dictionary], macro_required_court_parcels)
				landmark_candidates.assign(landmark_plan.get("candidates", []) \
					as Array)
			if diagnostic_trace_skywalk_timing:
				print("SKYWALK_TIMING landmark_candidates ms=",
					Time.get_ticks_msec() - landmark_stage_started,
					" count=", landmark_candidates.size())
			var landmark_corpus_key := _landmark_candidate_corpus_key(
				landmark_candidates)
			var landmark_sets: Array[Dictionary] = []
			var landmark_set_cache_hit := landmark_sets_by_corpus.has(
				landmark_corpus_key)
			if landmark_set_cache_hit:
				landmark_sets = landmark_sets_by_corpus[landmark_corpus_key] \
					as Array[Dictionary]
			else:
				# Enumerate every count in the selected size contract, richest
				# first. Exact embeddedness/skywalk ranking normally keeps the
				# richer complete-building set; the lower bound remains a genuine
				# fallback when a second or third measured prefab cannot compose
				# cleanly with this town's route and occupied mountain.
				for landmark_count in range(scale_profile.landmark_range.y,
						target_landmarks - 1, -1):
					landmark_sets.append_array(_landmark_candidate_sets(
						landmark_candidates, volume.world_seed, landmark_count))
				landmark_sets_by_corpus[landmark_corpus_key] = landmark_sets
			if diagnostic_trace_skywalk_timing:
				print("SKYWALK_TIMING landmark_sets ms=",
					Time.get_ticks_msec() - landmark_stage_started,
					" count=", landmark_sets.size(), " cache=",
					landmark_set_cache_hit)
			_rank_landmark_sets_for_skywalks(landmark_sets, skywalk_corpus,
				target_skywalks)
			if diagnostic_trace_skywalk_timing:
				print("SKYWALK_TIMING landmark_rank ms=",
					Time.get_ticks_msec() - landmark_stage_started)
			for set_index in mini(MAX_LANDMARK_SET_ATTEMPTS,
					landmark_sets.size()):
				var landmark_attempt_started := Time.get_ticks_msec()
				var landmark_set := (landmark_sets[set_index] as Dictionary) \
					.get("reservations", []) as Array[Dictionary]
				if diagnostic_trace_skywalk_timing:
					print("SKYWALK_TIMING landmark_set_begin index=", set_index,
						" key=", _landmark_set_diagnostic_key(landmark_set))
				var trial_owners := _protected_owners_with_landmarks(court_owners,
					landmark_set)
				var trial_skywalk_plan := _skywalk_plan_for_landmarks(grid, volume,
					proposals, trial_owners, skywalk_corpus, landmark_set,
					construction_program, public_air, route_walk,
					macro_route_covered, target_skywalks,
					macro_required_court_parcels)
				var trial_skywalks: Array[Dictionary] = []
				trial_skywalks.assign(trial_skywalk_plan.get("reservations", []) \
					as Array)
				if diagnostic_trace_skywalk_timing:
					print("SKYWALK_TIMING landmark_set index=", set_index,
						" ms=", Time.get_ticks_msec() - landmark_attempt_started,
						" candidates=", trial_skywalk_plan.get(
							"candidate_count", 0),
						" selected=", trial_skywalks.size())
				feature_set_attempts.append({
					"market_parcel": candidate.get("backing_parcel_id", &""),
					"market_origin": candidate.get("origin", Vector3i.ZERO),
					"courtyard_bridge_count": 1,
					"courtyard_bridge_origin": court_reservation.origin,
					"landmark_count": landmark_set.size(),
					"landmark_recipes": _landmark_recipe_ids(landmark_set),
					"skywalk_count": trial_skywalks.size(),
					"skywalk_candidate_count": int((landmark_sets[set_index] \
						as Dictionary).get("skywalk_candidate_count", 0)),
					"exact_skywalk_candidate_count": int(trial_skywalk_plan.get(
						"candidate_count", 0)),
					"skywalk_pair_frontier_count": int(trial_skywalk_plan.get(
						"pair_frontier_count", 0))})
				if landmark_set.size() < target_landmarks \
						or trial_skywalks.size() \
							< scale_profile.skywalk_range.x:
					continue
				var market_landmark_owners := \
					_protected_owners_with_landmarks(market_owners,
						landmark_set)
				# This is the first point where market, court room, landmark pair,
				# and all requested skywalks are known together. Prove the bounded
				# diverse skywalk frontier through the exact room composition here,
				# while the enclosing loops can still try another court or market,
				# then rank the sealed survivors by the same transformed recipe
				# occluders the final enclosure audit measures.
				var exact_room_started := Time.get_ticks_msec()
				var skywalk_trial_plans: Array[Dictionary] = [trial_skywalk_plan]
				var exclusion_snapshot := _court_candidate_exclusion_snapshot(
					court_candidate)
				var sealed_trials: Array[Dictionary] = []
				var fatal_court_failure := false
				var trial_index := 0
				while trial_index < skywalk_trial_plans.size():
					var trial_plan := skywalk_trial_plans[trial_index]
					var trial_reservations: Array[Dictionary] = []
					trial_reservations.assign(trial_plan.get("reservations", []) \
						as Array)
					if trial_index > 0 and trial_reservations.size() \
							< scale_profile.skywalk_range.x:
						trial_index += 1
						continue
					# Compact and standard towns have no authored elevated-court
					# obligation. Keep their already ranked primary link plan; later
					# exact fabric/roof compilation remains the authority and can reject
					# the partition without making optional link alternatives alter room
					# composition during this topology pass.
					if not requires_courtyard:
						sealed_trials.append({"plan": trial_plan, "result": {},
							"covered": -1, "route_cells": route_walk.size(),
							"exclusions": exclusion_snapshot,
							"reduced": false, "trial_index": trial_index})
						break
					_restore_court_candidate_exclusions(court_candidate,
						exclusion_snapshot)
					var exact_key := _exact_room_preflight_key(court_candidate,
						landmark_set, trial_plan)
					var trial_fit := false
					var exact_room_result: Dictionary = {}
					if exact_room_preflight_failures.has(exact_key):
						exact_room_preflight_cache_hit_count += 1
						_restore_exact_room_preflight_failure(
							exact_room_preflight_failures[exact_key] as Dictionary)
					else:
						trial_fit = \
							_court_candidate_preserves_exact_room_envelopes(
								grid, volume, proposals, construction_program,
								candidate, court_candidate,
								market_landmark_owners,
								court_fixed_blocks_by_parcel, trial_plan,
								enable_paired_registration_relief,
								exact_room_result)
						if not trial_fit:
							exact_room_preflight_failures[exact_key] = \
								_exact_room_preflight_failure_snapshot()
					if diagnostic_trace_skywalk_timing:
						print("SKYWALK_TIMING exact_room_fit index=", set_index,
							" trial=", trial_index, " fit=", trial_fit, " ms=",
							Time.get_ticks_msec() - exact_room_started,
							" room=", last_preplan_market_diagnostic.get(
								"last_exact_room_composition_failure", ""),
							" pairs=", last_preplan_market_diagnostic.get(
								"last_exact_room_pair_failure", ""),
							" composition=", last_preplan_market_diagnostic.get(
								"last_exact_court_composition_failure", {}),
							" required=", last_preplan_market_diagnostic.get(
								"last_exact_court_required_conflict", {}),
							" tower=", last_preplan_market_diagnostic.get(
								"last_exact_court_tall_tower_failure", []),
							" court_owners=", court_reservation.get(
								"owner_parcel_ids", []),
							" court_offsets=", court_candidate.get(
								"forced_offsets", {}),
							" skywalk_owners=", _skywalk_plan_owner_preview(
								trial_plan),
							" skywalk_offsets=", trial_plan.get(
								"forced_offsets", {}),
							" variant_failure=", WarrenRoomCompositionPlanner \
								.last_variant_diagnostic.get("failure", ""),
							" variant_lineage=", WarrenRoomCompositionPlanner \
								.last_variant_diagnostic.get("lineage_id", &""))
					if not trial_fit:
						if trial_index == 0:
							var failure_signature := JSON.stringify(
								_exact_room_preflight_failure_snapshot())
							# A repeated failure can memoize an actual elevated-court
							# obligation because that same occupied bridge room is present
							# in every landmark trial. Compact/standard profiles carry an
							# empty sentinel here; repeated failures there belong to the
							# changing landmark/skywalk composition and must advance through
							# the bounded set frontier instead of falsely condemning a court
							# which does not exist.
							if requires_courtyard \
									and not bool(court_candidate.get(
										"optional_absent", false)) \
									and not failure_signature.is_empty() \
									and failure_signature != "{}":
								repeated_exact_failure_counts[failure_signature] = int(
									repeated_exact_failure_counts.get(
										failure_signature, 0)) + 1
								if int(repeated_exact_failure_counts[
										failure_signature]) >= 2:
									court_has_repeated_exact_failure = true
									fatal_court_failure = true
									break
							if last_preplan_market_diagnostic.has(
									"last_exact_court_tall_tower_failure"):
								# One court-owned failed lineage is sufficient to prove
								# this exact forced endpoint obligation impossible. Other
								# failed lineages may be incidental to the selected
								# landmark/skywalk set; they must not prevent memoizing
								# the independently fatal court obligation. A failure
								# with no court-owned lineage still advances to the next
								# court candidate, but cannot memoize other visual
								# variants of this structural obligation.
								var failed_ids := last_preplan_market_diagnostic[
									"last_exact_court_tall_tower_failure"] as Array
								var court_owned_failures := \
									_court_owned_tall_tower_failures(failed_ids,
										court_candidate)
								if not court_owned_failures.is_empty():
									failed_court_tower_obligations[
										court_obligation_key] = court_owned_failures
								court_has_intrinsic_tall_tower = true
								fatal_court_failure = true
								break
						trial_index += 1
						continue
					# Sealed: measure the composed recipe occluder route coverage,
					# excluding the parcels this exact pass dispositioned away.
					var trial_excluded: Dictionary = {}
					for excluded_value: Variant in court_candidate.get(
							"excluded_parcel_ids", []) as Array:
						trial_excluded[StringName(excluded_value)] = true
					var coverage_reservations: Array[Dictionary] = []
					coverage_reservations.append_array(trial_reservations)
					if not bool(court_candidate.get("optional_absent", false)):
						coverage_reservations.append(court_candidate.get(
							"reservation", {}) as Dictionary)
					coverage_reservations.append_array(landmark_set)
					var covered := -1
					var route_cells := route_walk.size()
					var trial_probes := _exact_composition_room_probes(
						exact_room_result.get("composition", {}) as Dictionary,
						proposals, construction_program, volume.world_seed,
						court_candidate, trial_reservations, trial_excluded)
					if bool(trial_probes.get("valid", false)):
						var probe_records: Array[Dictionary] = []
						probe_records.assign(trial_probes.get("probes", []) \
							as Array)
						var coverage := _sealed_recipe_occluder_route_coverage(
							probe_records, coverage_reservations,
							construction_program, route_walk)
						covered = int(coverage.covered_route_cell_count)
						route_cells = int(coverage.route_cell_count)
					sealed_trials.append({"plan": trial_plan,
						"result": exact_room_result,
						"covered": covered, "route_cells": route_cells,
						"exclusions": _court_candidate_exclusion_snapshot(
							court_candidate),
						"reduced": bool(trial_plan.get(
							"reduced_link_count", false)),
						"trial_index": trial_index})
					if trial_index == 0:
						# Richer court towns inspect alternates only after the primary
						# exact composition seals; this keeps the bounded search lazy.
						skywalk_trial_plans.append_array(
							_deferred_alternate_skywalk_plans(grid, volume,
								proposals, trial_owners, trial_plan))
					trial_index += 1
				if sealed_trials.is_empty():
					(feature_set_attempts.back() as Dictionary)[
						"exact_room_fit"] = false
					if fatal_court_failure:
						break
					continue
				# Rank sealed survivors: highest composed occluder coverage wins;
				# ties keep the deterministic trial order. A reduced three-link
				# plan wins only when it strictly beats every full-target plan,
				# which proves the fourth link visually redundant.
				var best_full: Dictionary = {}
				var best_reduced: Dictionary = {}
				for sealed_trial: Dictionary in sealed_trials:
					if bool(sealed_trial.get("reduced", false)):
						if best_reduced.is_empty() or int(sealed_trial.covered) \
								> int(best_reduced.covered):
							best_reduced = sealed_trial
					elif best_full.is_empty() or int(sealed_trial.covered) \
							> int(best_full.covered):
						best_full = sealed_trial
				# The redundancy flag is an exact measured fact: the extra link
				# failed to raise distinct route coverage. The tie nevertheless
				# keeps the richer plan — review gate 11 explicitly values
				# repeated overhead episodes, so equal-coverage extra links are
				# kept and judged visually rather than silently dropped.
				var fourth_link_redundant := not best_full.is_empty() \
					and not best_reduced.is_empty() \
					and int(best_reduced.covered) >= int(best_full.covered)
				var chosen := best_full
				if best_full.is_empty():
					chosen = best_reduced
				elif not best_reduced.is_empty() \
						and int(best_reduced.covered) > int(best_full.covered):
					chosen = best_reduced
				_restore_court_candidate_exclusions(court_candidate,
					chosen.exclusions as Dictionary)
				var chosen_result := chosen.result as Dictionary
				(feature_set_attempts.back() as Dictionary)["exact_room_fit"] = true
				(feature_set_attempts.back() as Dictionary)[
					"occluder_rank_sealed_count"] = sealed_trials.size()
				last_preplan_skywalk_diagnostic["occluder_rank_trial_count"] = \
					skywalk_trial_plans.size()
				last_preplan_skywalk_diagnostic["occluder_rank_sealed_count"] = \
					sealed_trials.size()
				last_preplan_skywalk_diagnostic[
					"occluder_rank_selected_covered_route_cell_count"] = \
					int(chosen.covered)
				last_preplan_skywalk_diagnostic[
					"occluder_rank_route_cell_count"] = int(chosen.route_cells)
				last_preplan_skywalk_diagnostic[
					"occluder_rank_fourth_link_redundant"] = fourth_link_redundant
				var trial_coverage_report: Array[Dictionary] = []
				for sealed_trial: Dictionary in sealed_trials:
					trial_coverage_report.append({
						"trial_index": int(sealed_trial.trial_index),
						"covered": int(sealed_trial.covered),
						"reduced": bool(sealed_trial.get("reduced", false))})
				last_preplan_skywalk_diagnostic[
					"occluder_rank_trial_coverages"] = trial_coverage_report
				selected_occluder_rank = {
					"occluder_rank_trial_count": skywalk_trial_plans.size(),
					"occluder_rank_sealed_trial_count": sealed_trials.size(),
					"occluder_rank_selected_covered_route_cell_count":
						int(chosen.covered),
					"occluder_rank_route_cell_count": int(chosen.route_cells),
					"occluder_rank_fourth_link_redundant": fourth_link_redundant,
					"occluder_rank_trial_coverages": trial_coverage_report,
				}
				market_reservation = candidate
				courtyard_bridge_candidate = court_candidate
				courtyard_bridge_reservation = court_reservation
				landmark_reservations.assign(landmark_set)
				skywalk_plan = chosen.plan as Dictionary
				selected_exact_composition = chosen_result.get(
					"composition", {}) as Dictionary \
					if not bool(chosen_result.get(
						"recomposition_required", false)) else {}
				selected_court_alternatives.assign(raw_court_candidates)
				selected_market_landmark_owners = market_landmark_owners
				break
			if court_has_intrinsic_tall_tower \
					or court_has_repeated_exact_failure:
				continue
			if not market_reservation.is_empty():
				break
		if not market_reservation.is_empty():
			break
	var skywalk_reservations: Array[Dictionary] = []
	skywalk_reservations.assign(skywalk_plan.get("reservations", []) as Array)
	var maximum_joint_skywalk_count := 0
	var maximum_exact_skywalk_candidate_count := 0
	var maximum_skywalk_pair_frontier_count := 0
	for attempt: Dictionary in feature_set_attempts:
		maximum_joint_skywalk_count = maxi(maximum_joint_skywalk_count,
			int(attempt.skywalk_count))
		maximum_exact_skywalk_candidate_count = maxi(
			maximum_exact_skywalk_candidate_count,
			int(attempt.get("exact_skywalk_candidate_count", 0)))
		maximum_skywalk_pair_frontier_count = maxi(
			maximum_skywalk_pair_frontier_count,
			int(attempt.get("skywalk_pair_frontier_count", 0)))
	last_preplan_market_diagnostic["feature_set_attempts"] = feature_set_attempts
	last_preplan_landmark_diagnostic["joint_attempt_count"] = \
		feature_set_attempts.size()
	last_preplan_landmark_diagnostic["maximum_joint_skywalk_count"] = \
		maximum_joint_skywalk_count
	last_preplan_landmark_diagnostic["maximum_exact_skywalk_candidate_count"] = \
		maximum_exact_skywalk_candidate_count
	last_preplan_landmark_diagnostic["maximum_skywalk_pair_frontier_count"] = \
		maximum_skywalk_pair_frontier_count
	# The market is structural, not a richness quota: downstream composition and
	# the public realm both consume it, so its absence stays fatal in every mode.
	# Court/landmark/skywalk counts are richness — in one-pass mode a shortfall
	# is recorded and the town ships plainer rather than not at all.
	var quotas_advisory := WarrenTownSolver.feature_quotas_are_advisory()
	var short_hero_features := courtyard_bridge_reservation.is_empty() \
		or landmark_reservations.size() < target_landmarks \
		or skywalk_reservations.size() < scale_profile.skywalk_range.x
	if market_reservation.is_empty() \
			or (short_hero_features and not quotas_advisory):
		last_failure = "joint hero-feature beam found court=%d, %d landmarks, and %d skywalks (%s; %s)" \
			% [int(not courtyard_bridge_reservation.is_empty()),
				landmark_reservations.size(), skywalk_reservations.size(),
				last_preplan_landmark_diagnostic,
				last_preplan_skywalk_diagnostic]
		return {}
	if short_hero_features:
		last_advisory_shortfalls["hero_courtyard_bridges"] = int(
			not courtyard_bridge_reservation.is_empty())
		last_advisory_shortfalls["hero_landmarks"] = \
			landmark_reservations.size()
		last_advisory_shortfalls["hero_landmarks_target"] = target_landmarks
		last_advisory_shortfalls["hero_skywalks"] = skywalk_reservations.size()
		last_advisory_shortfalls["hero_skywalks_target"] = \
			scale_profile.skywalk_range.x
	# A committed absent-market sentinel becomes a genuinely absent market for
	# every downstream consumer (composition, features, audits) — mirroring
	# how optional-absent courts already flow through this beam.
	if bool(market_reservation.get("optional_absent", false)):
		market_reservation = {}
	# Landmark and three-skywalk selection is the expensive part of this beam.
	# Keep that complete feature set fixed while trying the tiny court frontier
	# against the *final* room grammar it induces. A failed cantilever may be
	# swapped without regenerating paths, landmarks, or connector triples.
	var ordered_court_alternatives: Array[Dictionary] = [
		courtyard_bridge_candidate]
	var selected_court_key := _skywalk_construction_key(
		courtyard_bridge_reservation)
	for raw_alternative: Dictionary in selected_court_alternatives:
		var raw_reservation := raw_alternative.reservation as Dictionary
		if _skywalk_construction_key(raw_reservation) == selected_court_key:
			continue
		ordered_court_alternatives.append(raw_alternative)
	var exact_court_attempt_count := 0
	var exact_court_rejection_count := 0
	var exact_court_selected := false
	var selected_skywalk_candidates := skywalk_plan.get(
		"selected_candidates", []) as Array
	for raw_alternative: Dictionary in ordered_court_alternatives:
		var alternative := raw_alternative.duplicate(true)
		var alternative_reservation := (raw_alternative.reservation \
			as Dictionary).duplicate(true)
		alternative_reservation["feature_id"] = COURTYARD_BRIDGE_FEATURE_ID
		alternative["reservation"] = alternative_reservation
		var is_selected_court := _skywalk_construction_key(
			alternative_reservation) == selected_court_key
		if not is_selected_court and not _skywalk_clearance_fits_protected(
				alternative.clearance as Dictionary,
				selected_market_landmark_owners):
			continue
		var compatible := true
		if not is_selected_court:
			for skywalk_value: Variant in selected_skywalk_candidates:
				if not _skywalk_candidates_compatible(alternative,
						skywalk_value as Dictionary):
					compatible = false
					break
		if not compatible:
			continue
		exact_court_attempt_count += 1
		var exact_started := Time.get_ticks_msec()
		var exact_court_result: Dictionary = {}
		var exact_fit := not requires_courtyard \
			or is_selected_court and not selected_exact_composition.is_empty()
		if requires_courtyard and not exact_fit:
			exact_fit = _court_candidate_preserves_exact_room_envelopes(
				grid, volume, proposals, construction_program, market_reservation,
				alternative, selected_market_landmark_owners,
				court_fixed_blocks_by_parcel, skywalk_plan,
				enable_paired_registration_relief, exact_court_result)
		if diagnostic_trace_skywalk_timing:
			print("SKYWALK_TIMING final_court_envelope attempt=",
				exact_court_attempt_count, " fit=", exact_fit, " ms=",
				Time.get_ticks_msec() - exact_started)
		if not exact_fit:
			exact_court_rejection_count += 1
			continue
		courtyard_bridge_candidate = alternative
		courtyard_bridge_reservation = alternative_reservation
		if exact_court_result.has("composition") and not bool(
				exact_court_result.get("recomposition_required", false)):
			selected_exact_composition = exact_court_result.composition \
				as Dictionary
		elif not exact_court_result.is_empty():
			selected_exact_composition = {}
		exact_court_selected = true
		break
	last_preplan_market_diagnostic["exact_court_attempt_count"] = \
		exact_court_attempt_count
	last_preplan_market_diagnostic["exact_court_rejection_count"] = \
		exact_court_rejection_count
	last_preplan_market_diagnostic["exact_room_preflight_cache_hit_count"] = \
		exact_room_preflight_cache_hit_count
	if not exact_court_selected:
		last_failure = ("no court cantilever clears the final authored room " \
			+ "envelopes: %s") % JSON.stringify(
				last_preplan_market_diagnostic.get(
					"last_exact_court_required_conflict", {}))
		return {}
	protected_owners = _protected_owners_with_courtyard_bridge(
		selected_market_landmark_owners, courtyard_bridge_candidate)
	# These feature envelopes are fixed by the joint preflight above. Commit them
	# before room composition so the exact solver searches the real residual 3D
	# mass instead of a much larger proxy volume. `protected_owners` remains the
	# lineage-level exception map, while the grid is the authoritative occupancy.
	if not market_reservation.is_empty() \
			and not _reserve_market_preplan(grid, market_reservation):
		last_failure = "covered-market reservation changed before joint commit: %s" \
			% grid.last_rejection
		return {}
	_annotate_landmark_skywalk_connections(landmark_reservations,
		skywalk_reservations)
	if not _reserve_landmark_preplans(grid, landmark_reservations):
		last_failure = "prefab-landmark reservation changed before joint commit: %s" \
			% grid.last_rejection
		return {}
	last_preplan_market_diagnostic["selected"] = {
		"parcel": market_reservation.get("backing_parcel_id", &""),
		"origin": market_reservation.get("origin", Vector3i.ZERO),
		"yaw": market_reservation.get("yaw_quarters", 0),
		"recipe": market_reservation.get("recipe_id", &""),
		"open_horizon_max_cells": int(market_reservation.get(
			"open_horizon_max_cells", -1)),
		"open_horizon_total_cells": int(market_reservation.get(
			"open_horizon_total_cells", -1)),
		"core_radius_squared": float(market_reservation.get(
			"core_radius_squared", -1.0))}
	var market_feature_id := StringName(market_reservation.get("feature_id",
		&""))
	# Selected hero-feature endpoint blocks outrank generic room proposals. Make
	# that priority explicit in the provisional-owner field so every displaced
	# parcel either finds another legal block offset or drops transactionally.
	for cell_value: Variant in (skywalk_plan.priority_cells as Dictionary).keys():
		protected_owners[cell_value] = {
			StringName((skywalk_plan.priority_cells as Dictionary)[cell_value]): true,
		}
	for reservation_index in skywalk_reservations.size():
		var reservation := skywalk_reservations[reservation_index]
		var reservation_owner := StringName("spatial.skywalk.reserve.%02d" \
			% reservation_index)
		var body := reservation.reserved_cells as Dictionary
		for cell_value: Variant in body.keys():
			var cell := cell_value as Vector3i
			if not protected_owners.has(cell):
				protected_owners[cell] = {}
			(protected_owners[cell] as Dictionary)[reservation_owner] = true
		var allowed_endpoint_owners := _skywalk_endpoint_owner_set(reservation)
		for cell_value: Variant in (reservation.get("visual_clearance_cells", {}) \
				as Dictionary).keys():
			if body.has(cell_value):
				continue
			if not protected_owners.has(cell_value):
				protected_owners[cell_value] = {}
			(protected_owners[cell_value] as Dictionary)[reservation_owner] = \
				allowed_endpoint_owners
	var forced_offsets_by_parcel := (skywalk_plan.forced_offsets \
		as Dictionary).duplicate(true)
	for parcel_value: Variant in (courtyard_bridge_candidate.forced_offsets \
			as Dictionary).keys():
		var parcel_id := StringName(parcel_value)
		if not forced_offsets_by_parcel.has(parcel_id):
			forced_offsets_by_parcel[parcel_id] = {}
		for block_value: Variant in ((courtyard_bridge_candidate.forced_offsets \
				as Dictionary)[parcel_id] as Dictionary).keys():
			var block := int(block_value)
			var wanted := ((courtyard_bridge_candidate.forced_offsets as Dictionary)[
				parcel_id] as Dictionary)[block_value] as Vector2i
			var existing := (forced_offsets_by_parcel[parcel_id] \
				as Dictionary).get(block, wanted) as Vector2i
			if existing != wanted:
				last_failure = "courtyard bridge and skywalk force incompatible block %s/%d" \
					% [parcel_id, block]
				return {}
			(forced_offsets_by_parcel[parcel_id] as Dictionary)[block] = wanted
	# First solve every exact interface block against the unchanged residual
	# mass. The volumetric composition planner then re-partitions only those
	# upper bands that are not doors, court edges, market sockets, or skywalk
	# endpoints. This separates immutable topology from mutable construction
	# form and prevents proposal iteration order from deciding who survives.
	var solved_offsets_by_parcel: Dictionary = {}
	var exact_forced_offsets_by_parcel: Dictionary = {}
	var court_displaced_parcels: Dictionary = {}
	for parcel_value: Variant in courtyard_bridge_candidate.get(
			"excluded_parcel_ids", []):
		court_displaced_parcels[StringName(parcel_value)] = true
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		# The exact room-pair preflight removes only a complete optional parcel.
		# Honor that sealed disposition when rebuilding the final composition;
		# merely counting it in the audit would recreate the collision that the
		# preflight explicitly resolved.
		if court_displaced_parcels.has(parcel.stable_id):
			parcel_gate_by_id[parcel.stable_id] = &"court_displaced"
			continue
		var storeys := int(proposal.storeys)
		var origin := proposal.origin as Vector3i
		var base_plate := _proposal_base_plate(proposal)
		if storeys <= 0 or base_plate.is_empty():
			parcel_gate_by_id[parcel.stable_id] = &"proposal_has_no_storeys"
			continue
		var threshold := WarrenParcelConstruction.threshold_cell(parcel)
		var addressed_storey := clampi(floori(float(threshold.y - origin.y) \
			/ float(WarrenSpatialGrid.STOREY_CELLS)), 0, storeys - 1)
		var forced_offsets: Dictionary = {0: Vector2i.ZERO,
			floori(float(addressed_storey) / 2.0): Vector2i.ZERO}
		for court_block_value: Variant in (court_fixed_blocks_by_parcel.get(
				parcel.stable_id, {}) as Dictionary).keys():
			forced_offsets[int(court_block_value)] = Vector2i.ZERO
		for block_value: Variant in (forced_offsets_by_parcel.get(
				parcel.stable_id, {}) as Dictionary).keys():
			var block := int(block_value)
			var wanted := (forced_offsets_by_parcel[parcel.stable_id] \
				as Dictionary)[block] as Vector2i
			if forced_offsets.has(block) and forced_offsets[block] != wanted:
				forced_offsets.clear()
				break
			forced_offsets[block] = wanted
		if forced_offsets.is_empty():
			parcel_gate_by_id[parcel.stable_id] = &"forced_offsets_conflict"
			continue
		var offsets := _composition_offsets(grid, base_plate, origin.y,
			storeys, protected_owners, parcel.stable_id, volume.world_seed,
			forced_offsets)
		if offsets.is_empty():
			parcel_gate_by_id[parcel.stable_id] = \
				&"exact_composition_unsolved"
			if volume.mass_context.has(&"maze_source_plan"):
				parcel_gate_detail_by_id[parcel.stable_id] = \
					_maze_exact_composition_conflict(grid, base_plate,
						origin.y, storeys, protected_owners,
						parcel.stable_id)
			continue
		solved_offsets_by_parcel[parcel.stable_id] = offsets
		exact_forced_offsets_by_parcel[parcel.stable_id] = forced_offsets
		# A solved block set is a provisional 3D reservation for the remaining
		# source passes. Without this lock, two individually legal lateral moves
		# can converge on the same residual cell even though neither overlaps the
		# original parcel envelopes. The later room grammar may merge or shrink
		# these reservations, but it starts from a non-overlapping partition.
		for cell: Vector3i in _segment_cells(base_plate, origin.y, offsets, 0,
				storeys):
			if not protected_owners.has(cell):
				protected_owners[cell] = {}
			(protected_owners[cell] as Dictionary)[parcel.stable_id] = true
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING final_composition_inputs displaced=",
			court_displaced_parcels.keys(), " solved_has_displaced=",
			_any_key_overlap(solved_offsets_by_parcel,
				court_displaced_parcels), " selected_exact=",
			not selected_exact_composition.is_empty())
	var composition := selected_exact_composition
	if composition.is_empty():
		composition = WarrenRoomCompositionPlanner.solve(grid, volume,
			proposals, solved_offsets_by_parcel, exact_forced_offsets_by_parcel,
			market_reservation, protected_owners, forced_offsets_by_parcel,
			skywalk_reservations, volume.world_seed,
			enable_paired_registration_relief)
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING final_composition_lineages displaced_present=",
			_any_key_overlap(composition.get("lineages", {}) as Dictionary,
				court_displaced_parcels), " lineage_count=",
			(composition.get("lineages", {}) as Dictionary).size())
	if composition.is_empty():
		last_failure = "3D room composition failed: %s" \
			% WarrenRoomCompositionPlanner.last_failure
		return {}
	if not WarrenRoomCompositionPlanner.lineages_are_supported(
			composition.lineages as Dictionary, grid):
		last_failure = "final 3D room composition lost structural bearing"
		return {}
	var composed_court_side_mask := _composition_courtyard_side_mask(
		court_floors, composition, courtyard_bridge_candidate.body as Dictionary)
	var composed_court_side_count := _side_mask_count(composed_court_side_mask)
	if requires_courtyard and composed_court_side_count \
			< WarrenSpatialFeatureSolver.MIN_COURT_SIDE_COUNT:
		last_failure = ("3D room composition preserves only %d courtyard " \
			+ "sides (mask=%d)") % [composed_court_side_count,
				composed_court_side_mask]
		return {}
	var composition_audit := composition.audit as Dictionary
	# What became of every asset plot the one-pass source placed: a prefab
	# landmark, or a named reason it could not be one. Maze mode only; a
	# searched town has no asset plots to account for.
	if volume.mass_context.has(&"maze_source_plan"):
		composition_audit["maze_asset_outcomes"] = maze_asset_outcomes
	composition_audit["macro_preflight_deferred_to_final_count"] = int(
		not requires_courtyard)
	composition_audit["court_displaced_parcel_count"] = \
		court_displaced_parcels.size()
	composition_audit["feature_clearance_displaced_parcel_count"] = (
		courtyard_bridge_candidate.get(
			"feature_clearance_displaced_parcel_ids", []) as Array).size()
	composition_audit["room_pair_displaced_parcel_count"] = (
		courtyard_bridge_candidate.get(
			"room_pair_displaced_parcel_ids", []) as Array).size()
	composition_audit["composed_courtyard_side_mask"] = \
		composed_court_side_mask
	composition_audit["composed_courtyard_side_count"] = \
		composed_court_side_count
	composition_audit.merge(selected_occluder_rank, true)
	composition_audit["landmark_skywalk_connected_count"] = int(
		skywalk_plan.get("landmark_coverage_count", 0))
	composition_audit["landmark_skywalk_connection_ratio"] = 1.0 \
		if landmark_reservations.is_empty() else float(
			composition_audit.landmark_skywalk_connected_count) \
			/ float(landmark_reservations.size())
	# Preserve the parcelizer's exact 3D frontier-bearing seams through room
	# recomposition. The feature solver realizes them as measured construction
	# before optional facade details can spend the same clearance.
	composition_audit["perimeter_gateway_support_records"] = (
		parcels.audit.get("perimeter_gateway_support_records", []) \
		as Array).duplicate(true)
	var lineages := composition.lineages as Dictionary
	var building_id_by_block_key: Dictionary = {}
	for proposal: Dictionary in proposals:
		var source_parcel := proposal.parcel as WarrenBuildingParcel
		var source_lineage := lineages.get(source_parcel.stable_id, {}) \
			as Dictionary
		if source_lineage.is_empty():
			continue
		var source_blocks := source_lineage.blocks as Array[Dictionary]
		for segment_index in source_blocks.size():
			var source_block := source_blocks[segment_index] as Dictionary
			building_id_by_block_key["%s/%d" % [source_parcel.stable_id,
				int(source_block.source_block_index)]] = StringName(
				"spatial.%s.part%02d" % [source_parcel.stable_id, segment_index])
	var buildings: Array[WarrenBuildingVolume] = []
	var supports := WarrenSupportGraph.new()
	var required_supports: Array[StringName] = []
	var terrain_support_ids: Array[StringName] = []
	var support_edges: Array[Dictionary] = []
	var room_count := 0
	var offset_blocks := 0
	var handoffs := 0
	# TASK C5 RULING 4. The plot model already decided which houses stand on
	# rock; empty on every legacy plan, so the check below is maze-only.
	var bears_on_rock_by_parcel := parcels.audit.get(
		"maze_parcel_bears_on_rock", {}) as Dictionary
	var unrooted_bearing: Array[Dictionary] = []
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		var lineage := lineages.get(parcel.stable_id, {}) as Dictionary
		if lineage.is_empty():
			continue
		var blocks := lineage.blocks as Array[Dictionary]
		if blocks.is_empty():
			continue
		var origin := proposal.origin as Vector3i
		var threshold := WarrenParcelConstruction.threshold_cell(parcel)
		for block: Dictionary in blocks:
			offset_blocks += int(StringName(block.kind) \
				!= StringName(block.original_kind) \
				or block.origin != block.original_origin \
				or int(block.yaw_quarters) \
					!= int(block.original_yaw_quarters))
		handoffs += maxi(0, blocks.size() - 1)
		var segment_ids: Array[StringName] = []
		for segment_index in blocks.size():
			segment_ids.append(StringName("spatial.%s.part%02d" % [
				StringName(parcel.stable_id), segment_index]))
		var threshold_segment := -1
		var transferred_address_parent := StringName(lineage.get(
			"address_parent_lineage_id", &""))
		var transferred_address_parent_block := int(lineage.get(
			"address_parent_source_block_index", -1))
		for segment_index in blocks.size():
			var block := blocks[segment_index] as Dictionary
			if threshold.y >= origin.y + int(block.start_storey) \
					* WarrenSpatialGrid.STOREY_CELLS \
					and threshold.y < origin.y + int(block.end_storey) \
						* WarrenSpatialGrid.STOREY_CELLS:
				threshold_segment = segment_index
				break
		if threshold_segment < 0 and transferred_address_parent.is_empty():
			last_failure = "3D composition removed addressed block for %s" \
				% parcel.stable_id
			return {}
		for segment_index in blocks.size():
			var block := blocks[segment_index] as Dictionary
			var building_id := segment_ids[segment_index]
			var cells := block.cells as Array[Vector3i]
			var assign := grid.begin_transaction(building_id)
			if not assign.require_use(cells,
					[WarrenSpatialGrid.Use.ALLOCATABLE,
						WarrenSpatialGrid.Use.OUTSIDE] as Array[int]) \
					or not assign.assign_use(cells,
						WarrenSpatialGrid.Use.PRIVATE_VOLUME, building_id) \
					or not assign.commit():
				var conflict_parts := PackedStringArray()
				for conflict_cell: Vector3i in cells:
					if grid.use_at(conflict_cell) \
							!= WarrenSpatialGrid.Use.ALLOCATABLE:
						conflict_parts.append("%s=%d/%s" % [conflict_cell,
							grid.use_at(conflict_cell),
							String(grid.owner_name_at(conflict_cell))])
						if conflict_parts.size() >= 8:
							break
				last_failure = "room segment %s rejected: %s conflicts=%s" % [
					building_id, assign.last_rejection,
					",".join(conflict_parts)]
				return {}
			var building := WarrenBuildingVolume.new(building_id,
				origin.y + int(block.start_storey) \
					* WarrenSpatialGrid.STOREY_CELLS)
			if not building.add_private_cells(cells):
				last_failure = "could not assign private cells to %s" % building_id
				return {}
			for storey in range(int(block.start_storey), int(block.end_storey)):
				var room_origin := Vector3i((block.origin as Vector3i).x,
					origin.y + storey * WarrenSpatialGrid.STOREY_CELLS,
					(block.origin as Vector3i).z)
				var room_cells := WarrenRoomStamp.expected_private_cells(
					StringName(block.kind), room_origin,
					int(block.yaw_quarters))
				var addressed := threshold_segment >= 0 \
					and threshold.y >= origin.y \
					+ storey * WarrenSpatialGrid.STOREY_CELLS \
					and threshold.y < origin.y \
						+ (storey + 1) * WarrenSpatialGrid.STOREY_CELLS
				var room_door_phase := WarrenParcelConstruction \
					.address_door_phase_for_room(StringName(block.kind), room_origin,
						int(block.yaw_quarters), threshold,
						Vector3i(parcel.frontage_direction.x, 0,
							parcel.frontage_direction.y)) if addressed else 0
				if addressed and room_door_phase < 0:
					last_failure = "recomposed room %s/%d lost exact threshold %s" % [
						parcel.stable_id, storey, threshold]
					return {}
				var support_parent_parcel_id := &""
				var support_parent_storey_index := -1
				if storey == int(block.start_storey) \
						and block.has("support_parent_lineage_id"):
					support_parent_parcel_id = StringName(
						block.support_parent_lineage_id)
					support_parent_storey_index = int(
						block.support_parent_source_storey)
				var terrain_bearing := storey == 0 and not block.has(
					"support_parent_lineage_id")
				if terrain_bearing and room_origin.y >= parcel.base_band \
						and bears_on_rock_by_parcel.has(parcel.stable_id) \
						and not bool(bears_on_rock_by_parcel[
							parcel.stable_id]):
					# Task C3 ruling 4's disagreement, published rather than
					# flipped. The plot says this house stands on ANOTHER PLOT,
					# and the composition rooted it in the mountain at its own
					# floor band -- so it wears a `base.rock` shell it has not
					# earned. It cannot simply be set false: an unrooted stamp
					# with no support parent does not seal, so the honest
					# answer is to name it.
					#
					# TASK C5c: THIS IS NO LONGER ZERO, and the old note here
					# ("zero once the stacked-house seam declares") was true
					# for the wrong reason. It read zero because a maze parcel
					# DESCENDED through the plot below and swallowed it, so no
					# room was ever left standing on another plot's roof. Fix 1
					# stopped that descent (`WarrenParcelConstruction
					# ._support_base_band`) and the disagreement it was hiding
					# is now visible and bounded: 3 / 4 / 1 on the three
					# sealing seeds, every one of them a plot whose seam
					# `WarrenMazeBlockPartitioner.stack_parents` could not
					# declare because its columns are covered by more than one
					# plot below (a PARTIAL stack).
					#
					# What such a house loses is its base PALETTE, not its
					# structure: `WarrenSpatialFabricCompiler
					# ._retained_foundation_cells` already refuses to lay a
					# masonry course on another house's roof. Closing it is the
					# partial-stack seam, a planner-side contract Phase E/F
					# owns. `UNROOTED_TERRAIN_BEARING_CEILING` pins the count
					# against the same derivation, so a NEW cause cannot hide
					# inside the tolerated one.
					unrooted_bearing.append({
						"parcel_id": parcel.stable_id,
						"origin": room_origin,
						"base_band": parcel.base_band})
				var room := WarrenRoomStamp.new(
					StringName("%s.room%02d" % [building_id,
						storey - int(block.start_storey)]), parcel.stable_id,
					StringName(block.kind), room_origin,
					int(block.yaw_quarters), storey, terrain_bearing,
					addressed, threshold if addressed else Vector3i(2147483647,
						2147483647, 2147483647),
					Vector3i(parcel.frontage_direction.x, 0,
						parcel.frontage_direction.y), int(proposal.roof_feature),
					support_parent_parcel_id, support_parent_storey_index,
					room_door_phase,
					# The parcel's own roof contract reaches the stamp here
					# (Task C5 ruling 1). False on every legacy proposal.
					bool(proposal.get("flat_roof", false)),
					# ... and its roof PREFERENCE beside it (Task C5d ruling
					# 2). Empty on every legacy proposal.
					StringName(proposal.get("roof_preference", &"")))
				if not room.add_private_cells(room_cells) \
						or not room.seal(grid, building_id) \
						or not building.add_room(room):
					last_failure = "could not record room stamp for %s" % building_id
					return {}
				room_count += 1
			if segment_index == threshold_segment:
				var public_cell := threshold + Vector3i(
					parcel.frontage_direction.x, 0,
					parcel.frontage_direction.y)
				if not building.add_threshold(threshold, public_cell):
					last_failure = "real threshold left room segment %s" % building_id
					return {}
			elif threshold_segment >= 0:
				var access_index := clampi(threshold_segment, 0,
					segment_ids.size() - 1)
				if not building.add_private_parent(segment_ids[access_index]):
					last_failure = "could not attach private segment %s" % building_id
					return {}
			elif segment_index == 0:
				var address_parent_key := "%s/%d" % [
					transferred_address_parent,
					transferred_address_parent_block]
				var address_parent_id := StringName(
					building_id_by_block_key.get(address_parent_key, &""))
				if address_parent_id.is_empty() \
						or not building.add_private_parent(address_parent_id):
					last_failure = "transferred address parent %s missing for %s" % [
						address_parent_key, building_id]
					return {}
			else:
				if not building.add_private_parent(segment_ids[0]):
					last_failure = "could not attach transferred private segment %s" \
						% building_id
					return {}
			for reservation_index in skywalk_reservations.size():
				var reservation := skywalk_reservations[reservation_index]
				var owner_ids := reservation.get("owner_parcel_ids", []) as Array
				var endpoints := reservation.get("owner_endpoints", []) as Array
				for endpoint_index in mini(owner_ids.size(), endpoints.size()):
					if StringName(owner_ids[endpoint_index]) != parcel.stable_id:
						continue
					var endpoint := endpoints[endpoint_index] as Dictionary
					if not building.has_private_cell(endpoint.cell as Vector3i):
						continue
					var feature_id := StringName("spatial.feature.skywalk.%02d" \
						% reservation_index)
					if not building.add_feature(feature_id):
						last_failure = "could not attach %s to %s" % [feature_id,
							building_id]
						return {}
			if StringName(market_reservation.get("backing_parcel_id", &"")) \
					== parcel.stable_id \
					and building.has_private_cell(
						market_reservation.get("backing_cell",
						Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i):
				if not building.add_feature(market_feature_id):
					last_failure = "could not attach covered market to %s" % building_id
					return {}
			var court_owner_ids := courtyard_bridge_reservation.get(
				"owner_parcel_ids", []) as Array
			var court_endpoints := courtyard_bridge_reservation.get(
				"owner_endpoints", []) as Array
			for endpoint_index in mini(court_owner_ids.size(),
					court_endpoints.size()):
				if StringName(court_owner_ids[endpoint_index]) != parcel.stable_id:
					continue
				var court_endpoint := court_endpoints[endpoint_index] as Dictionary
				if building.has_private_cell(court_endpoint.cell as Vector3i) \
						and not building.add_feature(
							COURTYARD_BRIDGE_FEATURE_ID):
					last_failure = "could not attach courtyard bridge house to %s" \
						% building_id
					return {}
			if not building.seal(grid):
				last_failure = "building %s rejected: %s" % [building_id,
					building.last_rejection]
				return {}
			buildings.append(building)
			if not supports.add_node(building_id):
				last_failure = "duplicate support node %s" % building_id
				return {}
			required_supports.append(building_id)
		for segment_index in segment_ids.size():
			var block := blocks[segment_index] as Dictionary
			var parent_key := ""
			if block.has("support_parent_lineage_id"):
				parent_key = "%s/%d" % [StringName(
					block.support_parent_lineage_id),
					int(block.support_parent_source_block_index)]
			elif segment_index > 0:
				var lower_block := blocks[segment_index - 1] as Dictionary
				parent_key = "%s/%d" % [parcel.stable_id,
					int(lower_block.source_block_index)]
			elif int(block.source_block_index) == 0:
				terrain_support_ids.append(segment_ids[segment_index])
				continue
			var parent_id := StringName(building_id_by_block_key.get(parent_key,
				&""))
			if parent_id.is_empty():
				last_failure = "composition support parent %s missing for %s" % [
					parent_key, segment_ids[segment_index]]
				return {}
			support_edges.append({"child": segment_ids[segment_index],
				"parent": parent_id})
	# The route-frontage parcelizer deliberately owns doors and hero sockets, but
	# it covers only about 22% of the inhabited source massif on the reviewed
	# seed. Do not erase the remaining mountain wholesale. Pack a bounded set of
	# complete roofable rooms into residual allocation, requiring real terrain or
	# inhabited bearing plus a face-adjacent private access parent. These are
	# ordinary WarrenBuildingVolume records and enter the same support, shell,
	# authored-envelope, and construction transactions as frontage buildings.
	# Before the greedy scan: the DIRECTED pass. A maze town's leftover plot
	# mass is not something to discover -- the plot planner assigned it to a
	# building already -- so it is stamped from the record rather than searched
	# for, and only what that pass cannot stand up is left to the greedy scan
	# below. `maze_back_rooms` exists on no searched plan, so this is a no-op
	# in every legacy mode.
	var back_rooms := _stamp_maze_back_rooms(grid, volume, parcels, proposals,
		buildings, supports, required_supports, terrain_support_ids,
		support_edges, protected_owners, construction_program)
	if bool(back_rooms.get("failed", false)):
		last_failure = "maze back-room stamping failed: %s" % last_failure
		return {}
	composition_audit["maze_back_room_record_count"] = int(
		back_rooms.get("record_count", 0))
	composition_audit["maze_back_room_rectangle_count"] = int(
		back_rooms.get("rectangle_count", 0))
	composition_audit["maze_back_room_building_count"] = int(
		back_rooms.get("building_count", 0))
	# RULING 3: a back room that found a street of its own, versus one reached
	# through the house in front of it.
	composition_audit["maze_back_rooms_addressed"] = int(
		back_rooms.get("addressed_count", 0))
	composition_audit["maze_back_rooms_private"] = int(
		back_rooms.get("private_count", 0))
	composition_audit["maze_back_rooms_unstamped_cells"] = (
		back_rooms.get("unstamped_cells", {}) as Dictionary).get("count", 0)
	composition_audit["maze_back_room_cell_count"] = int(
		back_rooms.get("cell_count", 0))
	composition_audit["maze_back_room_stamped_cell_count"] = int(
		back_rooms.get("stamped_cell_count", 0))
	composition_audit["maze_back_room_unstamped_cells"] = (
		back_rooms.get("unstamped_cells", {}) as Dictionary).duplicate(true)
	composition_audit["maze_back_room_refusals"] = (
		back_rooms.get("refusals", {}) as Dictionary).duplicate()
	# Bridges after back rooms and before the greedy scan: a bridge bears on
	# its two flanks, so every directed room that could BE a flank is standing
	# first, and the mass a released bridge leaves is still there for the scan.
	var bridges := _stamp_maze_bridges(grid, volume, parcels, buildings,
		supports, required_supports, terrain_support_ids, support_edges,
		protected_owners, construction_program)
	if bool(bridges.get("failed", false)):
		last_failure = "maze bridge stamping failed: %s" % last_failure
		return {}
	# Ruling 5, and before the greedy scan can claim the mass: a span no room
	# could stand on, whose two flanks both present a FLAT roof at its own
	# floor, is paved as an OPEN BRIDGE DECK -- a rooftop walkway -- instead
	# of shipping as rock.
	var bridge_outcomes := (bridges.get("outcomes",
		[]) as Array).duplicate(true)
	var unstamped_bridges: Dictionary = {}
	for outcome_value: Variant in bridge_outcomes:
		var bridge_outcome := outcome_value as Dictionary
		if String(bridge_outcome.get("outcome", "")) != "stamped":
			unstamped_bridges[StringName(bridge_outcome["id"])] = true
	var open_decks := _pave_open_bridge_decks(grid, volume,
		parcels.audit.get("maze_bridges", []) as Array, unstamped_bridges)
	if bool(open_decks.get("failed", false)):
		last_failure = "maze open bridge deck paving failed: %s" % last_failure
		return {}
	var paved_bridges := open_decks.get("paved_ids", {}) as Dictionary
	for outcome_value: Variant in bridge_outcomes:
		var bridge_outcome := outcome_value as Dictionary
		var flanks := (open_decks.get("flanks", {}) as Dictionary).get(
			StringName(bridge_outcome["id"]), {}) as Dictionary
		bridge_outcome["flat_flank_columns"] = int(flanks.get("columns", -1))
		bridge_outcome["flat_flank_sides"] = int(flanks.get("sides", -1))
		if paved_bridges.has(StringName(bridge_outcome["id"])):
			bridge_outcome["outcome"] = "open_deck"
			bridge_outcome["reason"] = ""
	# Published for a maze town and only for one: a legacy plan's audit gains
	# no zeroed key it has no records behind.
	if volume.mass_context.has(&"maze_source_plan"):
		var composed_parcels: Dictionary = {}
		for composed: WarrenBuildingVolume in buildings:
			for composed_room: WarrenRoomStamp in composed.room_records:
				composed_parcels[composed_room.source_parcel_id] = true
		var uncomposed_stacks := 0
		for child_value: Variant in (parcels.audit.get("maze_stack_parents",
				{}) as Dictionary).keys():
			uncomposed_stacks += int(not composed_parcels.has(
				StringName(child_value)))
		# A declared seam the composition never built on: the child parcel's
		# whole lineage was dropped, so the stack is a plan fact with no
		# building behind it. Published beside the declared count because
		# "declared 3" and "declared 3, built 0" are different towns.
		composition_audit["maze_uncomposed_stack_count"] = uncomposed_stacks
		# RULING 4. Every parcel that composed no lineage, with the gate that
		# dropped it. A parcel is a whole building's worth of plot mass, so an
		# uncomposed one is the single largest contribution a town can make to
		# its own quarry block; naming the gate is what lets the next pass fix
		# the fixable ones instead of guessing.
		var uncomposed_parcels: Array[Dictionary] = []
		var uncomposed_gates: Dictionary = {}
		for parcel: WarrenBuildingParcel in parcels.parcels:
			if composed_parcels.has(parcel.stable_id):
				continue
			var gate := StringName(parcel_gate_by_id.get(parcel.stable_id,
				&"structural_yielded_lineage"))
			uncomposed_parcels.append({"parcel_id": parcel.stable_id,
				"gate": gate, "floor": parcel.base_band,
				"top": parcel.top_band, "area": parcel.area_cells(),
				"detail": String(parcel_gate_detail_by_id.get(
					parcel.stable_id, ""))})
			uncomposed_gates[gate] = int(uncomposed_gates.get(gate, 0)) + 1
		uncomposed_parcels.sort_custom(func(a: Dictionary,
				b: Dictionary) -> bool:
			return String(a.parcel_id) < String(b.parcel_id))
		composition_audit["maze_uncomposed_parcels"] = uncomposed_parcels
		composition_audit["maze_uncomposed_parcel_count"] = \
			uncomposed_parcels.size()
		composition_audit["maze_uncomposed_parcel_gates"] = uncomposed_gates
		composition_audit["maze_parcel_count"] = parcels.parcels.size()
		composition_audit["maze_unrooted_terrain_bearing_count"] = \
			unrooted_bearing.size()
		composition_audit["maze_unrooted_terrain_bearing_details"] = \
			unrooted_bearing.duplicate(true)
		composition_audit["maze_deck_addressed_parcel_count"] = \
			deck_addressed_parcels
		composition_audit["maze_bridge_rooms"] = int(bridges.get("stamped", 0))
		composition_audit["maze_bridge_open_decks"] = paved_bridges.size()
		composition_audit["maze_bridge_open_deck_cell_count"] = (
			open_decks.get("floor_cells", []) as Array).size()
		composition_audit["maze_bridge_outcomes"] = bridge_outcomes
	if int(bridges.get("record_count", 0)) > 0:
		# Never a rejection: a span the flanks cannot carry ships as rock. An
		# open deck is not a shortfall -- the walkway is what the two flat
		# roofs beside it asked for -- so it leaves the count.
		last_advisory_shortfalls["bridges"] = int(bridges.get("released", 0)) \
			- paved_bridges.size()
	var backfill := _backfill_residual_rooms(grid, volume, buildings, supports,
		required_supports, terrain_support_ids, support_edges, protected_owners,
		scale_profile.residual_room_budget,
		scale_profile.residual_kind_budget, construction_program)
	if bool(backfill.get("failed", false)):
		last_failure = "residual room backfill failed: %s" % JSON.stringify(
			backfill.get("failure", backfill))
		return {}
	composition_audit["residual_backfill_building_count"] = int(
		backfill.get("building_count", 0))
	composition_audit["residual_backfill_private_cell_count"] = int(
		backfill.get("private_cell_count", 0))
	composition_audit["residual_backfill_kind_counts"] = (
		backfill.get("kind_counts", {}) as Dictionary).duplicate()
	composition_audit["residual_backfill_overhead_route_cell_count"] = int(
		backfill.get("overhead_route_cell_count", 0))
	composition_audit["residual_backfill_frontage_side_count"] = int(
		backfill.get("frontage_side_count", 0))
	composition_audit["residual_backfill_terrain_root_count"] = int(
		backfill.get("terrain_root_count", 0))
	composition_audit["residual_backfill_massif_edge_room_count"] = int(
		backfill.get("massif_edge_room_count", 0))
	composition_audit["residual_backfill_massif_edge_contact_count"] = int(
		backfill.get("massif_edge_contact_count", 0))
	composition_audit["residual_backfill_terrain_rooted_established_access_count"] = int(
		backfill.get("terrain_rooted_established_access_count", 0))
	composition_audit["residual_backfill_bridge_counts"] = (
		backfill.get("bridge_counts", {}) as Dictionary).duplicate()
	composition_audit["preplanned_skywalk_unique_route_cover_count"] = int(
		skywalk_plan.get("unique_route_cover_count", 0))
	composition_audit["preplanned_skywalk_marginal_route_cover_count"] = int(
		skywalk_plan.get("marginal_route_cover_count", 0))
	# Every stamped back room is one WarrenRoomStamp in the sealed plan, so it
	# belongs in the same count the greedy backfill's rooms do; leaving it out
	# made `room_stamp_count` understate a maze town by its whole directed pass.
	room_count += int(back_rooms.get("building_count", 0)) \
		+ int(backfill.get("building_count", 0))
	if buildings.size() < MIN_BUILDINGS:
		last_failure = "room partition formed only %d buildings" % buildings.size()
		return {}
	for root_id: StringName in terrain_support_ids:
		if not supports.mark_terrain_root(root_id):
			last_failure = "could not root %s" % root_id
			return {}
	for edge: Dictionary in support_edges:
		if not supports.add_edge(StringName(edge.child), StringName(edge.parent)):
			last_failure = "could not support %s from %s" % [edge.child,
				edge.parent]
			return {}
	if not supports.seal(required_supports):
		last_failure = "support DAG rejected: %s" % supports.last_rejection
		return {}
	last_failure = ""
	return {"open_bridge_deck_floor_cells": open_decks.get("floor_cells",
			[] as Array[Vector3i]) as Array[Vector3i],
		"buildings": buildings, "supports": supports,
		"room_count": room_count, "offset_blocks": offset_blocks,
		"handoffs": handoffs,
		"composition_audit": composition_audit,
		"rejected_unfloored_address_count": rejected_unfloored_addresses,
		"preplanned_skywalk_count": skywalk_reservations.size(),
		"skywalk_reservations": skywalk_reservations,
		"courtyard_bridge_reservation": courtyard_bridge_reservation,
		"landmark_reservations": landmark_reservations,
		"market_reservation": market_reservation}


static func _maze_feature_pass(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, parcels: WarrenParcelPlan,
		proposals: Array[Dictionary], program: SettlementFabricProgram,
		protected_owners: Dictionary,
		court_fixed_blocks_by_parcel: Dictionary, public_air: Dictionary,
		market_candidates: Array[Dictionary],
		enable_paired_registration_relief: bool) -> Dictionary:
	## The one-pass replacement for the joint hero-feature beam.
	##
	## A maze town's features are not something composition discovers: the plot
	## planner chose them, so there is nothing to search over and nothing a
	## richer trial could improve. Market, court, landmarks and links are
	## selected once, in that order, and every quota the source could not
	## supply becomes an entry in `last_advisory_shortfalls` rather than a
	## rejection. The dictionary returned is exactly what the beam's commit
	## writes into its own locals, so control rejoins the shared post-beam
	## code unchanged.
	##
	## Skywalks are deliberately absent here: the source's `maze_bridges` are
	## a later task's contract, and an empty link plan is an audit fact.
	var scale_profile := _scale_profile_for_volume(volume)
	# The bazaar: the first candidate of the corpus `_preplan_spatial_market`
	# already ranked. The beam retried the corpus only because a later hero
	# feature could consume the socket this one wanted; with no such feature
	# left to search for, the ranking's own first choice is the choice.
	# `_partition_rooms` owns the absent sentinel and substitutes it for an
	# empty market plan before this branch is reached, so there is exactly one
	# place a sentinel is born and the corpus here is never empty.
	assert(not market_candidates.is_empty())
	var market_reservation: Dictionary = market_candidates[0]
	if bool(market_reservation.get("optional_absent", false)):
		# Recorded whether or not the profile REQUIRES a market: a village
		# whose street could hold no measured canopy shipped without one, and
		# that is a fact about the town either way.
		last_advisory_shortfalls["covered_market"] = 0
	var market_owners := _protected_owners_with_market(protected_owners,
		market_reservation)
	var skywalk_plan: Dictionary = {
		"reservations": [] as Array[Dictionary],
		"selected_candidates": [] as Array[Dictionary],
		"forced_offsets": {}, "priority_cells": {},
		"candidate_count": 0,
	}
	# The threaded upper court is a size invariant of large and grand towns
	# only. Elsewhere the absent sentinel is the honest selection: it reserves
	# no cells, moves no rooms, and compiles no feature.
	var court := _maze_court_candidate(grid, volume, proposals, program,
		scale_profile, market_reservation, market_owners,
		court_fixed_blocks_by_parcel, public_air, skywalk_plan,
		enable_paired_registration_relief)
	var court_candidate := court.candidate as Dictionary
	var court_owners := _protected_owners_with_courtyard_bridge(market_owners,
		court_candidate)
	var assets := _maze_asset_landmarks(grid, volume, parcels, program,
		court_owners)
	var landmarks: Array[Dictionary] = []
	landmarks.assign(assets.reservations as Array)
	if int(assets.shortfall_count) > 0:
		last_advisory_shortfalls["assets"] = int(assets.shortfall_count)
	last_preplan_landmark_diagnostic = {
		"maze_asset_record_count": (assets.outcomes as Array).size(),
		"maze_asset_landmark_count": landmarks.size(),
		"maze_asset_outcomes": assets.outcomes,
	}
	last_preplan_skywalk_diagnostic = {"maze_skywalk_count": 0}
	return {
		"market_reservation": market_reservation,
		"courtyard_bridge_candidate": court_candidate,
		"courtyard_bridge_reservation": court_candidate.reservation \
			as Dictionary,
		"landmark_reservations": landmarks,
		"skywalk_plan": skywalk_plan,
		"selected_exact_composition": court.exact_composition as Dictionary,
		"selected_occluder_rank": {},
		"selected_court_alternatives": [court_candidate] as Array[Dictionary],
		"selected_market_landmark_owners": _protected_owners_with_landmarks(
			market_owners, landmarks),
		"asset_outcomes": assets.outcomes,
	}


static func _maze_court_candidate(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, proposals: Array[Dictionary],
		program: SettlementFabricProgram,
		scale_profile: WarrenVillageScaleProfile,
		market_reservation: Dictionary, market_owners: Dictionary,
		court_fixed_blocks_by_parcel: Dictionary, public_air: Dictionary,
		skywalk_plan: Dictionary,
		enable_paired_registration_relief: bool) -> Dictionary:
	## The court half of the one-pass feature selection. Profiles without an
	## elevated-court invariant take the absent sentinel outright; the ones
	## that have it take the FIRST cantilever whose exact room envelopes
	## survive, in the order `_courtyard_cantilever_room_candidates` produced
	## them. There is no ranking loop: a court the source cannot host is a
	## shortfall, exactly like a market it cannot host.
	var absent := _maze_dressed_court_candidate(
		_absent_courtyard_bridge_candidate())
	if not scale_profile.requires_elevated_courtyard:
		return {"candidate": absent, "exact_composition": {}}
	var raw_candidates := _courtyard_cantilever_room_candidates(grid, volume,
		proposals, program, market_owners, public_air)
	for raw_candidate: Dictionary in raw_candidates:
		var candidate := _maze_dressed_court_candidate(raw_candidate)
		var exact_result: Dictionary = {}
		if not _court_candidate_preserves_exact_room_envelopes(grid, volume,
				proposals, program, market_reservation, candidate,
				market_owners, court_fixed_blocks_by_parcel, skywalk_plan,
				enable_paired_registration_relief, exact_result):
			continue
		var composition := exact_result.get("composition", {}) as Dictionary \
			if not bool(exact_result.get("recomposition_required", false)) \
			else {}
		return {"candidate": candidate, "exact_composition": composition}
	last_advisory_shortfalls["courtyard_bridges"] = 0
	return {"candidate": absent, "exact_composition": {}}


static func _maze_dressed_court_candidate(
		raw_candidate: Dictionary) -> Dictionary:
	## The beam's own two lines of court bookkeeping: a deep copy carrying its
	## own reservation, stamped with the courtyard feature id so the post-beam
	## construction key matches the one it later searches alternatives by.
	var candidate := raw_candidate.duplicate(true)
	var reservation := (raw_candidate.reservation as Dictionary).duplicate(true)
	reservation["feature_id"] = COURTYARD_BRIDGE_FEATURE_ID
	candidate["reservation"] = reservation
	return candidate


static func _maze_asset_landmarks(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, parcels: WarrenParcelPlan,
		program: SettlementFabricProgram,
		protected_owners: Dictionary) -> Dictionary:
	## Every `maze_assets` record becomes a prefab-landmark reservation at the
	## site the planner costed for it, or a counted outcome saying why it could
	## not. An asset is never a rejection: its mass is already the plot
	## planner's, and a recipe that will not sit on it leaves that mass as the
	## derived rock it was, one landmark poorer and one audit line richer.
	##
	## Each accepted landmark joins the protected-owner map before the next
	## record is tried, which is how two assets whose measured clearance
	## envelopes overlap resolve deterministically instead of both committing.
	var reservations: Array[Dictionary] = []
	var outcomes: Array[Dictionary] = []
	var shortfall_count := 0
	var owners := protected_owners
	for record: Dictionary in parcels.audit.get("maze_assets", []) as Array:
		var attempt := _maze_asset_landmark(grid, volume, program, owners,
			record, reservations.size())
		var reservation := attempt.get("reservation", {}) as Dictionary
		outcomes.append({
			"id": StringName(record["id"]),
			"kind_id": StringName(record["kind_id"]),
			"placed": not reservation.is_empty(),
			"reason": String(attempt.get("reason", "")),
		})
		if reservation.is_empty():
			shortfall_count += 1
			continue
		reservations.append(reservation)
		owners = _protected_owners_with_landmarks(owners,
			[reservation] as Array[Dictionary])
	return {"reservations": reservations, "outcomes": outcomes,
		"shortfall_count": shortfall_count}


static func _maze_asset_landmark(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, program: SettlementFabricProgram,
		protected_owners: Dictionary, record: Dictionary,
		index: int) -> Dictionary:
	## One asset record against one catalog recipe at one site. This is the
	## per-candidate half of `_preplan_spatial_landmarks` with the search
	## removed: there the landing, recipe and yaw are enumerated over the whole
	## town; here the plot fixes the site, the planner fixed the recipe, and
	## the door fixes the facing, so the only remaining freedom is which fine
	## lane of the 3 m street cell the doorway opens onto.
	##
	## Returns `{reservation}` on success or `{reason}` on refusal; the same
	## measured facts the searched path admits a candidate on are what refuse
	## it here, so an asset that becomes a shortfall is one the fine grid
	## genuinely could not host.
	var kind_id := StringName(record["kind_id"])
	var recipe := program.recipe(kind_id)
	if recipe == null or not recipe.has_tag(&"prefab_anchor") \
			or not recipe.has_tag(&"terrain_bearing") \
			or recipe.bearing_parent_count != 0 \
			or recipe.entrances.is_empty():
		return {"reason": "%s is not an entranced terrain-rooted anchor" \
			% kind_id}
	var frontage := _maze_asset_frontage(record)
	if frontage == Vector2i.ZERO:
		return {"reason": "no footprint column fronts the plot's own door"}
	# From the doorway into the mass: the inverse of the frontage the plot
	# addressed its street across.
	var side := Vector3i(-frontage.x, 0, -frontage.y)
	var footprint := _maze_asset_fine_footprint(record)
	var entrance := recipe.entrances[0] as Dictionary
	var yaw := _yaw_for_direction(entrance.facing as Vector3i, -side)
	if yaw < 0:
		return {"reason": "%s has no yaw that opens its entrance onto %s" \
			% [kind_id, frontage]}
	var reasons := PackedStringArray()
	for landing: Vector3i in _maze_asset_landings(record, side, footprint):
		var origin := landing + side - FabricRecipe.transform_cell(
			entrance.cell as Vector3i, Vector3i.ZERO, yaw)
		var refusal := _maze_landmark_refusal(grid, volume, program, recipe,
			protected_owners, origin, yaw, landing, side, index)
		if refusal.has("reservation"):
			return refusal
		# Every lane is reported, not just the first: which of the two fine
		# doorways a 3 m street cell offers a prefab failed on, and how, is
		# the fact a template revision needs.
		reasons.append("lane %s: %s" % [landing, refusal.reason])
	if reasons.is_empty():
		return {"reason": "the plot's door cell offers no public landing"}
	return {"reason": "; ".join(reasons)}


static func _maze_landmark_refusal(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, program: SettlementFabricProgram,
		recipe: FabricRecipe, protected_owners: Dictionary,
		origin: Vector3i, yaw: int, landing: Vector3i, side: Vector3i,
		index: int) -> Dictionary:
	## The measured admission test, in the order `_preplan_spatial_landmarks`
	## applies it, each failure naming itself. Returns `{reservation}` or
	## `{reason}`.
	var entrance_cell := landing + side
	if not grid.contains(landing):
		return {"reason": "landing %s is outside the grid" % landing}
	var floor_claim := grid.face_claim(landing, Vector3i.DOWN)
	if grid.use_at(landing) != WarrenSpatialGrid.Use.PUBLIC_AIR \
			or floor_claim.is_empty() \
			or int(floor_claim.get("kind", -1)) \
				!= WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
		return {"reason": "landing %s is not canonical public floor" % landing}
	if not grid.contains(entrance_cell) \
			or grid.use_at(entrance_cell) not in [
				WarrenSpatialGrid.Use.OUTSIDE,
				WarrenSpatialGrid.Use.ALLOCATABLE]:
		return {"reason": "doorway cell %s is already spoken for" \
			% entrance_cell}
	var body: Dictionary = {}
	for cells: Array[Vector3i] in [recipe.solid_cells, recipe.headroom_cells,
			recipe.walk_cells]:
		for local_cell: Vector3i in cells:
			body[FabricRecipe.transform_cell(local_cell, origin, yaw)] = true
	if body.is_empty() or not _skywalk_body_fits_grid(grid, body):
		return {"reason": "body at %s/r%d does not fit the residual mass%s" \
			% [origin, yaw, _maze_body_conflict_text(grid, body)]}
	var bearing: Dictionary = {}
	for local_cell: Vector3i in recipe.terrain_bearing_cells:
		bearing[FabricRecipe.transform_cell(local_cell, origin, yaw)] = true
	if bearing.is_empty() or not _landmark_bearing_follows_terrain(bearing,
			volume):
		return {"reason": "bearing at band %d does not follow terrain" \
			% origin.y}
	var components: Array[Dictionary] = [{"recipe_id": recipe.recipe_id,
		"origin": origin, "yaw_quarters": yaw}]
	var clearance := _skywalk_visual_clearance_cells(components, program)
	var protected_cells := clearance.duplicate()
	protected_cells.merge(body, true)
	protected_cells.merge(bearing, true)
	if clearance.is_empty() or not _cells_fit_grid(grid, clearance) \
			or not _skywalk_clearance_fits_grid(grid, clearance) \
			or not _skywalk_clearance_fits_protected(protected_cells,
				protected_owners):
		return {"reason": ("measured clearance at %s leaves the grid or " \
			+ "meets another feature") % origin}
	# TASK C5c RULING 5, the other half of letting a prefab commit. A house's
	# AUTHORED SHELL is wider than its footprint -- native eaves overhang by a
	# fraction of a fine cell, which is why the residual scan carries a
	# one-cell `roof_eave_halo` -- so a prefab whose measured envelope stops
	# exactly at a neighbour's cells still meets that neighbour's roof in
	# `compile_room_units`, and there the verdict is the whole town rather than
	# one asset. Ask for the cell of air here instead.
	#
	# FIX 1, IMPORTANT 3: at the ROOF BAND ONLY, which is where the precedent
	# puts it. `_backfill_residual_rooms` halos `roof_clearance` cells -- the
	# band above a room -- and nothing else; halo every band of a prefab's
	# envelope and the rule stops being an eave rule and becomes a one-cell
	# setback from every wall, which refuses exactly the embedded siting
	# `_landmark_embeddedness` is asking for. Walls may meet; eaves may not.
	var envelope_top := -2147483648
	for cell_value: Variant in protected_cells.keys():
		envelope_top = maxi(envelope_top, (cell_value as Vector3i).y)
	var halo: Dictionary = {}
	for cell_value: Variant in protected_cells.keys():
		var cell := cell_value as Vector3i
		if cell.y != envelope_top:
			halo[cell] = true
			continue
		for z_offset in range(-1, 2):
			for x_offset in range(-1, 2):
				halo[cell + Vector3i(x_offset, 0, z_offset)] = true
	var blockers: Dictionary = {}
	for cell_value: Variant in halo.keys():
		for owner_value: Variant in (protected_owners.get(cell_value, {}) \
				as Dictionary).keys():
			blockers[StringName(owner_value)] = true
	if not blockers.is_empty():
		# The searched path DISPLACES the parcels a landmark overlaps. A maze
		# town may not: the plot planner already partitioned this mass and a
		# prefab is not entitled to delete a neighbour's house.
		#
		# Sorted, like every other landmark id list that reaches an audit:
		# a Dictionary's key order is cell iteration order, which would make
		# the published reason depend on where the overlap was noticed first.
		var blocker_ids: Array[StringName] = []
		blocker_ids.assign(blockers.keys())
		blocker_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b))
		return {"reason": "clearance overlaps %d plot(s): %s" % [
			blocker_ids.size(), blocker_ids]}
	var assets := recipe.asset_ids()
	var source_family := &"unknown" if assets.is_empty() else \
		StringName(String(assets[0]).get_slice(".", 0))
	var embeddedness := _landmark_embeddedness(protected_cells,
		protected_owners, blockers, grid)
	var socket_signature := _landmark_recipe_socket_signature(recipe, origin,
		yaw)
	return {"reservation": {
		"feature_id": StringName("spatial.feature.landmark.%02d" % index),
		"recipe_id": recipe.recipe_id, "source_family": source_family,
		# RULING 5: this reservation, and only this one, lets the commit skip
		# a ROOF face the public realm already owns -- see
		# `_reserve_landmark_preplan`.
		"route_roof_is_shared": true,
		"origin": origin, "yaw_quarters": yaw, "landing_cell": landing,
		"entrance_cell": entrance_cell, "entrance_facing": -side,
		"body": body, "bearing_cells": bearing, "clearance": clearance,
		"protected_cells": protected_cells,
		"blocker_parcels": blockers, "blocker_count": blockers.size(),
		"city_contact_side_count": embeddedness.side_count,
		"city_contact_edge_count": embeddedness.edge_count,
		"city_contact_score": embeddedness.score,
		"nearest_city_gap": embeddedness.nearest_gap,
		"transition_owner_ids": embeddedness.owner_ids,
		"height_cell_count": ceili(recipe.local_clearance_bounds.size.y \
			/ FabricRecipe.CELL_SIZE),
		"skywalk_socket_signature": socket_signature,
		"structural_signature": ("%s/body=%s/protected=%s/sockets=%s" % [
			source_family, _cell_set_signature(body),
			_cell_set_signature(protected_cells),
			socket_signature]).sha256_text(),
		"footprint_area": recipe.local_clearance_bounds.size.x \
			* recipe.local_clearance_bounds.size.z,
		# The searched path breaks ranking ties with a seeded hash. Nothing
		# ranks these, so the field is present for shape and constant.
		"tie": 0,
	}}


static func _maze_body_conflict_text(grid: WarrenSpatialGrid,
		body: Dictionary) -> String:
	## The first few cells of a refused prefab body that are not free mass, so
	## an audited shortfall says WHERE the template and the recipe disagree
	## instead of only that they did.
	var parts := PackedStringArray()
	var ordered: Array[Vector3i] = []
	ordered.assign(body.keys())
	ordered.sort_custom(_cell_less)
	for cell: Vector3i in ordered:
		if grid.contains(cell) and grid.use_at(cell) in [
				WarrenSpatialGrid.Use.OUTSIDE,
				WarrenSpatialGrid.Use.ALLOCATABLE]:
			continue
		parts.append("%s=%d" % [cell, grid.use_at(cell) \
			if grid.contains(cell) else -1])
		if parts.size() >= 4:
			break
	return "" if parts.is_empty() else " at %s" % ",".join(parts)


static func _maze_asset_frontage(record: Dictionary) -> Vector2i:
	## The cardinal from the asset's own footprint toward the street cell the
	## planner addressed it across. Scanned in one fixed order so the answer is
	## a pure function of the record.
	var columns: Dictionary = {}
	for cell_value: Variant in record["cells"] as Array:
		columns[cell_value as Vector2i] = true
	var door_walk := record["door_walk"] as Vector3i
	var door_column := Vector2i(door_walk.x, door_walk.z)
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
			Vector2i.UP]:
		if columns.has(door_column - direction):
			return direction
	return Vector2i.ZERO


static func _maze_asset_fine_footprint(record: Dictionary) -> Dictionary:
	## The plot's macro columns at construction resolution: four fine cells per
	## column, all at the plot's own floor band.
	var out: Dictionary = {}
	var floor_band := int(record["floor"])
	for cell_value: Variant in record["cells"] as Array:
		var column := cell_value as Vector2i
		for x_offset in 2:
			for z_offset in 2:
				out[Vector3i(column.x * 2 + x_offset, floor_band,
					column.y * 2 + z_offset)] = true
	return out


static func _maze_asset_landings(record: Dictionary, side: Vector3i,
		footprint: Dictionary) -> Array[Vector3i]:
	## The fine public lanes of the plot's own 3 m door cell that actually face
	## its footprint. A macro street cell carries two lanes across and two
	## along; only the ones whose inward neighbour is plot mass can be this
	## landmark's doorway, which leaves at most two, in sorted order.
	var door_walk := record["door_walk"] as Vector3i
	var out: Array[Vector3i] = []
	for x_offset in 2:
		for z_offset in 2:
			var landing := Vector3i(door_walk.x * 2 + x_offset, door_walk.y,
				door_walk.z * 2 + z_offset)
			if footprint.has(landing + side):
				out.append(landing)
	out.sort_custom(_cell_less)
	return out


static func _parcel_address_has_public_floor(grid: WarrenSpatialGrid,
		parcel: WarrenBuildingParcel) -> bool:
	if grid == null or parcel == null:
		return false
	var threshold := WarrenParcelConstruction.threshold_cell(parcel)
	if threshold.x == 2147483647:
		return false
	var landing := threshold + Vector3i(parcel.frontage_direction.x, 0,
		parcel.frontage_direction.y)
	var floor_claim := grid.face_claim(landing, Vector3i.DOWN)
	return grid.use_at(landing) == WarrenSpatialGrid.Use.PUBLIC_AIR \
		and not floor_claim.is_empty() \
		and int(floor_claim.get("kind", -1)) \
			== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR


static func _preplan_spatial_landmarks(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, program: SettlementFabricProgram,
		protected_owners: Dictionary, market_reservation: Dictionary,
		skywalk_reservations: Array[Dictionary],
		additional_required_parcels: Array[StringName] = []) -> Dictionary:
	var required_parcels: Dictionary = {
		StringName(market_reservation.get("backing_parcel_id", &"")): true,
	}
	for reservation: Dictionary in skywalk_reservations:
		for parcel_value: Variant in reservation.get("owner_parcel_ids", []):
			required_parcels[StringName(parcel_value)] = true
	for parcel_id: StringName in additional_required_parcels:
		required_parcels[parcel_id] = true
	required_parcels.erase(&"")
	# Compact warrens use the shipped 6--9 m complete-house family. A 15 m-wide
	# prefab can satisfy a span-only gate while still dominating the whole village
	# by footprint and height, so all three measured dimensions participate in the
	# scale contract. Broader source silhouettes remain available as the selected
	# fabric grows; meshes are never scaled.
	var scale_profile_id := StringName(volume.mass_context.get(
		&"scale_profile_id", WarrenVillageScaleProfile.LARGE))
	var maximum_prefab_span := 21.0
	var maximum_prefab_height := INF
	var maximum_prefab_area := INF
	match scale_profile_id:
		WarrenVillageScaleProfile.COMPACT:
			maximum_prefab_span = 10.0
			maximum_prefab_height = 9.0
			maximum_prefab_area = 75.0
		WarrenVillageScaleProfile.STANDARD:
			maximum_prefab_span = 24.0
		WarrenVillageScaleProfile.LARGE:
			maximum_prefab_span = 30.0
		WarrenVillageScaleProfile.GRAND:
			maximum_prefab_span = 36.0
	var prefab_catalog_count := 0
	var prefab_recipes: Array[FabricRecipe] = []
	for recipe: FabricRecipe in program.recipes():
		if not recipe.has_tag(&"prefab_anchor"):
			continue
		prefab_catalog_count += 1
		var bounds := recipe.local_clearance_bounds
		if not recipe.entrances.is_empty() \
			and maxf(bounds.size.x, bounds.size.z) <= maximum_prefab_span \
			and bounds.size.y <= maximum_prefab_height \
			and bounds.size.x * bounds.size.z <= maximum_prefab_area:
			prefab_recipes.append(recipe)
	var prefab_stamps: Dictionary = {}
	for recipe: FabricRecipe in prefab_recipes:
		for yaw in 4:
			var local_body: Dictionary = {}
			for cells: Array[Vector3i] in [recipe.solid_cells,
					recipe.headroom_cells, recipe.walk_cells]:
				for local_cell: Vector3i in cells:
					local_body[FabricRecipe.transform_cell(local_cell,
						Vector3i.ZERO, yaw)] = true
			var local_bearing: Dictionary = {}
			for local_cell: Vector3i in recipe.terrain_bearing_cells:
				local_bearing[FabricRecipe.transform_cell(local_cell,
					Vector3i.ZERO, yaw)] = true
			var components: Array[Dictionary] = [{"recipe_id": recipe.recipe_id,
				"origin": Vector3i.ZERO, "yaw_quarters": yaw}]
			prefab_stamps["%s/r%d" % [recipe.recipe_id, yaw]] = {
				"body": local_body, "bearing": local_bearing,
				"clearance": _skywalk_visual_clearance_cells(components,
					program),
			}
	var candidates: Array[Dictionary] = []
	var landing_count := 0
	var body_fit_count := 0
	var bearing_fit_count := 0
	var clearance_fit_count := 0
	var mandatory_rejection_count := 0
	var seen: Dictionary = {}
	for landing: Vector3i in grid.cells_with_use(
			WarrenSpatialGrid.Use.PUBLIC_AIR):
		var floor_claim := grid.face_claim(landing, Vector3i.DOWN)
		if landing.y > 1 or floor_claim.is_empty() \
				or int(floor_claim.kind) != WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
			continue
		landing_count += 1
		for side: Vector3i in WarrenSpatialFeatureSolver.SKY_DIRECTIONS:
			if grid.use_at(landing + side) not in [WarrenSpatialGrid.Use.OUTSIDE,
					WarrenSpatialGrid.Use.ALLOCATABLE]:
				continue
			for recipe: FabricRecipe in prefab_recipes:
				var entrance := recipe.entrances[0] as Dictionary
				var yaw := _yaw_for_direction(entrance.facing as Vector3i, -side)
				if yaw < 0:
					continue
				var origin := landing + side - FabricRecipe.transform_cell(
					entrance.cell as Vector3i, Vector3i.ZERO, yaw)
				var key := "%s@%s/r%d" % [recipe.recipe_id, origin, yaw]
				if seen.has(key):
					continue
				seen[key] = true
				var stamp := prefab_stamps["%s/r%d" % [recipe.recipe_id, yaw]] \
					as Dictionary
				var body := _translated_cell_set(stamp.body as Dictionary, origin)
				if body.is_empty() or not _skywalk_body_fits_grid(grid, body):
					continue
				body_fit_count += 1
				var bearing := _translated_cell_set(stamp.bearing as Dictionary,
					origin)
				if bearing.is_empty() or not _landmark_bearing_follows_terrain(
						bearing, volume):
					continue
				bearing_fit_count += 1
				var clearance := _translated_cell_set(stamp.clearance as Dictionary,
					origin)
				var protected_cells := clearance.duplicate()
				protected_cells.merge(body, true)
				protected_cells.merge(bearing, true)
				if clearance.is_empty() or not _cells_fit_grid(grid, clearance) \
						or not _skywalk_clearance_fits_grid(grid, clearance) \
						or not _skywalk_clearance_fits_protected(protected_cells,
							protected_owners):
					continue
				clearance_fit_count += 1
				var blockers: Dictionary = {}
				var mandatory_hit := false
				for cell_value: Variant in protected_cells.keys():
					for owner_value: Variant in (protected_owners.get(cell_value, {}) \
							as Dictionary).keys():
						var owner_id := StringName(owner_value)
						if required_parcels.has(owner_id) \
								or _protected_owner_is_feature(owner_id):
							mandatory_hit = true
						else:
							blockers[owner_id] = true
				if mandatory_hit:
					mandatory_rejection_count += 1
					continue
				var assets := recipe.asset_ids()
				var source_family := &"unknown" if assets.is_empty() else \
					StringName(String(assets[0]).get_slice(".", 0))
				var embeddedness := _landmark_embeddedness(protected_cells,
					protected_owners, blockers, grid)
				var skywalk_socket_signature := \
					_landmark_recipe_socket_signature(recipe, origin, yaw)
				var structural_signature := \
					("%s/body=%s/protected=%s/sockets=%s" % [source_family,
						_cell_set_signature(body),
						_cell_set_signature(protected_cells),
						skywalk_socket_signature]).sha256_text()
				candidates.append({"recipe_id": recipe.recipe_id,
					"source_family": source_family, "origin": origin,
					"yaw_quarters": yaw, "landing_cell": landing,
					"entrance_cell": landing + side,
					"entrance_facing": -side,
					"body": body, "bearing_cells": bearing,
					"clearance": clearance, "protected_cells": protected_cells,
					"blocker_parcels": blockers,
					"blocker_count": blockers.size(),
					"city_contact_side_count": embeddedness.side_count,
					"city_contact_edge_count": embeddedness.edge_count,
					"city_contact_score": embeddedness.score,
					"nearest_city_gap": embeddedness.nearest_gap,
					"transition_owner_ids": embeddedness.owner_ids,
					"height_cell_count": ceili(
						recipe.local_clearance_bounds.size.y \
							/ FabricRecipe.CELL_SIZE),
					"skywalk_socket_signature": skywalk_socket_signature,
					"structural_signature": structural_signature,
					"footprint_area": recipe.local_clearance_bounds.size.x \
						* recipe.local_clearance_bounds.size.z,
					"tie": posmod(Helper._mix64(volume.world_seed \
						^ String(recipe.recipe_id).hash() ^ origin.x * 31 \
						^ origin.z * 47 ^ yaw * 131), 1000003)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.blocker_count) != int(b.blocker_count):
			return int(a.blocker_count) > int(b.blocker_count)
		if not is_equal_approx(float(a.footprint_area), float(b.footprint_area)):
			return float(a.footprint_area) > float(b.footprint_area)
		return int(a.tie) < int(b.tie))
	var candidate_preview: Array[Dictionary] = []
	for candidate_index in mini(8, candidates.size()):
		var candidate := candidates[candidate_index]
		var blocker_ids: Array[StringName] = []
		blocker_ids.assign((candidate.blocker_parcels as Dictionary).keys())
		blocker_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b))
		candidate_preview.append({"recipe_id": candidate.recipe_id,
			"source_family": candidate.source_family,
			"origin": candidate.origin,
			"yaw_quarters": candidate.yaw_quarters,
			"landing_cell": candidate.landing_cell,
			"entrance_cell": candidate.entrance_cell,
			"body_cell_count": (candidate.body as Dictionary).size(),
			"clearance_cell_count": (candidate.clearance as Dictionary).size(),
			"blocker_count": candidate.blocker_count,
			"blocker_parcels": blocker_ids,
			"city_contact_side_count": candidate.city_contact_side_count,
			"city_contact_edge_count": candidate.city_contact_edge_count,
			"city_contact_score": candidate.city_contact_score,
			"nearest_city_gap": candidate.nearest_city_gap,
			"transition_owner_ids": candidate.transition_owner_ids,
			"footprint_area": candidate.footprint_area})
	last_preplan_landmark_diagnostic = {"landing_count": landing_count,
		"prefab_catalog_count": prefab_catalog_count,
		"prefab_recipe_count": prefab_recipes.size(),
		"maximum_prefab_span_m": maximum_prefab_span,
		"maximum_prefab_height_m": maximum_prefab_height,
		"maximum_prefab_area_m2": maximum_prefab_area,
		"body_fit_count": body_fit_count,
		"bearing_fit_count": bearing_fit_count,
		"clearance_fit_count": clearance_fit_count,
		"mandatory_rejection_count": mandatory_rejection_count,
		"candidate_count": candidates.size(),
		"candidate_preview": candidate_preview}
	return {"candidates": candidates}


static func _landmark_embeddedness_has_city_seam(audit: Dictionary) -> bool:
	return int(audit.get("side_count", 0)) > 0 \
		and int(audit.get("nearest_gap",
			LANDMARK_CITY_CONTACT_RADIUS_CELLS + 1)) \
			<= MAX_LANDMARK_CITY_GAP_CELLS


static func _translated_cell_set(local_cells: Dictionary,
		origin: Vector3i) -> Dictionary:
	var out: Dictionary = {}
	for value: Variant in local_cells.keys():
		out[(value as Vector3i) + origin] = true
	return out


static func _landmark_embeddedness(protected_cells: Dictionary,
		protected_owners: Dictionary, blocker_parcels: Dictionary,
		grid: WarrenSpatialGrid = null) -> Dictionary:
	## Collapse the authored 3D envelope to its horizontal silhouette, then look
	## outward from every boundary face for surviving room envelopes.  Blocked
	## parcels do not count: they will be removed by the landmark transaction and
	## cannot visually bridge it back into the town.  Feature owners likewise do
	## not count; a market canopy or another hero reservation is not a terrain-
	## rooted transition house.
	var footprint: Dictionary = {}
	var minimum_y := 2147483647
	var maximum_y := -2147483648
	for cell_value: Variant in protected_cells.keys():
		var cell := cell_value as Vector3i
		footprint[Vector2i(cell.x, cell.z)] = true
		minimum_y = mini(minimum_y, cell.y)
		maximum_y = maxi(maximum_y, cell.y)
	if footprint.is_empty():
		return {"side_count": 0, "edge_count": 0, "score": 0,
			"nearest_gap": LANDMARK_CITY_CONTACT_RADIUS_CELLS + 1,
			"owner_ids": [] as Array[StringName]}
	var touched_sides: Dictionary = {}
	var touched_owners: Dictionary = {}
	var edge_count := 0
	var score := 0
	var nearest_gap := LANDMARK_CITY_CONTACT_RADIUS_CELLS + 1
	for column_value: Variant in footprint.keys():
		var column := column_value as Vector2i
		for direction_3d: Vector3i in WarrenSpatialFeatureSolver.SKY_DIRECTIONS:
			var direction := Vector2i(direction_3d.x, direction_3d.z)
			if footprint.has(column + direction):
				continue
			var boundary_hit := false
			for distance in range(1, LANDMARK_CITY_CONTACT_RADIUS_CELLS + 1):
				var target := column + direction * distance
				if footprint.has(target):
					break
				# Distance two is admitted only when its one intervening column is
				# an exact public lane. Without this check, the same metric treats a
				# strip of open lawn as urban integration.
				if distance > 1 and grid != null \
						and not _landmark_gap_is_public_lane(grid, column,
							direction, distance, minimum_y, maximum_y):
					continue
				var distance_owners: Dictionary = {}
				for y in range(minimum_y - 1, maximum_y + 2):
					for owner_value: Variant in (protected_owners.get(
							Vector3i(target.x, y, target.y), {}) as Dictionary).keys():
						var owner_id := StringName(owner_value)
						if blocker_parcels.has(owner_id) \
								or _protected_owner_is_feature(owner_id):
							continue
						distance_owners[owner_id] = true
				if distance_owners.is_empty():
					continue
				boundary_hit = true
				edge_count += 1
				score += LANDMARK_CITY_CONTACT_RADIUS_CELLS + 1 - distance
				nearest_gap = mini(nearest_gap, distance)
				touched_sides[direction] = true
				touched_owners.merge(distance_owners, true)
				break
			if boundary_hit:
				continue
	var owner_ids: Array[StringName] = []
	owner_ids.assign(touched_owners.keys())
	owner_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return {"side_count": touched_sides.size(), "edge_count": edge_count,
		"score": score, "nearest_gap": nearest_gap, "owner_ids": owner_ids}


static func _landmark_gap_is_public_lane(grid: WarrenSpatialGrid,
		boundary_column: Vector2i, direction: Vector2i, distance: int,
		minimum_y: int, maximum_y: int) -> bool:
	if grid == null or distance <= 1:
		return distance <= 1
	for step in range(1, distance):
		var column := boundary_column + direction * step
		var has_public_floor := false
		for y in range(minimum_y - 1, maximum_y + 2):
			var cell := Vector3i(column.x, y, column.y)
			if grid.use_at(cell) != WarrenSpatialGrid.Use.PUBLIC_AIR:
				continue
			var floor_claim := grid.face_claim(cell, Vector3i.DOWN)
			if not floor_claim.is_empty() and int(floor_claim.get("kind", -1)) \
					== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
				has_public_floor = true
				break
		if not has_public_floor:
			return false
	return true


static func _landmark_set_embeddedness(
		reservations: Array[Dictionary]) -> Dictionary:
	var minimum_side_count := 4
	var side_count := 0
	var edge_count := 0
	var score := 0
	var maximum_gap := 0
	var owner_ids: Dictionary = {}
	for reservation: Dictionary in reservations:
		var reservation_sides := int(reservation.get(
			"city_contact_side_count", 0))
		minimum_side_count = mini(minimum_side_count, reservation_sides)
		side_count += reservation_sides
		edge_count += int(reservation.get("city_contact_edge_count", 0))
		score += int(reservation.get("city_contact_score", 0))
		maximum_gap = maxi(maximum_gap, int(reservation.get("nearest_city_gap",
			LANDMARK_CITY_CONTACT_RADIUS_CELLS + 1)))
		for owner_value: Variant in reservation.get("transition_owner_ids", []):
			owner_ids[StringName(owner_value)] = true
	if reservations.is_empty():
		minimum_side_count = 0
	return {"minimum_city_contact_side_count": minimum_side_count,
		"city_contact_side_count": side_count,
		"city_contact_edge_count": edge_count,
		"city_contact_score": score,
		"maximum_city_gap": maximum_gap,
		"transition_owner_count": owner_ids.size()}


static func _landmark_candidate_sets(candidates: Array[Dictionary],
		world_seed: int, target_count: int = 2) -> Array[Dictionary]:
	## Every size may compose complete shipped buildings into its segmented mass,
	## but only when their measured footprint, doorway, bearing, and city-contact
	## facts fit. Selection still precedes the skywalk beam so connectors route
	## around the final authored mass instead of consuming its only viable anchor.
	assert(target_count >= 0 and target_count <= 8)
	var out: Array[Dictionary] = []
	if target_count == 0:
		out.append({"reservations": [] as Array[Dictionary],
			"distinct_source_families": false,
			"displaced_parcel_count": 0,
			"protected_cell_count": 0,
			"separation_squared": 0,
			"footprint_area": 0.0,
			"tie": posmod(Helper._mix64(world_seed ^ 0x17983), 1000003)})
		return out
	if target_count == 1:
		for candidate: Dictionary in candidates:
			var reservation := candidate.duplicate(true)
			reservation["feature_id"] = &"spatial.feature.landmark.00"
			var candidate_set := {"reservations": [reservation] as Array[Dictionary],
				"distinct_source_families": false,
				"displaced_parcel_count": (
					candidate.blocker_parcels as Dictionary).size(),
				"protected_cell_count": (
					candidate.protected_cells as Dictionary).size(),
				"separation_squared": 0,
				"footprint_area": float(candidate.footprint_area),
				"tie": posmod(Helper._mix64(world_seed \
					^ String(candidate.recipe_id).hash() \
					^ (candidate.landing_cell as Vector3i).x * 31 \
					^ (candidate.landing_cell as Vector3i).z * 47), 1000003)}
			candidate_set.merge(_landmark_set_embeddedness(
				candidate_set.reservations as Array[Dictionary]), true)
			out.append(candidate_set)
	if target_count > 3:
		out = _landmark_candidate_set_beam(candidates, world_seed,
			target_count)
	if target_count == 3:
		for first_index in candidates.size():
			for second_index in range(first_index + 1, candidates.size()):
				var first_candidate := candidates[first_index]
				var second_candidate := candidates[second_index]
				if not _landmark_candidates_compatible(first_candidate,
						second_candidate):
					continue
				for third_index in range(second_index + 1, candidates.size()):
					var third_candidate := candidates[third_index]
					if not _landmark_candidates_compatible(first_candidate,
							third_candidate) \
							or not _landmark_candidates_compatible(
								second_candidate, third_candidate):
						continue
					var reservations: Array[Dictionary] = []
					var blocker_union: Dictionary = {}
					var protected_union: Dictionary = {}
					var source_families: Dictionary = {}
					var landing_cells: Array[Vector3i] = []
					var footprint_area := 0.0
					var tie_value := world_seed
					for candidate_value: Dictionary in [first_candidate,
							second_candidate, third_candidate]:
						var reservation := candidate_value.duplicate(true)
						reservation["feature_id"] = StringName(
							"spatial.feature.landmark.%02d" % reservations.size())
						reservations.append(reservation)
						blocker_union.merge(candidate_value.blocker_parcels \
							as Dictionary, true)
						protected_union.merge(candidate_value.protected_cells \
							as Dictionary, true)
						source_families[StringName(candidate_value.source_family)] = true
						var landing := candidate_value.landing_cell as Vector3i
						landing_cells.append(landing)
						footprint_area += float(candidate_value.footprint_area)
						tie_value ^= String(candidate_value.recipe_id).hash() \
							^ landing.x * (31 + reservations.size() * 17) \
							^ landing.z * (47 + reservations.size() * 19)
					var separation := 0
					for left_landing_index in landing_cells.size():
						for right_landing_index in range(left_landing_index + 1,
								landing_cells.size()):
							var delta := Vector2i(
								landing_cells[left_landing_index].x \
									- landing_cells[right_landing_index].x,
								landing_cells[left_landing_index].z \
									- landing_cells[right_landing_index].z)
							separation += delta.length_squared()
					var candidate_set := {"reservations": reservations,
						"distinct_source_families": source_families.size() > 1,
						"displaced_parcel_count": blocker_union.size(),
						"protected_cell_count": protected_union.size(),
						"separation_squared": separation,
						"footprint_area": footprint_area,
						"tie": posmod(Helper._mix64(tie_value), 1000003)}
					candidate_set.merge(_landmark_set_embeddedness(reservations), true)
					out.append(candidate_set)
	for left_index in candidates.size():
		if target_count != 2:
			break
		for right_index in range(left_index + 1, candidates.size()):
			var left := candidates[left_index]
			var right := candidates[right_index]
			if not _landmark_candidates_compatible(left, right):
				continue
			var first := left.duplicate(true)
			var second := right.duplicate(true)
			first["feature_id"] = &"spatial.feature.landmark.00"
			second["feature_id"] = &"spatial.feature.landmark.01"
			var blocker_union := (left.blocker_parcels as Dictionary).duplicate()
			blocker_union.merge(right.blocker_parcels as Dictionary, true)
			var protected_union := (left.protected_cells as Dictionary).duplicate()
			protected_union.merge(right.protected_cells as Dictionary, true)
			var left_landing := left.landing_cell as Vector3i
			var right_landing := right.landing_cell as Vector3i
			var separation := Vector2i(left_landing.x - right_landing.x,
				left_landing.z - right_landing.z).length_squared()
			var distinct_family: bool = left.source_family != right.source_family
			var reservations := [first, second] as Array[Dictionary]
			var candidate_set := {"reservations": reservations,
				"distinct_source_families": distinct_family,
				"displaced_parcel_count": blocker_union.size(),
				"protected_cell_count": protected_union.size(),
				"separation_squared": separation,
				"footprint_area": float(left.footprint_area) \
					+ float(right.footprint_area),
				"tie": posmod(Helper._mix64(world_seed \
					^ String(left.recipe_id).hash() \
					^ String(right.recipe_id).hash() \
					^ left_landing.x * 31 ^ left_landing.z * 47 \
					^ right_landing.x * 73 ^ right_landing.z * 89), 1000003)}
			candidate_set.merge(_landmark_set_embeddedness(reservations), true)
			out.append(candidate_set)
	out.sort_custom(_landmark_set_precedes)
	var raw_compatible_count := out.size()
	var structural_order: Array[String] = []
	var representative_by_structure: Dictionary = {}
	for candidate_set: Dictionary in out:
		var structural_key := _landmark_structural_set_key(
			candidate_set.reservations as Array[Dictionary])
		if not representative_by_structure.has(structural_key):
			structural_order.append(structural_key)
			representative_by_structure[structural_key] = candidate_set
			continue
		# Identical body/clearance/socket contracts share one topology proof, but
		# they need not share one exterior forever. Select the reviewed complete
		# mesh with the seed-derived tie after structural ranking, so House_01,
		# House_02, and House_07 can vary between towns without multiplying the
		# hero-feature search frontier.
		var existing := representative_by_structure[structural_key] as Dictionary
		if int(candidate_set.tie) < int(existing.tie):
			representative_by_structure[structural_key] = candidate_set
	var unique: Array[Dictionary] = []
	for structural_key: String in structural_order:
		unique.append(representative_by_structure[structural_key] as Dictionary)
	out = unique
	last_preplan_landmark_diagnostic["raw_compatible_pair_count"] = \
		raw_compatible_count
	last_preplan_landmark_diagnostic["compatible_pair_count"] = out.size()
	var pair_preview: Array[Dictionary] = []
	for pair_index in mini(8, out.size()):
		var pair := out[pair_index]
		var reservations := pair.reservations as Array[Dictionary]
		var landing_cells: Array[Vector3i] = []
		for reservation: Dictionary in reservations:
			landing_cells.append(reservation.landing_cell as Vector3i)
		pair_preview.append({"recipe_ids": _landmark_recipe_ids(reservations),
			"landing_cells": landing_cells,
			"distinct_source_families": pair.distinct_source_families,
			"minimum_city_contact_side_count": pair.minimum_city_contact_side_count,
			"city_contact_side_count": pair.city_contact_side_count,
			"city_contact_score": pair.city_contact_score,
			"maximum_city_gap": pair.maximum_city_gap,
			"transition_owner_count": pair.transition_owner_count,
			"displaced_parcel_count": pair.displaced_parcel_count,
			"protected_cell_count": pair.protected_cell_count,
			"separation_squared": pair.separation_squared,
			"footprint_area": pair.footprint_area})
	last_preplan_landmark_diagnostic["pair_preview"] = pair_preview
	return out


static func _landmark_candidate_set_beam(candidates: Array[Dictionary],
		world_seed: int, target_count: int) -> Array[Dictionary]:
	## Search compatible complete-building sets at bounded cost. Structurally
	## identical mesh alternatives at one transform share the same topology state;
	## the seed chooses their representative before the beam, exactly as the old
	## pair/triple dedup did after exhaustive enumeration.
	assert(target_count > 3 and target_count <= 8)
	var representative_by_structure: Dictionary = {}
	var structural_order := PackedStringArray()
	for candidate: Dictionary in candidates:
		var key := String(candidate.get("structural_signature",
			_landmark_reservation_search_key(candidate)))
		if not representative_by_structure.has(key):
			structural_order.append(key)
			representative_by_structure[key] = candidate
		elif int(candidate.get("tie", 0)) < int((representative_by_structure[key]
				as Dictionary).get("tie", 0)):
			representative_by_structure[key] = candidate
	var unique_candidates: Array[Dictionary] = []
	for key: String in structural_order:
		unique_candidates.append(representative_by_structure[key] as Dictionary)
	var states: Array[Dictionary] = [{
		"selection": [] as Array[Dictionary], "next_index": 0,
	}]
	for _depth in target_count:
		var expanded: Array[Dictionary] = []
		for state: Dictionary in states:
			var selected := state.selection as Array[Dictionary]
			for candidate_index in range(int(state.next_index),
					unique_candidates.size()):
				var candidate := unique_candidates[candidate_index]
				var compatible := true
				for existing: Dictionary in selected:
					if not _landmark_candidates_compatible(existing, candidate):
						compatible = false
						break
				if not compatible:
					continue
				var next_selection: Array[Dictionary] = []
				next_selection.assign(selected)
				next_selection.append(candidate)
				expanded.append({"selection": next_selection,
					"next_index": candidate_index + 1,
					"set": _landmark_set_from_candidates(next_selection,
						world_seed)})
		if expanded.is_empty():
			return [] as Array[Dictionary]
		expanded.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _landmark_set_precedes(a.set as Dictionary,
				b.set as Dictionary))
		var seen_structures: Dictionary = {}
		states = []
		for state: Dictionary in expanded:
			var structural_key := _landmark_structural_set_key(
				(state.set as Dictionary).reservations as Array[Dictionary])
			if seen_structures.has(structural_key):
				continue
			seen_structures[structural_key] = true
			states.append(state)
			if states.size() >= MAX_LANDMARK_SET_BEAM:
				break
	var out: Array[Dictionary] = []
	for state: Dictionary in states:
		out.append(state.set as Dictionary)
	return out


static func _landmark_set_from_candidates(selection: Array[Dictionary],
		world_seed: int) -> Dictionary:
	var reservations: Array[Dictionary] = []
	var blocker_union: Dictionary = {}
	var protected_union: Dictionary = {}
	var source_families: Dictionary = {}
	var landing_cells: Array[Vector3i] = []
	var footprint_area := 0.0
	var tie_value := world_seed
	for candidate: Dictionary in selection:
		var reservation := candidate.duplicate(true)
		reservation["feature_id"] = StringName(
			"spatial.feature.landmark.%02d" % reservations.size())
		reservations.append(reservation)
		blocker_union.merge(candidate.blocker_parcels as Dictionary, true)
		protected_union.merge(candidate.protected_cells as Dictionary, true)
		source_families[StringName(candidate.source_family)] = true
		var landing := candidate.landing_cell as Vector3i
		landing_cells.append(landing)
		footprint_area += float(candidate.footprint_area)
		tie_value ^= String(candidate.recipe_id).hash() \
			^ landing.x * (31 + reservations.size() * 17) \
			^ landing.z * (47 + reservations.size() * 19)
	var separation := 0
	for left_index in landing_cells.size():
		for right_index in range(left_index + 1, landing_cells.size()):
			var delta := Vector2i(landing_cells[left_index].x \
				- landing_cells[right_index].x,
				landing_cells[left_index].z - landing_cells[right_index].z)
			separation += delta.length_squared()
	var out := {"reservations": reservations,
		"distinct_source_families": source_families.size() > 1,
		"displaced_parcel_count": blocker_union.size(),
		"protected_cell_count": protected_union.size(),
		"separation_squared": separation,
		"footprint_area": footprint_area,
		"tie": posmod(Helper._mix64(tie_value), 1000003)}
	out.merge(_landmark_set_embeddedness(reservations), true)
	return out


static func _landmark_set_precedes(a: Dictionary, b: Dictionary) -> bool:
	if int(a.minimum_city_contact_side_count) \
			!= int(b.minimum_city_contact_side_count):
		return int(a.minimum_city_contact_side_count) \
			> int(b.minimum_city_contact_side_count)
	if int(a.city_contact_side_count) != int(b.city_contact_side_count):
		return int(a.city_contact_side_count) > int(b.city_contact_side_count)
	if int(a.city_contact_score) != int(b.city_contact_score):
		return int(a.city_contact_score) > int(b.city_contact_score)
	if int(a.maximum_city_gap) != int(b.maximum_city_gap):
		return int(a.maximum_city_gap) < int(b.maximum_city_gap)
	if int(a.displaced_parcel_count) != int(b.displaced_parcel_count):
		return int(a.displaced_parcel_count) < int(b.displaced_parcel_count)
	if int(a.protected_cell_count) != int(b.protected_cell_count):
		return int(a.protected_cell_count) < int(b.protected_cell_count)
	if int(a.separation_squared) != int(b.separation_squared):
		return int(a.separation_squared) > int(b.separation_squared)
	if bool(a.distinct_source_families) != bool(b.distinct_source_families):
		return bool(a.distinct_source_families)
	if not is_equal_approx(float(a.footprint_area), float(b.footprint_area)):
		return float(a.footprint_area) > float(b.footprint_area)
	return int(a.tie) < int(b.tie)


static func _landmark_recipe_socket_signature(recipe: FabricRecipe,
		origin: Vector3i, yaw: int) -> String:
	var parts := PackedStringArray()
	for socket: Dictionary in recipe.sockets:
		if int(socket.kind) != FabricRecipe.SocketKind.ROOM \
				or String(StringName(socket.id)).contains(".corner."):
			continue
		var cell := FabricRecipe.transform_cell(socket.cell as Vector3i,
			origin, yaw)
		var facing := FabricRecipe.transform_direction(socket.facing as Vector3i,
			yaw)
		parts.append("%d:%d:%d/%d:%d:%d" % [cell.x, cell.y, cell.z,
			facing.x, facing.y, facing.z])
	parts.sort()
	return ",".join(parts)


static func _landmark_structural_set_key(
		reservations: Array[Dictionary]) -> String:
	## Colour/material alternatives with identical occupied volume and bridge
	## sockets are one topology state. Keep the best-ranked representative; room
	## and connector solvers must not repay seconds for a palette permutation.
	var parts := PackedStringArray()
	for reservation: Dictionary in reservations:
		parts.append(String(reservation.get("structural_signature", "")))
	parts.sort()
	return "|".join(parts).sha256_text()


static func _rank_landmark_sets_for_skywalks(sets: Array[Dictionary],
		skywalk_corpus: Array[Dictionary], target_skywalks: int = 3) -> void:
	# A set blocks the union of the candidates blocked by each of its landmarks.
	# Compute the expensive measured-cell relation once per individual landmark;
	# the former set x skywalk nested scan repeated the same AABB-derived cell
	# intersections for every compatible pair and dominated large-town runtime.
	# This is an exact factorization of `_skywalk_candidate_avoids_landmarks`, not
	# a shortlist: every set and every skywalk remains in the frontier.
	var blocked_indices_by_landmark: Dictionary = {}
	for landmark_set: Dictionary in sets:
		for landmark: Dictionary in landmark_set.reservations as Array[Dictionary]:
			var landmark_key := _landmark_reservation_search_key(landmark)
			if blocked_indices_by_landmark.has(landmark_key):
				continue
			var protected := landmark.protected_cells as Dictionary
			var blocked_parcels := landmark.blocker_parcels as Dictionary
			var blocked_indices: Dictionary = {}
			for skywalk_index in skywalk_corpus.size():
				if not _skywalk_candidate_avoids_landmarks(
						skywalk_corpus[skywalk_index], protected,
						blocked_parcels):
					blocked_indices[skywalk_index] = true
			blocked_indices_by_landmark[landmark_key] = blocked_indices
	for landmark_set: Dictionary in sets:
		var blocked_indices: Dictionary = {}
		for landmark: Dictionary in landmark_set.reservations as Array[Dictionary]:
			blocked_indices.merge(blocked_indices_by_landmark[
				_landmark_reservation_search_key(landmark)] as Dictionary, true)
		var candidate_count := 0
		var pair_keys: Dictionary = {}
		for skywalk_index in skywalk_corpus.size():
			if blocked_indices.has(skywalk_index):
				continue
			var skywalk := skywalk_corpus[skywalk_index]
			candidate_count += 1
			pair_keys[String(skywalk.pair_key)] = true
		landmark_set["skywalk_candidate_count"] = candidate_count
		landmark_set["skywalk_pair_count"] = pair_keys.size()
	sets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		# The required link count is the contract; surplus candidates are only a
		# late tie-break after keeping the landmark set embedded in inhabited mass.
		var a_viable := int(a.skywalk_pair_count) \
			>= target_skywalks \
			and int(a.skywalk_candidate_count) \
				>= target_skywalks
		var b_viable := int(b.skywalk_pair_count) \
			>= target_skywalks \
			and int(b.skywalk_candidate_count) \
				>= target_skywalks
		if a_viable != b_viable:
			return a_viable
		var a_minimum_contact := int(a.get(
			"minimum_city_contact_side_count", 0))
		var b_minimum_contact := int(b.get(
			"minimum_city_contact_side_count", 0))
		if a_minimum_contact != b_minimum_contact:
			return a_minimum_contact > b_minimum_contact
		var a_contact_sides := int(a.get("city_contact_side_count", 0))
		var b_contact_sides := int(b.get("city_contact_side_count", 0))
		if a_contact_sides != b_contact_sides:
			return a_contact_sides > b_contact_sides
		var a_contact_score := int(a.get("city_contact_score", 0))
		var b_contact_score := int(b.get("city_contact_score", 0))
		if a_contact_score != b_contact_score:
			return a_contact_score > b_contact_score
		var a_maximum_gap := int(a.get("maximum_city_gap",
			LANDMARK_CITY_CONTACT_RADIUS_CELLS + 1))
		var b_maximum_gap := int(b.get("maximum_city_gap",
			LANDMARK_CITY_CONTACT_RADIUS_CELLS + 1))
		if a_maximum_gap != b_maximum_gap:
			return a_maximum_gap < b_maximum_gap
		if int(a.displaced_parcel_count) != int(b.displaced_parcel_count):
			return int(a.displaced_parcel_count) < int(b.displaced_parcel_count)
		if int(a.protected_cell_count) != int(b.protected_cell_count):
			return int(a.protected_cell_count) < int(b.protected_cell_count)
		if int(a.skywalk_pair_count) != int(b.skywalk_pair_count):
			return int(a.skywalk_pair_count) > int(b.skywalk_pair_count)
		if int(a.skywalk_candidate_count) != int(b.skywalk_candidate_count):
			return int(a.skywalk_candidate_count) > int(b.skywalk_candidate_count)
		if int(a.separation_squared) != int(b.separation_squared):
			return int(a.separation_squared) > int(b.separation_squared)
		if bool(a.distinct_source_families) != bool(b.distinct_source_families):
			return bool(a.distinct_source_families)
		return int(a.tie) < int(b.tie))
	var preview: Array[Dictionary] = []
	for index in mini(8, sets.size()):
		var pair := sets[index]
		var reservations := pair.reservations as Array[Dictionary]
		var landing_cells: Array[Vector3i] = []
		for reservation: Dictionary in reservations:
			landing_cells.append(reservation.landing_cell as Vector3i)
		preview.append({"recipe_ids": _landmark_recipe_ids(reservations),
			"landing_cells": landing_cells,
			"skywalk_candidate_count": pair.skywalk_candidate_count,
			"skywalk_pair_count": pair.skywalk_pair_count,
			"minimum_city_contact_side_count": pair.get(
				"minimum_city_contact_side_count", 0),
			"city_contact_side_count": pair.get("city_contact_side_count", 0),
			"city_contact_score": pair.get("city_contact_score", 0),
			"maximum_city_gap": pair.get("maximum_city_gap",
				LANDMARK_CITY_CONTACT_RADIUS_CELLS + 1),
			"displaced_parcel_count": pair.displaced_parcel_count,
			"protected_cell_count": pair.protected_cell_count})
	last_preplan_landmark_diagnostic["joint_pair_preview"] = preview
	last_preplan_landmark_diagnostic[
		"rank_unique_landmark_reservation_count"] = \
		blocked_indices_by_landmark.size()


static func _landmark_set_protected_cells(
		landmarks: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for landmark: Dictionary in landmarks:
		out.merge(landmark.protected_cells as Dictionary, true)
	return out


static func _landmark_set_blocker_parcels(
		landmarks: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for landmark: Dictionary in landmarks:
		out.merge(landmark.blocker_parcels as Dictionary, true)
	return out


static func _skywalk_candidate_avoids_landmarks(candidate: Dictionary,
		protected: Dictionary, blocked_parcels: Dictionary = {}) -> bool:
	for owner_value: Variant in (candidate.reservation as Dictionary).get(
			"owner_parcel_ids", []):
		if blocked_parcels.has(StringName(owner_value)):
			return false
	for field: StringName in [&"clearance", &"body", &"priority_cells"]:
		for cell_value: Variant in (candidate.get(field, {}) as Dictionary).keys():
			if protected.has(cell_value):
				return false
	return true


static func _skywalk_plan_for_landmarks(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, proposals: Array[Dictionary],
		protected_owners: Dictionary,
		candidate_corpus: Array[Dictionary],
		landmarks: Array[Dictionary], program: SettlementFabricProgram,
		public_air: Dictionary, route_walk: Dictionary,
		base_route_covered: Dictionary, target_count: int = 3,
		preserved_parcel_ids: Array[StringName] = []) -> Dictionary:
	var stage_started := Time.get_ticks_msec()
	var landmark_cells: Dictionary = {}
	for cell_value: Variant in protected_owners.keys():
		for owner_value: Variant in (protected_owners[cell_value] \
				as Dictionary).keys():
			if String(owner_value).begins_with("spatial.feature.landmark."):
				landmark_cells[cell_value] = true
				break
	var blocked_parcels := _landmark_set_blocker_parcels(landmarks)
	var landmark_transition_owner_ids := \
		_landmark_transition_owner_ids(landmarks)
	# A landmark is already part of the inhabited mountain when its measured body
	# replaces parcels, its entrance addresses the connected street, and the
	# surviving private-mass audit encloses several sides. Prefer a rare upper
	# socket when one also crosses route space, but never reject the whole town
	# merely because a large prefab's authored sockets do not align with a room at
	# the same band. The ordinary skywalk quota remains exact either way.
	var require_landmark_endpoint := false
	var prefer_landmark_endpoint := landmarks.size() >= 2
	var required_landmark_coverage := int(require_landmark_endpoint)
	var landmark_attached: Array[Dictionary] = []
	if prefer_landmark_endpoint:
		landmark_attached = _landmark_attached_skywalk_candidates(grid,
			volume, proposals, landmarks, program, protected_owners, public_air)
		landmark_attached = _skywalk_candidates_preserving_parcels(
			landmark_attached, preserved_parcel_ids)
	var existing_landmark_endpoint_count := 0
	for candidate: Dictionary in candidate_corpus:
		existing_landmark_endpoint_count += int(candidate.get(
			"landmark_endpoint_count", 0))
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING landmark_attached_initial ms=",
			Time.get_ticks_msec() - stage_started, " attached=",
			landmark_attached.size())
	if require_landmark_endpoint and landmark_attached.is_empty() \
			and existing_landmark_endpoint_count == 0:
		last_preplan_skywalk_diagnostic["landmark_filtered_candidate_count"] = 0
		last_preplan_skywalk_diagnostic["landmark_attached_candidate_count"] = 0
		last_preplan_skywalk_diagnostic["landmark_joint_selected_count"] = 0
		last_preplan_skywalk_diagnostic["composition_ranked_combination_count"] = 0
		last_preplan_skywalk_diagnostic["ranked_triple_count"] = 0
		last_preplan_skywalk_diagnostic["composition_trial_count"] = 0
		var empty_plan := _skywalk_plan_from_selected(
			[] as Array[Dictionary], 0)
		empty_plan["landmark_transition_owner_ids"] = \
			landmark_transition_owner_ids
		return empty_plan
	var candidates: Array[Dictionary] = []
	for candidate: Dictionary in candidate_corpus:
		if not _skywalk_candidate_avoids_landmarks(candidate, landmark_cells,
				blocked_parcels) \
				or not _skywalk_selection_preserves_endpoint_rooms(grid, volume,
					[candidate] as Array[Dictionary], proposals, protected_owners,
					volume.world_seed):
			continue
		candidates.append(candidate)
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING landmark_individual ms=",
			Time.get_ticks_msec() - stage_started, " candidates=",
			candidates.size())
	for candidate: Dictionary in landmark_attached:
		if not _skywalk_selection_preserves_endpoint_rooms(grid, volume,
				[candidate] as Array[Dictionary], proposals, protected_owners,
				volume.world_seed):
			continue
		candidates.append(candidate)
	var proposal_by_id: Dictionary = {}
	for proposal: Dictionary in proposals:
		var proposal_parcel := proposal.parcel as WarrenBuildingParcel
		proposal_by_id[proposal_parcel.stable_id] = proposal
	_annotate_skywalk_route_coverage(candidates, route_walk,
		base_route_covered)
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING landmark_attached ms=",
			Time.get_ticks_msec() - stage_started, " attached=",
			landmark_attached.size())
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		# Prefer a landmark link if it exists without turning an absent authored
		# alignment into a topology gate.
		if int(a.get("landmark_endpoint_count", 0)) \
				!= int(b.get("landmark_endpoint_count", 0)):
			return int(a.get("landmark_endpoint_count", 0)) \
				> int(b.get("landmark_endpoint_count", 0))
		if int(a.blocker_count) != int(b.blocker_count):
			return int(a.blocker_count) < int(b.blocker_count)
		if int(a.lower_cover) != int(b.lower_cover):
			return int(a.lower_cover) > int(b.lower_cover)
		return int(a.tie) < int(b.tie))
	if target_count < 3:
		var selected_small: Array[Dictionary] = []
		var selected_small_tower_risk := 2147483647
		var selected_small_support_risk := 2147483647
		var selected_small_quality := 2147483647
		var selected_small_rank_index := -1
		var small_ranked_combinations: Array[Dictionary] = []
		var ranked_pairs: Array[Dictionary] = []
		if target_count == 1:
			for candidate_index in candidates.size():
				var candidate := candidates[candidate_index]
				if require_landmark_endpoint \
						and int(candidate.get("landmark_endpoint_count", 0)) <= 0:
					continue
				var combination := [candidate] as Array[Dictionary]
				var tower_risk := _skywalk_combination_tower_risk(
					combination, proposals, {})
				var quality := int(candidate.blocker_count) * 100 \
					- int(candidate.lower_cover) * 10
				small_ranked_combinations.append({
					"indices": [candidate_index] as Array[int],
					"tower_risk": tower_risk, "quality": quality})
				if not selected_small.is_empty() \
						or not _skywalk_selection_preserves_endpoint_rooms(grid,
							volume, combination, proposals, protected_owners,
							volume.world_seed):
					continue
				selected_small = combination
				selected_small_rank_index = \
					small_ranked_combinations.size() - 1
				selected_small_tower_risk = tower_risk
				selected_small_quality = quality
		elif target_count == 2:
			for first in candidates.size():
				for second in range(first + 1, candidates.size()):
					if not _skywalk_candidates_compatible(candidates[first],
							candidates[second]):
						continue
					var pair := [candidates[first], candidates[second]] \
						as Array[Dictionary]
					var pair_coverage := _skywalk_landmark_coverage(pair)
					if (require_landmark_endpoint and pair_coverage.size() \
							< required_landmark_coverage):
						continue
					var quality := 0
					var tie := 0
					var landmark_endpoint_count := 0
					for candidate: Dictionary in pair:
						quality += int(candidate.blocker_count) * 100 \
							- int(candidate.lower_cover) * 10
						tie += int(candidate.tie)
						landmark_endpoint_count += int(candidate.get(
							"landmark_endpoint_count", 0))
					ranked_pairs.append({"indices": Vector2i(first, second),
						"support_risk": _skywalk_combination_support_risk(pair,
							proposal_by_id),
						"tower_risk": _skywalk_combination_tower_risk(pair,
							proposals, proposal_by_id),
						"marginal_route_cover_count":
							_skywalk_combination_route_cover_count(pair,
								&"marginal_route_cover_cells"),
						"route_cover_count":
							_skywalk_combination_route_cover_count(pair,
								&"route_cover_cells"),
						"quality": quality,
						"landmark_endpoint_count": landmark_endpoint_count,
						"tie": tie})
			ranked_pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				if int(a.support_risk) != int(b.support_risk):
					return int(a.support_risk) < int(b.support_risk)
				if int(a.tower_risk) != int(b.tower_risk):
					return int(a.tower_risk) < int(b.tower_risk)
				if int(a.quality) != int(b.quality):
					return int(a.quality) < int(b.quality)
				if int(a.landmark_endpoint_count) \
						!= int(b.landmark_endpoint_count):
					return int(a.landmark_endpoint_count) \
						> int(b.landmark_endpoint_count)
				return int(a.tie) < int(b.tie))
			for ranked_pair: Dictionary in ranked_pairs:
				var indices := ranked_pair.indices as Vector2i
				var pair := [candidates[indices.x], candidates[indices.y]] \
					as Array[Dictionary]
				small_ranked_combinations.append({
					"indices": [indices.x, indices.y] as Array[int],
					"tower_risk": int(ranked_pair.tower_risk),
					"quality": int(ranked_pair.quality)})
				if not selected_small.is_empty() \
						or not _skywalk_selection_preserves_endpoint_rooms(grid, volume,
						pair, proposals, protected_owners, volume.world_seed):
					continue
				selected_small = pair
				selected_small_rank_index = \
					small_ranked_combinations.size() - 1
				selected_small_support_risk = int(ranked_pair.support_risk)
				selected_small_tower_risk = int(ranked_pair.tower_risk)
				selected_small_quality = int(ranked_pair.quality)
			# A village that genuinely holds only one exact link keeps that
			# one instead of rejecting the whole town; the profile minimum
			# gate downstream still enforces the declared floor.
			if selected_small.is_empty():
				small_ranked_combinations.clear()
				for candidate_index in candidates.size():
					var candidate := candidates[candidate_index]
					var combination := [candidate] as Array[Dictionary]
					var tower_risk := _skywalk_combination_tower_risk(
						combination, proposals, {})
					var quality := int(candidate.blocker_count) * 100 \
						- int(candidate.lower_cover) * 10
					small_ranked_combinations.append({
						"indices": [candidate_index] as Array[int],
						"tower_risk": tower_risk, "quality": quality})
					if not selected_small.is_empty():
						continue
					if not _skywalk_selection_preserves_endpoint_rooms(grid,
							volume, combination,
							proposals, protected_owners, volume.world_seed):
						continue
					selected_small = combination
					selected_small_rank_index = \
						small_ranked_combinations.size() - 1
					selected_small_tower_risk = tower_risk
					selected_small_quality = quality
		last_preplan_skywalk_diagnostic["landmark_filtered_candidate_count"] = \
			candidates.size()
		last_preplan_skywalk_diagnostic["landmark_attached_candidate_count"] = \
			landmark_attached.size()
		last_preplan_skywalk_diagnostic["landmark_joint_selected_count"] = \
			selected_small.size()
		last_preplan_skywalk_diagnostic["composition_ranked_combination_count"] = \
			int(selected_small.size() == target_count)
		last_preplan_skywalk_diagnostic["ranked_pair_count"] = \
			ranked_pairs.size() if target_count == 2 else 0
		last_preplan_skywalk_diagnostic["selected_tower_risk"] = \
			selected_small_tower_risk
		last_preplan_skywalk_diagnostic["selected_support_risk"] = \
			selected_small_support_risk
		last_preplan_skywalk_diagnostic["selected_quality"] = \
			selected_small_quality
		last_preplan_skywalk_diagnostic[
			"selected_unique_route_cover_count"] = \
			_skywalk_combination_route_cover_count(selected_small,
				&"route_cover_cells")
		last_preplan_skywalk_diagnostic[
			"selected_marginal_route_cover_count"] = \
			_skywalk_combination_route_cover_count(selected_small,
				&"marginal_route_cover_cells")
		var small_plan := _skywalk_plan_from_selected(selected_small,
			candidates.size())
		small_plan["pair_frontier_count"] = int(selected_small.size() == 2)
		small_plan["landmark_coverage_count"] = \
			_skywalk_landmark_coverage(selected_small).size()
		small_plan["unique_route_cover_count"] = \
			_skywalk_combination_route_cover_count(selected_small,
				&"route_cover_cells")
		small_plan["marginal_route_cover_count"] = \
			_skywalk_combination_route_cover_count(selected_small,
				&"marginal_route_cover_cells")
		# Landmark contact is a ranking fact, not an authored socket. The selected
		# bridge endpoints, market backing, and courtyard walls stay mandatory; a
		# merely nearby upper crown must remain free to move or terminate so the
		# exact support audit cannot be forced to retain a floating backdrop.
		small_plan["landmark_transition_owner_ids"] = [] as Array[StringName]
		small_plan["ranked_landmark_transition_owner_ids"] = \
			landmark_transition_owner_ids
		# Compact one-link and standard two-link towns need the same bounded
		# post-roofability fallback as richer triple/quadruple towns. Endpoint
		# composition is necessary but cannot see a one-cell cross-lineage roof
		# sliver left by the chosen connector.
		small_plan["alternate_search"] = {
			"candidates": candidates,
			"ranked_combinations": small_ranked_combinations,
			"ranked_triples": [] as Array[Dictionary],
			"pair_frontier_count": ranked_pairs.size(),
			"primary_rank_index": selected_small_rank_index,
		}
		return small_plan
	var selected: Array[Dictionary] = []
	var selected_tower_risk := 2147483647
	var selected_quality := 2147483647
	var composition_ranked_combination_count := 0
	var composition_trial_count := 0
	var primary_frontier_size := mini(candidates.size(), 64)
	var pair_frontier: Array[Vector2i] = []
	var stop_pairs := false
	for first in primary_frontier_size:
		var accepted_for_first := 0
		for second in candidates.size():
			if second == first or not _skywalk_candidates_compatible(
					candidates[first], candidates[second]):
				continue
			var pair := [candidates[first], candidates[second]] \
				as Array[Dictionary]
			if not _skywalk_selection_preserves_endpoint_rooms(grid, volume,
					pair, proposals, protected_owners, volume.world_seed):
				continue
			pair_frontier.append(Vector2i(first, second))
			accepted_for_first += 1
			if pair_frontier.size() >= 128:
				stop_pairs = true
				break
			if accepted_for_first >= 4:
				break
		if stop_pairs:
			break
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING landmark_pairs ms=",
			Time.get_ticks_msec() - stage_started, " pairs=",
			pair_frontier.size())
	# Rank the finite compatible triples using the same quality function before
	# invoking the exact room-composition proof.  The former loop proved every
	# surviving triple just to discover the minimum tower risk, so a 500-member
	# corpus expanded into tens of thousands of identical-cost recompositions.
	# The first exact survivor in this ordering is the same optimum (with an
	# explicit deterministic tie-break) and lets the search stop immediately.
	var ranked_triples: Array[Dictionary] = []
	var seen_triples: Dictionary = {}
	for pair_indices: Vector2i in pair_frontier:
		var first := pair_indices.x
		var second := pair_indices.y
		for third in candidates.size():
			if third in [first, second] \
					or not _skywalk_candidates_compatible(candidates[first],
						candidates[third]) \
					or not _skywalk_candidates_compatible(candidates[second],
						candidates[third]):
				continue
			var combination := [candidates[first], candidates[second],
				candidates[third]] as Array[Dictionary]
			var landmark_coverage := _skywalk_landmark_coverage(combination)
			if landmark_coverage.size() < required_landmark_coverage:
				continue
			var landmark_endpoint_count := 0
			for candidate: Dictionary in combination:
				landmark_endpoint_count += int(candidate.get(
					"landmark_endpoint_count", 0))
			var sorted_indices: Array[int] = [first, second, third]
			sorted_indices.sort()
			var triple_key := "%d/%d/%d" % sorted_indices
			if seen_triples.has(triple_key):
				continue
			seen_triples[triple_key] = true
			var tower_risk := _skywalk_combination_tower_risk(combination,
				proposals, proposal_by_id)
			var quality := 0
			var tie := 0
			for candidate: Dictionary in combination:
				quality += int(candidate.blocker_count) * 100 \
					- int(candidate.lower_cover) * 10
				tie += int(candidate.tie)
			ranked_triples.append({"indices": sorted_indices,
				"tower_risk": tower_risk,
				"marginal_route_cover_count":
					_skywalk_combination_route_cover_count(combination,
						&"marginal_route_cover_cells"),
				"route_cover_count": _skywalk_combination_route_cover_count(
					combination, &"route_cover_cells"),
				"quality": quality,
				"landmark_coverage_count": landmark_coverage.size(),
				"landmark_endpoint_count": landmark_endpoint_count,
				"tie": tie})
	ranked_triples.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.tower_risk) != int(b.tower_risk):
			return int(a.tower_risk) < int(b.tower_risk)
		if int(a.quality) != int(b.quality):
			return int(a.quality) < int(b.quality)
		if int(a.landmark_endpoint_count) != int(b.landmark_endpoint_count):
			return int(a.landmark_endpoint_count) \
				> int(b.landmark_endpoint_count)
		return int(a.tie) < int(b.tie))
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING landmark_triples ms=",
			Time.get_ticks_msec() - stage_started, " triples=",
			ranked_triples.size())
	var ranked_combinations := ranked_triples
	var ranked_quadruple_count := 0
	if target_count == 4:
		ranked_combinations = _ranked_skywalk_quadruple_frontier(
			ranked_triples, candidates, proposals, proposal_by_id,
			required_landmark_coverage)
		ranked_quadruple_count = ranked_combinations.size()
		if diagnostic_trace_skywalk_timing:
			print("SKYWALK_TIMING landmark_quadruples ms=",
				Time.get_ticks_msec() - stage_started, " quadruples=",
				ranked_quadruple_count)
	elif target_count > 4:
		ranked_combinations = [] as Array[Dictionary]
	var selected_rank_index := -1
	for rank_index in ranked_combinations.size():
		var ranked := ranked_combinations[rank_index]
		composition_trial_count += 1
		var indices := ranked.indices as Array[int]
		var combination: Array[Dictionary] = []
		for candidate_index: int in indices:
			combination.append(candidates[candidate_index])
		if not _skywalk_selection_preserves_endpoint_rooms(grid, volume,
				combination, proposals, protected_owners, volume.world_seed):
			continue
		composition_ranked_combination_count += 1
		selected = combination
		selected_tower_risk = int(ranked.tower_risk)
		selected_quality = int(ranked.quality)
		selected_rank_index = rank_index
		break
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING landmark_exact ms=",
			Time.get_ticks_msec() - stage_started, " trials=",
			composition_trial_count, " selected=", selected.size())
	last_preplan_skywalk_diagnostic["landmark_filtered_candidate_count"] = \
		candidates.size()
	last_preplan_skywalk_diagnostic["landmark_attached_candidate_count"] = \
		landmark_attached.size()
	last_preplan_skywalk_diagnostic["landmark_joint_selected_count"] = \
		selected.size()
	last_preplan_skywalk_diagnostic["composition_ranked_combination_count"] = \
		composition_ranked_combination_count
	last_preplan_skywalk_diagnostic["ranked_triple_count"] = \
		ranked_triples.size()
	last_preplan_skywalk_diagnostic["ranked_quadruple_count"] = \
		ranked_quadruple_count
	last_preplan_skywalk_diagnostic["composition_trial_count"] = \
		composition_trial_count
	last_preplan_skywalk_diagnostic["selected_tower_risk"] = \
		selected_tower_risk
	last_preplan_skywalk_diagnostic["selected_unique_route_cover_count"] = \
		_skywalk_combination_route_cover_count(selected,
			&"route_cover_cells")
	last_preplan_skywalk_diagnostic["selected_marginal_route_cover_count"] = \
		_skywalk_combination_route_cover_count(selected,
			&"marginal_route_cover_cells")
	var selected_landmark_coverage := _skywalk_landmark_coverage(selected)
	last_preplan_skywalk_diagnostic["required_landmark_coverage_count"] = \
		required_landmark_coverage
	last_preplan_skywalk_diagnostic["selected_landmark_coverage_count"] = \
		selected_landmark_coverage.size()
	var plan := _landmark_skywalk_plan_for_combination(selected,
		candidates.size(), pair_frontier.size(), selected_tower_risk,
		landmark_transition_owner_ids)
	# Deferred alternate search state. The enclosing feature transaction requests
	# this bounded frontier only for the selected landmark set. It may need the
	# alternates even when the primary endpoint-valid plan fails the later global
	# roofability proof.
	plan["alternate_search"] = {
		"candidates": candidates,
		"ranked_combinations": ranked_combinations,
		"ranked_triples": ranked_triples if target_count == 4 \
			else [] as Array[Dictionary],
		"pair_frontier_count": pair_frontier.size(),
		# Every combination ranked before the primary already failed the exact
		# endpoint-composition proof; the deferred alternate scan must resume
		# after this rank instead of re-proving that prefix.
		"primary_rank_index": selected_rank_index,
	}
	return plan


static func _deferred_alternate_skywalk_plans(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, proposals: Array[Dictionary],
		protected_owners: Dictionary, plan: Dictionary) -> Array[Dictionary]:
	## Bounded, diverse alternates for exact composition/occluder ranking. Runs
	## only for the selected landmark set, so the extra endpoint-composition
	## proofs are paid once per feature-set attempt, not while building every
	## landmark permutation. A reduced (one-fewer-link)
	## triple is included so the exact ranking can prove or refute the fourth
	## link's distinct inhabited route coverage.
	var out: Array[Dictionary] = []
	var search := plan.get("alternate_search", {}) as Dictionary
	if search.is_empty():
		return out
	var candidates: Array[Dictionary] = []
	candidates.assign(search.get("candidates", []) as Array)
	var ranked_combinations: Array[Dictionary] = []
	ranked_combinations.assign(search.get("ranked_combinations", []) as Array)
	var ranked_triples: Array[Dictionary] = []
	ranked_triples.assign(search.get("ranked_triples", []) as Array)
	var pair_frontier_count := int(search.get("pair_frontier_count", 0))
	var landmark_transition_owner_ids: Array[StringName] = []
	landmark_transition_owner_ids.assign(plan.get(
		"landmark_transition_owner_ids", []) as Array)
	var primary: Array[Dictionary] = []
	primary.assign(plan.get("selected_candidates", []) as Array)
	if primary.is_empty():
		return out
	var scanned := 0
	var scan_start := maxi(0, int(search.get("primary_rank_index", -1)) + 1)
	for rank_index in range(scan_start, ranked_combinations.size()):
		var ranked := ranked_combinations[rank_index]
		if out.size() >= MAX_OCCLUDER_RANK_TRIALS - 1 \
				or scanned >= MAX_OCCLUDER_RANK_SCAN:
			break
		scanned += 1
		var indices := ranked.indices as Array[int]
		var combination: Array[Dictionary] = []
		for candidate_index: int in indices:
			combination.append(candidates[candidate_index])
		if not _skywalk_selection_preserves_endpoint_rooms(grid, volume,
				combination, proposals, protected_owners, volume.world_seed):
			continue
		# A construction-near alternate can still be structurally distinct at the
		# roof interface. Do not discard it merely because it shares an endpoint
		# pair with the primary; the exact composition audit below is the authority
		# on whether that placement yields a coherent building/roof campaign.
		out.append(_landmark_skywalk_plan_for_combination(combination,
			candidates.size(), pair_frontier_count,
			int(ranked.tower_risk), landmark_transition_owner_ids))
	# The fourth link must prove it raises distinct inhabited route coverage.
	var reduced_scanned := 0
	for ranked: Dictionary in ranked_triples:
		if reduced_scanned >= MAX_OCCLUDER_RANK_SCAN:
			break
		reduced_scanned += 1
		var indices := ranked.indices as Array[int]
		var combination: Array[Dictionary] = []
		for candidate_index: int in indices:
			combination.append(candidates[candidate_index])
		if not _skywalk_selection_preserves_endpoint_rooms(grid, volume,
				combination, proposals, protected_owners, volume.world_seed):
			continue
		var reduced_plan := _landmark_skywalk_plan_for_combination(combination,
			candidates.size(), pair_frontier_count,
			int(ranked.tower_risk), landmark_transition_owner_ids)
		reduced_plan["reduced_link_count"] = true
		out.append(reduced_plan)
		break
	last_preplan_skywalk_diagnostic["occluder_rank_alternate_count"] = out.size()
	return out


static func _landmark_skywalk_plan_for_combination(
		selected: Array[Dictionary], candidate_count: int,
		pair_frontier_count: int, tower_risk: int,
		landmark_transition_owner_ids: Array[StringName]) -> Dictionary:
	var plan := _skywalk_plan_from_selected(selected, candidate_count)
	plan["pair_frontier_count"] = pair_frontier_count
	plan["tower_risk"] = tower_risk
	plan["unique_route_cover_count"] = _skywalk_combination_route_cover_count(
		selected, &"route_cover_cells")
	plan["marginal_route_cover_count"] = \
		_skywalk_combination_route_cover_count(selected,
			&"marginal_route_cover_cells")
	plan["landmark_coverage_count"] = _skywalk_landmark_coverage(selected).size()
	plan["landmark_transition_owner_ids"] = landmark_transition_owner_ids
	return plan


static func _skywalk_combination_is_diverse(combination: Array[Dictionary],
		retained_combinations: Array) -> bool:
	## A useful alternate offers the exact occluder ranker a genuinely different
	## bridge set. Require at least two links absent from every retained
	## combination so the bounded exact trials do not re-prove near-identical
	## sets that would measure the same coverage.
	for retained_value: Variant in retained_combinations:
		var prior := retained_value as Array
		var prior_keys: Dictionary = {}
		for candidate_value: Variant in prior:
			prior_keys[(candidate_value as Dictionary).pair_key] = true
		var shared := 0
		for candidate: Dictionary in combination:
			if prior_keys.has(candidate.pair_key):
				shared += 1
		if shared > maxi(0, combination.size() - 2):
			return false
	return true


static func _ranked_skywalk_quadruple_frontier(
		ranked_triples: Array[Dictionary], candidates: Array[Dictionary],
		proposals: Array[Dictionary], proposal_by_id: Dictionary,
		required_landmark_coverage: int) -> Array[Dictionary]:
	## Four occupied links are the large-town visual contract. Extend a bounded
	## frontier of the already-ranked compatible triples, then run the expensive
	## exact room proof only in the resulting deterministic quality order.
	const MAX_TRIPLE_EXTENSION_FRONTIER := 384
	const MAX_EXTENSIONS_PER_TRIPLE := 24
	const MAX_QUADRUPLE_FRONTIER := 6144
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for triple_index in mini(MAX_TRIPLE_EXTENSION_FRONTIER,
			ranked_triples.size()):
		var triple := ranked_triples[triple_index]
		var triple_indices := triple.indices as Array[int]
		var accepted_for_triple := 0
		for fourth in candidates.size():
			if fourth in triple_indices:
				continue
			var compatible := true
			for prior_index: int in triple_indices:
				if not _skywalk_candidates_compatible(candidates[prior_index],
						candidates[fourth]):
					compatible = false
					break
			if not compatible:
				continue
			var indices := triple_indices.duplicate()
			indices.append(fourth)
			indices.sort()
			var key := "%d/%d/%d/%d" % indices
			if seen.has(key):
				continue
			seen[key] = true
			var combination: Array[Dictionary] = []
			for candidate_index: int in indices:
				combination.append(candidates[candidate_index])
			var landmark_coverage := _skywalk_landmark_coverage(combination)
			if landmark_coverage.size() < required_landmark_coverage:
				continue
			var landmark_endpoint_count := 0
			var quality := 0
			var tie := 0
			for candidate: Dictionary in combination:
				landmark_endpoint_count += int(candidate.get(
					"landmark_endpoint_count", 0))
				quality += int(candidate.blocker_count) * 100 \
					- int(candidate.lower_cover) * 10
				tie += int(candidate.tie)
			out.append({"indices": indices,
				"tower_risk": _skywalk_combination_tower_risk(combination,
					proposals, proposal_by_id),
				"marginal_route_cover_count":
					_skywalk_combination_route_cover_count(combination,
						&"marginal_route_cover_cells"),
				"route_cover_count": _skywalk_combination_route_cover_count(
					combination, &"route_cover_cells"),
				"quality": quality,
				"landmark_coverage_count": landmark_coverage.size(),
				"landmark_endpoint_count": landmark_endpoint_count,
				"tie": tie})
			accepted_for_triple += 1
			if accepted_for_triple >= MAX_EXTENSIONS_PER_TRIPLE \
					or out.size() >= MAX_QUADRUPLE_FRONTIER:
				break
		if out.size() >= MAX_QUADRUPLE_FRONTIER:
			break
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.tower_risk) != int(b.tower_risk):
			return int(a.tower_risk) < int(b.tower_risk)
		if int(a.quality) != int(b.quality):
			return int(a.quality) < int(b.quality)
		if int(a.landmark_endpoint_count) != int(b.landmark_endpoint_count):
			return int(a.landmark_endpoint_count) \
				> int(b.landmark_endpoint_count)
		return int(a.tie) < int(b.tie))
	return out


static func _skywalk_candidates_preserving_parcels(
		candidates: Array[Dictionary],
		preserved_parcel_ids: Array[StringName]) -> Array[Dictionary]:
	if preserved_parcel_ids.is_empty():
		return candidates
	var preserved: Dictionary = {}
	for parcel_id: StringName in preserved_parcel_ids:
		preserved[parcel_id] = true
	var out: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		var consumes_preserved_room := false
		for owner_value: Variant in candidate.get("owner_parcel_ids", []) as Array:
			if preserved.has(StringName(owner_value)):
				consumes_preserved_room = true
				break
		if not consumes_preserved_room:
			out.append(candidate)
	return out


static func _skywalk_landmark_coverage(
		candidates: Array[Dictionary]) -> Dictionary:
	## Count distinct landmark endpoints, not links. Two bridge-houses attached
	## to the same prefab cannot make a second external landmark feel integrated.
	var out: Dictionary = {}
	for candidate: Dictionary in candidates:
		var reservation := candidate.get("reservation", candidate) as Dictionary
		for owner_value: Variant in reservation.get("owner_parcel_ids", []):
			var owner_id := StringName(owner_value)
			if String(owner_id).begins_with("spatial.feature.landmark."):
				out[owner_id] = true
	return out


static func _landmark_transition_owner_ids(
		landmarks: Array[Dictionary]) -> Array[StringName]:
	## These are ordinary terrain-rooted houses whose surviving envelopes make a
	## landmark read as an embedded edge district.  Once selected, they become a
	## structural part of the landmark transaction: a later room-pair repair may
	## drop some other optional parcel, but never the transition it just ranked.
	var owner_set: Dictionary = {}
	for landmark: Dictionary in landmarks:
		for owner_value: Variant in landmark.get("transition_owner_ids", []):
			owner_set[StringName(owner_value)] = true
	var out: Array[StringName] = []
	out.assign(owner_set.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out


static func _skywalk_combination_tower_risk(
		combination: Array[Dictionary], proposals: Array[Dictionary],
		cached_proposal_by_id: Dictionary = {}) -> int:
	## Exact endpoint survival alone can still force a stationary upper block on
	## a tall narrow parcel, leaving the later 3D composer no legal alternative
	## to a tower. Rank complete bridge triples by that downstream obligation:
	## shifted tall endpoints are cheaper than stationary ones, and fewer/highly
	## constrained tower parcels are preferred. This is topology selection, not a
	## post-construction decoration score.
	var proposal_by_id := cached_proposal_by_id
	if proposal_by_id.is_empty():
		for proposal: Dictionary in proposals:
			var parcel := proposal.parcel as WarrenBuildingParcel
			proposal_by_id[parcel.stable_id] = proposal
	var states: Dictionary = {}
	for candidate: Dictionary in combination:
		for parcel_value: Variant in (candidate.forced_offsets \
				as Dictionary).keys():
			var parcel_id := StringName(parcel_value)
			if not proposal_by_id.has(parcel_id):
				continue
			var proposal := proposal_by_id[parcel_id] as Dictionary
			# Predict the same failure the final room audit enforces. A three-
			# storey identical shaft is already visually invalid even though the
			# later annex quota calls only four-plus-storey lineages "tall".
			if StringName(proposal.kind) != &"tower" \
					or int(proposal.storeys) <= WarrenRoomCompositionPlanner \
						.MAX_IDENTICAL_TOWER_FLOORPLATE_RUN_STOREYS:
				continue
			if not states.has(parcel_id):
				states[parcel_id] = {"shifted": false, "highest_block": 0,
					"storeys": int(proposal.storeys)}
			var state := states[parcel_id] as Dictionary
			for block_value: Variant in ((candidate.forced_offsets \
					as Dictionary)[parcel_id] as Dictionary).keys():
				var delta := ((candidate.forced_offsets as Dictionary)[
					parcel_id] as Dictionary)[block_value] as Vector2i
				state["shifted"] = bool(state.shifted) or delta != Vector2i.ZERO
				state["highest_block"] = maxi(int(state.highest_block),
					int(block_value))
	var risk := 0
	for state_value: Variant in states.values():
		var state := state_value as Dictionary
		risk += 100000 if not bool(state.shifted) else 10000
		risk += int(state.highest_block) * 1000 + int(state.storeys)
	return risk


static func _skywalk_combination_support_risk(combination: Array[Dictionary],
		proposal_by_id: Dictionary) -> int:
	## Prefer connector endpoints whose forced upper block changes remain within
	## an already terrain-bearing source footprint. The exact room solver still
	## proves final support; this cheap rank only keeps obviously suspended source
	## blocks from being the first pair tested in the large-town hero beam.
	var risk := 0
	for candidate: Dictionary in combination:
		for parcel_value: Variant in (candidate.forced_offsets \
				as Dictionary).keys():
			var parcel_id := StringName(parcel_value)
			var proposal := proposal_by_id.get(parcel_id, {}) as Dictionary
			if proposal.is_empty():
				continue
			var bearing_columns: Dictionary = {}
			var parcel := proposal.parcel as WarrenBuildingParcel
			for column: Vector2i in parcel.bearing_columns:
				for x_offset in 2:
					for z_offset in 2:
						bearing_columns[Vector2i(column.x * 2 + x_offset,
							column.y * 2 + z_offset)] = true
			var forced := (candidate.forced_offsets as Dictionary)[parcel_id] \
				as Dictionary
			for block_value: Variant in forced.keys():
				var block := int(block_value)
				if block <= 0:
					continue
				var delta := forced[block_value] as Vector2i
				var cells := _forced_block_cells(proposal, block, delta)
				var columns: Dictionary = {}
				for cell_value: Variant in cells.keys():
					var cell := cell_value as Vector3i
					columns[Vector2i(cell.x, cell.z)] = true
				var borne := 0
				for column_value: Variant in columns.keys():
					borne += int(bearing_columns.has(column_value))
				risk += maxi(0, columns.size() - borne) * 100 \
					+ int(borne == 0) * 10000
	return risk


static func _landmark_attached_skywalk_candidates(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, proposals: Array[Dictionary],
		landmarks: Array[Dictionary], program: SettlementFabricProgram,
		protected_owners: Dictionary, public_air: Dictionary) \
		-> Array[Dictionary]:
	## Large authored buildings expose the same measured ROOM/BEARING sockets as
	## modular rooms. Let one of the required links terminate in that real socket;
	## otherwise two landmarks can erase the third bridge endpoint even while a
	## perfectly good elevated facade connection exists on the prefab itself.
	var parcels: Array[WarrenBuildingParcel] = []
	var proposal_by_id: Dictionary = {}
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		parcels.append(parcel)
		proposal_by_id[parcel.stable_id] = proposal
	var cache := WarrenAssetCompiler.massif_partition_asset_cache(parcels,
		volume.world_seed, program)
	if not bool(cache.get(&"enabled", false)):
		return [] as Array[Dictionary]
	var all_landmark_cells := _landmark_set_protected_cells(landmarks)
	var blocked_parcels := _landmark_set_blocker_parcels(landmarks)
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	var socket_count := 0
	var body_socket_count := 0
	var endpoint_pair_count := 0
	var raw_link_count := 0
	var raw_straight_count := 0
	var raw_corner_count := 0
	var upper_block_count := 0
	var body_fit_count := 0
	var route_cover_count := 0
	for landmark: Dictionary in landmarks:
		var landmark_id := StringName(landmark.feature_id)
		var landmark_recipe := program.recipe(StringName(landmark.recipe_id))
		if landmark_recipe == null:
			continue
		for socket: Dictionary in landmark_recipe.sockets:
			if int(socket.kind) != FabricRecipe.SocketKind.ROOM \
					or String(StringName(socket.id)).contains(".corner."):
				continue
			socket_count += 1
			var landmark_endpoint := {
				"slot_signature": String(landmark_id),
				"owner_kind": &"landmark",
				"cell": FabricRecipe.transform_cell(socket.cell as Vector3i,
					landmark.origin as Vector3i, int(landmark.yaw_quarters)),
				"facing": FabricRecipe.transform_direction(
					socket.facing as Vector3i, int(landmark.yaw_quarters)),
			}
			if not (landmark.body as Dictionary).has(landmark_endpoint.cell):
				continue
			body_socket_count += 1
			for parcel: WarrenBuildingParcel in parcels:
				if blocked_parcels.has(parcel.stable_id):
					continue
				var proposal := proposal_by_id[parcel.stable_id] as Dictionary
				for parcel_endpoint: Dictionary in WarrenAssetCompiler \
						._parcel_room_endpoints(parcel, program, cache):
					endpoint_pair_count += 1
					var raw_links: Array[Dictionary] = []
					var straight := _raw_straight_skywalk_between_endpoints(
						landmark_endpoint, parcel_endpoint, landmark_id,
						parcel.stable_id, program, public_air)
					if not straight.is_empty():
						raw_links.append(straight)
						raw_straight_count += 1
					var corners := _raw_corner_skywalks_between_endpoints(
						landmark_endpoint, parcel_endpoint, landmark_id,
						parcel.stable_id, program, public_air)
					raw_corner_count += corners.size()
					raw_links.append_array(corners)
					raw_link_count += raw_links.size()
					for raw: Dictionary in raw_links:
						var body := raw.reserved_cells as Dictionary
						var clearance := raw.visual_clearance_cells as Dictionary
						var block := _proposal_block_for_cell(proposal,
							parcel_endpoint.cell as Vector3i)
						var priority := _forced_block_cells(proposal, block,
							Vector2i.ZERO)
						if block <= 0:
							continue
						upper_block_count += 1
						if priority.is_empty() \
								or not _forced_block_fits(grid, proposal, block,
									Vector2i.ZERO) \
								or _sets_overlap(body, all_landmark_cells) \
								or _sets_overlap(priority, all_landmark_cells) \
								or not _skywalk_body_fits_grid(grid, body) \
								or not _skywalk_clearance_fits_grid(grid, clearance) \
								or not _landmark_link_clearance_fits_protected(
									clearance, protected_owners, landmark_id):
							continue
						body_fit_count += 1
						var lower_cover := _lower_public_cover(body, public_air)
						if lower_cover < 2:
							continue
						route_cover_count += 1
						raw["owner_parcel_ids"] = [landmark_id, parcel.stable_id]
						var endpoint_key := _skywalk_endpoint_pair_key(raw)
						var construction_key := _skywalk_construction_key(raw)
						var unique_key := "%s/%s" % [endpoint_key, construction_key]
						if seen.has(unique_key):
							continue
						seen[unique_key] = true
						var priority_cells: Dictionary = {}
						for cell_value: Variant in priority.keys():
							priority_cells[cell_value] = parcel.stable_id
						out.append({"reservation": raw, "body": body,
							"clearance": clearance,
							"forced_offsets": {parcel.stable_id: {
								block: Vector2i.ZERO}},
							"priority_cells": priority_cells,
							"pair_key": "%s|%s" % [landmark_id,
								parcel.stable_id],
							"endpoint_pair_key": endpoint_key,
							"blocker_count": _skywalk_blocker_count(clearance,
								protected_owners, {landmark_id: true,
									parcel.stable_id: true}),
							"lower_cover": lower_cover,
							"landmark_endpoint_count": 1,
							"tie": posmod(Helper._mix64(volume.world_seed \
								^ String(landmark_id).hash() \
								^ String(parcel.stable_id).hash() \
								^ (landmark_endpoint.cell as Vector3i).y * 131),
								1000003)})
	last_preplan_skywalk_diagnostic["landmark_link_socket_count"] = socket_count
	last_preplan_skywalk_diagnostic["landmark_link_body_socket_count"] = \
		body_socket_count
	last_preplan_skywalk_diagnostic["landmark_link_endpoint_pair_count"] = \
		endpoint_pair_count
	last_preplan_skywalk_diagnostic["landmark_link_raw_count"] = raw_link_count
	last_preplan_skywalk_diagnostic["landmark_link_raw_straight_count"] = \
		raw_straight_count
	last_preplan_skywalk_diagnostic["landmark_link_raw_corner_count"] = \
		raw_corner_count
	last_preplan_skywalk_diagnostic["landmark_link_upper_block_count"] = \
		upper_block_count
	last_preplan_skywalk_diagnostic["landmark_link_body_fit_count"] = \
		body_fit_count
	last_preplan_skywalk_diagnostic["landmark_link_route_cover_count"] = \
		route_cover_count
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING landmark_link_gates ", {
			"sockets": socket_count, "body_sockets": body_socket_count,
			"endpoint_pairs": endpoint_pair_count, "raw": raw_link_count,
			"straight": raw_straight_count, "corner": raw_corner_count,
			"upper": upper_block_count, "body_fit": body_fit_count,
			"cover": route_cover_count, "accepted": out.size()})
	return out


static func _landmark_link_clearance_fits_protected(clearance: Dictionary,
		protected_owners: Dictionary, allowed_landmark_id: StringName) -> bool:
	for cell_value: Variant in clearance.keys():
		for owner_value: Variant in (protected_owners.get(cell_value, {}) \
				as Dictionary).keys():
			var owner_id := StringName(owner_value)
			if _protected_owner_is_feature(owner_id) \
					and owner_id != allowed_landmark_id:
				return false
	return true


static func _raw_straight_skywalk_between_endpoints(left_endpoint: Dictionary,
		right_endpoint: Dictionary, left_owner_id: StringName,
		right_owner_id: StringName, program: SettlementFabricProgram,
		public_air: Dictionary) -> Dictionary:
	if (left_endpoint.cell as Vector3i).y \
			!= (right_endpoint.cell as Vector3i).y \
			or (left_endpoint.facing as Vector3i) \
				!= -(right_endpoint.facing as Vector3i):
		return {}
	var forward := left_endpoint.facing as Vector3i
	var delta := (right_endpoint.cell as Vector3i) \
		- (left_endpoint.cell as Vector3i)
	var distance: int = delta.x * forward.x + delta.z * forward.z
	if distance < 3 or distance > 7 or posmod(distance, 2) != 1 \
			or delta != forward * distance:
		return {}
	var segments := (distance - 1) / 2
	var recipe_id := &"skywalk.3.blue" if segments == 1 \
		else &"skywalk.6.orange" if segments == 2 else &"skywalk.9.blue"
	var recipe := program.recipe(recipe_id)
	var yaw := -1
	for candidate_yaw in 4:
		if FabricRecipe.transform_direction(Vector3i.LEFT, candidate_yaw) \
				== -forward:
			yaw = candidate_yaw
			break
	if recipe == null or yaw < 0:
		return {}
	var west := recipe.socket(&"room.west")
	if west.is_empty():
		return {}
	var origin := (left_endpoint.cell as Vector3i) + forward \
		- FabricRecipe.transform_cell(west.cell as Vector3i, Vector3i.ZERO, yaw)
	var reserved: Dictionary = {}
	for source_cells: Array[Vector3i] in [recipe.solid_cells,
			recipe.headroom_cells]:
		for local: Vector3i in source_cells:
			var cell := FabricRecipe.transform_cell(local, origin, yaw)
			if public_air.has(cell):
				return {}
			reserved[cell] = true
	var components: Array[Dictionary] = [{"recipe_id": recipe_id,
		"origin": origin, "yaw_quarters": yaw}]
	var left_record := left_endpoint.duplicate(true)
	left_record["owner_id"] = left_owner_id
	var right_record := right_endpoint.duplicate(true)
	right_record["owner_id"] = right_owner_id
	return {"kind": &"straight", "recipe_id": recipe_id,
		"origin": origin, "yaw_quarters": yaw, "components": components,
		"reserved_cells": reserved,
		"visual_bounds": [FabricRecipe.lattice_transform(origin, yaw) \
			* recipe.local_clearance_bounds] as Array[AABB],
		"visual_clearance_cells": _skywalk_visual_clearance_cells(components,
			program), "owner_endpoints": [left_record, right_record]}


static func _skywalk_plan_from_selected(selected: Array[Dictionary],
		candidate_count: int) -> Dictionary:
	var reservations: Array[Dictionary] = []
	var forced_offsets: Dictionary = {}
	var priority_cells: Dictionary = {}
	for candidate: Dictionary in selected:
		reservations.append((candidate.reservation as Dictionary).duplicate(true))
		for parcel_value: Variant in (candidate.forced_offsets \
				as Dictionary).keys():
			var parcel_id := StringName(parcel_value)
			if not forced_offsets.has(parcel_id):
				forced_offsets[parcel_id] = {}
			for block_value: Variant in ((candidate.forced_offsets \
					as Dictionary)[parcel_id] as Dictionary).keys():
				(forced_offsets[parcel_id] as Dictionary)[int(block_value)] = \
					((candidate.forced_offsets as Dictionary)[parcel_id] \
						as Dictionary)[block_value]
		for cell_value: Variant in (candidate.priority_cells as Dictionary).keys():
			priority_cells[cell_value] = (candidate.priority_cells \
				as Dictionary)[cell_value]
	return {"reservations": reservations, "forced_offsets": forced_offsets,
		"priority_cells": priority_cells, "candidate_count": candidate_count,
		"selected_candidates": selected.duplicate(true)}


static func _skywalk_plan_owner_preview(plan: Dictionary) -> Array:
	var out: Array = []
	for reservation_value: Variant in plan.get("reservations", []) as Array:
		var reservation := reservation_value as Dictionary
		out.append(reservation.get("owner_parcel_ids", []).duplicate())
	return out


static func _feature_forced_offset_key(candidate: Dictionary) -> String:
	var parts := PackedStringArray()
	var forced := candidate.get("forced_offsets", {}) as Dictionary
	var parcel_ids: Array[StringName] = []
	parcel_ids.assign(forced.keys())
	parcel_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for parcel_id: StringName in parcel_ids:
		var blocks := forced[parcel_id] as Dictionary
		var block_ids: Array[int] = []
		block_ids.assign(blocks.keys())
		block_ids.sort()
		for block: int in block_ids:
			var delta := blocks[block] as Vector2i
			parts.append("%s/b%d/%d:%d" % [parcel_id, block,
				delta.x, delta.y])
	return "|".join(parts)


static func _court_candidate_exclusion_snapshot(
		court_candidate: Dictionary) -> Dictionary:
	## The exact preflight records complete-parcel dispositions on the court
	## candidate. Ranked sealed trials each mutate that state, so the frontier
	## restores this snapshot before every trial and finally re-applies the
	## winning trial's dispositions.
	var snapshot: Dictionary = {}
	for key: String in ["excluded_parcel_ids",
			"feature_clearance_displaced_parcel_ids",
			"room_pair_displaced_parcel_ids"]:
		if court_candidate.has(key):
			snapshot[key] = (court_candidate[key] as Array).duplicate()
	return snapshot


static func _restore_court_candidate_exclusions(court_candidate: Dictionary,
		snapshot: Dictionary) -> void:
	for key: String in ["excluded_parcel_ids",
			"feature_clearance_displaced_parcel_ids",
			"room_pair_displaced_parcel_ids"]:
		if snapshot.has(key):
			court_candidate[key] = (snapshot[key] as Array).duplicate()
		else:
			court_candidate.erase(key)


static func _exact_room_preflight_key(court_candidate: Dictionary,
		landmarks: Array[Dictionary], skywalk_plan: Dictionary) -> String:
	## Key only the facts consumed by the exact room preflight. This deliberately
	## ignores prefab recipe names when two authored colour/style alternatives
	## resolve to identical protected cells, but distinguishes every changed
	## body, clearance cell, forced offset, endpoint owner, and transition owner.
	var parts := PackedStringArray([
		"court.force=" + _feature_forced_offset_key(court_candidate),
		"court.body=" + _cell_set_signature(court_candidate.get("body", {})),
		"court.clear=" + _cell_set_signature(court_candidate.get(
			"clearance", {})),
		"court.priority=" + _cell_owner_map_signature(court_candidate.get(
			"priority_cells", {})),
		"sky.force=" + _feature_forced_offset_key({
			"forced_offsets": skywalk_plan.get("forced_offsets", {})}),
		"sky.priority=" + _cell_owner_map_signature(skywalk_plan.get(
			"priority_cells", {})),
	])
	var landmark_parts := PackedStringArray()
	for landmark: Dictionary in landmarks:
		landmark_parts.append("%s:%s" % [StringName(landmark.get(
			"feature_id", &"")), _cell_set_signature(landmark.get(
			"protected_cells", {}))])
	landmark_parts.sort()
	parts.append("landmarks=" + "|".join(landmark_parts))
	var skywalk_parts := PackedStringArray()
	for reservation_value: Variant in skywalk_plan.get("reservations", []) as Array:
		var reservation := reservation_value as Dictionary
		var owners := PackedStringArray()
		for owner_value: Variant in reservation.get("owner_parcel_ids", []):
			owners.append(String(StringName(owner_value)))
		owners.sort()
		skywalk_parts.append("%s/%s/body=%s/clear=%s" % [
			_skywalk_construction_key(reservation), ",".join(owners),
			_cell_set_signature(reservation.get("reserved_cells", {})),
			_cell_set_signature(reservation.get("visual_clearance_cells", {})),
		])
	skywalk_parts.sort()
	parts.append("skywalks=" + "|".join(skywalk_parts))
	var transition_owners := PackedStringArray()
	for owner_value: Variant in skywalk_plan.get(
			"landmark_transition_owner_ids", []):
		transition_owners.append(String(StringName(owner_value)))
	transition_owners.sort()
	parts.append("transitions=" + ",".join(transition_owners))
	return "\n".join(parts).sha256_text()


static func _cell_set_signature(cells_value: Variant) -> String:
	var cells := cells_value as Dictionary
	var ordered: Array[Vector3i] = []
	ordered.assign(cells.keys())
	ordered.sort_custom(_cell_less)
	var parts := PackedStringArray()
	for cell: Vector3i in ordered:
		parts.append("%d:%d:%d" % [cell.x, cell.y, cell.z])
	return ",".join(parts)


static func _cell_owner_map_signature(cells_value: Variant) -> String:
	var cells := cells_value as Dictionary
	var ordered: Array[Vector3i] = []
	ordered.assign(cells.keys())
	ordered.sort_custom(_cell_less)
	var parts := PackedStringArray()
	for cell: Vector3i in ordered:
		parts.append("%d:%d:%d=%s" % [cell.x, cell.y, cell.z,
			String(StringName(cells[cell]))])
	return ",".join(parts)


static func _exact_room_preflight_failure_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for key: String in [
			"last_exact_court_tall_tower_failure",
			"last_exact_room_composition_failure",
			"last_exact_room_pair_failure",
			"last_exact_court_composition_failure",
			"last_exact_court_required_conflict",
	]:
		if last_preplan_market_diagnostic.has(key):
			snapshot[key] = last_preplan_market_diagnostic[key].duplicate(true) \
				if last_preplan_market_diagnostic[key] is Array \
				or last_preplan_market_diagnostic[key] is Dictionary \
				else last_preplan_market_diagnostic[key]
	return snapshot


static func _restore_exact_room_preflight_failure(snapshot: Dictionary) -> void:
	for key: String in [
			"last_exact_court_tall_tower_failure",
			"last_exact_room_composition_failure",
			"last_exact_room_pair_failure",
			"last_exact_court_composition_failure",
			"last_exact_court_required_conflict",
	]:
		last_preplan_market_diagnostic.erase(key)
	for key_value: Variant in snapshot.keys():
		var key := String(key_value)
		last_preplan_market_diagnostic[key] = snapshot[key_value].duplicate(true) \
			if snapshot[key_value] is Array or snapshot[key_value] is Dictionary \
			else snapshot[key_value]


static func _court_owned_tall_tower_failures(failed_ids: Array,
		court_candidate: Dictionary) -> Array[StringName]:
	var court_forced := court_candidate.get("forced_offsets", {}) as Dictionary
	var out: Array[StringName] = []
	for failed_value: Variant in failed_ids:
		var failed_id := StringName(failed_value)
		if court_forced.has(failed_id) and not out.has(failed_id):
			out.append(failed_id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out


static func _landmark_candidates_compatible(left: Dictionary,
		right: Dictionary) -> bool:
	if left.landing_cell == right.landing_cell \
			or StringName(left.recipe_id) == StringName(right.recipe_id):
		return false
	for cell_value: Variant in (left.protected_cells as Dictionary).keys():
		if (right.protected_cells as Dictionary).has(cell_value):
			return false
	return true


static func _annotate_landmark_party_walls(
		landmarks: Array[Dictionary]) -> void:
	## Measured prefab bodies may meet at one exact cell face. That contact is an
	## authored city seam, not two exterior facades occupying the same plane. Both
	## transactions claim the same deterministic joint owner and face kind, so the
	## grid stores one canonical party wall (or vertical construction joint) while
	## each landmark retains independent volume and feature ownership.
	for landmark: Dictionary in landmarks:
		landmark["party_wall_faces"] = {}
	for left_index in landmarks.size():
		var left := landmarks[left_index]
		var left_body := left.get("body", {}) as Dictionary
		for right_index in range(left_index + 1, landmarks.size()):
			var right := landmarks[right_index]
			var right_body := right.get("body", {}) as Dictionary
			var ids: Array[StringName] = [StringName(left.feature_id),
				StringName(right.feature_id)]
			ids.sort_custom(func(a: StringName, b: StringName) -> bool:
				return String(a) < String(b))
			var joint_owner := StringName("%s+%s" % [ids[0], ids[1]])
			for cell_value: Variant in left_body.keys():
				var cell := cell_value as Vector3i
				for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
						Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
						Vector3i.BACK]:
					var neighbor := cell + direction
					if not right_body.has(neighbor):
						continue
					if not (left.party_wall_faces as Dictionary).has(cell):
						(left.party_wall_faces as Dictionary)[cell] = {}
					((left.party_wall_faces as Dictionary)[cell] \
						as Dictionary)[direction] = joint_owner
					if not (right.party_wall_faces as Dictionary).has(neighbor):
						(right.party_wall_faces as Dictionary)[neighbor] = {}
					((right.party_wall_faces as Dictionary)[neighbor] \
						as Dictionary)[-direction] = joint_owner


static func _protected_owners_with_landmarks(protected_owners: Dictionary,
		landmarks: Array[Dictionary]) -> Dictionary:
	var trial := protected_owners.duplicate(true)
	for landmark: Dictionary in landmarks:
		var feature_id := StringName(landmark.feature_id)
		for cell_value: Variant in (landmark.protected_cells as Dictionary).keys():
			if not trial.has(cell_value):
				trial[cell_value] = {}
			(trial[cell_value] as Dictionary)[feature_id] = true
	return trial


static func _landmark_recipe_ids(landmarks: Array[Dictionary]) \
		-> Array[StringName]:
	var out: Array[StringName] = []
	for landmark: Dictionary in landmarks:
		out.append(StringName(landmark.recipe_id))
	return out


static func _landmark_set_diagnostic_key(
		landmarks: Array[Dictionary]) -> String:
	var parts := PackedStringArray()
	for landmark: Dictionary in landmarks:
		var origin := landmark.origin as Vector3i
		var landing := landmark.landing_cell as Vector3i
		parts.append("%s@%d:%d:%d/r%d/land%d:%d:%d" % [
			StringName(landmark.recipe_id), origin.x, origin.y, origin.z,
			int(landmark.yaw_quarters), landing.x, landing.y, landing.z])
	parts.sort()
	return "|".join(parts)


static func _landmark_reservation_search_key(landmark: Dictionary) -> String:
	var origin := landmark.origin as Vector3i
	var landing := landmark.landing_cell as Vector3i
	return "%s@%d:%d:%d/r%d/land%d:%d:%d" % [
		StringName(landmark.recipe_id), origin.x, origin.y, origin.z,
		int(landmark.yaw_quarters), landing.x, landing.y, landing.z]


static func _landmark_candidate_corpus_key(
		candidates: Array[Dictionary]) -> String:
	var parts := PackedStringArray()
	for candidate: Dictionary in candidates:
		parts.append(_landmark_reservation_search_key(candidate))
	parts.sort()
	return ("%d|%s" % [parts.size(), "|".join(parts)]).sha256_text()


static func _reserve_landmark_preplans(grid: WarrenSpatialGrid,
		landmarks: Array[Dictionary]) -> bool:
	_annotate_landmark_party_walls(landmarks)
	for landmark_index in landmarks.size():
		var landmark := landmarks[landmark_index]
		if not _reserve_landmark_preplan(grid, landmark):
			last_preplan_landmark_diagnostic["reservation_failure"] = {
				"index": landmark_index,
				"feature_id": landmark.get("feature_id", &""),
				"recipe_id": landmark.get("recipe_id", &""),
				"origin": landmark.get("origin", Vector3i.ZERO),
				"rejection": grid.last_rejection,
			}
			return false
	var selected: Array[Dictionary] = []
	for landmark: Dictionary in landmarks:
		selected.append({"feature_id": landmark.feature_id,
			"recipe_id": landmark.recipe_id,
			"source_family": landmark.source_family,
			"origin": landmark.origin,
			"yaw_quarters": landmark.yaw_quarters,
			"landing_cell": landmark.landing_cell,
			"entrance_cell": landmark.entrance_cell,
			"body_cell_count": (landmark.body as Dictionary).size(),
			"clearance_cell_count": (landmark.clearance as Dictionary).size(),
			"displaced_parcel_count": (landmark.blocker_parcels \
				as Dictionary).size()})
	last_preplan_landmark_diagnostic["selected"] = selected
	return true


static func _annotate_landmark_skywalk_connections(
		landmarks: Array[Dictionary], skywalks: Array[Dictionary]) -> void:
	var landmark_by_id: Dictionary = {}
	for landmark: Dictionary in landmarks:
		landmark["skywalk_socket_faces"] = {}
		landmark_by_id[StringName(landmark.feature_id)] = landmark
	for skywalk: Dictionary in skywalks:
		var owner_ids := skywalk.get("owner_parcel_ids", []) as Array
		var endpoints := skywalk.get("owner_endpoints", []) as Array
		for endpoint_index in mini(owner_ids.size(), endpoints.size()):
			var owner_id := StringName(owner_ids[endpoint_index])
			if not landmark_by_id.has(owner_id):
				continue
			var endpoint := endpoints[endpoint_index] as Dictionary
			var landmark := landmark_by_id[owner_id] as Dictionary
			(landmark.skywalk_socket_faces as Dictionary)[
				endpoint.cell as Vector3i] = endpoint.facing as Vector3i
			var skywalk_body := skywalk.get("reserved_cells", {}) as Dictionary
			for cell_value: Variant in (landmark.body as Dictionary).keys():
				var cell := cell_value as Vector3i
				for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
						Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
						Vector3i.BACK]:
					if skywalk_body.has(cell + direction):
						(landmark.skywalk_socket_faces as Dictionary)[cell] = \
							direction


static func _reserve_landmark_preplan(grid: WarrenSpatialGrid,
		landmark: Dictionary) -> bool:
	var feature_id := StringName(landmark.feature_id)
	var body_set := landmark.body as Dictionary
	var body: Array[Vector3i] = []
	body.assign(body_set.keys())
	body.sort_custom(_cell_less)
	var clearance_only: Array[Vector3i] = []
	for cell_value: Variant in (landmark.clearance as Dictionary).keys():
		if not body_set.has(cell_value):
			clearance_only.append(cell_value as Vector3i)
	var bearing: Array[Vector3i] = []
	bearing.assign((landmark.bearing_cells as Dictionary).keys())
	var entrance_cell := landmark.entrance_cell as Vector3i
	var landing_cell := landmark.landing_cell as Vector3i
	var skywalk_socket_faces := landmark.get("skywalk_socket_faces", {}) \
		as Dictionary
	var party_wall_faces := landmark.get("party_wall_faces", {}) as Dictionary
	var route_roof_is_shared := bool(landmark.get("route_roof_is_shared",
		false))
	var tx := grid.begin_transaction(feature_id)
	if body.is_empty() or bearing.is_empty() \
			or not tx.require_use(body, [WarrenSpatialGrid.Use.OUTSIDE,
				WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not tx.reserve(body, WarrenSpatialGrid.Reservation.FEATURE \
				| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not clearance_only.is_empty() and not tx.reserve(clearance_only,
				WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not tx.reserve(bearing,
				WarrenSpatialGrid.Reservation.TERRAIN_BEARING, feature_id) \
			or not tx.assign_use(body, WarrenSpatialGrid.Use.PRIVATE_VOLUME,
				feature_id):
		return false
	for cell: Vector3i in body:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if body_set.has(neighbor):
				continue
			var cell_joints := party_wall_faces.get(cell, {}) as Dictionary
			if cell_joints.has(direction):
				var joint_kind := WarrenSpatialGrid.FaceKind.PARTY_WALL \
					if direction.y == 0 \
					else WarrenSpatialGrid.FaceKind.CONSTRUCTION_JOINT
				if not tx.claim_face(cell, direction, joint_kind,
						StringName(cell_joints[direction])):
					return false
				continue
			if skywalk_socket_faces.get(cell, Vector3i.ZERO) == direction:
				continue
			var kind := WarrenSpatialGrid.FaceKind.FACADE
			if cell == entrance_cell and neighbor == landing_cell:
				kind = WarrenSpatialGrid.FaceKind.DOOR
			elif direction == Vector3i.UP:
				kind = WarrenSpatialGrid.FaceKind.ROOF
			elif direction == Vector3i.DOWN:
				kind = WarrenSpatialGrid.FaceKind.PRIVATE_FLOOR
			# TASK C5c RULING 5. A prefab under an upper street meets that
			# street's PUBLIC_FLOOR on its own top boundary, and the route
			# claimed that face first. Claiming ROOF there is not a better
			# answer than the one already on the grid -- it is the same
			# boundary described twice -- so the prefab takes no claim and the
			# street keeps its floor. `WarrenPlotPlanner._no_street_left
			# _hanging` allows the arrangement on purpose: the plot BEARS that
			# street. Maze-only, and carried on the reservation the maze asset
			# pass builds rather than on a mode global, so no searched landmark
			# can silently stop rejecting a conflict it is meant to reject.
			if route_roof_is_shared and direction == Vector3i.UP:
				var existing := grid.face_claim(cell, Vector3i.UP)
				if not existing.is_empty() and int(existing.get("kind", -1)) \
						== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
					continue
			if not tx.claim_face(cell, direction, kind, feature_id):
				return false
	return tx.commit()


static func _landmark_bearing_follows_terrain(bearing: Dictionary,
		volume: WarrenVolumePlan) -> bool:
	var massif := volume.mass_context.get("massif") as WarrenMassif
	if massif == null:
		return false
	# TASK C5c RULING 5. In a searched town the only thing under a prefab is
	# terrain, so "follows terrain" and "stands on something" are one test. In
	# MAZE mode they are two: the plot planner sited this asset on a plot whose
	# floor may be bands above natural ground, and what fills the gap is the
	# derived rock Task C5 retains and Task C5b skins as real stone. C2 kept
	# the rule strict because nothing drew that rock; it is drawn now, so the
	# honest test is that every bearing cell rests on SOLID the source names --
	# the plot's own flat floor at the datum, or the retained stone under it --
	# and never on air.
	var source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	for cell_value: Variant in bearing.keys():
		var cell := cell_value as Vector3i
		var macro_column := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		if massif.bearing_at(macro_column) == cell.y:
			continue
		if source == null or cell.y < massif.bearing_at(macro_column) \
				or not source.solid_at(Vector3i(macro_column.x, cell.y - 1,
					macro_column.y)):
			return false
	return true


static func _proposal_base_plate(proposal: Dictionary) -> Dictionary:
	var origin := proposal.origin as Vector3i
	var out: Dictionary = {}
	for cell: Vector3i in StaggeredFabricCompiler.proposal_occupied_cells(
			proposal):
		if cell.y == origin.y:
			out[Vector2i(cell.x, cell.z)] = true
	return out


static func _preplan_spatial_market(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, proposals: Array[Dictionary],
		program: SettlementFabricProgram,
		protected_owners: Dictionary) -> Dictionary:
	## Attach the reviewed 6 x 3 m bazaar to one exact base-room MARKET socket.
	## Its central two-by-two aisle is already canonical route air; the corner
	## posts and continuous canopy surround/cover that negative space without
	## turning the market into a detached tent row or a late decoration pass.
	var candidates: Array[Dictionary] = []
	var socket_count := 0
	var ground_fit_count := 0
	var body_fit_count := 0
	var aisle_fit_count := 0
	var clearance_fit_count := 0
	var backing_fit_count := 0
	var aisle_failures: Array[Dictionary] = []
	var feature_id := &"spatial.feature.market.00"
	var aisle_local: Array[Vector3i] = [
		Vector3i(-1, 0, -1), Vector3i(0, 0, -1),
		Vector3i(-1, 0, 0), Vector3i(0, 0, 0),
	]
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		var profile := WarrenParcelConstruction.profile_for(parcel)
		if profile.is_empty():
			continue
		var proposal_origin := proposal.origin as Vector3i
		var proposal_yaw := int(proposal.yaw_quarters)
		var minimum := profile.minimum as Vector3i
		var size := profile.size as Vector3i
		var sockets: Array[Dictionary] = [
			{"cell": minimum + Vector3i(size.x - 1, 0,
				(size.z - 1) / 2), "facing": Vector3i.RIGHT},
			{"cell": minimum + Vector3i(0, 0, (size.z - 1) / 2),
				"facing": Vector3i.LEFT},
			{"cell": minimum + Vector3i((size.x - 1) / 2, 0, 0),
				"facing": Vector3i.FORWARD},
			{"cell": minimum + Vector3i((size.x - 1) / 2, 0,
				size.z - 1), "facing": Vector3i.BACK},
		]
		for socket: Dictionary in sockets:
			socket_count += 1
			var backing_cell := FabricRecipe.transform_cell(
				socket.cell as Vector3i, proposal_origin, proposal_yaw)
			var backing_facing := FabricRecipe.transform_direction(
				socket.facing as Vector3i, proposal_yaw)
			var market_yaw := _yaw_for_direction(Vector3i.FORWARD,
				-backing_facing)
			if market_yaw < 0:
				continue
			var market_socket_cell := backing_cell + backing_facing
			var market_origin := market_socket_cell - FabricRecipe.transform_cell(
				Vector3i(-1, 0, -1), Vector3i.ZERO, market_yaw)
			var family := posmod(Helper._mix64(volume.world_seed \
				^ String(parcel.stable_id).hash() ^ backing_cell.x * 73856093 \
				^ backing_cell.z * 19349663),
				SettlementFabricProgram.MARKET_STALLS.size())
			var recipe_id := StringName("market.covered.%02d.garden" % family)
			var recipe := program.recipe(recipe_id)
			if recipe == null or not recipe.has_tag(&"covered_market"):
				continue
			if not WarrenMarketSolver._bearing_follows_local_ground(market_origin,
					market_yaw, volume, WarrenMarketSolver.COVERED_MARKET_MINIMUM,
					WarrenMarketSolver.COVERED_MARKET_SIZE):
				continue
			ground_fit_count += 1
			var body: Dictionary = {}
			for cells: Array[Vector3i] in [recipe.solid_cells,
					recipe.headroom_cells, recipe.walk_cells]:
				for local_cell: Vector3i in cells:
					body[FabricRecipe.transform_cell(local_cell, market_origin,
						market_yaw)] = true
			if body.is_empty() or not _skywalk_body_fits_grid(grid, body):
				continue
			body_fit_count += 1
			# The named backing room may touch the visual envelope, but structural
			# market cells may never replace the room they claim to address.
			var overlaps_backing := false
			for body_value: Variant in body.keys():
				if (protected_owners.get(body_value, {}) as Dictionary).has(
						parcel.stable_id):
					overlaps_backing = true
					break
			if overlaps_backing:
				continue
			var aisle := _market_public_aisle(grid, volume, market_origin,
				market_yaw, aisle_local, body, protected_owners, parcel.stable_id)
			if aisle.is_empty():
				if aisle_failures.size() < 16:
					aisle_failures.append({"parcel": parcel.stable_id,
						"origin": market_origin, "yaw": market_yaw})
				continue
			var public_cells := aisle.cells as Dictionary
			var covered_aisle_cells := aisle.covered_cells as Dictionary
			var new_public_cell_count := int(aisle.new_public_cell_count)
			var entrance_edge_count := int(aisle.entrance_edge_count)
			var entrance_width := int(aisle.entrance_width)
			aisle_fit_count += 1
			var components: Array[Dictionary] = [{"recipe_id": recipe_id,
				"origin": market_origin, "yaw_quarters": market_yaw}]
			var clearance := _skywalk_visual_clearance_cells(components, program)
			if clearance.is_empty() or not _cells_fit_grid(grid, clearance):
				continue
			clearance_fit_count += 1
			var bearing_cells: Dictionary = {}
			for local_cell: Vector3i in FabricRecipe.box_cells(
					WarrenMarketSolver.COVERED_MARKET_MINIMUM,
					Vector3i(WarrenMarketSolver.COVERED_MARKET_SIZE.x, 1,
						WarrenMarketSolver.COVERED_MARKET_SIZE.z)):
				bearing_cells[FabricRecipe.transform_cell(local_cell,
					market_origin, market_yaw)] = true
			var blocker_count := _skywalk_blocker_count(clearance,
				protected_owners, {parcel.stable_id: true})
			var shelter := _market_shelter_audit(grid, public_cells, body,
				protected_owners)
			var overhead_public_floor_seam_count := \
				_market_overhead_public_floor_seam_count(grid, body, public_cells)
			candidates.append({"feature_id": feature_id,
				"kind": &"covered_market", "recipe_id": recipe_id,
				"origin": market_origin, "yaw_quarters": market_yaw,
				"components": components, "reserved_cells": body,
				"public_cells": public_cells,
				"covered_aisle_cells": covered_aisle_cells,
				"aisle_extension_cell_count": public_cells.size() \
					- covered_aisle_cells.size(),
				"aisle_extension_length": int(aisle.extension_length),
				"new_public_cell_count": new_public_cell_count,
				"street_entrance_edge_count": entrance_edge_count,
				"street_entrance_width": entrance_width,
				"visual_clearance_cells": clearance,
				"bearing_cells": bearing_cells,
				"owner_parcel_ids": [parcel.stable_id],
				"backing_parcel_id": parcel.stable_id,
				"backing_cell": backing_cell,
				"backing_facing": backing_facing,
				"blocker_count": blocker_count,
				"overhead_public_floor_seam_count":
					overhead_public_floor_seam_count,
				"open_horizon_max_cells": int(shelter.max_open_cells),
				"open_horizon_total_cells": int(shelter.total_open_cells),
				"core_radius_squared": float(shelter.core_radius_squared),
				"tie": posmod(Helper._mix64(volume.world_seed \
					^ String(recipe_id).hash() ^ market_origin.x * 31 \
					^ market_origin.z * 47 ^ market_yaw * 131), 1000003)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		# A covered bazaar belongs inside the inhabited maze. Prefer the exact
		# candidate whose aisle views terminate in mass soonest; a low room-
		# displacement count may break ties, but may not drag the market back to
		# an empty perimeter merely because that space is cheap.
		if int(a.overhead_public_floor_seam_count) \
				!= int(b.overhead_public_floor_seam_count):
			return int(a.overhead_public_floor_seam_count) \
				> int(b.overhead_public_floor_seam_count)
		if int(a.open_horizon_max_cells) != int(b.open_horizon_max_cells):
			return int(a.open_horizon_max_cells) < int(b.open_horizon_max_cells)
		if int(a.open_horizon_total_cells) != int(b.open_horizon_total_cells):
			return int(a.open_horizon_total_cells) < int(b.open_horizon_total_cells)
		if not is_equal_approx(float(a.core_radius_squared),
				float(b.core_radius_squared)):
			return float(a.core_radius_squared) < float(b.core_radius_squared)
		if int(a.aisle_extension_length) != int(b.aisle_extension_length):
			return int(a.aisle_extension_length) < int(b.aisle_extension_length)
		if int(a.blocker_count) != int(b.blocker_count):
			return int(a.blocker_count) < int(b.blocker_count)
		return int(a.tie) < int(b.tie))
	var viable: Array[Dictionary] = []
	var open_horizon_limit := _market_open_horizon_limit(volume)
	for candidate: Dictionary in candidates:
		if int(candidate.open_horizon_max_cells) \
				> open_horizon_limit:
			continue
		if not _market_backing_composition_survives(grid, candidate, proposals,
				protected_owners, volume.world_seed):
			continue
		backing_fit_count += 1
		viable.append(candidate)
	var shelter_preview: Array[Dictionary] = []
	for index in mini(12, candidates.size()):
		var candidate := candidates[index]
		shelter_preview.append({"parcel": candidate.backing_parcel_id,
			"origin": candidate.origin,
			"overhead_public_floor_seams": int(
				candidate.overhead_public_floor_seam_count),
			"open_max": int(candidate.open_horizon_max_cells),
			"open_total": int(candidate.open_horizon_total_cells),
			"radius_squared": float(candidate.core_radius_squared),
			"aisle_extension_length": int(candidate.aisle_extension_length),
			"blockers": int(candidate.blocker_count)})
	last_preplan_market_diagnostic = {"socket_count": socket_count,
		"ground_fit_count": ground_fit_count, "body_fit_count": body_fit_count,
		"aisle_fit_count": aisle_fit_count,
		"clearance_fit_count": clearance_fit_count,
		"candidate_count": candidates.size(),
		"backing_fit_count": backing_fit_count,
		"open_horizon_limit_cells": open_horizon_limit,
		"shelter_preview": shelter_preview,
		"aisle_failures": aisle_failures}
	return {"candidates": viable}


static func _market_open_horizon_limit(volume: WarrenVolumePlan) -> int:
	## Shelter is measured in fixed 1.5 m lattice cells, while the authored town
	## radius deliberately varies by scale. Keep compact and standard bazaars
	## tucked into the tightest alleys. A large courtyard town may admit one
	## longer approach sightline, but it still has to terminate inside its own
	## inhabited mass; grand towns get only the review ray's finite upper bound.
	var profile := _scale_profile_for_volume(volume)
	if profile == null:
		return MAX_MARKET_OPEN_HORIZON_CELLS
	match profile.scale_id:
		WarrenVillageScaleProfile.LARGE:
			return LARGE_MARKET_OPEN_HORIZON_CELLS
		WarrenVillageScaleProfile.GRAND:
			return GRAND_MARKET_OPEN_HORIZON_CELLS
		_:
			return MAX_MARKET_OPEN_HORIZON_CELLS


static func _market_overhead_public_floor_seam_count(
		grid: WarrenSpatialGrid, body: Dictionary,
		planned_public_cells: Dictionary = {}) -> int:
	## The canopy is part of the vertical public-realm composition: at least one
	## of its exposed upper faces must meet an already-sealed public floor. This
	## makes the bazaar a genuine inhabited undercroft instead of a tent inserted
	## into whichever ground-level void happened to remain cheapest.
	var count := 0
	for cell_value: Variant in body.keys():
		var cell := cell_value as Vector3i
		if body.has(cell + Vector3i.UP):
			continue
		var upper_cell := cell + Vector3i.UP
		var existing := grid.face_claim(cell, Vector3i.UP)
		if planned_public_cells.has(upper_cell) \
				or not existing.is_empty() and int(existing.kind) \
					== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
			count += 1
	return count


static func _market_shelter_audit(grid: WarrenSpatialGrid,
		public_cells: Dictionary, body: Dictionary,
		proposed_private_cells: Dictionary) -> Dictionary:
	## Measure the negative-space experience rather than distance to a nominal
	## town centre. From every exposed aisle edge, walk a bounded sight ray until
	## it meets either the market construction or an actual proposed room cell.
	## Generic ALLOCATABLE massif is deliberately not shelter: most of it is
	## discarded after room composition, and counting it made edge markets look
	## enclosed in planning before opening directly onto empty terrain in the
	## render. PUBLIC_AIR and true empty OUTSIDE cells keep the ray open. The maximum is
	## the important failure mode visible in review: one market mouth looking
	## straight out of the town. The total distinguishes equally bounded arcades.
	const HORIZON_LIMIT_CELLS := 10
	var maximum_open := 0
	var total_open := 0
	var centre := Vector2.ZERO
	for cell_value: Variant in public_cells.keys():
		var cell := cell_value as Vector3i
		centre += Vector2(cell.x + 0.5, cell.z + 0.5)
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			if public_cells.has(cell + direction):
				continue
			var open_cells := 0
			for distance in range(1, HORIZON_LIMIT_CELLS + 1):
				var sample := cell + direction * distance
				if body.has(sample) or body.has(sample + Vector3i.UP) \
						or proposed_private_cells.has(sample) \
						or proposed_private_cells.has(sample + Vector3i.UP):
					break
				open_cells += 1
				if not grid.contains(sample):
					break
			maximum_open = maxi(maximum_open, open_cells)
			total_open += open_cells
	if not public_cells.is_empty():
		centre /= float(public_cells.size())
	return {"max_open_cells": maximum_open,
		"total_open_cells": total_open,
		"core_radius_squared": centre.length_squared()}


static func _market_backing_composition_survives(grid: WarrenSpatialGrid,
		market: Dictionary, proposals: Array[Dictionary],
		protected_owners: Dictionary, world_seed: int) -> bool:
	var backing_parcel_id := StringName(market.backing_parcel_id)
	var proposal: Dictionary = {}
	for candidate: Dictionary in proposals:
		if (candidate.parcel as WarrenBuildingParcel).stable_id \
				== backing_parcel_id:
			proposal = candidate
			break
	if proposal.is_empty():
		return false
	var trial := protected_owners.duplicate(true)
	var feature_id := StringName(market.feature_id)
	var endpoint_allowance: Dictionary = {backing_parcel_id: true}
	for cell_value: Variant in (market.reserved_cells as Dictionary).keys():
		if not trial.has(cell_value):
			trial[cell_value] = {}
		(trial[cell_value] as Dictionary)[feature_id] = true
	for cell_value: Variant in (market.visual_clearance_cells \
			as Dictionary).keys():
		if (market.reserved_cells as Dictionary).has(cell_value):
			continue
		if not trial.has(cell_value):
			trial[cell_value] = {}
		(trial[cell_value] as Dictionary)[feature_id] = endpoint_allowance
	_protect_market_public_air(trial, market, feature_id)
	var parcel := proposal.parcel as WarrenBuildingParcel
	var origin := proposal.origin as Vector3i
	var storeys := int(proposal.storeys)
	var threshold := WarrenParcelConstruction.threshold_cell(parcel)
	var addressed_storey := clampi(floori(float(threshold.y - origin.y) \
		/ float(WarrenSpatialGrid.STOREY_CELLS)), 0, storeys - 1)
	var forced: Dictionary = {0: Vector2i.ZERO,
		addressed_storey / 2: Vector2i.ZERO}
	return not _composition_offsets(grid, _proposal_base_plate(proposal),
		origin.y, storeys, trial, backing_parcel_id, world_seed, forced).is_empty()


static func _protected_owners_with_market(protected_owners: Dictionary,
		market: Dictionary) -> Dictionary:
	var trial := protected_owners.duplicate(true)
	if market.is_empty() or bool(market.get("optional_absent", false)):
		return trial
	var feature_id := StringName(market.feature_id)
	var endpoint_allowance: Dictionary = {
		StringName(market.backing_parcel_id): true}
	for cell_value: Variant in (market.reserved_cells as Dictionary).keys():
		if not trial.has(cell_value):
			trial[cell_value] = {}
		(trial[cell_value] as Dictionary)[feature_id] = true
	for cell_value: Variant in (market.visual_clearance_cells \
			as Dictionary).keys():
		if (market.reserved_cells as Dictionary).has(cell_value):
			continue
		if not trial.has(cell_value):
			trial[cell_value] = {}
		(trial[cell_value] as Dictionary)[feature_id] = endpoint_allowance
	_protect_market_public_air(trial, market, feature_id)
	return trial


static func _protect_market_public_air(protected_owners: Dictionary,
		market: Dictionary, feature_id: StringName) -> void:
	## The aisle floor is a logical surface; the occupied reservation is its full
	## swept player volume. Existing route air is already blocked by the grid,
	## but aisle extensions still read ALLOCATABLE during preflight. Protect both
	## headroom bands here so the exact room solve sees the same undercroft void
	## that `_reserve_market_preplan` later commits as PUBLIC_AIR.
	for floor_value: Variant in (market.get("public_cells", {}) \
			as Dictionary).keys():
		var floor := floor_value as Vector3i
		for y_offset in WarrenVolumePlan.HEADROOM_BANDS:
			var air := floor + Vector3i.UP * y_offset
			if not protected_owners.has(air):
				protected_owners[air] = {}
			(protected_owners[air] as Dictionary)[feature_id] = true


static func _protected_owners_with_courtyard_bridge(
		protected_owners: Dictionary, candidate: Dictionary) -> Dictionary:
	## The occupied court room yields only to its one exact endpoint lineage.
	## Its body remains unavailable to every room/landmark/skywalk, while the
	## measured eave envelope may overlap the parent building at the authored
	## socket and nowhere else.
	var trial := protected_owners.duplicate(true)
	var reservation := candidate.reservation as Dictionary
	var feature_id := StringName(reservation.feature_id)
	var endpoint_allowance := _skywalk_endpoint_owner_set(reservation)
	var body := candidate.body as Dictionary
	for cell_value: Variant in body.keys():
		if not trial.has(cell_value):
			trial[cell_value] = {}
		(trial[cell_value] as Dictionary)[feature_id] = true
	for cell_value: Variant in (candidate.clearance as Dictionary).keys():
		if body.has(cell_value):
			continue
		if not trial.has(cell_value):
			trial[cell_value] = {}
		(trial[cell_value] as Dictionary)[feature_id] = endpoint_allowance
	for cell_value: Variant in (candidate.priority_cells as Dictionary).keys():
		if not trial.has(cell_value):
			trial[cell_value] = {}
		(trial[cell_value] as Dictionary)[StringName(
			(candidate.priority_cells as Dictionary)[cell_value])] = true
	return trial


static func _absent_courtyard_bridge_candidate() -> Dictionary:
	## Sentinel used only by profiles where the 6 x 6 m threaded upper court is
	## not a size invariant. It lets the market/landmark/skywalk joint beam retain
	## one code path while reserving no cells, moving no rooms, and compiling no
	## feature. Large and grand profiles never receive this candidate.
	return {
		"optional_absent": true,
		"reservation": {
			"feature_id": &"spatial.feature.courtyard.absent",
			"origin": Vector3i.ZERO,
			"owner_parcel_ids": [] as Array[StringName],
			"owner_endpoints": [] as Array[Dictionary],
			"components": [] as Array[Dictionary],
		},
		"body": {},
		"clearance": {},
		"priority_cells": {},
		"forced_offsets": {},
		"excluded_parcel_ids": [] as Array[StringName],
	}


static func _macro_composition_preflight(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, proposals: Array[Dictionary],
		base_protected_owners: Dictionary,
		court_fixed_blocks_by_parcel: Dictionary) -> Dictionary:
	var trial_owners := base_protected_owners.duplicate(true)
	var solved_offsets_by_parcel: Dictionary = {}
	var exact_forced_offsets_by_parcel: Dictionary = {}
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		var storeys := int(proposal.storeys)
		var origin := proposal.origin as Vector3i
		var base_plate := _proposal_base_plate(proposal)
		if storeys <= 0 or base_plate.is_empty():
			continue
		var threshold := WarrenParcelConstruction.threshold_cell(parcel)
		var addressed_storey := clampi(floori(float(threshold.y - origin.y) \
			/ float(WarrenSpatialGrid.STOREY_CELLS)), 0, storeys - 1)
		var forced: Dictionary = {0: Vector2i.ZERO,
			floori(float(addressed_storey) / 2.0): Vector2i.ZERO}
		for block_value: Variant in (court_fixed_blocks_by_parcel.get(
				parcel.stable_id, {}) as Dictionary).keys():
			forced[int(block_value)] = Vector2i.ZERO
		var offsets := _composition_offsets(grid, base_plate, origin.y,
			storeys, trial_owners, parcel.stable_id, volume.world_seed, forced)
		if offsets.is_empty():
			continue
		solved_offsets_by_parcel[parcel.stable_id] = offsets
		exact_forced_offsets_by_parcel[parcel.stable_id] = forced
		for cell: Vector3i in _segment_cells(base_plate, origin.y, offsets, 0,
				storeys):
			if not trial_owners.has(cell):
				trial_owners[cell] = {}
			(trial_owners[cell] as Dictionary)[parcel.stable_id] = true
	return WarrenRoomCompositionPlanner.solve(grid, volume, proposals,
		solved_offsets_by_parcel, exact_forced_offsets_by_parcel, {},
		trial_owners, {}, [] as Array[Dictionary], volume.world_seed, false, true)


static func _court_candidate_preserves_exact_room_envelopes(
		grid: WarrenSpatialGrid, volume: WarrenVolumePlan,
		proposals: Array[Dictionary], program: SettlementFabricProgram,
		market: Dictionary, court_candidate: Dictionary,
		base_protected_owners: Dictionary,
		court_fixed_blocks_by_parcel: Dictionary,
		skywalk_plan: Dictionary,
		enable_paired_registration_relief: bool,
		result: Dictionary,
		stop_after_macro_support: bool = false) -> bool:
	## Exact post-feature preflight for the six-member court frontier. Solve the
	## actual room grammar with the already-fixed market, landmarks, three
	## skywalks, and this cantilever, then compare authored room envelopes against
	## its two measured components. This is deliberately not a raster halo: party
	## walls and narrow streets remain legal, while the exact eave collision that
	## final fabric compilation would reject removes only this court candidate.
	last_preplan_market_diagnostic.erase(
		"last_exact_court_tall_tower_failure")
	last_preplan_market_diagnostic.erase(
		"last_exact_room_composition_failure")
	last_preplan_market_diagnostic.erase(
		"last_exact_room_pair_failure")
	last_preplan_market_diagnostic.erase(
		"last_exact_court_composition_failure")
	last_preplan_market_diagnostic.erase(
		"last_exact_court_required_conflict")
	result.clear()
	var initial_excluded_ids: Array[StringName] = []
	initial_excluded_ids.assign(court_candidate.get(
		"excluded_parcel_ids", []) as Array)
	initial_excluded_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	var initial_excluded_set: Dictionary = {}
	for excluded_id: StringName in initial_excluded_ids:
		initial_excluded_set[excluded_id] = true
	var initial_feature_excluded_set: Dictionary = {}
	for excluded_value: Variant in court_candidate.get(
			"feature_clearance_displaced_parcel_ids", []) as Array:
		initial_feature_excluded_set[StringName(excluded_value)] = true
	var forced_offsets_by_parcel := (skywalk_plan.forced_offsets \
		as Dictionary).duplicate(true)
	for parcel_value: Variant in (court_candidate.forced_offsets \
			as Dictionary).keys():
		var parcel_id := StringName(parcel_value)
		if not forced_offsets_by_parcel.has(parcel_id):
			forced_offsets_by_parcel[parcel_id] = {}
		for block_value: Variant in ((court_candidate.forced_offsets \
				as Dictionary)[parcel_id] as Dictionary).keys():
			var block := int(block_value)
			var wanted := ((court_candidate.forced_offsets as Dictionary)[
				parcel_id] as Dictionary)[block_value] as Vector2i
			var existing := (forced_offsets_by_parcel[parcel_id] \
				as Dictionary).get(block, wanted) as Vector2i
			if existing != wanted:
				return false
			(forced_offsets_by_parcel[parcel_id] as Dictionary)[block] = wanted
	var trial_owners := _protected_owners_with_courtyard_bridge(
		base_protected_owners, court_candidate)
	for cell_value: Variant in (skywalk_plan.priority_cells as Dictionary).keys():
		trial_owners[cell_value] = {StringName(
			(skywalk_plan.priority_cells as Dictionary)[cell_value]): true}
	var skywalk_reservations: Array[Dictionary] = []
	skywalk_reservations.assign(skywalk_plan.get("reservations", []) as Array)
	for reservation_index in skywalk_reservations.size():
		var skywalk := skywalk_reservations[reservation_index]
		var reservation_owner := StringName("spatial.skywalk.reserve.%02d" \
			% reservation_index)
		var body := skywalk.reserved_cells as Dictionary
		for cell_value: Variant in body.keys():
			if not trial_owners.has(cell_value):
				trial_owners[cell_value] = {}
			(trial_owners[cell_value] as Dictionary)[reservation_owner] = true
		var endpoint_allowance := _skywalk_endpoint_owner_set(skywalk)
		for cell_value: Variant in (skywalk.get("visual_clearance_cells", {}) \
				as Dictionary).keys():
			if body.has(cell_value):
				continue
			if not trial_owners.has(cell_value):
				trial_owners[cell_value] = {}
			(trial_owners[cell_value] as Dictionary)[reservation_owner] = \
				endpoint_allowance
	var solved_offsets_by_parcel: Dictionary = {}
	var exact_forced_offsets_by_parcel: Dictionary = {}
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		# A repeated exact pass starts from the prior pass's complete-parcel
		# dispositions. Reintroducing them here and merely comparing the same
		# exclusion list afterward would incorrectly label the stale composition
		# reusable.
		if initial_excluded_set.has(parcel.stable_id):
			continue
		var storeys := int(proposal.storeys)
		var proposal_origin := proposal.origin as Vector3i
		var base_plate := _proposal_base_plate(proposal)
		if storeys <= 0 or base_plate.is_empty():
			continue
		var threshold := WarrenParcelConstruction.threshold_cell(parcel)
		var addressed_storey := clampi(floori(float(
			threshold.y - proposal_origin.y) \
			/ float(WarrenSpatialGrid.STOREY_CELLS)), 0, storeys - 1)
		var forced: Dictionary = {0: Vector2i.ZERO,
			floori(float(addressed_storey) / 2.0): Vector2i.ZERO}
		for block_value: Variant in (court_fixed_blocks_by_parcel.get(
				parcel.stable_id, {}) as Dictionary).keys():
			forced[int(block_value)] = Vector2i.ZERO
		for block_value: Variant in (forced_offsets_by_parcel.get(
				parcel.stable_id, {}) as Dictionary).keys():
			var block := int(block_value)
			var wanted := (forced_offsets_by_parcel[parcel.stable_id] \
				as Dictionary)[block_value] as Vector2i
			if forced.has(block) and forced[block] != wanted:
				forced.clear()
				break
			forced[block] = wanted
		if forced.is_empty():
			continue
		var offsets := _composition_offsets(grid, base_plate,
			proposal_origin.y, storeys, trial_owners, parcel.stable_id,
			volume.world_seed, forced)
		if offsets.is_empty():
			continue
		solved_offsets_by_parcel[parcel.stable_id] = offsets
		exact_forced_offsets_by_parcel[parcel.stable_id] = forced
		for cell: Vector3i in _segment_cells(base_plate, proposal_origin.y,
				offsets, 0, storeys):
			if not trial_owners.has(cell):
				trial_owners[cell] = {}
			(trial_owners[cell] as Dictionary)[parcel.stable_id] = true
	var composition := WarrenRoomCompositionPlanner.solve(grid, volume,
		proposals, solved_offsets_by_parcel, exact_forced_offsets_by_parcel,
		market, trial_owners, forced_offsets_by_parcel,
		skywalk_reservations, volume.world_seed,
		enable_paired_registration_relief, stop_after_macro_support)
	if composition.is_empty():
		# The room solver publishes its audit before rejecting a repeated tower.
		# Preserve that structured cause here: the enclosing hero-feature beam can
		# then advance to another market/court state instead of spending twelve
		# landmark palette permutations on the same forced floorplate geometry.
		# This is not a heuristic cutoff; every palette permutation inherits the
		# identical sealed room obligations that produced this failure.
		var failed_tall_tower_ids: Array = WarrenRoomCompositionPlanner.last_audit \
			.get("tall_tower_only_lineage_ids", []) as Array
		var annex_targets := WarrenRoomCompositionPlanner.last_audit.get(
			"tower_relief_annex_target_by_lineage", {}) as Dictionary
		for detail_value: Variant in WarrenRoomCompositionPlanner.last_audit.get(
			"overlong_tower_run_details", []) as Array:
			var detail := detail_value as Dictionary
			var lineage_id := StringName(detail.get("lineage_id", &""))
			if not lineage_id.is_empty() \
					and int(annex_targets.get(lineage_id, 0)) <= 0 \
					and lineage_id not in failed_tall_tower_ids:
				failed_tall_tower_ids.append(lineage_id)
		if not failed_tall_tower_ids.is_empty():
			last_preplan_market_diagnostic[
				"last_exact_court_tall_tower_failure"] = \
				failed_tall_tower_ids.duplicate()
		last_preplan_market_diagnostic[
			"last_exact_room_composition_failure"] = \
			WarrenRoomCompositionPlanner.last_failure
		return false
	if not WarrenRoomCompositionPlanner.lineages_are_supported(
			composition.lineages as Dictionary, grid):
		last_preplan_market_diagnostic[
			"last_exact_room_composition_failure"] = \
			"exact room preflight lost structural bearing"
		return false
	var tall_tower_ids := WarrenRoomCompositionPlanner.last_audit.get(
		"tall_tower_only_lineage_ids", []) as Array
	if not tall_tower_ids.is_empty():
		# This exact feature set has already determined the room composition.
		# The composition audit has discounted genuinely zig-zagging whole-room
		# steps; anything left here is still an unrelieved vertical extrusion.
		# Continue the bounded market/court frontier instead of hoping a late
		# decorative annex can disguise it.
		last_preplan_market_diagnostic[
			"last_exact_court_tall_tower_failure"] = tall_tower_ids.duplicate()
		return false
	if bool(court_candidate.get("optional_absent", false)):
		result["composition"] = composition
		result["recomposition_required"] = false
		return true
	var court_floors := _courtyard_floor_cells(volume)
	var court_side_mask := _composition_courtyard_side_mask(court_floors,
		composition, court_candidate.body as Dictionary)
	var court_side_count := _side_mask_count(court_side_mask)
	if court_side_count < WarrenSpatialFeatureSolver.MIN_COURT_SIDE_COUNT:
		last_preplan_market_diagnostic[
			"last_exact_court_composition_failure"] = {
				"side_count": court_side_count,
				"side_mask": court_side_mask,
			}
		return false
	var reservation := court_candidate.reservation as Dictionary
	var related_parcels := _skywalk_endpoint_owner_set(reservation)
	var feature_bounds: Array[AABB] = []
	for component_value: Variant in reservation.get("components", []):
		var component := component_value as Dictionary
		var feature_recipe := program.recipe(StringName(component.recipe_id))
		if feature_recipe == null:
			return false
		feature_bounds.append(FabricRecipe.lattice_transform(
			component.origin as Vector3i, int(component.yaw_quarters)) \
			* feature_recipe.local_clearance_bounds)
	var required_parcels := related_parcels.duplicate()
	for parcel_value: Variant in court_candidate.get(
			"macro_required_parcel_ids", []) as Array:
		required_parcels[StringName(parcel_value)] = true
	var market_backing_id := StringName(market.get("backing_parcel_id", &""))
	if not market_backing_id.is_empty():
		required_parcels[market_backing_id] = true
	for parcel_value: Variant in court_fixed_blocks_by_parcel.keys():
		required_parcels[StringName(parcel_value)] = true
	for skywalk: Dictionary in skywalk_reservations:
		for owner_value: Variant in skywalk.get("owner_parcel_ids", []):
			var owner_id := StringName(owner_value)
			if not String(owner_id).begins_with("spatial.feature.landmark."):
				required_parcels[owner_id] = true
	for owner_value: Variant in skywalk_plan.get(
			"landmark_transition_owner_ids", []):
		required_parcels[StringName(owner_value)] = true
	var displaced_parcels: Dictionary = initial_excluded_set.duplicate()
	var feature_clearance_displaced: Dictionary = \
		initial_feature_excluded_set.duplicate()
	var probe_result := _exact_composition_room_probes(composition, proposals,
		program, volume.world_seed, court_candidate, skywalk_reservations)
	if not bool(probe_result.get("valid", false)):
		if bool(probe_result.get("portal_failure", false)):
			last_preplan_market_diagnostic["last_exact_room_pair_failure"] = \
				probe_result.get("failure", "feature portal binding failed")
		return false
	var room_probes: Array[Dictionary] = []
	room_probes.assign(probe_result.get("probes", []) as Array)
	for record: Dictionary in room_probes:
		var room := record.room as WarrenRoomStamp
		var desired := record.desired as FabricRecipe
		var fallback := record.fallback as FabricRecipe
		# The court endpoint's own portal intentionally meets its authored bridge
		# component. All other rooms still prove clearance from both components.
		if not related_parcels.has(room.source_parcel_id) \
				and _room_recipe_overlaps_any_bounds(room.lattice_origin,
					room.yaw_quarters, desired, feature_bounds) \
				and _room_recipe_overlaps_any_bounds(room.lattice_origin,
					room.yaw_quarters, fallback, feature_bounds):
			if required_parcels.has(room.source_parcel_id):
				last_preplan_market_diagnostic[
					"last_exact_court_required_conflict"] = {
						"parcel": room.source_parcel_id,
						"storey": room.source_storey_index,
						"room_origin": room.lattice_origin,
						"desired_recipe": desired.recipe_id,
						"fallback_recipe": fallback.recipe_id,
					}
				return false
			displaced_parcels[room.source_parcel_id] = true
			feature_clearance_displaced[room.source_parcel_id] = true
	var room_pair_failure := _exact_room_pair_envelope_failure(grid, program,
		room_probes, displaced_parcels, required_parcels)
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING exact_room_pairs rooms=", room_probes.size(),
			" feature_displaced=", feature_clearance_displaced.keys(),
			" final_displaced=", displaced_parcels.keys(),
			" failure=", room_pair_failure)
	if not room_pair_failure.is_empty():
		last_preplan_market_diagnostic["last_exact_room_pair_failure"] = \
			room_pair_failure
		return false
	var displaced_ids: Array[StringName] = []
	displaced_ids.assign(displaced_parcels.keys())
	displaced_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	var feature_displaced_ids: Array[StringName] = []
	feature_displaced_ids.assign(feature_clearance_displaced.keys())
	feature_displaced_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	var room_pair_displaced_ids: Array[StringName] = []
	for displaced_id: StringName in displaced_ids:
		if not feature_clearance_displaced.has(displaced_id):
			room_pair_displaced_ids.append(displaced_id)
	court_candidate["excluded_parcel_ids"] = displaced_ids
	court_candidate["feature_clearance_displaced_parcel_ids"] = \
		feature_displaced_ids
	court_candidate["room_pair_displaced_parcel_ids"] = \
		room_pair_displaced_ids
	result["composition"] = composition
	result["recomposition_required"] = initial_excluded_ids != displaced_ids
	return true


static func _exact_composition_room_probes(composition: Dictionary,
		proposals: Array[Dictionary], program: SettlementFabricProgram,
		world_seed: int, court_candidate: Dictionary,
		skywalk_reservations: Array[Dictionary],
		skip_parcels: Dictionary = {}) -> Dictionary:
	## Rebuild the exact compile-time room stamps and their measured recipe
	## choices for a sealed composition. The exact court preflight and the sealed
	## hero-feature occluder ranking share this so both always see the same rooms
	## and recipes the final compiler will construct.
	var room_probes: Array[Dictionary] = []
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		if skip_parcels.has(parcel.stable_id):
			continue
		var lineage := (composition.lineages as Dictionary).get(
			parcel.stable_id, {}) as Dictionary
		if lineage.is_empty():
			continue
		var proposal_origin := proposal.origin as Vector3i
		var threshold := WarrenParcelConstruction.threshold_cell(parcel)
		var lineage_blocks := lineage.blocks as Array[Dictionary]
		for block_index in lineage_blocks.size():
			var block := lineage_blocks[block_index]
			for storey in range(int(block.start_storey),
					int(block.end_storey)):
				var room_origin := Vector3i((block.origin as Vector3i).x,
					proposal_origin.y + storey \
						* WarrenSpatialGrid.STOREY_CELLS,
					(block.origin as Vector3i).z)
				var addressed := threshold.y >= proposal_origin.y \
					+ storey * WarrenSpatialGrid.STOREY_CELLS \
					and threshold.y < proposal_origin.y \
						+ (storey + 1) * WarrenSpatialGrid.STOREY_CELLS
				var room_door_phase := WarrenParcelConstruction \
					.address_door_phase_for_room(StringName(block.kind), room_origin,
						int(block.yaw_quarters), threshold,
						Vector3i(parcel.frontage_direction.x, 0,
							parcel.frontage_direction.y)) if addressed else 0
				if addressed and room_door_phase < 0:
					return {"valid": false, "portal_failure": false,
						"failure": "recomposed room lost its exact threshold"}
				var building_id := StringName("spatial.%s.part%02d" % [
					parcel.stable_id, block_index])
				var room := WarrenRoomStamp.new(StringName(
					"%s.room%02d" % [building_id,
						storey - int(block.start_storey)]),
					parcel.stable_id, StringName(block.kind), room_origin,
					int(block.yaw_quarters), storey,
					storey == 0 and not block.has(
						"support_parent_lineage_id"), addressed,
					threshold if addressed else Vector3i(2147483647,
						2147483647, 2147483647),
					Vector3i(parcel.frontage_direction.x, 0,
						parcel.frontage_direction.y), int(proposal.roof_feature),
					&"", -1, room_door_phase)
				if not room.add_private_cells(
						WarrenRoomStamp.expected_private_cells(
							StringName(block.kind), room_origin,
							int(block.yaw_quarters))):
					return {"valid": false, "portal_failure": false,
						"failure": "room stamp cells could not be recorded"}
				room_probes.append({"room": room, "building_id": building_id})
	var portal_result := _exact_preflight_feature_portal_masks(room_probes,
		court_candidate, skywalk_reservations)
	if not bool(portal_result.get("valid", false)):
		return {"valid": false, "portal_failure": true,
			"failure": String(portal_result.get("failure",
				"feature portal binding failed"))}
	var portal_masks := portal_result.get("masks", {}) as Dictionary
	for record: Dictionary in room_probes:
		var room := record.room as WarrenRoomStamp
		var feature_portal_mask := int(portal_masks.get(room.stable_id, 0))
		var desired := program.recipe(
			WarrenSpatialFabricCompiler._room_recipe_id(room,
				world_seed, true, feature_portal_mask))
		var fallback := program.recipe(
			WarrenSpatialFabricCompiler._room_recipe_id(room,
				world_seed, false, feature_portal_mask))
		if desired == null or fallback == null:
			return {"valid": false, "portal_failure": false,
				"failure": "composed room has no measured recipe"}
		record["desired"] = desired
		record["fallback"] = fallback
	return {"valid": true, "portal_failure": false, "probes": room_probes}


static func _sealed_recipe_occluder_route_coverage(
		room_probes: Array[Dictionary],
		feature_reservations: Array[Dictionary],
		program: SettlementFabricProgram,
		route_walk: Dictionary) -> Dictionary:
	## Selection objective for the hero-feature frontier: canonical route cells
	## covered two to six fine bands above by the exact room-tagged recipe
	## occluders the final compiler will place. This mirrors the occupied-
	## overhead test of SettlementFabricSolver._audit_enclosure on the sealed
	## preflight composition; the final fabric audit remains authoritative.
	var occupied: Dictionary = {}
	for record: Dictionary in room_probes:
		var room := record.room as WarrenRoomStamp
		var desired := record.get("desired") as FabricRecipe
		if desired == null or not desired.has_tag(&"room"):
			continue
		for local: Vector3i in desired.occluder_cells:
			occupied[FabricRecipe.transform_cell(local, room.lattice_origin,
				room.yaw_quarters)] = true
	for reservation: Dictionary in feature_reservations:
		for component_value: Variant in reservation.get("components", []) as Array:
			var component := component_value as Dictionary
			var recipe := program.recipe(StringName(component.recipe_id))
			if recipe == null or not recipe.has_tag(&"room"):
				continue
			for local: Vector3i in recipe.occluder_cells:
				occupied[FabricRecipe.transform_cell(local,
					component.origin as Vector3i,
					int(component.yaw_quarters))] = true
	var covered := 0
	for cell_value: Variant in route_walk:
		var cell := cell_value as Vector3i
		for rise in range(2, 7):
			if occupied.has(cell + Vector3i(0, rise, 0)):
				covered += 1
				break
	return {"covered_route_cell_count": covered,
		"route_cell_count": route_walk.size()}


static func _exact_preflight_feature_portal_masks(
		room_probes: Array[Dictionary], court_candidate: Dictionary,
		skywalk_reservations: Array[Dictionary]) -> Dictionary:
	## Resolve the same room-face portal masks that final feature commitment will
	## record. Measured portal shells can have a different clearance envelope from
	## their closed facade, so testing an ordinary recipe here would make the
	## feature beam accept a state that the final compiler must reject.
	var room_by_id: Dictionary = {}
	var rooms_by_parcel: Dictionary = {}
	for record: Dictionary in room_probes:
		var room := record.get("room") as WarrenRoomStamp
		if room == null:
			return {"valid": false, "failure": "room preflight lacks a stamp"}
		room_by_id[room.stable_id] = room
		if not rooms_by_parcel.has(room.source_parcel_id):
			rooms_by_parcel[room.source_parcel_id] = \
				[] as Array[WarrenRoomStamp]
		(rooms_by_parcel[room.source_parcel_id] \
			as Array[WarrenRoomStamp]).append(room)
	var reservations: Array[Dictionary] = []
	if not bool(court_candidate.get("optional_absent", false)):
		reservations.append(court_candidate.get("reservation", {}) as Dictionary)
	reservations.append_array(skywalk_reservations)
	var masks: Dictionary = {}
	for reservation: Dictionary in reservations:
		var owner_ids := reservation.get("owner_parcel_ids", []) as Array
		var endpoints := reservation.get("owner_endpoints", []) as Array
		if owner_ids.size() != endpoints.size() or owner_ids.is_empty():
			return {"valid": false,
				"failure": "feature endpoint owners differ from endpoint cells"}
		for endpoint_index in owner_ids.size():
			var owner_id := StringName(owner_ids[endpoint_index])
			if String(owner_id).begins_with("spatial.feature.landmark."):
				continue
			var endpoint := endpoints[endpoint_index] as Dictionary
			var endpoint_cell := endpoint.get("cell", Vector3i(2147483647,
				2147483647, 2147483647)) as Vector3i
			var endpoint_facing := endpoint.get("facing",
				Vector3i.ZERO) as Vector3i
			var matches: Array[WarrenRoomStamp] = []
			for room: WarrenRoomStamp in (rooms_by_parcel.get(owner_id,
					[] as Array[WarrenRoomStamp]) as Array[WarrenRoomStamp]):
				if room.has_private_cell(endpoint_cell):
					matches.append(room)
			if matches.size() != 1:
				return {"valid": false,
					"failure": "feature endpoint %s/%s resolves to %d rooms" % [
						owner_id, endpoint_cell, matches.size()]}
			var room := matches[0]
			if not WarrenSpatialFabricCompiler._record_feature_portal(masks,
					room_by_id, room.stable_id, endpoint_cell, endpoint_facing):
				return {"valid": false,
					"failure": WarrenSpatialFabricCompiler.last_failure}
	return {"valid": true, "masks": masks}


static func _exact_room_pair_envelope_failure(grid: WarrenSpatialGrid,
		program: SettlementFabricProgram, room_probes: Array[Dictionary],
		displaced_parcels: Dictionary,
		required_parcels: Dictionary = {}) -> String:
	## Mirror the room compiler's measured phase-A/phase-B transaction while the
	## landmark/court beam can still choose another candidate.  The older preflight
	## checked rooms only against the court components; an embedded landmark could
	## therefore force two unrelated upper shells into one another, pass the beam,
	## and fail only after every alternative had been discarded.
	var ordered := room_probes.duplicate(true) as Array[Dictionary]
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := a.room as WarrenRoomStamp
		var right := b.room as WarrenRoomStamp
		if left.lattice_origin.y != right.lattice_origin.y:
			return left.lattice_origin.y < right.lattice_origin.y
		if left.source_storey_index != right.source_storey_index:
			return left.source_storey_index < right.source_storey_index
		return String(left.stable_id) < String(right.stable_id))
	# `program` and `grid` remain explicit inputs because this preflight belongs to
	# the same measured construction transaction, but it must not call
	# SettlementFabricPlan.add_unit(): at this stage bearing parents have not yet
	# been committed. Support is proved by the sealed support DAG later; here we
	# compare only authored visual envelopes and exact room-to-room seam facts.
	if grid == null or program == null:
		return "missing exact room-pair construction context"
	if displaced_parcels.size() > 6:
		return "room-pair clearance would displace more than six parcels"
	var prior_unit_by_cell: Dictionary = {}
	var prior_records: Dictionary = {}
	for record: Dictionary in ordered:
		var room := record.room as WarrenRoomStamp
		if displaced_parcels.has(room.source_parcel_id):
			continue
		var desired := record.desired as FabricRecipe
		var fallback := record.fallback as FabricRecipe
		var desired_bounds := FabricRecipe.lattice_transform(
			room.lattice_origin, room.yaw_quarters) \
			* desired.local_clearance_bounds
		# This preflight runs before recomposed PRIVATE_VOLUME cells and their
		# PARTY_WALL faces are committed to the grid. Recover that future typed
		# seam losslessly from the exact room stamps: face-adjacent occupied cells
		# are a real shared wall/bearing plane. Diagonal or merely nearby rooms do
		# not enter this set, so the detached upper-shell collision that motivated
		# the gate remains unrelated and is still rejected.
		var seam_set: Dictionary = {}
		for cell: Vector3i in room.private_cells:
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
					Vector3i.BACK]:
				var prior_id := StringName(prior_unit_by_cell.get(
					cell + direction, &""))
				if not prior_id.is_empty():
					seam_set[prior_id] = true
		var edge_offsets: Array[Vector3i] = []
		for first_axis in 3:
			for second_axis in range(first_axis + 1, 3):
				for first_sign in [-1, 1]:
					for second_sign in [-1, 1]:
						var offset := Vector3i.ZERO
						offset[first_axis] = first_sign
						offset[second_axis] = second_sign
						edge_offsets.append(offset)
		for cell: Vector3i in room.private_cells:
			for offset: Vector3i in edge_offsets:
				var prior_id := StringName(prior_unit_by_cell.get(
					cell + offset, &""))
				if prior_id.is_empty() or seam_set.has(prior_id):
					continue
				var prior_record := prior_records.get(prior_id, {}) as Dictionary
				if not prior_record.is_empty() \
						and SettlementFabricPlan._aabb_overlaps_volume(
							desired_bounds, prior_record.bounds as AABB) \
						and SettlementFabricPlan._is_edge_nick(
							desired_bounds, prior_record.bounds as AABB):
					seam_set[prior_id] = true
		var unit_id := StringName("spatial.fabric.%s" % room.stable_id)
		var desired_rejection := _room_pair_bounds_rejection(unit_id,
			desired_bounds, seam_set, prior_records)
		var selected_recipe := desired
		var selected_bounds := desired_bounds
		if not desired_rejection.is_empty():
			if fallback.recipe_id == desired.recipe_id:
				var displaced := _displace_optional_room_pair_parcel(room,
					desired_rejection, prior_records, displaced_parcels,
					required_parcels)
				if displaced.is_empty():
					return "room %s: %s" % [room.stable_id,
						_room_pair_rejection_text(desired_rejection)]
				return _exact_room_pair_envelope_failure(grid, program,
					room_probes, displaced_parcels, required_parcels)
			selected_bounds = FabricRecipe.lattice_transform(
				room.lattice_origin, room.yaw_quarters) \
				* fallback.local_clearance_bounds
			var fallback_rejection := _room_pair_bounds_rejection(unit_id,
				selected_bounds, seam_set, prior_records)
			if not fallback_rejection.is_empty():
				var displaced := _displace_optional_room_pair_parcel(room,
					fallback_rejection, prior_records, displaced_parcels,
					required_parcels)
				if displaced.is_empty():
					return "room %s desired=%s fallback=%s" % [room.stable_id,
						_room_pair_rejection_text(desired_rejection),
						_room_pair_rejection_text(fallback_rejection)]
				return _exact_room_pair_envelope_failure(grid, program,
					room_probes, displaced_parcels, required_parcels)
			selected_recipe = fallback
		prior_records[unit_id] = {"recipe_id": selected_recipe.recipe_id,
			"bounds": selected_bounds,
			"source_parcel_id": room.source_parcel_id}
		for cell: Vector3i in room.private_cells:
			prior_unit_by_cell[cell] = unit_id
	return ""


static func _room_pair_bounds_rejection(unit_id: StringName, bounds: AABB,
		seam_ids: Dictionary, prior_records: Dictionary) -> Dictionary:
	var prior_ids: Array[StringName] = []
	prior_ids.assign(prior_records.keys())
	prior_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for prior_id: StringName in prior_ids:
		if seam_ids.has(prior_id):
			continue
		var prior := prior_records[prior_id] as Dictionary
		var prior_bounds := prior.bounds as AABB
		if SettlementFabricPlan._aabb_overlaps_volume(bounds, prior_bounds):
			return {"unit_id": unit_id, "bounds": bounds,
				"prior_id": prior_id, "prior_bounds": prior_bounds}
	return {}


static func _room_pair_rejection_text(rejection: Dictionary) -> String:
	if rejection.is_empty():
		return ""
	return "visual envelope of %s %s intersects unrelated unit %s %s" % [
		rejection.unit_id, rejection.bounds, rejection.prior_id,
		rejection.prior_bounds]


static func _displace_optional_room_pair_parcel(room: WarrenRoomStamp,
		rejection: Dictionary, prior_records: Dictionary,
		displaced_parcels: Dictionary, required_parcels: Dictionary) -> StringName:
	## A full optional parcel may yield, never an individual storey or mesh. This
	## keeps the structural/support transaction coherent while allowing the dense
	## packer to reject one bad neighbor relation instead of abandoning an
	## otherwise valid embedded landmark district.
	var current_parcel := room.source_parcel_id
	var prior := prior_records.get(StringName(rejection.prior_id), {}) \
		as Dictionary
	var prior_parcel := StringName(prior.get("source_parcel_id", &""))
	var chosen := &""
	if not required_parcels.has(current_parcel):
		chosen = current_parcel
	elif not prior_parcel.is_empty() and not required_parcels.has(prior_parcel):
		chosen = prior_parcel
	if chosen.is_empty():
		return &""
	displaced_parcels[chosen] = true
	return chosen


static func _room_recipe_overlaps_any_bounds(origin: Vector3i, yaw: int,
		recipe: FabricRecipe, other_bounds: Array[AABB]) -> bool:
	var bounds := FabricRecipe.lattice_transform(origin, yaw) \
		* recipe.local_clearance_bounds
	for other: AABB in other_bounds:
		if SettlementFabricPlan._aabb_overlaps_volume(bounds, other):
			return true
	return false


static func _scale_profile_for_volume(volume: WarrenVolumePlan) \
		-> WarrenVillageScaleProfile:
	if volume == null:
		return null
	return WarrenVillageScaleProfile.for_id(StringName(volume.mass_context.get(
		&"scale_profile_id", WarrenVillageScaleProfile.LARGE)))


static func _reserve_market_preplan(grid: WarrenSpatialGrid,
		market: Dictionary) -> bool:
	var feature_id := StringName(market.feature_id)
	var body: Array[Vector3i] = []
	body.assign((market.reserved_cells as Dictionary).keys())
	var clearance_only: Array[Vector3i] = []
	for cell_value: Variant in (market.visual_clearance_cells \
			as Dictionary).keys():
		if not (market.reserved_cells as Dictionary).has(cell_value):
			clearance_only.append(cell_value as Vector3i)
	var public_cells: Array[Vector3i] = []
	public_cells.assign((market.public_cells as Dictionary).keys())
	var new_air: Dictionary = {}
	for floor: Vector3i in public_cells:
		for y_offset in WarrenVolumePlan.HEADROOM_BANDS:
			var air := floor + Vector3i.UP * y_offset
			if grid.use_at(air) != WarrenSpatialGrid.Use.PUBLIC_AIR:
				new_air[air] = true
	var new_air_cells: Array[Vector3i] = []
	new_air_cells.assign(new_air.keys())
	var bearing_cells: Array[Vector3i] = []
	bearing_cells.assign((market.bearing_cells as Dictionary).keys())
	var tx := grid.begin_transaction(feature_id)
	if not tx.reserve(body, WarrenSpatialGrid.Reservation.FEATURE \
			| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not new_air_cells.is_empty() and (not tx.require_use(new_air_cells,
				[WarrenSpatialGrid.Use.OUTSIDE,
					WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
				or not tx.reserve(new_air_cells,
					WarrenSpatialGrid.Reservation.PUBLIC_CLEARANCE, feature_id) \
				or not tx.assign_use(new_air_cells,
					WarrenSpatialGrid.Use.PUBLIC_AIR, feature_id)) \
			or not clearance_only.is_empty() and not tx.reserve(clearance_only,
				WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not tx.reserve(public_cells,
				WarrenSpatialGrid.Reservation.CONSTRUCTION_SEAM, feature_id) \
			or not tx.reserve(bearing_cells,
				WarrenSpatialGrid.Reservation.TERRAIN_BEARING, feature_id):
		return false
	for floor: Vector3i in public_cells:
		var existing := grid.face_claim(floor, Vector3i.DOWN)
		if existing.is_empty() and not tx.claim_face(floor, Vector3i.DOWN,
				WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR, feature_id):
			return false
	return tx.commit()


static func _yaw_for_direction(local_direction: Vector3i,
		target_direction: Vector3i) -> int:
	for yaw in 4:
		if FabricRecipe.transform_direction(local_direction, yaw) \
				== target_direction:
			return yaw
	return -1


static func _cells_fit_grid(grid: WarrenSpatialGrid, cells: Dictionary) -> bool:
	for cell_value: Variant in cells.keys():
		if not grid.contains(cell_value as Vector3i):
			return false
	return true


static func _market_public_aisle(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, origin: Vector3i, yaw: int,
		covered_local_cells: Array[Vector3i], body: Dictionary,
		protected_owners: Dictionary,
		backing_parcel_id: StringName) -> Dictionary:
	## The four central cells are the browsable space beneath the canopy. When
	## that bay does not directly meet two lanes of one route episode, extend a
	## short two-cell-wide negative-space throat. This keeps the market atomic and
	## player-width without requiring the macro route to land on one exact phase.
	var covered: Dictionary = {}
	for local_cell: Vector3i in covered_local_cells:
		covered[FabricRecipe.transform_cell(local_cell, origin, yaw)] = true
	var directions: Array[Vector3i] = [Vector3i.BACK, Vector3i.RIGHT,
		Vector3i.LEFT, Vector3i.FORWARD]
	for extension_length in range(_market_aisle_extension_limit(volume) + 1):
		var direction_count := 1 if extension_length == 0 else directions.size()
		for direction_index in direction_count:
			var cells := covered.duplicate()
			if extension_length > 0:
				var local_direction := directions[direction_index]
				for step in range(1, extension_length + 1):
					var row: Array[Vector3i] = []
					if local_direction == Vector3i.BACK:
						row = [Vector3i(-1, 0, step), Vector3i(0, 0, step)]
					elif local_direction == Vector3i.FORWARD:
						row = [Vector3i(-1, 0, -1 - step),
							Vector3i(0, 0, -1 - step)]
					elif local_direction == Vector3i.RIGHT:
						row = [Vector3i(step, 0, -1), Vector3i(step, 0, 0)]
					else:
						row = [Vector3i(-1 - step, 0, -1),
							Vector3i(-1 - step, 0, 0)]
					for local_cell: Vector3i in row:
						cells[FabricRecipe.transform_cell(local_cell, origin,
							yaw)] = true
			if not _market_aisle_cells_fit(grid, volume, cells, body,
					protected_owners, backing_parcel_id):
				continue
			var entrance := _market_street_connection(volume, grid, cells)
			if int(entrance.max_episode_width) < 2:
				continue
			var new_public_count := 0
			for cell_value: Variant in cells.keys():
				new_public_count += int(grid.use_at(cell_value as Vector3i) \
					!= WarrenSpatialGrid.Use.PUBLIC_AIR)
			return {"cells": cells, "covered_cells": covered,
				"new_public_cell_count": new_public_count,
				"entrance_edge_count": int(entrance.edge_count),
				"entrance_width": int(entrance.max_episode_width),
				"extension_length": extension_length}
	return {}


static func _market_aisle_extension_limit(volume: WarrenVolumePlan) -> int:
	## A market remains one atomic covered chamber, but larger towns may reach it
	## through a longer two-lane alley cut from the inhabited mass. The extension
	## is still exact public floor/headroom and is evaluated by the same shelter
	## rays; it is not an open plaza or a decorative platform.
	var profile := _scale_profile_for_volume(volume)
	if profile == null:
		return 3
	match profile.scale_id:
		WarrenVillageScaleProfile.LARGE:
			return 5
		WarrenVillageScaleProfile.GRAND:
			return 6
		_:
			return 3


static func _market_aisle_cells_fit(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, cells: Dictionary, body: Dictionary,
		protected_owners: Dictionary,
		backing_parcel_id: StringName) -> bool:
	for value: Variant in cells.keys():
		var cell := value as Vector3i
		var upper := cell + Vector3i.UP
		var use_value := grid.use_at(cell)
		var upper_use := grid.use_at(upper)
		if body.has(cell) or body.has(upper) or use_value not in [
				WarrenSpatialGrid.Use.OUTSIDE,
				WarrenSpatialGrid.Use.ALLOCATABLE] or upper_use not in [
				WarrenSpatialGrid.Use.OUTSIDE,
				WarrenSpatialGrid.Use.ALLOCATABLE] \
				or (protected_owners.get(cell, {}) as Dictionary).has(
					backing_parcel_id) \
				or (protected_owners.get(upper, {}) as Dictionary).has(
					backing_parcel_id) \
				or (grid.reservation_bits_at(cell) \
					| grid.reservation_bits_at(upper)) & (
						WarrenSpatialGrid.Reservation.FEATURE \
						| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE) != 0:
			return false
		var column := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		if not volume.envelope.contains_column(column) \
				or volume.envelope.ground_at(column) != cell.y:
			return false
	return true


static func _market_street_connection(volume: WarrenVolumePlan,
		grid: WarrenSpatialGrid, market_cells: Dictionary) -> Dictionary:
	var episode_owners: Dictionary = {}
	for index in volume.walk_cells.size():
		var owner_id := StringName("walk.%02d" % index)
		for cell: Vector3i in _fine_square(volume.walk_cells[index]):
			if not episode_owners.has(cell):
				episode_owners[cell] = [] as Array[StringName]
			(episode_owners[cell] as Array[StringName]).append(owner_id)
	for index in volume.transitions.size():
		var transition := volume.transitions[index]
		if not transition.is_vertical():
			continue
		var owner_id := StringName("transition.%02d" % index)
		for cell: Vector3i in transition.surface_cells():
			if not episode_owners.has(cell):
				episode_owners[cell] = [] as Array[StringName]
			(episode_owners[cell] as Array[StringName]).append(owner_id)
	var seams_by_episode: Dictionary = {}
	var edge_count := 0
	for cell_value: Variant in market_cells.keys():
		var cell := cell_value as Vector3i
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if market_cells.has(neighbor) \
					or grid.use_at(neighbor) != WarrenSpatialGrid.Use.PUBLIC_AIR:
				continue
			var floor := grid.face_claim(neighbor, Vector3i.DOWN)
			if floor.is_empty() or int(floor.kind) \
					!= WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
				continue
			edge_count += 1
			for owner_id: StringName in episode_owners.get(neighbor,
					[] as Array[StringName]):
				if not seams_by_episode.has(owner_id):
					seams_by_episode[owner_id] = {}
				(seams_by_episode[owner_id] as Dictionary)["%s>%s" % [cell,
					neighbor]] = true
	var max_width := 0
	for seams_value: Variant in seams_by_episode.values():
		max_width = maxi(max_width, (seams_value as Dictionary).size())
	return {"edge_count": edge_count, "max_episode_width": max_width}


static func _preplan_spatial_skywalks(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, proposals: Array[Dictionary],
		program: SettlementFabricProgram, protected_owners: Dictionary,
		target_count: int, court_bridge_candidate_count: int = 0) -> Dictionary:
	## Bounded feature-set search over exact measured straight-link contracts.
	## Unlike the retired late detail pass, candidates may displace unrelated
	## generic rooms; the endpoint composition blocks and bridge void are fixed
	## before `_partition_rooms` commits any private volume.
	var stage_started := Time.get_ticks_msec()
	var parcels: Array[WarrenBuildingParcel] = []
	var proposal_by_slot: Dictionary = {}
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		parcels.append(parcel)
		proposal_by_slot[parcel.slot_signature()] = proposal
	var court_fixed_blocks_by_parcel: Dictionary = {}
	var court_neighbors := _courtyard_neighbor_cells(
		_courtyard_floor_cells(volume))
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		var fixed := _proposal_court_fixed_blocks(proposal, court_neighbors)
		if not fixed.is_empty():
			court_fixed_blocks_by_parcel[parcel.stable_id] = fixed
	var realm := WarrenVolumePublicRealmAdapter.from_volume(volume)
	if realm == null:
		return {}
	var public_air := realm.air_claims()
	var cache := WarrenAssetCompiler.massif_partition_asset_cache(parcels,
		volume.world_seed, program)
	if not bool(cache.get(&"enabled", false)):
		return {}
	var candidates: Array[Dictionary] = []
	var forced_block_cache: Dictionary = {}
	var corner_reservation_cache: Dictionary = {}
	var raw_count := 0
	var corner_raw_count := 0
	var corner_summaries: Array[Dictionary] = []
	var corner_upper_block_count := 0
	var corner_forced_fit_count := 0
	var corner_body_fit_count := 0
	var corner_route_cover_count := 0
	var upper_block_count := 0
	var forced_fit_count := 0
	var body_fit_count := 0
	var route_cover_count := 0
	for left_index in parcels.size():
		var left := parcels[left_index]
		for right_index in range(left_index + 1, parcels.size()):
			var right := parcels[right_index]
			if not WarrenAssetCompiler.parcels_may_form_skywalk(left, right,
					program, cache):
				continue
			var left_endpoints := WarrenAssetCompiler._parcel_room_endpoints(left,
				program, cache)
			var right_endpoints := WarrenAssetCompiler._parcel_room_endpoints(right,
				program, cache)
			for left_endpoint: Dictionary in left_endpoints:
				for right_endpoint: Dictionary in right_endpoints:
					var left_proposal := proposal_by_slot[left.slot_signature()] \
						as Dictionary
					var right_proposal := proposal_by_slot[right.slot_signature()] \
						as Dictionary
					var left_block := _proposal_block_for_cell(left_proposal,
						left_endpoint.cell as Vector3i)
					var right_block := _proposal_block_for_cell(right_proposal,
						right_endpoint.cell as Vector3i)
					var corner_result := _shifted_corner_skywalk_candidates(grid,
						left, right, left_proposal, right_proposal,
						left_endpoint, right_endpoint, left_block, right_block,
						program, protected_owners, public_air, volume.world_seed,
						forced_block_cache, corner_reservation_cache)
					var corner_candidates := corner_result.get("candidates", []) \
						as Array[Dictionary]
					if not corner_candidates.is_empty():
						candidates.append_array(corner_candidates)
					corner_upper_block_count += int(corner_result.get(
						"upper_pair_count", 0))
					corner_forced_fit_count += int(corner_result.get(
						"forced_fit_count", 0))
					corner_body_fit_count += int(corner_result.get(
						"body_fit_count", 0))
					corner_route_cover_count += int(corner_result.get(
						"route_cover_count", 0))
					var raw := _raw_straight_skywalk_reservation(left,
						right, left_endpoint, right_endpoint, program, public_air)
					if raw.is_empty():
						continue
					raw_count += 1
					candidates.append_array(_stationary_skywalk_candidates(grid,
						raw, left, right, left_proposal, right_proposal,
						left_endpoint, right_endpoint, left_block, right_block,
						protected_owners, public_air, volume.world_seed))
					# A shifted base block would no longer bear on immutable terrain.
					# Both endpoints therefore live in true upper composition blocks.
					if left_block <= 0 or right_block <= 0:
						continue
					upper_block_count += 1
					var facing := left_endpoint.facing as Vector3i
					var perpendicular := Vector3i(-facing.z, 0, facing.x)
					for sign_value in [-1, 1]:
						var delta3 := perpendicular * int(sign_value)
						var delta := Vector2i(delta3.x, delta3.z)
						if not _forced_block_fits(grid, left_proposal,
								left_block, delta) \
								or not _forced_block_fits(grid, right_proposal,
									right_block, delta):
							continue
						forced_fit_count += 1
						var left_plate := _forced_block_cells(left_proposal,
							left_block, delta)
						var right_plate := _forced_block_cells(right_proposal,
							right_block, delta)
						if _sets_overlap(left_plate, right_plate):
							continue
						var shifted := _translate_skywalk_reservation(raw,
							delta3)
						var body := shifted.reserved_cells as Dictionary
						var clearance := shifted.visual_clearance_cells as Dictionary
						if not _skywalk_body_fits_grid(grid, body) \
								or not _skywalk_clearance_fits_grid(grid, clearance) \
								or not _skywalk_clearance_fits_protected(clearance,
									protected_owners):
							continue
						if _sets_overlap(body, left_plate) \
								or _sets_overlap(body, right_plate):
							continue
						body_fit_count += 1
						var lower_cover := _lower_public_cover(body, public_air)
						if lower_cover < 2:
							continue
						route_cover_count += 1
						var blockers := _skywalk_blocker_count(clearance,
							protected_owners, {left.stable_id: true,
								right.stable_id: true})
						var forced: Dictionary = {
							left.stable_id: {left_block: delta},
							right.stable_id: {right_block: delta},
						}
						var priority_cells: Dictionary = {}
						for value: Variant in left_plate.keys():
							priority_cells[value] = left.stable_id
						for value: Variant in right_plate.keys():
							priority_cells[value] = right.stable_id
						shifted["owner_parcel_ids"] = [left.stable_id,
							right.stable_id]
						var endpoint_pair_key := _skywalk_endpoint_pair_key(shifted)
						candidates.append({"reservation": shifted,
							"body": body, "clearance": clearance,
							"forced_offsets": forced,
							"priority_cells": priority_cells,
							"pair_key": "%s|%s" % [left.stable_id,
								right.stable_id],
							"endpoint_pair_key": endpoint_pair_key,
							"blocker_count": blockers,
							"lower_cover": lower_cover,
							"tie": posmod(Helper._mix64(volume.world_seed \
								^ String(left.stable_id).hash() \
								^ String(right.stable_id).hash() \
								^ int(sign_value) * 0x45d9f3b \
								^ (left_endpoint.cell as Vector3i).y * 17),
								1000003)})
			var corner_raw := WarrenAssetCompiler._corner_skywalk_reservation(
				left, right, program, public_air, cache)
			if not corner_raw.is_empty():
				corner_raw_count += 1
				corner_summaries.append({
					"pair_key": "%s|%s" % [left.stable_id, right.stable_id],
					"endpoint_pair_key": _skywalk_endpoint_pair_key(corner_raw),
					"origin": corner_raw.origin,
					"reserved_cell_count": (corner_raw.reserved_cells \
						as Dictionary).size(),
				})
	var fixed_block_rejection_count := 0
	var fixed_block_candidates: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		if _skywalk_candidate_respects_fixed_blocks(candidate, proposal_by_slot,
				court_fixed_blocks_by_parcel):
			fixed_block_candidates.append(candidate)
		else:
			fixed_block_rejection_count += 1
	candidates = fixed_block_candidates
	var pre_structural_dedup_count := candidates.size()
	candidates.sort_custom(_skywalk_candidate_less)
	candidates = _unique_skywalk_structural_candidates(candidates)
	var structural_duplicate_count := pre_structural_dedup_count \
		- candidates.size()
	var candidate_generation_ms := Time.get_ticks_msec() - stage_started
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING baseline_generate ms=", candidate_generation_ms,
			" candidates=", candidates.size())
	if diagnostic_stop_after_skywalk_candidates:
		last_preplan_skywalk_diagnostic = {
			"raw_straight_count": raw_count,
			"raw_corner_count": corner_raw_count,
			"courtyard_bridge_candidate_count": court_bridge_candidate_count,
			"generated_candidate_count": candidates.size() \
				+ fixed_block_rejection_count,
			"fixed_block_rejection_count": fixed_block_rejection_count,
			"structural_duplicate_candidate_count":
				structural_duplicate_count,
			"pre_individual_candidate_count": candidates.size(),
			"courtyard_fixed_block_count": _nested_dictionary_entry_count(
				court_fixed_blocks_by_parcel),
			"candidate_generation_ms": candidate_generation_ms,
		}
		return {"reservations": [] as Array[Dictionary],
			"forced_offsets": {}, "priority_cells": {},
			"candidate_count": 0, "candidate_corpus": [] as Array[Dictionary],
			"public_air": public_air}
	var individual_rejection_count := 0
	var individual_rejection_failures: Dictionary = {}
	var individually_viable: Array[Dictionary] = []
	var individual_started := Time.get_ticks_msec()
	var individual_limit := candidates.size()
	if diagnostic_skywalk_candidate_limit >= 0:
		individual_limit = mini(individual_limit,
			diagnostic_skywalk_candidate_limit)
	for candidate_index in individual_limit:
		var candidate := candidates[candidate_index]
		if _skywalk_selection_preserves_endpoint_rooms(grid, volume,
				[candidate] as Array[Dictionary], proposals, protected_owners,
				volume.world_seed):
			individually_viable.append(candidate)
		else:
			individual_rejection_count += 1
			individual_rejection_failures[_last_skywalk_selection_failure] = int(
				individual_rejection_failures.get(
					_last_skywalk_selection_failure, 0)) + 1
	var individual_validation_ms := Time.get_ticks_msec() - individual_started
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING baseline_individual total_ms=",
			Time.get_ticks_msec() - stage_started, " stage_ms=",
			individual_validation_ms, " viable=", individually_viable.size())
	if diagnostic_stop_after_skywalk_individual:
		last_preplan_skywalk_diagnostic = {
			"raw_straight_count": raw_count,
			"raw_corner_count": corner_raw_count,
			"generated_candidate_count": candidates.size()
				+ fixed_block_rejection_count,
			"fixed_block_rejection_count": fixed_block_rejection_count,
			"structural_duplicate_candidate_count":
				structural_duplicate_count,
			"pre_individual_candidate_count": candidates.size(),
			"courtyard_fixed_block_count": _nested_dictionary_entry_count(
				court_fixed_blocks_by_parcel),
			"candidate_generation_ms": candidate_generation_ms,
			"individual_validated_count": individual_limit,
			"individual_viable_count": individually_viable.size(),
			"individual_validation_ms": individual_validation_ms,
			"individual_candidate_rejection_count": individual_rejection_count,
			"individual_candidate_rejection_failures":
				individual_rejection_failures,
		}
		return {"reservations": [] as Array[Dictionary],
			"forced_offsets": {}, "priority_cells": {},
			"candidate_count": 0,
			"candidate_corpus": [] as Array[Dictionary],
			"public_air": public_air}
	candidates = individually_viable
	candidates.sort_custom(_skywalk_candidate_less)
	# Build a bounded progressive beam. Pair survival is materially cheaper than
	# trying every triple and keeps candidates from one dense corner from crowding
	# all three slots; the third member may come from the complete finite corpus.
	var primary_frontier_size := mini(candidates.size(), 64)
	const MAX_PAIR_FRONTIER := 128
	const MAX_PAIRS_PER_FIRST := 4
	var selected: Array[Dictionary] = []
	var endpoint_survival_rejection_count := 0
	var endpoint_survival_failures: Dictionary = {}
	if target_count == 1 and not candidates.is_empty():
		selected.append(candidates[0])
	elif target_count >= 2:
		var pair_frontier: Array[Vector2i] = []
		var stop_pairs := false
		for first in primary_frontier_size:
			var accepted_for_first := 0
			for second in candidates.size():
				if second == first:
					continue
				if not _skywalk_candidates_compatible(candidates[first],
						candidates[second]):
					continue
				var pair := [candidates[first], candidates[second]] \
					as Array[Dictionary]
				if not _skywalk_selection_preserves_endpoint_rooms(grid, volume,
						pair, proposals, protected_owners, volume.world_seed):
					endpoint_survival_rejection_count += 1
					endpoint_survival_failures[_last_skywalk_selection_failure] = \
						int(endpoint_survival_failures.get(
							_last_skywalk_selection_failure, 0)) + 1
					continue
				pair_frontier.append(Vector2i(first, second))
				accepted_for_first += 1
				if pair_frontier.size() >= MAX_PAIR_FRONTIER:
					stop_pairs = true
					break
				if accepted_for_first >= MAX_PAIRS_PER_FIRST:
					break
			if stop_pairs:
				break
		if target_count == 2 and not pair_frontier.is_empty():
			selected = [candidates[pair_frontier[0].x],
				candidates[pair_frontier[0].y]] as Array[Dictionary]
		for pair_indices: Vector2i in pair_frontier:
			if target_count == 2:
				break
			var first := pair_indices.x
			var second := pair_indices.y
			for third in candidates.size():
				if third in [first, second] \
						or not _skywalk_candidates_compatible(candidates[first],
							candidates[third]) \
						or not _skywalk_candidates_compatible(candidates[second],
							candidates[third]):
					continue
				var combination := [candidates[first], candidates[second],
					candidates[third]] as Array[Dictionary]
				if not _skywalk_selection_preserves_endpoint_rooms(grid, volume,
						combination, proposals, protected_owners,
						volume.world_seed):
					endpoint_survival_rejection_count += 1
					endpoint_survival_failures[_last_skywalk_selection_failure] = \
						int(endpoint_survival_failures.get(
							_last_skywalk_selection_failure, 0)) + 1
					continue
				selected = combination
				break
			if not selected.is_empty():
				break
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING baseline_beam total_ms=",
			Time.get_ticks_msec() - stage_started, " selected=", selected.size())
	var reservations: Array[Dictionary] = []
	var forced_offsets: Dictionary = {}
	var priority_cells: Dictionary = {}
	for candidate: Dictionary in selected:
		reservations.append((candidate.reservation as Dictionary).duplicate(true))
		for parcel_value: Variant in (candidate.forced_offsets \
				as Dictionary).keys():
			var parcel_id := StringName(parcel_value)
			if not forced_offsets.has(parcel_id):
				forced_offsets[parcel_id] = {}
			for block_value: Variant in ((candidate.forced_offsets \
					as Dictionary)[parcel_id] as Dictionary).keys():
				(forced_offsets[parcel_id] as Dictionary)[int(block_value)] = \
					((candidate.forced_offsets as Dictionary)[parcel_id] \
						as Dictionary)[block_value]
		for cell_value: Variant in (candidate.priority_cells as Dictionary).keys():
			priority_cells[cell_value] = (candidate.priority_cells \
				as Dictionary)[cell_value]
	var pair_keys: Dictionary = {}
	var endpoint_pair_keys: Dictionary = {}
	var candidate_summaries: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		pair_keys[String(candidate.pair_key)] = true
		endpoint_pair_keys[String(candidate.endpoint_pair_key)] = true
	for candidate_index in mini(candidates.size(), 32):
		var candidate := candidates[candidate_index]
		candidate_summaries.append({
			"pair_key": String(candidate.pair_key),
			"endpoint_pair_key": String(candidate.endpoint_pair_key),
			"origin": (candidate.reservation as Dictionary).origin,
			"forced_offsets": candidate.forced_offsets,
			"body_cell_count": (candidate.body as Dictionary).size(),
			"lower_cover": int(candidate.lower_cover),
		})
	var selected_summaries: Array[Dictionary] = []
	for candidate: Dictionary in selected:
		selected_summaries.append({
			"pair_key": String(candidate.pair_key),
			"endpoint_pair_key": String(candidate.endpoint_pair_key),
			"origin": (candidate.reservation as Dictionary).origin,
			"forced_offsets": candidate.forced_offsets,
			"body_cell_count": (candidate.body as Dictionary).size(),
			"lower_cover": int(candidate.lower_cover),
		})
	last_preplan_skywalk_diagnostic = {"raw_straight_count": raw_count,
		"raw_corner_count": corner_raw_count,
		"courtyard_bridge_candidate_count": court_bridge_candidate_count,
		"raw_corners": corner_summaries,
		"corner_upper_block_pair_count": corner_upper_block_count,
		"corner_forced_offset_fit_count": corner_forced_fit_count,
		"corner_body_fit_count": corner_body_fit_count,
		"corner_route_cover_count": corner_route_cover_count,
		"upper_block_pair_count": upper_block_count,
		"forced_offset_fit_count": forced_fit_count,
		"body_fit_count": body_fit_count,
		"route_cover_count": route_cover_count,
		"compatible_candidate_count": candidates.size(),
		"fixed_block_rejection_count": fixed_block_rejection_count,
		"candidate_generation_ms": candidate_generation_ms,
		"courtyard_fixed_block_count": _nested_dictionary_entry_count(
			court_fixed_blocks_by_parcel),
		"individual_candidate_rejection_count": individual_rejection_count,
		"individual_validated_count": individual_limit,
		"individual_validation_ms": individual_validation_ms,
		"individual_candidate_rejection_failures": \
			individual_rejection_failures,
		"distinct_pair_count": pair_keys.size(),
		"pair_keys": pair_keys.keys(),
		"distinct_endpoint_pair_count": endpoint_pair_keys.size(),
		"candidates": candidate_summaries,
		"selected": selected_summaries,
		"endpoint_survival_rejection_count": \
			endpoint_survival_rejection_count,
		"endpoint_survival_failures": endpoint_survival_failures,
		"selected_count": selected.size()}
	return {"reservations": reservations, "forced_offsets": forced_offsets,
		"priority_cells": priority_cells,
		"candidate_count": candidates.size(), "candidate_corpus": candidates,
		"public_air": public_air}


static func _unique_skywalk_structural_candidates(
		candidates: Array[Dictionary]) -> Array[Dictionary]:
	## Asset palette variants and duplicate socket enumeration can describe the
	## same occupied bridge, endpoint obligations, and displaced macro blocks.
	## Preserve the first ranked representative and prove that topology once.
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for candidate: Dictionary in candidates:
		var reservation := candidate.get("reservation", {}) as Dictionary
		var owners := PackedStringArray()
		for owner_value: Variant in reservation.get("owner_parcel_ids", []):
			owners.append(String(StringName(owner_value)))
		owners.sort()
		var key := ("%s/owners=%s/endpoints=%s/force=%s/body=%s/clear=%s/" \
			+ "priority=%s") % [String(candidate.get("pair_key", "")),
			",".join(owners), String(candidate.get("endpoint_pair_key", "")),
			_feature_forced_offset_key(candidate),
			_cell_set_signature(candidate.get("body", {})),
			_cell_set_signature(candidate.get("clearance", {})),
			_cell_owner_map_signature(candidate.get("priority_cells", {}))]
		key = key.sha256_text()
		if seen.has(key):
			continue
		seen[key] = true
		out.append(candidate)
	return out


static func _skywalk_candidate_less(a: Dictionary, b: Dictionary) -> bool:
	if bool(a.get("courtyard_bridge", false)) \
			!= bool(b.get("courtyard_bridge", false)):
		return bool(a.get("courtyard_bridge", false))
	if int(a.blocker_count) != int(b.blocker_count):
		return int(a.blocker_count) < int(b.blocker_count)
	if int(a.lower_cover) != int(b.lower_cover):
		return int(a.lower_cover) > int(b.lower_cover)
	return int(a.tie) < int(b.tie)


static func _courtyard_cantilever_room_candidates(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, proposals: Array[Dictionary],
		program: SettlementFabricProgram, protected_owners: Dictionary,
		public_air: Dictionary) -> Array[Dictionary]:
	## The court-side route may pierce the raw wall, so a full private U-link can
	## be physically impossible.  A corner knuckle plus one reviewed cantilever
	## bay forms an inhabited half-facade over the lower street while leaving the
	## crossing public gateway open.  It is a building feature, not one of the
	## three independent room-to-room skywalks.
	var out: Array[Dictionary] = []
	var floors := _courtyard_floor_cells(volume)
	var parcel_side_mask := _proposal_courtyard_side_mask(volume, proposals)
	var court_y := 2147483647
	for floor_value: Variant in floors.keys():
		court_y = mini(court_y, (floor_value as Vector3i).y)
	var corner_recipe := program.recipe(&"skywalk.corner.blue")
	var bay_recipe := program.recipe(&"skywalk.cantilever.3.blue")
	if corner_recipe == null or bay_recipe == null:
		return out
	var seen: Dictionary = {}
	var raw_count := 0
	var court_side_count := 0
	var body_fit_count := 0
	var clearance_grid_fit_count := 0
	var clearance_protected_fit_count := 0
	var grid_fit_count := 0
	var cover_count := 0
	var rejection_samples: Array[Dictionary] = []
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		for endpoint: Dictionary in _all_proposal_room_endpoints(proposal,
				parcel, program):
			if (endpoint.cell as Vector3i).y != court_y:
				continue
			var endpoint_cell := endpoint.cell as Vector3i
			var facing := endpoint.facing as Vector3i
			for corner_yaw in 4:
				var attach := WarrenAssetCompiler._socket_facing(corner_recipe,
					-facing, corner_yaw)
				if attach.is_empty():
					continue
				var corner_origin := WarrenAssetCompiler._attached_origin(
					corner_recipe, StringName(attach.id), corner_yaw,
					endpoint_cell, facing)
				for along: Vector3i in [Vector3i(-facing.z, 0, facing.x),
						Vector3i(facing.z, 0, -facing.x)]:
					var free := WarrenAssetCompiler._socket_facing(corner_recipe,
						along, corner_yaw)
					if free.is_empty() or free.id == attach.id:
						continue
					var free_cell := FabricRecipe.transform_cell(
						free.cell as Vector3i, corner_origin, corner_yaw)
					var bay_yaw := WarrenAssetCompiler._yaw_for_facing(
						Vector3i.LEFT, -along)
					if bay_yaw < 0:
						continue
					var bay_origin := WarrenAssetCompiler._attached_origin(bay_recipe,
						&"room.west", bay_yaw, free_cell, along)
					var components: Array[Dictionary] = [{
						"recipe_id": &"skywalk.corner.blue",
						"origin": corner_origin, "yaw_quarters": corner_yaw}, {
						"recipe_id": &"skywalk.cantilever.3.blue",
						"origin": bay_origin, "yaw_quarters": bay_yaw}]
					var reservation := WarrenAssetCompiler._component_reservation(
						components, program, public_air)
					if reservation.is_empty():
						continue
					raw_count += 1
					var body := reservation.reserved_cells as Dictionary
					var side_mask := _courtyard_address_side_mask_from_occupied(
						floors, body)
					if side_mask == 0 or not _skywalk_selection_addresses_courtyard(
							[{"courtyard_side_mask": side_mask}] \
								as Array[Dictionary], parcel_side_mask):
						continue
					court_side_count += 1
					var clearance := _skywalk_visual_clearance_cells(components,
						program)
					var body_fits := _skywalk_body_fits_grid(grid, body)
					var clearance_grid_fits := _skywalk_clearance_fits_grid(grid,
						clearance)
					var clearance_protected_fits := \
						_skywalk_clearance_fits_protected(clearance,
							protected_owners)
					body_fit_count += int(body_fits)
					clearance_grid_fit_count += int(body_fits \
						and clearance_grid_fits)
					clearance_protected_fit_count += int(body_fits \
						and clearance_grid_fits and clearance_protected_fits)
					if not body_fits or not clearance_grid_fits \
							or not clearance_protected_fits:
						if rejection_samples.size() < 8:
							rejection_samples.append({
								"endpoint": endpoint_cell,
								"facing": facing,
								"corner_origin": corner_origin,
								"corner_yaw": corner_yaw,
								"bay_origin": bay_origin,
								"bay_yaw": bay_yaw,
								"side_mask": side_mask,
								"body_fits": body_fits,
								"clearance_grid_fits": clearance_grid_fits,
								"clearance_protected_fits":
									clearance_protected_fits,
								"body_conflicts": _skywalk_grid_conflicts(grid,
									body, true),
								"clearance_conflicts": _skywalk_grid_conflicts(grid,
									clearance, false),
								"protected_conflicts":
									_skywalk_protected_conflicts(clearance,
										protected_owners),
							})
						continue
					grid_fit_count += 1
					var lower_cover := _lower_public_cover(body, public_air)
					if lower_cover < 2:
						continue
					cover_count += 1
					var block := _proposal_block_for_cell(proposal, endpoint_cell)
					if block < 0 or not _forced_block_fits(grid, proposal, block,
							Vector2i.ZERO):
						continue
					var plate := _forced_block_cells(proposal, block,
						Vector2i.ZERO)
					if _sets_overlap(body, plate):
						continue
					var key := _skywalk_construction_key({"components": components})
					if seen.has(key):
						continue
					seen[key] = true
					var priority_cells: Dictionary = {}
					for cell_value: Variant in plate.keys():
						priority_cells[cell_value] = parcel.stable_id
					var tower_risk := 0
					if StringName(proposal.kind) == &"tower" \
							and int(proposal.storeys) > WarrenRoomCompositionPlanner \
								.MAX_IDENTICAL_TOWER_FLOORPLATE_RUN_STOREYS:
						tower_risk = 100000 + block * 1000 \
							+ int(proposal.storeys)
					reservation["visual_clearance_cells"] = clearance
					reservation["kind"] = &"courtyard_bridge_house"
					reservation["recipe_id"] = &"skywalk.cantilever.3.blue"
					reservation["origin"] = bay_origin
					reservation["yaw_quarters"] = bay_yaw
					var owner_endpoint := endpoint.duplicate(true)
					owner_endpoint["owner_id"] = parcel.stable_id
					reservation["owner_endpoints"] = [owner_endpoint]
					reservation["owner_parcel_ids"] = [parcel.stable_id]
					reservation["courtyard_side_mask"] = side_mask
					out.append({"reservation": reservation, "body": body,
						"clearance": clearance,
						"forced_offsets": {parcel.stable_id: {
							block: Vector2i.ZERO}},
						"priority_cells": priority_cells,
						"pair_key": String(parcel.stable_id),
						"endpoint_pair_key": _skywalk_endpoint_pair_key(reservation),
						"blocker_count": _skywalk_blocker_count(clearance,
							protected_owners, {parcel.stable_id: true}),
						"lower_cover": lower_cover, "courtyard_bridge": true,
						"courtyard_side_mask": side_mask,
						"tower_risk": tower_risk,
						"tie": posmod(Helper._mix64(volume.world_seed \
							^ String(parcel.stable_id).hash() ^ key.hash()),
							1000003)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("tower_risk", 0)) != int(b.get("tower_risk", 0)):
			return int(a.get("tower_risk", 0)) < int(b.get("tower_risk", 0))
		return _skywalk_candidate_less(a, b))
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING court_cantilever_gates ", {
			"raw": raw_count, "court_side": court_side_count,
			"body": body_fit_count,
			"clearance_grid": clearance_grid_fit_count,
			"clearance_protected": clearance_protected_fit_count,
			"grid": grid_fit_count, "cover": cover_count,
			"accepted": out.size(), "rejections": rejection_samples})
	return out


static func _rank_courtyard_candidates_for_macro(
		candidates: Array[Dictionary], court_floors: Dictionary,
		macro_composition: Dictionary) -> void:
	## Court assets are selected against the already-sealed macroscopic room
	## pattern. Prefer a candidate that completes the required court walls without
	## cutting through those rooms; only then consider the older visual/tie score.
	## This preserves the same complete frontier while avoiding several expensive
	## recompositions of candidates whose structural conflict was visible in O(n)
	## from the first macro plan.
	var room_owner_by_cell: Dictionary = {}
	for lineage_value: Variant in (macro_composition.get("lineages", {}) \
			as Dictionary).values():
		var lineage := lineage_value as Dictionary
		var proposal := lineage.get("proposal", {}) as Dictionary
		var parcel := proposal.get("parcel") as WarrenBuildingParcel
		if parcel == null:
			continue
		for block_value: Variant in lineage.get("blocks", []) as Array:
			for cell: Vector3i in (block_value as Dictionary).get(
					"cells", []) as Array[Vector3i]:
				room_owner_by_cell[cell] = parcel.stable_id
	for candidate: Dictionary in candidates:
		var reservation := candidate.get("reservation", {}) as Dictionary
		var socket_owners: Dictionary = {}
		for owner_value: Variant in reservation.get(
				"owner_parcel_ids", []) as Array:
			socket_owners[StringName(owner_value)] = true
		var conflicts: Dictionary = {}
		var conflict_cell_count := 0
		var owner_socket_conflict_cell_count := 0
		var unrelated_conflicts: Dictionary = {}
		for cell_value: Variant in (candidate.get("body", {}) \
				as Dictionary).keys():
			if not room_owner_by_cell.has(cell_value):
				continue
			conflict_cell_count += 1
			var owner_id := StringName(room_owner_by_cell[cell_value])
			conflicts[owner_id] = true
			if socket_owners.has(owner_id):
				owner_socket_conflict_cell_count += 1
			else:
				unrelated_conflicts[owner_id] = true
		candidate["macro_room_conflict_count"] = conflicts.size()
		candidate["macro_room_conflict_cell_count"] = conflict_cell_count
		candidate["macro_owner_socket_conflict_cell_count"] = \
			owner_socket_conflict_cell_count
		candidate["macro_unrelated_room_conflict_count"] = \
			unrelated_conflicts.size()
		candidate["macro_room_conflict_owner_ids"] = conflicts.keys()
		candidate["macro_court_side_count"] = _side_mask_count(
			_composition_courtyard_side_mask(court_floors,
				macro_composition, candidate.body as Dictionary))
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_encloses := int(a.macro_court_side_count) \
			>= WarrenSpatialFeatureSolver.MIN_COURT_SIDE_COUNT
		var b_encloses := int(b.macro_court_side_count) \
			>= WarrenSpatialFeatureSolver.MIN_COURT_SIDE_COUNT
		if a_encloses != b_encloses:
			return a_encloses
		var a_recomposable := _court_macro_conflict_is_recomposable(a)
		var b_recomposable := _court_macro_conflict_is_recomposable(b)
		if a_recomposable != b_recomposable:
			return a_recomposable
		if int(a.macro_unrelated_room_conflict_count) \
				!= int(b.macro_unrelated_room_conflict_count):
			return int(a.macro_unrelated_room_conflict_count) \
				< int(b.macro_unrelated_room_conflict_count)
		if int(a.macro_owner_socket_conflict_cell_count) \
				!= int(b.macro_owner_socket_conflict_cell_count):
			return int(a.macro_owner_socket_conflict_cell_count) \
				< int(b.macro_owner_socket_conflict_cell_count)
		if int(a.macro_room_conflict_count) \
				!= int(b.macro_room_conflict_count):
			return int(a.macro_room_conflict_count) \
				< int(b.macro_room_conflict_count)
		if int(a.macro_room_conflict_cell_count) \
				!= int(b.macro_room_conflict_cell_count):
			return int(a.macro_room_conflict_cell_count) \
				< int(b.macro_room_conflict_cell_count)
		return _skywalk_candidate_less(a, b))


static func _court_macro_conflict_is_recomposable(candidate: Dictionary) -> bool:
	return int(candidate.get("macro_unrelated_room_conflict_count", 1)) == 0 \
		and int(candidate.get("macro_owner_socket_conflict_cell_count",
			MAX_COURT_OWNER_SOCKET_RECOMPOSITION_CELLS + 1)) \
			<= MAX_COURT_OWNER_SOCKET_RECOMPOSITION_CELLS


static func _any_key_overlap(left: Dictionary, right: Dictionary) -> bool:
	for key: Variant in left.keys():
		if right.has(key):
			return true
	return false


static func _courtyard_bridge_skywalk_candidates(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, proposals: Array[Dictionary],
		program: SettlementFabricProgram, protected_owners: Dictionary,
		public_air: Dictionary) -> Array[Dictionary]:
	## A court cut through a solid mountain may have its third raw wall hovering
	## over the lower street instead of standing on a vertical bearing column.
	## Realize that condition as one measured U-shaped bridge-house: two pitched
	## corner knuckles bond to independent rooms and a reviewed enclosed link runs
	## along the court edge.  The body, endpoints, lower route, and asset seams all
	## participate in the same pre-partition transaction.
	var out: Array[Dictionary] = []
	var court_floors := _courtyard_floor_cells(volume)
	var parcel_side_mask := _proposal_courtyard_side_mask(volume, proposals)
	var proposal_by_id: Dictionary = {}
	var endpoints: Array[Dictionary] = []
	var court_y := 2147483647
	for floor_value: Variant in court_floors.keys():
		court_y = mini(court_y, (floor_value as Vector3i).y)
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		proposal_by_id[parcel.stable_id] = proposal
		for endpoint: Dictionary in _all_proposal_room_endpoints(proposal,
				parcel, program):
			if (endpoint.cell as Vector3i).y == court_y:
				endpoints.append(endpoint)
	var seen: Dictionary = {}
	var parallel_pair_count := 0
	var raw_count := 0
	var court_side_fit_count := 0
	var grid_fit_count := 0
	var lower_cover_count := 0
	var endpoint_block_fit_count := 0
	var court_endpoint_preview: Array[Dictionary] = []
	var raw_preview: Array[Dictionary] = []
	for endpoint: Dictionary in endpoints:
		if StringName(endpoint.owner_id) in [&"parcel.solid.0050",
				&"parcel.solid.0051"]:
			court_endpoint_preview.append({"owner": endpoint.owner_id,
				"cell": endpoint.cell, "facing": endpoint.facing})
	for left_index in endpoints.size():
		var left := endpoints[left_index]
		var left_id := StringName(left.owner_id)
		for right_index in range(left_index + 1, endpoints.size()):
			var right := endpoints[right_index]
			var right_id := StringName(right.owner_id)
			if left_id == right_id or left.facing != right.facing:
				continue
			parallel_pair_count += 1
			for reservation: Dictionary in _raw_u_courtyard_bridges(left,
					right, left_id, right_id, program, public_air):
				raw_count += 1
				var body := reservation.reserved_cells as Dictionary
				var body_side_mask := _courtyard_address_side_mask_from_occupied(
					court_floors, body)
				if raw_preview.size() < 32:
					raw_preview.append({"left": left, "right": right,
						"origin": reservation.origin, "side_mask": body_side_mask,
						"body": body.keys()})
				if body_side_mask == 0 or not _skywalk_selection_addresses_courtyard(
						[{"courtyard_side_mask": body_side_mask}] \
							as Array[Dictionary], parcel_side_mask):
					continue
				court_side_fit_count += 1
				var clearance := reservation.visual_clearance_cells as Dictionary
				if not _skywalk_body_fits_grid(grid, body) \
						or not _skywalk_clearance_fits_grid(grid, clearance) \
						or not _skywalk_clearance_fits_protected(clearance,
							protected_owners):
					continue
				grid_fit_count += 1
				var lower_cover := _lower_public_cover(body, public_air)
				if lower_cover < 2:
					continue
				lower_cover_count += 1
				var left_proposal := proposal_by_id[left_id] as Dictionary
				var right_proposal := proposal_by_id[right_id] as Dictionary
				var left_block := _proposal_block_for_cell(left_proposal,
					left.cell as Vector3i)
				var right_block := _proposal_block_for_cell(right_proposal,
					right.cell as Vector3i)
				if left_block < 0 or right_block < 0 \
						or not _forced_block_fits(grid, left_proposal, left_block,
							Vector2i.ZERO) \
						or not _forced_block_fits(grid, right_proposal, right_block,
							Vector2i.ZERO):
					continue
				endpoint_block_fit_count += 1
				var left_plate := _forced_block_cells(left_proposal, left_block,
					Vector2i.ZERO)
				var right_plate := _forced_block_cells(right_proposal, right_block,
					Vector2i.ZERO)
				if _sets_overlap(body, left_plate) or _sets_overlap(body,
						right_plate):
					continue
				var construction_key := _skywalk_construction_key(reservation)
				if seen.has(construction_key):
					continue
				seen[construction_key] = true
				var priority_cells: Dictionary = {}
				for value: Variant in left_plate.keys():
					priority_cells[value] = left_id
				for value: Variant in right_plate.keys():
					priority_cells[value] = right_id
				out.append({"reservation": reservation, "body": body,
					"clearance": clearance,
					"forced_offsets": {left_id: {left_block: Vector2i.ZERO},
						right_id: {right_block: Vector2i.ZERO}},
					"priority_cells": priority_cells,
					"pair_key": "%s|%s" % [left_id, right_id],
					"endpoint_pair_key": _skywalk_endpoint_pair_key(reservation),
					"blocker_count": _skywalk_blocker_count(clearance,
						protected_owners, {left_id: true, right_id: true}),
					"lower_cover": lower_cover,
					"courtyard_bridge": true,
					"courtyard_side_mask": body_side_mask,
					"tie": posmod(Helper._mix64(volume.world_seed \
						^ String(left_id).hash() ^ String(right_id).hash() \
						^ construction_key.hash()), 1000003)})
	out.sort_custom(_skywalk_candidate_less)
	if diagnostic_trace_skywalk_timing:
		print("SKYWALK_TIMING court_bridge_gates ", {
			"endpoints": endpoints.size(), "parallel_pairs": parallel_pair_count,
			"raw": raw_count, "court_side": court_side_fit_count,
			"grid": grid_fit_count, "lower_cover": lower_cover_count,
			"endpoint_blocks": endpoint_block_fit_count,
			"accepted": out.size(), "court_endpoints": court_endpoint_preview,
			"raw_preview": raw_preview})
	return out


static func _all_proposal_room_endpoints(proposal: Dictionary,
		parcel: WarrenBuildingParcel,
		program: SettlementFabricProgram) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for component: Dictionary in StaggeredFabricCompiler.proposal_components(
			proposal):
		var recipe := program.recipe(StringName(component.recipe_id))
		if recipe == null or recipe.has_tag(&"roof"):
			continue
		for socket: Dictionary in recipe.sockets:
			if int(socket.kind) != FabricRecipe.SocketKind.ROOM \
					or not String(StringName(socket.id)).begins_with("room.") \
					or String(StringName(socket.id)).contains(".corner."):
				continue
			var cell := FabricRecipe.transform_cell(socket.cell as Vector3i,
				component.origin as Vector3i, int(component.yaw_quarters))
			var facing := FabricRecipe.transform_direction(
				socket.facing as Vector3i, int(component.yaw_quarters))
			var key := "%s/%s" % [cell, facing]
			if seen.has(key):
				continue
			seen[key] = true
			out.append({"cell": cell, "facing": facing,
				"owner_id": parcel.stable_id,
				"slot_signature": parcel.slot_signature()})
	return out


static func _raw_u_courtyard_bridges(left_endpoint: Dictionary,
		right_endpoint: Dictionary, left_owner_id: StringName,
		right_owner_id: StringName, program: SettlementFabricProgram,
		public_air: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var left_cell := left_endpoint.cell as Vector3i
	var right_cell := right_endpoint.cell as Vector3i
	var facing := left_endpoint.facing as Vector3i
	var delta := right_cell - left_cell
	if left_cell.y != right_cell.y or facing != right_endpoint.facing \
			or delta.y != 0 or delta.x != 0 and delta.z != 0:
		return out
	var distance := absi(delta.x) + absi(delta.z)
	if distance < 5 or distance > 9:
		return out
	var along := Vector3i(signi(delta.x), 0, signi(delta.z))
	if along == Vector3i.ZERO or along == facing or along == -facing:
		return out
	# The socket geometry is identical across palette variants. Use the cool
	# contract for layout, then campaign-match both knuckles to the selected
	# middle span before the measured reservation is compiled.
	var corner_recipe := program.recipe(&"skywalk.corner.blue")
	if corner_recipe == null:
		return out
	var seen: Dictionary = {}
	var yaw_pair_count := 0
	var middle_fit_count := 0
	var component_fit_count := 0
	var middle_preview: Array[Dictionary] = []
	for left_yaw in 4:
		var left_attach := WarrenAssetCompiler._socket_facing(corner_recipe,
			-facing, left_yaw)
		var left_free := WarrenAssetCompiler._socket_facing(corner_recipe,
			along, left_yaw)
		if left_attach.is_empty() or left_free.is_empty() \
				or left_attach.id == left_free.id:
			continue
		var left_origin := WarrenAssetCompiler._attached_origin(corner_recipe,
			StringName(left_attach.id), left_yaw, left_cell, facing)
		var left_free_cell := FabricRecipe.transform_cell(
			left_free.cell as Vector3i, left_origin, left_yaw)
		for right_yaw in 4:
			var right_attach := WarrenAssetCompiler._socket_facing(corner_recipe,
				-facing, right_yaw)
			var right_free := WarrenAssetCompiler._socket_facing(corner_recipe,
				-along, right_yaw)
			if right_attach.is_empty() or right_free.is_empty() \
					or right_attach.id == right_free.id:
				continue
			yaw_pair_count += 1
			var right_origin := WarrenAssetCompiler._attached_origin(corner_recipe,
				StringName(right_attach.id), right_yaw, right_cell, facing)
			var right_free_cell := FabricRecipe.transform_cell(
				right_free.cell as Vector3i, right_origin, right_yaw)
			var middle := _raw_straight_skywalk_between_endpoints(
				{"cell": left_free_cell, "facing": along},
				{"cell": right_free_cell, "facing": -along},
				&"court.corner.left", &"court.corner.right", program, public_air)
			if middle.is_empty():
				if middle_preview.size() < 8:
					var geometry_only := _raw_straight_skywalk_between_endpoints(
						{"cell": left_free_cell, "facing": along},
						{"cell": right_free_cell, "facing": -along},
						&"court.corner.left", &"court.corner.right", program, {})
					var public_conflicts: Array[Vector3i] = []
					for cell_value: Variant in (geometry_only.get("reserved_cells", {}) \
							as Dictionary).keys():
						if public_air.has(cell_value):
							public_conflicts.append(cell_value as Vector3i)
					middle_preview.append({"left_yaw": left_yaw,
						"right_yaw": right_yaw, "left_free": left_free_cell,
						"right_free": right_free_cell,
						"geometry_only": not geometry_only.is_empty(),
						"public_conflicts": public_conflicts})
				continue
			middle_fit_count += 1
			var corner_recipe_id := _skywalk_corner_campaign_recipe(
				StringName(middle.recipe_id), StringName(middle.recipe_id))
			var components: Array[Dictionary] = [{
				"recipe_id": corner_recipe_id, "origin": left_origin,
				"yaw_quarters": left_yaw}]
			components.append_array(middle.components as Array)
			components.append({"recipe_id": corner_recipe_id,
				"origin": right_origin, "yaw_quarters": right_yaw})
			var reservation := WarrenAssetCompiler._component_reservation(
				components, program, public_air)
			if reservation.is_empty():
				continue
			component_fit_count += 1
			reservation["visual_clearance_cells"] = \
				_skywalk_visual_clearance_cells(components, program)
			reservation["kind"] = &"courtyard_bridge_house"
			reservation["recipe_id"] = StringName(middle.recipe_id)
			reservation["origin"] = middle.origin
			reservation["yaw_quarters"] = int(middle.yaw_quarters)
			var left_record := left_endpoint.duplicate(true)
			left_record["owner_id"] = left_owner_id
			var right_record := right_endpoint.duplicate(true)
			right_record["owner_id"] = right_owner_id
			reservation["owner_endpoints"] = [left_record, right_record]
			var key := _skywalk_construction_key(reservation)
			if seen.has(key):
				continue
			seen[key] = true
			out.append(reservation)
	if diagnostic_trace_skywalk_timing \
			and ((left_owner_id == &"parcel.solid.0050" \
				and right_owner_id == &"parcel.solid.0051") \
			or (left_owner_id == &"parcel.solid.0051" \
				and right_owner_id == &"parcel.solid.0050")):
		print("SKYWALK_TIMING target_u_bridge ", {"left": left_endpoint,
			"right": right_endpoint, "yaw_pairs": yaw_pair_count,
			"middle_fit": middle_fit_count, "component_fit": component_fit_count,
			"accepted": out.size(), "middle_preview": middle_preview})
	return out


static func _skywalk_candidate_respects_fixed_blocks(candidate: Dictionary,
		proposal_by_slot: Dictionary,
		court_fixed_blocks_by_parcel: Dictionary = {}) -> bool:
	for parcel_value: Variant in (candidate.forced_offsets as Dictionary).keys():
		var parcel_id := StringName(parcel_value)
		var proposal: Dictionary = {}
		for proposal_value: Variant in proposal_by_slot.values():
			var candidate_proposal := proposal_value as Dictionary
			if (candidate_proposal.parcel as WarrenBuildingParcel).stable_id \
					== parcel_id:
				proposal = candidate_proposal
				break
		if proposal.is_empty():
			return false
		var parcel := proposal.parcel as WarrenBuildingParcel
		var origin := proposal.origin as Vector3i
		var storeys := int(proposal.storeys)
		var threshold := WarrenParcelConstruction.threshold_cell(parcel)
		var addressed_storey := clampi(floori(float(threshold.y - origin.y) \
			/ float(WarrenSpatialGrid.STOREY_CELLS)), 0, storeys - 1)
		var addressed_block := addressed_storey / 2
		for block_value: Variant in ((candidate.forced_offsets as Dictionary)[
				parcel_id] as Dictionary).keys():
			var block := int(block_value)
			var wanted := ((candidate.forced_offsets as Dictionary)[parcel_id] \
				as Dictionary)[block] as Vector2i
			var court_fixed := (court_fixed_blocks_by_parcel.get(parcel_id, {}) \
				as Dictionary).has(block)
			if (block in [0, addressed_block] or court_fixed) \
					and wanted != Vector2i.ZERO:
				return false
	return true


static func _shifted_corner_skywalk_candidates(grid: WarrenSpatialGrid,
		left: WarrenBuildingParcel, right: WarrenBuildingParcel,
		left_proposal: Dictionary, right_proposal: Dictionary,
		left_endpoint: Dictionary, right_endpoint: Dictionary,
		left_block: int, right_block: int,
		program: SettlementFabricProgram, protected_owners: Dictionary,
		public_air: Dictionary, world_seed: int,
		forced_block_cache: Dictionary,
		corner_reservation_cache: Dictionary) -> Dictionary:
	## Re-solve the complete L-shaped recipe after independently shifting its
	## endpoint composition blocks. Translating an already-solved corner only
	## admitted one of the three high opportunities; recomposition preserves the
	## measured sockets while allowing the two arms to change length around the
	## immutable public void.
	var out: Array[Dictionary] = []
	var left_cell := left_endpoint.cell as Vector3i
	var right_cell := right_endpoint.cell as Vector3i
	var left_facing := left_endpoint.facing as Vector3i
	var right_facing := right_endpoint.facing as Vector3i
	if left_cell.y != right_cell.y \
			or left_facing.x * right_facing.x \
				+ left_facing.z * right_facing.z != 0 \
			or left_block < 0 or right_block < 0:
		return {"candidates": out}
	var left_storey := _proposal_storey_for_cell(left_proposal, left_cell)
	var right_storey := _proposal_storey_for_cell(right_proposal, right_cell)
	var left_can_break := left_storey > 0 and posmod(left_storey, 2) == 0
	var right_can_break := right_storey > 0 and posmod(right_storey, 2) == 0
	if not left_can_break and not right_can_break:
		return {"candidates": out}
	var deltas: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT,
		Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	var forced_fit_count := 0
	var body_fit_count := 0
	var route_cover_count := 0
	var seen: Dictionary = {}
	for left_delta: Vector2i in deltas:
		if left_delta != Vector2i.ZERO and left_block <= 0:
			continue
		var left_state := _cached_forced_block_state(forced_block_cache, grid,
			left_proposal, left_block, left_delta)
		if not bool(left_state.fits):
			continue
		var left_plate := left_state.cells as Dictionary
		for right_delta: Vector2i in deltas:
			if left_delta == Vector2i.ZERO and right_delta == Vector2i.ZERO:
				continue
			if not (left_can_break and left_delta != Vector2i.ZERO) \
					and not (right_can_break and right_delta != Vector2i.ZERO):
				continue
			if right_delta != Vector2i.ZERO and right_block <= 0:
				continue
			var right_state := _cached_forced_block_state(forced_block_cache,
				grid, right_proposal, right_block, right_delta)
			if not bool(right_state.fits):
				continue
			forced_fit_count += 1
			var right_plate := right_state.cells as Dictionary
			if _sets_overlap(left_plate, right_plate):
				continue
			var shifted_left := left_endpoint.duplicate(true)
			shifted_left["cell"] = left_cell + Vector3i(left_delta.x, 0,
				left_delta.y)
			var shifted_right := right_endpoint.duplicate(true)
			shifted_right["cell"] = right_cell + Vector3i(right_delta.x, 0,
				right_delta.y)
			var reservations := _cached_corner_skywalk_reservations(
				corner_reservation_cache, left, right, shifted_left,
				shifted_right, program, public_air)
			for reservation: Dictionary in reservations:
				var body := reservation.reserved_cells as Dictionary
				var clearance := reservation.visual_clearance_cells as Dictionary
				if not _skywalk_body_fits_grid(grid, body) \
						or not _skywalk_clearance_fits_grid(grid, clearance) \
						or not _skywalk_clearance_fits_protected(clearance,
							protected_owners) \
						or _sets_overlap(body, left_plate) \
						or _sets_overlap(body, right_plate):
					continue
				body_fit_count += 1
				var lower_cover := _lower_public_cover(body, public_air)
				if lower_cover < 2:
					continue
				route_cover_count += 1
				var endpoint_pair_key := _skywalk_endpoint_pair_key(reservation)
				var construction_key := _skywalk_construction_key(reservation)
				var unique_key := "%s/%s" % [endpoint_pair_key, construction_key]
				if seen.has(unique_key):
					continue
				seen[unique_key] = true
				var blockers := _skywalk_blocker_count(clearance,
					protected_owners, {left.stable_id: true,
						right.stable_id: true})
				var forced: Dictionary = {
					left.stable_id: {left_block: left_delta},
					right.stable_id: {right_block: right_delta},
				}
				var priority_cells: Dictionary = {}
				for value: Variant in left_plate.keys():
					priority_cells[value] = left.stable_id
				for value: Variant in right_plate.keys():
					priority_cells[value] = right.stable_id
				reservation["owner_parcel_ids"] = [left.stable_id,
					right.stable_id]
				var corner_origin := reservation.origin as Vector3i
				out.append({"reservation": reservation, "body": body,
					"clearance": clearance,
					"forced_offsets": forced, "priority_cells": priority_cells,
					"pair_key": "%s|%s" % [left.stable_id, right.stable_id],
					"endpoint_pair_key": endpoint_pair_key,
					"blocker_count": blockers, "lower_cover": lower_cover,
					"tie": posmod(Helper._mix64(world_seed \
						^ String(left.stable_id).hash() \
						^ String(right.stable_id).hash() \
						^ left_delta.x * 0x45d9f3b \
						^ left_delta.y * 0x27d4eb2d \
						^ right_delta.x * 0x165667b1 \
						^ right_delta.y * 0x1b873593 \
						^ corner_origin.x * 31 ^ corner_origin.z * 47), 1000003)})
	return {"candidates": out,
		"upper_pair_count": int(left_block > 0 or right_block > 0),
		"forced_fit_count": forced_fit_count,
		"body_fit_count": body_fit_count,
		"route_cover_count": route_cover_count}


static func _cached_forced_block_state(cache: Dictionary,
		grid: WarrenSpatialGrid, proposal: Dictionary, block: int,
		offset: Vector2i) -> Dictionary:
	var key := "%s/b%d/%d:%d" % [StringName(proposal.stable_id), block,
		offset.x, offset.y]
	if cache.has(key):
		return cache[key] as Dictionary
	var cells := _forced_block_cells(proposal, block, offset)
	var state := {"fits": _forced_block_fits(grid, proposal, block, offset),
		"cells": cells}
	cache[key] = state
	return state


static func _cached_corner_skywalk_reservations(cache: Dictionary,
		left: WarrenBuildingParcel, right: WarrenBuildingParcel,
		left_endpoint: Dictionary, right_endpoint: Dictionary,
		program: SettlementFabricProgram, public_air: Dictionary) \
		-> Array[Dictionary]:
	var key := "%s|%s/%s|%s" % [left.stable_id, right.stable_id,
		_skywalk_endpoint_part(left_endpoint),
		_skywalk_endpoint_part(right_endpoint)]
	if not cache.has(key):
		cache[key] = _raw_corner_skywalk_reservations(left, right,
			left_endpoint, right_endpoint, program, public_air)
	var out: Array[Dictionary] = []
	for value: Variant in cache[key] as Array:
		out.append((value as Dictionary).duplicate(true))
	return out


static func _skywalk_endpoint_part(endpoint: Dictionary) -> String:
	var cell := endpoint.cell as Vector3i
	var facing := endpoint.facing as Vector3i
	return "%d:%d:%d/%d:%d:%d" % [cell.x, cell.y, cell.z,
		facing.x, facing.y, facing.z]


static func _raw_corner_skywalk_reservations(left: WarrenBuildingParcel,
		right: WarrenBuildingParcel, left_endpoint: Dictionary,
		right_endpoint: Dictionary, program: SettlementFabricProgram,
		public_air: Dictionary) -> Array[Dictionary]:
	return _raw_corner_skywalks_between_endpoints(left_endpoint,
		right_endpoint, left.stable_id, right.stable_id, program, public_air)


static func _raw_corner_skywalks_between_endpoints(left_endpoint: Dictionary,
		right_endpoint: Dictionary, left_owner_id: StringName,
		right_owner_id: StringName, program: SettlementFabricProgram,
		public_air: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var left_cell := left_endpoint.cell as Vector3i
	var right_cell := right_endpoint.cell as Vector3i
	var left_facing := left_endpoint.facing as Vector3i
	var right_facing := right_endpoint.facing as Vector3i
	if left_cell.y != right_cell.y \
			or left_facing.x * right_facing.x \
				+ left_facing.z * right_facing.z != 0:
		return out
	var corner_recipe := program.recipe(&"skywalk.corner.blue")
	if corner_recipe == null:
		return out
	var seen: Dictionary = {}
	for corner_yaw in 4:
		var left_socket := WarrenAssetCompiler._socket_facing(corner_recipe,
			-left_facing, corner_yaw)
		var right_socket := WarrenAssetCompiler._socket_facing(corner_recipe,
			-right_facing, corner_yaw)
		if left_socket.is_empty() or right_socket.is_empty() \
				or left_socket.id == right_socket.id:
			continue
		for left_distance: int in [3, 5, 7]:
			var desired_left: Vector3i = left_cell \
				+ left_facing * left_distance
			var corner_origin: Vector3i = desired_left \
				- FabricRecipe.transform_cell(
				left_socket.cell as Vector3i, Vector3i.ZERO, corner_yaw)
			var right_corner_cell := FabricRecipe.transform_cell(
				right_socket.cell as Vector3i, corner_origin, corner_yaw)
			var right_delta := right_corner_cell - right_cell
			var right_distance: int = right_delta.x * right_facing.x \
				+ right_delta.z * right_facing.z
			if right_distance not in [3, 5, 7] \
					or right_delta != right_facing * right_distance:
				continue
			var left_recipe_id := WarrenAssetCompiler._cantilever_recipe(
				(left_distance - 1) / 2)
			var right_recipe_id := WarrenAssetCompiler._cantilever_recipe(
				(right_distance - 1) / 2)
			var left_recipe := program.recipe(left_recipe_id)
			var right_recipe := program.recipe(right_recipe_id)
			var left_yaw := WarrenAssetCompiler._yaw_for_facing(Vector3i.LEFT,
				-left_facing)
			var right_yaw := WarrenAssetCompiler._yaw_for_facing(Vector3i.LEFT,
				right_facing)
			if left_recipe == null or right_recipe == null \
					or left_yaw < 0 or right_yaw < 0:
				continue
			var left_origin := WarrenAssetCompiler._attached_origin(left_recipe,
				&"room.west", left_yaw, left_cell, left_facing)
			var right_corner_facing := FabricRecipe.transform_direction(
				right_socket.facing as Vector3i, corner_yaw)
			var right_origin := WarrenAssetCompiler._attached_origin(right_recipe,
				&"room.west", right_yaw, right_corner_cell,
				right_corner_facing)
			var corner_recipe_id := _skywalk_corner_campaign_recipe(
				left_recipe_id, right_recipe_id)
			var components: Array[Dictionary] = [
				{"recipe_id": left_recipe_id, "origin": left_origin,
					"yaw_quarters": left_yaw},
				{"recipe_id": corner_recipe_id, "origin": corner_origin,
					"yaw_quarters": corner_yaw},
				{"recipe_id": right_recipe_id, "origin": right_origin,
					"yaw_quarters": right_yaw},
			]
			var reservation := WarrenAssetCompiler._component_reservation(
				components, program, public_air)
			if reservation.is_empty():
				continue
			reservation["visual_clearance_cells"] = \
				_skywalk_visual_clearance_cells(components, program)
			reservation["kind"] = &"corner"
			reservation["recipe_id"] = corner_recipe_id
			reservation["origin"] = corner_origin
			reservation["yaw_quarters"] = corner_yaw
			var left_record := left_endpoint.duplicate(true)
			left_record["owner_id"] = left_owner_id
			var right_record := right_endpoint.duplicate(true)
			right_record["owner_id"] = right_owner_id
			reservation["owner_endpoints"] = [left_record, right_record]
			var key := _skywalk_construction_key(reservation)
			if seen.has(key):
				continue
			seen[key] = true
			out.append(reservation)
	return out


static func _skywalk_corner_campaign_recipe(left_recipe_id: StringName,
		right_recipe_id: StringName) -> StringName:
	## One occupied bridge-house is one roof campaign. A differently coloured
	## knuckle made a single continuous pitched roof look patched together at the
	## seam. Match both equal-family arms; mixed-length/mixed-family arms use slate
	## as the quieter junction material rather than adding a third abrupt patch.
	var left_orange := String(left_recipe_id).contains("orange")
	var right_orange := String(right_recipe_id).contains("orange")
	return &"skywalk.corner.orange" if left_orange and right_orange \
		else &"skywalk.corner.blue"


static func _skywalk_construction_key(reservation: Dictionary) -> String:
	var parts := PackedStringArray()
	for component_value: Variant in reservation.get("components", []):
		var component := component_value as Dictionary
		var origin := component.origin as Vector3i
		parts.append("%s@%d:%d:%d/r%d" % [StringName(component.recipe_id),
			origin.x, origin.y, origin.z, int(component.yaw_quarters)])
	parts.sort()
	return "|".join(parts)


static func _skywalk_visual_clearance_cells(components: Array[Dictionary],
		program: SettlementFabricProgram) -> Dictionary:
	## Convert the measured world-space envelopes into a conservative fine-cell
	## reservation. The exact AABB test uses the same tolerance as final fabric
	## assembly, so topology yields only where an unrelated mesh would really be
	## rejected later; the connector's own occupancy remains a separate fact.
	var out: Dictionary = {}
	var cell_size := FabricRecipe.CELL_SIZE
	var half := cell_size * 0.5
	for component: Dictionary in components:
		var recipe := program.recipe(StringName(component.recipe_id))
		if recipe == null:
			return {}
		var bounds := FabricRecipe.lattice_transform(
			component.origin as Vector3i, int(component.yaw_quarters)) \
			* recipe.local_clearance_bounds
		var minimum := bounds.position
		var maximum := bounds.end
		var min_x := floori((minimum.x - half) / cell_size) - 1
		var max_x := ceili((maximum.x + half) / cell_size) + 1
		var min_y := floori(minimum.y / cell_size) - 1
		var max_y := ceili(maximum.y / cell_size) + 1
		var min_z := floori((minimum.z - half) / cell_size) - 1
		var max_z := ceili((maximum.z + half) / cell_size) + 1
		for y in range(min_y, max_y + 1):
			for z in range(min_z, max_z + 1):
				for x in range(min_x, max_x + 1):
					var cell := Vector3i(x, y, z)
					var cell_bounds := AABB(Vector3(cell) * cell_size \
						+ Vector3(-half, 0.0, -half),
						Vector3.ONE * cell_size)
					if SettlementFabricPlan._aabb_overlaps_volume(bounds,
							cell_bounds):
						out[cell] = true
	return out


static func _skywalk_endpoint_owner_set(reservation: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for owner_value: Variant in reservation.get("owner_parcel_ids", []):
		out[StringName(owner_value)] = true
	return out


static func _stationary_skywalk_candidates(grid: WarrenSpatialGrid,
		raw: Dictionary, left: WarrenBuildingParcel,
		right: WarrenBuildingParcel, left_proposal: Dictionary,
		right_proposal: Dictionary, left_endpoint: Dictionary,
		right_endpoint: Dictionary, left_block: int, right_block: int,
		protected_owners: Dictionary, public_air: Dictionary,
		world_seed: int) -> Array[Dictionary]:
	## Keep the exact connector/endpoints fixed and move the composition block
	## immediately below one endpoint. This is legal only when the endpoint is
	## the first storey of block 2 or higher; its floorplate then differs from the
	## actual storey beneath without shifting terrain-bearing mass.
	var out: Array[Dictionary] = []
	var body := raw.reserved_cells as Dictionary
	var clearance := raw.visual_clearance_cells as Dictionary
	if not _skywalk_body_fits_grid(grid, body) \
			or not _skywalk_clearance_fits_grid(grid, clearance) \
			or not _skywalk_clearance_fits_protected(clearance,
				protected_owners):
		return out
	var lower_cover := _lower_public_cover(body, public_air)
	if lower_cover < 2:
		return out
	var facing := left_endpoint.facing as Vector3i
	var perpendicular := Vector3i(-facing.z, 0, facing.x)
	for side: Dictionary in [
		{"parcel": left, "proposal": left_proposal,
			"endpoint": left_endpoint, "block": left_block,
			"other_parcel": right, "other_block": right_block},
		{"parcel": right, "proposal": right_proposal,
			"endpoint": right_endpoint, "block": right_block,
			"other_parcel": left, "other_block": left_block},
	]:
		var block := int(side.block)
		var storey := _proposal_storey_for_cell(side.proposal as Dictionary,
			(side.endpoint as Dictionary).cell as Vector3i)
		if block < 2 or storey != block * 2:
			continue
		for sign_value in [-1, 1]:
			var delta3 := perpendicular * int(sign_value)
			var delta := Vector2i(delta3.x, delta3.z)
			var previous_block := block - 1
			if not _forced_block_fits(grid, side.proposal as Dictionary,
					previous_block, delta):
				continue
			var shifted_lower := _forced_block_cells(side.proposal as Dictionary,
				previous_block, delta)
			if _sets_overlap(body, shifted_lower):
				continue
			var owner := side.parcel as WarrenBuildingParcel
			var other := side.other_parcel as WarrenBuildingParcel
			var forced: Dictionary = {
				owner.stable_id: {previous_block: delta, block: Vector2i.ZERO},
				other.stable_id: {int(side.other_block): Vector2i.ZERO},
			}
			var priority_cells: Dictionary = {}
			for value: Variant in shifted_lower.keys():
				priority_cells[value] = owner.stable_id
			var blockers := _skywalk_blocker_count(clearance, protected_owners,
				{left.stable_id: true, right.stable_id: true})
			var reservation := raw.duplicate(true)
			reservation["owner_parcel_ids"] = [left.stable_id,
				right.stable_id]
			var endpoint_pair_key := _skywalk_endpoint_pair_key(reservation)
			out.append({"reservation": reservation, "body": body,
				"clearance": clearance,
				"forced_offsets": forced, "priority_cells": priority_cells,
				"pair_key": "%s|%s" % [left.stable_id, right.stable_id],
				"endpoint_pair_key": endpoint_pair_key,
				"blocker_count": blockers, "lower_cover": lower_cover,
				"tie": posmod(Helper._mix64(world_seed \
					^ String(left.stable_id).hash() \
					^ String(right.stable_id).hash() \
					^ owner.stable_id.hash() ^ int(sign_value) * 0x27d4eb2d),
					1000003)})
	return out


static func _skywalk_endpoint_pair_key(reservation: Dictionary) -> String:
	var parts := PackedStringArray()
	for endpoint_value: Variant in reservation.get("owner_endpoints", []):
		var endpoint := endpoint_value as Dictionary
		var cell := endpoint.cell as Vector3i
		var facing := endpoint.facing as Vector3i
		parts.append("%d:%d:%d/%d:%d:%d" % [cell.x, cell.y, cell.z,
			facing.x, facing.y, facing.z])
	parts.sort()
	return "|".join(parts)


static func _raw_straight_skywalk_reservation(left: WarrenBuildingParcel,
		right: WarrenBuildingParcel, left_endpoint: Dictionary,
		right_endpoint: Dictionary, program: SettlementFabricProgram,
		public_air: Dictionary) -> Dictionary:
	if (left_endpoint.cell as Vector3i).y != (right_endpoint.cell as Vector3i).y \
			or (left_endpoint.facing as Vector3i) \
				!= -(right_endpoint.facing as Vector3i):
		return {}
	var forward := left_endpoint.facing as Vector3i
	var delta := (right_endpoint.cell as Vector3i) \
		- (left_endpoint.cell as Vector3i)
	var distance: int = delta.x * forward.x + delta.z * forward.z
	if distance < 3 or distance > 7 or posmod(distance, 2) != 1 \
			or delta != forward * distance:
		return {}
	var segments := (distance - 1) / 2
	var recipe_id := &"skywalk.3.blue" if segments == 1 \
		else &"skywalk.6.orange" if segments == 2 else &"skywalk.9.blue"
	var recipe := program.recipe(recipe_id)
	var yaw := -1
	for candidate_yaw in 4:
		if FabricRecipe.transform_direction(Vector3i.LEFT, candidate_yaw) \
				== -forward:
			yaw = candidate_yaw
			break
	if recipe == null or yaw < 0:
		return {}
	var west := recipe.socket(&"room.west")
	if west.is_empty():
		return {}
	var origin := (left_endpoint.cell as Vector3i) + forward \
		- FabricRecipe.transform_cell(west.cell as Vector3i, Vector3i.ZERO, yaw)
	var reserved: Dictionary = {}
	for source_cells: Array[Vector3i] in [recipe.solid_cells,
			recipe.headroom_cells]:
		for local: Vector3i in source_cells:
			var cell := FabricRecipe.transform_cell(local, origin, yaw)
			if public_air.has(cell):
				return {}
			reserved[cell] = true
	var components: Array[Dictionary] = [{"recipe_id": recipe_id,
		"origin": origin, "yaw_quarters": yaw}]
	return {"kind": &"straight", "recipe_id": recipe_id,
		"origin": origin, "yaw_quarters": yaw,
		"components": components, "reserved_cells": reserved,
		"visual_bounds": [FabricRecipe.lattice_transform(origin, yaw) \
			* recipe.local_clearance_bounds] as Array[AABB],
		"visual_clearance_cells": _skywalk_visual_clearance_cells(components,
			program),
		"owner_endpoints": [
			{"slot_signature": left.slot_signature(),
				"cell": left_endpoint.cell, "facing": left_endpoint.facing},
			{"slot_signature": right.slot_signature(),
				"cell": right_endpoint.cell, "facing": right_endpoint.facing},
		]}


static func _proposal_block_for_cell(proposal: Dictionary,
		cell: Vector3i) -> int:
	return _proposal_storey_for_cell(proposal, cell) / 2


static func _proposal_storey_for_cell(proposal: Dictionary,
		cell: Vector3i) -> int:
	var origin := proposal.origin as Vector3i
	return floori(float(cell.y - origin.y) \
		/ float(WarrenSpatialGrid.STOREY_CELLS))


static func _forced_block_fits(grid: WarrenSpatialGrid, proposal: Dictionary,
		block: int, offset: Vector2i) -> bool:
	var storeys := int(proposal.storeys)
	var start_storey := block * 2
	if start_storey >= storeys:
		return false
	for value: Variant in _forced_block_cells(proposal, block, offset).keys():
		var cell := value as Vector3i
		if not grid.contains(cell) \
				or grid.use_at(cell) != WarrenSpatialGrid.Use.ALLOCATABLE:
			return false
	return true


static func _forced_block_cells(proposal: Dictionary, block: int,
		offset: Vector2i) -> Dictionary:
	var storeys := int(proposal.storeys)
	var origin := proposal.origin as Vector3i
	var base_plate := _proposal_base_plate(proposal)
	var out: Dictionary = {}
	for storey in range(block * 2, mini(storeys, block * 2 + 2)):
		for column_value: Variant in base_plate.keys():
			var column := column_value as Vector2i
			for y_offset in WarrenSpatialGrid.STOREY_CELLS:
				out[Vector3i(column.x + offset.x,
					origin.y + storey * WarrenSpatialGrid.STOREY_CELLS + y_offset,
					column.y + offset.y)] = true
	return out


static func _sets_overlap(left: Dictionary, right: Dictionary) -> bool:
	for value: Variant in left.keys():
		if right.has(value):
			return true
	return false


static func _translate_skywalk_reservation(source: Dictionary,
		delta: Vector3i) -> Dictionary:
	var out := source.duplicate(true)
	var cells: Dictionary = {}
	for value: Variant in (source.reserved_cells as Dictionary).keys():
		cells[(value as Vector3i) + delta] = true
	out["reserved_cells"] = cells
	var clearance: Dictionary = {}
	for value: Variant in (source.get("visual_clearance_cells", {}) \
			as Dictionary).keys():
		clearance[(value as Vector3i) + delta] = true
	out["visual_clearance_cells"] = clearance
	var visual_bounds: Array[AABB] = []
	for bounds_value: Variant in source.get("visual_bounds", []):
		var bounds := bounds_value as AABB
		bounds.position += Vector3(delta) * FabricRecipe.CELL_SIZE
		visual_bounds.append(bounds)
	out["visual_bounds"] = visual_bounds
	var endpoints: Array[Dictionary] = []
	for value: Variant in source.get("owner_endpoints", []):
		var endpoint := (value as Dictionary).duplicate(true)
		endpoint["cell"] = (endpoint.cell as Vector3i) + delta
		endpoints.append(endpoint)
	out["owner_endpoints"] = endpoints
	var components: Array[Dictionary] = []
	for value: Variant in source.get("components", []):
		var component := (value as Dictionary).duplicate(true)
		component["origin"] = (component.origin as Vector3i) + delta
		components.append(component)
	out["components"] = components
	out["origin"] = (source.get("origin", Vector3i()) as Vector3i) + delta
	return out


static func _skywalk_body_fits_grid(grid: WarrenSpatialGrid,
		body: Dictionary) -> bool:
	for value: Variant in body.keys():
		var cell := value as Vector3i
		if not grid.contains(cell) or grid.use_at(cell) not in [
				WarrenSpatialGrid.Use.OUTSIDE,
				WarrenSpatialGrid.Use.ALLOCATABLE] \
				or (grid.reservation_bits_at(cell) & (
					WarrenSpatialGrid.Reservation.FEATURE \
					| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE)) != 0:
			return false
	return true


static func _skywalk_grid_conflicts(grid: WarrenSpatialGrid,
		cells: Dictionary, require_open_mass: bool) -> Array[Dictionary]:
	## Harness diagnostic for the very small court-cantilever frontier. Keep the
	## exact reason visible instead of treating public air, daylight, bounds, and
	## an earlier feature reservation as one opaque "does not fit" result.
	var out: Array[Dictionary] = []
	for value: Variant in cells.keys():
		var cell := value as Vector3i
		var in_bounds := grid.contains(cell)
		var use := grid.use_at(cell)
		var bits := grid.reservation_bits_at(cell)
		var conflicts := not in_bounds or (bits & (
			WarrenSpatialGrid.Reservation.FEATURE \
			| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE)) != 0
		if require_open_mass:
			conflicts = conflicts or use not in [
				WarrenSpatialGrid.Use.OUTSIDE,
				WarrenSpatialGrid.Use.ALLOCATABLE]
		if not conflicts:
			continue
		out.append({"cell": cell, "in_bounds": in_bounds,
			"use": use, "reservation_bits": bits,
			"owner": grid.owner_name_at(cell)})
		if out.size() >= 12:
			break
	return out


static func _skywalk_protected_conflicts(clearance: Dictionary,
		protected_owners: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for value: Variant in clearance.keys():
		var owners := protected_owners.get(value, {}) as Dictionary
		for owner_value: Variant in owners.keys():
			var owner_id := StringName(owner_value)
			if not _protected_owner_is_feature(owner_id):
				continue
			out.append({"cell": value as Vector3i, "owner": owner_id})
			if out.size() >= 12:
				return out
	return out


static func _skywalk_clearance_fits_grid(grid: WarrenSpatialGrid,
		clearance: Dictionary) -> bool:
	for value: Variant in clearance.keys():
		var cell := value as Vector3i
		if not grid.contains(cell) or (grid.reservation_bits_at(cell) & (
				WarrenSpatialGrid.Reservation.FEATURE \
				| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE)) != 0:
			return false
	return true


static func _skywalk_clearance_fits_protected(clearance: Dictionary,
		protected_owners: Dictionary) -> bool:
	for value: Variant in clearance.keys():
		for owner_value: Variant in (protected_owners.get(value, {}) \
				as Dictionary).keys():
			if _protected_owner_is_feature(StringName(owner_value)):
				return false
	return true


static func _protected_owner_is_feature(owner_id: StringName) -> bool:
	var text := String(owner_id)
	return text.begins_with("spatial.feature.") \
		or text.begins_with("spatial.skywalk.reserve.") \
		or text.begins_with("spatial.skywalk.trial.")


static func _lower_public_cover(body: Dictionary,
		public_air: Dictionary) -> int:
	var minimum_y := 2147483647
	for value: Variant in body.keys():
		minimum_y = mini(minimum_y, (value as Vector3i).y)
	var columns: Dictionary = {}
	for value: Variant in body.keys():
		var cell := value as Vector3i
		if cell.y != minimum_y:
			continue
		for down in range(1, 9):
			if public_air.has(cell + Vector3i.DOWN * down):
				columns[Vector2i(cell.x, cell.z)] = true
				break
	return columns.size()


static func _enclosure_route_walk(
		realm: SectionalPublicRealmPlan) -> Dictionary:
	## Keep skywalk planning and final visual-quality measurement on one route
	## definition. Courts, terraces, the approach landing, and short bridges are
	## intentionally allowed open edges and therefore do not belong to the canyon
	## overhead denominator in `SettlementFabricSolver._audit_enclosure`.
	var out: Dictionary = {}
	if realm == null:
		return out
	for node_value: PublicRealmNode in realm.nodes:
		if node_value.is_landing \
				or node_value.episode_kind == PublicRealmNode.EpisodeKind.COURT \
				or node_value.episode_kind == PublicRealmNode.EpisodeKind.TERRACE \
				or node_value.episode_kind \
					== PublicRealmNode.EpisodeKind.SHORT_BRIDGE:
			continue
		for cell: Vector3i in node_value.surface_cells:
			out[cell] = node_value.stable_id
	return out


static func _uncovered_route_overhead_supply_audit(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan) -> Dictionary:
	## Phase B evidence, measured pre-discard: for every canonical route cell
	## lacking occupied overhead in the final 2-6 band window, distinguish
	## trimmed massif supply above it (a partition/selection failure the
	## source beam could still claim as rooms) from genuinely empty sky (a
	## massing failure only the carver or an authored street-spanning gallery
	## can add). A huge discarded source shell must not hide a visible
	## planning hole.
	var realm := WarrenVolumePublicRealmAdapter.from_volume(volume)
	if realm == null:
		return {}
	var route_walk := _enclosure_route_walk(realm)
	var covered := 0
	var trimmed_supply_cells: Array[Vector3i] = []
	var no_mass_cells: Array[Vector3i] = []
	for cell_value: Variant in route_walk:
		var cell := cell_value as Vector3i
		var has_private := false
		var has_trimmed := false
		for rise in range(2, 7):
			var above: Vector3i = cell + Vector3i.UP * rise
			var use := grid.use_at(above)
			if use == WarrenSpatialGrid.Use.PRIVATE_VOLUME:
				has_private = true
				break
			if use == WarrenSpatialGrid.Use.ALLOCATABLE:
				has_trimmed = true
		if has_private:
			covered += 1
		elif has_trimmed:
			trimmed_supply_cells.append(cell)
		else:
			no_mass_cells.append(cell)
	trimmed_supply_cells.sort_custom(_cell_less)
	no_mass_cells.sort_custom(_cell_less)
	var trimmed_preview := PackedStringArray()
	for cell: Vector3i in trimmed_supply_cells.slice(0, 48):
		trimmed_preview.append("%d:%d:%d" % [cell.x, cell.y, cell.z])
	var no_mass_preview := PackedStringArray()
	for cell: Vector3i in no_mass_cells.slice(0, 48):
		no_mass_preview.append("%d:%d:%d" % [cell.x, cell.y, cell.z])
	return {
		"route_overhead_supply_route_cell_count": route_walk.size(),
		"route_overhead_supply_covered_cell_count": covered,
		"uncovered_route_trimmed_supply_cell_count":
			trimmed_supply_cells.size(),
		"uncovered_route_no_mass_cell_count": no_mass_cells.size(),
		"uncovered_route_trimmed_supply_cells": trimmed_preview,
		"uncovered_route_no_mass_cells": no_mass_preview,
	}


static func _route_cells_covered_by_body(body: Dictionary,
		route_walk: Dictionary) -> Dictionary:
	## Mirror the final inhabited-overhead height window exactly. Candidate body
	## cells are semantic occupied volume, so generic exterior air beneath a link
	## never earns credit unless it is also a measured route surface.
	var out: Dictionary = {}
	for route_value: Variant in route_walk.keys():
		var route_cell := route_value as Vector3i
		for rise in range(2, 7):
			if body.has(route_cell + Vector3i.UP * rise):
				out[route_cell] = true
				break
	return out


static func _composition_route_covered_cells(composition: Dictionary,
		route_walk: Dictionary) -> Dictionary:
	var body: Dictionary = {}
	for lineage_value: Variant in (composition.get("lineages", {}) \
			as Dictionary).values():
		var lineage := lineage_value as Dictionary
		for block_value: Variant in lineage.get("blocks", []) as Array:
			for cell: Vector3i in (block_value as Dictionary).get(
					"cells", []) as Array[Vector3i]:
				body[cell] = true
	return _route_cells_covered_by_body(body, route_walk)


static func _annotate_skywalk_route_coverage(
		candidates: Array[Dictionary], route_walk: Dictionary,
		base_route_covered: Dictionary = {}) -> void:
	for candidate: Dictionary in candidates:
		var covered := _route_cells_covered_by_body(
			candidate.get("body", {}) as Dictionary, route_walk)
		var covered_cells: Array[Vector3i] = []
		covered_cells.assign(covered.keys())
		covered_cells.sort_custom(_cell_less)
		var marginal_cells: Array[Vector3i] = []
		for cell: Vector3i in covered_cells:
			if not base_route_covered.has(cell):
				marginal_cells.append(cell)
		candidate["route_cover_cells"] = covered_cells
		candidate["route_cover_count"] = covered_cells.size()
		candidate["marginal_route_cover_cells"] = marginal_cells
		candidate["marginal_route_cover_count"] = marginal_cells.size()


static func _skywalk_combination_route_cover_count(
		combination: Array[Dictionary], field: StringName) -> int:
	var covered: Dictionary = {}
	for candidate: Dictionary in combination:
		for cell: Vector3i in candidate.get(field, []) as Array[Vector3i]:
			covered[cell] = true
	return covered.size()


static func _skywalk_blocker_count(body: Dictionary,
		protected_owners: Dictionary, endpoint_owners: Dictionary) -> int:
	var blockers: Dictionary = {}
	for value: Variant in body.keys():
		for owner_value: Variant in (protected_owners.get(value, {}) \
				as Dictionary).keys():
			var owner_id := StringName(owner_value)
			if not endpoint_owners.has(owner_id):
				blockers[owner_id] = true
	return blockers.size()


static func _skywalk_candidates_compatible(left: Dictionary,
		right: Dictionary) -> bool:
	if left.pair_key == right.pair_key:
		return false
	var left_clearance := left.get("clearance", left.body) as Dictionary
	var right_clearance := right.get("clearance", right.body) as Dictionary
	if _skywalk_visual_bounds_overlap(left.reservation as Dictionary,
			right.reservation as Dictionary):
		return false
	for value: Variant in left_clearance.keys():
		if (right.priority_cells as Dictionary).has(value):
			return false
	for value: Variant in right_clearance.keys():
		if (left.priority_cells as Dictionary).has(value):
			return false
	for value: Variant in (left.body as Dictionary).keys():
		if (right.body as Dictionary).has(value):
			return false
		if (right.priority_cells as Dictionary).has(value):
			return false
	for value: Variant in (right.body as Dictionary).keys():
		if (left.priority_cells as Dictionary).has(value):
			return false
	for value: Variant in (left.priority_cells as Dictionary).keys():
		if (right.priority_cells as Dictionary).has(value) \
				and StringName((left.priority_cells as Dictionary)[value]) \
					!= StringName((right.priority_cells as Dictionary)[value]):
			return false
	for parcel_value: Variant in (left.forced_offsets as Dictionary).keys():
		var parcel_id := StringName(parcel_value)
		if not (right.forced_offsets as Dictionary).has(parcel_id):
			continue
		var left_blocks := (left.forced_offsets as Dictionary)[parcel_id] \
			as Dictionary
		var right_blocks := (right.forced_offsets as Dictionary)[parcel_id] \
			as Dictionary
		for block_value: Variant in left_blocks.keys():
			if right_blocks.has(block_value) \
					and left_blocks[block_value] != right_blocks[block_value]:
				return false
	return true


static func _skywalk_visual_bounds_overlap(left: Dictionary,
		right: Dictionary) -> bool:
	for left_value: Variant in left.get("visual_bounds", []):
		var left_bounds := left_value as AABB
		for right_value: Variant in right.get("visual_bounds", []):
			if SettlementFabricPlan._aabb_overlaps_volume(left_bounds,
					right_value as AABB):
				return true
	return false


static func _skywalk_selection_preserves_endpoint_rooms(
		grid: WarrenSpatialGrid, volume: WarrenVolumePlan,
		selected: Array[Dictionary],
		proposals: Array[Dictionary], protected_owners: Dictionary,
		world_seed: int) -> bool:
	## Validate a whole connector set against the same priority field and exact
	## composition solver used by `_partition_rooms`. Individual endpoint blocks
	## can each fit while a third feature displaces the rest of one endpoint
	## parcel; accepting that set would create a one-ended skywalk after packing.
	_last_skywalk_selection_failure = ""
	var trial_owners := protected_owners.duplicate(true)
	var forced_by_parcel: Dictionary = {}
	for candidate_index in selected.size():
		var candidate := selected[candidate_index]
		for cell_value: Variant in (candidate.priority_cells as Dictionary).keys():
			trial_owners[cell_value] = {
				StringName((candidate.priority_cells as Dictionary)[cell_value]): true,
			}
		var reservation_owner := StringName("spatial.skywalk.trial.%02d" \
			% candidate_index)
		var body := candidate.body as Dictionary
		for cell_value: Variant in body.keys():
			if not trial_owners.has(cell_value):
				trial_owners[cell_value] = {}
			(trial_owners[cell_value] as Dictionary)[reservation_owner] = true
		var reservation := candidate.reservation as Dictionary
		var allowed_endpoint_owners := _skywalk_endpoint_owner_set(reservation)
		for cell_value: Variant in (candidate.get("clearance", body) \
				as Dictionary).keys():
			if body.has(cell_value):
				continue
			if not trial_owners.has(cell_value):
				trial_owners[cell_value] = {}
			(trial_owners[cell_value] as Dictionary)[reservation_owner] = \
				allowed_endpoint_owners
		for parcel_value: Variant in (candidate.forced_offsets \
				as Dictionary).keys():
			var parcel_id := StringName(parcel_value)
			if not forced_by_parcel.has(parcel_id):
				forced_by_parcel[parcel_id] = {}
			var blocks := (candidate.forced_offsets as Dictionary)[parcel_id] \
				as Dictionary
			for block_value: Variant in blocks.keys():
				var block := int(block_value)
				var wanted := blocks[block_value] as Vector2i
				if (forced_by_parcel[parcel_id] as Dictionary).has(block) \
						and (forced_by_parcel[parcel_id] \
							as Dictionary)[block] != wanted:
					_last_skywalk_selection_failure = "forced-offset conflict"
					return false
				(forced_by_parcel[parcel_id] as Dictionary)[block] = wanted
	var proposal_by_id: Dictionary = {}
	var solved_offsets_by_parcel: Dictionary = {}
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		proposal_by_id[parcel.stable_id] = proposal
	var endpoint_parcel_ids := forced_by_parcel.duplicate()
	var required_parcel_ids := forced_by_parcel.duplicate()
	# Named feature-clearance allowances identify structural endpoint parcels.
	# The preplanned market has no shifted block, so it would otherwise fall out
	# of this skywalk-only forced-offset set even though its exact backing socket
	# is just as mandatory as either end of a bridge.
	for owners_value: Variant in trial_owners.values():
		for allowance_value: Variant in (owners_value as Dictionary).values():
			if not allowance_value is Dictionary:
				continue
			for parcel_value: Variant in (allowance_value as Dictionary).keys():
				var parcel_id := StringName(parcel_value)
				if _protected_owner_is_feature(parcel_id):
					continue
				endpoint_parcel_ids[parcel_id] = true
				required_parcel_ids[parcel_id] = true
	var court_floors: Dictionary = {}
	for macro: Vector3i in volume.courtyard_cells:
		for floor_cell: Vector3i in _fine_square(macro):
			court_floors[floor_cell] = true
	var court_neighbor_cells := _courtyard_neighbor_cells(court_floors)
	for proposal: Dictionary in proposals:
		var parcel := proposal.parcel as WarrenBuildingParcel
		for occupied: Vector3i in StaggeredFabricCompiler \
				.proposal_occupied_cells(proposal):
			if court_neighbor_cells.has(occupied):
				required_parcel_ids[parcel.stable_id] = true
				break
	for parcel_value: Variant in required_parcel_ids.keys():
		var parcel_id := StringName(parcel_value)
		var proposal := proposal_by_id.get(parcel_id, {}) as Dictionary
		if proposal.is_empty():
			_last_skywalk_selection_failure = "missing endpoint proposal"
			return false
		var parcel := proposal.parcel as WarrenBuildingParcel
		var storeys := int(proposal.storeys)
		var origin := proposal.origin as Vector3i
		var threshold := WarrenParcelConstruction.threshold_cell(parcel)
		var addressed_storey := clampi(floori(float(threshold.y - origin.y) \
			/ float(WarrenSpatialGrid.STOREY_CELLS)), 0, storeys - 1)
		var forced: Dictionary = {0: Vector2i.ZERO,
			floori(float(addressed_storey) / 2.0): Vector2i.ZERO}
		for court_block_value: Variant in _proposal_court_fixed_blocks(proposal,
				court_neighbor_cells).keys():
			forced[int(court_block_value)] = Vector2i.ZERO
		for block_value: Variant in (forced_by_parcel.get(parcel_id, {}) \
				as Dictionary).keys():
			var block := int(block_value)
			var wanted := (forced_by_parcel[parcel_id] \
				as Dictionary)[block] as Vector2i
			if forced.has(block) and forced[block] != wanted:
				_last_skywalk_selection_failure = "addressed-block offset conflict"
				return false
			forced[block] = wanted
		var solved_offsets := _composition_offsets(grid,
			_proposal_base_plate(proposal), origin.y, storeys, trial_owners,
			parcel_id, world_seed, forced)
		if solved_offsets.is_empty():
			if not endpoint_parcel_ids.has(parcel_id):
				continue
			_last_skywalk_selection_failure = "endpoint composition failed: %s" % \
				parcel_id
			return false
		solved_offsets_by_parcel[parcel_id] = solved_offsets
	# Court enclosure is owned by the separately selected occupied cantilever
	# room plus the two fixed parcel walls. Independent skywalks are therefore
	# judged only on their own endpoints and 3D circulation here; the final court
	# transaction re-proves its real PRIVATE_VOLUME sides after all features land.
	for candidate: Dictionary in selected:
		var reservation := candidate.reservation as Dictionary
		var owner_ids := reservation.get("owner_parcel_ids", []) as Array
		var endpoints := reservation.get("owner_endpoints", []) as Array
		var offset_endpoint_count := 0
		for endpoint_index in mini(owner_ids.size(), endpoints.size()):
			var parcel_id := StringName(owner_ids[endpoint_index])
			if String(parcel_id).begins_with("spatial.feature.landmark."):
				offset_endpoint_count += 1
				continue
			var proposal := proposal_by_id.get(parcel_id, {}) as Dictionary
			var offsets := solved_offsets_by_parcel.get(parcel_id, []) \
				as Array[Vector2i]
			if proposal.is_empty() or offsets.is_empty():
				_last_skywalk_selection_failure = "endpoint solve missing after beam"
				return false
			var endpoint := endpoints[endpoint_index] as Dictionary
			var storey := _proposal_storey_for_cell(proposal,
				endpoint.cell as Vector3i)
			if storey <= 0:
				continue
			var current_block := storey / 2
			var lower_block := (storey - 1) / 2
			if current_block < offsets.size() and lower_block < offsets.size() \
					and offsets[current_block] != offsets[lower_block]:
				offset_endpoint_count += 1
		if offset_endpoint_count < 1:
			_last_skywalk_selection_failure = "no exact floorplate break"
			return false
	_last_skywalk_selection_failure = ""
	return true


static func _courtyard_neighbor_cells(court_floors: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for floor_value: Variant in court_floors.keys():
		var floor_cell := floor_value as Vector3i
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			if court_floors.has(floor_cell + direction):
				continue
			for y_offset in WarrenSpatialGrid.STOREY_CELLS:
				out[floor_cell + direction + Vector3i.UP * y_offset] = true
	return out


static func _courtyard_floor_cells(volume: WarrenVolumePlan) -> Dictionary:
	var out: Dictionary = {}
	if volume == null:
		return out
	for macro: Vector3i in volume.courtyard_cells:
		for floor: Vector3i in _fine_square(macro):
			out[floor] = true
	return out


static func _proposal_courtyard_side_mask(volume: WarrenVolumePlan,
		proposals: Array[Dictionary]) -> int:
	var occupied: Dictionary = {}
	for proposal: Dictionary in proposals:
		for cell: Vector3i in _proposal_private_cells(proposal):
			occupied[cell] = true
	return _courtyard_address_side_mask_from_occupied(
		_courtyard_floor_cells(volume), occupied)


static func _composition_courtyard_side_mask(court_floors: Dictionary,
		composition: Dictionary, extra_occupied: Dictionary = {}) -> int:
	## Court walls are an output property of the final 3D room tiling. Source
	## proposals do not count: a parcel whose exact block cannot survive a market,
	## landmark, or skywalk reservation must not leave behind a fictional facade.
	var occupied := extra_occupied.duplicate()
	for lineage_value: Variant in (composition.get("lineages", {}) \
			as Dictionary).values():
		var lineage := lineage_value as Dictionary
		for block_value: Variant in (lineage.get("blocks", []) as Array):
			var block := block_value as Dictionary
			for cell: Vector3i in block.get("cells", []) as Array[Vector3i]:
				occupied[cell] = true
	return _courtyard_address_side_mask_from_occupied(court_floors, occupied)


static func _composition_courtyard_side_owner_ids(court_floors: Dictionary,
		composition: Dictionary) -> Array[StringName]:
	## Bind the room lineages that make a macro court wall before landmark search.
	## A prefab may vary the skyline; it may not erase one of the three sides that
	## made this court candidate structurally admissible.
	var owners: Dictionary = {}
	for lineage_value: Variant in (composition.get("lineages", {}) \
			as Dictionary).values():
		var lineage := lineage_value as Dictionary
		var proposal := lineage.get("proposal", {}) as Dictionary
		var parcel := proposal.get("parcel") as WarrenBuildingParcel
		if parcel == null:
			continue
		var cells: Dictionary = {}
		for block_value: Variant in lineage.get("blocks", []) as Array:
			for cell: Vector3i in (block_value as Dictionary).get(
					"cells", []) as Array[Vector3i]:
				cells[cell] = true
		var addresses_court := false
		for floor_value: Variant in court_floors.keys():
			var floor := floor_value as Vector3i
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				if court_floors.has(floor + direction):
					continue
				for y_offset in WarrenSpatialGrid.STOREY_CELLS:
					if cells.has(floor + direction + Vector3i.UP * y_offset):
						addresses_court = true
						break
				if addresses_court:
					break
			if addresses_court:
				break
		if addresses_court:
			owners[parcel.stable_id] = true
	var out: Array[StringName] = []
	out.assign(owners.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out


static func _side_mask_count(side_mask: int) -> int:
	var count := 0
	for bit in 4:
		count += int((side_mask & (1 << bit)) != 0)
	return count


static func _proposal_private_cells(proposal: Dictionary) -> Array[Vector3i]:
	if proposal.is_empty():
		return [] as Array[Vector3i]
	var storeys := int(proposal.storeys)
	var offsets: Array[Vector2i] = []
	for _block in ceili(float(storeys) / 2.0):
		offsets.append(Vector2i.ZERO)
	return _segment_cells(_proposal_base_plate(proposal),
		(proposal.origin as Vector3i).y, offsets, 0, storeys)


static func _annotate_skywalk_courtyard_side_masks(volume: WarrenVolumePlan,
		candidates: Array[Dictionary]) -> void:
	var floors := _courtyard_floor_cells(volume)
	for candidate: Dictionary in candidates:
		candidate["courtyard_side_mask"] = \
			_courtyard_address_side_mask_from_occupied(floors,
				candidate.body as Dictionary)


static func _skywalk_selection_addresses_courtyard(
		selected: Array[Dictionary], parcel_side_mask: int) -> bool:
	## Cheap topology gate used before the exact composition proof.  An occupied
	## connector is allowed to complete the courtyard enclosure only when its
	## measured PRIVATE_VOLUME body itself runs along the court edge; endpoints,
	## clearance boxes, and decorative meshes do not count.
	var side_mask := parcel_side_mask
	for candidate: Dictionary in selected:
		side_mask |= int(candidate.get("courtyard_side_mask", 0))
	var side_count := 0
	for bit in 4:
		side_count += int((side_mask & (1 << bit)) != 0)
	return side_count >= WarrenSpatialFeatureSolver.MIN_COURT_SIDE_COUNT


static func _courtyard_addressing_candidate_count(candidates: Array[Dictionary],
		parcel_side_mask: int) -> int:
	var count := 0
	for candidate: Dictionary in candidates:
		count += int(_skywalk_selection_addresses_courtyard(
			[candidate] as Array[Dictionary], parcel_side_mask))
	return count


static func _courtyard_address_side_mask_from_occupied(
		court_floors: Dictionary, occupied: Dictionary) -> int:
	var side_mask := 0
	var directions: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT,
		Vector3i.FORWARD, Vector3i.BACK]
	for direction_index in directions.size():
		var direction := directions[direction_index]
		for floor_value: Variant in court_floors.keys():
			var floor_cell := floor_value as Vector3i
			if court_floors.has(floor_cell + direction):
				continue
			for y_offset in WarrenSpatialGrid.STOREY_CELLS:
				if occupied.has(floor_cell + direction \
						+ Vector3i.UP * y_offset):
					side_mask |= 1 << direction_index
					break
			if (side_mask & (1 << direction_index)) != 0:
				break
	return side_mask


static func _courtyard_address_side_count_from_occupied(
		court_floors: Dictionary, occupied: Dictionary) -> int:
	var side_mask := _courtyard_address_side_mask_from_occupied(court_floors,
		occupied)
	var side_count := 0
	for bit in 4:
		side_count += int((side_mask & (1 << bit)) != 0)
	return side_count


static func _proposal_court_fixed_blocks(proposal: Dictionary,
		court_neighbor_cells: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if proposal.is_empty() or court_neighbor_cells.is_empty():
		return out
	var block_count := ceili(float(int(proposal.storeys)) / 2.0)
	for block in block_count:
		for cell_value: Variant in _forced_block_cells(proposal, block,
				Vector2i.ZERO).keys():
			if court_neighbor_cells.has(cell_value):
				out[block] = Vector2i.ZERO
				break
	return out


static func _nested_dictionary_entry_count(values: Dictionary) -> int:
	var out := 0
	for nested_value: Variant in values.values():
		out += (nested_value as Dictionary).size()
	return out


static func _solved_courtyard_address_side_count(court_floors: Dictionary,
		solved_offsets_by_parcel: Dictionary,
		proposal_by_id: Dictionary,
		selected_skywalks: Array[Dictionary] = []) -> int:
	var occupied: Dictionary = {}
	for parcel_value: Variant in solved_offsets_by_parcel.keys():
		var parcel_id := StringName(parcel_value)
		var proposal := proposal_by_id[parcel_id] as Dictionary
		var offsets := solved_offsets_by_parcel[parcel_id] as Array[Vector2i]
		var origin := proposal.origin as Vector3i
		for cell: Vector3i in _segment_cells(_proposal_base_plate(proposal),
				origin.y, offsets, 0, int(proposal.storeys)):
			occupied[cell] = parcel_id
	for candidate: Dictionary in selected_skywalks:
		for cell_value: Variant in (candidate.body as Dictionary).keys():
			occupied[cell_value] = StringName("occupied.court.connector")
	return _courtyard_address_side_count_from_occupied(court_floors, occupied)


static func _composition_offsets(grid: WarrenSpatialGrid,
		base_plate: Dictionary, origin_y: int, storeys: int,
		protected_owners: Dictionary, parcel_id: StringName,
		world_seed: int, forced_offsets: Dictionary) -> Array[Vector2i]:
	var block_count := ceili(float(storeys) / 2.0)
	var out: Array[Vector2i] = []
	var directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN,
		Vector2i.LEFT, Vector2i.UP]
	var parcel_hash := String(parcel_id).hash()
	for block in block_count:
		var start_storey := block * 2
		var end_storey := mini(storeys, start_storey + 2)
		# The base block and the block carrying the addressed door retain the
		# authored parcel phase.  All other blocks may shift by one fine cell.
		if forced_offsets.has(block):
			var forced := forced_offsets[block] as Vector2i
			if not _plate_fits(grid, base_plate, forced, origin_y,
					start_storey, end_storey, protected_owners, parcel_id):
				return [] as Array[Vector2i]
			out.append(forced)
			continue
		var previous := out[block - 1]
		var chosen := Vector2i(2147483647, 2147483647)
		# Start the 3D room grammar from a coherent structural column. The former
		# one-cell lateral shift was only a provisional anti-tower heuristic, but it
		# left a one-cell strip of every lower room exposed and forced the roof
		# compiler to tile dozens of plank shoulders. WarrenRoomCompositionPlanner
		# now owns macroscopic changes of shape, merges, cantilevers, and tower
		# relief, so preserve the previous phase whenever it is genuinely available.
		if _plate_fits(grid, base_plate, previous, origin_y,
				start_storey, end_storey, protected_owners, parcel_id):
			chosen = previous
		var start := posmod(Helper._mix64(world_seed ^ parcel_hash \
			^ block * 0x45d9f3b), directions.size())
		for direction_offset in directions.size() if chosen.x == 2147483647 \
				else 0:
			var candidate := previous + directions[
				posmod(start + direction_offset, directions.size())]
			if candidate.length_squared() > 4:
				continue
			if _plate_fits(grid, base_plate, candidate, origin_y,
					start_storey, end_storey, protected_owners, parcel_id):
				chosen = candidate
				break
		# A failed lateral proposal may keep its previous phase only when that
		# exact volume is still allocatable.  The former unconditional fallback
		# let two buildings claim the same residual-mass cells.
		if chosen.x == 2147483647 and _plate_fits(grid, base_plate,
				Vector2i.ZERO, origin_y, start_storey, end_storey,
				protected_owners, parcel_id):
			chosen = Vector2i.ZERO
		if chosen.x == 2147483647:
			# A collision in an optional crown must not erase the valid terrain
			# root, doorway, court wall, or bridge endpoint below it. End the
			# lineage at the last complete two-storey band when no later exact
			# interface depends on the missing mass. This is a real shorter house,
			# and gives the mountain another stepped roof break; it is not a partial
			# or unsupported room stamp.
			var later_forced := false
			for forced_block_value: Variant in forced_offsets.keys():
				if int(forced_block_value) >= block:
					later_forced = true
					break
			if not out.is_empty() and not later_forced:
				return out
			return [] as Array[Vector2i]
		out.append(chosen)
	return out


static func _maze_unfloored_address_detail(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, parcel: WarrenBuildingParcel) -> String:
	## Why `_parcel_address_has_public_floor` refused this parcel's door, in
	## the vocabulary of the thing that decides it: which fine lane the door
	## opens onto, what the grid made of that lane, and whether the SOURCE
	## calls the macro square a walk cell, a transition, or neither.
	##
	## Maze mode only and only on the failure path. A door faces a passage cell
	## BY CONSTRUCTION in the plot model -- the plot planner put it there -- so
	## a landing with no floor is a disagreement between the planner and the
	## carve, and naming which of the three it is decides where the fix goes.
	var threshold := WarrenParcelConstruction.threshold_cell(parcel)
	if threshold.x == 2147483647:
		return "parcel has no authored threshold cell"
	var landing := threshold + Vector3i(parcel.frontage_direction.x, 0,
		parcel.frontage_direction.y)
	var macro := Vector3i(floori(float(landing.x) / 2.0), landing.y,
		floori(float(landing.z) / 2.0))
	var is_walk := volume.walk_cells.has(macro)
	var is_transition := false
	for transition: WarrenVolumeTransition in volume.transitions:
		for surface: Vector3i in transition.surface_cells():
			if surface == landing:
				is_transition = true
				break
		if is_transition:
			break
	var floor_claim := grid.face_claim(landing, Vector3i.DOWN)
	return ("landing %s (macro %s) use %d floor kind %d owner %s; " \
		+ "source walk=%s transition_surface=%s") % [landing, macro,
		grid.use_at(landing), int(floor_claim.get("kind", -1)),
		floor_claim.get("owner", &"-"), is_walk, is_transition]


static func _maze_exact_composition_conflict(grid: WarrenSpatialGrid,
		base_plate: Dictionary, origin_y: int, storeys: int,
		protected_owners: Dictionary, parcel_id: StringName) -> String:
	## TASK C5c RULING 4's diagnosis. `_composition_offsets` returns an empty
	## offset list without saying which cell refused it, and on a maze town
	## that is the gate almost every uncomposed parcel dies at. Re-walk the
	## parcel's own UNSHIFTED plate and name the first cell that is not free
	## mass: its band, the use it carries, and whoever else claimed it.
	##
	## Maze mode only and only on the failure path, so a composed parcel pays
	## nothing for it. It reads exactly what `_plate_fits` reads, including the
	## paired-allowance escape, so the two can never disagree about what a
	## conflict is.
	var columns: Array[Vector2i] = []
	columns.assign(base_plate.keys())
	columns.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	for storey in storeys:
		for y_offset in WarrenSpatialGrid.STOREY_CELLS:
			var band := origin_y \
				+ storey * WarrenSpatialGrid.STOREY_CELLS + y_offset
			for column: Vector2i in columns:
				var cell := Vector3i(column.x, band, column.y)
				if not grid.contains(cell):
					return "storey %d cell %s is outside the grid" % [storey,
						cell]
				if grid.use_at(cell) != WarrenSpatialGrid.Use.ALLOCATABLE:
					return "storey %d cell %s is use %d owned by %s" % [
						storey, cell, grid.use_at(cell),
						grid.owner_name_at(cell)]
				var others: Array[StringName] = []
				for owner_value: Variant in (protected_owners.get(cell,
						{}) as Dictionary).keys():
					var other := StringName(owner_value)
					if other == parcel_id:
						continue
					var allowance: Variant = (protected_owners[cell] \
						as Dictionary)[owner_value]
					if allowance is Dictionary \
							and (allowance as Dictionary).has(parcel_id):
						continue
					others.append(other)
				if others.is_empty():
					continue
				others.sort()
				return "storey %d cell %s is claimed by %s" % [storey, cell,
					others]
	return "no unshifted conflict"


static func _plate_fits(grid: WarrenSpatialGrid, base_plate: Dictionary,
		offset: Vector2i, origin_y: int, start_storey: int, end_storey: int,
		protected_owners: Dictionary, parcel_id: StringName) -> bool:
	for storey in range(start_storey, end_storey):
		for column_value: Variant in base_plate.keys():
			var column := column_value as Vector2i
			for y_offset in WarrenSpatialGrid.STOREY_CELLS:
				var cell := Vector3i(column.x + offset.x,
					origin_y + storey * WarrenSpatialGrid.STOREY_CELLS + y_offset,
					column.y + offset.y)
				if not grid.contains(cell) \
						or grid.use_at(cell) != WarrenSpatialGrid.Use.ALLOCATABLE:
					return false
				var owners := protected_owners.get(cell, {}) as Dictionary
				for protected_id_value: Variant in owners.keys():
					if StringName(protected_id_value) == parcel_id:
						continue
					var allowance: Variant = owners[protected_id_value]
					if allowance is Dictionary \
							and (allowance as Dictionary).has(parcel_id):
						continue
					return false
	return true


static func _composition_segments(offsets: Array[Vector2i],
		storeys: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var start_storey := 0
	for block in range(1, offsets.size()):
		if offsets[block] == offsets[block - 1]:
			out.append(Vector2i(start_storey, block * 2))
			start_storey = block * 2
	out.append(Vector2i(start_storey, storeys))
	return out


static func _segment_cells(base_plate: Dictionary, origin_y: int,
		offsets: Array[Vector2i], start_storey: int,
		end_storey: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var complete_end_storey := mini(end_storey, offsets.size() * 2)
	for storey in range(start_storey, complete_end_storey):
		var offset := offsets[storey / 2]
		for column_value: Variant in base_plate.keys():
			var column := column_value as Vector2i
			for y_offset in WarrenSpatialGrid.STOREY_CELLS:
				out.append(Vector3i(column.x + offset.x,
					origin_y + storey * WarrenSpatialGrid.STOREY_CELLS + y_offset,
					column.y + offset.y))
	return out


static func _stamp_maze_back_rooms(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, parcels: WarrenParcelPlan,
		proposals: Array[Dictionary],
		buildings: Array[WarrenBuildingVolume],
		supports: WarrenSupportGraph, required_supports: Array[StringName],
		terrain_support_ids: Array[StringName],
		support_edges: Array[Dictionary], protected_owners: Dictionary,
		construction_program: SettlementFabricProgram) -> Dictionary:
	## The DIRECTED residual pass. The plot planner already decided which mass
	## belongs to which house, so the cells a house's door rectangle left over
	## are not something composition has to discover: each `maze_back_rooms`
	## record is cut into rectangles of the five-kind vocabulary and stamped as
	## rooms of the same building, at the same storeys, reaching the street
	## through the parcel's own volume instead of a threshold of their own.
	##
	## Runs BEFORE `_backfill_residual_rooms`, which then sees the result as
	## ordinary sealed fabric. A rectangle this pass cannot stand up is left in
	## `maze_back_room_unstamped_cells` for the greedy scan to try, never
	## silently dropped.
	##
	## Maze mode only: `maze_back_rooms` exists on no searched plan, so the
	## empty-record guard is what keeps legacy composition byte-identical.
	var empty := {"failed": false, "cell_count": 0, "stamped_cell_count": 0,
		"building_count": 0, "addressed_count": 0, "private_count": 0,
		"rectangle_count": 0, "record_count": 0,
		"refusals": {},
		"unstamped_cells": {"count": 0, "cells": [] as Array[Vector3i]}}
	var records := parcels.audit.get("maze_back_rooms", []) as Array
	if records.is_empty():
		return empty
	var parcel_by_id: Dictionary = {}
	for proposal: Dictionary in proposals:
		var proposed := proposal.parcel as WarrenBuildingParcel
		parcel_by_id[proposed.stable_id] = proposed
	var building_by_id: Dictionary = {}
	var building_by_cell: Dictionary = {}
	var access_by_parcel := _maze_back_room_access_roots(buildings,
		building_by_id, building_by_cell)
	# One work item per (rectangle, storey), ordered by BAND: no back room is
	# then ever stamped before the mass it stands on, and no lower room's roof
	# preflight has to argue with the upper room that will replace that roof.
	var work: Array[Dictionary] = []
	var candidate_cells: Dictionary = {}
	var refusals: Dictionary = {}
	var rectangle_count := 0
	for record_index in records.size():
		var record := records[record_index] as Dictionary
		var parcel := parcel_by_id.get(
			StringName(record["parcel_id"])) as WarrenBuildingParcel
		if parcel == null:
			# The parcel left composition, so its back rooms have no building
			# to belong to and no storeys to copy.
			_note_maze_back_room_refusal(refusals, "parcel left composition")
			continue
		var yaw := _yaw_for_direction(Vector3i.BACK,
			Vector3i(parcel.frontage_direction.x, 0,
				parcel.frontage_direction.y))
		var access_id := StringName(access_by_parcel.get(parcel.stable_id,
			&""))
		if yaw < 0 or access_id.is_empty():
			_note_maze_back_room_refusal(refusals,
				"parcel volume has no frontage yaw or access root")
			continue
		var floor_band := int(record["floor"])
		var rectangles := _maze_back_room_rectangles(
			record["cells"] as Array, parcel.frontage_direction)
		rectangle_count += rectangles.size()
		for rectangle_index in rectangles.size():
			var rectangle := rectangles[rectangle_index] as Dictionary
			for storey in parcel.storey_count():
				var band := floor_band \
					+ storey * WarrenSpatialGrid.STOREY_CELLS
				var cells := _maze_back_room_cells(
					rectangle["columns"] as Array[Vector2i], band)
				var allocatable := true
				for cell: Vector3i in cells:
					if grid.use_at(cell) \
							!= WarrenSpatialGrid.Use.ALLOCATABLE:
						allocatable = false
						continue
					# The denominator is the mass this pass could really have
					# taken: a plot band a street was bored through is not
					# back-room mass and never counts against the share.
					candidate_cells[cell] = true
				if not allocatable:
					_note_maze_back_room_refusal(refusals,
						"storey is not whole allocatable mass")
					continue
				work.append({"kind": StringName(rectangle["kind"]),
					"columns": rectangle["columns"], "cells": cells,
					"band": band, "yaw": yaw, "access_id": access_id,
					"record": record_index, "rectangle": rectangle_index,
					# A back room is the SAME building as the parcel in front
					# of it, so it wears the same roof contract (Task C5
					# ruling 1): a flat-roofed plot's back rooms are slab-
					# crowned too, never pitched.
					"flat_roof": parcel.flat_roof})
	work.sort_custom(_maze_back_room_less)
	var stamped_cells: Dictionary = {}
	var added := 0
	var addressed_count := 0
	var private_count := 0
	for item: Dictionary in work:
		var cells := item["cells"] as Array[Vector3i]
		var blocked := false
		for cell: Vector3i in cells:
			if grid.use_at(cell) != WarrenSpatialGrid.Use.ALLOCATABLE \
					or _residual_feature_protected(grid, cell,
						protected_owners):
				blocked = true
				break
		if blocked:
			_note_maze_back_room_refusal(refusals,
				"mass already spent or feature-reserved")
			continue
		var band := int(item["band"])
		var columns := item["columns"] as Array[Vector2i]
		var kind := StringName(item["kind"])
		var yaw := int(item["yaw"])
		var origin := _maze_back_room_origin(kind, cells, yaw)
		# TASK C5c RULING 3 -- THE SECOND DOOR. A back room whose own shell can
		# open an authored doorway onto a street is an ADDRESSED room of this
		# building, not a windowless cell reached through the house in front of
		# it: the plot is a corner and this is its second frontage.
		var address := _maze_back_room_address(grid, kind, cells, yaw)
		if not address.is_empty():
			yaw = int(address.yaw)
			origin = address.origin as Vector3i
		if origin.x == 2147483647:
			_note_maze_back_room_refusal(refusals,
				"rectangle is not an authored shell")
			continue
		var terrain_bearing := _maze_back_room_bears_terrain(grid, volume,
			columns, band)
		var support_parent_id := &""
		var support_parent_cell := Vector3i(2147483647, 2147483647, 2147483647)
		if not terrain_bearing:
			var support_counts: Dictionary = {}
			var support_cell_by_owner: Dictionary = {}
			for cell: Vector3i in cells:
				if cell.y != band:
					continue
				var below := cell + Vector3i.DOWN
				var owner := StringName(building_by_cell.get(below, &""))
				if owner.is_empty():
					continue
				support_counts[owner] = int(
					support_counts.get(owner, 0)) + 1
				support_cell_by_owner[owner] = below
			support_parent_id = _largest_contact_owner(support_counts)
			var required := maxi(1, columns.size() * 2)
			if support_parent_id.is_empty() \
					or int(support_counts[support_parent_id]) < required:
				# Neither the ground nor half a floorplate of inhabited mass
				# stands under this rectangle. What is usually there instead is
				# structural ROCK, which is derived stone rather than
				# construction and which no room may name as its bearing.
				_note_maze_back_room_refusal(refusals,
					"no terrain or building bearing")
				continue
			support_parent_cell = support_cell_by_owner[
				support_parent_id] as Vector3i
		var parent_building := building_by_id.get(support_parent_id) \
			as WarrenBuildingVolume
		var parent_room := _maze_back_room_parent_room(parent_building,
			support_parent_cell)
		if not terrain_bearing and parent_room == null:
			_note_maze_back_room_refusal(refusals,
				"bearing parent has no room to name")
			continue
		var building_id := StringName("spatial.maze_back.%02d" % added)
		var source_id := StringName("maze.back.%02d" % added)
		var support_source := &"" if terrain_bearing \
			else parent_room.source_parcel_id
		var support_storey := -1 if terrain_bearing \
			else parent_room.source_storey_index
		var roof_feature := _residual_roof_feature(kind, origin,
			volume.world_seed)
		var addressed := not address.is_empty()
		var threshold_cell := address.get("threshold",
			Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
		var frontage_direction := address.get("direction",
			Vector3i.ZERO) as Vector3i
		var probe := WarrenRoomStamp.new(&"maze.back.envelope.probe",
			&"maze.back.envelope.probe", kind, origin, yaw, 0, terrain_bearing,
			addressed, threshold_cell, frontage_direction, roof_feature,
			support_source, support_storey, 0,
			bool(item.get("flat_roof", false)))
		probe.private_cells.assign(cells)
		if not _residual_room_envelope_fits(probe, building_by_id,
				construction_program, volume.world_seed):
			_note_maze_back_room_refusal(refusals,
				"authored envelope does not fit")
			continue
		if _stamp_maze_private_room(grid, supports, {
				"building_id": building_id, "source_id": source_id,
				"kind": kind, "origin": origin, "yaw": yaw, "cells": cells,
				"floor_band": band, "terrain_bearing": terrain_bearing,
				"addressed": addressed, "threshold_cell": threshold_cell,
				"frontage_direction": frontage_direction,
				"access_id": StringName(item["access_id"]),
				"support_parcel_id": support_source,
				"support_storey_index": support_storey,
				"roof_feature": roof_feature,
				"flat_roof": bool(item.get("flat_roof", false)),
				"parent_building_id": &"" if terrain_bearing \
					else parent_building.stable_id},
				buildings, building_by_id, building_by_cell,
				required_supports, terrain_support_ids,
				support_edges) == null:
			return {"failed": true}
		for cell: Vector3i in cells:
			stamped_cells[cell] = true
		addressed_count += int(addressed)
		private_count += int(not addressed)
		added += 1
	var unstamped: Array[Vector3i] = []
	for cell_value: Variant in candidate_cells.keys():
		var cell := cell_value as Vector3i
		if not stamped_cells.has(cell):
			unstamped.append(cell)
	unstamped.sort_custom(_cell_less)
	return {"failed": false, "cell_count": candidate_cells.size(),
		"stamped_cell_count": stamped_cells.size(), "building_count": added,
		"addressed_count": addressed_count, "private_count": private_count,
		"rectangle_count": rectangle_count, "record_count": records.size(),
		"refusals": refusals,
		"unstamped_cells": {"count": unstamped.size(), "cells": unstamped}}


static func _stamp_maze_private_room(grid: WarrenSpatialGrid,
		supports: WarrenSupportGraph, spec: Dictionary,
		buildings: Array[WarrenBuildingVolume], building_by_id: Dictionary,
		building_by_cell: Dictionary, required_supports: Array[StringName],
		terrain_support_ids: Array[StringName],
		support_edges: Array[Dictionary]) -> WarrenBuildingVolume:
	## The one step both DIRECTED maze passes share: take a rectangle whose
	## mass, shell and bearing are already proved and make it a private room of
	## an existing lineage -- one grid transaction, one `WarrenRoomStamp`, one
	## `WarrenBuildingVolume` reaching the street through `add_private_parent`,
	## and the support-graph wiring. Returns the sealed building, or null with
	## `last_failure` set; a null is a broken invariant, never a refusal, and
	## every refusal a caller can survive is decided BEFORE this is called.
	##
	## `spec` carries `building_id`, `source_id`, `kind`, `origin`, `yaw`,
	## `cells`, `floor_band`, `terrain_bearing`, `access_id`,
	## `support_parcel_id`, `support_storey_index`, `roof_feature`,
	## `parent_building_id` (empty when the room stands on the ground) and the
	## optional `flat_roof` a back room inherits from its own parcel.
	##
	## Task C5c ruling 3 adds the optional `addressed`, `threshold_cell` and
	## `frontage_direction`: a rectangle whose own authored doorway meets a
	## street reaches it directly, with a threshold of its own, instead of
	## through the building in front of it. An addressed room takes the
	## threshold INSTEAD of `add_private_parent` -- exactly as the greedy
	## backfill does -- because a building with both would claim two ways in
	## and `WarrenBuildingVolume.seal` wants one.
	var cells := spec["cells"] as Array[Vector3i]
	var building_id := StringName(spec["building_id"])
	var assign := grid.begin_transaction(building_id)
	if not assign.require_use(cells,
			[WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not assign.assign_use(cells,
				WarrenSpatialGrid.Use.PRIVATE_VOLUME, building_id) \
			or not assign.commit():
		last_failure = "maze room %s changed before commit: %s" % [
			building_id, assign.last_rejection]
		return null
	var terrain_bearing := bool(spec["terrain_bearing"])
	var addressed := bool(spec.get("addressed", false))
	var threshold_cell := spec.get("threshold_cell",
		Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
	var frontage_direction := spec.get("frontage_direction",
		Vector3i.ZERO) as Vector3i
	var room := WarrenRoomStamp.new(
		StringName("%s.room00" % building_id),
		StringName(spec["source_id"]), StringName(spec["kind"]),
		spec["origin"] as Vector3i, int(spec["yaw"]), 0, terrain_bearing,
		addressed, threshold_cell, frontage_direction,
		int(spec["roof_feature"]), StringName(spec["support_parcel_id"]),
		int(spec["support_storey_index"]), 0,
		bool(spec.get("flat_roof", false)))
	var building := WarrenBuildingVolume.new(building_id,
		int(spec["floor_band"]))
	if not building.add_private_cells(cells) \
			or not room.add_private_cells(cells) \
			or not room.seal(grid, building_id) \
			or not building.add_room(room) \
			or addressed and not building.add_threshold(threshold_cell,
				threshold_cell + frontage_direction) \
			or not addressed and not building.add_private_parent(
				StringName(spec["access_id"])) \
			or not building.seal(grid) \
			or not supports.add_node(building_id):
		last_failure = ("maze room %s failed its building transaction: " \
			+ "%s/%s") % [building_id, room.last_rejection,
				building.last_rejection]
		return null
	if terrain_bearing:
		terrain_support_ids.append(building_id)
	else:
		support_edges.append({"child": building_id,
			"parent": StringName(spec["parent_building_id"])})
	required_supports.append(building_id)
	buildings.append(building)
	building_by_id[building_id] = building
	for cell: Vector3i in cells:
		building_by_cell[cell] = building_id
	return building


static func _stamp_maze_bridges(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, parcels: WarrenParcelPlan,
		buildings: Array[WarrenBuildingVolume],
		supports: WarrenSupportGraph, required_supports: Array[StringName],
		terrain_support_ids: Array[StringName],
		support_edges: Array[Dictionary], protected_owners: Dictionary,
		construction_program: SettlementFabricProgram) -> Dictionary:
	## The second DIRECTED pass. A `maze_bridges` record is a one-storey plot
	## the carver retained over a street it kept covered, so it is a private
	## BRIDGE ROOM of the house beside it -- a tower over a one-cell span, a
	## slim over a two-cell one -- and not a skywalk: an authored skywalk
	## recipe needs a flank STOREY floor exactly at the bridge band, which the
	## span's own `headroom top + roof` datum does not promise.
	##
	## What it bears on is its two FLANKS, never the street below, so
	## admission runs the residual machinery's own two-sided socket proof
	## against the flanks' real measured recipes -- the same proof
	## `WarrenSpatialFabricCompiler` re-runs strictly when it bonds the span.
	##
	## A record this pass cannot stand up is RELEASED, never rejected: its
	## bands stay rock and its reason is published in `maze_bridge_outcomes`.
	##
	## Maze mode only: `maze_bridges` exists on no searched plan.
	var empty := {"failed": false, "record_count": 0, "stamped": 0,
		"released": 0, "outcomes": [] as Array[Dictionary]}
	var records := parcels.audit.get("maze_bridges", []) as Array
	if records.is_empty():
		return empty
	var building_by_id: Dictionary = {}
	var building_by_cell: Dictionary = {}
	var access_by_parcel := _maze_back_room_access_roots(buildings,
		building_by_id, building_by_cell)
	var outcomes: Array[Dictionary] = []
	var stamped := 0
	for record_value: Variant in records:
		var record := record_value as Dictionary
		var id := StringName(record["id"])
		var columns: Array[Vector2i] = []
		columns.assign(record["cells"] as Array)
		var floor_band := int(record["floor"])
		var top_band := int(record["top"])
		var kind := _maze_bridge_kind(columns)
		if kind.is_empty() \
				or top_band - floor_band != WarrenSpatialGrid.STOREY_CELLS:
			outcomes.append(_maze_bridge_release(id,
				"span is not a one-storey tower or slim shell"))
			continue
		var cells := _maze_bridge_cells(columns, floor_band, top_band)
		var blocked := false
		for cell: Vector3i in cells:
			if grid.use_at(cell) != WarrenSpatialGrid.Use.ALLOCATABLE \
					or _residual_feature_protected(grid, cell,
						protected_owners):
				blocked = true
				break
		if blocked:
			outcomes.append(_maze_bridge_release(id,
				"span mass is already spent or feature-reserved"))
			continue
		var access_id := _maze_bridge_access_id(record, volume, parcels,
			access_by_parcel, columns, floor_band)
		if access_id.is_empty():
			outcomes.append(_maze_bridge_release(id,
				"no flank house composed a building at this floor"))
			continue
		var yaw := -1
		var origin := Vector3i(2147483647, 2147483647, 2147483647)
		for candidate_yaw in 4:
			var candidate := _maze_back_room_origin(kind, cells,
				candidate_yaw)
			if candidate.x == 2147483647:
				continue
			yaw = candidate_yaw
			origin = candidate
			break
		if yaw < 0:
			outcomes.append(_maze_bridge_release(id,
				"span footprint is not an authored shell"))
			continue
		# `_residual_bridge_span` accumulates its diagnosis into one static
		# counter dictionary that `_backfill_residual_rooms` wipes on entry.
		# Snapshot it per record here, or the only explanation of WHY a span
		# did not bind is gone by the time the audit is read.
		_residual_bridge_counts = {}
		var span := _residual_bridge_span(cells, building_by_id,
			building_by_cell, volume.world_seed, construction_program)
		var span_counts := _residual_bridge_counts.duplicate(true)
		if span.is_empty():
			outcomes.append(_maze_bridge_release(id,
				"span has no two bound flank bearings", span_counts))
			continue
		var parent_building := building_by_id.get(
			StringName(span.parent_building_id)) as WarrenBuildingVolume
		var parent_room := _maze_back_room_parent_room(parent_building,
			span.parent_contact_cell as Vector3i)
		if parent_room == null:
			outcomes.append(_maze_bridge_release(id,
				"bearing flank has no room to name", span_counts))
			continue
		var building_id := StringName("spatial.maze_bridge.%02d" % stamped)
		var roof_feature := _residual_roof_feature(kind, origin,
			volume.world_seed)
		# TASK C5d RULING 1 -- a bridge room is the plot model's construction
		# too, so its crown is a slab like every house's. It carries no parcel
		# to inherit the flag from (a bridge is a typed record, never a
		# parcel), so it is stated here, and the probe states it as well or
		# the preflight would prove a PITCHED envelope for a span the real
		# compile then crowns flat.
		var probe := WarrenRoomStamp.new(&"maze.bridge.envelope.probe",
			&"maze.bridge.envelope.probe", kind, origin, yaw, 0, false, false,
			Vector3i(2147483647, 2147483647, 2147483647), Vector3i.ZERO,
			roof_feature, parent_room.source_parcel_id,
			parent_room.source_storey_index, 0, true)
		probe.private_cells.assign(cells)
		if not _residual_room_envelope_fits(probe, building_by_id,
				construction_program, volume.world_seed):
			outcomes.append(_maze_bridge_release(id,
				"authored envelope does not fit", span_counts))
			continue
		var built := _stamp_maze_private_room(grid, supports, {
			"building_id": building_id,
			"source_id": StringName("maze.bridge.%02d" % stamped),
			"kind": kind, "origin": origin, "yaw": yaw, "cells": cells,
			"floor_band": floor_band, "terrain_bearing": false,
			"access_id": access_id,
			"support_parcel_id": parent_room.source_parcel_id,
			"support_storey_index": parent_room.source_storey_index,
			"roof_feature": roof_feature,
			"flat_roof": true,
			"parent_building_id": parent_building.stable_id},
			buildings, building_by_id, building_by_cell, required_supports,
			terrain_support_ids, support_edges)
		if built == null:
			return {"failed": true}
		# Stamped after seal(), which rebuilds the room's audit. This is what
		# the fabric compiler reads to bond BOTH span sockets instead of
		# looking for a bearing parent underneath the room.
		var room := built.room_records[0]
		room.audit["bridge_support_room_ids"] = span.room_ids
		room.audit["bridge_support_records"] = (span.get(
			"support_records", []) as Array).duplicate(true)
		room.audit["bridge_is_bracketed_jetty"] = bool(span.get(
			"is_bracketed_jetty", false))
		outcomes.append({"id": id, "outcome": "stamped", "reason": "",
			"span_counts": span_counts})
		stamped += 1
	return {"failed": false, "record_count": records.size(),
		"stamped": stamped, "released": outcomes.size() - stamped,
		"outcomes": outcomes}


static func _string_name_less(left: StringName,
		right: StringName) -> bool:
	return String(left) < String(right)


static func _maze_bridge_release(id: StringName, reason: String,
		counts: Dictionary = {}) -> Dictionary:
	return {"id": id, "outcome": "released", "reason": reason,
		"span_counts": counts}


static func _maze_bridge_kind(columns: Array[Vector2i]) -> StringName:
	## A retained span is one macro cell, or two in a line -- exactly the tower
	## and slim shells of the room vocabulary. Anything else is a span shape
	## this pass does not author, and it is released rather than forced.
	if columns.size() == 1:
		return &"tower"
	if columns.size() != 2:
		return &""
	var delta := columns[1] - columns[0]
	return &"slim" if absi(delta.x) + absi(delta.y) == 1 else &""


static func _maze_bridge_cells(columns: Array[Vector2i], floor_band: int,
		top_band: int) -> Array[Vector3i]:
	## The one storey of fine mass a bridge plot owns.
	var out: Array[Vector3i] = []
	for column: Vector2i in columns:
		for band in range(floor_band, top_band):
			out.append_array(_fine_square(Vector3i(column.x, band, column.y)))
	return out


static func _maze_bridge_access_id(record: Dictionary,
		volume: WarrenVolumePlan, parcels: WarrenParcelPlan,
		access_by_parcel: Dictionary, columns: Array[Vector2i],
		floor_band: int) -> StringName:
	## The building volume a bridge room reaches the street through: the house
	## beside the span. The planner names one whenever a house plot stood at
	## the bridge's own floor as the span was placed, and the record then
	## carries that house's building group; a record naming ITSELF found none,
	## so the flanks are searched here for a house PLOT 4-adjacent to the span
	## whose `[floor, top)` contains the bridge floor.
	##
	## The search is over PLOTS rather than parcel rectangles because a plot's
	## flanking column is often the part its door rectangle left over -- back
	## room mass of the same house. The house is still the house; which of its
	## rectangles touches the span decides nothing about who owns the bridge.
	## Lowest group id where several qualify, and the first parcel of that
	## group which actually composed a volume wins.
	var groups := parcels.audit.get("maze_buildings", {}) as Dictionary
	var wanted: Array[StringName] = []
	var group := StringName(record["building_id"])
	if group != StringName(record["id"]):
		wanted.append(group)
	else:
		var footprint: Dictionary = {}
		for column: Vector2i in columns:
			footprint[column] = true
		var source := volume.mass_context.get(&"maze_source_plan") \
			as WarrenMazeSourcePlan
		if source == null:
			return &""
		for plot: Dictionary in source.plots:
			if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_HOUSE \
					or floor_band < int(plot["floor"]) \
					or floor_band >= int(plot["top"]):
				continue
			var beside := false
			for cell_value: Variant in plot["cells"] as Array:
				var column := cell_value as Vector2i
				for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
						Vector2i.UP, Vector2i.DOWN]:
					beside = beside or footprint.has(column + direction)
				if beside:
					break
			var owner := StringName(plot["building_id"])
			if beside and not wanted.has(owner):
				wanted.append(owner)
	# Lexical, never `Array[StringName].sort()`: StringName compares by its
	# interned pointer, so the default sort orders by whatever order the town
	# happened to intern its ids in. That is stable inside one process and
	# different in the next, which is exactly the nondeterminism a seeded
	# generator may not have.
	wanted.sort_custom(_string_name_less)
	for owner: StringName in wanted:
		var members: Array[StringName] = []
		members.assign(groups.get(owner, []) as Array)
		members.sort_custom(_string_name_less)
		for parcel_id: StringName in members:
			var access := StringName(access_by_parcel.get(parcel_id, &""))
			if not access.is_empty():
				return access
	return &""


static func _maze_back_room_access_roots(
		buildings: Array[WarrenBuildingVolume], building_by_id: Dictionary,
		building_by_cell: Dictionary) -> Dictionary:
	## Source parcel id -> the volume a back room of that parcel should name as
	## its private parent, indexing the two cell/id maps on the same walk. The
	## ADDRESSED segment is preferred because it is the access root of its own
	## lineage; an all-transferred lineage falls back to its lowest segment id,
	## which reaches the street through the chain `_partition_rooms` built.
	var addressed: Dictionary = {}
	var any: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		building_by_id[building.stable_id] = building
		for cell: Vector3i in building.private_cells:
			building_by_cell[cell] = building.stable_id
		var target := addressed if not building.thresholds.is_empty() else any
		for room: WarrenRoomStamp in building.room_records:
			var current := StringName(target.get(room.source_parcel_id, &""))
			if current.is_empty() \
					or String(building.stable_id) < String(current):
				target[room.source_parcel_id] = building.stable_id
	for parcel_value: Variant in any.keys():
		var parcel_id := StringName(parcel_value)
		if not addressed.has(parcel_id):
			addressed[parcel_id] = any[parcel_id]
	return addressed


static func _maze_back_room_parent_room(building: WarrenBuildingVolume,
		cell: Vector3i) -> WarrenRoomStamp:
	if building == null:
		return null
	for room: WarrenRoomStamp in building.room_records:
		if room.has_private_cell(cell):
			return room
	return building.room_records[0] if not building.room_records.is_empty() \
		else null


static func _note_maze_back_room_refusal(refusals: Dictionary,
		reason: String) -> void:
	refusals[reason] = int(refusals.get(reason, 0)) + 1


static func _maze_back_room_less(left: Dictionary,
		right: Dictionary) -> bool:
	if int(left["band"]) != int(right["band"]):
		return int(left["band"]) < int(right["band"])
	if int(left["record"]) != int(right["record"]):
		return int(left["record"]) < int(right["record"])
	return int(left["rectangle"]) < int(right["rectangle"])


static func _maze_back_room_rectangles(columns: Array,
		frontage: Vector2i) -> Array[Dictionary]:
	## Cut one back-room record's macro columns into axis-aligned rectangles of
	## the five-kind vocabulary, largest first. Greedy and deterministic: walk
	## the still-unclaimed columns in (z, x) order and take the biggest kind
	## whose whole rectangle is unclaimed, anchored at that column's minimum
	## corner. A 1 x 1 tower always fits, so no column is left uncut.
	var free: Dictionary = {}
	for column_value: Variant in columns:
		free[column_value as Vector2i] = true
	var order: Array[Vector2i] = []
	order.assign(free.keys())
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x if a.y == b.y else a.y < b.y)
	var out: Array[Dictionary] = []
	for anchor: Vector2i in order:
		if not free.has(anchor):
			continue
		for shape: Dictionary in MAZE_BACK_ROOM_KINDS:
			var span := Vector2i(int(shape["depth"]), int(shape["width"])) \
				if frontage.x != 0 \
				else Vector2i(int(shape["width"]), int(shape["depth"]))
			var claimed: Array[Vector2i] = []
			for x in range(anchor.x, anchor.x + span.x):
				for z in range(anchor.y, anchor.y + span.y):
					if free.has(Vector2i(x, z)):
						claimed.append(Vector2i(x, z))
			if claimed.size() != span.x * span.y:
				continue
			for column: Vector2i in claimed:
				free.erase(column)
			out.append({"kind": StringName(shape["kind"]),
				"columns": claimed})
			break
	return out


static func _maze_back_room_cells(columns: Array[Vector2i],
		band: int) -> Array[Vector3i]:
	## One storey of fine mass under a macro rectangle.
	var out: Array[Vector3i] = []
	for column: Vector2i in columns:
		for y_offset in WarrenSpatialGrid.STOREY_CELLS:
			out.append_array(_fine_square(Vector3i(column.x, band + y_offset,
				column.y)))
	return out


static func _maze_back_room_address(grid: WarrenSpatialGrid,
		kind: StringName, cells: Array[Vector3i],
		parcel_yaw: int) -> Dictionary:
	## TASK C5c RULING 3. Can this back-room rectangle open its OWN authored
	## doorway onto a street?
	##
	## The rectangle already stands at the parcel's frontage yaw, whose door
	## faces the house in front of it -- so the question is which of the four
	## yaws stamps this exact box AND puts the authored threshold
	## `_residual_authored_threshold` names against canonical public floor.
	## That is the same admission the greedy backfill applies to a residual
	## room, asked here of a rectangle the plot planner already chose, so the
	## facade compiler can never be handed a doorway its shell cannot render.
	##
	## The parcel's own yaw is tried FIRST and the rest in ascending order, so
	## a rectangle that can face two streets keeps the orientation of the house
	## it belongs to. Returns `{yaw, origin, threshold, direction}` or empty.
	## Four yaws of constant work per rectangle: this is a decision, not a
	## search.
	var yaws: Array[int] = [parcel_yaw]
	for yaw in 4:
		if yaw != parcel_yaw:
			yaws.append(yaw)
	for yaw: int in yaws:
		var origin := _maze_back_room_origin(kind, cells, yaw)
		if origin.x == 2147483647:
			continue
		var threshold := _residual_authored_threshold(kind, origin, yaw)
		var direction := FabricRecipe.transform_direction(Vector3i.BACK, yaw)
		var landing := threshold + direction
		if grid.use_at(landing) != WarrenSpatialGrid.Use.PUBLIC_AIR:
			continue
		var floor_claim := grid.face_claim(landing, Vector3i.DOWN)
		if floor_claim.is_empty() or int(floor_claim.get("kind", -1)) \
				!= WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
			continue
		return {"yaw": yaw, "origin": origin, "threshold": threshold,
			"direction": direction}
	return {}


static func _maze_back_room_origin(kind: StringName, cells: Array[Vector3i],
		yaw: int) -> Vector3i:
	## The lattice origin at which `kind` at `yaw` stamps exactly `cells`. Both
	## are boxes, so aligning their minimum corners decides it; the set
	## comparison afterwards is what refuses a rectangle whose extent is not
	## this kind's, rather than trusting the caller's arithmetic.
	var invalid := Vector3i(2147483647, 2147483647, 2147483647)
	var local := WarrenRoomStamp.expected_private_cells(kind, Vector3i.ZERO,
		yaw)
	if local.is_empty() or local.size() != cells.size():
		return invalid
	var local_minimum := local[0]
	for cell: Vector3i in local:
		local_minimum = local_minimum.min(cell)
	var target_minimum := cells[0]
	var wanted: Dictionary = {}
	for cell: Vector3i in cells:
		target_minimum = target_minimum.min(cell)
		wanted[cell] = true
	var origin := target_minimum - local_minimum
	for cell: Vector3i in WarrenRoomStamp.expected_private_cells(kind, origin,
			yaw):
		if not wanted.has(cell):
			return invalid
	return origin


static func _maze_back_room_bears_terrain(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, columns: Array[Vector2i],
		band: int) -> bool:
	## A back room stands on the ground when every one of its macro columns has
	## unbroken source mass from its own stamped bearing datum up to the room's
	## floor, and that rise is short enough for the authored stone course to
	## close. This is exactly the contract
	## `WarrenSpatialFabricCompiler._retained_foundation_cells` enforces on any
	## terrain-bearing room -- asked HERE, before the room enters the grid,
	## because there it rejects the whole town rather than one rectangle.
	##
	## TASK C5c MEASURED AND REVERTED, TASK C5d RE-APPLIED. The compiler's own
	## rule moved in C5c ruling 4 -- a maze room deeper than one plinth course
	## is carried by the retained mountain and takes no plinth -- and relaxing
	## this mirror to match it stamps more back rooms (3/standard went 0.319 ->
	## 0.301 unroomed, 11 -> 14 back rooms) but cost 12/compact and 4/compact
	## their towns at the PITCHED roof gates, because every extra room was
	## another authored crown to fit beside its neighbours. C5d made maze
	## houses flat-roofed, so the marginal room now brings a one-band slab
	## rather than a shell with an eave, and the mirror is aligned to the
	## builder here: a column the compiler would call STONE-BORNE -- a tier, a
	## tunnel roof, or a bored street under the hill -- is bearing, and the
	## only thing left to prove for it is that the room stands on real source
	## mass, which is the compiler's own second check.
	##
	## Mirroring rather than approximating is deliberate (C5c fix #1, Important
	## 4): a mirror stricter than the builder refuses rectangles the real
	## compile would have taken, and one looser than the builder rejects the
	## whole town instead of one rectangle.
	##
	## STONE-BORNE IS A ROOM-LEVEL VERDICT, not a per-column one, and that is
	## the whole shape of this function (C5d fix #1, Important 1). The builder
	## sets one `stone_borne` flag for the room the moment ANY column is
	## carried by stone, and then demands real source mass under EVERY column
	## at `band - 1` -- including the columns that were themselves at grade.
	## Deciding it per column let a MIXED footprint through: one stone-borne
	## column that stands on mass, plus one at grade with `depth == 0` that
	## never reached the standing test at all. The mirror said yes, the builder
	## then said `terrain-bearing room ... stands on nothing at ...` and took
	## the whole town rather than the one rectangle -- exactly the failure mode
	## this mirror exists to prevent.
	var maze_source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	var stone_borne := false
	var plinth_columns: Array[Vector2i] = []
	for column: Vector2i in columns:
		if not volume.envelope.contains_column(column):
			return false
		var ground := volume.envelope.bearing_at(column)
		var depth := band - ground
		if depth < 0:
			return false
		var span_is_whole := true
		for lower_band in range(ground, band):
			if not volume.has_mass(Vector3i(column.x, lower_band, column.y)):
				span_is_whole = false
				break
		if maze_source != null and (not span_is_whole \
				or depth > WarrenSpatialFabricCompiler \
					.FOUNDATION_MODULE_HEIGHT_BANDS \
				or maze_source.rock_shoulder(column) < band):
			# A tier, a tunnel roof, or a bored street under the hill: the plot
			# planner's own support rule already proved this floor stands on
			# something, and the mass below it is stone or another building
			# rather than this room's masonry course.
			stone_borne = true
			continue
		if not span_is_whole or depth > WarrenSpatialFabricCompiler \
				.FOUNDATION_MODULE_HEIGHT_BANDS:
			return false
		if depth > 0:
			plinth_columns.append(column)
	if stone_borne:
		# `_retained_foundation_cells`'s second check, over the whole
		# footprint: the room takes no plinth at all, so the only thing that
		# still has to hold is that there IS real source mass directly beneath
		# every column of it.
		for column: Vector2i in columns:
			if not volume.has_mass(Vector3i(column.x, band - 1, column.y)):
				return false
		return true
	for column: Vector2i in plinth_columns:
		for fine: Vector3i in _fine_square(Vector3i(column.x, band - 1,
				column.y)):
			if grid.use_at(fine) == WarrenSpatialGrid.Use.PUBLIC_AIR:
				return false
	return true


static func _maze_plot_mass_cells(volume: WarrenVolumePlan) -> Dictionary:
	## Every FINE cell inside some plot's own `[floor, top)`. In the plot model
	## this is the whole of a maze town's buildable mass: solid that no plot
	## stands in is structural ROCK -- interior stone the source plan derived,
	## which C5 renders and which is never a room. Empty for a searched volume,
	## which is what makes the residual filter maze-only.
	var out: Dictionary = {}
	var source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null:
		return out
	for plot: Dictionary in source.plots:
		for cell_value: Variant in plot["cells"] as Array:
			var column := cell_value as Vector2i
			for band in range(int(plot["floor"]), int(plot["top"])):
				for fine: Vector3i in _fine_square(Vector3i(column.x, band,
						column.y)):
					out[fine] = true
	return out


static func _backfill_residual_rooms(grid: WarrenSpatialGrid,
		volume: WarrenVolumePlan, buildings: Array[WarrenBuildingVolume],
		supports: WarrenSupportGraph, required_supports: Array[StringName],
		terrain_support_ids: Array[StringName],
		support_edges: Array[Dictionary],
		protected_owners: Dictionary, maximum_buildings: int,
		maximum_per_kind: int,
		construction_program: SettlementFabricProgram) -> Dictionary:
	assert(maximum_buildings > 0 and maximum_per_kind > 0)
	_residual_bridge_counts = {}
	var massif := volume.mass_context.get(&"massif") as WarrenMassif
	if massif == null:
		return {"failed": false, "building_count": 0,
			"private_cell_count": 0, "kind_counts": {}}
	var building_by_id: Dictionary = {}
	var building_by_cell: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		building_by_id[building.stable_id] = building
		for cell: Vector3i in building.private_cells:
			building_by_cell[cell] = building.stable_id
	# In the plot model a room may stand only in mass some plot claimed; solid
	# outside every plot is structural ROCK, which the source plan derived and
	# which is stone rather than construction. Empty on a searched volume, and
	# an empty set is what leaves the candidate check below byte-identical for
	# every legacy mode.
	var plot_mass_cells := _maze_plot_mass_cells(volume)
	# TASK C5c RULING 2 -- the budget is a SEARCHED town's idea. There the
	# greedy scan roams the whole massif and the budget is what stops it
	# turning a mountain into a rash of towers; here every candidate is already
	# confined to plot mass the planner assigned to a building, so a cap on the
	# COUNT just leaves buildings unbuilt. The scan therefore runs until no
	# candidate fits, bounded -- as ruling 2 asks -- by the plot-mass cell count
	# rather than by a room budget: a room owns at least one cell, so this can
	# never bind, and it can never diverge either.
	#
	# Keyed on the plot mass rather than on `feature_quotas_are_advisory()`,
	# which is a global the review harness does not set: `--maze-source`
	# composes a maze volume with GENERATION_MODE still route-first, and a
	# review render that backfilled differently from production would be a
	# picture of a town nobody ships.
	if not plot_mass_cells.is_empty():
		maximum_buildings = plot_mass_cells.size()
		maximum_per_kind = plot_mass_cells.size()
	# Index each still-uncovered public floor by the private-volume cells that
	# could form its ceiling. This turns the first part of residual packing into
	# an explicit tunnel/bridge-house pass: complete inhabited rooms that span a
	# street outrank equally valid peripheral rooms by a wide margin.
	var uncovered_route_floors: Dictionary = {}
	var route_floor_by_overhead_cell: Dictionary = {}
	var route_floor_set: Dictionary = {}
	for air_cell: Vector3i in grid.cells_with_use(
			WarrenSpatialGrid.Use.PUBLIC_AIR):
		var floor_claim := grid.face_claim(air_cell, Vector3i.DOWN)
		if floor_claim.is_empty() or int(floor_claim.get("kind", -1)) \
				!= WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
			continue
		route_floor_set[air_cell] = true
		var already_covered := false
		for rise in range(WarrenVolumePlan.HEADROOM_BANDS, 7):
			if building_by_cell.has(air_cell + Vector3i.UP * rise):
				already_covered = true
				break
		if already_covered:
			continue
		uncovered_route_floors[air_cell] = true
		for rise in range(WarrenVolumePlan.HEADROOM_BANDS, 7):
			var overhead_cell := air_cell + Vector3i.UP * rise
			if not route_floor_by_overhead_cell.has(overhead_cell):
				route_floor_by_overhead_cell[overhead_cell] = \
					[] as Array[Vector3i]
			(route_floor_by_overhead_cell[overhead_cell] \
				as Array[Vector3i]).append(air_cell)
	var initial_uncovered_route_count := uncovered_route_floors.size()
	var uncovered_frontage_sides: Dictionary = {}
	var frontage_side_by_private_cell: Dictionary = {}
	for floor_value: Variant in route_floor_set.keys():
		var floor_cell := floor_value as Vector3i
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := floor_cell + direction
			if route_floor_set.has(neighbor) or building_by_cell.has(neighbor) \
					or building_by_cell.has(neighbor + Vector3i.UP):
				continue
			var side_key := "%d:%d:%d/%d:%d" % [floor_cell.x,
				floor_cell.y, floor_cell.z, direction.x, direction.z]
			uncovered_frontage_sides[side_key] = true
			for private_cell: Vector3i in [neighbor,
					neighbor + Vector3i.UP]:
				if not frontage_side_by_private_cell.has(private_cell):
					frontage_side_by_private_cell[private_cell] = \
						PackedStringArray()
				(frontage_side_by_private_cell[private_cell] \
					as PackedStringArray).append(side_key)
	var initial_uncovered_frontage_count := uncovered_frontage_sides.size()
	var roof_clearance: Dictionary = {}
	# Native pitched roofs extend a fraction of a fine cell past their logical
	# footprint.  Keep that measured eave band distinct from the exact roof
	# volume: it blocks a later wall from rising through an earlier roof, but it
	# must not prevent two same-height roofs from meeting over party-wall rooms.
	var roof_eave_halo: Dictionary = {}
	_reserve_existing_roof_clearance(buildings, building_by_cell,
		roof_clearance, roof_eave_halo)
	var kind_counts: Dictionary = {}
	var added_count := 0
	var added_cells := 0
	var terrain_root_count := 0
	var massif_edge_room_count := 0
	var massif_edge_contact_count := 0
	var terrain_rooted_established_access_count := 0
	while added_count < maximum_buildings:
		var best: Dictionary = {}
		for origin: Vector3i in grid.cells_with_use(
				WarrenSpatialGrid.Use.ALLOCATABLE):
			for kind: StringName in WarrenRoomStamp.KINDS:
				if int(kind_counts.get(kind, 0)) >= maximum_per_kind:
					continue
				var yaw_count := 1 if kind in [&"tower", &"building"] else 2
				for yaw in yaw_count:
					var candidate := _residual_room_candidate(grid, massif,
						origin, kind, yaw, building_by_id, building_by_cell,
						roof_clearance, roof_eave_halo, protected_owners,
						route_floor_by_overhead_cell, uncovered_route_floors,
						frontage_side_by_private_cell,
						uncovered_frontage_sides,
						volume.world_seed,
						int(kind_counts.get(kind, 0)), construction_program,
						plot_mass_cells)
					if candidate.is_empty():
						continue
					if best.is_empty() or float(candidate.score) \
							> float(best.score) or is_equal_approx(
							float(candidate.score), float(best.score)) \
							and String(candidate.key) < String(best.key):
						best = candidate
		if best.is_empty():
			break
		var building_id := StringName("spatial.residual.%02d" % added_count)
		var source_id := StringName("residual.mass.%02d" % added_count)
		var cells := best.cells as Array[Vector3i]
		var assign := grid.begin_transaction(building_id)
		if not assign.require_use(cells,
				[WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
				or not assign.assign_use(cells,
					WarrenSpatialGrid.Use.PRIVATE_VOLUME, building_id) \
				or not assign.commit():
			last_failure = "residual room %s changed before commit: %s" % [
				building_id, assign.last_rejection]
			return {"failed": true}
		var parent_building := building_by_id.get(best.support_parent_id) \
			as WarrenBuildingVolume
		var parent_room: WarrenRoomStamp = null
		if parent_building != null:
			for room: WarrenRoomStamp in parent_building.room_records:
				if room.has_private_cell(best.support_parent_cell as Vector3i):
					parent_room = room
					break
			if parent_room == null and not parent_building.room_records.is_empty():
				parent_room = parent_building.room_records[0]
		var terrain_bearing := bool(best.terrain_bearing)
		terrain_root_count += int(terrain_bearing)
		terrain_rooted_established_access_count += int(terrain_bearing \
			and not bool(best.addressed))
		var edge_contacts := int(best.massif_edge_contact_count)
		massif_edge_room_count += int(edge_contacts > 0)
		massif_edge_contact_count += edge_contacts
		var addressed := bool(best.addressed)
		var threshold_cell := best.threshold_cell as Vector3i \
			if addressed else Vector3i(2147483647, 2147483647, 2147483647)
		var frontage_direction := best.frontage_direction as Vector3i \
			if addressed else Vector3i.ZERO
		var room := WarrenRoomStamp.new(
			StringName("%s.room00" % building_id), source_id,
			StringName(best.kind), best.origin as Vector3i, int(best.yaw), 0,
			terrain_bearing, addressed, threshold_cell, frontage_direction,
			_residual_roof_feature(StringName(best.kind),
				best.origin as Vector3i, volume.world_seed),
			&"" if terrain_bearing or parent_room == null \
				else parent_room.source_parcel_id,
			-1 if terrain_bearing or parent_room == null \
				else parent_room.source_storey_index)
		var building := WarrenBuildingVolume.new(building_id,
			(best.origin as Vector3i).y)
		if not building.add_private_cells(cells) \
				or not room.add_private_cells(cells) \
				or not room.seal(grid, building_id) \
				or not building.add_room(room) \
				or addressed and not building.add_threshold(threshold_cell,
					threshold_cell + frontage_direction) \
				or not addressed and not building.add_private_parent(
					StringName(best.access_parent_id)) \
				or not building.seal(grid) \
				or not supports.add_node(building_id):
			last_failure = "residual room %s failed its building transaction: %s/%s" \
				% [building_id, room.last_rejection, building.last_rejection]
			return {"failed": true}
		var bridge_support_room_ids: Array[StringName] = []
		bridge_support_room_ids.assign(best.get("bridge_support_room_ids",
			[]) as Array)
		if not bridge_support_room_ids.is_empty():
			# A street-bridge room bears on its two flanking walls; the compiler
			# binds both through the exact span sockets instead of a below
			# parent, and the support graph keeps one terrain-reaching edge.
			# Stamped after seal() because seal rebuilds the audit dictionary.
			room.audit["bridge_support_room_ids"] = bridge_support_room_ids
			room.audit["bridge_support_records"] = (
				best.get("bridge_support_records", []) as Array).duplicate(true)
			room.audit["bridge_is_bracketed_jetty"] = bool(best.get(
				"bridge_is_bracketed_jetty", false))
		if terrain_bearing:
			terrain_support_ids.append(building_id)
		else:
			if parent_building == null:
				last_failure = "residual room %s lost its bearing parent" % building_id
				return {"failed": true}
			support_edges.append({"child": building_id,
				"parent": parent_building.stable_id})
		required_supports.append(building_id)
		buildings.append(building)
		building_by_id[building_id] = building
		for cell: Vector3i in cells:
			building_by_cell[cell] = building_id
		for floor_cell: Vector3i in best.overhead_route_floors \
				as Array[Vector3i]:
			uncovered_route_floors.erase(floor_cell)
		for side_key: String in best.frontage_side_keys as PackedStringArray:
			uncovered_frontage_sides.erase(side_key)
		for cell_value: Variant in (best.roof_clearance as Dictionary).keys():
			var roof_cell := cell_value as Vector3i
			roof_clearance[roof_cell] = building_id
			for z_offset in range(-1, 2):
				for x_offset in range(-1, 2):
					roof_eave_halo[roof_cell + Vector3i(x_offset, 0,
						z_offset)] = building_id
		var kind := StringName(best.kind)
		kind_counts[kind] = int(kind_counts.get(kind, 0)) + 1
		added_count += 1
		added_cells += cells.size()
	return {"failed": false, "building_count": added_count,
		"private_cell_count": added_cells, "kind_counts": kind_counts,
		"terrain_root_count": terrain_root_count,
		"massif_edge_room_count": massif_edge_room_count,
		"massif_edge_contact_count": massif_edge_contact_count,
		"terrain_rooted_established_access_count": \
			terrain_rooted_established_access_count,
		"bridge_counts": _residual_bridge_counts.duplicate(),
		"overhead_route_cell_count": initial_uncovered_route_count \
			- uncovered_route_floors.size(),
		"frontage_side_count": initial_uncovered_frontage_count \
			- uncovered_frontage_sides.size()}


static func _reserve_existing_roof_clearance(
		buildings: Array[WarrenBuildingVolume], building_by_cell: Dictionary,
		roof_clearance: Dictionary, roof_eave_halo: Dictionary) -> void:
	## Primary macro rooms are present before residual packing begins. Their
	## exposed top cells already imply a roof, even though the authored roof is
	## compiled later. Seed the same two-band clearance and one-cell measured eave
	## halo used for committed residual rooms so late infill cannot occupy a
	## shoulder and force the roof compiler into an overlapping micro-cap.
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			for cell: Vector3i in room.private_cells:
				if building_by_cell.has(cell + Vector3i.UP):
					continue
				for rise in range(1, ROOF_CLEARANCE_CELLS + 1):
					var roof_cell := cell + Vector3i.UP * rise
					roof_clearance[roof_cell] = building.stable_id
					for z_offset in range(-1, 2):
						for x_offset in range(-1, 2):
							roof_eave_halo[roof_cell + Vector3i(x_offset,
								0, z_offset)] = building.stable_id


static func _residual_room_candidate(grid: WarrenSpatialGrid,
		massif: WarrenMassif, origin: Vector3i, kind: StringName, yaw: int,
		building_by_id: Dictionary, building_by_cell: Dictionary,
		roof_clearance: Dictionary, roof_eave_halo: Dictionary,
		protected_owners: Dictionary,
		route_floor_by_overhead_cell: Dictionary,
		uncovered_route_floors: Dictionary,
		frontage_side_by_private_cell: Dictionary,
		uncovered_frontage_sides: Dictionary,
		world_seed: int, existing_kind_count: int,
		construction_program: SettlementFabricProgram,
		plot_mass_cells: Dictionary = {}) -> Dictionary:
	var cells := WarrenRoomStamp.expected_private_cells(kind, origin, yaw)
	if cells.is_empty():
		return {}
	# `plot_mass_cells` is empty in every searched mode and the short-circuit
	# below therefore never even reads the dictionary there. In MAZE mode it is
	# the town's plot mass, and a cell outside it is structural ROCK: derived
	# stone the plot planner never gave to a building, which the greedy scan
	# used to fill with unroofable towers.
	var footprint: Dictionary = {}
	for cell: Vector3i in cells:
		if grid.use_at(cell) != WarrenSpatialGrid.Use.ALLOCATABLE \
				or roof_eave_halo.has(cell) \
				or not plot_mass_cells.is_empty() \
					and not plot_mass_cells.has(cell) \
				or _residual_feature_protected(grid, cell, protected_owners):
			return {}
		footprint[Vector2i(cell.x, cell.z)] = true
	var candidate_roof_clearance: Dictionary = {}
	# A freestanding residual roof needs open air around its eaves; a bridge
	# room nestled between its two taller flanks does not — its roof compiles
	# as a party-wall cap or bound lean-to under the roof phase's own measured
	# gates. Record the halo verdict instead of rejecting outright so the
	# bridge admission below can waive exactly this one condition.
	var roof_halo_clear := true
	for column_value: Variant in footprint.keys():
		var column := column_value as Vector2i
		for rise in range(WarrenSpatialGrid.STOREY_CELLS,
				WarrenSpatialGrid.STOREY_CELLS + ROOF_CLEARANCE_CELLS):
			var roof_cell := Vector3i(column.x, origin.y + rise, column.y)
			var use := grid.use_at(roof_cell)
			if use not in [WarrenSpatialGrid.Use.ALLOCATABLE,
					WarrenSpatialGrid.Use.OUTSIDE] \
					or roof_clearance.has(roof_cell) \
					or _residual_feature_protected(grid, roof_cell,
						protected_owners):
				return {}
			for z_offset in range(-1, 2):
				for x_offset in range(-1, 2):
					if building_by_cell.has(roof_cell + Vector3i(x_offset,
							0, z_offset)):
						roof_halo_clear = false
			candidate_roof_clearance[roof_cell] = true
	var threshold_candidates: Array[Dictionary] = []
	# An adjacent street cell is not automatically a door. Use the same exact
	# authored local threshold as the final facade compiler so dense infill can
	# never claim a doorway that its selected room shell cannot render.
	var authored_threshold := _residual_authored_threshold(kind, origin, yaw)
	var authored_frontage := FabricRecipe.transform_direction(
		Vector3i.BACK, yaw)
	var authored_landing := authored_threshold + authored_frontage
	if grid.use_at(authored_landing) == WarrenSpatialGrid.Use.PUBLIC_AIR:
		var floor_claim := grid.face_claim(authored_landing, Vector3i.DOWN)
		if not floor_claim.is_empty() and int(floor_claim.get("kind", -1)) \
				== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
			threshold_candidates.append({"cell": authored_threshold,
				"direction": authored_frontage,
				"key": "%d:%d:%d/%d:%d" % [authored_threshold.x,
					authored_threshold.y, authored_threshold.z,
					authored_frontage.x, authored_frontage.z]})
	threshold_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.key) < String(b.key))
	var addressed := not threshold_candidates.is_empty()
	var selected_threshold: Dictionary = threshold_candidates[0] \
		if addressed else {}
	var access_counts: Dictionary = {}
	var access_cell_by_owner: Dictionary = {}
	for cell: Vector3i in cells:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			var owner := StringName(building_by_cell.get(neighbor, &""))
			if owner.is_empty():
				continue
			access_counts[owner] = int(access_counts.get(owner, 0)) + 1
			access_cell_by_owner[owner] = neighbor
	var access_parent_id := _largest_contact_owner(access_counts)
	var terrain_contacts := 0
	var support_counts: Dictionary = {}
	var support_cell_by_owner: Dictionary = {}
	for column_value: Variant in footprint.keys():
		var column := column_value as Vector2i
		var macro := Vector2i(floori(float(column.x) / 2.0),
			floori(float(column.y) / 2.0))
		terrain_contacts += int(massif.has_column(macro) \
			and origin.y == massif.bearing_at(macro))
		var below := Vector3i(column.x, origin.y - 1, column.y)
		var owner := StringName(building_by_cell.get(below, &""))
		if owner.is_empty():
			continue
		support_counts[owner] = int(support_counts.get(owner, 0)) + 1
		support_cell_by_owner[owner] = below
	var required_bearing := maxi(1, ceili(float(footprint.size()) * 0.5))
	var terrain_bearing := terrain_contacts >= required_bearing
	var frontage_side_set: Dictionary = {}
	for cell: Vector3i in cells:
		for side_key: String in frontage_side_by_private_cell.get(cell,
				PackedStringArray()) as PackedStringArray:
			if uncovered_frontage_sides.has(side_key):
				frontage_side_set[side_key] = true
	var frontage_side_keys := PackedStringArray()
	for side_key_value: Variant in frontage_side_set.keys():
		frontage_side_keys.append(String(side_key_value))
	frontage_side_keys.sort()
	# Residual rooms complete the inhabited mass; they never scatter around it.
	# Every candidate must lean on the already sealed connected fabric with a
	# measured side interface. Earlier versions required direct contact with a
	# pre-backfill room, which limited the entire pass to a one-room-deep fringe:
	# a legal second infill room could not continue the same connected wing and
	# most of the carved massif disappeared into lawn. A residual parent is safe
	# here because it has already entered the support graph, shell, roof-clearance,
	# and private-access transactions before the next candidate is considered.
	var connected_parent := _largest_contact_owner(access_counts)
	# A terrain-rooted, addressed infill room already has two independent
	# cohesion facts: its exact street threshold and a full terrain bearing. Let
	# one measured side cell stitch that room to the established fabric. Requiring
	# two contacts here discarded otherwise roofable frontage at turns and left
	# the carved route opening into broad lawns. Elevated or unaddressed residuals
	# still require the original two-cell structural interface.
	var measured_contact_count := int(access_counts.get(connected_parent, 0))
	var closes_street_notch := terrain_bearing and addressed \
		and frontage_side_keys.size() >= 2
	var minimum_established_contact := 1 if terrain_bearing and addressed else 2
	if not closes_street_notch and (connected_parent.is_empty() \
			or measured_contact_count < minimum_established_contact):
		return {}
	if not addressed:
		if terrain_bearing:
			access_parent_id = connected_parent
		elif access_parent_id.is_empty() \
				or int(access_counts[access_parent_id]) < 2:
			return {}
	var support_parent_id := _largest_contact_owner(support_counts)
	var bridge_span: Dictionary = {}
	if not terrain_bearing and (support_parent_id.is_empty() \
			or int(support_counts[support_parent_id]) < required_bearing):
		# No half-footprint mass stands below. The one remaining legal bearing
		# form is a street bridge: a tower or slim room whose side cells
		# exactly meet the centred cardinal bearing sockets of two distinct
		# established flanking rooms, and whose body actually covers uncovered
		# canonical route. Anything else stays rejected.
		if kind not in [&"tower", &"slim"]:
			return {}
		var covers_uncovered_route := false
		for cell: Vector3i in cells:
			for floor_cell: Vector3i in route_floor_by_overhead_cell.get(cell,
					[] as Array[Vector3i]) as Array[Vector3i]:
				if uncovered_route_floors.has(floor_cell):
					covers_uncovered_route = true
					break
			if covers_uncovered_route:
				break
		if not covers_uncovered_route:
			return {}
		_residual_bridge_counts["route_covering_candidates"] = int(
			_residual_bridge_counts.get("route_covering_candidates", 0)) + 1
		bridge_span = _residual_bridge_span(cells, building_by_id,
			building_by_cell, world_seed, construction_program)
		if bridge_span.is_empty():
			_residual_bridge_counts["span_unbound"] = int(
				_residual_bridge_counts.get("span_unbound", 0)) + 1
			return {}
		_residual_bridge_counts["span_bound"] = int(
			_residual_bridge_counts.get("span_bound", 0)) + 1
		support_parent_id = StringName(bridge_span.parent_building_id)
	if not roof_halo_clear and bridge_span.is_empty():
		return {}
	var support_parent_cell := Vector3i(2147483647, 2147483647, 2147483647)
	if not terrain_bearing:
		support_parent_cell = bridge_span.parent_contact_cell as Vector3i \
			if not bridge_span.is_empty() \
			else support_cell_by_owner[support_parent_id] as Vector3i
	var massif_edge_contact_count := 0
	for column_value: Variant in footprint.keys():
		var column := column_value as Vector2i
		var macro := Vector2i(floori(float(column.x) / 2.0),
			floori(float(column.y) / 2.0))
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
				Vector2i.UP, Vector2i.DOWN]:
			if not massif.has_column(macro + direction):
				massif_edge_contact_count += 1
				break
	var overhead_route_floor_set: Dictionary = {}
	for cell: Vector3i in cells:
		for floor_cell: Vector3i in route_floor_by_overhead_cell.get(cell,
				[] as Array[Vector3i]):
			if uncovered_route_floors.has(floor_cell):
				overhead_route_floor_set[floor_cell] = true
	var overhead_route_floors: Array[Vector3i] = []
	overhead_route_floors.assign(overhead_route_floor_set.keys())
	overhead_route_floors.sort_custom(_cell_less)
	var tie := posmod(Helper._mix64(world_seed ^ origin.x * 73856093 \
		^ origin.y * 83492791 ^ origin.z * 19349663 ^ kind.hash() ^ yaw * 97),
		1000003)
	var provisional_room := WarrenRoomStamp.new(&"residual.envelope.probe",
		&"residual.envelope.probe", kind, origin, yaw, 0, terrain_bearing,
		addressed, selected_threshold.get("cell", Vector3i.ZERO) as Vector3i \
			if addressed else Vector3i(2147483647, 2147483647, 2147483647),
		selected_threshold.get("direction", Vector3i.ZERO) as Vector3i \
			if addressed else Vector3i.ZERO,
		_residual_roof_feature(kind, origin, world_seed))
	provisional_room.private_cells.assign(cells)
	if not _residual_room_envelope_fits(provisional_room, building_by_id,
			construction_program, world_seed):
		return {}
	var score := float(overhead_route_floors.size() \
			* RESIDUAL_OVERHEAD_ROUTE_CELL_SCORE \
			+ frontage_side_keys.size() * RESIDUAL_FRONTAGE_SIDE_SCORE \
			+ int(terrain_bearing) * RESIDUAL_TERRAIN_ROOT_SCORE \
			+ massif_edge_contact_count * RESIDUAL_MASSIF_EDGE_COLUMN_SCORE \
			+ int(access_counts.get(access_parent_id, 0)) * 1000 \
		+ threshold_candidates.size() * 500 \
		+ maxi(terrain_contacts, int(support_counts.get(support_parent_id, 0))) \
			* 320 + footprint.size() * 90 + origin.y * 18 \
			- existing_kind_count * 240) - float(tie) * 0.000001
	return {"origin": origin, "kind": kind, "yaw": yaw, "cells": cells,
		"roof_clearance": candidate_roof_clearance,
		"terrain_bearing": terrain_bearing,
		"addressed": addressed,
		"threshold_cell": selected_threshold.get("cell", Vector3i.ZERO),
		"frontage_direction": selected_threshold.get("direction",
			Vector3i.ZERO),
		"access_parent_id": access_parent_id,
		"support_parent_id": support_parent_id,
		"support_parent_cell": support_parent_cell,
		"bridge_support_room_ids": bridge_span.get("room_ids",
			[] as Array[StringName]),
		"bridge_support_records": bridge_span.get("support_records", []),
		"bridge_is_bracketed_jetty": bool(bridge_span.get(
			"is_bracketed_jetty", false)),
		"massif_edge_contact_count": massif_edge_contact_count,
		"overhead_route_floors": overhead_route_floors,
		"frontage_side_keys": frontage_side_keys,
		"score": score,
		"key": "%s/%d:%d:%d/r%d" % [String(kind), origin.x, origin.y,
			origin.z, yaw]}


static func _residual_bridge_span(cells: Array[Vector3i],
		building_by_id: Dictionary, building_by_cell: Dictionary,
		world_seed: int, program: SettlementFabricProgram) -> Dictionary:
	## Prove the two-sided wall bearing for a candidate bridge room: on each of
	## two opposing sides, one distinct established flanking room whose centred
	## cardinal bearing socket exactly meets a cell of this footprint. The
	## proof runs against the flanks' real measured recipes, so the strict
	## compile-time `_sockets_meet` bond can never disagree with admission.
	if program == null:
		return {}
	var cell_set: Dictionary = {}
	for cell: Vector3i in cells:
		cell_set[cell] = true
	var bindings_by_direction: Dictionary = {}
	for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
			Vector3i.FORWARD, Vector3i.BACK]:
		for cell: Vector3i in cells:
			var neighbor := cell + direction
			if cell_set.has(neighbor):
				continue
			var owner := StringName(building_by_cell.get(neighbor, &""))
			if owner.is_empty():
				continue
			var building := building_by_id.get(owner) as WarrenBuildingVolume
			if building == null:
				continue
			_residual_bridge_counts["flank_contacts"] = int(
				_residual_bridge_counts.get("flank_contacts", 0)) + 1
			var binding: Dictionary = {}
			for flank_room: WarrenRoomStamp in building.room_records:
				if not flank_room.has_private_cell(neighbor):
					continue
				# An earlier residual room is a legal flank — it carries its
				# own terrain-reaching support chain — but a bridge may not
				# bear on another bridge: no viaducts of unproven depth.
				if not (flank_room.audit.get("bridge_support_room_ids",
						[]) as Array).is_empty():
					continue
				_residual_bridge_counts["flank_rooms_probed"] = int(
					_residual_bridge_counts.get("flank_rooms_probed", 0)) + 1
				binding = _bridge_flank_binding(cell_set, flank_room, owner,
					world_seed, program)
				if not binding.is_empty():
					break
			if not binding.is_empty():
				bindings_by_direction[direction] = binding
				break
	if bindings_by_direction.size() == 1:
		_residual_bridge_counts["one_side_bound"] = int(
			_residual_bridge_counts.get("one_side_bound", 0)) + 1
	# Two exact socket bonds on distinct flanking rooms carry the room.
	# Opposing walls are the classic street bridge; perpendicular walls are
	# the corner-bridge form over a street bend. A single bound wall is never an
	# inhabited residual room: even with brackets it reads as a complete 3 m room
	# pasted onto the parent facade, which is the forbidden one-cell box rather
	# than a shallow outcropping.
	var bound_directions: Array = bindings_by_direction.keys()
	bound_directions.sort_custom(func(a: Variant, b: Variant) -> bool:
		var left := a as Vector3i
		var right := b as Vector3i
		if left.x != right.x:
			return left.x < right.x
		return left.z < right.z)
	for first_index in bound_directions.size():
		for second_index in range(first_index + 1, bound_directions.size()):
			var negative := bindings_by_direction[
				bound_directions[first_index]] as Dictionary
			var positive := bindings_by_direction[
				bound_directions[second_index]] as Dictionary
			# Two distinct bonded rooms carry the span. They are usually two
			# buildings across a street; two wings of one U-shaped building
			# bridging their own notch is the same legal arch.
			if StringName(negative.room_id) == StringName(positive.room_id):
				_residual_bridge_counts["same_room_pair"] = int(
					_residual_bridge_counts.get("same_room_pair", 0)) + 1
				continue
			var room_ids: Array[StringName] = [
				StringName(negative.room_id), StringName(positive.room_id)]
			return {
				"room_ids": room_ids,
				"parent_building_id": StringName(negative.building_id),
				"parent_contact_cell": negative.contact_cell,
			}
	return {}


static func _bridge_flank_binding(cell_set: Dictionary,
		flank_room: WarrenRoomStamp, owner_id: StringName, world_seed: int,
		program: SettlementFabricProgram) -> Dictionary:
	## A flank binds when its centred cardinal bearing socket faces a cell of
	## the candidate footprint at the exact same band. The bridge recipe
	## authors a span socket on every side cell, so this one-sided test is the
	## complete strict mutual-adjacency proof.
	var recipe := program.recipe(WarrenSpatialFabricCompiler._room_recipe_id(
		flank_room, world_seed, true, 0))
	if recipe == null:
		_residual_bridge_counts["flank_recipe_null"] = int(
			_residual_bridge_counts.get("flank_recipe_null", 0)) + 1
		return {}
	var probed_sockets := 0
	for socket_name: StringName in [&"bearing.east", &"bearing.west",
			&"bearing.north", &"bearing.south"]:
		var socket := recipe.socket(socket_name)
		if socket.is_empty():
			continue
		probed_sockets += 1
		var socket_cell := FabricRecipe.transform_cell(
			socket.cell as Vector3i, flank_room.lattice_origin,
			flank_room.yaw_quarters)
		var facing := FabricRecipe.transform_direction(
			socket.facing as Vector3i, flank_room.yaw_quarters)
		if cell_set.has(socket_cell + facing):
			return {"room_id": flank_room.stable_id,
				"building_id": owner_id,
				"contact_cell": socket_cell}
		if not _residual_bridge_counts.has("sample_miss"):
			var candidate_cells: Array = cell_set.keys()
			candidate_cells.sort_custom(_cell_less)
			_residual_bridge_counts["sample_miss"] = {
				"flank_room": flank_room.stable_id,
				"flank_kind": flank_room.kind,
				"socket": socket_name,
				"socket_cell": socket_cell,
				"facing": facing,
				"candidate_min": candidate_cells[0]}
	if probed_sockets == 0:
		_residual_bridge_counts["flank_no_cardinal_sockets"] = int(
			_residual_bridge_counts.get("flank_no_cardinal_sockets", 0)) + 1
	return {}


static func _residual_room_envelope_fits(candidate: WarrenRoomStamp,
		building_by_id: Dictionary, program: SettlementFabricProgram,
		world_seed: int) -> bool:
	## Residual packing is allowed to close a real party wall or bearing face, but
	## it may not rely on the final compiler to discover that two nearby authored
	## shells overlap. Check both the rich and plain existing phases because those
	## lower rooms are selected before a later residual room and cannot backtrack.
	if candidate == null or program == null:
		return false
	var candidate_recipe := program.recipe(
		WarrenSpatialFabricCompiler._room_recipe_id(candidate, world_seed, false))
	if candidate_recipe == null:
		return false
	var candidate_bounds := FabricRecipe.lattice_transform(
		candidate.lattice_origin, candidate.yaw_quarters) \
		* candidate_recipe.local_clearance_bounds
	for building_value: Variant in building_by_id.values():
		var building := building_value as WarrenBuildingVolume
		for existing: WarrenRoomStamp in building.room_records:
			if _rooms_share_lattice_face(candidate, existing):
				continue
			for phase_b: bool in [true, false]:
				var recipe := program.recipe(WarrenSpatialFabricCompiler \
					._room_recipe_id(existing, world_seed, phase_b))
				if recipe == null:
					return false
				var existing_bounds := FabricRecipe.lattice_transform(
					existing.lattice_origin, existing.yaw_quarters) \
					* recipe.local_clearance_bounds
				if SettlementFabricPlan._aabb_overlaps_volume(candidate_bounds,
						existing_bounds) and not SettlementFabricPlan._is_edge_nick(
						candidate_bounds, existing_bounds):
					return false
	return _residual_roof_envelope_fits(candidate, building_by_id, program,
		world_seed)


static func _residual_roof_envelope_fits(candidate: WarrenRoomStamp,
		building_by_id: Dictionary, program: SettlementFabricProgram,
		world_seed: int) -> bool:
	## Residual rooms are selected after the macro composition, so they must prove
	## a complete roof profile before entering the grid. Room-shell adjacency alone
	## is insufficient: the old preflight skipped every shared face and admitted a
	## small infill whose eaves later passed through an upper neighboring facade.
	var preferred := WarrenSpatialFabricCompiler._full_roof_recipe_id(candidate,
		world_seed)
	var roof_ids: Array[StringName] = [preferred]
	var plain := WarrenSpatialFabricCompiler._plain_pitched_recipe_id(preferred)
	if plain != preferred:
		roof_ids.append(plain)
	if candidate.flat_roof:
		# A flat-roofed stamp will receive the one-band `roof.flat.*` slab
		# (Task C5 ruling 1), never these pitched shells, so proving the
		# pitched envelope would refuse rectangles the real compile accepts.
		# Its own slab is tried FIRST and the pitched ids stay as the fallback
		# the preflight has always used.
		roof_ids.push_front(WarrenSpatialFabricCompiler._flat_roof_recipe_id(
			candidate))
	var yaw_offsets: Array[int] = [0]
	if candidate.kind in [&"tower", &"building"]:
		yaw_offsets.append(1)
	for roof_id: StringName in roof_ids:
		var roof_recipe := program.recipe(roof_id)
		if roof_recipe == null:
			continue
		for yaw_offset: int in yaw_offsets:
			var roof_transform := FabricRecipe.lattice_transform(
				candidate.lattice_origin + Vector3i.UP \
					* WarrenSpatialGrid.STOREY_CELLS,
				posmod(candidate.yaw_quarters + yaw_offset, 4))
			var roof_bounds := roof_transform * roof_recipe.local_clearance_bounds
			var clear := true
			for building_value: Variant in building_by_id.values():
				var building := building_value as WarrenBuildingVolume
				for existing: WarrenRoomStamp in building.room_records:
					for phase_b: bool in [true, false]:
						var existing_recipe := program.recipe(
							WarrenSpatialFabricCompiler._room_recipe_id(existing,
								world_seed, phase_b))
						if existing_recipe == null:
							return false
						var existing_bounds := FabricRecipe.lattice_transform(
							existing.lattice_origin, existing.yaw_quarters) \
							* existing_recipe.local_clearance_bounds
						if SettlementFabricPlan._aabb_overlaps_volume(roof_bounds,
								existing_bounds) \
								and not SettlementFabricPlan._is_edge_nick(
									roof_bounds, existing_bounds):
							clear = false
							break
					if not clear:
						break
				if not clear:
					break
			if clear:
				return true
	return false


static func _rooms_share_lattice_face(left: WarrenRoomStamp,
		right: WarrenRoomStamp) -> bool:
	if left == null or right == null:
		return false
	var right_cells: Dictionary = {}
	for cell: Vector3i in right.private_cells:
		right_cells[cell] = true
	for cell: Vector3i in left.private_cells:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			if right_cells.has(cell + direction):
				return true
	return false


static func _residual_authored_threshold(kind: StringName, origin: Vector3i,
		yaw: int) -> Vector3i:
	var local := Vector3i.ZERO
	match kind:
		&"tower":
			local = Vector3i(0, 0, 0)
		&"slim":
			local = Vector3i(0, 0, 1)
		&"row":
			local = Vector3i(-1, 0, 0)
		&"building":
			local = Vector3i(-1, 0, 1)
		&"long":
			local = Vector3i(-1, 0, 2)
		_:
			return Vector3i(2147483647, 2147483647, 2147483647)
	return FabricRecipe.transform_cell(local, origin, yaw)


static func _largest_contact_owner(counts: Dictionary) -> StringName:
	var best := &""
	var best_count := -1
	for owner_value: Variant in counts.keys():
		var owner := StringName(owner_value)
		var count := int(counts[owner])
		if count > best_count or count == best_count \
				and String(owner) < String(best):
			best = owner
			best_count = count
	return best


static func _residual_feature_protected(grid: WarrenSpatialGrid,
		cell: Vector3i, protected_owners: Dictionary) -> bool:
	var bits := grid.reservation_bits_at(cell)
	if (bits & (WarrenSpatialGrid.Reservation.FEATURE \
			| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE \
			| WarrenSpatialGrid.Reservation.PRIVATE_CONNECTION \
			| WarrenSpatialGrid.Reservation.PUBLIC_CLEARANCE \
			| WarrenSpatialGrid.Reservation.DAYLIGHT)) != 0:
		return true
	for owner_value: Variant in (protected_owners.get(cell, {}) \
			as Dictionary).keys():
		var owner := String(owner_value)
		if owner.begins_with("spatial.feature.") \
				or owner.begins_with("spatial.skywalk.reserve."):
			return true
	return false


static func _residual_roof_feature(kind: StringName, origin: Vector3i,
		world_seed: int) -> int:
	var phase := posmod(world_seed ^ origin.x * 73856093 \
		^ origin.y * 83492791 ^ origin.z * 19349663, 6)
	if kind == &"long":
		return [1, 2, 4, 5, 1, 2][phase]
	if kind == &"building":
		return 1 if phase in [0, 1, 2] else 2 if phase in [3, 4] \
			else 3 if phase == 5 else 0
	if kind == &"tower":
		return 1 if phase == 0 else 2 if phase == 1 \
			else 3 if phase == 2 else 0
	if kind == &"slim":
		return 1 if phase in [0, 1] else 2 if phase in [2, 3] \
			else 3 if phase == 4 else 0
	if kind == &"row":
		return 1 if phase in [0, 1] else 2 if phase in [2, 3] \
			else 3 if phase == 4 else 0
	return 0


static func _discard_unassigned_mass(grid: WarrenSpatialGrid) -> bool:
	var cells := grid.cells_with_use(WarrenSpatialGrid.Use.ALLOCATABLE)
	if cells.is_empty():
		return true
	var discard := grid.begin_transaction(&"massif.discard")
	if not discard.assign_use(cells, WarrenSpatialGrid.Use.OUTSIDE, &"") \
			or not discard.commit():
		last_failure = "could not discard unowned allocation: %s" \
			% discard.last_rejection
		return false
	return true


static func _unassigned_mass_audit(grid: WarrenSpatialGrid) -> Dictionary:
	## Unclaimed source mass is only a *candidate* solid from the Gaussian massif;
	## it is not automatically a missing building. Classify it before discard so a
	## large exterior-connected source shell cannot be mislabeled as one enormous
	## room hole, while a genuinely enclosed residual or a one-cell slit between
	## two occupied walls cannot hide inside that same shell component.
	var remaining: Dictionary = {}
	for cell: Vector3i in grid.cells_with_use(WarrenSpatialGrid.Use.ALLOCATABLE):
		remaining[cell] = true
	var component_count := 0
	var largest_component := 0
	var room_sized_component_count := 0
	var room_sized_cell_count := 0
	var thin_component_count := 0
	var exterior_component_count := 0
	var exterior_cell_count := 0
	var enclosed_component_count := 0
	var enclosed_cell_count := 0
	var enclosed_room_sized_component_count := 0
	var enclosed_room_sized_cell_count := 0
	var public_frontage_component_count := 0
	var public_frontage_face_count := 0
	var private_contact_face_count := 0
	var component_sizes := PackedInt32Array()
	var component_details: Array[Dictionary] = []
	var interstitial_gap_cells: Dictionary = {}
	var feature_clearance_gap_cells: Dictionary = {}
	while not remaining.is_empty():
		var start := remaining.keys()[0] as Vector3i
		var pending: Array[Vector3i] = [start]
		remaining.erase(start)
		var size := 0
		var minimum := start
		var maximum := start
		var exterior_faces := 0
		var public_faces := 0
		var private_faces := 0
		while not pending.is_empty():
			var current: Vector3i = pending.pop_back()
			size += 1
			minimum = minimum.min(current)
			maximum = maximum.max(current)
			if _is_one_cell_interstitial_gap(grid, current):
				# A trapped course inside another feature's exclusive
				# reservation, or flanked by a feature's own authored wall,
				# is typed, owned air rather than an unexplained crack. It is
				# reported separately and never becomes a join obligation.
				if _cell_has_exclusive_feature_reservation(grid, current) \
						or _interstitial_gap_is_feature_adjacent(grid,
							current):
					feature_clearance_gap_cells[current] = true
				else:
					interstitial_gap_cells[current] = true
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
					Vector3i.BACK]:
				var neighbor := current + direction
				var neighbor_use := grid.use_at(neighbor)
				exterior_faces += int(neighbor_use \
					== WarrenSpatialGrid.Use.OUTSIDE)
				public_faces += int(neighbor_use in [
					WarrenSpatialGrid.Use.PUBLIC_AIR,
					WarrenSpatialGrid.Use.DAYLIGHT_AIR])
				private_faces += int(neighbor_use \
					== WarrenSpatialGrid.Use.PRIVATE_VOLUME)
				if not remaining.has(neighbor):
					continue
				remaining.erase(neighbor)
				pending.append(neighbor)
		component_count += 1
		largest_component = maxi(largest_component, size)
		component_sizes.append(size)
		# Eight fine cells are the smallest complete 2x2x2 room stamp.
		room_sized_component_count += int(size >= 8)
		room_sized_cell_count += size if size >= 8 else 0
		var extent := maximum - minimum + Vector3i.ONE
		thin_component_count += int(extent.x < 2 or extent.y < 2 \
			or extent.z < 2)
		var exterior_connected := exterior_faces > 0
		exterior_component_count += int(exterior_connected)
		exterior_cell_count += size if exterior_connected else 0
		enclosed_component_count += int(not exterior_connected)
		enclosed_cell_count += size if not exterior_connected else 0
		enclosed_room_sized_component_count += int(not exterior_connected \
			and size >= 8)
		enclosed_room_sized_cell_count += size if not exterior_connected \
			and size >= 8 else 0
		public_frontage_component_count += int(public_faces > 0)
		public_frontage_face_count += public_faces
		private_contact_face_count += private_faces
		if component_details.size() < 16:
			component_details.append({"size": size, "minimum": minimum,
				"maximum": maximum, "exterior_connected": exterior_connected,
				"exterior_face_count": exterior_faces,
				"public_frontage_face_count": public_faces,
				"private_contact_face_count": private_faces,
				"classification": &"discardable_exterior_trim" \
					if exterior_connected else &"enclosed_residual"})
	component_sizes.sort()
	component_sizes.reverse()
	if component_sizes.size() > 16:
		component_sizes.resize(16)
	var gap_component_sizes := _dictionary_component_sizes(
		interstitial_gap_cells)
	var gap_cells: Array[Vector3i] = []
	gap_cells.assign(interstitial_gap_cells.keys())
	gap_cells.sort_custom(_cell_less)
	var gap_details: Array[Dictionary] = []
	for cell: Vector3i in gap_cells:
		if gap_details.size() >= 16:
			break
		gap_details.append(_interstitial_gap_detail(grid, cell))
	return {"trimmed_mass_component_count": component_count,
		"trimmed_mass_largest_component_cell_count": largest_component,
		"trimmed_mass_room_sized_component_count": room_sized_component_count,
		"trimmed_mass_room_sized_cell_count": room_sized_cell_count,
		"trimmed_mass_thin_component_count": thin_component_count,
		"trimmed_mass_largest_component_sizes": component_sizes,
		"discardable_exterior_trim_component_count":
			exterior_component_count,
		"discardable_exterior_trim_cell_count": exterior_cell_count,
		"enclosed_residual_component_count": enclosed_component_count,
		"enclosed_residual_cell_count": enclosed_cell_count,
		"enclosed_room_sized_residual_component_count":
			enclosed_room_sized_component_count,
		"enclosed_room_sized_residual_cell_count":
			enclosed_room_sized_cell_count,
		"public_frontage_residual_component_count":
			public_frontage_component_count,
		"public_frontage_residual_face_count": public_frontage_face_count,
		"private_contact_residual_face_count": private_contact_face_count,
		"one_cell_interstitial_gap_cell_count": interstitial_gap_cells.size(),
		"one_cell_interstitial_gap_component_count":
			gap_component_sizes.size(),
		"one_cell_interstitial_gap_component_sizes": gap_component_sizes,
		"one_cell_interstitial_gap_details": gap_details,
		"feature_clearance_gap_cell_count": feature_clearance_gap_cells.size(),
		"trimmed_mass_component_details": component_details}


static func _cell_has_exclusive_feature_reservation(grid: WarrenSpatialGrid,
		cell: Vector3i) -> bool:
	## True when a composed feature exclusively owns this cell's air (visual
	## clearance, feature body reservation, or protected connection). Such a
	## course is deliberate typed void, not an unexplained interstitial crack.
	var bits := grid.reservation_bits_at(cell)
	var exclusive := bits & ~(WarrenSpatialGrid.Reservation.TERRAIN_BEARING \
		| WarrenSpatialGrid.Reservation.LOAD_CHANNEL \
		| WarrenSpatialGrid.Reservation.CONSTRUCTION_SEAM)
	return exclusive != 0


static func _interstitial_gap_is_feature_adjacent(grid: WarrenSpatialGrid,
		cell: Vector3i) -> bool:
	## A trapped course whose flanking wall belongs to a composed feature
	## (landmark prefab, bridge house, sealed strip) is part of that feature's
	## authored silhouette — a sculpted concavity or clearance reveal, never a
	## two-building contact defect the join transaction may fill with mass.
	var detail := _interstitial_gap_detail(grid, cell)
	return String(StringName(detail.get("negative_owner", &""))).begins_with(
			"spatial.feature.") \
		or String(StringName(detail.get("positive_owner", &""))).begins_with(
			"spatial.feature.")


static func _is_one_cell_interstitial_gap(grid: WarrenSpatialGrid,
		cell: Vector3i) -> bool:
	if grid.use_at(cell) != WarrenSpatialGrid.Use.ALLOCATABLE:
		return false
	# A single 1.5 m residual course trapped between occupied walls is too small
	# to read as a deliberate alley and is exactly the screenshot failure this
	# audit targets. A public-air cell is never included because intentional
	# passages are carved and typed before room composition.
	return grid.use_at(cell + Vector3i.LEFT) \
			== WarrenSpatialGrid.Use.PRIVATE_VOLUME \
		and grid.use_at(cell + Vector3i.RIGHT) \
			== WarrenSpatialGrid.Use.PRIVATE_VOLUME \
		or grid.use_at(cell + Vector3i.FORWARD) \
			== WarrenSpatialGrid.Use.PRIVATE_VOLUME \
		and grid.use_at(cell + Vector3i.BACK) \
			== WarrenSpatialGrid.Use.PRIVATE_VOLUME


static func _interstitial_gap_detail(grid: WarrenSpatialGrid,
		cell: Vector3i) -> Dictionary:
	var axis := &"x"
	var negative := cell + Vector3i.LEFT
	var positive := cell + Vector3i.RIGHT
	if grid.use_at(negative) != WarrenSpatialGrid.Use.PRIVATE_VOLUME \
			or grid.use_at(positive) != WarrenSpatialGrid.Use.PRIVATE_VOLUME:
		axis = &"z"
		negative = cell + Vector3i.FORWARD
		positive = cell + Vector3i.BACK
	return {"cell": cell, "axis": axis,
		"negative_owner": grid.owner_name_at(negative),
		"positive_owner": grid.owner_name_at(positive)}


static func _dictionary_component_sizes(cells: Dictionary) \
		-> PackedInt32Array:
	var remaining := cells.duplicate()
	var sizes := PackedInt32Array()
	while not remaining.is_empty():
		var start := remaining.keys()[0] as Vector3i
		var pending: Array[Vector3i] = [start]
		remaining.erase(start)
		var size := 0
		while not pending.is_empty():
			var current: Vector3i = pending.pop_back()
			size += 1
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
					Vector3i.BACK]:
				var neighbor := current + direction
				if not remaining.has(neighbor):
					continue
				remaining.erase(neighbor)
				pending.append(neighbor)
		sizes.append(size)
	sizes.sort()
	sizes.reverse()
	if sizes.size() > 16:
		sizes.resize(16)
	return sizes


static func _carve_route_connected_rooftop_court(grid: WarrenSpatialGrid,
		source: WarrenVolumePlan, route_floors: Array[Vector3i],
		buildings: Array[WarrenBuildingVolume]) -> Dictionary:
	## Turn one broad, supported room crown into canonical exterior circulation.
	## The selected cells are not a platform floating over the town: every floor
	## face is the top of inhabited volume, and a two-cell seam joins the existing
	## bored route.  The later shell pass sees PUBLIC_FLOOR on that interface and
	## therefore emits neither a pitched roof nor a second overlapping floor.
	if grid == null or grid.is_sealed() or source == null \
			or not source.is_sealed() or route_floors.is_empty() \
			or buildings.is_empty():
		last_failure = "roof-court planning lacks mutable town topology"
		return {"failed": true}
	var building_by_cell: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for cell: Vector3i in building.private_cells:
			building_by_cell[cell] = building.stable_id
	var available: Dictionary = {}
	for cell_value: Variant in building_by_cell.keys():
		var top_cell := cell_value as Vector3i
		if building_by_cell.has(top_cell + Vector3i.UP):
			continue
		var surface := top_cell + Vector3i.UP
		var headroom := surface + Vector3i.UP
		if not grid.contains(surface) or not grid.contains(headroom) \
				or grid.use_at(surface) not in [WarrenSpatialGrid.Use.OUTSIDE,
					WarrenSpatialGrid.Use.ALLOCATABLE] \
				or grid.use_at(headroom) not in [WarrenSpatialGrid.Use.OUTSIDE,
					WarrenSpatialGrid.Use.ALLOCATABLE] \
				or grid.reservation_bits_at(surface) != 0 \
				or grid.reservation_bits_at(headroom) != 0 \
				or not grid.face_claim(surface, Vector3i.DOWN).is_empty():
			continue
		var macro_column := Vector2i(floori(float(surface.x) / 2.0),
			floori(float(surface.z) / 2.0))
		if surface.y - source.envelope.ground_at(macro_column) \
				< MIN_ROOFTOP_COURT_LIFT_CELLS:
			continue
		available[surface] = building_by_cell[top_cell]
	if available.is_empty():
		return {"failed": false, "court_count": 0,
			"floor_cells": [] as Array[Vector3i],
			"audit": {"candidate_count": 0, "rejection": &"no_room_crowns"}}
	var route_set: Dictionary = {}
	for floor: Vector3i in route_floors:
		# A new court must join the actual bore (or its authored transition), not
		# depend on another supplemental surface that the realm adapter has not
		# connected yet.
		if grid.owner_name_at(floor) == &"public.route":
			route_set[floor] = true
	var candidates: Array[Dictionary] = []
	var seen: Dictionary = {}
	for surface_value: Variant in available.keys():
		var anchor := surface_value as Vector3i
		for shape: Vector2i in ROOFTOP_COURT_SHAPES:
			# A real court may absorb the same-level path that enters it. Search
			# every placement of this supported anchor inside the rectangle rather
			# than insisting that all cells be removable roofs. This lets the route
			# cross the broad roof plaza instead of hanging a one-cell doorway off a
			# two-cell-wide private crown.
			for anchor_z in shape.y:
				for anchor_x in shape.x:
					var corner := anchor - Vector3i(anchor_x, 0, anchor_z)
					var candidate_key := "%d:%d:%d/%d:%d" % [corner.x,
						corner.y, corner.z, shape.x, shape.y]
					if seen.has(candidate_key):
						continue
					seen[candidate_key] = true
					var cells: Array[Vector3i] = []
					var new_cells: Array[Vector3i] = []
					var owner_ids: Dictionary = {}
					var route_inside_count := 0
					var complete := true
					for z_offset in shape.y:
						for x_offset in shape.x:
							var surface := corner + Vector3i(x_offset, 0,
								z_offset)
							if available.has(surface):
								new_cells.append(surface)
								owner_ids[StringName(available[surface])] = true
							elif route_set.has(surface):
								route_inside_count += 1
							else:
								complete = false
								break
							cells.append(surface)
						if not complete:
							break
					if not complete or new_cells.size() < 8 \
							or new_cells.size() * 5 < cells.size() * 3 \
							or route_inside_count == 0:
						continue
					var best_seam_direction := Vector3i.ZERO
					var best_seam_count := route_inside_count
					for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
							Vector3i.FORWARD, Vector3i.BACK]:
						var seam_count := 0
						for cell: Vector3i in cells:
							var on_edge := cell.x == corner.x \
								if direction == Vector3i.LEFT \
								else cell.x == corner.x + shape.x - 1 \
									if direction == Vector3i.RIGHT \
								else cell.z == corner.z \
									if direction == Vector3i.FORWARD \
								else cell.z == corner.z + shape.y - 1
							if on_edge and route_set.has(cell + direction):
								seam_count += 1
						if seam_count > best_seam_count:
							best_seam_count = seam_count
							best_seam_direction = direction
					if best_seam_count < 2:
						continue
					var enclosing_facade_cells := 0
					for cell: Vector3i in cells:
						for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
								Vector3i.FORWARD, Vector3i.BACK]:
							var neighbor := cell + direction
							if available.has(neighbor) or route_set.has(neighbor):
								continue
							enclosing_facade_cells += int(grid.use_at(neighbor) \
								== WarrenSpatialGrid.Use.PRIVATE_VOLUME \
								or grid.use_at(neighbor + Vector3i.UP) \
									== WarrenSpatialGrid.Use.PRIVATE_VOLUME)
					var score := cells.size() * 10000 \
						+ best_seam_count * 800 \
						+ enclosing_facade_cells * 300 \
						+ owner_ids.size() * 120 + corner.y * 10
					var tie := posmod(Helper._mix64(source.world_seed \
						^ corner.x * 73856093 ^ corner.y * 83492791 \
						^ corner.z * 19349663 ^ shape.x * 131 \
						^ shape.y * 197), 1000003)
					candidates.append({"corner": corner, "shape": shape,
						"cells": new_cells, "combined_cells": cells,
						"owner_ids": owner_ids, "is_irregular": false,
						"seam_direction": best_seam_direction,
						"seam_count": best_seam_count,
						"route_inside_count": route_inside_count,
						"enclosing_facade_cell_count": enclosing_facade_cells,
						"score": score, "tie": tie})
	# Dense massing frequently forms an L/T roof union rather than one perfect
	# rectangle. Accept the complete connected crown when it still meets two
	# adjacent route lanes. This produces the requested non-boxy court outline
	# while preserving a literal player-width graph seam.
	if candidates.is_empty():
		candidates = _irregular_rooftop_court_candidates(available, route_set,
			grid, source.world_seed)
	if candidates.is_empty():
		return {"failed": false, "court_count": 0,
			"floor_cells": [] as Array[Vector3i],
			"audit": _rooftop_court_supply_audit(available, route_set)}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.score) != int(b.score):
			return int(a.score) > int(b.score)
		return int(a.tie) < int(b.tie))
	var selected := candidates[0] as Dictionary
	var floors := selected.cells as Array[Vector3i]
	var air_set: Dictionary = {}
	for floor: Vector3i in floors:
		air_set[floor] = true
		air_set[floor + Vector3i.UP] = true
	var air_cells: Array[Vector3i] = []
	air_cells.assign(air_set.keys())
	air_cells.sort_custom(_cell_less)
	var feature_id := &"public.rooftop_court.00"
	var carve := grid.begin_transaction(feature_id)
	if not carve.require_use(air_cells, [WarrenSpatialGrid.Use.OUTSIDE,
			WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not carve.reserve(air_cells,
				WarrenSpatialGrid.Reservation.PUBLIC_CLEARANCE, feature_id) \
			or not carve.assign_use(air_cells,
				WarrenSpatialGrid.Use.PUBLIC_AIR, feature_id):
		last_failure = "could not stage route-connected roof court"
		return {"failed": true}
	for floor: Vector3i in floors:
		if not carve.claim_face(floor, Vector3i.DOWN,
				WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR, feature_id):
			last_failure = "could not stage roof-court floor at %s" % floor
			return {"failed": true}
	if not carve.commit():
		last_failure = "roof-court carve rejected: %s" % carve.last_rejection
		return {"failed": true}
	return {"failed": false, "court_count": 1, "floor_cells": floors,
		"audit": {"candidate_count": candidates.size(),
			"floor_cell_count": floors.size(),
			"combined_floor_cell_count": (selected.get("combined_cells",
				floors) as Array).size(),
			"shape": selected.shape, "floor_band": (floors[0] as Vector3i).y,
			"is_irregular": bool(selected.get("is_irregular", false)),
			"route_inside_cell_count": int(selected.get(
				"route_inside_count", 0)),
			"supporting_building_count": (selected.owner_ids as Dictionary).size(),
			"route_seam_cell_count": int(selected.seam_count),
			"route_seam_direction": selected.seam_direction,
			"enclosing_facade_cell_count": int(
				selected.enclosing_facade_cell_count)}}


static func _irregular_rooftop_court_candidates(available: Dictionary,
		route_set: Dictionary, grid: WarrenSpatialGrid,
		world_seed: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var remaining := available.duplicate()
	while not remaining.is_empty():
		var start := remaining.keys()[0] as Vector3i
		var frontier: Array[Vector3i] = [start]
		var cells: Array[Vector3i] = []
		remaining.erase(start)
		while not frontier.is_empty():
			var current: Vector3i = frontier.pop_back()
			cells.append(current)
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				var neighbor := current + direction
				if remaining.erase(neighbor):
					frontier.append(neighbor)
		if cells.size() < 12 or cells.size() > 24:
			continue
		cells.sort_custom(_cell_less)
		var minimum := Vector2i(2147483647, 2147483647)
		var maximum := Vector2i(-2147483648, -2147483648)
		for cell: Vector3i in cells:
			minimum = minimum.min(Vector2i(cell.x, cell.z))
			maximum = maximum.max(Vector2i(cell.x, cell.z))
		var spans := maximum - minimum + Vector2i.ONE
		if mini(spans.x, spans.y) < 3:
			# Long roof strips are useful galleries, but do not meet the civic-court
			# contract and must keep their ordinary roof treatment.
			continue
		var seams: Array[Dictionary] = []
		for cell: Vector3i in cells:
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				var route_cell := cell + direction
				if route_set.has(route_cell):
					seams.append({"court_cell": cell, "route_cell": route_cell,
						"direction": direction})
		var selected_seam: Array[Dictionary] = []
		for first_index in seams.size():
			for second_index in range(first_index + 1, seams.size()):
				var first := seams[first_index] as Dictionary
				var second := seams[second_index] as Dictionary
				var court_delta := (first.court_cell as Vector3i) \
					- (second.court_cell as Vector3i)
				var route_delta := (first.route_cell as Vector3i) \
					- (second.route_cell as Vector3i)
				if absi(court_delta.x) + absi(court_delta.z) == 1 \
						and court_delta.y == 0 \
						and absi(route_delta.x) + absi(route_delta.z) == 1 \
						and route_delta.y == 0:
					selected_seam.assign([first, second])
					break
			if not selected_seam.is_empty():
				break
		# A broad crown may meet one cell of an existing route node. The common
		# realm adapter folds this connected patch into that same node, so this is
		# not a one-lane graph edge and does not weaken the two-lane episode seam
		# invariant. It is simply a 1.5 m opening from a path into a wider court.
		if selected_seam.is_empty() and not seams.is_empty():
			selected_seam.append(seams[0])
		if selected_seam.is_empty():
			continue
		var owner_ids: Dictionary = {}
		var enclosing_facade_cells := 0
		for cell: Vector3i in cells:
			owner_ids[StringName(available[cell])] = true
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				var neighbor := cell + direction
				if available.has(neighbor) or route_set.has(neighbor):
					continue
				enclosing_facade_cells += int(
					grid.use_at(neighbor) == WarrenSpatialGrid.Use.PRIVATE_VOLUME \
					or grid.use_at(neighbor + Vector3i.UP) \
						== WarrenSpatialGrid.Use.PRIVATE_VOLUME)
		var seam_direction := (selected_seam[0] as Dictionary).direction \
			as Vector3i
		var tie := posmod(Helper._mix64(world_seed ^ start.x * 73856093 \
			^ start.y * 83492791 ^ start.z * 19349663), 1000003)
		out.append({"corner": start, "shape": Vector2i.ZERO,
			"cells": cells, "owner_ids": owner_ids, "is_irregular": true,
			"seam_direction": seam_direction, "seam_count": seams.size(),
			"enclosing_facade_cell_count": enclosing_facade_cells,
			"score": cells.size() * 9500 + enclosing_facade_cells * 300 \
				+ seams.size() * 800 + owner_ids.size() * 120 + start.y * 10,
			"tie": tie})
	return out


static func _rooftop_court_supply_audit(available: Dictionary,
		route_set: Dictionary) -> Dictionary:
	var remaining := available.duplicate()
	var component_sizes := PackedInt32Array()
	var component_details: Array[Dictionary] = []
	var route_adjacent_count := 0
	var route_adjacent_by_band: Dictionary = {}
	for cell_value: Variant in available.keys():
		var cell := cell_value as Vector3i
		var adjacent := false
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			adjacent = adjacent or route_set.has(cell + direction)
		route_adjacent_count += int(adjacent)
		if adjacent:
			route_adjacent_by_band[cell.y] = int(
				route_adjacent_by_band.get(cell.y, 0)) + 1
	while not remaining.is_empty():
		var start := remaining.keys()[0] as Vector3i
		var frontier: Array[Vector3i] = [start]
		remaining.erase(start)
		var size := 0
		var minimum := start
		var maximum := start
		var nearest_route_distance := 2147483647
		var nearest_route_cell := Vector3i(2147483647, 2147483647, 2147483647)
		while not frontier.is_empty():
			var current: Vector3i = frontier.pop_back()
			size += 1
			minimum = minimum.min(current)
			maximum = maximum.max(current)
			for route_value: Variant in route_set.keys():
				var route_cell := route_value as Vector3i
				var distance := absi(route_cell.x - current.x) \
					+ absi(route_cell.y - current.y) \
					+ absi(route_cell.z - current.z)
				if distance < nearest_route_distance:
					nearest_route_distance = distance
					nearest_route_cell = route_cell
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				var neighbor := current + direction
				if remaining.erase(neighbor):
					frontier.append(neighbor)
		component_sizes.append(size)
		component_details.append({"size": size, "minimum": minimum,
			"maximum": maximum, "nearest_route_distance": nearest_route_distance,
			"nearest_route_cell": nearest_route_cell})
	component_sizes.sort()
	component_sizes.reverse()
	component_details.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.size) > int(b.size) if int(a.size) != int(b.size) \
			else int(a.nearest_route_distance) < int(b.nearest_route_distance))
	if component_sizes.size() > 12:
		component_sizes.resize(12)
	if component_details.size() > 12:
		component_details.resize(12)
	return {"candidate_count": 0,
		"rejection": &"no_broad_route_connected_crown",
		"available_room_crown_cell_count": available.size(),
		"route_adjacent_room_crown_cell_count": route_adjacent_count,
		"route_adjacent_room_crown_by_band": route_adjacent_by_band,
		"room_crown_component_sizes": component_sizes,
		"room_crown_component_details": component_details}


static func _derive_shell(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume]) -> bool:
	var threshold_faces: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for threshold: Dictionary in building.thresholds:
			threshold_faces[WarrenSpatialGrid._face_key(
				threshold.private_cell as Vector3i,
				threshold.direction as Vector3i)] = building.stable_id
	var shell := grid.begin_transaction(&"spatial.shell")
	var roof_clearance_by_owner: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for cell: Vector3i in building.private_cells:
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
					Vector3i.BACK]:
				var neighbor := cell + direction
				var neighbor_use := grid.use_at(neighbor)
				# Topology-first composed features may already own this exact
				# interface (for example the open seam between a room and an
				# enclosed skywalk). Shell derivation never replaces it with a
				# generic party wall.
				if not grid.face_claim(cell, direction).is_empty():
					continue
				var face_kind := -1
				var owner_id := building.stable_id
				if neighbor_use == WarrenSpatialGrid.Use.PUBLIC_AIR:
					var key := WarrenSpatialGrid._face_key(cell, direction)
					if direction == Vector3i.UP:
						# The carver already owns the canonical upper interface
						# wherever a street or court walks on inhabited mass.
						# Reclassifying it as a soffit/roof would make the same
						# face contradict itself depending on traversal order.
						var existing := grid.face_claim(cell, direction)
						if not existing.is_empty() and int(existing.kind) \
								== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
							continue
						face_kind = WarrenSpatialGrid.FaceKind.ROOF
					elif direction == Vector3i.DOWN:
						face_kind = WarrenSpatialGrid.FaceKind.SOFFIT
					else:
						face_kind = WarrenSpatialGrid.FaceKind.DOOR \
							if threshold_faces.has(key) \
							else WarrenSpatialGrid.FaceKind.FACADE
				elif neighbor_use == WarrenSpatialGrid.Use.PRIVATE_VOLUME:
					var neighbor_owner := grid.owner_name_at(neighbor)
					if neighbor_owner != building.stable_id:
						face_kind = WarrenSpatialGrid.FaceKind.PARTY_WALL
						owner_id = &"spatial.party_wall"
				elif direction == Vector3i.UP:
					face_kind = WarrenSpatialGrid.FaceKind.ROOF
					if not roof_clearance_by_owner.has(building.stable_id):
						roof_clearance_by_owner[building.stable_id] = \
							[] as Array[Vector3i]
					for y_offset in range(1, ROOF_CLEARANCE_CELLS + 1):
						var clearance := cell + Vector3i.UP * y_offset
						if grid.contains(clearance) and grid.use_at(clearance) \
								== WarrenSpatialGrid.Use.OUTSIDE:
							(roof_clearance_by_owner[building.stable_id] \
								as Array[Vector3i]).append(clearance)
				elif direction == Vector3i.DOWN:
					face_kind = WarrenSpatialGrid.FaceKind.PRIVATE_FLOOR
				elif neighbor_use in [WarrenSpatialGrid.Use.OUTSIDE,
						WarrenSpatialGrid.Use.DAYLIGHT_AIR,
						WarrenSpatialGrid.Use.SERVICE_VOID]:
					face_kind = WarrenSpatialGrid.FaceKind.FACADE
				if face_kind >= 0 and not shell.claim_face(cell, direction,
						face_kind, owner_id):
					last_failure = "could not classify shell face at %s" % cell
					return false
	for owner_value: Variant in roof_clearance_by_owner.keys():
		var owner_id := StringName(owner_value)
		var unique: Dictionary = {}
		for cell: Vector3i in roof_clearance_by_owner[owner_id] \
				as Array[Vector3i]:
			unique[cell] = true
		var cells: Array[Vector3i] = []
		cells.assign(unique.keys())
		if not cells.is_empty() and not shell.reserve(cells,
				WarrenSpatialGrid.Reservation.ROOF_CLEARANCE, owner_id):
			last_failure = "could not reserve roof clearance for %s" % owner_id
			return false
	if not shell.commit():
		last_failure = "derived shell rejected: %s" % shell.last_rejection
		return false
	return true


static func _fine_square(macro_cell: Vector3i) -> Array[Vector3i]:
	var origin := Vector3i(macro_cell.x * 2, macro_cell.y,
		macro_cell.z * 2)
	return [origin, origin + Vector3i.RIGHT, origin + Vector3i.BACK,
		origin + Vector3i(1, 0, 1)] as Array[Vector3i]


static func _cell_less(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	if a.z != b.z:
		return a.z < b.z
	return a.x < b.x
