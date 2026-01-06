extends Resource
class_name TerrainModuleList

var library: Array[TerrainModule]

func _init(list: Array[TerrainModule] = []) -> void:
	library = list
	
func size() -> int:
	return library.size()
	
func append(element: TerrainModule) -> void:
	library.append(element)
	
func is_empty() -> bool:
	return library.is_empty()
