class_name EnvironmentInstancePayload
extends RefCounted

## Worker-safe, render-resource-free instances grouped by stable asset ID.
## A batch is either entirely anonymous or carries one stable ID per transform.
var batches: Dictionary = {}
var instance_count := 0
## Plain worker-side box colliders for generated structures whose reviewed
## visual mesh has a broader baked hull than the authored traversal contract.
## Resources are still created only by `EnvironmentCollisionBuilder` on the
## main thread.
var collision_boxes: Array[Dictionary] = []
## Generated walk-surface meshes (stairs/ramps) as plain packed arrays. Each
## entry carries its own collision faces and a world anchor for half-open
## block ownership; the commit adapter alone turns them into resources.
var surface_meshes: Array[Dictionary] = []


func add_surface_mesh(mesh: Dictionary) -> void:
	surface_meshes.append(mesh.duplicate(true))


static func _surface_mesh_is_valid(mesh: Dictionary) -> bool:
	if StringName(mesh.get("stable_id", "")).is_empty() \
			or not mesh.has("anchor") or not mesh.has("vertices") \
			or not mesh.has("normals") or not mesh.has("uvs") \
			or not mesh.has("indices") or not mesh.has("collision_faces"):
		return false
	var vertices := mesh.vertices as PackedVector3Array
	var normals := mesh.normals as PackedVector3Array
	var uvs := mesh.uvs as PackedVector2Array
	var indices := mesh.indices as PackedInt32Array
	var collision := mesh.collision_faces as PackedVector3Array
	var visual_only := bool(mesh.get("visual_only", false))
	if vertices.is_empty() or normals.size() != vertices.size() \
			or uvs.size() != vertices.size() or indices.is_empty() \
			or indices.size() % 3 != 0 \
			or (collision.is_empty() and not visual_only) \
			or collision.size() % 3 != 0:
		return false
	for index: int in indices:
		if index < 0 or index >= vertices.size():
			return false
	return true

func add(asset_id: StringName, transform: Transform3D, color: Color,
		stable_id: StringName = &"", collision_enabled: bool = true) -> void:
	if not batches.has(asset_id):
		batches[asset_id] = {"transforms": [], "colors": [], "ids": [],
			"collision_enabled": []}
	var batch: Dictionary = batches[asset_id]
	var identified := not stable_id.is_empty()
	assert(batch.transforms.is_empty() or identified == not batch.ids.is_empty(),
		"One environment batch cannot mix identified and anonymous instances")
	var collision_flags: Array = batch.get("collision_enabled", [])
	if collision_flags.is_empty() and not batch.transforms.is_empty():
		collision_flags.resize(batch.transforms.size())
		collision_flags.fill(true)
	batch.transforms.append(transform)
	batch.colors.append(color)
	collision_flags.append(collision_enabled)
	batch["collision_enabled"] = collision_flags
	if identified:
		batch.ids.append(stable_id)
	instance_count += 1


func add_collision_box(transform: Transform3D, size: Vector3,
		stable_id: StringName = &"") -> void:
	assert(transform.is_finite() and size.is_finite())
	assert(size.x > 0.0 and size.y > 0.0 and size.z > 0.0)
	collision_boxes.append({"transform": transform, "size": size,
		"stable_id": stable_id})

func asset_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(batches.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out

func validate() -> bool:
	var total := 0
	for asset_id: StringName in asset_ids():
		var batch: Dictionary = batches[asset_id]
		if batch.transforms.size() != batch.colors.size():
			return false
		if not batch.ids.is_empty() and batch.ids.size() != batch.transforms.size():
			return false
		var collision_flags: Array = batch.get("collision_enabled", [])
		if not collision_flags.is_empty() \
				and collision_flags.size() != batch.transforms.size():
			return false
		total += batch.transforms.size()
	for box: Dictionary in collision_boxes:
		var transform := box.get("transform", Transform3D()) as Transform3D
		var size := box.get("size", Vector3.ZERO) as Vector3
		if not transform.is_finite() or not size.is_finite() \
				or size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
			return false
	for mesh: Dictionary in surface_meshes:
		if not _surface_mesh_is_valid(mesh):
			return false
	return total == instance_count

func append_from(other: EnvironmentInstancePayload,
		ownership: Rect2 = Rect2()) -> void:
	assert(other != null and other.validate())
	var filter_by_owner := ownership.has_area()
	for asset_id: StringName in other.asset_ids():
		var batch: Dictionary = other.batches[asset_id]
		for index in batch.transforms.size():
			var transform: Transform3D = batch.transforms[index]
			var anchor := Vector2(transform.origin.x, transform.origin.z)
			if filter_by_owner and not _half_open_has_point(ownership, anchor):
				continue
			var stable_id := StringName()
			if not batch.ids.is_empty():
				stable_id = batch.ids[index]
			var collision_flags: Array = batch.get("collision_enabled", [])
			var collision_enabled := collision_flags.is_empty() \
				or bool(collision_flags[index])
			add(asset_id, transform, batch.colors[index], stable_id,
				collision_enabled)
	for mesh: Dictionary in other.surface_meshes:
		var anchor := mesh.get("anchor", Vector3.ZERO) as Vector3
		if filter_by_owner and not _half_open_has_point(ownership,
				Vector2(anchor.x, anchor.z)):
			continue
		add_surface_mesh(mesh)
	for box: Dictionary in other.collision_boxes:
		var transform := box.transform as Transform3D
		var anchor := Vector2(transform.origin.x, transform.origin.z)
		if filter_by_owner and not _half_open_has_point(ownership, anchor):
			continue
		add_collision_box(transform, box.size as Vector3,
			StringName(box.get("stable_id", &"")))

func duplicate_payload() -> EnvironmentInstancePayload:
	var out := EnvironmentInstancePayload.new()
	out.append_from(self)
	return out

static func _half_open_has_point(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x and point.y >= rect.position.y \
		and point.x < rect.end.x and point.y < rect.end.y
