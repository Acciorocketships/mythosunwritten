extends Resource
class_name TagList

# True passthrough storage (untyped so callers can pass normal arrays)
var tags: Array[String] = []

var _iter_i := 0

func _init(_tags: Array[String] = []) -> void:
	tags = _tags  # passthrough on purpose

# Convenience (optional)
func size() -> int: return tags.size()
func is_empty() -> bool: return tags.is_empty()
func append(tag: String) -> void: tags.append(tag)
func has(tag: String) -> bool: return tags.has(tag)
func clear() -> void: tags.clear()

# Iterable protocol (must match parent signatures; don't type args)
func _iter_init(_arg) -> bool:
	_iter_i = 0
	return tags.size() > 0

func _iter_next(_arg) -> bool:
	_iter_i += 1
	return _iter_i < tags.size()

func _iter_get(_arg):
	return tags[_iter_i]
	
func union(other: TagList) -> TagList:
	var out_dict: Dictionary[String, Variant] = {}
	for tag: String in tags:
		out_dict[tag] = null
	for tag: String in other:
		out_dict[tag] = null
	var out: TagList = TagList.new(out_dict.keys())
	return out
