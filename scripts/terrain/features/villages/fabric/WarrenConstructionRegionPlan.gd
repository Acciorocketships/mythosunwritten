class_name WarrenConstructionRegionPlan
extends RefCounted

## Complete lossless merge of WarrenSpatialGrid face claims into construction
## regions.  It is derived once from the authoritative grid and can be consumed
## by asset compilers without asking building footprints to explain the shell.
var stable_id: StringName
var regions: Array[WarrenConstructionRegion] = []
var audit: Dictionary = {}
var last_rejection := ""
var _sealed := false


func _init(p_stable_id: StringName) -> void:
	stable_id = p_stable_id


static func derive(stable_id: StringName,
		grid: WarrenSpatialGrid) -> WarrenConstructionRegionPlan:
	if stable_id.is_empty() or grid == null or not grid.is_valid():
		return null
	var result := WarrenConstructionRegionPlan.new(stable_id)
	var records := grid.face_claims()
	var by_key: Dictionary = {}
	for record: Dictionary in records:
		by_key[_face_key(record.cell as Vector3i,
			record.direction as Vector3i)] = record
	var consumed: Dictionary = {}
	var ordinal := 0
	for source: Dictionary in records:
		var source_cell := source.cell as Vector3i
		var source_direction := source.direction as Vector3i
		var source_key := _face_key(source_cell, source_direction)
		if consumed.has(source_key):
			continue
		var kind := int(source.kind)
		var owner_id := StringName(source.owner_id)
		var component: Array[Vector3i] = []
		var pending: Array[Vector3i] = [source_cell]
		consumed[source_key] = true
		while not pending.is_empty():
			var cell: Vector3i = pending.pop_back()
			component.append(cell)
			if WarrenConstructionRegion._must_remain_explicit(kind):
				continue
			for tangent: Vector3i in WarrenConstructionRegion \
					._tangent_directions(source_direction):
				var neighbor := cell + tangent
				var key := _face_key(neighbor, source_direction)
				if consumed.has(key) or not by_key.has(key):
					continue
				var candidate := by_key[key] as Dictionary
				if int(candidate.kind) != kind \
						or StringName(candidate.owner_id) != owner_id \
						or _plane_coordinate(neighbor, source_direction) \
							!= _plane_coordinate(source_cell, source_direction):
					continue
				consumed[key] = true
				pending.append(neighbor)
		var region_id := StringName("%s.region.%03d" % [stable_id, ordinal])
		var region := WarrenConstructionRegion.new(region_id, kind, owner_id,
			source_direction)
		for cell: Vector3i in component:
			if not region.add_face(cell):
				return null
		if not region.seal(grid):
			return null
		result.regions.append(region)
		ordinal += 1
	if not result.seal(grid):
		return null
	return result


func seal(grid: WarrenSpatialGrid) -> bool:
	last_rejection = ""
	if _sealed or stable_id.is_empty() or grid == null or regions.is_empty():
		return _reject("missing construction regions")
	var covered: Dictionary = {}
	var kind_counts: Dictionary = {}
	var owner_counts: Dictionary = {}
	for region: WarrenConstructionRegion in regions:
		if region == null or not region.is_sealed():
			return _reject("unsealed construction region")
		kind_counts[region.face_kind] = int(kind_counts.get(
			region.face_kind, 0)) + 1
		owner_counts[region.owner_id] = int(owner_counts.get(
			region.owner_id, 0)) + 1
		for cell: Vector3i in region.face_cells:
			var key := _face_key(cell, region.direction)
			if covered.has(key):
				return _reject("face belongs to two construction regions")
			covered[key] = region.stable_id
	var source_count := grid.face_claims().size()
	if covered.size() != source_count:
		return _reject("construction regions cover %d of %d source faces" % [
			covered.size(), source_count])
	audit = {
		"source_face_count": source_count,
		"construction_region_count": regions.size(),
		"roof_region_count": int(kind_counts.get(
			WarrenSpatialGrid.FaceKind.ROOF, 0)),
		"facade_region_count": int(kind_counts.get(
			WarrenSpatialGrid.FaceKind.FACADE, 0)),
		"door_region_count": int(kind_counts.get(
			WarrenSpatialGrid.FaceKind.DOOR, 0)),
		"owner_count": owner_counts.size(),
	}
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func regions_for_kind(kind: int) -> Array[WarrenConstructionRegion]:
	var out: Array[WarrenConstructionRegion] = []
	for region: WarrenConstructionRegion in regions:
		if region.face_kind == kind:
			out.append(region)
	return out


func deterministic_signature() -> String:
	var parts := PackedStringArray()
	for region: WarrenConstructionRegion in regions:
		parts.append(region.deterministic_signature())
	parts.sort()
	return "%s[%s]" % [String(stable_id), "|".join(parts)]


static func _plane_coordinate(cell: Vector3i,
		direction: Vector3i) -> int:
	return cell.x + 1 if direction.x != 0 \
		else cell.y + 1 if direction.y != 0 else cell.z + 1


static func _face_key(cell: Vector3i, direction: Vector3i) -> String:
	return "%d:%d:%d/%d:%d:%d" % [cell.x, cell.y, cell.z,
		direction.x, direction.y, direction.z]


func _reject(reason: String) -> bool:
	last_rejection = reason
	return false
