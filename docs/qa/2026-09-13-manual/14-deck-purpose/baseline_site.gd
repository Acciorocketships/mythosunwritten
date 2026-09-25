extends RefCounted

## One-pass entry point for the constructive maze-town pipeline: massif ->
## carve (unsealed) -> reserve (assets + decks) -> partition (houses, heights,
## bridges, public destinations) -> seal. Every phase is pure and costs milliseconds, so
## `stop_after` simply re-runs the pipeline from scratch up to and including
## the named phase and hands back the still-unsealed plan; the debug view that
## wants a mid-pipeline snapshot calls plan() again with a different
## stop_after rather than this planner keeping any state of its own between
## calls.
const STOP_AFTER_STAGES: Array[StringName] = [
	&"carve", &"reserve", &"partition",
]

static var last_failure := ""


static func plan(world_seed: int, ground_bands: Dictionary,
		profile: WarrenVillageScaleProfile,
		stop_after: StringName = &"",
		collect_diagnostics: bool = true) -> WarrenMazeSourcePlan:
	last_failure = ""
	if stop_after != &"" and stop_after not in STOP_AFTER_STAGES:
		last_failure = "unknown stop_after stage %s" % String(stop_after)
		return null

	var massif := WarrenMassifBuilder.build(world_seed, ground_bands, profile)
	if massif == null:
		last_failure = "massif: %s" % WarrenMassifBuilder.last_failure
		return null

	var source_plan := WarrenMazeCarver.carve(world_seed, massif, profile,
		false, collect_diagnostics)
	if source_plan == null:
		last_failure = "carve: %s" % WarrenMazeCarver.last_failure
		return null
	if stop_after == &"carve":
		return source_plan

	# The plot layer never fails: shortfalls are audit facts (rules become
	# repairs), so neither phase has a rejection path to translate here.
	WarrenPlotPlanner.reserve(source_plan, profile)
	if stop_after == &"reserve":
		return source_plan

	WarrenPlotPlanner.partition(source_plan, profile)
	if stop_after == &"partition":
		return source_plan

	source_plan.finish_construction(collect_diagnostics)
	return source_plan


static func finish_public_destinations(source: WarrenMazeSourcePlan) -> void:
	## Plot allocation supplies actual destinations. Before sealing the source,
	## withdraw a terminal climb above all of them, together with its optional
	## empty lookout. Preserve complete flights and every connecting route.
	if source == null or source.is_sealed() or source.plots.is_empty():
		return
	var old := source.excavation
	if old == null or old.transitions.is_empty():
		return
	var highest: int = old.route.front().y
	var protected: Dictionary = {}
	for plot: Dictionary in source.plots:
		var door: Vector3i = plot.door_walk
		highest = maxi(highest, door.y)
		protected[door] = true
		# A reserved public deck is an intentional destination even when its
		# address is on a lower connecting flight.
		if plot.get("kind", &"") == WarrenMazeSourcePlan.PLOT_DECK:
			highest = maxi(highest, int(plot.floor))
	for cell: Vector3i in old.portals + source.market_zone + source.market_square_cells:
		protected[cell] = true
	var lookout: Dictionary = {}
	for stamp: Dictionary in source.feature_stamps:
		for cell: Vector3i in stamp.get("cells", []):
			if stamp.kind == &"terminal_lookout":
				lookout[cell] = true
			else:
				protected[cell] = true
	for lane: Dictionary in old.lanes:
		if lane.get("feature_kind", &"") == &"terminal_lookout":
			continue
		protected[lane.anchor] = true
		for cell: Vector3i in lane.cells:
			protected[cell] = true
	for edge: Dictionary in old.loop_edges:
		if lookout.has(edge.from) and lookout.has(edge.to):
			continue
		protected[edge.from] = true
		protected[edge.to] = true
	for span: Array in old.bridge_spans:
		for cell: Vector3i in span:
			protected[cell] = true
	# A lookout reached by another lane or used by a plot cannot be withdrawn
	# with the spine's last flight: it is now a real part of the public network.
	for cell: Vector3i in lookout:
		if protected.has(cell):
			for other: Vector3i in lookout:
				protected[other] = true
			break
	var cut := old.route.size()
	var transition_count := old.transitions.size()
	while transition_count > 0:
		var edge: Dictionary = old.transitions[transition_count - 1]
		if (edge.to as Vector3i).y <= highest:
			break
		var start := old.route.find(edge.from)
		if start < 0:
			break
		var can_withdraw := true
		for index in range(start + 1, cut):
			if protected.has(old.route[index]):
				can_withdraw = false
				break
		if not can_withdraw:
			break
		cut = start + 1
		transition_count -= 1
	if cut == old.route.size() or cut < 2:
		return
	var removed: Dictionary = {}
	for cell: Vector3i in old.route.slice(cut):
		removed[cell] = true
	var stamps: Array[Dictionary] = []
	for stamp: Dictionary in source.feature_stamps:
		var withdraw := false
		if stamp.kind == &"terminal_lookout":
			for cell: Vector3i in stamp.cells:
				if removed.has(cell):
					withdraw = true
		if withdraw:
			for cell: Vector3i in stamp.cells:
				removed[cell] = true
		else:
			stamps.append(stamp)
	# Make a fresh construction value rather than mutate a sealed excavation.
	# Its existing negative space remains released; no new rock may fill the
	# discarded stair's swept headroom beside already allocated native houses.
	var excavation := WarrenExcavation.new(old.world_seed)
	excavation.route.assign(old.route.slice(0, cut))
	excavation.transitions.assign(old.transitions.slice(0, transition_count))
	for lane: Dictionary in old.lanes:
		if not removed.has(lane.anchor):
			excavation.lanes.append(lane)
	for edge: Dictionary in old.loop_edges:
		if not removed.has(edge.from) and not removed.has(edge.to):
			excavation.loop_edges.append(edge)
	excavation.carved = old.carved.duplicate()
	excavation.covered = old.covered.duplicate()
	excavation.portals.assign(old.portals)
	excavation.bridge_spans.assign(old.bridge_spans)
	excavation.bridge_span_audit = old.bridge_span_audit.duplicate(true)
	excavation.frontage_reservations = old.frontage_reservations.duplicate()
	for cell: Vector3i in removed:
		source.passage_kinds.erase(cell)
		excavation.covered.erase(cell)
	excavation.finish_construction()
	source.excavation = excavation
	source.feature_stamps = stamps
	source.summit_cell = excavation.route.front()
	for cell: Vector3i in excavation.route:
		if cell.y > source.summit_cell.y:
			source.summit_cell = cell
	source.audit["withdrawn_terminal_public_cells"] = removed.keys()
