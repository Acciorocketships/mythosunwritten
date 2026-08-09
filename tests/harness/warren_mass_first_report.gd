extends SceneTree

## Where does a mass-first seed die? Reports the two stages that actually
## consume the corpus, per seed, so a change can be judged without reading a
## composed town's tail end.
##
## Reach for this when mass-first stops producing towns, or after touching
## WarrenSolidPartitioner / WarrenExcavationCarver / WarrenMassifBuilder: the
## `gate` stage is a ~15 s answer where `compose` is a ~8 min one, and the two
## report different failures, so a green `gate` run does not imply a composed
## town.
##
##   --stage gate      per-volume construction-gate metrics plus whether the
##                     real FabricRoofJunctionModuleTable accepts the partition.
##                     `gate=false` names a WarrenTownSolver threshold that the
##                     partition misses; `roofs=false` means the roofs cannot be
##                     joined and the plan is doomed however well it scores.
##   --stage compose   WarrenBuiltTownSolver.solve() per seed, reporting the
##                     rejecting stage for every seed that does not compose.
##   --stage bridge    whether the solid standing OVER the streets could become
##                     houses at all: how deep it is, how many street-spanning
##                     footprints exist, and how many of them are legal
##                     envelopes. Read it with `cover`, which says how much of
##                     that solid the partition actually built -- `cover` alone
##                     cannot tell lost cover from unbuildable trim.
##   --stage fill      how much of the massif becomes houses, and how tall they
##                     BUILD rather than how tall their envelopes are -- the
##                     storey count WarrenParcelConstruction gives a house after
##                     descending it to natural ground, which is what a viewer
##                     counts. Read it with the exposed-face table beside it:
##                     a stack is only a tower where no neighbour stands.
##   --stage hillside  A/B between the massif as built and the same massif with
##                     its terrace levels read as a rising GROUND surface under
##                     a shallow buildable layer (`--layer N`, default 9). Runs
##                     carve -> adapt -> topology gate -> ground arcade on both.
##                     This is the measurement that rules on "make the massif a
##                     hillside so houses stop being towers".
##   --stage address   the address supply itself: how many public cells the town
##                     offers, how many houses the partition builds from them,
##                     and the two WarrenVolumePlan.seal() budgets a wider public
##                     realm spends -- the exact-route interior slab counts. Read
##                     it before and after any change to the street network; the
##                     house count is a consequence of the address count and
##                     nothing else moves it as far.
##   --stage breadth   the inside-corner audit split into the PROPERTY and the
##                     PROXY: per plan, walk cells, total interior cells, the
##                     ratio between them, and the full component-size
##                     histogram. Run it over both pipelines before touching
##                     WarrenVolumePlan.MAX_EXACT_ROUTE_INTERIOR_CELLS -- the
##                     histogram is what says whether a total over 36 is a slab
##                     or simply a bigger street network.
##   --stage read      what a VIEWER reads, on the composed detailed fabric:
##                     the massif's bell profile (ring means, peak offset), how
##                     many houses FLOAT (their lowest rendered band standing
##                     clear of every support beneath their own footprint), the
##                     tallest COMPOSED vertical face (the run of bands read as
##                     one unbroken wall, whichever stage drew each band), and
##                     how many room units clad a storey above the ground one in
##                     rock. Runs WarrenBuiltTownSolver.diagnostic_best_effort,
##                     so it measures the town the preview renders -- roughly a
##                     minute a seed. `--no-fabric` reports the bell profile
##                     alone in a second.
##   --stage routeab   ROUTE-FIRST, the shipping pipeline: per seed, how many
##                     candidates WarrenTownSolver.ranked_candidates offers and
##                     whether WarrenBuiltTownSolver.solve accepts one, with the
##                     accepted town's deterministic signature digest and the
##                     facade audit any change to the family table moves. This
##                     is the controlled A/B route-first is owed whenever the
##                     mass-first branch touches shared vocabulary.
##   --stage timing    WHERE a mass-first detail solve spends its wall clock,
##                     split at the two public boundaries a vocabulary change
##                     can slow down, with the candidate-list census that turns
##                     a slow number into a mechanism. Run it before and after
##                     any change to a pool size.
##   --stage terrain   READ-ONLY: mass-first run against real ground bands --
##                     flat, a steady slope and a terraced step field -- naming
##                     the first stage that refuses and how far each house's
##                     underside ends up above its own natural ground. Feeds
##                     the phase-2 terrain milestone; fixes nothing.
##   --stage motif     READ-ONLY CENSUS for the terrace-over-tunnel motif
##                     (design 2026-08-10, Wave 0 -- the wave that may refute
##                     the design before a line of production code). Over the
##                     stamped corpus it counts LEGAL MOTIF SITES under the
##                     design's own §3.4 predicate: a flat 4-connected run of
##                     2..MAX_PLATEAU_CELLS columns whose buildable layer is
##                     deep enough to carry a house on a lifted deck, untouched
##                     by the bore, with a passage anchor at ground and a deck
##                     anchor at D±1. Reported at both deck datums (a lane at
##                     D+1 needs l>=5, a lane at D needs l>=6), at the current
##                     relief budget and at +4 bands, plus the support-asset
##                     census R2 asks for. Changes nothing; measures only.
##   --stage map       one seed's massif drawn as a plan, band heights in hex,
##                     marking every column as street, house, gallery walk cell
##                     or bare solid. The fastest way to see WHERE a town's mass
##                     went unhoused, which no ratio can tell you.
##   --stage contact   both pipelines' building-contact metrics side by side,
##                     parcel-weighted against cell-weighted. Use it when
##                     touching the construction gate's contact threshold.
##   --stage variety   what a viewer reads as VARIETY on the detailed town the
##                     preview renders: how many distinct wall/gable assets the
##                     facades draw, the longest run of one wall asset along a
##                     single street face, how many skywalks and outcrops the
##                     detail phases admitted, and how many market-stall
##                     families appear. The wiring wave's before/after ledger --
##                     roughly a minute a seed.
##   --seeds 1,3,4     seed list (default: the mass-first review corpus).
##
## Usage:
##   Godot --headless --path . -s tests/harness/warren_mass_first_report.gd \
##     -- --stage gate --seeds 1,3,4,5,6,9,11,13,16,20

const DEFAULT_SEEDS: Array[int] = [1, 3, 4, 5, 6, 9, 11, 13, 16, 20]

var _stage := "gate"
var _seeds: Array[int] = []
var _layer_bands := 9
var _rise_bands := 13
var _fabric_stage := true


func _init() -> void:
	_read_args()
	if _seeds.is_empty():
		if _stage == "motif":
			# The stamped corpus the terrain milestone measures on, not the
			# ten-seed mass-first review list: Wave 0's question is a supply
			# distribution and a ten-seed sample cannot carry it.
			for value in MOTIF_SEED_COUNT:
				_seeds.append(value)
		else:
			_seeds.assign(DEFAULT_SEEDS)
	if _stage == "cover":
		_report_cover()
		quit()
		return
	if _stage == "bridge":
		_report_bridge()
		quit()
		return
	if _stage == "skywalk":
		_report_skywalk()
		quit()
		return
	if _stage == "grade":
		_report_grade()
		quit()
		return
	if _stage == "envelopes":
		_report_envelopes()
		quit()
		return
	if _stage == "contact":
		_report_contact()
		quit()
		return
	if _stage == "fill":
		_report_fill()
		quit()
		return
	if _stage == "address":
		_report_address()
		quit()
		return
	if _stage == "breadth":
		_report_breadth()
		quit()
		return
	if _stage == "hillside":
		_report_hillside()
		quit()
		return
	if _stage == "read":
		_report_read()
		quit()
		return
	if _stage == "variety":
		_report_variety()
		quit()
		return
	if _stage == "timing":
		_report_timing()
		quit()
		return
	if _stage == "routeab":
		_report_route_first_ab()
		quit()
		return
	if _stage == "terrain":
		_report_terrain()
		quit()
		return
	if _stage == "motif":
		_report_motif()
		quit()
		return
	if _stage == "map":
		for world_seed: int in _seeds:
			_report_map(world_seed)
		quit()
		return
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	if _stage == "compose":
		_report_composition()
	else:
		_report_gate()
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST
	quit()


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--stage" and index + 1 < args.size():
			_stage = args[index + 1]
		elif args[index] == "--allow-corner-overlap":
			# See SettlementFabricPlan: diagnostic only, so a town blocked
			# solely by corner-envelope overlap can be measured and rendered.
			SettlementFabricPlan.DIAGNOSTIC_ALLOW_CORNER_ENVELOPE_OVERLAP = true
		elif args[index] == "--layer" and index + 1 < args.size():
			_layer_bands = int(args[index + 1])
		elif args[index] == "--rise" and index + 1 < args.size():
			_rise_bands = int(args[index + 1])
		elif args[index] == "--no-fabric":
			_fabric_stage = false
		elif args[index] == "--seeds" and index + 1 < args.size():
			for token: String in args[index + 1].split(",", false):
				# `A-B` is an inclusive range, the spelling
				# warren_buildable_layer_probe.gd already takes, so a
				# forty-seed corpus is not forty comma-separated integers.
				var bounds := token.split("-", false)
				if not token.begins_with("-") and bounds.size() == 2:
					for value in range(int(bounds[0]), int(bounds[1]) + 1):
						_seeds.append(value)
				else:
					_seeds.append(int(token))


static func _as_hillside(massif: WarrenMassif, layer_bands: int,
		rise_bands: int = 0) -> WarrenMassif:
	## The massif the mass-first design correction asked for: the terrace level
	## becomes a rising GROUND surface and only `layer_bands` sit above it, so a
	## house on a high terrace is short instead of a stack descended to natural
	## ground. Applied here as a transform of a real WarrenMassifBuilder result
	## rather than as a production change, because the production change does
	## not survive its own measurement -- see _report_hillside.
	##
	## `rise_bands` optionally rescales the hill to that peak first. A shallow
	## layer caps how far a bore can stand above local ground at
	## layer_bands - WarrenExcavation.HEADROOM_BANDS, so on the 16-20 band hill
	## the builder ships the flanks outrun every move in
	## WarrenExcavationCarver.ACTIONS and almost nothing carves. Rescaling makes
	## the hill walkable, which is what separates "the bore cannot climb this"
	## from the deeper result the addressed-frontage column reports.
	var out := WarrenMassif.new(massif.world_seed)
	var peak := 1
	for column: Vector2i in massif.columns:
		peak = maxi(peak, massif.top_at(column))
	var scale := 1.0 if rise_bands <= 0 else float(rise_bands) / float(peak)
	for column_value: Variant in massif.columns.keys():
		var column := column_value as Vector2i
		var terrace := int((massif.columns[column] as Dictionary).get("terrace",
			massif.top_at(column)))
		var ground := massif.base_at(column) - terrace
		terrace = maxi(1, int(round(float(terrace) * scale)))
		var top := ground + terrace
		out.columns[column] = {
			"base": maxi(ground, top - layer_bands),
			"top": top,
			"terrace": terrace,
		}
	out.core_top_bands = 0
	for column: Vector2i in out.columns:
		out.core_top_bands = maxi(out.core_top_bands,
			out.top_at(column) - out.base_at(column))
	out.seal()
	return out


func _report_hillside() -> void:
	## A/B for the "terraced hillside carrying a shallow buildable layer"
	## correction: identical seeds, identical bores, one flat-based massif and
	## one whose ground surface rises with its terraces.
	##
	## Read the `addr` column first. It is `addressed_walk_ratio`, and
	## WarrenPublicRealmCarver's topology gate wants 0.55 of it: a walk cell
	## counts only when a neighbouring column carries
	## WarrenVolumePlan.MIN_ADDRESS_BUILDING_BANDS of CONTINUOUS mass starting
	## at the street's own floor band. Three columns, because the two ways of
	## building a hillside fail differently:
	##
	##   FLAT           the massif as shipped -- the control.
	##   HILL-AS-BUILT  16-20 band hill, shallow layer. A bore may stand at most
	##                  layer - HEADROOM_BANDS bands above local ground, so a
	##                  taller riser is a cliff no move in
	##                  WarrenExcavationCarver.ACTIONS can climb: `b` collapses
	##                  before any gate is reached.
	##   SHORT+HILL     the hill rescaled gentle enough to climb. Bores carve;
	##                  `addr` then falls through the gate, because raising a
	##                  column's base deletes the mass below its terrace and
	##                  only same-level neighbours can address a street.
	##
	## The deleted mass is the mass a viewer counts as a tower. A street must
	## climb MIN_SPAN_BANDS and be flanked by MIN_ADDRESS_BUILDING_BANDS
	## measured from its own floor, so ~14 bands stand under its highest cell
	## and WarrenParcelConstruction descends a house through all of them. The
	## tower is what the address gate is asking for -- pinned by
	## test_the_address_gate_requires_a_tower_at_the_top_of_the_climb.
	##
	## Rescaling here rounds an existing terracing rather than re-terracing, so
	## SHORT+HILL loses some bores for reasons of its own; the builder-level
	## control (MIN_HILL_RISE_BANDS 12-16, flat base, no layer) measured the
	## same addressed collapse, 0.57 -> 0.39.
	var layer := _layer_bands
	print("hillside A/B, buildable layer %d bands, walkable hill rescaled to %d"
		% [layer, _rise_bands])
	print("seed | FLAT b/g/a addr | HILL-AS-BUILT b/g/a addr | SHORT+HILL b/g/a addr")
	var totals := {"flat_gate": 0, "hill_gate": 0, "walk_gate": 0,
		"flat_arcade": 0, "hill_arcade": 0, "walk_arcade": 0}
	for world_seed: int in _seeds:
		var built := WarrenMassifBuilder.build(world_seed)
		if built == null:
			print("%4d | massif rejected: %s" % [world_seed,
				WarrenMassifBuilder.last_failure])
			continue
		var flat := _hillside_row(world_seed, built)
		var hill := _hillside_row(world_seed, _as_hillside(built, layer))
		var walkable := _hillside_row(world_seed, _as_hillside(built, layer,
			_rise_bands))
		totals["flat_gate"] = int(totals["flat_gate"]) + int(flat["gate"])
		totals["hill_gate"] = int(totals["hill_gate"]) + int(hill["gate"])
		totals["flat_arcade"] = int(totals["flat_arcade"]) + int(flat["arcade"])
		totals["hill_arcade"] = int(totals["hill_arcade"]) + int(hill["arcade"])
		totals["walk_gate"] = int(totals["walk_gate"]) + int(walkable["gate"])
		totals["walk_arcade"] = int(totals["walk_arcade"]) \
			+ int(walkable["arcade"])
		print("%4d | %2d/%2d/%2d %.2f | %2d/%2d/%2d %.2f | %2d/%2d/%2d %.2f"
			% [world_seed,
			int(flat["bores"]), int(flat["gate"]), int(flat["arcade"]),
			float(flat["addressed"]),
			int(hill["bores"]), int(hill["gate"]), int(hill["arcade"]),
			float(hill["addressed"]),
			int(walkable["bores"]), int(walkable["gate"]),
			int(walkable["arcade"]), float(walkable["addressed"])])
	print("TOTAL gate %d flat -> %d as-built -> %d short+hill" % [
		int(totals["flat_gate"]), int(totals["hill_gate"]),
		int(totals["walk_gate"])])
	print("TOTAL arcade %d flat -> %d as-built -> %d short+hill" % [
		int(totals["flat_arcade"]), int(totals["hill_arcade"]),
		int(totals["walk_arcade"])])


func _hillside_row(world_seed: int, massif: WarrenMassif) -> Dictionary:
	## Runs the frontier's own three stages -- carve, adapt, topology gate,
	## ground arcade -- over the same bore family WarrenTownSolver uses, so the
	## counts are the ones that decide whether a seed yields a town at all.
	var bores := 0
	var gate := 0
	var arcade := 0
	var addressed := 0.0
	for attempt in WarrenTownSolver.MASS_FIRST_EXCAVATION_ATTEMPTS:
		var excavation := WarrenExcavationCarver.carve(world_seed
			+ attempt * WarrenTownSolver.MASS_FIRST_ATTEMPT_STRIDE, massif)
		if excavation == null:
			continue
		var volume := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
			excavation)
		if volume == null:
			continue
		bores += 1
		addressed += float(volume.audit.addressed_walk_ratio)
		if not WarrenPublicRealmCarver.passes_topology_gate(volume):
			continue
		gate += 1
		if WarrenGroundArcadeSolver.extend(volume) != null:
			arcade += 1
	return {"bores": bores, "gate": gate, "arcade": arcade,
		"addressed": addressed / float(maxi(1, bores))}


func _report_gate() -> void:
	var passing := 0
	for world_seed: int in _seeds:
		var frontier := WarrenTownSolver.mass_first_frontier(world_seed)
		if frontier.is_empty():
			print("seed %2d: no frontier -- %s" % [world_seed,
				WarrenTownSolver.last_failure])
			continue
		var best := ""
		var usable := false
		for volume: WarrenVolumePlan in frontier:
			var plan := WarrenTownSolver.partition_parcels(volume)
			if plan == null:
				continue
			var gate := WarrenTownSolver._passes_construction_gate(plan, true)
			var roofs := _roofs_compile(plan)
			usable = usable or (gate and roofs)
			if best.is_empty() or (gate and roofs):
				best = "n=%d cells=%d families=%d contact=%.2f contacted=%.2f " \
					% [int(plan.audit.parcel_count),
						int(plan.audit.get("parcel_footprint_cell_count", 0)),
						int(plan.audit.footprint_family_count),
						float(plan.audit.get(
							"largest_building_contact_component_cell_ratio",
							0.0)),
						float(plan.audit.get("contacted_building_ratio", 0.0))] \
					+ "isolated=%d roofbands=%d gate=%s roofs=%s" \
					% [int(plan.audit.get("isolated_building_count", -1)),
						int(plan.audit.get("roof_band_count", 0)), gate, roofs]
		passing += int(usable)
		print("seed %2d: usable=%s | %s" % [world_seed, usable, best])
	print("SEEDS with a gate-passing, roof-joinable volume: %d/%d" % [passing,
		_seeds.size()])


func _report_composition() -> void:
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	if program == null:
		print("no compiled construction vocabulary")
		return
	var composed := 0
	for world_seed: int in _seeds:
		var town := WarrenBuiltTownSolver.solve(world_seed, program)
		if town != null:
			composed += 1
			print("seed %2d: COMPOSED (%d buildings)" % [world_seed,
				town.town.parcels.parcels.size()])
			continue
		# An empty candidate-failure list means nothing was ever ranked, so the
		# corpus was consumed before composition and WarrenTownSolver holds the
		# reason.
		var reason := WarrenBuiltTownSolver.last_failure
		if WarrenBuiltTownSolver.last_candidate_failure_diagnostic.is_empty():
			reason = "no ranked candidate -- %s" % WarrenTownSolver.last_failure
		print("seed %2d: FAILED :: %s" % [world_seed, reason.substr(0, 400)])
	print("COMPOSED %d/%d" % [composed, _seeds.size()])


func _report_cover() -> void:
	## Is mass that stands OVER a street actually being built into houses?
	## A route cell with solid above its carved headroom is potential cover; if
	## the partition leaves that solid unbuilt, the overhead the visual gate
	## measures was available and lost in this stage. If instead there is no
	## mass above, the ceiling is structural and no partition can raise it.
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	for world_seed: int in _seeds:
		var frontier := WarrenTownSolver.mass_first_frontier(world_seed)
		if frontier.is_empty():
			print("seed %2d: no frontier" % world_seed)
			continue
		var volume := frontier[0]
		var massif := volume.mass_context.get(&"massif") as WarrenMassif
		var bore := volume.mass_context.get(&"excavation") as WarrenExcavation
		var excavation := WarrenExcavationVolumeAdapter.excavation_for_volume(
			bore, volume)
		var plan := WarrenTownSolver.partition_parcels(volume)
		if excavation == null or plan == null:
			print("seed %2d: no partition" % world_seed)
			continue
		var owned: Dictionary = {}
		for parcel: WarrenBuildingParcel in plan.parcels:
			for cell: Vector3i in WarrenSolidPartitioner.occupied_cells(parcel):
				owned[cell] = true
		var roofed := 0
		var bare := 0
		var lost_cells := 0
		for walk: Vector3i in excavation.route:
			var column := Vector2i(walk.x, walk.z)
			var ceiling := walk.y + excavation.slot_bands(walk)
			var above := massif.top_at(column) - ceiling
			if above <= 0:
				bare += 1
				continue
			roofed += 1
			for band in range(ceiling, massif.top_at(column)):
				var cell := Vector3i(column.x, band, column.y)
				if not excavation.carved.has(cell) and not owned.has(cell):
					lost_cells += 1
		print("seed %2d: route %d | cells with mass above %d | no mass above %d"
			% [world_seed, excavation.route.size(), roofed, bare]
			+ " | UNBUILT mass cells over the route %d" % lost_cells)
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


func _report_fill() -> void:
	## Is the massif becoming a town, and does that town read as terraced?
	##
	## Two numbers answer the first: how many of the massif's solid columns
	## carry a house at all, and how many houses the infill pass added on top of
	## the mandatory street-wall flanks. Two answer the second: the distribution
	## of BUILT storeys -- `WarrenParcelConstruction.proposal().storeys`, which
	## counts the stack down to its BEARING datum rather than the envelope the
	## partition cut -- and, for every house, how many of those storeys stand
	## clear of every neighbour on their tallest exposed side. A house whose
	## exposed height is one or two storeys is part of a terraced mass however
	## tall the whole stack is; one exposed for six is the tower the reviewer
	## rejected.
	##
	## `hill` is the third: houses standing on a terrace, and the bands of
	## source mass beneath them that SettlementFabricAssembler must retain as
	## stone. A house on a hill is short BECAUSE that mass stopped being house;
	## if the hill were not rendered it would be floating instead.
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	for world_seed: int in _seeds:
		var frontier := WarrenTownSolver.mass_first_frontier(world_seed)
		if frontier.is_empty():
			print("seed %2d: no frontier" % world_seed)
			continue
		var volume := frontier[0]
		var massif := volume.mass_context.get(&"massif") as WarrenMassif
		var plan := WarrenTownSolver.partition_parcels(volume)
		if massif == null or plan == null:
			print("seed %2d: no partition -- %s" % [world_seed,
				WarrenTownSolver.last_partition_failure])
			continue
		var tops: Dictionary = {}
		for parcel: WarrenBuildingParcel in plan.parcels:
			for column: Vector2i in parcel.footprint:
				tops[column] = parcel.top_band
		var storeys: Dictionary = {}
		var exposed: Dictionary = {}
		var on_a_hill := 0
		var retained_cells := 0
		for parcel: WarrenBuildingParcel in plan.parcels:
			var proposal := WarrenParcelConstruction.proposal(parcel)
			var built := int(proposal.get("storeys", 0))
			storeys[built] = int(storeys.get(built, 0)) + 1
			var bare := _exposed_storeys(parcel, tops, built)
			exposed[bare] = int(exposed.get(bare, 0)) + 1
			var terrace := WarrenParcelConstruction.retained_terrace_cells(
				parcel).size()
			retained_cells += terrace
			on_a_hill += int(terrace > 0)
		print("seed %2d: houses %d over %d of %d massif columns" % [world_seed,
			plan.parcels.size(), tops.size(), massif.columns.size()]
			+ " | infill %d" % int(WarrenSolidPartitioner.last_diagnostic.get(
				"infill_house_count", -1))
			+ " | hill %d houses/%d cells" % [on_a_hill, retained_cells]
			+ " | BUILT storeys %s | EXPOSED storeys %s" % [
				_ascending(storeys), _ascending(exposed)])
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


func _report_breadth() -> void:
	## Is exact_route_interior_cell_count measuring breadth, or counting corners?
	##
	## Both pipelines, same measurement. `int` is the total the absolute cap
	## bounds; `comp` is the component histogram, which is the only part of it
	## that describes a SLAB. A component of 1 is one inside corner of one turn;
	## 2 is a T-junction; a 2x2 macro plaza would be 4 and a 2x3 block 8.
	print("pipeline seed | walk | interior | ratio | max comp | histogram")
	var route_first_ratio := 0.0
	var route_first_max := 0
	var route_first_worst_component := 0
	for world_seed: int in _seeds:
		var envelope := WarrenVolumeEnvelope.build(world_seed, {})
		if envelope == null:
			continue
		for attempt in WarrenTownSolver.TOPOLOGY_ATTEMPTS:
			var volume := WarrenPublicRealmCarver.sealed_candidate(world_seed,
				attempt, envelope)
			if volume == null:
				continue
			volume = WarrenGroundArcadeSolver.extend(volume)
			if volume == null:
				continue
			for variant: WarrenVolumePlan in \
					WarrenElevatedFrontageSolver.variants(volume):
				var audit := variant.exact_route_breadth_audit()
				var walk := variant.walk_cells.size()
				var interior := int(audit.interior_cell_count)
				var ratio := float(interior) / float(maxi(1, walk))
				route_first_ratio = maxf(route_first_ratio, ratio)
				route_first_max = maxi(route_first_max, interior)
				route_first_worst_component = maxi(route_first_worst_component,
					int(audit.max_interior_component_size))
				print("route-first %2d | %3d | %3d | %.3f | %d | %s" % [world_seed,
					walk, interior, ratio,
					int(audit.max_interior_component_size),
					str(audit.interior_component_sizes)])
	print("ROUTE-FIRST legitimate density: max interior %d, max ratio %.3f, " \
		% [route_first_max, route_first_ratio]
		+ "worst component %d" % route_first_worst_component)
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	var mass_ratio := 0.0
	var mass_worst_component := 0
	for world_seed: int in _seeds:
		for volume: WarrenVolumePlan in \
				WarrenTownSolver.mass_first_frontier(world_seed):
			var audit := volume.exact_route_breadth_audit()
			var walk := volume.walk_cells.size()
			var interior := int(audit.interior_cell_count)
			var ratio := float(interior) / float(maxi(1, walk))
			mass_ratio = maxf(mass_ratio, ratio)
			mass_worst_component = maxi(mass_worst_component,
				int(audit.max_interior_component_size))
			print("mass-first %2d | %3d | %3d | %.3f | %d | %s" % [world_seed,
				walk, interior, ratio, int(audit.max_interior_component_size),
				str(audit.interior_component_sizes)])
	print("MASS-FIRST: max ratio %.3f, worst component %d" % [mass_ratio,
		mass_worst_component])
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


func _bore_census(world_seed: int) -> String:
	## Where a seed's twelve bores actually die, and what their exact-resolution
	## interior counts were when they did. A frontier can be lost at the adapter's
	## own seal, at the topology gate or at the ground arcade, and only the first
	## of those is visible in WarrenTownSolver.last_failure.
	var massif := WarrenMassifBuilder.build(world_seed)
	if massif == null:
		return "massif rejected"
	var bores := 0
	var adapted := 0
	var gated := 0
	var arcaded := 0
	var slab_at_adapt := 0
	var slab_at_arcade := 0
	var lane_cells := 0
	var interiors := PackedInt32Array()
	for attempt in WarrenTownSolver.MASS_FIRST_EXCAVATION_ATTEMPTS:
		var excavation := WarrenExcavationCarver.carve(world_seed
			+ attempt * WarrenTownSolver.MASS_FIRST_ATTEMPT_STRIDE, massif)
		if excavation == null:
			continue
		bores += 1
		lane_cells += excavation.lane_cells().size()
		var volume := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
			excavation)
		if volume == null:
			slab_at_adapt += int("floor slab" in
				WarrenExcavationVolumeAdapter.last_failure)
			continue
		adapted += 1
		interiors.append(int(volume.audit.exact_route_interior_cell_count))
		if not WarrenPublicRealmCarver.passes_topology_gate(volume):
			continue
		gated += 1
		if WarrenGroundArcadeSolver.extend(volume) != null:
			arcaded += 1
		else:
			slab_at_arcade += int("floor slab" in
				WarrenGroundArcadeSolver.last_failure)
	return ("bores %d lanecells %d | adapted %d gated %d arcaded %d" % [bores,
		lane_cells, adapted, gated, arcaded]
		+ " | LOST TO THE SLAB CAP: adapt %d arcade %d" % [slab_at_adapt,
			slab_at_arcade]
		+ " | interior %s" % str(interiors))


func _report_address() -> void:
	## Address supply against house count, plus the two seal() budgets a wider
	## public realm spends.
	##
	## `addr` is |bore route U volume.walk_cells| -- every cell
	## WarrenBuildingParcel.seal() will accept as an address, because :47 rejects
	## anything volume.has_frontage() does not hold for. `houses` is what the
	## partition actually builds from them. The ratio between the two is the whole
	## ceiling: no partitioner change raises the house count once every address is
	## spent.
	##
	## `interior` and `component` are audit.exact_route_interior_cell_count and
	## audit.max_exact_route_interior_component_size against
	## WarrenVolumePlan.MAX_EXACT_ROUTE_INTERIOR_CELLS (36) and
	## MAX_EXACT_ROUTE_INTERIOR_COMPONENT_SIZE (5). Both grow with public realm --
	## the first with its total turn count, the second only with real slabs -- so
	## they are the budgets any lane network has to live inside.
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	var total_addresses := 0
	var total_houses := 0
	var towns := 0
	for world_seed: int in _seeds:
		var frontier := WarrenTownSolver.mass_first_frontier(world_seed)
		print("seed %2d census: %s" % [world_seed, _bore_census(world_seed)])
		if frontier.is_empty():
			print("seed %2d: no frontier -- %s" % [world_seed,
				WarrenTownSolver.last_failure.substr(0, 110)])
			continue
		var volume := frontier[0]
		var massif := volume.mass_context.get(&"massif") as WarrenMassif
		var bore := volume.mass_context.get(&"excavation") as WarrenExcavation
		var plan := WarrenTownSolver.partition_parcels(volume)
		var addresses: Dictionary = {}
		for cell: Vector3i in bore.route:
			addresses[cell] = true
		for cell: Vector3i in bore.lane_cells():
			addresses[cell] = true
		for cell: Vector3i in volume.walk_cells:
			addresses[cell] = true
		var audit := WarrenSolidPartitioner.street_wall_audit(
			[] as Array[WarrenBuildingParcel] if plan == null else plan.parcels,
			WarrenExcavationVolumeAdapter.excavation_for_volume(bore, volume),
			massif)
		towns += 1
		total_addresses += addresses.size()
		total_houses += 0 if plan == null else plan.parcels.size()
		print("seed %2d: frontier %d | columns %d | route %d lanes %d/%d"
			% [world_seed, frontier.size(), massif.columns.size(),
				bore.route.size(), bore.lanes.size(), bore.lane_cells().size()]
			+ " | ADDRESSES %d | houses %s" % [addresses.size(),
				"none" if plan == null else str(plan.parcels.size())]
			+ " | walls %d unowned %d" % [int(audit["wall_count"]),
				(audit["unowned"] as Array[Vector3i]).size()]
			+ " | interior %d/%d component %d/%d" % [
				int(volume.audit.exact_route_interior_cell_count),
				WarrenVolumePlan.MAX_EXACT_ROUTE_INTERIOR_CELLS,
				int(volume.audit.max_exact_route_interior_component_size),
				WarrenVolumePlan.MAX_EXACT_ROUTE_INTERIOR_COMPONENT_SIZE]
			+ " | overhang %.2f" % float(volume.audit.overhang_walk_ratio))
	print("TOWNS %d/%d | mean addresses %.1f | mean houses %.1f" % [towns,
		_seeds.size(), float(total_addresses) / float(maxi(1, towns)),
		float(total_houses) / float(maxi(1, towns))])
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


func _report_map(world_seed: int) -> void:
	## The town in plan. Every ratio in this file collapses one of these maps to
	## a number; read the map first when a ratio is surprising, because it shows
	## the one thing the ratios cannot -- whether unhoused mass is rim trim or
	## the tallest part of the massif standing untouched behind the street.
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	var frontier := WarrenTownSolver.mass_first_frontier(world_seed)
	if frontier.is_empty():
		print("seed %2d: no frontier" % world_seed)
		WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST
		return
	var volume := frontier[0]
	var massif := volume.mass_context.get(&"massif") as WarrenMassif
	var bore := volume.mass_context.get(&"excavation") as WarrenExcavation
	var plan := WarrenTownSolver.partition_parcels(volume)
	var marks: Dictionary = {}
	for column_value: Variant in massif.columns.keys():
		var column := column_value as Vector2i
		marks[column] = " %X " % massif.top_at(column)
	if plan != null:
		for parcel: WarrenBuildingParcel in plan.parcels:
			for column: Vector2i in parcel.footprint:
				marks[column] = "[%X]" % parcel.top_band
	for walk: Vector3i in volume.walk_cells:
		marks[Vector2i(walk.x, walk.z)] = "(%X)" % walk.y
	for walk: Vector3i in bore.route:
		marks[Vector2i(walk.x, walk.z)] = "<%X>" % walk.y
	var minimum := Vector2i(1 << 30, 1 << 30)
	var maximum := Vector2i(-(1 << 30), -(1 << 30))
	for column_value: Variant in massif.columns.keys():
		minimum = minimum.min(column_value as Vector2i)
		maximum = maximum.max(column_value as Vector2i)
	print("seed %d: <b> street at band b | [t] house topping at band t" % world_seed
		+ " | (b) arcade/gallery walk cell | t bare massif top, all hex")
	for z in range(minimum.y, maximum.y + 1):
		var line := "%4d " % z
		for x in range(minimum.x, maximum.x + 1):
			line += String(marks.get(Vector2i(x, z), "  . "))
		print(line)
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


func _exposed_storeys(parcel: WarrenBuildingParcel, tops: Dictionary,
		built: int) -> int:
	## The storeys of this house's tallest facade that no neighbour stands
	## against. A neighbouring roof hides everything below it, so the worst
	## exposed side is the perimeter column with the lowest standing top --
	## including bare ground, where the whole stack is exposed.
	var lowest := parcel.top_band
	for column: Vector2i in parcel.footprint:
		for direction: Vector2i in BRIDGE_DIRECTIONS:
			var neighbour := column + direction
			if parcel.footprint.has(neighbour):
				continue
			lowest = mini(lowest, int(tops.get(neighbour, 0)))
	return mini(built, (parcel.top_band - maxi(0, lowest))
		/ WarrenBuildingParcel.STOREY_BANDS)


func _tally(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


func _ascending(counts: Dictionary) -> String:
	var keys: Array[int] = []
	keys.assign(counts.keys())
	keys.sort()
	var parts := PackedStringArray()
	for key: int in keys:
		parts.append("%d:%d" % [key, int(counts[key])])
	return "{%s}" % ", ".join(parts)


const ARCADE_SEED_START := 16
const ARCADE_SEED_COUNT := 16


func _report_grade() -> void:
	## What the ground street costs the coverage gate, and what the arcade stage
	## gets for it -- the two halves of WarrenExcavationCarver.MIN_GRADE_CELLS,
	## measured together so the constant can be traded rather than guessed.
	##
	## A route cell at grade sits on the massif's thin rim, where there is no
	## mass overhead, so it can never be roofed by a house, a bridge or a
	## skywalk. `bare` counts every route cell with nothing above its carved
	## slot and `longest bare run` is the consecutive run of them along the
	## itinerary -- the quantity WarrenBuiltTownPlan rejects on through
	## MAX_UNCOVERED_ROUTE_COMPONENT_SIZE, and the component every composed
	## mass-first seed has failed on.
	##
	## The arcade half re-runs the committed integration test's own chain
	## (carve -> to_volume_plan -> WarrenGroundArcadeSolver.extend) over the same
	## seed window, so a trim can be judged against the authority that owns it
	## rather than against a proxy.
	var carved := 0
	var cleared := 0
	var reasons: Dictionary = {}
	for world_seed in range(ARCADE_SEED_START,
			ARCADE_SEED_START + ARCADE_SEED_COUNT):
		var massif := WarrenMassifBuilder.build(world_seed)
		if massif == null:
			continue
		var excavation := WarrenExcavationCarver.carve(world_seed, massif)
		if excavation == null:
			continue
		carved += 1
		var plan := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
			excavation)
		if plan == null:
			_tally(reasons, "adapter: %s" % WarrenExcavationVolumeAdapter.last_failure)
			continue
		if WarrenGroundArcadeSolver.extend(plan) != null:
			cleared += 1
		else:
			_tally(reasons, WarrenGroundArcadeSolver.last_failure)
	print("MIN_GRADE_CELLS=%d: arcade %d/%d carved routes cleared (%.2f) | %s" % [
		WarrenExcavationCarver.MIN_GRADE_CELLS, cleared, carved,
		float(cleared) / float(maxi(1, carved)), str(reasons)])
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	var with_frontier := 0
	for world_seed: int in _seeds:
		var frontier := WarrenTownSolver.mass_first_frontier(world_seed)
		if frontier.is_empty():
			print("seed %2d: no frontier" % world_seed)
			continue
		with_frontier += 1
		var volume := frontier[0]
		var massif := volume.mass_context.get(&"massif") as WarrenMassif
		var bore := volume.mass_context.get(&"excavation") as WarrenExcavation
		var bare := 0
		var run := 0
		var longest := 0
		var grade := 0
		for walk: Vector3i in bore.route:
			var column := Vector2i(walk.x, walk.z)
			grade += int(walk.y == massif.base_at(column))
			if massif.top_at(column) - walk.y - bore.slot_bands(walk) > 0:
				run = 0
				continue
			bare += 1
			run += 1
			longest = maxi(longest, run)
		print("seed %2d: route %d | grade %d | bare %d | longest bare run %d" % [
			world_seed, bore.route.size(), grade, bare, longest])
	print("FRONTIER %d/%d" % [with_frontier, _seeds.size()])
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


func _report_skywalk() -> void:
	## Does a mass-first partition offer any occupied-link corridor at all?
	##
	## Route-first seeds one deliberately: WarrenParcelizer._best_connection_pair
	## reserves a skywalk pair BEFORE packing anything else, so two compatible
	## upper-room sockets are guaranteed to survive facing each other, and
	## WarrenBuiltTownSolver realises that reservation ahead of every other
	## detail. Mass-first replaced WarrenParcelizer.solve wholesale, so it seals
	## its plan with no reservations and skywalks are left to the detail phase.
	##
	## This asks the question the parcel stage would ask:
	## WarrenAssetCompiler.skywalk_reservation over every pair of partitioned
	## houses, with the volume's own public air, then the same
	## parcel_preserves_skywalk_reservation filter the parcelizer applies before
	## committing one. `standalone` is how many pairs form a corridor at all;
	## `preserved` is how many survive every other house in the partition; `cover`
	## counts those that pass over a ground route cell.
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	if program == null:
		print("no compiled construction vocabulary")
		return
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	for world_seed: int in _seeds:
		var frontier := WarrenTownSolver.mass_first_frontier(world_seed)
		if frontier.is_empty():
			print("seed %2d: no frontier" % world_seed)
			continue
		var volumes := 0
		var best_standalone := 0
		var best_preserved := 0
		var best_cover := 0
		var best_solid := 0
		var best_envelope := 0
		var parcels := 0
		for volume: WarrenVolumePlan in frontier:
			var plan := WarrenTownSolver.partition_parcels(volume)
			var realm := WarrenVolumePublicRealmAdapter.from_volume(volume)
			if plan == null or realm == null:
				continue
			volumes += 1
			parcels = maxi(parcels, plan.parcels.size())
			var air := realm.air_claims()
			var cache: Dictionary = {&"enabled": true}
			var standalone := 0
			var preserved := 0
			var cover := 0
			var blocked_solid := 0
			var blocked_envelope := 0
			for left_index in plan.parcels.size():
				var left := plan.parcels[left_index]
				for right_index in range(left_index + 1, plan.parcels.size()):
					var right := plan.parcels[right_index]
					var reservation := WarrenAssetCompiler.skywalk_reservation(
						left, right, program, air, cache)
					if reservation.is_empty():
						continue
					standalone += 1
					var clear := true
					for other: WarrenBuildingParcel in plan.parcels:
						if other == left or other == right:
							continue
						if WarrenAssetCompiler \
								.parcel_preserves_skywalk_reservation(other,
									reservation, program, cache):
							continue
						clear = false
						# Which half of that predicate fired decides whether the
						# corridor is inside a building (structural) or merely
						# grazed by a roof overhang (the envelope class).
						if _occupies_reserved_cells(other, reservation, program):
							blocked_solid += 1
						else:
							blocked_envelope += 1
						break
					if not clear:
						continue
					preserved += 1
					cover += int(_reservation_covers_route(volume, reservation))
			if standalone > best_standalone:
				best_standalone = standalone
				best_solid = blocked_solid
				best_envelope = blocked_envelope
			best_preserved = maxi(best_preserved, preserved)
			best_cover = maxi(best_cover, cover)
		print("seed %2d: %d volumes, up to %d houses" % [world_seed, volumes,
			parcels]
			+ " | skywalk pairs: standalone %d, preserved by the whole partition"
				% best_standalone
			+ " %d, of those over a route cell %d" % [best_preserved, best_cover]
			+ " | blocked by a third house: mass %d, envelope %d"
				% [best_solid, best_envelope])
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


func _occupies_reserved_cells(parcel: WarrenBuildingParcel,
		reservation: Dictionary, program: SettlementFabricProgram) -> bool:
	## The structural half of WarrenAssetCompiler
	## .parcel_preserves_skywalk_reservation, restated so a rejection can be
	## attributed: does this house's built mass actually stand in the corridor,
	## or does only its clearance envelope reach it?
	var reserved := reservation.reserved_cells as Dictionary
	var proposal := WarrenParcelConstruction.proposal(parcel)
	if proposal.is_empty():
		return false
	for component: Dictionary in \
			StaggeredFabricCompiler.proposal_components(proposal):
		var recipe_value := program.recipe(StringName(component.recipe_id))
		if recipe_value == null:
			continue
		for group: Array[Vector3i] in [recipe_value.solid_cells,
				recipe_value.headroom_cells]:
			for local_cell: Vector3i in group:
				if reserved.has(FabricRecipe.transform_cell(local_cell,
						component.origin as Vector3i,
						int(component.yaw_quarters))):
					return true
	return false


func _reservation_covers_route(volume: WarrenVolumePlan,
		reservation: Dictionary) -> bool:
	## Mirrors WarrenParcelizer._reservation_lower_route_cover_count's test for a
	## single reservation: a reserved cell standing over a walk cell's column,
	## clear of its headroom.
	var cells := reservation.get("reserved_cells", {}) as Dictionary
	for walk: Vector3i in volume.walk_cells:
		for cell_value: Variant in cells.keys():
			var cell := cell_value as Vector3i
			if cell.x == walk.x and cell.z == walk.z \
					and cell.y >= walk.y + WarrenVolumePlan.HEADROOM_BANDS:
				return true
	return false


const BRIDGE_SHAPES: Array[Vector2i] = [
	Vector2i(2, 3), Vector2i(2, 2), Vector2i(1, 2), Vector2i(1, 1),
]
const BRIDGE_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
]


func _report_bridge() -> void:
	## CAN the over-street mass become houses at all? `cover` says how much is
	## left unbuilt; this says how much of it any legal envelope could ever
	## claim, before conflict resolution, so a partition change can be judged
	## against a real ceiling rather than against zero.
	##
	## A bridging house is an ordinary house whose footprint spans a lower walk
	## cell, so it is bound by every rule any house is: its base band must BE a
	## frontage cell's band (WarrenBuildingParcel.seal), at least half its
	## columns must reach ground (the bearing majority), and -- because a
	## mixed-span parcel never descends (WarrenParcelConstruction
	## ._support_base_band) -- it must carry two complete storeys plus the roof
	## reservation in the mass left ABOVE the street's headroom.
	##
	## Scanned over the WHOLE frontier, not one volume: a different bore leaves a
	## different thickness of mass overhead, so a negative taken from a single
	## candidate would only be a statement about that candidate.
	var minimum := WarrenBuildingParcel.STOREY_BANDS * 2 \
		+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	for world_seed: int in _seeds:
		var frontier := WarrenTownSolver.mass_first_frontier(world_seed)
		if frontier.is_empty():
			print("seed %2d: no frontier" % world_seed)
			continue
		var route_cells := 0
		var with_mass := 0
		var buildable_depth := 0
		var deepest := 0
		var spanning := 0
		var tallest := 0
		var two_storey_bridges := 0
		var one_storey_bridges := 0
		var one_storey_route_cells := 0
		var scanned := 0
		var refused: Dictionary = {"column": 0, "bearing": 0, "height": 0}
		for volume: WarrenVolumePlan in frontier:
			var massif := volume.mass_context.get(&"massif") as WarrenMassif
			var bore := volume.mass_context.get(&"excavation") as WarrenExcavation
			var excavation := WarrenExcavationVolumeAdapter.excavation_for_volume(
				bore, volume)
			if massif == null or excavation == null:
				continue
			scanned += 1
			var ceilings: Dictionary = {}
			var over_street: Dictionary = {}
			for walk: Vector3i in excavation.route:
				var column := Vector2i(walk.x, walk.z)
				var ceiling := walk.y + excavation.slot_bands(walk)
				ceilings[column] = maxi(int(ceilings.get(column, -(1 << 30))),
					ceiling)
			route_cells = maxi(route_cells, excavation.route.size())
			var volume_with_mass := 0
			var volume_buildable := 0
			for column_value: Variant in ceilings.keys():
				var column := column_value as Vector2i
				var ceiling := int(ceilings[column])
				var above := massif.top_at(column) - ceiling
				if above <= 0:
					continue
				volume_with_mass += 1
				deepest = maxi(deepest, above)
				volume_buildable += int(above >= minimum)
				for band in range(ceiling, massif.top_at(column)):
					var cell := Vector3i(column.x, band, column.y)
					if not excavation.carved.has(cell):
						over_street[cell] = true
			with_mass = maxi(with_mass, volume_with_mass)
			buildable_depth = maxi(buildable_depth, volume_buildable)
			# Every address the plan offers, at the band a house rooted there sits.
			var addresses: Array[Vector3i] = []
			var seen_addresses: Dictionary = {}
			for cell: Vector3i in volume.walk_cells:
				seen_addresses[cell] = true
				addresses.append(cell)
			for cell: Vector3i in excavation.route:
				if not seen_addresses.has(cell):
					seen_addresses[cell] = true
					addresses.append(cell)
			var two_storey := _bridge_scan(addresses, ceilings, over_street,
				massif, excavation, minimum)
			# The same scan with the storey minimum dropped to one, which is what
			# a bridge over a street would have to be if it were allowed at all.
			# Not a proposal -- the number that says what the question is worth.
			var one_storey := _bridge_scan(addresses, ceilings, over_street,
				massif, excavation, WarrenBuildingParcel.STOREY_BANDS
					+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS)
			spanning = maxi(spanning, int(two_storey["spanning"]))
			tallest = maxi(tallest, int(two_storey["tallest"]))
			two_storey_bridges = maxi(two_storey_bridges,
				int(two_storey["candidates"]))
			one_storey_bridges = maxi(one_storey_bridges,
				int(one_storey["candidates"]))
			one_storey_route_cells = maxi(one_storey_route_cells,
				int(one_storey["route_cells"]))
			for reason: String in ["column", "bearing", "height"]:
				refused[reason] = int(refused[reason]) \
					+ int(two_storey[reason])
		print("seed %2d: %d volumes | route %d, with mass above %d," % [world_seed,
			scanned, route_cells, with_mass]
			+ " of which %d carry a %d-band envelope (deepest %d bands)"
				% [buildable_depth, minimum, deepest]
			+ " | street-spanning footprints %d, tallest legal span %d bands"
				% [spanning, tallest]
			+ " | BRIDGES: 2-storey %d, 1-storey %d over %d route cells"
				% [two_storey_bridges, one_storey_bridges, one_storey_route_cells]
			+ " | refused off-massif %d, bearing %d, too short %d"
				% [int(refused["column"]), int(refused["bearing"]),
					int(refused["height"])])
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


func _bridge_scan(addresses: Array[Vector3i], ceilings: Dictionary,
		unbuilt: Dictionary, massif: WarrenMassif,
		excavation: WarrenExcavation, mixed_minimum: int) -> Dictionary:
	var out: Dictionary = {"column": 0, "bearing": 0, "height": 0,
		"tallest": 0, "spanning": 0, "candidates": 0}
	var reached: Dictionary = {}
	var reached_columns: Dictionary = {}
	for address: Vector3i in addresses:
		for direction: Vector2i in BRIDGE_DIRECTIONS:
			for shape: Vector2i in BRIDGE_SHAPES:
				var footprint := _bridge_footprint(address, direction, shape.x,
					shape.y)
				var spans := false
				for column: Vector2i in footprint:
					spans = spans or (ceilings.has(column) \
						and int(ceilings[column]) <= address.y)
				if not spans:
					continue
				out["spanning"] = int(out["spanning"]) + 1
				var top := _bridge_top(footprint, address.y, massif, excavation,
					out, mixed_minimum)
				if top <= address.y:
					continue
				out["candidates"] = int(out["candidates"]) + 1
				for column: Vector2i in footprint:
					for band in range(address.y, top):
						var cell := Vector3i(column.x, band, column.y)
						if not unbuilt.has(cell):
							continue
						reached[cell] = true
						# SettlementFabricSolver only counts a route cell covered
						# when a room occupies 2..6 bands above it, so mass higher
						# than that buys nothing the visual gate can see.
						if cell.y - int(ceilings[column]) \
								+ WarrenExcavation.HEADROOM_BANDS <= 6:
							reached_columns[column] = true
	out["reachable"] = reached.size()
	out["route_cells"] = reached_columns.size()
	return out


func _bridge_footprint(walk: Vector3i, direction: Vector2i, width: int,
		depth: int) -> Array[Vector2i]:
	var perpendicular := Vector2i(-direction.y, direction.x)
	var threshold := Vector2i(walk.x, walk.z) + direction
	var out: Array[Vector2i] = []
	for depth_offset in depth:
		for width_offset in width:
			out.append(threshold + direction * depth_offset \
				+ perpendicular * width_offset)
	return out


func _bridge_top(footprint: Array[Vector2i], base: int, massif: WarrenMassif,
		excavation: WarrenExcavation, reasons: Dictionary,
		mixed_minimum: int) -> int:
	## WarrenSolidPartitioner._top_band without the claim/no-straddle rules --
	## this measures what the SOLID allows, not what one serving order left.
	var top := 1 << 30
	var bearing := 0
	for column: Vector2i in footprint:
		if not massif.has_column(column) or massif.base_at(column) > base:
			reasons["column"] = int(reasons.get("column", 0)) + 1
			return base
		top = mini(top, massif.top_at(column))
		var grounded := true
		for band in range(massif.base_at(column), base):
			if excavation.carved.has(Vector3i(column.x, band, column.y)):
				grounded = false
				break
		bearing += int(grounded)
	var reachable_top := top
	for column: Vector2i in footprint:
		for band in range(base, reachable_top):
			if excavation.carved.has(Vector3i(column.x, band, column.y)):
				reachable_top = band
				break
	reasons["tallest"] = maxi(int(reasons.get("tallest", 0)),
		reachable_top - base)
	if bearing * 2 < footprint.size():
		reasons["bearing"] = int(reasons.get("bearing", 0)) + 1
		return base
	for column: Vector2i in footprint:
		for band in range(base, top):
			if excavation.carved.has(Vector3i(column.x, band, column.y)):
				top = band
				break
	var settled := base + (top - base) - (top - base) % 2
	var needed := mixed_minimum
	if bearing == footprint.size():
		needed = WarrenBuildingParcel.STOREY_BANDS * 2 \
			+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS
		var ground := -(1 << 30)
		for column: Vector2i in footprint:
			ground = maxi(ground, massif.base_at(column))
		var support := ground
		if posmod(base - ground, WarrenBuildingParcel.STOREY_BANDS) != 0:
			support -= 1
		needed -= base - mini(support, base)
		needed = maxi(WarrenBuildingParcel.STOREY_BANDS
			+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS,
			needed + posmod(needed, 2))
	if settled - base < needed:
		reasons["height"] = int(reasons.get("height", 0)) + 1
		return base
	return settled


func _report_envelopes() -> void:
	## How far each authored roof's visual envelope reaches past the lattice
	## footprint it is placed on. SettlementFabricPlan rejects unrelated units
	## whose envelopes overlap by more than 0.10 m, so this overhang is what
	## decides which adjacencies are buildable at all. Reach for it before
	## assuming a trimmed variant exists for some junction.
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	if program == null:
		print("no compiled construction vocabulary")
		return
	for recipe: FabricRecipe in program.recipes():
		var text := String(recipe.recipe_id)
		if not (text.begins_with("roof.") or text.begins_with("room.")):
			continue
		var bounds := recipe.local_bounds
		var clearance := recipe.local_clearance_bounds
		var overhang_x := maxf(bounds.position.x - clearance.position.x,
			clearance.end.x - bounds.end.x)
		var overhang_z := maxf(bounds.position.z - clearance.position.z,
			clearance.end.z - bounds.end.z)
		print("%-42s bounds=%s clearance=%s overhang x=%.3f z=%.3f" % [
			recipe.recipe_id, bounds.size, clearance.size, overhang_x,
			overhang_z])


func _report_variety() -> void:
	## The wiring wave's before/after ledger. Everything here is read off the
	## SAME detailed fabric the preview renders, so a number and an image can
	## never disagree about which town they describe.
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	var catalog := EnvironmentCatalog.load_default()
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	SettlementFabricPlan.DIAGNOSTIC_ALLOW_CORNER_ENVELOPE_OVERLAP = true
	for world_seed: int in _seeds:
		var attempt := WarrenBuiltTownSolver.diagnostic_best_effort(world_seed,
			program)
		var fabric := attempt.get("fabric") as SettlementFabricPlan
		if fabric == null:
			print("seed %2d VARIETY no fabric -- %s" % [world_seed,
				WarrenBuiltTownSolver.last_failure])
			continue
		var audit := variety_audit(fabric, catalog)
		print(("seed %2d VARIETY walls %d distinct / %d placed | longest same-"
			+ "asset street run %d | skywalks %d | outcrops %d | stalls %d "
			+ "distinct | roof features %d distinct") % [world_seed,
			int(audit.distinct_wall_assets), int(audit.placed_wall_assets),
			int(audit.longest_same_asset_run), int(audit.skywalk_unit_count),
			int(audit.outcrop_unit_count), int(audit.distinct_stall_assets),
			int(audit.distinct_roof_feature_assets)])
		var supply := overhead_supply_audit(program, fabric, world_seed)
		print(("seed %2d SUPPLY raw skywalk corridors %d, raw outcrop bays %d "
			+ "on the finished town | admitted %d/%d skywalks, %d/%d outcrops")
			% [world_seed, int(supply.raw_skywalks), int(supply.raw_outcrops),
			int(audit.skywalk_unit_count), WarrenBuiltTownSolver.MAX_SKYWALKS,
			int(audit.outcrop_unit_count), WarrenBuiltTownSolver.MAX_OUTCROPS])
	SettlementFabricPlan.DIAGNOSTIC_ALLOW_CORNER_ENVELOPE_OVERLAP = false
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


static func overhead_supply_audit(program: SettlementFabricProgram,
		fabric: SettlementFabricPlan, world_seed: int) -> Dictionary:
	## Budget or supply? Counts every overhead corridor and bay the FINISHED
	## town's socket geometry still offers, unqualified. A budget is binding
	## only when the admitted count sits AT the cap; a raw supply far above an
	## admitted count well under the cap means the refusals are downstream of
	## enumeration, in the exact transaction, not in the budget.
	##
	## Deliberately does not re-run the qualifying pass: that pass rebuilds every
	## sealed unit's bounds per candidate and costs more than the whole solve.
	var raw_skywalks := 0
	var raw_outcrops := 0
	for candidate: Dictionary in WarrenOverheadSolver.candidate_specs(program,
			fabric, world_seed, false):
		if StringName(candidate.category) == &"skywalk":
			raw_skywalks += 1
		else:
			raw_outcrops += 1
	return {
		"raw_skywalks": raw_skywalks,
		"raw_outcrops": raw_outcrops,
	}


static func variety_audit(fabric: SettlementFabricPlan,
		catalog: EnvironmentCatalog) -> Dictionary:
	## Read-only. Wall variety is counted over the assets the catalog itself
	## calls walls, never over an id-prefix guess, so a future bake wave that
	## renames a family cannot silently drop out of the measurement.
	var wall_placements: Array[Dictionary] = []
	var distinct_walls: Dictionary = {}
	var distinct_stalls: Dictionary = {}
	var distinct_roof_features: Dictionary = {}
	for placement: Dictionary in fabric.expanded_placements():
		var asset_id := StringName(placement.asset_id)
		var descriptor := catalog.descriptor(asset_id)
		if descriptor == null:
			continue
		if descriptor.tags.has(&"fabric_wall") \
				or descriptor.tags.has(&"fabric_gable"):
			distinct_walls[asset_id] = true
			wall_placements.append({
				"asset_id": asset_id,
				"origin": (placement.transform as Transform3D).origin,
			})
		if descriptor.tags.has(&"stall"):
			distinct_stalls[asset_id] = true
		if descriptor.tags.has(&"dormer") or descriptor.tags.has(&"roof_seam") \
				or descriptor.tags.has(&"chimney"):
			distinct_roof_features[asset_id] = true
	var skywalks := 0
	var outcrops := 0
	for unit_value: FabricUnit in fabric.units:
		var text := String(unit_value.stable_id)
		if text.begins_with("overhead.skywalk.") \
				or text.begins_with("overhead.corner."):
			skywalks += 1
		elif text.begins_with("overhead.outcrop."):
			outcrops += 1
	return {
		"distinct_wall_assets": distinct_walls.size(),
		"placed_wall_assets": wall_placements.size(),
		"longest_same_asset_run": _longest_same_asset_run(wall_placements),
		"skywalk_unit_count": skywalks,
		"outcrop_unit_count": outcrops,
		"distinct_stall_assets": distinct_stalls.size(),
		"distinct_roof_feature_assets": distinct_roof_features.size(),
	}


static func _longest_same_asset_run(wall_placements: Array[Dictionary]) -> int:
	## "How repetitive does one street face look" -- the longest chain of wall
	## modules sharing an asset id that also share a wall plane (same height,
	## same axis coordinate) and sit one 3 m module apart along that plane.
	## Bounded to the placements the town actually drew, so the measurement is
	## a fact about the render rather than about the recipe tables.
	var lanes: Dictionary = {}
	for placement: Dictionary in wall_placements:
		var origin := placement.origin as Vector3
		for axis in 2:
			var along := origin.z if axis == 0 else origin.x
			var across := origin.x if axis == 0 else origin.z
			var key := "%s|%d|%d|%d" % [placement.asset_id, axis,
				roundi(across * 10.0), roundi(origin.y * 10.0)]
			if not lanes.has(key):
				# Deliberately an Array, not a PackedFloat32Array: the packed
				# types are VALUE types, so `dict[key].append(...)` mutates a
				# copy and every lane silently stays empty.
				lanes[key] = []
			(lanes[key] as Array).append(along)
	var longest := 0
	for key: Variant in lanes:
		var sorted := (lanes[key] as Array).duplicate()
		sorted.sort()
		var run := 1
		for index in range(1, sorted.size()):
			var step: float = absf(float(sorted[index]) - float(sorted[index - 1]))
			run = run + 1 if step > 0.01 and step < 3.2 else 1
			longest = maxi(longest, run)
		longest = maxi(longest, mini(run, sorted.size()))
	return longest


func _report_contact() -> void:
	## Both pipelines, same measurement, so a threshold change can be judged
	## against the pipeline that ships as well as the one being built.
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	for mode: StringName in [WarrenTownSolver.MODE_ROUTE_FIRST,
			WarrenTownSolver.MODE_MASS_FIRST]:
		WarrenTownSolver.GENERATION_MODE = mode
		for world_seed: int in _seeds:
			var towns := WarrenTownSolver.ranked_candidates(world_seed, {},
				program, 4)
			if towns.is_empty():
				print("%s seed %2d: no ranked candidate" % [mode, world_seed])
				continue
			for town: WarrenTownPlan in towns:
				var audit := town.parcels.audit
				print("%s seed %2d attempt %d: n=%d cells=%d parcelratio=%.2f " \
					% [mode, world_seed, int(town.audit.get("route_attempt",
							-1)), int(audit.parcel_count),
						int(audit.get("parcel_footprint_cell_count", 0)),
						float(audit.get(
							"largest_building_contact_component_ratio", 0.0))] \
					+ "cellratio=%.2f isolated=%d isolatedcells=%.3f" \
					% [float(audit.get(
							"largest_building_contact_component_cell_ratio",
							0.0)),
						int(audit.get("isolated_building_count", -1)),
						float(audit.get("isolated_building_cell_ratio", 0.0))])
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


func _roofs_compile(plan: WarrenParcelPlan) -> bool:
	var proposals: Array[Dictionary] = []
	for parcel: WarrenBuildingParcel in plan.parcels:
		var proposal := WarrenParcelConstruction.proposal(parcel)
		if proposal.is_empty():
			return false
		proposals.append(proposal)
	var topology := FabricRoofTopologyPlan.build(proposals)
	if topology == null:
		return false
	return not FabricRoofJunctionModuleTable.build(proposals,
		topology).is_empty()


const READ_FACE_DIRECTIONS: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT,
	Vector3i.FORWARD, Vector3i.BACK]
## What a foundation course can honestly hide: SettlementFabricAssembler's
## STONE_BUDGET_BANDS, restated here so the harness never reads the number it
## is auditing from the class it audits.
const READ_MAX_PLINTH_BANDS := 2


func _report_read() -> void:
	## The round-5 review's three visual claims, measured on the town the
	## preview renders rather than on the partition that precedes it.
	var program: SettlementFabricProgram = null
	if _fabric_stage:
		program = SettlementFabricProgram.compile(
			EnvironmentCatalog.load_default())
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	SettlementFabricPlan.DIAGNOSTIC_ALLOW_CORNER_ENVELOPE_OVERLAP = true
	var floating_total := 0
	var house_total := 0
	var stone_total := 0
	var tallest_face := 0
	for world_seed: int in _seeds:
		var massif := WarrenMassifBuilder.build(world_seed)
		if massif == null:
			print("seed %2d: massif rejected -- %s" % [world_seed,
				WarrenMassifBuilder.last_failure])
			continue
		print("seed %2d BELL %s" % [world_seed, _bell_line(massif)])
		if not _fabric_stage:
			continue
		var attempt := WarrenBuiltTownSolver.diagnostic_best_effort(world_seed,
			program)
		var fabric := attempt.get("fabric") as SettlementFabricPlan
		if fabric == null:
			print("seed %2d READ no fabric -- %s" % [world_seed,
				WarrenBuiltTownSolver.last_failure])
			continue
		var read := read_audit(fabric)
		floating_total += int(read.floating_house_count)
		house_total += int(read.house_count)
		stone_total += int(read.stone_upper_unit_count)
		tallest_face = maxi(tallest_face, int(read.tallest_composed_face_bands))
		print("seed %2d READ floating %d/%d %s | face %d bands (%s) | " % [
				world_seed, int(read.floating_house_count),
				int(read.house_count), str(read.floating_gaps),
				int(read.tallest_composed_face_bands),
				str(read.composed_face_histogram)]
			+ "stone upper %d/%d units" % [int(read.stone_upper_unit_count),
				int(read.room_unit_count)])
		print("seed %2d BUILT core->rim %s over %d fine columns" % [world_seed,
			String(read.built_ring_means), int(read.built_column_count)])
	if _fabric_stage:
		print("TOTAL floating %d/%d houses | tallest composed face %d bands | " \
			% [floating_total, house_total, tallest_face]
			+ "stone upper units %d" % stone_total)
	SettlementFabricPlan.DIAGNOSTIC_ALLOW_CORNER_ENVELOPE_OVERLAP = false
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


static func bell_profile(massif: WarrenMassif) -> Dictionary:
	## Ring means of the massif's own height, measured from the footprint
	## centroid outward and normalised by the widest radius, plus where the peak
	## actually stands. A bell has a low rim, a rising middle and a tall core;
	## an off-centre peak is variation, not a defect.
	var centroid := Vector2.ZERO
	for column: Vector2i in massif.columns:
		centroid += Vector2(column)
	centroid /= float(maxi(1, massif.columns.size()))
	var widest := 0.0
	for column: Vector2i in massif.columns:
		widest = maxf(widest, (Vector2(column) - centroid).length())
	var sums := PackedFloat64Array()
	var counts := PackedInt32Array()
	for _index in 5:
		sums.append(0.0)
		counts.append(0)
	var peak := 0
	var peak_column := Vector2i.ZERO
	var rim_tallest := 0
	for column: Vector2i in massif.columns:
		var height := massif.top_at(column) - massif.base_at(column)
		var ring := clampi(int(floor((Vector2(column) - centroid).length()
			/ maxf(0.001, widest) * 5.0)), 0, 4)
		sums[ring] += float(height)
		counts[ring] += 1
		if height > peak:
			peak = height
			peak_column = column
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP,
				Vector2i.DOWN]:
			if not massif.has_column(column + direction):
				rim_tallest = maxi(rim_tallest, height)
				break
	var means := PackedFloat64Array()
	for ring in 5:
		means.append(sums[ring] / float(maxi(1, counts[ring])))
	return {
		"ring_means": means,
		"peak_bands": peak,
		"peak_offset_cells": (Vector2(peak_column) - centroid).length(),
		"rim_tallest_bands": rim_tallest,
		"column_count": massif.columns.size(),
		"radius_cells": widest,
	}


func _bell_line(massif: WarrenMassif) -> String:
	var profile := bell_profile(massif)
	var means := profile.ring_means as PackedFloat64Array
	var parts := PackedStringArray()
	for ring in means.size():
		parts.append("%.1f" % means[ring])
	return "core->rim %s | peak %d at %.1f cells off centre | rim tallest %d" % [
		" ".join(parts), int(profile.peak_bands),
		float(profile.peak_offset_cells), int(profile.rim_tallest_bands)]


static func read_audit(fabric: SettlementFabricPlan) -> Dictionary:
	## Everything the round-5 notes ask about the RENDERED town, derived from
	## the sealed fabric alone so no stage can claim a wall it does not draw.
	var solids := fabric.transformed_cells(&"solid")
	var retained := fabric.retained_terrace_cells
	## DRAWN support only, and the model must track what the assembler actually
	## emits or the numbers are about an imaginary town.
	## WarrenFabricCompiler declares EVERY unbuilt massif cell as retained, but
	## SettlementFabricAssembler.hill_substrate_walls emits a module only on a
	## column a building stands over, so counting the declaration would score a
	## house as grounded on mass the viewer cannot see -- which is precisely the
	## artefact this stage exists to catch (task-17-report.md §2). Widen this to
	## every retained cell only if that emission rule is ever widened too.
	var ceilings := SettlementFabricAssembler.building_ceiling(solids)
	var support: Dictionary = {}
	for cell_value: Variant in solids.keys():
		support[cell_value as Vector3i] = true
	for cell_value: Variant in retained.keys():
		var cell := cell_value as Vector3i
		var column := Vector2i(cell.x, cell.z)
		if ceilings.has(column) and cell.y < int(ceilings[column]):
			support[cell] = true

	var lowest_band: Dictionary = {}
	var lowest_owner: Dictionary = {}
	for cell_value: Variant in solids.keys():
		var cell := cell_value as Vector3i
		var column := Vector2i(cell.x, cell.z)
		if not lowest_band.has(column) or cell.y < int(lowest_band[column]):
			lowest_band[column] = cell.y
			lowest_owner[column] = StringName(solids[cell])
	var gaps_by_owner: Dictionary = {}
	for column_value: Variant in lowest_band.keys():
		var column := column_value as Vector2i
		var bottom := int(lowest_band[column])
		var gap := bottom
		for band in range(bottom - 1, -1, -1):
			if support.has(Vector3i(column.x, band, column.y)):
				gap = bottom - band - 1
				break
		var owner := StringName(lowest_owner[column])
		gaps_by_owner[owner] = mini(int(gaps_by_owner.get(owner, 1 << 30)), gap)
	var floating := 0
	var gap_histogram: Dictionary = {}
	for owner_value: Variant in gaps_by_owner.keys():
		var gap := int(gaps_by_owner[owner_value])
		gap_histogram[gap] = int(gap_histogram.get(gap, 0)) + 1
		floating += int(gap > READ_MAX_PLINTH_BANDS)

	var runs: Dictionary = {}
	for cell_value: Variant in support.keys():
		var cell := cell_value as Vector3i
		for index in READ_FACE_DIRECTIONS.size():
			if support.has(cell + READ_FACE_DIRECTIONS[index]):
				continue
			var key := Vector3i(cell.x, cell.z, index)
			if not runs.has(key):
				runs[key] = {}
			(runs[key] as Dictionary)[cell.y] = true
	var tallest := 0
	var face_histogram: Dictionary = {}
	for key_value: Variant in runs.keys():
		var bands: Array[int] = []
		bands.assign((runs[key_value] as Dictionary).keys())
		bands.sort()
		var index := 0
		while index < bands.size():
			var last := index
			while last + 1 < bands.size() and bands[last + 1] == bands[last] + 1:
				last += 1
			var run := bands[last] - bands[index] + 1
			tallest = maxi(tallest, run)
			face_histogram[run] = int(face_histogram.get(run, 0)) + 1
			index = last + 1

	var stone_upper := 0
	var room_units := 0
	for unit_value: FabricUnit in fabric.units:
		var text := String(unit_value.recipe_id)
		if not text.begins_with("room."):
			continue
		room_units += 1
		if not text.contains(".upper"):
			continue
		var recipe_value := fabric.recipe(unit_value.recipe_id)
		if recipe_value == null:
			continue
		for asset_id: StringName in recipe_value.asset_ids():
			if SettlementFabricAssembler.STONE_FACADE_ASSETS.has(asset_id):
				stone_upper += 1
				break
	## The BUILT silhouette, which is the one a viewer actually sees: the massif
	## may be a textbook bell and still read as a mesa if only a patch of it
	## carries houses. Ring means over the built columns alone, centroid and
	## radius taken from the built area itself.
	var built_top: Dictionary = {}
	var built_centroid := Vector2.ZERO
	for cell_value: Variant in solids.keys():
		var cell := cell_value as Vector3i
		var column := Vector2i(cell.x, cell.z)
		if not built_top.has(column):
			built_centroid += Vector2(column)
		built_top[column] = maxi(int(built_top.get(column, cell.y)), cell.y)
	built_centroid /= float(maxi(1, built_top.size()))
	var built_radius := 0.0
	for column_value: Variant in built_top.keys():
		built_radius = maxf(built_radius,
			(Vector2(column_value as Vector2i) - built_centroid).length())
	var built_sums := PackedFloat64Array()
	var built_counts := PackedInt32Array()
	for _index in 5:
		built_sums.append(0.0)
		built_counts.append(0)
	for column_value: Variant in built_top.keys():
		var ring := clampi(int(floor(
			(Vector2(column_value as Vector2i) - built_centroid).length()
			/ maxf(0.001, built_radius) * 5.0)), 0, 4)
		built_sums[ring] += float(int(built_top[column_value]))
		built_counts[ring] += 1
	var built_means := PackedStringArray()
	for ring in 5:
		built_means.append("%.1f" % (built_sums[ring]
			/ float(maxi(1, built_counts[ring]))))
	return {
		"built_ring_means": " ".join(built_means),
		"built_column_count": built_top.size(),
		"house_count": gaps_by_owner.size(),
		"floating_house_count": floating,
		"floating_gaps": _sorted_histogram(gap_histogram),
		"tallest_composed_face_bands": tallest,
		"composed_face_histogram": _sorted_histogram(face_histogram),
		"stone_upper_unit_count": stone_upper,
		"room_unit_count": room_units,
	}


static func _sorted_histogram(counts: Dictionary) -> String:
	var keys: Array[int] = []
	keys.assign(counts.keys())
	keys.sort()
	var parts := PackedStringArray()
	for key: int in keys:
		parts.append("%d:%d" % [key, int(counts[key])])
	return "{%s}" % ", ".join(parts)


func _report_route_first_ab() -> void:
	## The controlled diff the SHIPPING pipeline is owed. Mass-first work keeps
	## touching shared vocabulary tables -- the facade family list, the market
	## pool, the bay roll -- and route-first reads every one of them. Green tests
	## say no contract broke; only this says the same seeds still compose the
	## same towns.
	##
	## Deliberately runs the real `solve`, not `diagnostic_best_effort`: solve is
	## what ships, and its acceptance is the quantity that may not regress. The
	## signature is printed as a SHA-256 digest with its source length beside it,
	## because the raw signature is tens of kilobytes and only exact equality
	## matters when comparing two revisions.
	##
	## GENERATION_MODE is deliberately left at its default. Route-first is the
	## default, and a harness that sets the mode it means to measure can no
	## longer detect the mode being wrong.
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	if program == null:
		print("no compiled construction vocabulary")
		return
	print("mode %s | recipes %d | market stalls %d" % [
		WarrenTownSolver.GENERATION_MODE, program.recipes().size(),
		SettlementFabricProgram.MARKET_STALLS.size()])
	var accepted := 0
	for world_seed: int in _seeds:
		var start := Time.get_ticks_msec()
		var ranked := WarrenTownSolver.ranked_candidates(world_seed, {}, program,
			WarrenTownSolver.COMPOSED_PLAN_FRONTIER).size()
		var town := WarrenBuiltTownSolver.solve(world_seed, program)
		var elapsed := float(Time.get_ticks_msec() - start) / 1000.0
		if town == null:
			print("route-first seed %2d REJECT ranked %d | %.0f s | %s"
				% [world_seed, ranked, elapsed,
				WarrenBuiltTownSolver.last_failure.substr(0, 200)])
			continue
		accepted += 1
		var signature := town.deterministic_signature()
		print("route-first seed %2d ACCEPT ranked %d | %.0f s | sig %s len %d"
			% [world_seed, ranked, elapsed,
			signature.sha256_text().substr(0, 24), signature.length()]
			+ " | buildings %d | facade families %d ratio %.3f" % [
				int(town.audit.get("building_stack_count", -1)),
				int(town.audit.get("facade_family_count", -1)),
				float(town.audit.get("largest_facade_family_ratio", -1.0))]
			+ " | skywalks %d | targets met %s" % [
				int(town.audit.get("skywalk_link_count", -1)),
				str(town.audit.get("visual_quality_target_met", false))])
	print("ROUTE-FIRST ACCEPTED %d/%d" % [accepted, _seeds.size()])


func _report_timing() -> void:
	## WHERE the wall clock goes, split at the two public boundaries that
	## separate the only two stages a vocabulary change can slow down:
	##
	##   rank    WarrenTownSolver.ranked_candidates -- the parcel/frontier
	##           search. Under route-first this is where
	##           WarrenAssetCompiler.parcels_are_visually_compatible runs its
	##           O(n^2) measured-envelope broad phase; under mass-first
	##           _parcelize returns partition_parcels and never reaches it.
	##   detail  everything WarrenBuiltTownSolver builds on top -- asset
	##           compile, fabric compile, then the market / outcrop / skywalk
	##           admission passes. Each of those pays a FULL
	##           WarrenFabricCompiler.solve per trial, admitted or refused.
	##
	## The CENSUS line is what turns a slow number into a mechanism. An
	## admission pass that walks N candidates at t seconds a rebuild cannot cost
	## less than N*t, so a pool that multiplies N is legible here without a
	## profiler -- and a pool that widens CHOICE without multiplying N leaves
	## this line flat. Read `market` against `detail`: when N*t accounts for most
	## of the detail time, the pool feeds a search rather than a choice.
	var wall := Time.get_ticks_msec()
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	print("program compile %d ms | recipes %d | market stalls %d"
		% [Time.get_ticks_msec() - wall,
		program.recipes().size() if program != null else -1,
		SettlementFabricProgram.MARKET_STALLS.size()])
	if program == null:
		return
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	SettlementFabricPlan.DIAGNOSTIC_ALLOW_CORNER_ENVELOPE_OVERLAP = true
	for world_seed: int in _seeds:
		var rank_start := Time.get_ticks_msec()
		var towns := WarrenTownSolver.ranked_candidates(world_seed, {}, program,
			WarrenTownSolver.COMPOSED_PLAN_FRONTIER)
		var rank_ms := Time.get_ticks_msec() - rank_start
		print("seed %2d CENSUS %s" % [world_seed,
			_timing_census(program, towns, world_seed)])
		var solve_start := Time.get_ticks_msec()
		var attempt := WarrenBuiltTownSolver.diagnostic_best_effort(world_seed,
			program)
		var solve_ms := Time.get_ticks_msec() - solve_start
		print("seed %2d TIMING rank %.1f s | solve %.1f s | detail %.1f s | %s"
			% [world_seed, float(rank_ms) / 1000.0, float(solve_ms) / 1000.0,
			float(solve_ms - rank_ms) / 1000.0,
			"fabric" if attempt.get("fabric") != null else "NO FABRIC"])
	SettlementFabricPlan.DIAGNOSTIC_ALLOW_CORNER_ENVELOPE_OVERLAP = false
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


func _timing_census(program: SettlementFabricProgram,
		towns: Array[WarrenTownPlan], world_seed: int) -> String:
	## One candidate, taken to the same bare parcel fabric the detail phases
	## start from, then asked what each of those phases will have to walk. The
	## single measured WarrenFabricCompiler.solve is the unit price every
	## admission trial pays, so `N x t` is a floor on that pass's cost.
	if towns.is_empty():
		return "no ranked candidate -- %s" % WarrenTownSolver.last_failure
	var variants := WarrenTownSolver.infill_variants(towns[0])
	if variants.is_empty():
		return "no infill variant"
	var town := variants[0]
	var assets := WarrenAssetCompiler.solve(town, program)
	if assets == null:
		return "no asset plan -- %s" % WarrenAssetCompiler.last_failure
	var compile_start := Time.get_ticks_usec()
	var fabric := WarrenFabricCompiler.solve(assets)
	var compile_us := Time.get_ticks_usec() - compile_start
	if fabric == null:
		return "no parcel fabric -- %s" % WarrenFabricCompiler.last_failure
	var markets := WarrenMarketSolver.candidate_specs(program, fabric,
		town.volume, world_seed, town.pruning.daylight_void_columns).size()
	var overhead := WarrenOverheadSolver.candidate_specs(program, fabric,
		world_seed).size()
	var unit := float(compile_us) / 1000000.0
	return ("ranked %d | parcels %d | one fabric rebuild %.2f s" % [towns.size(),
		town.parcels.parcels.size(), unit]
		+ " | market candidates %d (floor %.0f s)" % [markets,
			float(markets) * unit]
		+ " | overhead candidates %d (floor %.0f s)" % [overhead,
			float(overhead) * unit])


func _report_terrain() -> void:
	## READ-ONLY AUDIT for the phase-2 terrain milestone: mass-first has only
	## ever been exercised at base=0, so what actually happens when the village
	## layer hands it real ground bands is unknown rather than known-good.
	##
	## Three frames over the same seeds: flat (the pinned case), a steady SLOPE
	## across the footprint, and a TERRACED step field in the shape
	## test_village_plan.gd's _terraced_region uses. Every stage from the massif
	## to the partition is run and the first one that refuses is named.
	var span := WarrenMassifBuilder.RADIUS_CELLS + 4
	var frames: Array[Dictionary] = []
	var flat: Dictionary = {}
	var slope: Dictionary = {}
	var terraced: Dictionary = {}
	for z in range(-span, span + 1):
		for x in range(-span, span + 1):
			var column := Vector2i(x, z)
			flat[column] = 0
			slope[column] = clampi((x + span) / 4, 0, 8)
			terraced[column] = 0 if x <= -1 else (2 if x == 0 else 6)
	frames.append({"name": "flat", "bands": flat})
	frames.append({"name": "slope 0-8", "bands": slope})
	frames.append({"name": "terrace 0/2/6", "bands": terraced})
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	for frame: Dictionary in frames:
		for world_seed: int in _seeds:
			print("%-16s seed %2d: %s" % [frame.name, world_seed,
				_terrain_probe(world_seed, frame.bands as Dictionary)])
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


func _terrain_probe(world_seed: int, ground_bands: Dictionary) -> String:
	var massif := WarrenMassifBuilder.build(world_seed, ground_bands)
	if massif == null:
		return "massif rejected -- %s" % WarrenMassifBuilder.last_failure
	var lowest := 1 << 30
	var highest := -(1 << 30)
	var deepest_bearing := 0
	for column: Vector2i in massif.columns:
		lowest = mini(lowest, massif.base_at(column))
		highest = maxi(highest, massif.top_at(column))
		deepest_bearing = maxi(deepest_bearing,
			massif.bearing_at(column) - massif.base_at(column))
	var frontier := WarrenTownSolver.mass_first_frontier(world_seed,
		ground_bands)
	var text := "base %d..%d top %d bearing lift <=%d" % [lowest,
		massif.base_at(massif.columns.keys()[0] as Vector2i), highest,
		deepest_bearing]
	if frontier.is_empty():
		return "%s | NO FRONTIER -- %s" % [text, WarrenTownSolver.last_failure]
	var volume := frontier[0]
	var plan := WarrenTownSolver.partition_parcels(volume)
	if plan == null:
		return "%s | frontier %d | NO PARTITION -- %s" % [text,
			frontier.size(), WarrenTownSolver.last_partition_failure]
	var below_ground := 0
	var undersides: Dictionary = {}
	for parcel: WarrenBuildingParcel in plan.parcels:
		var proposal := WarrenParcelConstruction.proposal(parcel)
		if proposal.is_empty():
			below_ground += 1
			continue
		var origin := proposal.origin as Vector3i
		var lift := 1 << 30
		for column: Vector2i in parcel.footprint:
			lift = mini(lift, origin.y - massif.base_at(column))
		undersides[lift] = int(undersides.get(lift, 0)) + 1
	return "%s | frontier %d | houses %d | no-proposal %d | " % [text,
		frontier.size(), plan.parcels.size(), below_ground] \
		+ "underside above own ground %s" % _sorted_histogram(undersides)


# --- Wave 0: the terrace-over-tunnel motif site census -----------------------
#
# Read-only throughout. Every number below is measured off an UNMODIFIED massif
# and an UNMODIFIED excavation; nothing here lifts a column, bores a passage or
# touches a constant. The design (docs/superpowers/specs/
# 2026-08-10-warren-terrace-tunnel-motif-design.md) names site scarcity as its
# own most likely failure mode (R1) and gives this stage the authority to refute
# it, so the predicate is transcribed from §3.4 rather than approximated.

## Seeds in the stamped corpus the terrain milestone measures on.
const MOTIF_SEED_COUNT := 40
## `U` in the design's notation: the open air a lifted column leaves beneath it,
## which is exactly the void one street cell removes.
const MOTIF_UNDERCROFT_BANDS := WarrenExcavation.HEADROOM_BANDS
## §3.4: "a 4-connected run of 2..MAX_PLATEAU_CELLS columns".
const MOTIF_MIN_RUN_CELLS := 2
const MOTIF_MAX_RUN_CELLS := WarrenMassifBuilder.MAX_PLATEAU_CELLS
## §3.4: "at least 2 columns inside the footprint boundary".
const MOTIF_MIN_INTERIOR_CELLS := 2
## §3.4: "a public cell at band `D ± 1` within 2 columns of the run".
const MOTIF_DECK_ANCHOR_REACH_CELLS := 2
const MOTIF_DECK_ANCHOR_BAND_SLACK := 1
## The two deck datums of §3.3 rows 9-13, which is the whole layer arithmetic:
## a deck lane one band above the deck needs five bands of layer, a deck lane ON
## the deck needs six. Measured separately because they are different towns.
const MOTIF_LAYER_FOR_DECK_PLUS_ONE := 5
const MOTIF_LAYER_FOR_DECK := WarrenMassif.BUILDABLE_LAYER_BANDS
## The supply lever of §3.3/§7: the relief budget is the reviewer's pending
## ruling, so the census is run twice and the delta is the ruling's price tag.
const MOTIF_BUDGET_DELTA_BANDS := 4
## The undercroft opening R2 asks the vocabulary for: one column wide, one
## street storey tall. The no-scaling rule that killed the WWall ramparts is
## absolute, so the test is against the asset's own baked bounding box.
const MOTIF_OPENING_SPAN_M := WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M
const MOTIF_OPENING_HEIGHT_M := WarrenExcavation.HEADROOM_BANDS \
	* WarrenVolumePlan.VERTICAL_BAND_SIZE_M
const MOTIF_FIT_TOLERANCE_M := 0.10
const MOTIF_DESCRIPTOR_DIR := "res://terrain/environment/catalog/descriptors"
## The pieces §3.8 names as the intended undercroft vocabulary, reported with
## their measured sizes whether they fit or not -- "it does not fit" is the
## answer R2 is asking for, and a bare absence from the fitting list is weaker
## evidence than the number.
const MOTIF_NAMED_SUPPORTS: Array[String] = ["sfv.arch.001", "sfv.arch.002",
	"sfv.entrance_arch.001", "sfv.bridge.001", "sfv.foundation.rock.001"]
## Tags a piece must carry before "it fits in the hole" means "it can hold the
## deck up". Without this the fit test passes 179 of 375 descriptors, almost all
## of them wall panels, dormers and grass.
const MOTIF_SUPPORT_TAGS: Array[String] = ["arch", "beam", "brace", "bridge",
	"column", "fabric_brace", "foundation", "pier", "pillar", "post",
	"support"]
const MOTIF_REFUSALS: Array[String] = ["bore", "rim", "passage-anchor",
	"deck-anchor"]

var _motif_ground_cache: Dictionary = {}


func _report_motif() -> void:
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_MASS_FIRST
	print("MOTIF SITE CENSUS -- terrace-over-tunnel design Wave 0, read-only.")
	print("site = flat 4-connected run of %d..%d massif columns, equal base_at," \
		% [MOTIF_MIN_RUN_CELLS, MOTIF_MAX_RUN_CELLS])
	print("  layer >= the deck datum's demand, >=%d columns off the rim," \
		% MOTIF_MIN_INTERIOR_CELLS)
	print("  no column touched by the bore/a lane/a portal,")
	print("  a public cell at band g beside an END of the run (passage anchor),")
	print("  a public cell at band D+-%d within %d columns (deck anchor)." \
		% [MOTIF_DECK_ANCHOR_BAND_SLACK, MOTIF_DECK_ANCHOR_REACH_CELLS])
	print("D = g + %d. `cand` counts every legal run; `sites` is the greedy" \
		% MOTIF_UNDERCROFT_BANDS)
	print("  column-disjoint packing of them -- what a town could actually build.")
	var budgets: Array[float] = [SettlementReliefPlan.RELIEF_BUDGET_METRES,
		SettlementReliefPlan.RELIEF_BUDGET_METRES
			+ float(MOTIF_BUDGET_DELTA_BANDS)
			* WarrenVolumePlan.VERTICAL_BAND_SIZE_M]
	for budget: float in budgets:
		_motif_budget_report(budget)
	_motif_support_census()
	WarrenTownSolver.GENERATION_MODE = WarrenTownSolver.MODE_ROUTE_FIRST


func _motif_budget_report(budget_metres: float) -> void:
	print("")
	print("=== relief budget %.1f m (%.2f bands, %d terrace steps) ===" \
		% [budget_metres, budget_metres / WarrenVolumePlan.VERTICAL_BAND_SIZE_M,
		SettlementReliefPlan.terrace_steps(budget_metres)])
	var rows: Array[Dictionary] = []
	for world_seed: int in _seeds:
		var row := _motif_seed_census(world_seed, budget_metres)
		rows.append(row)
		if row.has("failure"):
			print("seed %2d: %s" % [world_seed, row["failure"]])
			continue
		print(("seed %2d: cols %3d l>=5 %3d l=6 %3d flat %2d/%2d benches %3d " \
			+ "| route %2d public %2d | D+1 cand %3d sites %2d cells %2d " \
			+ "bench %d rings %d/%d/%d | D cand %3d sites %2d cells %2d " \
			+ "| sole %s") % [world_seed,
			int(row["columns"]), int(row["layer5"]), int(row["layer6"]),
			int(row["d1_component"]), int(row["d0_component"]),
			int(row["bench_edges"]),
			int(row["route"]), int(row["public"]),
			int(row["d1_candidates"]), int(row["d1_sites"]),
			int(row["d1_cells"]), int(row["d1_bench"]),
			int(row["d1_inner"]), int(row["d1_middle"]), int(row["d1_outer"]),
			int(row["d0_candidates"]), int(row["d0_sites"]),
			int(row["d0_cells"]), row["d1_sole"]])
	_motif_summary(rows)


func _motif_summary(rows: Array[Dictionary]) -> void:
	var built: Array[Dictionary] = []
	for row: Dictionary in rows:
		if not row.has("failure"):
			built.append(row)
	print("-- summary over %d/%d seeds that built a massif and a bore" \
		% [built.size(), rows.size()])
	if built.is_empty():
		return
	var bench_edges := 0
	var benchless := 0
	for row: Dictionary in built:
		bench_edges += int(row["bench_edges"])
		benchless += int(int(row["bench_edges"]) == 0)
	print("   bench edges (adjacent ground step of exactly %d bands): %.1f " \
		% [MOTIF_UNDERCROFT_BANDS, float(bench_edges) / float(built.size())] \
		+ "per seed, %d seeds with none" % benchless)
	for datum: String in ["d1", "d0"]:
		var label := "deck lane at D    (layer >= %d)" % MOTIF_LAYER_FOR_DECK
		if datum == "d1":
			label = "deck lane at D+1 (layer >= %d)" \
				% MOTIF_LAYER_FOR_DECK_PLUS_ONE
		var sites: Array[int] = []
		var zero := 0
		var passage_cells := 0
		var route_cells := 0
		var bench := 0
		var rings := [0, 0, 0]
		var sole: Dictionary = {}
		for row: Dictionary in built:
			var count := int(row["%s_sites" % datum])
			sites.append(count)
			zero += int(count == 0)
			passage_cells += int(row["%s_cells" % datum])
			route_cells += int(row["route"])
			bench += int(row["%s_bench" % datum])
			rings[0] += int(row["%s_inner" % datum])
			rings[1] += int(row["%s_middle" % datum])
			rings[2] += int(row["%s_outer" % datum])
			for key: String in MOTIF_REFUSALS:
				sole[key] = int(sole.get(key, 0)) \
					+ int((row["%s_sole_counts" % datum] as Dictionary).get(
						key, 0))
		sites.sort()
		var total := 0
		for count: int in sites:
			total += count
		var seeds_with := built.size() - zero
		print(("   %s: sites/seed min %d median %d max %d mean %.2f | " \
			+ "zero-site seeds %d/%d (%.0f%% carry >=1) | passage cells " \
			+ "%d vs route cells %d = %.3f of the street | bench-level sites " \
			+ "%d | crown/mid/rim %d/%d/%d") % [label, sites[0],
			sites[sites.size() / 2], sites[-1],
			float(total) / float(built.size()), zero, built.size(),
			100.0 * float(seeds_with) / float(built.size()), passage_cells,
			route_cells, float(passage_cells) / float(maxi(1, route_cells)),
			bench, rings[0], rings[1], rings[2]])
		var parts := PackedStringArray()
		for key: String in MOTIF_REFUSALS:
			parts.append("%s %d" % [key, int(sole.get(key, 0))])
		print("     sole blocker over every enumerated run: %s" \
			% " ".join(parts))


func _motif_seed_census(world_seed: int, budget_metres: float) -> Dictionary:
	var bands := _motif_ground_bands(world_seed, budget_metres)
	var massif := WarrenMassifBuilder.build(world_seed, bands)
	if massif == null:
		return {"failure": "MASSIF -- %s" % WarrenMassifBuilder.last_failure}
	# The motif is a stage seam INSIDE the frontier's bore loop (§3.4), so the
	# excavation it sees is whatever that loop carved. Take the first attempt
	# that carves, on the frontier's own attempt schedule, so this census is
	# about a bore the pipeline actually produces.
	var excavation: WarrenExcavation = null
	for attempt in WarrenTownSolver.MASS_FIRST_EXCAVATION_ATTEMPTS:
		excavation = WarrenExcavationCarver.carve(world_seed
			+ attempt * WarrenTownSolver.MASS_FIRST_ATTEMPT_STRIDE, massif)
		if excavation != null:
			break
	if excavation == null:
		return {"failure": "BORE -- %s" % WarrenExcavationCarver.last_failure}
	var layer5 := 0
	var layer6 := 0
	for column: Vector2i in massif.columns:
		var layer := massif.layer_at(column)
		layer5 += int(layer >= MOTIF_LAYER_FOR_DECK_PLUS_ONE)
		layer6 += int(layer >= MOTIF_LAYER_FOR_DECK)
	var row: Dictionary = {
		"seed": world_seed,
		"columns": massif.columns.size(),
		"layer5": layer5,
		"layer6": layer6,
		"route": excavation.route.size(),
		"public": excavation.public_cells().size(),
		"bench_edges": _motif_bench_edges(massif),
	}
	var datums: Dictionary = {
		"d1": MOTIF_LAYER_FOR_DECK_PLUS_ONE,
		"d0": MOTIF_LAYER_FOR_DECK,
	}
	for key: String in ["d1", "d0"]:
		var census := _motif_sites(massif, excavation, int(datums[key]))
		var packed: Array[Dictionary] = census["packed"]
		var legal: Array[Dictionary] = census["legal"]
		var cells := 0
		var bench := 0
		var rings := [0, 0, 0]
		for site: Dictionary in packed:
			cells += (site["columns"] as Array).size()
			bench += int(bool(site["bench"]))
			rings[int(site["ring"])] += 1
		row["%s_candidates" % key] = legal.size()
		row["%s_enumerated" % key] = int(census["enumerated"])
		row["%s_sites" % key] = packed.size()
		row["%s_cells" % key] = cells
		row["%s_bench" % key] = bench
		row["%s_inner" % key] = rings[0]
		row["%s_middle" % key] = rings[1]
		row["%s_outer" % key] = rings[2]
		row["%s_component" % key] = int(census["component"])
		row["%s_sole_counts" % key] = census["sole"]
		row["%s_sole" % key] = _motif_refusal_text(census["sole"] as Dictionary)
	return row


func _motif_bench_edges(massif: WarrenMassif) -> int:
	## THE BENCH CENSUS the design asks for: adjacent columns whose own ground
	## differs by exactly one undercroft. Those are the edges where a lifted
	## deck comes out level with an ordinary at-grade street, which is the
	## natural anchor §3.3 says more relief budget buys more of.
	var count := 0
	for column: Vector2i in massif.columns:
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbour := column + direction
			if not massif.has_column(neighbour):
				continue
			if absi(massif.base_at(neighbour) - massif.base_at(column)) \
					== MOTIF_UNDERCROFT_BANDS:
				count += 1
	return count


func _motif_refusal_text(counts: Dictionary) -> String:
	var parts := PackedStringArray()
	for key: String in MOTIF_REFUSALS:
		var value := int(counts.get(key, 0))
		if value > 0:
			parts.append("%s:%d" % [key, value])
	return "none" if parts.is_empty() else " ".join(parts)


func _motif_sites(massif: WarrenMassif, excavation: WarrenExcavation,
		min_layer: int) -> Dictionary:
	## Enumerates every run the design would consider and says, for each, which
	## clause of §3.4 refused it. The refusal split is the point: "no sites"
	## and "no sites because the bore is standing on all of them" are different
	## verdicts and only one of them can be answered by a supply lever.
	var blocked: Dictionary = {}
	var public_at: Dictionary = {}
	for cell: Vector3i in excavation.carved:
		blocked[Vector2i(cell.x, cell.z)] = true
	for cell: Vector3i in excavation.public_cells():
		blocked[Vector2i(cell.x, cell.z)] = true
		public_at[cell] = true
	for cell: Vector3i in excavation.portals:
		blocked[Vector2i(cell.x, cell.z)] = true
		public_at[cell] = true
	var crown := _motif_crown(massif)
	var reach := 0
	for column: Vector2i in massif.columns:
		reach = maxi(reach, absi(column.x - crown.x) + absi(column.y - crown.y))
	var eligible: Array[Vector2i] = []
	for column: Vector2i in massif.columns:
		if massif.layer_at(column) >= min_layer:
			eligible.append(column)
	eligible.sort()
	var eligible_set: Dictionary = {}
	for column: Vector2i in eligible:
		eligible_set[column] = true
	# Every §3.4 clause is a per-COLUMN property once the run's ground band is
	# fixed, and a run has one ground band by construction, so precomputing
	# them turns the path scan into an aggregation.
	var interior: Dictionary = {}
	var passage_anchor: Dictionary = {}
	var deck_anchor: Dictionary = {}
	var bench: Dictionary = {}
	for column: Vector2i in eligible:
		var ground := massif.base_at(column)
		var inside := true
		var touches_bench := false
		var at_grade := false
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
				Vector2i.UP, Vector2i.DOWN]:
			var neighbour := column + direction
			if not massif.has_column(neighbour):
				inside = false
				continue
			# The supply-lever note (§3.3): a neighbour whose own ground stands
			# exactly one undercroft higher puts an ordinary at-grade street
			# level with this column's deck.
			touches_bench = touches_bench \
				or massif.base_at(neighbour) - ground == MOTIF_UNDERCROFT_BANDS
			at_grade = at_grade or public_at.has(
				Vector3i(neighbour.x, ground, neighbour.y))
		interior[column] = inside
		bench[column] = touches_bench
		passage_anchor[column] = at_grade
		deck_anchor[column] = _motif_deck_anchor(public_at, column,
			ground + MOTIF_UNDERCROFT_BANDS)
	var legal: Array[Dictionary] = []
	var state: Dictionary = {
		"massif": massif,
		"eligible": eligible_set,
		"blocked": blocked,
		"interior": interior,
		"passage_anchor": passage_anchor,
		"deck_anchor": deck_anchor,
		"bench": bench,
		"crown": crown,
		"reach": maxi(1, reach),
		"enumerated": 0,
		"sole": {},
		"legal": legal,
	}
	for start: Vector2i in eligible:
		var path: Array[Vector2i] = [start]
		_motif_walk(path, state)
	return {
		"enumerated": int(state["enumerated"]),
		"component": _motif_largest_component(massif, eligible, eligible_set),
		"sole": state["sole"],
		"legal": legal,
		"packed": _motif_pack(legal),
	}


func _motif_largest_component(massif: WarrenMassif, eligible: Array[Vector2i],
		eligible_set: Dictionary) -> int:
	## The raw supply before any anchor is asked for: the widest patch of deep
	## enough layer standing on ONE ground band. A run can never be longer than
	## this, so a small number here refutes the motif on arithmetic alone.
	var seen: Dictionary = {}
	var widest := 0
	for start: Vector2i in eligible:
		if seen.has(start):
			continue
		var ground := massif.base_at(start)
		var frontier: Array[Vector2i] = [start]
		seen[start] = true
		var size := 0
		while not frontier.is_empty():
			var column: Vector2i = frontier.pop_back()
			size += 1
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
					Vector2i.UP, Vector2i.DOWN]:
				var neighbour := column + direction
				if seen.has(neighbour) or not eligible_set.has(neighbour):
					continue
				if massif.base_at(neighbour) != ground:
					continue
				seen[neighbour] = true
				frontier.append(neighbour)
		widest = maxi(widest, size)
	return widest


func _motif_deck_anchor(public_at: Dictionary, column: Vector2i,
		deck: int) -> bool:
	for dz in range(-MOTIF_DECK_ANCHOR_REACH_CELLS,
			MOTIF_DECK_ANCHOR_REACH_CELLS + 1):
		var span := MOTIF_DECK_ANCHOR_REACH_CELLS - absi(dz)
		for dx in range(-span, span + 1):
			for band in range(deck - MOTIF_DECK_ANCHOR_BAND_SLACK,
					deck + MOTIF_DECK_ANCHOR_BAND_SLACK + 1):
				if public_at.has(Vector3i(column.x + dx, band,
						column.y + dz)):
					return true
	return false


func _motif_walk(path: Array[Vector2i], state: Dictionary) -> void:
	## Depth-first over flat 4-connected runs. A path and its reverse are the
	## same site, so only the orientation whose first column sorts lower is
	## scored -- the dedup is exact because a simple path has two distinct ends.
	if path.size() >= MOTIF_MIN_RUN_CELLS and path[0] < path[-1]:
		_motif_score(path, state)
	if path.size() >= MOTIF_MAX_RUN_CELLS:
		return
	var massif := state["massif"] as WarrenMassif
	var eligible := state["eligible"] as Dictionary
	var ground := massif.base_at(path[0])
	var tail: Vector2i = path[-1]
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP,
			Vector2i.DOWN]:
		var next := tail + direction
		if not eligible.has(next):
			continue
		if massif.base_at(next) != ground:
			continue
		if path.has(next):
			continue
		path.append(next)
		_motif_walk(path, state)
		path.resize(path.size() - 1)


func _motif_score(path: Array[Vector2i], state: Dictionary) -> void:
	state["enumerated"] = int(state["enumerated"]) + 1
	var blocked := state["blocked"] as Dictionary
	var interior := state["interior"] as Dictionary
	var passage_anchor := state["passage_anchor"] as Dictionary
	var deck_anchor := state["deck_anchor"] as Dictionary
	var bench := state["bench"] as Dictionary
	var refused := PackedStringArray()
	var free := true
	var inside := 0
	var reaches_deck := false
	var against_bench := false
	for column: Vector2i in path:
		free = free and not blocked.has(column)
		inside += int(bool(interior.get(column, false)))
		reaches_deck = reaches_deck or bool(deck_anchor.get(column, false))
		against_bench = against_bench or bool(bench.get(column, false))
	if not free:
		refused.append("bore")
	if inside < MOTIF_MIN_INTERIOR_CELLS:
		refused.append("rim")
	if not (bool(passage_anchor.get(path[0], false))
			or bool(passage_anchor.get(path[-1], false))):
		refused.append("passage-anchor")
	if not reaches_deck:
		refused.append("deck-anchor")
	if refused.size() == 1:
		var sole := state["sole"] as Dictionary
		sole[refused[0]] = int(sole.get(refused[0], 0)) + 1
	if not refused.is_empty():
		return
	var massif := state["massif"] as WarrenMassif
	var crown: Vector2i = state["crown"]
	var distance := 1 << 30
	for column: Vector2i in path:
		distance = mini(distance,
			absi(column.x - crown.x) + absi(column.y - crown.y))
	var columns: Array[Vector2i] = []
	columns.assign(path)
	var legal: Array[Dictionary] = state["legal"]
	legal.append({
		"columns": columns,
		"ground": massif.base_at(path[0]),
		"bench": against_bench,
		"distance": distance,
		# Thirds of the footprint's own reach from the crown, so "crown" and
		# "flank" mean the same thing on a wide massif and a narrow one.
		"ring": mini(2, distance * 3 / int(state["reach"])),
	})


func _motif_pack(legal: Array[Dictionary]) -> Array[Dictionary]:
	## How many sites a town could build AT ONCE. Overlapping runs are the same
	## piece of ground offered twice; counting them all would answer a question
	## nobody asked. Longest first, then a total order on the columns, so the
	## packing is a pure function of the input.
	var order := legal.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := (a["columns"] as Array).size()
		var right := (b["columns"] as Array).size()
		if left != right:
			return left > right
		return str(a["columns"]) < str(b["columns"]))
	var taken: Dictionary = {}
	var out: Array[Dictionary] = []
	for site: Dictionary in order:
		var columns: Array[Vector2i] = site["columns"]
		var clash := false
		for column: Vector2i in columns:
			clash = clash or taken.has(column)
		if clash:
			continue
		for column: Vector2i in columns:
			taken[column] = true
		out.append(site)
	return out


func _motif_crown(massif: WarrenMassif) -> Vector2i:
	var crown := Vector2i.ZERO
	var best := -(1 << 30)
	var best_base := -(1 << 30)
	var columns: Array[Vector2i] = []
	columns.assign(massif.columns.keys())
	columns.sort()
	for column: Vector2i in columns:
		var top := massif.top_at(column)
		var base := massif.base_at(column)
		if top > best or (top == best and base > best_base):
			best = top
			best_base = base
			crown = column
	return crown


func _motif_ground_bands(world_seed: int, budget_metres: float) -> Dictionary:
	## The REAL stamp, sampled the way production samples it
	## (VillageWarrenFabricSolver._sample_ground_bands: five probes per 3 m
	## column, ceiled off the site's own lowest sample). Reproduced here rather
	## than imported because the production reader needs a VillageTerrainView
	## the harness has already built, and because this stage has to be able to
	## re-stamp at a budget production does not currently use.
	var key := "%d@%.2f" % [world_seed, budget_metres]
	if _motif_ground_cache.has(key):
		return _motif_ground_cache[key]
	var water := TerrainWorldTuning.make_water(world_seed)
	var settlements := SettlementPlan.new(world_seed, water)
	var relief := SettlementReliefPlan.new(world_seed, settlements,
		TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE,
		TerrainWorldTuning.HEIGHTFIELD_MAX_STOREYS, budget_metres)
	var plan := TerrainWorldTuning.make_heightfield(world_seed, water, relief)
	var site := Vector2i.ZERO
	for ring in 3:
		var found := false
		for sz in range(-ring, ring + 1):
			for sx in range(-ring, ring + 1):
				var candidate: Dictionary = settlements.site_for(
					Vector2i(sx, sz))
				if candidate.is_empty():
					continue
				site = candidate["cell"] as Vector2i
				found = true
				break
			if found:
				break
		if found:
			break
	var region := plan.compute_region(site.x, site.y,
		TerrainChunkMesher.CELLS_PER_CHUNK)
	var terrain := VillageTerrainView.from_region(region)
	var centre := Vector2(float(site.x), float(site.y)) * TerrainSurfaceField.TILE
	var span := WarrenMassifBuilder.RADIUS_CELLS + 1
	var half := WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M * 0.45
	var maxima: Dictionary = {}
	var lowest := INF
	for z in range(-span, span + 1):
		for x in range(-span, span + 1):
			var point := centre + Vector2(
				float(x) * WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M,
				float(z) * WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M)
			var column_max := -INF
			for offset: Vector2 in [Vector2.ZERO, Vector2(-half, -half),
					Vector2(half, -half), Vector2(-half, half),
					Vector2(half, half)]:
				var height := terrain.surface_y(point + offset)
				column_max = maxf(column_max, height)
				lowest = minf(lowest, height)
			maxima[Vector2i(x, z)] = column_max
	var bands: Dictionary = {}
	for column: Vector2i in maxima:
		bands[column] = ceili((float(maxima[column]) - lowest)
			/ WarrenVolumePlan.VERTICAL_BAND_SIZE_M)
	_motif_ground_cache[key] = bands
	return bands


func _motif_support_census() -> void:
	## R2, and the second half of Wave 0's acceptance: is there a baked piece
	## that can stand in a 3.0 m x 4.5 m undercroft opening WITHOUT SCALING?
	## The measured_aabb the bake writes is already in placed metres, so this
	## is the same test the WWall rampart family failed at 3.8-8.0 m.
	print("")
	print("=== support vocabulary: pieces fitting a %.1f m x %.1f m opening ===" \
		% [MOTIF_OPENING_SPAN_M, MOTIF_OPENING_HEIGHT_M])
	var directory := DirAccess.open(MOTIF_DESCRIPTOR_DIR)
	if directory == null:
		print("  no descriptor catalogue at %s" % MOTIF_DESCRIPTOR_DIR)
		return
	var names := PackedStringArray(directory.get_files())
	names.sort()
	var fitting: Array[String] = []
	var named: Array[String] = []
	var scanned := 0
	var fitted := 0
	var heights: Array[float] = []
	var tallest_in_span := 0.0
	var tallest_id := "none"
	for file_name: String in names:
		if not file_name.ends_with(".tres"):
			continue
		var descriptor: Resource = load("%s/%s" \
			% [MOTIF_DESCRIPTOR_DIR, file_name])
		if descriptor == null:
			continue
		var measured: Variant = descriptor.get("measured_aabb")
		if typeof(measured) != TYPE_AABB:
			continue
		var box: AABB = measured
		scanned += 1
		var identifier := String(descriptor.get("id"))
		var tags := PackedStringArray()
		var raw_tags: Variant = descriptor.get("tags")
		if typeof(raw_tags) == TYPE_ARRAY:
			for tag: Variant in raw_tags as Array:
				tags.append(String(tag))
		var line := "%s  %.2f x %.2f x %.2f m  [%s]" % [identifier,
			box.size.x, box.size.y, box.size.z, " ".join(tags)]
		if MOTIF_NAMED_SUPPORTS.has(identifier):
			named.append(line)
		if box.size.x > MOTIF_OPENING_SPAN_M + MOTIF_FIT_TOLERANCE_M \
				or box.size.z > MOTIF_OPENING_SPAN_M + MOTIF_FIT_TOLERANCE_M:
			continue
		# Tallest thing in the WHOLE catalogue that stands in one column's
		# footprint, tag or no tag: if that is under the opening, no filter
		# choice above can rescue the answer.
		if box.size.y > tallest_in_span:
			tallest_in_span = box.size.y
			tallest_id = identifier
		if box.size.y > MOTIF_OPENING_HEIGHT_M + MOTIF_FIT_TOLERANCE_M:
			continue
		fitted += 1
		var structural := false
		for tag: String in tags:
			structural = structural or MOTIF_SUPPORT_TAGS.has(tag)
		if not structural:
			continue
		# SPANS means one piece reaches the deck. STACKS means the opening is
		# an exact whole number of this piece, so a course of them reaches it
		# -- which is a stricter test than "the piece is a whole number of
		# bands": a 3.0 m pillar is two exact bands and still cannot make 4.5
		# out of copies of itself.
		var courses := MOTIF_OPENING_HEIGHT_M / maxf(0.01, box.size.y)
		var verdict := "SHORT "
		if box.size.y >= MOTIF_OPENING_HEIGHT_M - MOTIF_FIT_TOLERANCE_M:
			verdict = "SPANS "
		elif absf(courses - roundf(courses)) * box.size.y \
				<= MOTIF_FIT_TOLERANCE_M:
			verdict = "STACKS"
		fitting.append("%s %s" % [verdict, line])
		# Only a piece that is itself a whole number of bands can be a member
		# of a course; a 0.39 m brace stacked three deep to make up a shortfall
		# is not masonry, it is scaling by another name.
		var bands := box.size.y / WarrenVolumePlan.VERTICAL_BAND_SIZE_M
		if absf(bands - roundf(bands)) * WarrenVolumePlan.VERTICAL_BAND_SIZE_M \
				<= MOTIF_FIT_TOLERANCE_M and bands >= 0.5:
			heights.append(box.size.y)
	print("  scanned %d descriptors; %d fit the opening; %d of those could" \
		% [scanned, fitted, fitting.size()])
	print("  carry load (tagged %s)" % " ".join(MOTIF_SUPPORT_TAGS))
	print("  SPANS = tall enough to reach the deck; STACKS = an exact multiple")
	print("  of the %.1f m band, so a course of them reaches it without scaling." \
		% WarrenVolumePlan.VERTICAL_BAND_SIZE_M)
	for line: String in fitting:
		print("    %s" % line)
	print("  a course of the whole-band pieces above reaches %.2f m exactly: %s" \
		% [MOTIF_OPENING_HEIGHT_M,
		"YES" if _motif_course_reaches(heights) else "NO"])
	print("  tallest piece of ANY tag standing in one column's footprint: " \
		+ "%s at %.2f m (the opening is %.2f m)" % [tallest_id,
		tallest_in_span, MOTIF_OPENING_HEIGHT_M])
	print("  the pieces design §3.8 names, fitting or not:")
	for line: String in named:
		print("    %s" % line)


func _motif_course_reaches(heights: Array[float]) -> bool:
	## Can ANY multiset of the fitting pieces stack to the undercroft's exact
	## height? A pier that ends 0.9 m under the deck is not a pier, and the
	## no-scaling rule forbids stretching one to close the gap.
	var reachable: Dictionary = {0: true}
	var step := MOTIF_OPENING_HEIGHT_M / 100.0
	for _course in 8:
		var grown: Dictionary = {}
		for key: int in reachable:
			for height: float in heights:
				var total := float(key) * step + height
				if total > MOTIF_OPENING_HEIGHT_M + MOTIF_FIT_TOLERANCE_M:
					continue
				grown[int(roundf(total / step))] = true
		for key: int in grown:
			reachable[key] = true
	for key: int in reachable:
		if key == 0:
			continue
		if absf(float(key) * step - MOTIF_OPENING_HEIGHT_M) \
				<= MOTIF_FIT_TOLERANCE_M:
			return true
	return false
