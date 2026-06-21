# scripts/terrain/tools/SlopeMeshGenerator.gd
# Builds the 4 reusable 12x12 slope component meshes + convex collision slabs.
# All geometry is authored in cell-local coords (x,z in [-6,6], y in [-4,0]).
class_name SlopeMeshGenerator
extends RefCounted

const SEG := 12                       # render segments per 12u cell
const COLLISION_SEG := 2              # convex collision slabs per axis (COLLISION_SEG^2 per slope cell)
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

# COLLISION_SEG x COLLISION_SEG convex hulls, one per sub-quad of the surface,
# each its 4 corner samples plus those pushed down by SKIRT. Convex = fast.
func _convex_slabs(hfn: Callable) -> Array:
	var shapes: Array = []
	var step := (2.0 * H) / COLLISION_SEG
	for iz in COLLISION_SEG:
		for ix in COLLISION_SEG:
			var x0 := -H + ix * step
			var x1 := x0 + step
			var z0 := -H + iz * step
			var z1 := z0 + step
			var pts := PackedVector3Array()
			for c in [[x0, z0], [x1, z0], [x1, z1], [x0, z1]]:
				var y: float = hfn.call(float(c[0]), float(c[1]))
				pts.append(Vector3(c[0], y, c[1]))
				pts.append(Vector3(c[0], y - SKIRT, c[1]))
			var shape := ConvexPolygonShape3D.new()
			shape.points = pts
			shapes.append(shape)
	return shapes
