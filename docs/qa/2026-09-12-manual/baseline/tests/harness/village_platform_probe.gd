extends SceneTree

## Headless geometry audit for the same-band platform stage on a synthetic
## terrace. Kept as a focused regression aid for future platform grammars.
func _init() -> void:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-12, 13):
		for x in range(-12, 13):
			var cell := Vector2i(x, z)
			storeys[cell] = 0 if x <= -1 else (1 if x == 0 else 2)
			levels[cell] = 0
	var terrain := VillageTerrainView.from_region(
		HeightfieldRegion.new(storeys, levels))
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var massing := VillageMassingSolver.solve(terrain, Vector2.ZERO,
		Vector2.RIGHT, program, &"village")
	var result := VillagePlatformSolver.solve(Vector2.ZERO, Vector2.RIGHT,
		massing.placements)
	var circulation := VillageCirculationSolver.solve(terrain, Vector2.ZERO,
		Vector2.RIGHT, massing, program.elevated_program)
	var door_nodes: Array[VillageCirculationNode] = []
	for placement: VillageMassingPlacement in massing.placements:
		door_nodes.append(VillageCirculationNode.new(
			StringName("%s.door" % placement.stable_key),
			VillageCirculationNode.Kind.DOOR, placement.entrance,
			placement.floor_y, placement.stable_key,
			placement.entrance_outward))
	var aerial_diagnostics: Array[Dictionary] = []
	for candidate: Dictionary in VillageAerialRouter.candidates(door_nodes,
			massing.placements, program.elevated_program):
		var link := candidate.link as VillageCirculationLink
		aerial_diagnostics.append({"from": String(link.from_key),
			"to": String(link.to_key), "length": link.length,
			"horizontal": VillageRouteGeometry.polyline_horizontal_length(
				link.samples), "stairs": link.stair_count})
	var pair_diagnostics: Array[Dictionary] = []
	for index in massing.placements.size():
		var a := massing.placements[index]
		if a.ground_accessible:
			continue
		for prior in index:
			var b := massing.placements[prior]
			if b.ground_accessible or not is_equal_approx(a.floor_y, b.floor_y):
				continue
			var paths := VillagePlatformSolver._cell_paths(Vector2.ZERO,
				Vector2.RIGHT, a, b)
			var searched := VillagePlatformSolver._searched_cell_path(
				Vector2.ZERO, Vector2.RIGHT, a, b, massing.placements, [])
			var path_diagnostics: Array[Dictionary] = []
			for cells: Array[Vector2] in paths:
				var samples := VillagePlatformSolver._samples(a, b, cells)
				var segment_hits: Array[Dictionary] = []
				for sample_index in range(1, samples.size()):
					var segment: Array[Vector3] = [samples[sample_index - 1],
						samples[sample_index]]
					var hit := VillageRouteGeometry.first_solid_hit(segment,
						massing.placements, a.stable_key, b.stable_key,
						VillagePlatformSolver.PLATFORM_HALF_WIDTH)
					if not hit.is_empty():
						segment_hits.append({"index": sample_index,
							"hit": String(hit), "a": segment[0],
							"b": segment[1]})
				path_diagnostics.append({
					"cell_count": cells.size(),
					"first_hit": String(VillageRouteGeometry.first_solid_hit(
						samples, massing.placements, a.stable_key,
						b.stable_key, VillagePlatformSolver.PLATFORM_HALF_WIDTH)),
					"segment_hits": segment_hits,
				})
			pair_diagnostics.append({
				"a": String(a.stable_key),
				"b": String(b.stable_key),
				"distance": a.entrance.distance_to(b.entrance),
				"a_departure": VillagePlatformSolver._departure(a),
				"a_outward": a.entrance_outward,
				"a_access_end": a.street_contact,
				"b_departure": VillagePlatformSolver._departure(b),
				"b_outward": b.entrance_outward,
				"b_access_end": b.street_contact,
				"paths": path_diagnostics,
				"searched_cells": searched.size(),
			})
	var placements: Array[Dictionary] = []
	for placement: VillageMassingPlacement in massing.placements:
		placements.append({
			"key": String(placement.stable_key),
			"band": placement.perch.architectural_band,
			"floor_y": placement.floor_y,
			"ground_accessible": placement.ground_accessible,
			"entrance": [placement.entrance.x, placement.entrance.y],
		})
	print(JSON.stringify({
		"accepted": massing.accepted,
		"placements": placements,
		"candidate_count": result.candidate_count,
		"circulation": {
			"accepted": circulation.accepted,
			"reason": String(circulation.reason),
			"platform_candidates": circulation.platform_candidate_count,
			"platform_regions": circulation.platform_region_count,
			"aerial_candidates": circulation.aerial_candidate_count,
			"components": circulation.disconnected_components,
		},
		"regions": (result.regions as Array).size(),
		"links": (result.links as Array).size(),
		"aerial_diagnostics": aerial_diagnostics,
		"pair_diagnostics": pair_diagnostics,
	}, "  "))
	quit()
