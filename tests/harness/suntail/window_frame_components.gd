extends RefCounted
## Connected authored wood pieces in Pure Village opening panels. UV seams
## duplicate vertices, so topology is welded at 0.1 mm for measurement only.
static func bounds(vertices: PackedVector3Array, indices: PackedInt32Array) -> Array[AABB]:
	var parents: Array[int] = []
	var ids := {}
	var unique: Array[Vector3] = []
	var remap: Array[int] = []
	for v: Vector3 in vertices:
		var key := Vector3i(roundi(v.x*10000),roundi(v.y*10000),roundi(v.z*10000))
		if not ids.has(key):
			ids[key] = parents.size()
			parents.append(parents.size())
			unique.append(v)
		remap.append(ids[key])
	for j in range(0,indices.size(),3):
		for k in [1,2]:
			parents[_root(parents,remap[indices[j+k]])] = _root(parents,remap[indices[j]])
	var boxes := {}
	for j in unique.size():
		var r := _root(parents,j)
		boxes[r] = boxes[r].expand(unique[j]) if boxes.has(r) else AABB(unique[j],Vector3.ZERO)
	var out: Array[AABB] = []
	out.assign(boxes.values())
	return out

static func _root(parents: Array[int], i: int) -> int:
	while parents[i] != i:
		parents[i] = parents[parents[i]]
		i = parents[i]
	return i

## Suntail uses one timber material for its window and structural beams.
## Follow physical component contacts outward from the pane; detached floor,
## corner and roof beams do not belong to the opening assembly.
static func touching_opening(components: Array[AABB], opening: AABB) -> Array[AABB]:
	var selected: Array[AABB] = []
	var pending := components.duplicate()
	var frontier: Array[AABB] = [opening]
	while not frontier.is_empty():
		var current: AABB = frontier.pop_back()
		for index in range(pending.size()-1,-1,-1):
			var box: AABB = pending[index]
			if not current.grow(0.001).intersects(box): continue
			selected.append(box)
			frontier.append(box)
			pending.remove_at(index)
	return selected
