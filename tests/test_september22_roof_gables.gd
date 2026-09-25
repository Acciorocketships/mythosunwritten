extends GutTest
## September 22 manual review, photo 1 (upper left): a compact roof's exterior
## gable sat 0.27 m behind the facade, exposing the wall's top plate as a ledge.
## Every exterior compact gable foot must reach its end wall's outer face.
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
const SOURCE := "res://tests/fixtures/september22/town-e-source.txt"
const TOLERANCE := 0.02  # local units (one hundredth of a 3 m bay is 0.03)


func _gable_offsets() -> Array[Dictionary]:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var fabric := FROZEN.spatial(FROZEN.read(SOURCE), program).compiled_fabric_cache()
	var runs := fabric.continuous_roof_plan.compiled_runs
	var feet: Dictionary = {}
	var out: Array[Dictionary] = []
	for placement: Dictionary in fabric.expanded_placements():
		var asset := String(placement.asset_id)
		if not asset.begins_with("lpfv.fabric.roof.compact") or ".valley." in asset: continue
		var id := String(placement.stable_id)
		var run: Dictionary = {}
		for candidate: Dictionary in runs:
			if id.begins_with(String(candidate.unit_id) + "/"): run = candidate
		if run.is_empty(): continue
		if not feet.has(asset):
			var visual: EnvironmentVisual = load(catalog.descriptor(StringName(asset)).visual_path)
			var points := PackedVector3Array()
			for piece: EnvironmentVisualPiece in visual.pieces:
				points.append_array(EnvironmentBakeGeometry.triangle_faces(piece.mesh, piece.local_transform))
			feet[asset] = points
		var pose: Transform3D = placement.transform
		var axis_x := bool(run.axis_x)
		var low := INF
		var high := -INF
		for point: Vector3 in feet[asset]:
			var world: Vector3 = pose * point
			if world.y > float(run.base_y) + 0.35: continue
			var along: float = world.x if axis_x else world.z
			low = minf(low, along)
			high = maxf(high, along)
		var start: float = (run.start as Vector3).x if axis_x else (run.start as Vector3).z
		var end: float = (run.end as Vector3).x if axis_x else (run.end as Vector3).z
		# A foot within half a section of a run end is that end's exterior gable.
		if absf(low - start) < 0.6: out.append({"id": id, "asset": asset, "offset": start - low})
		if absf(high - end) < 0.6: out.append({"id": id, "asset": asset, "offset": high - end})
	return out


func test_exterior_compact_gables_reach_their_facade() -> void:
	var offsets := _gable_offsets()
	assert_gt(offsets.size(), 10, "the town has exterior compact gables")
	for gable: Dictionary in offsets:
		assert_gt(float(gable.offset), -TOLERANCE,
			"%s (%s) gable foot sits %.3f behind its facade" % [gable.id, gable.asset, -float(gable.offset)])
