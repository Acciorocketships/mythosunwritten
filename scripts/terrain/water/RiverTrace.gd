# scripts/terrain/water/RiverTrace.gd
# One traced river: a polyline descending the smooth landform field from a
# mountain source. Parallel arrays per sample: points (world XZ), beds
# (monotone non-increasing water-bed height), widths (ribbon half-width,
# grows downstream). A river ends either by JOINING higher-priority water
# (joined = true, no pond) or with a terminal pond. source_pool always set.
class_name RiverTrace
extends RefCounted

var source_cell: Vector2i          # super-grid cell — identity
var priority: int                  # 64-bit hash; higher wins junctions
var points: PackedVector2Array = PackedVector2Array()
var beds: PackedFloat32Array = PackedFloat32Array()
var widths: PackedFloat32Array = PackedFloat32Array()
var joined: bool = false
var source_pool: PondStamp = null
var pond: PondStamp = null         # terminal pond; null when joined


## Conservative world-space AABB around everything this river touches.
func bounds() -> Rect2:
	var r: Rect2 = Rect2(points[0], Vector2.ZERO)
	for p in points:
		r = r.expand(p)
	if source_pool != null:
		r = r.merge(Rect2(source_pool.center - Vector2.ONE * source_pool.bound_radius(),
			Vector2.ONE * source_pool.bound_radius() * 2.0))
	if pond != null:
		r = r.merge(Rect2(pond.center - Vector2.ONE * pond.bound_radius(),
			Vector2.ONE * pond.bound_radius() * 2.0))
	return r
