# scripts/terrain/water/WaterGroundSnapshot.gd
# Frozen point heights (and storeys) of one water fill window: the only terrain
# a WaterSampler keeps after its chunk's live region is evicted. It answers the
# read API TerrainTileField uses (surface_height / storey_at /
# terrain_tile_size), so the tile kernel -- a pure function of point heights --
# reconstructs exactly the ground the live region gave while the sampler and
# WaterField share one fill evaluator (WaterField._fill_bilinear). Frozen packed
# arrays plus a bounded, locked cache of exact surface queries; safe across
# the worker-to-main-thread handoff.
# Town grades arrive as per-point controls (native_control_heights) and are
# therefore captured; a legacy post-classification grade warp is not.
class_name WaterGroundSnapshot
extends RefCounted

var _first: Vector2i
var _w: int
var _h: int
var _heights: PackedFloat32Array
var _storeys: PackedInt32Array


## Captures every lattice point a surface query inside `rect` can read (the
## four corners of each tile it touches), plus one point of slack.
static func capture(region, rect: Rect2) -> WaterGroundSnapshot:
	var s := WaterGroundSnapshot.new()
	var pitch := TerrainTileField.spacing(region)
	s._first = Vector2i((rect.position / pitch).floor()) - Vector2i.ONE
	var last := Vector2i((rect.end / pitch).floor()) + Vector2i.ONE * 2
	s._w = last.x - s._first.x + 1
	s._h = last.y - s._first.y + 1
	s._heights.resize(s._w * s._h)
	s._storeys.resize(s._w * s._h)
	for j in s._h:
		for i in s._w:
			var p := s._first + Vector2i(i, j)
			s._heights[j * s._w + i] = region.surface_height(p.x, p.y)
			s._storeys[j * s._w + i] = region.storey_at(p.x, p.y)
	return s


func terrain_tile_size() -> float:
	return HeightfieldPlan.POINT


func surface_height(i: int, j: int) -> float:
	return _heights[_index(i, j)]


func storey_at(i: int, j: int) -> int:
	return _storeys[_index(i, j)]


func _index(i: int, j: int) -> int:
	assert(i >= _first.x and j >= _first.y and i < _first.x + _w and j < _first.y + _h,
		"point (%d, %d) lies outside the frozen fill window" % [i, j])
	return (j - _first.y) * _w + (i - _first.x)


## Water derivatives repeatedly probe the same exact wall and bank points.
## Keep a bounded FIFO of those immutable heights. A Vector2 lookup is only
## an index: retain both original doubles to reject float32 key collisions.
const SURFACE_CACHE_CAP := 8192
var _surface_memo: Dictionary = {}
var _surface_keys: Array[Vector2] = []
var _surface_next := 0
var _surface_lock := Mutex.new()

func water_surface_y(x: float, z: float) -> float:
	var key := Vector2(x,z)
	_surface_lock.lock()
	var found: Variant = _surface_memo.get(key)
	_surface_lock.unlock()
	if found != null and found[0] == x and found[1] == z: return found[2]
	var value := TerrainTileField.surface_y(self,x,z)
	_surface_lock.lock()
	if not _surface_memo.has(key):
		if _surface_keys.size() < SURFACE_CACHE_CAP:
			_surface_keys.append(key)
		else:
			_surface_memo.erase(_surface_keys[_surface_next])
			_surface_keys[_surface_next] = key
			_surface_next = (_surface_next + 1) % SURFACE_CACHE_CAP
	_surface_memo[key] = PackedFloat64Array([x,z,value])
	_surface_lock.unlock()
	return value
