class_name WarrenSpatialGrid
extends RefCounted

## Bounded, resource-free fine lattice for the volumetric warren.  Every axis
## uses FabricRecipe's 1.5 m construction cell.  Hot mutually-exclusive facts
## live in packed arrays; uncommon reservations and oriented face claims remain
## sparse.  Nothing in this class creates render, physics, or scene resources.
const CELL_SIZE_M := 1.5
const STOREY_CELLS := 2
const ROOM_BAY_CELLS := Vector2i(2, 2)

enum Use {
	OUTSIDE,
	ALLOCATABLE,
	PUBLIC_AIR,
	DAYLIGHT_AIR,
	PRIVATE_VOLUME,
	STRUCTURAL_VOLUME,
	SERVICE_VOID,
}

enum Reservation {
	PUBLIC_CLEARANCE = 1 << 0,
	PRIVATE_CONNECTION = 1 << 1,
	VISUAL_CLEARANCE = 1 << 2,
	TERRAIN_BEARING = 1 << 3,
	LOAD_CHANNEL = 1 << 4,
	ROOF_CLEARANCE = 1 << 5,
	FEATURE = 1 << 6,
	DAYLIGHT = 1 << 7,
	CONSTRUCTION_SEAM = 1 << 8,
}

enum FaceKind {
	PUBLIC_FLOOR,
	PRIVATE_FLOOR,
	FACADE,
	PARTY_WALL,
	SOFFIT,
	ROOF,
	GUARD,
	DOOR,
	WINDOW,
	OPEN_SEAM,
	CONSTRUCTION_JOINT,
}

const _KNOWN_RESERVATION_BITS := (1 << 9) - 1
const _SHAREABLE_RESERVATION_BITS := Reservation.TERRAIN_BEARING \
	| Reservation.LOAD_CHANNEL | Reservation.CONSTRUCTION_SEAM

var minimum: Vector3i
var size: Vector3i
var last_rejection := ""
var _use_by_cell := PackedByteArray()
var _owner_by_cell := PackedInt32Array()
var _reservation_bits_by_cell := PackedInt32Array()
var _owner_names: Array[StringName] = [&""]
var _owner_index_by_name: Dictionary = {&"": 0}
## One reservation bit may have several owners only when the bit is explicitly
## shareable.  The value is a Dictionary-as-set of integer owner indices.
var _reservation_owners: Dictionary = {}
var _face_claims: Dictionary = {}
var _sealed := false


func _init(p_minimum: Vector3i, p_size: Vector3i) -> void:
	minimum = p_minimum
	size = p_size
	if not is_valid():
		return
	var count := size.x * size.y * size.z
	_use_by_cell.resize(count)
	_use_by_cell.fill(Use.OUTSIDE)
	_owner_by_cell.resize(count)
	_owner_by_cell.fill(0)
	_reservation_bits_by_cell.resize(count)
	_reservation_bits_by_cell.fill(0)


func is_valid() -> bool:
	return size.x > 0 and size.y > 0 and size.z > 0


func is_sealed() -> bool:
	return _sealed


func seal() -> bool:
	if _sealed or not is_valid():
		return false
	_sealed = true
	return true


func contains(cell: Vector3i) -> bool:
	var local := cell - minimum
	return local.x >= 0 and local.y >= 0 and local.z >= 0 \
		and local.x < size.x and local.y < size.y and local.z < size.z


func index_for(cell: Vector3i) -> int:
	if not contains(cell):
		return -1
	var local := cell - minimum
	return local.x + size.x * (local.z + size.z * local.y)


func cell_for_index(index: int) -> Vector3i:
	if index < 0 or index >= _use_by_cell.size():
		return Vector3i(2147483647, 2147483647, 2147483647)
	var y := index / (size.x * size.z)
	var in_layer := index - y * size.x * size.z
	var z := in_layer / size.x
	var x := in_layer - z * size.x
	return minimum + Vector3i(x, y, z)


func use_at(cell: Vector3i) -> int:
	var index := index_for(cell)
	return Use.OUTSIDE if index < 0 else int(_use_by_cell[index])


func owner_name_at(cell: Vector3i) -> StringName:
	var index := index_for(cell)
	if index < 0:
		return &""
	var owner_index := int(_owner_by_cell[index])
	return _owner_names[owner_index] if owner_index >= 0 \
		and owner_index < _owner_names.size() else &""


func reservation_bits_at(cell: Vector3i) -> int:
	var index := index_for(cell)
	return 0 if index < 0 else int(_reservation_bits_by_cell[index])


func reservation_owned_by(cell: Vector3i, bit: int,
		owner_id: StringName) -> bool:
	var index := index_for(cell)
	if index < 0 or bit <= 0 or (reservation_bits_at(cell) & bit) != bit:
		return false
	var owner_index := int(_owner_index_by_name.get(owner_id, -1))
	if owner_index < 0:
		return false
	for one_bit: int in _individual_bits(bit):
		var owners := _reservation_owners.get(
			_reservation_key(index, one_bit), {}) as Dictionary
		if not owners.has(owner_index):
			return false
	return true


func face_claim(cell: Vector3i, direction: Vector3i) -> Dictionary:
	var key := _face_key(cell, direction)
	return (_face_claims.get(key, {}) as Dictionary).duplicate(true)


func face_claims() -> Array[Dictionary]:
	var keys := PackedStringArray()
	for key_value: Variant in _face_claims.keys():
		keys.append(String(key_value))
	keys.sort()
	var out: Array[Dictionary] = []
	for key: String in keys:
		out.append((_face_claims[key] as Dictionary).duplicate(true))
	return out


func cells_with_use(use_value: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if use_value < Use.OUTSIDE or use_value > Use.SERVICE_VOID:
		return out
	for index in _use_by_cell.size():
		if int(_use_by_cell[index]) == use_value:
			out.append(cell_for_index(index))
	return out


func count_use(use_value: int) -> int:
	var count := 0
	for value: int in _use_by_cell:
		count += int(value == use_value)
	return count


func begin_transaction(stable_id: StringName) -> WarrenSpatialTransaction:
	return WarrenSpatialTransaction.new(self, stable_id)


func commit_transaction(transaction: WarrenSpatialTransaction) -> bool:
	last_rejection = ""
	if _sealed or transaction == null or transaction.grid != self \
			or transaction.stable_id.is_empty() or transaction.is_closed():
		return _reject("sealed grid or invalid transaction")
	if not _validate_requirements(transaction.requirements):
		return false
	if not _validate_assignments(transaction.assignments):
		return false
	if not _validate_reservations(transaction.reservations):
		return false
	if not _validate_faces(transaction.face_records):
		return false
	_apply_assignments(transaction.assignments)
	_apply_reservations(transaction.reservations)
	_apply_faces(transaction.face_records)
	return true


func deterministic_signature() -> String:
	var cells := PackedStringArray()
	for index in _use_by_cell.size():
		var use_value := int(_use_by_cell[index])
		var owner_index := int(_owner_by_cell[index])
		var bits := int(_reservation_bits_by_cell[index])
		if use_value == Use.OUTSIDE and owner_index == 0 and bits == 0:
			continue
		var cell := cell_for_index(index)
		cells.append("%d:%d:%d=%d/%s/%d" % [cell.x, cell.y, cell.z,
			use_value, String(_owner_names[owner_index]), bits])
	var faces := PackedStringArray()
	for record: Dictionary in face_claims():
		var cell := record.cell as Vector3i
		var direction := record.direction as Vector3i
		faces.append("%d:%d:%d>%d:%d:%d=%d/%s" % [cell.x, cell.y,
			cell.z, direction.x, direction.y, direction.z, int(record.kind),
			StringName(record.owner_id)])
	return "%d:%d:%d/%d:%d:%d|%s|%s" % [minimum.x, minimum.y,
		minimum.z, size.x, size.y, size.z, ",".join(cells),
		",".join(faces)]


func _validate_requirements(requirements: Dictionary) -> bool:
	for index_value: Variant in requirements.keys():
		var index := int(index_value)
		if index < 0 or index >= _use_by_cell.size():
			return _reject("required cell leaves the grid")
		var allowed := requirements[index] as Dictionary
		if not allowed.has(int(_use_by_cell[index])):
			return _reject("required use changed at %s" % cell_for_index(index))
	return true


func _validate_assignments(assignments: Dictionary) -> bool:
	for index_value: Variant in assignments.keys():
		var index := int(index_value)
		if index < 0 or index >= _use_by_cell.size():
			return _reject("assignment leaves the grid")
		var assignment := assignments[index] as Dictionary
		var next_use := int(assignment.use)
		var next_owner := StringName(assignment.owner_id)
		if next_use < Use.OUTSIDE or next_use > Use.SERVICE_VOID \
				or next_owner.is_empty() and next_use != Use.OUTSIDE:
			return _reject("invalid assignment at %s" % cell_for_index(index))
		var current_use := int(_use_by_cell[index])
		var current_owner := _owner_names[int(_owner_by_cell[index])]
		if current_use == next_use and current_owner == next_owner:
			continue
		if current_use == Use.OUTSIDE or current_use == Use.ALLOCATABLE:
			continue
		return _reject("final volume already owns %s" % cell_for_index(index))
	return true


func _validate_reservations(reservations: Array[Dictionary]) -> bool:
	for record: Dictionary in reservations:
		var index := int(record.index)
		var bits := int(record.bits)
		var owner_id := StringName(record.owner_id)
		if index < 0 or index >= _use_by_cell.size() or bits <= 0 \
				or (bits & ~_KNOWN_RESERVATION_BITS) != 0 or owner_id.is_empty():
			return _reject("invalid reservation")
		for bit: int in _individual_bits(bits):
			if (bit & _SHAREABLE_RESERVATION_BITS) != 0:
				continue
			var owners := _reservation_owners.get(
				_reservation_key(index, bit), {}) as Dictionary
			for owner_index_value: Variant in owners.keys():
				var existing_id := _owner_names[int(owner_index_value)]
				if existing_id != owner_id:
					return _reject("reservation conflict at %s" \
						% cell_for_index(index))
	return true


func _validate_faces(records: Array[Dictionary]) -> bool:
	for record: Dictionary in records:
		var cell := record.cell as Vector3i
		var direction := record.direction as Vector3i
		var kind := int(record.kind)
		var owner_id := StringName(record.owner_id)
		if not contains(cell) or not _cardinal(direction) \
				or kind < FaceKind.PUBLIC_FLOOR \
				or kind > FaceKind.CONSTRUCTION_JOINT or owner_id.is_empty():
			return _reject("invalid face claim")
		var key := _face_key(cell, direction)
		var existing := _face_claims.get(key, {}) as Dictionary
		if existing.is_empty():
			continue
		if int(existing.kind) != kind \
				or StringName(existing.owner_id) != owner_id:
			return _reject("face claim conflict at %s" % key)
	return true


func _apply_assignments(assignments: Dictionary) -> void:
	for index_value: Variant in assignments.keys():
		var index := int(index_value)
		var assignment := assignments[index] as Dictionary
		var owner_id := StringName(assignment.owner_id)
		_use_by_cell[index] = int(assignment.use)
		_owner_by_cell[index] = _owner_index(owner_id) \
			if not owner_id.is_empty() else 0


func _apply_reservations(reservations: Array[Dictionary]) -> void:
	for record: Dictionary in reservations:
		var index := int(record.index)
		var bits := int(record.bits)
		var owner_index := _owner_index(StringName(record.owner_id))
		_reservation_bits_by_cell[index] = int(
			_reservation_bits_by_cell[index]) | bits
		for bit: int in _individual_bits(bits):
			var key := _reservation_key(index, bit)
			if not _reservation_owners.has(key):
				_reservation_owners[key] = {}
			(_reservation_owners[key] as Dictionary)[owner_index] = true


func _apply_faces(records: Array[Dictionary]) -> void:
	for source: Dictionary in records:
		var record := _canonical_face(source.cell as Vector3i,
			source.direction as Vector3i)
		record["kind"] = int(source.kind)
		record["owner_id"] = StringName(source.owner_id)
		_face_claims[_face_key(record.cell, record.direction)] = record


func _owner_index(owner_id: StringName) -> int:
	if _owner_index_by_name.has(owner_id):
		return int(_owner_index_by_name[owner_id])
	var index := _owner_names.size()
	_owner_names.append(owner_id)
	_owner_index_by_name[owner_id] = index
	return index


static func _cardinal(direction: Vector3i) -> bool:
	return absi(direction.x) + absi(direction.y) + absi(direction.z) == 1


static func _canonical_face(cell: Vector3i,
		direction: Vector3i) -> Dictionary:
	var origin := cell
	var normal := direction
	if direction.x < 0 or direction.y < 0 or direction.z < 0:
		origin += direction
		normal = -direction
	return {"cell": origin, "direction": normal}


static func _face_key(cell: Vector3i, direction: Vector3i) -> String:
	if not _cardinal(direction):
		return ""
	var canonical := _canonical_face(cell, direction)
	var origin := canonical.cell as Vector3i
	var normal := canonical.direction as Vector3i
	return "%d:%d:%d/%d:%d:%d" % [origin.x, origin.y, origin.z,
		normal.x, normal.y, normal.z]


static func _reservation_key(index: int, bit: int) -> String:
	return "%d/%d" % [index, bit]


static func _individual_bits(bits: int) -> Array[int]:
	var out: Array[int] = []
	var bit := 1
	while bit <= _KNOWN_RESERVATION_BITS:
		if (bits & bit) != 0:
			out.append(bit)
		bit <<= 1
	return out


func _reject(reason: String) -> bool:
	last_rejection = reason
	return false
