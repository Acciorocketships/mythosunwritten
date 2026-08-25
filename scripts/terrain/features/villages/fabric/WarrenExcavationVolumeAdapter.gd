class_name WarrenExcavationVolumeAdapter
extends RefCounted

## Adapts a Task 2 WarrenExcavation (negative space carved from a Task 1
## WarrenMassif) into the sealed WarrenVolumePlan the downstream parcel/
## asset/construction pipeline already consumes. Nothing about the walk,
## transitions, or solid is re-derived or repaired here: every value is
## copied straight from the massif and the excavation, so a sealed plan can
## only describe the geometry those two objects already agreed on.
static var last_failure := ""


static func envelope_from_massif(massif: WarrenMassif) -> WarrenVolumeEnvelope:
	## Synthesises a WarrenVolumeEnvelope whose columns are an exact copy of
	## the massif's -- ground, height, and the complete unexcavated solid --
	## rather than this class's usual warped Gaussian. Downstream frontage/
	## height logic reads envelope.top_at()/height_at() to see the terraced
	## mass exactly as Task 1 built it, and WarrenVolumePlan.seal() later
	## subtracts the excavation's carved cells from envelope.mass_cells to
	## recover the post-excavation solid -- so mass_cells here must be the
	## FULL pre-excavation block, not a hint of it.
	var envelope := WarrenVolumeEnvelope.new()
	envelope.world_seed = massif.world_seed
	envelope.address_bands = WarrenMassif.ADDRESS_BANDS
	# Route self-crossings scale with the mountain: a grand mound interleaves
	# its climb over the lower alleys twice, a village once. The quality
	# meaning is unchanged — one public level must still roof another — and
	# the footprint proxy is the massif's own column count (roughly pi times
	# radius squared in macro columns).
	envelope.upper_route_crossovers = WarrenMassif.UPPER_ROUTE_CROSSOVERS \
		if massif.columns.size() >= 300 else 1
	envelope.plinth_budget_bands = WarrenMassif.PLINTH_BUDGET_BANDS
	var min_x := 2147483647
	var max_x := -2147483648
	var min_z := 2147483647
	var max_z := -2147483648
	for column_value: Variant in massif.columns.keys():
		var column := column_value as Vector2i
		var base := massif.base_at(column)
		var top := massif.top_at(column)
		# WarrenMassifBuilder's neighbour-step clamp can, at a footprint edge
		# with few already-assigned neighbours, squeeze a fresh district's
		# level down to zero or below (_new_district_level's `lvl = clampi(
		# lvl, lo, hi)`), leaving a column present in `massif.columns` with no
		# actual mass. Such a column can never host a borable slot --
		# the bore's own slot admission rejects any cell there since
		# cell.y + bands > top_at(column) for every bands >= 1 -- so it is
		# dropped here rather than copied in as a nonsensical zero-height
		# envelope column that WarrenVolumeEnvelope._seal() would reject
		# outright. Excavated geometry can never disagree with this: the
		# excavation could never have touched this column either way.
		if top - base < 1:
			continue
		min_x = mini(min_x, column.x)
		max_x = maxi(max_x, column.x)
		min_z = mini(min_z, column.y)
		max_z = maxi(max_z, column.y)
		envelope.ground_bands[column] = base
		# The massif's SECOND datum, carried across unchanged. Natural ground
		# stays `ground_bands` so every frontage, arcade and cover rule keeps
		# measuring the whole solid beside a street; the terrace is only where
		# a house stops descending. Copied rather than recomputed so the
		# partition and the construction stage read one authority.
		envelope.bearing_bands[column] = massif.bearing_at(column)
		envelope.height_bands[column] = top - base
		for y in range(base, top):
			envelope.mass_cells[Vector3i(column.x, y, column.y)] = true
	envelope.radius_x = maxi(3, (max_x - min_x) / 2)
	envelope.radius_z = maxi(3, (max_z - min_z) / 2)
	envelope.max_height_bands = massif.core_top_bands
	if not envelope.seal_synthesised():
		last_failure = "synthesised envelope rejected: %s" \
			% envelope.last_rejection
		return null
	return envelope


static func to_volume_plan(massif: WarrenMassif,
		excavation: WarrenExcavation,
		typed_market_cells: Array[Vector3i] = []) -> WarrenVolumePlan:
	last_failure = ""
	if massif == null or not massif.is_sealed():
		last_failure = "massif missing or unsealed"
		return null
	if excavation == null or not excavation.is_sealed():
		last_failure = "excavation missing or unsealed"
		return null
	var envelope := envelope_from_massif(massif)
	if envelope == null:
		return null
	var plan := WarrenVolumePlan.new(
		StringName("warren.volume.mass.%d" % excavation.world_seed),
		excavation.world_seed, envelope)
	if not plan.add_walk_cell(excavation.route[0]):
		last_failure = "duplicate walk cell %s" % excavation.route[0]
		return null
	if not _add_transitions(plan, excavation, excavation.route,
			excavation.transitions, "volume.transition", true):
		return null
	# Lanes enter as ordinary auxiliary public realm: walk nodes at their
	# transition endpoints, frontage everywhere, and no downstream special case.
	# NOT primary -- `primary_itinerary` is the bored route, and every gate that
	# reads it (overhang, addressed frontage, straight run, same-datum folds)
	# is a statement about that one itinerary. A lane is a street the town
	# addresses from, not part of the climb those gates measure.
	#
	# Anchors are already walk cells, from the route or from a lane declared
	# earlier, which is what makes the whole graph connected by construction --
	# WarrenExcavation.seal() has already refused any lane whose anchor was not.
	for index in excavation.lanes.size():
		var lane := excavation.lanes[index]
		var walk: Array[Vector3i] = [lane["anchor"] as Vector3i]
		walk.append_array(lane["cells"] as Array[Vector3i])
		if not _add_transitions(plan, excavation, walk,
				lane["transitions"] as Array[Dictionary],
				"volume.lane%02d" % index, false):
			return null
	# A loop edge is deliberately separate from the ordered route/lane walks:
	# both endpoints already exist, and this final seam is what turns the branch
	# tree into a cyclic street graph.  Copy it as an ordinary transition; do
	# not add or infer any new walk cell in this adapter.
	for index in excavation.loop_edges.size():
		var edge := excavation.loop_edges[index]
		var from_cell := edge["from"] as Vector3i
		var to_cell := edge["to"] as Vector3i
		if not plan.has_walk(from_cell) or not plan.has_walk(to_cell):
			last_failure = "loop edge %d has a non-walk endpoint" % index
			return null
		var span_walk: Array[Vector3i] = [from_cell, to_cell]
		var seam := WarrenVolumeTransition.new(
			StringName("volume.loop%02d" % index), from_cell, to_cell,
			int(edge["kind"]) as WarrenVolumeTransition.Kind,
			_swept_span(excavation, span_walk, 0, 1))
		if not plan.add_transition(seam):
			last_failure = "invalid loop edge %d (%s -> %s)" % [
				index, from_cell, to_cell]
			return null
	# Every excavated cell is real street ground a partitioner may
	# legitimately root a house at (it already does: street_wall_faces()
	# iterates excavation.public_cells() directly, unaware of which cells are
	# also walk_cells graph nodes), even though only move endpoints can BE graph
	# nodes. Registering the rest as frontage-only keeps
	# WarrenBuildingParcel.seal()/WarrenParcelPlan's detached-parcel audit
	# satisfied without giving any of them a colliding public-realm surface.
	for cell: Vector3i in excavation.public_cells():
		plan.add_frontage(cell)
	for cell: Vector3i in typed_market_cells:
		if not plan.mark_market_square_cell(cell):
			last_failure = "market square cell %s is not a walk node" % cell
			return null
	_close_landing_turns(plan)
	plan.mass_context = {&"massif": massif, &"excavation": excavation}
	if not plan.seal(excavation.portals[0]):
		last_failure = "plan seal rejected: %s" % plan.last_rejection
		return null
	return plan


static func excavation_for_volume(excavation: WarrenExcavation,
		volume: WarrenVolumePlan) -> WarrenExcavation:
	## The TOTAL negative space of a volume plan derived from `excavation`,
	## restated as a sealed WarrenExcavation.
	##
	## to_volume_plan() produces a plan whose mass is exactly the massif minus
	## `excavation.carved`, which is the solid predicate the retired partitioner
	## re-derives from (massif, excavation). Later stages -- the ground arcade
	## and the elevated galleries -- clone that plan and remove more mass, and
	## the bore alone then understates the void by exactly their branches. A
	## partition built from it puts houses inside an arcade and rests them on
	## columns the arcade undermined, and every such house is rejected by
	## WarrenBuildingParcel.seal() against the very plan it came from.
	##
	## So the void handed to the partitioner is read back off the plan itself:
	## its public air and daylight voids ARE its non-mass, so massif minus this
	## `carved` equals `volume.mass_cells` for a derived plan exactly as it did
	## for the raw one. The walk, transitions and portals are the bore's
	## unchanged -- only the subtraction grows -- so the seal still validates
	## the same route it always described, and street walls are still audited
	## against the bore rather than against the branches beside it.
	last_failure = ""
	if excavation == null or not excavation.is_sealed():
		last_failure = "excavation missing or unsealed"
		return null
	if volume == null or not volume.is_sealed():
		last_failure = "volume missing or unsealed"
		return null
	var out := WarrenExcavation.new(excavation.world_seed)
	out.route.assign(excavation.route)
	out.portals.assign(excavation.portals)
	out.transitions.assign(excavation.transitions)
	out.covered = excavation.covered.duplicate()
	out.lanes.assign(excavation.lanes)
	out.loop_edges.assign(excavation.loop_edges)
	out.carved = excavation.carved.duplicate()
	for cell: Vector3i in volume.public_air_cells:
		out.carved[cell] = true
	for cell: Vector3i in volume.daylight_void_cells:
		out.carved[cell] = true
	if not out.seal():
		last_failure = "derived excavation rejected: %s" % out.last_rejection
		return null
	return out


static func _close_landing_turns(plan: WarrenVolumePlan) -> bool:
	## Declares a square landing wherever WarrenVolumePlan._build_audit() would
	## otherwise count a landing_turn_violation: two transitions meeting at one
	## cell at right angles with either of them vertical.
	##
	## The route's own turns are already declared as they are laid, mirroring
	## the retired route carver's growth-time bookkeeping. This closes the case
	## that bookkeeping cannot see -- a lane branching off a route cell whose
	## incident transitions were fixed long before the lane existed. Stated as
	## the audit's own rule rather than as a second guess at it, and add_landing
	## is idempotent, so the route's declarations are unchanged.
	var incident: Dictionary = {}
	for cell: Vector3i in plan.walk_cells:
		incident[cell] = [] as Array[WarrenVolumeTransition]
	for value: WarrenVolumeTransition in plan.transitions:
		(incident[value.from_cell] as Array[WarrenVolumeTransition]).append(value)
		(incident[value.to_cell] as Array[WarrenVolumeTransition]).append(value)
	for cell: Vector3i in plan.walk_cells:
		var edges := incident[cell] as Array[WarrenVolumeTransition]
		for first_index in edges.size():
			for second_index in range(first_index + 1, edges.size()):
				var first := edges[first_index]
				var second := edges[second_index]
				if not first.is_vertical() and not second.is_vertical():
					continue
				if _dot(_step_direction(cell, first),
						_step_direction(cell, second)) != 0:
					continue
				plan.add_landing(cell)
	return true


static func _step_direction(cell: Vector3i,
		value: WarrenVolumeTransition) -> Vector2i:
	var other := value.other(cell)
	return Vector2i(signi(other.x - cell.x), signi(other.z - cell.z))


static func _add_transitions(plan: WarrenVolumePlan,
		excavation: WarrenExcavation, walk: Array[Vector3i],
		specs: Array[Dictionary], prefix: String, is_primary: bool) -> bool:
	## excavation.transitions records one macro edge per bored move (its
	## `from`/`to` span the whole 1-3 cell stride the carver's ACTIONS table
	## allows), exactly matching the WarrenVolumeTransition Kind contract --
	## see the bore carver's own docs.
	##
	## WALK CELLS ARE TRANSITION ENDPOINTS ONLY -- exactly
	## the retired route carver's own convention
	## (`route.append(destination)` once per move, never per stride cell).
	## An earlier revision instead made every carved cell (including a
	## STAIR/RAMP's intermediate stride cell) a walk cell, and wired the
	## orphaned intermediate into the graph with a LEVEL "spur" transition so
	## WarrenVolumePlan._all_walk_connected() would not strand it. That solved
	## CONNECTIVITY but not OWNERSHIP: WarrenVolumeTransition.surface_cells()
	## for a vertical transition always claims the intermediate macro column's
	## complete two-lane surface (its stair/ramp tread), and
	## WarrenVolumePublicRealmAdapter gives every walk cell an unconditional
	## 2x2 surface square of its own -- so a walk node at that exact column
	## collided with the transition node claiming the same ground. That
	## surface_cells() geometry is shared, protected code (pinned by
	## tests/test_warren_excavation.gd, which requires every cell it claims to
	## already be carved); it cannot change to make room for a second owner.
	## The only cell-for-cell-legitimate fix is therefore the one below: the
	## intermediate never becomes a walk cell in the first place, so there is
	## no orphan to strand and no second claimant to collide -- exactly
	## mirroring the model route-first has run for years without incident.
	var cursor := 0
	var previous_direction := Vector2i.ZERO
	var previous_vertical := false
	for index in specs.size():
		var spec := specs[index]
		var from_cell := spec["from"] as Vector3i
		var to_cell := spec["to"] as Vector3i
		var kind := int(spec["kind"]) as WarrenVolumeTransition.Kind
		var delta := to_cell - from_cell
		var run := absi(delta.x) + absi(delta.z)
		var direction := Vector2i(signi(delta.x), signi(delta.z))
		var vertical := delta.y != 0
		# Mirrors the retired route carver's landing bookkeeping:
		# the pivot between two moves owns a square landing whenever the
		# directions are perpendicular and either side of the turn is
		# vertical. WarrenVolumePlan._build_audit() gates on this exactly
		# (landing_turn_violation_count), and a route bored through a
		# terraced massif turns constantly, so skipping this reliably fails
		# real excavations, not just contrived ones.
		if previous_direction != Vector2i.ZERO \
				and _dot(previous_direction, direction) == 0 \
				and (previous_vertical or vertical):
			plan.add_landing(from_cell)
		if not plan.add_walk_cell(to_cell, is_primary):
			last_failure = "duplicate walk cell %s" % to_cell
			return false
		var spine := WarrenVolumeTransition.new(
			StringName("%s.%02d" % [prefix, index]),
			from_cell, to_cell, kind,
			_swept_span(excavation, walk, cursor, run))
		if not plan.add_transition(spine):
			last_failure = "invalid transition %d (%s -> %s): %s" \
				% [index, from_cell, to_cell, plan.last_rejection]
			return false
		cursor += run
		previous_direction = direction
		previous_vertical = vertical
	return true


static func _swept_span(excavation: WarrenExcavation, walk: Array[Vector3i],
		cursor: int, run: int) -> Array[Vector3i]:
	## The full physical volume this move's stride actually removed, read
	## back off `carved` per cell (via slot_bands()) rather than assumed to be
	## a fixed headroom -- a STAIR's intermediate cell carries both treads and
	## so is one band taller than its neighbours (see
	## the bore's surface-band span). Spanning cursor..cursor+run
	## inclusive means consecutive transitions' swept cells overlap exactly at
	## their shared endpoint, so the union across every transition in a route
	## equals excavation.carved exactly: the plan's mass never disagrees with
	## the void that was actually cut.
	var seen: Dictionary = {}
	var out: Array[Vector3i] = []
	for offset in range(run + 1):
		var cell := walk[cursor + offset]
		var height := excavation.slot_bands(cell)
		for band in range(cell.y, cell.y + height):
			var air_cell := Vector3i(cell.x, band, cell.z)
			if not seen.has(air_cell):
				seen[air_cell] = true
				out.append(air_cell)
	return out


static func _dot(a: Vector2i, b: Vector2i) -> int:
	return a.x * b.x + a.y * b.y
