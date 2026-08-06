class_name VillageOccupancy
extends RefCounted

## Deterministic bucketed 3D layout index. Explicit roles make legal vertical
## overlap representable; consumers never weaken collision globally to admit a
## deck, undercroft, or protected passage as a one-off special case.
enum Role {
	SOLID,
	WALK_SURFACE,
	HEADROOM,
	GROUND_EXCLUSIVE,
	## A rigid boundary of a declared public walk network. It remains solid to
	## buildings and headroom, but may meet the connected floor it protects at
	## owner seams such as a stair-to-platform landing.
	WALK_GUARD,
}

const BUCKET_SIZE := TerrainSurfaceField.TILE

var _buckets: Dictionary = {}
var _volumes: Array[VillageOccupancyVolume] = []

func can_add(candidate: VillageOccupancyVolume) -> bool:
	return conflicts(candidate).is_empty()

func add(candidate: VillageOccupancyVolume) -> bool:
	if not can_add(candidate):
		return false
	_insert(candidate)
	return true

func add_all(candidates: Array[VillageOccupancyVolume]) -> bool:
	# Validate the transaction before mutating the index. Atomic elevated groups
	# and multi-volume buildings therefore cannot leave partial reservations.
	if not first_conflict(candidates).is_empty():
		return false
	for candidate: VillageOccupancyVolume in candidates:
		_insert(candidate)
	return true

## Returns the first stable conflict without mutation. Atomic compound
## planners can expose a precise audit reason instead of a generic overlap.
func first_conflict(candidates: Array[VillageOccupancyVolume]) -> Dictionary:
	for index in candidates.size():
		var external := conflicts(candidates[index])
		if not external.is_empty():
			return {"candidate": candidates[index],
				"existing": external[0]}
		for prior_index in index:
			if _incompatible(candidates[index], candidates[prior_index]) \
					and candidates[index].overlaps(candidates[prior_index]):
				return {"candidate": candidates[index],
					"existing": candidates[prior_index]}
	return {}

func conflicts(candidate: VillageOccupancyVolume) -> Array[VillageOccupancyVolume]:
	var found: Dictionary = {}
	for key: Vector2i in _bucket_keys(candidate.bounds_xz()):
		for existing: VillageOccupancyVolume in _buckets.get(key, []):
			if found.has(existing.get_instance_id()) \
					or not _incompatible(candidate, existing):
				continue
			if candidate.overlaps(existing):
				found[existing.get_instance_id()] = existing
	var out: Array[VillageOccupancyVolume] = []
	out.assign(found.values())
	out.sort_custom(func(a: VillageOccupancyVolume,
			b: VillageOccupancyVolume) -> bool:
		return String(a.stable_id) < String(b.stable_id))
	return out

func volumes() -> Array[VillageOccupancyVolume]:
	return _volumes.duplicate()


## Tests one atomic candidate set against already-planned structures without
## requiring those reservations to be mutually compatible. This is useful for
## staged construction: a stair may intentionally meet its owning building,
## while a later rock core must still avoid both of them.
static func first_cross_conflict(candidates: Array[VillageOccupancyVolume],
		reservations: Array[VillageOccupancyVolume]) -> Dictionary:
	for candidate: VillageOccupancyVolume in candidates:
		for existing: VillageOccupancyVolume in reservations:
			if _incompatible(candidate, existing) \
					and candidate.overlaps(existing):
				return {"candidate": candidate, "existing": existing}
	return {}

func _insert(volume: VillageOccupancyVolume) -> void:
	_volumes.append(volume)
	for key: Vector2i in _bucket_keys(volume.bounds_xz()):
		if not _buckets.has(key):
			_buckets[key] = []
		_buckets[key].append(volume)

static func _incompatible(a: VillageOccupancyVolume,
		b: VillageOccupancyVolume) -> bool:
	if not a.walk_network_id.is_empty() \
			and a.walk_network_id == b.walk_network_id:
		var walk_pair := a.role == Role.WALK_SURFACE \
			and b.role == Role.WALK_SURFACE
		var guard_contact := (a.role == Role.WALK_GUARD \
			and b.role in [Role.WALK_SURFACE, Role.WALK_GUARD]) \
			or (b.role == Role.WALK_GUARD \
				and a.role in [Role.WALK_SURFACE, Role.WALK_GUARD])
		if walk_pair or guard_contact:
			# Structural ownership may change where public floors and their exact
			# boundary guards meet at a skirt, platform, turn, or stair landing.
			# Generic solids never gain this permission.
			return false
	if not a.owner_id.is_empty() and a.owner_id == b.owner_id:
		if (_is_rigid(a.role) and b.role == Role.HEADROOM) \
				or (a.role == Role.HEADROOM and _is_rigid(b.role)):
			return false
		if a.role == Role.WALK_SURFACE and b.role == Role.WALK_SURFACE:
			# Route cells, turn landings, and stair contacts form one
			# geometric union. Ownership admits only that declared union.
			return false
		if (a.role == Role.WALK_SURFACE and b.role == Role.HEADROOM) \
				or (a.role == Role.HEADROOM and b.role == Role.WALK_SURFACE):
			# The owned walk surface is the floor of its doorway or stair
			# headroom. Foreign walk surfaces remain intrusions.
			return false
		if (_is_rigid(a.role) and b.role == Role.WALK_SURFACE) \
				or (a.role == Role.WALK_SURFACE and _is_rigid(b.role)):
			# A reviewed owned floor may cross its own conservative structure
			# envelope at a doorway or sit directly beneath its supported shell.
			# Different owners remain strict, so this cannot tunnel one route
			# through an unrelated building.
			return false
		if _is_rigid(a.role) and _is_rigid(b.role):
			# Authored compound fabric (for example two railing panels at a
			# corner) may meet as one owned rigid structure. Unowned or
			# differently-owned solids remain strict conflicts.
			return false
	if a.role == Role.GROUND_EXCLUSIVE or b.role == Role.GROUND_EXCLUSIVE:
		return a.role == Role.GROUND_EXCLUSIVE \
			and b.role == Role.GROUND_EXCLUSIVE
	if _is_rigid(a.role) or _is_rigid(b.role):
		return true
	if a.role == Role.HEADROOM or b.role == Role.HEADROOM:
		return a.role == Role.WALK_SURFACE or b.role == Role.WALK_SURFACE
	return a.role == Role.WALK_SURFACE and b.role == Role.WALK_SURFACE


static func _is_rigid(role: int) -> bool:
	return role == Role.SOLID or role == Role.WALK_GUARD

static func _bucket_keys(bounds: Rect2) -> Array[Vector2i]:
	var lo := Vector2i(floori(bounds.position.x / BUCKET_SIZE),
		floori(bounds.position.y / BUCKET_SIZE))
	var hi := Vector2i(floori(bounds.end.x / BUCKET_SIZE),
		floori(bounds.end.y / BUCKET_SIZE))
	var out: Array[Vector2i] = []
	for z in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			out.append(Vector2i(x, z))
	return out
