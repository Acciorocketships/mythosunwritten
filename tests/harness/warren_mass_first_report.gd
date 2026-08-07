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


func _init() -> void:
	_read_args()
	if _seeds.is_empty():
		_seeds.assign(DEFAULT_SEEDS)
	if _stage == "contact":
		_report_contact()
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
		elif args[index] == "--seeds" and index + 1 < args.size():
			for token: String in args[index + 1].split(",", false):
				_seeds.append(int(token))


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
