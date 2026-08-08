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
##   --stage terrain   READ-ONLY: mass-first run against real ground bands --
##                     flat, a steady slope and a terraced step field -- naming
##                     the first stage that refuses and how far each house's
##                     underside ends up above its own natural ground. Feeds
##                     the phase-2 terrain milestone; fixes nothing.
##   --stage map       one seed's massif drawn as a plan, band heights in hex,
##                     marking every column as street, house, gallery walk cell
##                     or bare solid. The fastest way to see WHERE a town's mass
##                     went unhoused, which no ratio can tell you.
##   --stage contact   both pipelines' building-contact metrics side by side,
##                     parcel-weighted against cell-weighted. Use it when
##                     touching the construction gate's contact threshold.
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
	if _stage == "terrain":
		_report_terrain()
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
	## emits or the numbers are about an imaginary town. Since the round-5
	## grounding fix SettlementFabricAssembler.hill_substrate_walls renders the
	## whole retained solid, so the drawn set is solids plus retained; before it,
	## substrate was emitted only on a column a building stood over, and that
	## narrower set is what the "before" column of task-17-report.md measures.
	var support: Dictionary = {}
	for cell_value: Variant in solids.keys():
		support[cell_value as Vector3i] = true
	for cell_value: Variant in retained.keys():
		support[cell_value as Vector3i] = true

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
