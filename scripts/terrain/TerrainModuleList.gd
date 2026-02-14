extends Resource
class_name TerrainModuleList

var library: Array[TerrainModule] = []

var _iter_i := 0

func _init(list: Array[TerrainModule] = []) -> void:
	library = list

func copy() -> TerrainModuleList:
	# `Resource.duplicate()` does not reliably copy plain script vars like `library`.
	# Use an explicit copy for predictable behavior.
	return TerrainModuleList.new(library.duplicate())
	
func size() -> int:
	return library.size()

func get_at_index(i: int) -> TerrainModule:
	if i < 0 or i >= library.size():
		return null
	return library[i]

func append(element: TerrainModule) -> void:
	library.append(element)
	
func remove(element: TerrainModule) -> void:
	library.erase(element)
	
func is_empty() -> bool:
	return library.is_empty()

func _iter_init(_arg) -> bool:
	_iter_i = 0
	return library.size() > 0

func _iter_next(_arg) -> bool:
	_iter_i += 1
	return _iter_i < library.size()

func _iter_get(_arg):
	return library[_iter_i]
