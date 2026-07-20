@tool
extends SceneTree

## Runs from the exported environment-only PCK, in an otherwise empty
## project directory. It deliberately avoids project class-name lookups so
## the check proves the pack itself contains every descriptor, dynamic
## visual_path target, mesh, material, texture, and schema script.

const INDEX_PATH := "res://terrain/environment/catalog/index.tres"

func _init() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var index := load(INDEX_PATH)
	if index == null:
		_fail("missing catalogue index")
		return
	var descriptors: Array = index.get("descriptors")
	if descriptors.is_empty():
		_fail("catalogue index is empty")
		return
	var piece_count := 0
	var collision_count := 0
	for descriptor: Resource in descriptors:
		if descriptor == null:
			_fail("catalogue contains a null descriptor")
			return
		var asset_id := String(descriptor.get("id"))
		var visual_path := String(descriptor.get("visual_path"))
		if visual_path.is_empty() or not ResourceLoader.exists(visual_path):
			_fail("%s visual_path is absent from PCK: %s" % [asset_id, visual_path])
			return
		var visual := load(visual_path)
		if visual == null:
			_fail("%s visual does not load from PCK" % asset_id)
			return
		var pieces: Array = visual.get("pieces")
		if pieces.is_empty():
			_fail("%s visual has no pieces" % asset_id)
			return
		for piece: Resource in pieces:
			var mesh := piece.get("mesh") as Mesh
			if mesh == null or mesh.get_surface_count() == 0:
				_fail("%s contains an invalid mesh piece" % asset_id)
				return
			for surface_index in mesh.get_surface_count():
				if mesh.surface_get_material(surface_index) == null:
					_fail("%s contains an unmaterialed surface" % asset_id)
					return
			piece_count += 1
		var collisions: Array = visual.get("collisions")
		if collisions.size() != int(descriptor.get("collision_piece_count")):
			_fail("%s collision count disagrees with its descriptor" % asset_id)
			return
		for collision: Resource in collisions:
			var shape := collision.get("shape") as Shape3D
			var local_transform := collision.get("local_transform") as Transform3D
			if shape == null or not local_transform.is_finite():
				_fail("%s contains an invalid collision piece" % asset_id)
				return
			collision_count += 1
	print("[environment_pack] verified %d descriptors, %d visual pieces, and %d collision pieces" % [
		descriptors.size(), piece_count, collision_count])
	quit(0)

func _fail(message: String) -> void:
	push_error("Environment PCK verification failed: %s" % message)
	quit(1)
