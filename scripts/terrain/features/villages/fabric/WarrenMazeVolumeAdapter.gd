class_name WarrenMazeVolumeAdapter
extends RefCounted

## Narrow migration seam from the sealed maze source into the existing volume
## contract. It performs no topology repair and creates no feature branches;
## stamps will be translated here only after they become sealed source facts.
static var last_failure := ""


static func to_volume_plan(source: WarrenMazeSourcePlan) -> WarrenVolumePlan:
	last_failure = ""
	if source == null or not source.is_sealed():
		last_failure = "maze source plan missing or unsealed"
		return null
	var massif := source.massif
	if not source.column_edits.is_empty():
		massif = _edited_massif(source)
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


static func _edited_massif(source: WarrenMazeSourcePlan) -> WarrenMassif:
	## The constructive ledger (parcel-claim offenders, reservation footprints)
	## overlays a handful of columns with a raised floor and/or a trimmed roof
	## on top of the sealed Task-1 massif. Downstream excavation must see that
	## edited world -- otherwise the volume's mass disagrees with the very
	## addresses the source plan already sealed against. Only edited columns
	## move; every other column is copied through byte-for-byte, so the
	## edited copy's column SET (and therefore its footprint topology) is
	## identical to the sealed massif's own. WarrenMassif.seal() only checks
	## that topology (single connected component, no interior hole) -- it
	## never inspects band values -- so a legally-edited copy of an
	## already-sealed massif cannot newly fail seal() here.
	##
	## Bridge-capable columns (2026-08-22, controller ruling on slice 1c
	## task 1): a passage-hosting column's edited floor means "the
	## bridge/bearing house floor above the street's own headroom", never
	## "bottom of mass" -- overwriting `base` up to that floor the way every
	## other edited column's is would delete the passage's own walk cell
	## from the envelope entirely (`WarrenVolumeEnvelope.contains_air_column`
	## requires `ground_at(column) <= walk cell y`), which is exactly what
	## used to make `WarrenExcavationVolumeAdapter` reject the street as
	## "leaving the envelope". Such a column instead keeps `base` at the
	## ORIGINAL massif base -- true terrain, the rock the street itself still
	## stands on -- and only raises `top` to the ledger's own effective_top;
	## the actual carved passage cells (and their headroom) are excluded
	## from the final `mass_cells` regardless, since
	## `WarrenExcavationVolumeAdapter` subtracts every swept transition cell
	## sourced directly from `excavation.carved`, independent of what this
	## massif copy's own base/top report. A column with no hosted passage
	## keeps the pre-existing behaviour (both base and top move to the
	## ledger's own values; the discarded gap becomes construction's own
	## foundation courses, per this design's P5 section).
	var columns: Dictionary = {}
	for column: Vector2i in source.massif.columns:
		var entry := (source.massif.columns[column] as Dictionary).duplicate()
		if source.column_edits.has(column):
			if source._passage_headroom_floor(column) >= 0:
				entry["top"] = source.effective_top(column)
			else:
				entry["base"] = source.effective_base(column)
				entry["top"] = source.effective_top(column)
		columns[column] = entry
	var edited := WarrenMassif.with_columns(source.massif.world_seed, columns,
		source.massif.core_top_bands)
	# Mirrors WarrenMassifBuilder.build's own derivation: core_top_bands is the
	# deepest authored layer over any column, and an edit can change a
	# column's layer (raised floor, trimmed roof) without changing which
	# column is deepest.
	var core_top_bands := 0
	for column: Vector2i in edited.columns:
		core_top_bands = maxi(core_top_bands, edited.layer_at(column))
	edited.core_top_bands = core_top_bands
	if not edited.seal():
		last_failure = "edited massif copy failed to seal: %s" \
			% edited.last_rejection
		return null
	return edited


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
