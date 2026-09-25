extends TerrainGradePatch
# Reproduce the original frozen source's product collar without swapping live code.
# The complete original source is retained beside this adapter as baseline_grade_patch.txt.
func _init(id: StringName, heights: Dictionary, origin: Vector2, pitch: float) -> void:
	super(id,heights,origin,pitch)
	bounds=bounds.grow(TRANSITION_WIDTH-_collar_reach)
	_collar_reach=TRANSITION_WIDTH
	_collar_cells=ceili(TRANSITION_WIDTH/pitch)+1
	_targets.search_radius=_collar_cells

func _distances(local: Vector2) -> Array[float]:
	var result: Array[float]=[]
	for area: Rect2 in _collar_rectangles:
		result.append(local.distance_to(local.clamp(area.position,area.end)))
	return result

func _collar_weight(local: Vector2, cell: Vector2i) -> float:
	if _claims.has(cell): return 1.0
	var remaining:=1.0
	for distance: float in _distances(local): remaining*=TerrainSurfaceField.transition_weight(distance)
	return 1.0-remaining

func _weight_bounds(area: Rect2) -> Vector2:
	var half := _targets.pitch * 0.5
	var lo := Vector2i(floori(area.position.x / _targets.pitch + 0.5),
		floori(area.position.y / _targets.pitch + 0.5))
	var hi := Vector2i(ceili(area.end.x / _targets.pitch + 0.5) - 1,
		ceili(area.end.y / _targets.pitch + 0.5) - 1)
	var interval := Vector2(1, 0)
	for z in range(lo.y, maxi(lo.y, hi.y) + 1):
		for x in range(lo.x, maxi(lo.x, hi.x) + 1):
			var cell := Vector2i(x,z)
			if _claims.has(cell):
				interval.y = 1.0
				continue
			var part := area.intersection(Rect2(Vector2(cell) * _targets.pitch - Vector2.ONE * half,
				Vector2.ONE * _targets.pitch))
			# Each convex-boundary distance is 1-Lipschitz. The smooth union is
			# monotone in every input, so composing their intervals is conservative.
			var radius := part.size.length() * 0.5
			var remaining_lo := 1.0
			var remaining_hi := 1.0
			for distance: float in _distances(part.get_center()):
				remaining_lo *= TerrainSurfaceField.transition_weight(maxf(0,distance-radius))
				remaining_hi *= TerrainSurfaceField.transition_weight(distance+radius)
			interval.x=minf(interval.x,1.0-remaining_hi)
			interval.y=maxf(interval.y,1.0-remaining_lo)
	return interval


