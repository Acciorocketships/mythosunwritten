# scripts/terrain/tools/SlopeProfile.gd
class_name SlopeProfile
extends RefCounted

const HALF := 3.0      # half cell width
const CELL := 6.0      # cell / slope band width
const HEIGHT := 4.0    # total drop (top y=0 to bottom y=-4)
const BOTTOM := -4.0

static func smootherstep(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

# Ramp factor for a cell-local coord ramping toward its negative side.
# 0 at c=+HALF (inner/plateau), 1 at c=-HALF (outer/boundary).
static func _ramp(c: float) -> float:
	return smootherstep((HALF - c) / CELL)

# Edge: ramps toward front (-z), flat across x.
static func edge_height(_x: float, z: float) -> float:
	return BOTTOM * _ramp(z)

# Outer (convex) corner: ramps toward FL (-x,-z). a=front ramp, b=left ramp.
# f(a,b)=a+b-ab so f(a,0)=a and f(0,b)=b -> seams match the two edges.
static func outer_corner_height(x: float, z: float) -> float:
	var a := _ramp(z)
	var b := _ramp(x)
	return BOTTOM * (a + b - a * b)

# Inner (concave) corner: plateau wraps; only the far corner dips. f=a*b.
static func inner_corner_height(x: float, z: float) -> float:
	var a := _ramp(z)
	var b := _ramp(x)
	return BOTTOM * (a * b)
