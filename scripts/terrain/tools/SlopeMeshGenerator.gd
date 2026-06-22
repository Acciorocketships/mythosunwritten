# scripts/terrain/tools/SlopeMeshGenerator.gd
# Builds the 4 reusable 12x12 slope component meshes + convex collision slabs.
# All geometry is authored in cell-local coords (x,z in [-6,6], y in [-4,0]).
class_name SlopeMeshGenerator
extends RefCounted

const SEG := 12                       # render segments per 12u cell
const COLLISION_SEG := 5              # convex collision slabs along each CURVED axis. Odd so the
                                      # middle slab straddles the profile's t=0.5 inflection (z=0),
                                      # where the smootherstep is locally linear and a flat chord
                                      # fits it tightly. Flat axes (zero derivative) get 1 slab.
const FLAT_EPS := 1e-4                # height variation below this => the axis is treated as flat
const H := SlopeProfile.HALF          # 6.0
const SKIRT := 0.4                    # collision thickness below surface

var grass_uv: Vector2 = Vector2.ZERO
var material: Material = null

# --- meshes ---------------------------------------------------------------

func build_top() -> ArrayMesh:
	return _build(func(_x, _z): return 0.0)

func build_edge() -> ArrayMesh:
	return _build(func(x, z): return SlopeProfile.edge_height(x, z))

func build_outer_corner() -> ArrayMesh:
	return _build(func(x, z): return SlopeProfile.outer_corner_height(x, z))

func build_inner_corner() -> ArrayMesh:
	return _build(func(x, z): return SlopeProfile.inner_corner_height(x, z))

func build_outer_corner_stacked() -> ArrayMesh:
	return _build(func(x, z): return SlopeProfile.outer_corner_stacked_height(x, z))

func build_inner_corner_stacked() -> ArrayMesh:
	return _build(func(x, z): return SlopeProfile.inner_corner_stacked_height(x, z))

# Build a SEG x SEG grid over [-H,H]^2, height from `hfn` (Callable(x,z)->float).
func _build(hfn: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := (2.0 * H) / SEG
	for iz in SEG:
		for ix in SEG:
			var x0 := -H + ix * step
			var x1 := x0 + step
			var z0 := -H + iz * step
			var z1 := z0 + step
			var v00 := Vector3(x0, hfn.call(x0, z0), z0)
			var v10 := Vector3(x1, hfn.call(x1, z0), z0)
			var v11 := Vector3(x1, hfn.call(x1, z1), z1)
			var v01 := Vector3(x0, hfn.call(x0, z1), z1)
			_tri(st, v00, v10, v11)
			_tri(st, v00, v11, v01)
	st.generate_normals()
	if material != null:
		st.set_material(material)
	return st.commit()

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for v in [a, b, c]:
		st.set_uv(grass_uv)
		st.add_vertex(v)

# --- collision (convex slabs following the surface) ----------------------

func build_top_collision() -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = Vector3(2.0 * H, SKIRT, 2.0 * H)
	return s  # caller offsets center to y = -SKIRT/2

func build_edge_collision() -> Array:
	return _convex_slabs(func(x, z): return SlopeProfile.edge_height(x, z))

func build_outer_corner_collision() -> Array:
	return _convex_slabs(func(x, z): return SlopeProfile.outer_corner_height(x, z))

func build_inner_corner_collision() -> Array:
	return _convex_slabs(func(x, z): return SlopeProfile.inner_corner_height(x, z))

func build_outer_corner_stacked_collision() -> Array:
	return _convex_slabs(func(x, z): return SlopeProfile.outer_corner_stacked_height(x, z))

func build_inner_corner_stacked_collision() -> Array:
	return _convex_slabs(func(x, z): return SlopeProfile.inner_corner_stacked_height(x, z))

# A grid of convex hulls following the surface: COLLISION_SEG slabs along each axis
# the surface actually curves, 1 along any flat (zero-derivative) axis. Each slab is
# its 4 corner samples plus those pushed down by SKIRT. Convex = fast. Subdividing a
# flat axis (e.g. the edge profile is constant in x) only adds shapes with no gain, so
# we skip it; the saved budget goes into more slabs along the curved axis instead.
func _convex_slabs(hfn: Callable) -> Array:
	var seg := _axis_segments(hfn)
	var shapes: Array = []
	var step_x := (2.0 * H) / seg.x
	var step_z := (2.0 * H) / seg.y
	for iz in seg.y:
		for ix in seg.x:
			var x0 := -H + ix * step_x
			var x1 := x0 + step_x
			var z0 := -H + iz * step_z
			var z1 := z0 + step_z
			var pts := PackedVector3Array()
			for c in [[x0, z0], [x1, z0], [x1, z1], [x0, z1]]:
				var y: float = hfn.call(float(c[0]), float(c[1]))
				pts.append(Vector3(c[0], y, c[1]))
				pts.append(Vector3(c[0], y - SKIRT, c[1]))
			var shape := ConvexPolygonShape3D.new()
			shape.points = pts
			shapes.append(shape)
	return shapes

# Per-axis slab count: COLLISION_SEG where the height changes along that axis, 1 where
# it is flat. Probed on a grid finer than COLLISION_SEG to avoid aliasing a profile that
# happens to repeat at the slab boundaries. Returns Vector2i(x_slabs, z_slabs).
func _axis_segments(hfn: Callable) -> Vector2i:
	const PROBE := 8
	var step := (2.0 * H) / PROBE
	var varies_x := false
	var varies_z := false
	for iz in PROBE + 1:
		var z := -H + iz * step
		for ix in PROBE + 1:
			var x := -H + ix * step
			var y: float = hfn.call(x, z)
			if not varies_x and absf(hfn.call(minf(x + step, H), z) - y) > FLAT_EPS:
				varies_x = true
			if not varies_z and absf(hfn.call(x, minf(z + step, H)) - y) > FLAT_EPS:
				varies_z = true
		if varies_x and varies_z:
			break
	return Vector2i(COLLISION_SEG if varies_x else 1, COLLISION_SEG if varies_z else 1)
