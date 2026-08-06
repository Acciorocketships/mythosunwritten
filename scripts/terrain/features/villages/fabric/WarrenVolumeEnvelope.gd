class_name WarrenVolumeEnvelope
extends RefCounted

## Terrain-relative, discrete city mass.  This is a height envelope rather than
## a floating ellipsoid: every column begins at its local natural-ground band,
## and its available construction mass tapers toward the settlement boundary.
const MIN_ENTRY_HEIGHT_BANDS := 2

var world_seed: int
var radius_x: int
var radius_z: int
var max_height_bands: int
var ground_bands: Dictionary = {}
var height_bands: Dictionary = {}
var mass_cells: Dictionary = {}
var last_rejection := ""
var _sealed := false


static func build(p_world_seed: int,
		p_ground_bands: Dictionary = {},
		allow_unsealed_diagnostic: bool = false) -> WarrenVolumeEnvelope:
	var envelope := WarrenVolumeEnvelope.new()
	envelope.world_seed = p_world_seed
	envelope.radius_x = 7 + posmod(_hash(p_world_seed, 11, 0, 0), 3)
	envelope.radius_z = 6 + posmod(_hash(p_world_seed, 17, 0, 0), 3)
	# The envelope reserves complete construction, including roof clearance. The
	# earlier 9–11-band peak was sufficient for abstract walls but starved legal
	# roofed parcels after public headroom was carved through the same mass.
	envelope.max_height_bands = 12 + posmod(_hash(p_world_seed, 23, 0, 0), 3)
	var phase_x := _unit01(_hash(p_world_seed, 29, 0, 0)) * TAU
	var phase_z := _unit01(_hash(p_world_seed, 31, 0, 0)) * TAU
	var skew := (_unit01(_hash(p_world_seed, 37, 0, 0)) - 0.5) * 0.22
	for x in range(-envelope.radius_x - 2, envelope.radius_x + 3):
		for z in range(-envelope.radius_z - 2, envelope.radius_z + 3):
			var column := Vector2i(x, z)
			var warped_x := float(x) + sin(float(z) * 0.43 + phase_x) * 0.72
			var warped_z := float(z) + sin(float(x) * 0.37 + phase_z) * 0.62
			warped_x += warped_z * skew
			var normalized_x := warped_x / float(envelope.radius_x)
			var normalized_z := warped_z / float(envelope.radius_z)
			var gaussian := exp(-0.5 * (normalized_x * normalized_x * 3.25 \
				+ normalized_z * normalized_z * 3.25))
			var correlated := (sin(float(x) * 0.71 + float(z) * 0.29 + phase_x) \
				+ sin(float(z) * 0.63 - float(x) * 0.21 + phase_z)) * 0.42
			var height := floori(float(envelope.max_height_bands) * gaussian \
				+ correlated * gaussian + 0.35)
			if height < 1:
				continue
			var ground := int(p_ground_bands.get(column, 0))
			envelope.ground_bands[column] = ground
			envelope.height_bands[column] = height
			for y in range(ground, ground + height):
				envelope.mass_cells[Vector3i(x, y, z)] = true
	var sealed := envelope._seal()
	return envelope if sealed or allow_unsealed_diagnostic else null


func seal_synthesised() -> bool:
	## Sibling entry point for an envelope whose world_seed/radius/height/
	## ground/mass fields were copied from an already-accepted external solid
	## (see WarrenExcavationVolumeAdapter.envelope_from_massif) rather than
	## grown from this class's own warped Gaussian in build(). The caller is
	## responsible for populating every field build() would otherwise
	## generate; this runs the IDENTICAL _seal() contract so a synthesised
	## envelope can never reach a caller in a state the Gaussian path could
	## not also have produced. Generation is skipped here; validation never is.
	return _seal()


func contains_column(column: Vector2i) -> bool:
	return height_bands.has(column)


func ground_at(column: Vector2i) -> int:
	return int(ground_bands.get(column, 0))


func height_at(column: Vector2i) -> int:
	return int(height_bands.get(column, 0))


func top_at(column: Vector2i) -> int:
	return ground_at(column) + height_at(column)


func contains_air_column(surface_cell: Vector3i, headroom_bands: int) -> bool:
	var column := Vector2i(surface_cell.x, surface_cell.z)
	return contains_column(column) and surface_cell.y >= ground_at(column) \
		and surface_cell.y + headroom_bands <= top_at(column)


func boundary_entry_cells(headroom_bands: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for column_value: Variant in height_bands.keys():
		var column := column_value as Vector2i
		if height_at(column) < maxi(MIN_ENTRY_HEIGHT_BANDS, headroom_bands):
			continue
		var boundary := false
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
				Vector2i.UP, Vector2i.DOWN]:
			if not contains_column(column + direction) \
					or height_at(column + direction) < headroom_bands:
				boundary = true
				break
		if boundary:
			out.append(Vector3i(column.x, ground_at(column), column.y))
	out.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		var ah := _hash(world_seed, 41, a.x, a.z)
		var bh := _hash(world_seed, 41, b.x, b.z)
		return ah < bh if ah != bh else _cell_key(a) < _cell_key(b))
	return out


func deterministic_signature() -> String:
	var parts := PackedStringArray()
	for column_value: Variant in height_bands.keys():
		var column := column_value as Vector2i
		parts.append("%d:%d:%d:%d" % [column.x, column.y,
			ground_at(column), height_at(column)])
	parts.sort()
	return ",".join(parts)


func is_sealed() -> bool:
	return _sealed


func _seal() -> bool:
	if _sealed or radius_x < 3 or radius_z < 3 or max_height_bands < 5 \
			or height_bands.is_empty() or mass_cells.is_empty():
		last_rejection = "missing dimensions, columns, or mass"
		return false
	for column_value: Variant in height_bands.keys():
		var column := column_value as Vector2i
		var height := height_at(column)
		var ground := ground_at(column)
		if height < 1:
			last_rejection = "non-positive column height at %s" % column
			return false
		for y in range(ground, ground + height):
			if not mass_cells.has(Vector3i(column.x, y, column.y)):
				last_rejection = "mass column is discontinuous at %s:%d" % [column, y]
				return false
	if boundary_entry_cells(2).is_empty():
		last_rejection = "no boundary column can provide player headroom"
		return false
	_sealed = true
	return true


static func _hash(seed_value: int, salt: int, x: int, z: int) -> int:
	var value := seed_value * 1103515245 + salt * 12345
	value = value ^ (x * 73856093) ^ (z * 19349663)
	value = value ^ (value >> 13)
	return posmod(value, 2147483629)


static func _unit01(value: int) -> float:
	return float(posmod(value, 1000003)) / 1000003.0


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]
