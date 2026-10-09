extends RefCounted

## Exact, main-thread-only suspension of generated concave shapes. Node
## transforms, layers, metadata and disabled state stay on the existing node.
## Used by opt-in residency; callers must keep actors supported during restoration.
var _records: Array[Dictionary] = []
var compressed_bytes := 0
var source_bytes := 0

func suspend(node: CollisionShape3D) -> bool:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	if not is_instance_valid(node) or not node.shape is ConcavePolygonShape3D: return false
	var shape := node.shape as ConcavePolygonShape3D
	# Imported/shared shapes remain owned by the visual catalogue; archiving
	# their nodes would add storage without releasing the underlying resource.
	if not shape.resource_path.is_empty() or shape.get_script() != null: return false
	var raw := var_to_bytes(shape.get_faces())
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	if packed.is_empty(): return false
	_records.append({"node":weakref(node),"packed":packed,"size":raw.size(),
		"margin":shape.margin,"backface":shape.backface_collision,
		"solver_bias":shape.custom_solver_bias,"name":shape.resource_name,
		"local":shape.resource_local_to_scene})
	compressed_bytes += packed.size()
	source_bytes += raw.size()
	node.shape = null
	return true

func restore_one() -> bool:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	if _records.is_empty(): return false
	var record: Dictionary = _records.back()
	var node := (record.node as WeakRef).get_ref() as CollisionShape3D
	if node != null and node.shape == null:
		var raw: PackedByteArray = record.packed.decompress(record.size,FileAccess.COMPRESSION_ZSTD)
		var faces: Variant = bytes_to_var(raw)
		if not faces is PackedVector3Array or faces.size() % 3 != 0:
			push_error("Invalid archived collision faces; retaining the record")
			return false
		var shape := ConcavePolygonShape3D.new()
		shape.resource_name = record.name
		shape.resource_local_to_scene = record.local
		shape.custom_solver_bias = record.solver_bias
		shape.margin = record.margin
		shape.backface_collision = record.backface
		shape.set_faces(faces)
		node.shape = shape
	_records.pop_back()
	compressed_bytes -= (record.packed as PackedByteArray).size()
	source_bytes -= int(record.size)
	return true

func pending() -> int:
	return _records.size()
