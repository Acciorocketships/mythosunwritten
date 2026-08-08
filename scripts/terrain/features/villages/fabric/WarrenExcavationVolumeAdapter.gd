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
		# WarrenExcavationCarver._slot_is_borable rejects any cell there since
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
		excavation: WarrenExcavation) -> WarrenVolumePlan:
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
	if not _add_transitions(plan, excavation):
		return null
	# Every excavated cell is real street ground WarrenSolidPartitioner may
	# legitimately root a house at (it already does: street_wall_faces()
	# iterates excavation.route directly, unaware of which cells are also
	# walk_cells graph nodes), even though only move endpoints can BE graph
	# nodes. Registering the rest as frontage-only keeps
	# WarrenBuildingParcel.seal()/WarrenParcelPlan's detached-parcel audit
	# satisfied without giving any of them a colliding public-realm surface.
	for cell: Vector3i in excavation.route:
		plan.add_frontage(cell)
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
	## `excavation.carved`, which is the solid predicate WarrenSolidPartitioner
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
	out.carved = excavation.carved.duplicate()
	for cell: Vector3i in volume.public_air_cells:
		out.carved[cell] = true
	for cell: Vector3i in volume.daylight_void_cells:
		out.carved[cell] = true
	if not out.seal():
		last_failure = "derived excavation rejected: %s" % out.last_rejection
		return null
	return out


static func _add_transitions(plan: WarrenVolumePlan,
		excavation: WarrenExcavation) -> bool:
	## excavation.transitions records one macro edge per bored move (its
	## `from`/`to` span the whole 1-3 cell stride the carver's ACTIONS table
	## allows), exactly matching the WarrenVolumeTransition Kind contract --
	## see WarrenExcavationCarver's own docs.
	##
	## WALK CELLS ARE TRANSITION ENDPOINTS ONLY -- exactly
	## WarrenPublicRealmCarver's own route-first convention
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
	for index in excavation.transitions.size():
		var spec := excavation.transitions[index]
		var from_cell := spec["from"] as Vector3i
		var to_cell := spec["to"] as Vector3i
		var kind := int(spec["kind"]) as WarrenVolumeTransition.Kind
		var delta := to_cell - from_cell
		var run := absi(delta.x) + absi(delta.z)
		var direction := Vector2i(signi(delta.x), signi(delta.z))
		var vertical := delta.y != 0
		# Mirrors WarrenPublicRealmCarver._grow_candidate's landing bookkeeping:
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
		if not plan.add_walk_cell(to_cell):
			last_failure = "duplicate walk cell %s" % to_cell
			return false
		var spine := WarrenVolumeTransition.new(
			StringName("volume.transition.%02d" % index),
			from_cell, to_cell, kind, _swept_span(excavation, cursor, run))
		if not plan.add_transition(spine):
			last_failure = "invalid transition %d (%s -> %s): %s" \
				% [index, from_cell, to_cell, plan.last_rejection]
			return false
		cursor += run
		previous_direction = direction
		previous_vertical = vertical
	return true


static func _swept_span(excavation: WarrenExcavation, cursor: int,
		run: int) -> Array[Vector3i]:
	## The full physical volume this move's stride actually removed, read
	## back off `carved` per cell (via slot_bands()) rather than assumed to be
	## a fixed headroom -- a STAIR's intermediate cell carries both treads and
	## so is one band taller than its neighbours (see
	## WarrenExcavationCarver._surface_band_span). Spanning cursor..cursor+run
	## inclusive means consecutive transitions' swept cells overlap exactly at
	## their shared endpoint, so the union across every transition in a route
	## equals excavation.carved exactly: the plan's mass never disagrees with
	## the void that was actually cut.
	var seen: Dictionary = {}
	var out: Array[Vector3i] = []
	for offset in range(run + 1):
		var cell := excavation.route[cursor + offset]
		var height := excavation.slot_bands(cell)
		for band in range(cell.y, cell.y + height):
			var air_cell := Vector3i(cell.x, band, cell.z)
			if not seen.has(air_cell):
				seen[air_cell] = true
				out.append(air_cell)
	return out


static func _dot(a: Vector2i, b: Vector2i) -> int:
	return a.x * b.x + a.y * b.y
