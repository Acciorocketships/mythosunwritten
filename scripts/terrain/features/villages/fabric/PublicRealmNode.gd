class_name PublicRealmNode
extends RefCounted

## One spatial episode in the settlement's public journey. Nodes own only
## resource-free topology and surface claims; buildings bind to them through
## FabricUnit.public_node_id.
enum EpisodeKind {
	STREET,
	STAIR_CANYON,
	UNDERCROFT,
	TERRACE,
	COURT,
	EXTERIOR_GALLERY,
	SHORT_BRIDGE,
}

enum AirRealm {
	EXTERIOR,
	INTERIOR,
}

enum CoverPolicy {
	OPEN,
	COVERED,
}

var stable_id: StringName
var episode_kind: EpisodeKind
var surface_kind: int
var air_realm: AirRealm
var cover_policy: CoverPolicy
var surface_cells: Array[Vector3i] = []
var air_cells: Array[Vector3i] = []
var primary_entry_y: int
var primary_exit_y: int
var requires_fabric_unit: bool
var is_landing: bool
var _cell_set: Dictionary = {}
var _air_cell_set: Dictionary = {}
var _sealed := false


func _init(p_stable_id: StringName, p_episode_kind: EpisodeKind,
		p_surface_kind: int, p_air_realm: AirRealm,
		p_cover_policy: CoverPolicy, p_surface_cells: Array[Vector3i],
		p_air_cells: Array[Vector3i], p_primary_entry_y: int,
		p_primary_exit_y: int, p_requires_fabric_unit: bool = false,
		p_is_landing: bool = false) -> void:
	stable_id = p_stable_id
	episode_kind = p_episode_kind
	surface_kind = p_surface_kind
	air_realm = p_air_realm
	cover_policy = p_cover_policy
	surface_cells.assign(p_surface_cells)
	air_cells.assign(p_air_cells)
	primary_entry_y = p_primary_entry_y
	primary_exit_y = p_primary_exit_y
	requires_fabric_unit = p_requires_fabric_unit
	is_landing = p_is_landing


func seal() -> bool:
	if _sealed or stable_id.is_empty() or surface_cells.is_empty() \
			or air_cells.is_empty() \
			or episode_kind < EpisodeKind.STREET \
			or episode_kind > EpisodeKind.SHORT_BRIDGE \
			or air_realm < AirRealm.EXTERIOR \
			or air_realm > AirRealm.INTERIOR \
			or cover_policy < CoverPolicy.OPEN \
			or cover_policy > CoverPolicy.COVERED:
		return false
	for cell: Vector3i in air_cells:
		var key := _cell_key(cell)
		if _air_cell_set.has(key):
			return false
		_air_cell_set[key] = true
	var has_entry := false
	var has_exit := false
	for cell: Vector3i in surface_cells:
		var key := _cell_key(cell)
		if _cell_set.has(key):
			return false
		# Surface cells name the bottom of a 1.5 m swept interval. Two air
		# cells prove the common 3 m public headroom above every floor claim.
		if not _air_cell_set.has(key) \
				or not _air_cell_set.has(_cell_key(cell + Vector3i.UP)):
			_cell_set.clear()
			_air_cell_set.clear()
			return false
		_cell_set[key] = true
		has_entry = has_entry or cell.y == primary_entry_y
		has_exit = has_exit or cell.y == primary_exit_y
	if not has_entry or not has_exit:
		_cell_set.clear()
		_air_cell_set.clear()
		return false
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func has_cell(cell: Vector3i) -> bool:
	return _cell_set.has(_cell_key(cell))


func has_air_cell(cell: Vector3i) -> bool:
	return _air_cell_set.has(_cell_key(cell))


func min_y() -> int:
	var result := 2147483647
	for cell: Vector3i in surface_cells:
		result = mini(result, cell.y)
	return result


func max_y() -> int:
	var result := -2147483648
	for cell: Vector3i in surface_cells:
		result = maxi(result, cell.y)
	return result


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]
