class_name EnvironmentInstancePayload
extends RefCounted

## Worker-safe, render-resource-free instances grouped by stable asset ID.
## A batch is either entirely anonymous or carries one stable ID per transform.
var batches: Dictionary = {}
var instance_count := 0
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
	if vertices.is_empty() or normals.size() != vertices.size() \
			or uvs.size() != vertices.size() or indices.is_empty() \
			or indices.size() % 3 != 0 or collision.is_empty() \
			or collision.size() % 3 != 0:
		return false
	for index: int in indices:
		if index < 0 or index >= vertices.size():
			return false
	return true

func add(asset_id: StringName, transform: Transform3D, color: Color,
		stable_id: StringName = &"") -> void:
	if not batches.has(asset_id):
		batches[asset_id] = {"transforms": [], "colors": [], "ids": []}
	var batch: Dictionary = batches[asset_id]
	var identified := not stable_id.is_empty()
	assert(batch.transforms.is_empty() or identified == not batch.ids.is_empty(),
		"One environment batch cannot mix identified and anonymous instances")
	batch.transforms.append(transform)
	batch.colors.append(color)
	if identified:
		batch.ids.append(stable_id)
	instance_count += 1

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
		total += batch.transforms.size()
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
			add(asset_id, transform, batch.colors[index], stable_id)
	for mesh: Dictionary in other.surface_meshes:
		var anchor := mesh.get("anchor", Vector3.ZERO) as Vector3
		if filter_by_owner and not _half_open_has_point(ownership,
				Vector2(anchor.x, anchor.z)):
			continue
		add_surface_mesh(mesh)

func duplicate_payload() -> EnvironmentInstancePayload:
	var out := EnvironmentInstancePayload.new()
	out.append_from(self)
	return out

static func _half_open_has_point(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x and point.y >= rect.position.y \
		and point.x < rect.end.x and point.y < rect.end.y
