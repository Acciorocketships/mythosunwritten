class_name WarrenMazeVolumeAdapter
extends RefCounted

## Narrow migration seam from the sealed maze source into the existing volume
## contract. It performs no topology repair and creates no feature branches:
## the volume's solid is the plan's own `solid_at`, column by column, and the
## public realm is the excavation the bore already carved.
static var last_failure := ""


static func to_volume_plan(source: WarrenMazeSourcePlan,
		collect_diagnostics: bool = true) -> WarrenVolumePlan:
	last_failure = ""
	if source == null or not source.is_sealed():
		last_failure = "maze source plan missing or unsealed"
		return null
	var access := _deck_access_transitions(source)
	var access_air: Dictionary = {}
	for flight: WarrenVolumeTransition in access:
		for cell: Vector3i in flight.swept_air_cells:
			access_air[cell] = true
	var massif := _derived_massif(source, access_air)
	if massif == null:
		return null
	var derived_voids: Array[Vector3i] = []
	for column: Vector2i in massif.columns:
		for band in range(massif.base_at(column), massif.top_at(column)):
			var cell := Vector3i(column.x, band, column.y)
			if not source.solid_at(cell):
				derived_voids.append(cell)
	var volume := WarrenExcavationVolumeAdapter.to_volume_plan(
		massif, source.excavation, source.market_square_cells, false, access, derived_voids)
	if volume == null:
		last_failure = WarrenExcavationVolumeAdapter.last_failure
		return null
	if collect_diagnostics:
		volume.collect_construction_diagnostics()
		var alignment := _bore_surface_alignment(source, volume)
		volume.audit.merge(alignment, true)
	# Provenance only; WarrenVolumePlan explicitly permits metadata attachment
	# after seal. Geometry and its deterministic signature remain exactly what
	# the existing excavation adapter proved.
	volume.mass_context[&"maze_source_plan"] = source
	volume.mass_context[&"scale_profile_id"] = source.scale_profile.scale_id
	volume.mass_context[&"scale_profile_signature"] = \
		source.scale_profile.deterministic_signature()
	return volume


static func _deck_access_transitions(source: WarrenMazeSourcePlan) -> Array[WarrenVolumeTransition]:
	var out: Array[WarrenVolumeTransition] = []
	for plot: Dictionary in source.plots:
		if not plot.has("access_transition"): continue
		var spec: Dictionary = plot.access_transition
		var a: Vector3i = spec.from
		var b: Vector3i = spec.to
		var step := Vector3i(signi(b.x-a.x),0,signi(b.z-a.z))
		var air: Array[Vector3i] = []
		for offset in range(3):
			var column := a+step*offset
			var low := b.y if offset==2 else a.y
			var high := a.y if offset==0 else b.y
			for band in range(low,high+WarrenVolumePlan.HEADROOM_BANDS):
				air.append(Vector3i(column.x,band,column.z))
		out.append(WarrenVolumeTransition.new(StringName("volume.deck.%s" % plot.id),
			a,b,int(spec.kind) as WarrenVolumeTransition.Kind,air))
	return out


static func _derived_massif(source: WarrenMazeSourcePlan,
		access_air: Dictionary = {}) -> WarrenMassif:
	## The massif is the buildable ENVELOPE; the sealed plan's plots are the
	## town that was actually built inside it, and `solid_at` is the only
	## authority on which of the two a band belongs to (rock under a plot,
	## a plot, a rock shoulder, or air). This copy restates that authority as
	## a per-column envelope top. Empty bands inside that envelope are carried
	## separately as derived voids; only the source decides which bands are solid.
	##
	## `base` never moves -- terrain below `massif.base_at` is untouched
	## ground, the rock a street itself stands on, and the carved cells above
	## it are subtracted from the volume by WarrenExcavationVolumeAdapter
	## straight out of `excavation.carved` regardless of what this copy says.
	## Stair extensions and released bores may leave gaps below that top.
	## `derived_voids` preserves those gaps before volume sealing;
	## test_volume_matches_solid_at proves the result cell by cell.
	##
	## Only the column SET matters to WarrenMassif.seal() (single connected
	## component, no interior hole) and this copy keeps every column the
	## sealed massif had, so a legally derived copy of an already-sealed
	## massif cannot newly fail seal() here.
	var columns: Dictionary = {}
	for column: Vector2i in source.massif.columns:
		var entry := (source.massif.columns[column] as Dictionary).duplicate()
		# The scan has to start above everything that can put derived solid on
		# this column -- its own envelope, a plot standing on it, the rock
		# shoulder a taller neighbour left it -- which is exactly the plan's
		# own `column_ceiling`.
		entry["top"] = _derived_top(source, column,
			source.massif.base_at(column), source.column_ceiling(column))
		columns[column] = entry
	# The court's planned flight rises above its flat plot datum. These cells
	# extend only the envelope and are all explicitly subtracted as public air.
	for cell: Vector3i in access_air:
		var column := Vector2i(cell.x,cell.z)
		if columns.has(column):
			columns[column]["top"] = maxi(int(columns[column]["top"]),cell.y+1)
	var derived := WarrenMassif.with_columns(source.massif.world_seed, columns,
		source.massif.core_top_bands)
	derived.form_id = source.massif.form_id
	derived.open_court = source.massif.open_court.duplicate()
	# Mirrors WarrenMassifBuilder.build's own derivation: core_top_bands is the
	# deepest authored layer over any column, and deriving a column's top from
	# the town standing on it can change which column is deepest.
	var core_top_bands := 0
	for column: Vector2i in derived.columns:
		core_top_bands = maxi(core_top_bands, derived.layer_at(column))
	derived.core_top_bands = core_top_bands
	if not derived.seal():
		last_failure = "derived massif copy failed to seal: %s" \
			% derived.last_rejection
		return null
	return derived


static func _derived_top(source: WarrenMazeSourcePlan, column: Vector2i,
		base: int, ceiling: int) -> int:
	## One band above the highest band this column still owns: solid mass, or
	## the void a passage was bored through.
	##
	## The CARVED half of that is not mass and never becomes mass -- the
	## excavation adapter subtracts every carved cell from the envelope's own
	## solid -- but the envelope has to reach over a street all the same:
	## WarrenVolumePlan.seal() refuses a walk cell whose swept headroom leaves
	## the envelope (`WarrenVolumeEnvelope.contains_air_column`), which is
	## exactly the street this adapter is carrying across. Stopping at the
	## highest SOLID band would delete every open street from the volume's own
	## envelope and reject the plan the maze already sealed.
	##
	## A withdrawn terminal climb leaves its released headroom carved (no rock
	## may refill it), but once its column's leftover rock steps down to the
	## town floor that air can float over nothing. It carries no street, so it
	## must not raise the envelope: counting it would turn the empty bands
	## beneath into phantom mass the plan never owned.
	var band := ceiling - 1
	while band >= base:
		var cell := Vector3i(column.x, band, column.y)
		if source.solid_at(cell):
			return band + 1
		if source.excavation.carved.has(cell):
			var bottom := band
			while bottom - 1 >= base and not source.solid_at(Vector3i(column.x, bottom - 1, column.y)) \
					and source.excavation.carved.has(Vector3i(column.x, bottom - 1, column.y)):
				bottom -= 1
			var live := bottom == base or source.solid_at(Vector3i(column.x, bottom - 1, column.y))
			for run_band in range(bottom, band + 1):
				live = live or source.passage_kinds.has(Vector3i(column.x, run_band, column.y))
			if live:
				return band + 1
			band = bottom
		band -= 1
	return base


static func _bore_surface_alignment(source: WarrenMazeSourcePlan,
		volume: WarrenVolumePlan) -> Dictionary:
	## A sealed graph is insufficient if its eventual paving occupies different
	## columns from the void the maze bored. Prove both directions here, at the
	## only boundary that can still see both authorities. Each 3 m passage cell
	## must carry at least one complete two-lane (2 x 1.5 m) floor, while every
	## fine floor cell must remain inside a bored passage column.
	var bore_cells: Dictionary = {}
	var bore_columns: Dictionary = {}
	var lane_counts: Dictionary = {}
	var access_air: Dictionary = {}
	for flight: WarrenVolumeTransition in _deck_access_transitions(source):
		for cell: Vector3i in flight.swept_air_cells:
			access_air[cell] = true
	for cell: Vector3i in source.excavation.public_cells():
		bore_cells[cell] = true
		bore_columns[Vector2i(cell.x, cell.z)] = true
		lane_counts[cell] = 0
	var outside := 0
	var multi_band_treads := 0
	for surface: Vector3i in volume.exact_route_surface_cells():
		var macro := Vector3i(floori(float(surface.x) / 2.0), surface.y,
			floori(float(surface.z) / 2.0))
		if access_air.has(macro) and not bore_cells.has(macro):
			continue
		if not bore_columns.has(Vector2i(macro.x, macro.z)) \
				or not source.excavation.carved.has(macro):
			outside += 1
			continue
		if bore_cells.has(macro):
			lane_counts[macro] = int(lane_counts[macro]) + 1
		else:
			# A stair's intermediate macro column contains treads at both bands;
			# only one is the nominal centerline cell, but both are inside the
			# exact carved slot and both must survive into render/collision.
			multi_band_treads += 1
	var missing := 0
	var minimum_lanes := 2147483647
	for cell_value: Variant in bore_cells.keys():
		var count := int(lane_counts[cell_value])
		missing += int(count == 0)
		minimum_lanes = mini(minimum_lanes, count)
	return {
		"maze_bore_cell_count": bore_cells.size(),
		"maze_path_surface_cell_count": volume.exact_route_surface_cells().size(),
		"bore_without_path_count": missing,
		"path_outside_bore_count": outside,
		"multi_band_tread_surface_count": multi_band_treads,
		"minimum_lane_count": 0 if bore_cells.is_empty() else minimum_lanes,
	}
