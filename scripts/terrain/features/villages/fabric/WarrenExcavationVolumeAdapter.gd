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
	for cell: Vector3i in excavation.route:
		if not plan.add_walk_cell(cell):
			last_failure = "duplicate walk cell %s" % cell
			return null
	if not _add_transitions(plan, excavation):
		return null
	if not plan.seal(excavation.portals[0]):
		last_failure = "plan seal rejected: %s" % plan.last_rejection
		return null
	return plan


static func _add_transitions(plan: WarrenVolumePlan,
		excavation: WarrenExcavation) -> bool:
	## excavation.transitions records one macro edge per bored move (its
	## `from`/`to` span the whole 1-3 cell stride the carver's ACTIONS table
	## allows), exactly matching the WarrenVolumeTransition Kind contract --
	## see WarrenExcavationCarver's own docs. What it does NOT do is touch a
	## STAIR/RAMP's intermediate stride cell as a graph endpoint, even though
	## that cell is real, carved, and (per the brief's contract test) belongs
	## in the plan's primary_itinerary one-for-one with excavation.route. Left
	## unconnected, WarrenVolumePlan._all_walk_connected() would strand it, so
	## every intermediate is wired in below with a LEVEL spur to whichever
	## neighbour shares its floor band -- the only edge shape a same-band
	## single-cell hop can ever legally be.
	var route := excavation.route
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
		var spine := WarrenVolumeTransition.new(
			StringName("volume.transition.%02d" % index),
			from_cell, to_cell, kind, _swept_span(excavation, cursor, run))
		if not plan.add_transition(spine):
			last_failure = "invalid transition %d (%s -> %s): %s" \
				% [index, from_cell, to_cell, plan.last_rejection]
			return false
		if run > 1 and not _add_spurs(plan, route, cursor, run, index):
			return false
		cursor += run
		previous_direction = direction
		previous_vertical = vertical
	return true


static func _add_spurs(plan: WarrenVolumePlan, route: Array[Vector3i],
		cursor: int, run: int, index: int) -> bool:
	## Connects every intermediate cell of a multi-cell stride into the walk
	## graph. Exactly one consecutive pair inside a STAIR's stride, and
	## exactly two inside a RAMP's, share a floor band (WarrenExcavationCarver
	## always spends the whole rise on a single middle step; the approach and
	## departure stay level) -- detected here from the actual carved
	## coordinates rather than assumed from the kind, so this holds regardless
	## of which direction the move rises or falls.
	for offset in range(run):
		var a := route[cursor + offset]
		var b := route[cursor + offset + 1]
		if a.y != b.y:
			continue
		var spur := WarrenVolumeTransition.new(
			StringName("volume.transition.%02d.spur%d" % [index, offset]),
			a, b, WarrenVolumeTransition.Kind.LEVEL, [])
		if not plan.add_transition(spur):
			last_failure = "invalid spur at transition %d offset %d: %s" \
				% [index, offset, plan.last_rejection]
			return false
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
