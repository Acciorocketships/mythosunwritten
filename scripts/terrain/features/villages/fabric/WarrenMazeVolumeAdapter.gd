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
	var volume := WarrenExcavationVolumeAdapter.to_volume_plan(
		source.massif, source.excavation, source.market_square_cells)
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
