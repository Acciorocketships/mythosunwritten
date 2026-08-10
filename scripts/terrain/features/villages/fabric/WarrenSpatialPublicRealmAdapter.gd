class_name WarrenSpatialPublicRealmAdapter
extends RefCounted

## Migration adapter for the existing assembler.  The old macro route may
## supply graph episode identities, but this adapter accepts it only when its
## fine surfaces and exterior air are byte-for-cell identical to the sealed
## WarrenSpatialPlan. It is therefore a projection, never a topology fallback.
static var last_failure := ""


static func from_spatial(source: WarrenSpatialPlan) \
		-> SectionalPublicRealmPlan:
	last_failure = ""
	if source == null or not source.is_sealed() or source.source_volume == null:
		last_failure = "missing sealed spatial plan or route lineage"
		return null
	var spatial_air := source.grid.cells_with_use(
		WarrenSpatialGrid.Use.PUBLIC_AIR)
	var realm := WarrenVolumePublicRealmAdapter.from_volume(source.source_volume,
		null, null, WarrenPlatformInfillSolver.MAX_OPTIONAL_PATCH_COUNT,
		spatial_air)
	if realm == null:
		last_failure = WarrenVolumePublicRealmAdapter.last_failure
		return null
	if not _same_cells(source.route_floor_cells, realm.surface_claims()):
		last_failure = "macro projection changes authoritative route surfaces"
		return null
	if not _same_cells(spatial_air, realm.air_claims()):
		last_failure = "macro projection changes authoritative public air"
		return null
	return realm


static func _same_cells(left: Variant, right: Variant) -> bool:
	var left_cells := _cell_values(left)
	var right_cells := _cell_values(right)
	if left_cells.size() != right_cells.size():
		return false
	var remaining: Dictionary = {}
	for value: Variant in left_cells:
		remaining[value as Vector3i] = true
	if remaining.size() != left_cells.size():
		return false
	for value: Variant in right_cells:
		var cell := value as Vector3i
		if not remaining.erase(cell):
			return false
	return remaining.is_empty()


static func _cell_values(value: Variant) -> Array:
	if value is Dictionary:
		return (value as Dictionary).keys()
	if value is Array:
		return value as Array
	return []
