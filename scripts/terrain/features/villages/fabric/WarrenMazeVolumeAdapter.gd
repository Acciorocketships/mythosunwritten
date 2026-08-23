class_name WarrenMazeVolumeAdapter
extends RefCounted

## Narrow migration seam from the sealed maze source into the existing volume
## contract. It performs no topology repair and creates no feature branches:
## the volume's solid is the plan's own `solid_at`, column by column, and the
## public realm is the excavation the bore already carved.
static var last_failure := ""


static func to_volume_plan(source: WarrenMazeSourcePlan) -> WarrenVolumePlan:
	last_failure = ""
	if source == null or not source.is_sealed():
		last_failure = "maze source plan missing or unsealed"
		return null
	var massif := _derived_massif(source)
	if massif == null:
		return null
	var volume := WarrenExcavationVolumeAdapter.to_volume_plan(
		massif, source.excavation, source.market_square_cells)
	if volume == null:
		last_failure = WarrenExcavationVolumeAdapter.last_failure
		return null
	var alignment := _bore_surface_alignment(source, volume)
	if int(alignment.bore_without_path_count) != 0 \
			or int(alignment.path_outside_bore_count) != 0 \
			or int(alignment.minimum_lane_count) < 2:
		last_failure = "adapted path does not match bored passages: %s" \
			% alignment
		return null
	# Provenance only; WarrenVolumePlan explicitly permits metadata attachment
	# after seal. Geometry and its deterministic signature remain exactly what
	# the existing excavation adapter proved.
	volume.mass_context[&"maze_source_plan"] = source
	volume.mass_context[&"scale_profile_id"] = source.scale_profile.scale_id
	volume.mass_context[&"scale_profile_signature"] = \
		source.scale_profile.deterministic_signature()
	volume.audit.merge(alignment, true)
	return volume


static func _derived_massif(source: WarrenMazeSourcePlan) -> WarrenMassif:
	## The massif is the buildable ENVELOPE; the sealed plan's plots are the
	## town that was actually built inside it, and `solid_at` is the only
	## authority on which of the two a band belongs to (rock under a plot,
	## a plot, a rock shoulder, or air). This copy restates that authority as
	## the one thing the existing excavation adapter reads: a per-column top.
	##
	## `base` never moves -- terrain below `massif.base_at` is untouched
	## ground, the rock a street itself stands on, and the carved cells above
	## it are subtracted from the volume by WarrenExcavationVolumeAdapter
	## straight out of `excavation.carved` regardless of what this copy says.
	## The sealed stack invariant (solid is one contiguous run from terrain,
	## minus carved cells) is what makes a single top per column EXACT rather
	## than approximate; test_volume_matches_solid_at proves it cell by cell.
	##
	## Only the column SET matters to WarrenMassif.seal() (single connected
	## component, no interior hole) and this copy keeps every column the
	## sealed massif had, so a legally derived copy of an already-sealed
	## massif cannot newly fail seal() here.
	var columns: Dictionary = {}
	var ceilings := _plot_ceilings(source)
	for column: Vector2i in source.massif.columns:
		var entry := (source.massif.columns[column] as Dictionary).duplicate()
		var base := source.massif.base_at(column)
		# Three things can put derived solid on a column, and the scan has to
		# reach the highest of them: the envelope itself, a plot standing on
		# it, and -- on a column carrying no plot -- the ROCK SHOULDER, which
		# is the lowest floor of the plots bordering this column's own no-plot
		# region and can perfectly well stand above this column's envelope
		# where a taller neighbour was built out.
		var ceiling := maxi(source.massif.top_at(column),
			int(ceilings.get(column, base)))
		entry["top"] = _derived_top(source, column, base,
			maxi(ceiling, source.rock_shoulder(column)))
		columns[column] = entry
	var derived := WarrenMassif.with_columns(source.massif.world_seed, columns,
		source.massif.core_top_bands)
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
	for band in range(ceiling - 1, base - 1, -1):
		var cell := Vector3i(column.x, band, column.y)
		if source.solid_at(cell) or source.excavation.carved.has(cell):
			return band + 1
	return base


static func _plot_ceilings(source: WarrenMazeSourcePlan) -> Dictionary:
	## Vector2i column -> the highest plot top standing on it. A plot is NOT
	## clamped to the massif (WarrenMazeSourcePlan.add_plot says so), so a
	## house that rose to meet an upper street can stand above the envelope it
	## grew out of; the derivation scan has to reach it.
	var out: Dictionary = {}
	for plot: Dictionary in source.plots:
		var top := int(plot["top"])
		for cell_value: Variant in plot["cells"] as Array:
			var column := cell_value as Vector2i
			out[column] = maxi(int(out.get(column, top)), top)
	return out


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
	for cell: Vector3i in source.excavation.public_cells():
		bore_cells[cell] = true
		bore_columns[Vector2i(cell.x, cell.z)] = true
		lane_counts[cell] = 0
	var outside := 0
	var multi_band_treads := 0
	for surface: Vector3i in volume.exact_route_surface_cells():
		var macro := Vector3i(floori(float(surface.x) / 2.0), surface.y,
			floori(float(surface.z) / 2.0))
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
