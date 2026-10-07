class_name WarrenMarketSolver
extends RefCounted

## The covered market's measured footprint and its terrain-bearing proof. The
## one-pass feature selection (`WarrenVolumetricSolver._maze_feature_pass`)
## places the market; the retired candidate search that used to live here was
## deleted October 7 with the searched pipeline it fed.
const MARKET_MINIMUM := Vector3i(-2, 0, -1)
const MARKET_SIZE := Vector3i(4, 3, 2)
const COVERED_MARKET_MINIMUM := MARKET_MINIMUM
const COVERED_MARKET_SIZE := MARKET_SIZE


static func _bearing_follows_local_ground(origin: Vector3i, yaw: int,
		volume: WarrenVolumePlan, minimum: Vector3i,
		size: Vector3i) -> bool:
	for local_cell: Vector3i in FabricRecipe.box_cells(
			minimum, Vector3i(size.x, 1, size.z)):
		var cell := FabricRecipe.transform_cell(local_cell, origin, yaw)
		var column := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		if not volume.envelope.contains_column(column) \
				or volume.envelope.ground_at(column) != origin.y:
			return false
	return true
