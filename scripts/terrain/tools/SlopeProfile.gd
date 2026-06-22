# scripts/terrain/tools/SlopeProfile.gd
class_name SlopeProfile
extends RefCounted

const HALF := 6.0       # half cell width (12u cell -> 50% slope band)
const CELL := 12.0      # cell / slope band width
const HEIGHT := 4.0     # total drop magnitude (single source of truth)
const BOTTOM := -HEIGHT # plateau top is y=0, lower ground is y=-HEIGHT

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

# --- stacked (mating) corner profiles --------------------------------------
# A 2-storey corner is ONE S: flat at both far ends, steepest at the storey seam.
# Upper tile = top half of the S (convex), lower tile = bottom half (concave).
# The S's steep inflection sits AT the seam, so the upper tile's bottom tangent
# and the lower tile's top tangent match -> the stacked corner is C1.
#
# `_top_s` / `_bot_s` are the two halves of a smootherstep S, split at its t=0.5
# inflection: _top_s(d) runs the flat-shoulder->inflection half (0 flat at d=0,
# steepest at d=1), _bot_s(e) runs the inflection->flat-shoulder half (steepest
# at e=0, flat at e=1). Both have slope 1.875 per unit input at the seam, so when
# fed matching coordinates the world tangents agree (test_seam_tangents_mate).
#
# The catch: the normal `_ramp` (smootherstep) is FLAT at the far corner, which
# would zero the world derivative there. So the corner steepening is driven by a
# LINEAR seam-band coordinate (`UP_BAND`/`IN_BAND` wide) that has constant non-zero slope
# at the seam corner. The steep field is gated to the diagonal (k = a*b for outer,
# vanishing toward the +,+ seam for inner) so the edge-seams keep the plain `edge`
# / flat profile beside the corner.

# Band widths (world units) over which the steep S-half ramps at the storey seam,
# and how much of the inner onset is the steep seam band vs the gentle tail. Tuned
# so the outer-bottom and inner-top seam tangents agree (test_seam_tangents_mate)
# while the plateau end stays soft (test_outer_stacked_soft_at_plateau).
const UP_BAND := 1.4     # upper-tile seam band (outer)
const IN_BAND := 1.2     # inner-tile seam onset band
const IN_MIX  := 0.7     # inner: weight of the steep seam band vs the gentle far-corner tail

static func _top_s(u: float) -> float:
	return 2.0 * smootherstep(clampf(u, 0.0, 1.0) * 0.5)

static func _bot_s(u: float) -> float:
	return 2.0 * smootherstep(0.5 + clampf(u, 0.0, 1.0) * 0.5) - 1.0

# Linear progress (0..1, no flat shoulders) across the cell: 0 at +HALF, 1 at -HALF.
static func _lin(c: float) -> float:
	return clampf((HALF - c) / CELL, 0.0, 1.0)

# Per-axis ramp inside the UPPER tile's seam band: 1 AT the seam edge (c=-HALF),
# falling to 0 UP_BAND units away. Constant slope 1/UP_BAND -> non-zero (steep) at
# the seam corner where the plain `_ramp` would have been flat.
static func _up_band(c: float) -> float:
	return clampf((-HALF + UP_BAND - c) / UP_BAND, 0.0, 1.0)

# Per-axis ramp inside the INNER tile's seam band: 1 AT the seam edge (c=+HALF),
# falling to 0 IN_BAND units away.
static func _in_band(c: float) -> float:
	return clampf((HALF - c) / IN_BAND, 0.0, 1.0)

# Repurposed (2026-06-21): the 2-STOREY diagonal-ramp corner. Where a convex
# corner column sits two storeys above a diagonal pit (the cardinal clamp forces
# the two adjoining cardinals to exactly one storey between, and a diagonal drop
# can never exceed two), a single 1-storey corner tile cannot reach the pit floor
# — it bottoms out a storey up, leaving a sheer drop into the pit. This profile
# descends BOTH storeys across the corner's open diagonal as the SUM of the two
# per-axis edge ramps:
#   * along each cardinal edge-seam one ramp is 0 (b=_ramp(+HALF)=0 at the +x
#     seam, a=0 at the +z seam), so it reduces to exactly the plain `edge`
#     profile -> it mates continuously with the 1-storey sloping neighbour there;
#   * at the open-diagonal vertex (a=b=1) it reaches 2*BOTTOM = the pit floor.
# Replaces the old convex-top + understacked concave-bottom pair (which stacked
# the two halves vertically, so the lower half sat *under* the walkable surface
# instead of continuing the descent — see HeightfieldInstantiator).
static func outer_corner_stacked_height(x: float, z: float) -> float:
	return BOTTOM * (_ramp(z) + _ramp(x))

# Inner (concave) LOWER tile: only the far (-,-) corner dips. The onset coordinate q
# mixes the steep seam-band progress (`seam`, which has a non-zero slope right at the
# +,+ seam corner) with the gentle far-corner tail (`base`); q runs through _bot_s,
# whose inflection sits at the seam so the top tangent matches the upper tile's bottom
# tangent (C1). Both `seam` and `base` vanish at the x=+HALF (or z=+HALF) edge-seam,
# so q->0 and _bot_s(0)=0 keeps the edge-seams flat (test_inner_stacked_edge_seam_is_flat).
# At the far corner seam=base=1 so q=1 and _bot_s(1)=1 -> full -HEIGHT drop.
static func inner_corner_stacked_height(x: float, z: float) -> float:
	var base := minf(_lin(z), _lin(x))           # 0 at +,+ seam ; 1 at -,- ground
	if base <= 0.0:
		return 0.0
	var seam := minf(_in_band(z), _in_band(x))   # steep onset right at the seam corner
	var q := IN_MIX * seam + (1.0 - IN_MIX) * base
	return BOTTOM * _bot_s(q)

# --- assembled-tile surface height -----------------------------------------
# Walkable surface height at tile-local (x,z) for a variant's cell layout (from
# SlopeVariantLayout.layout / stacked_layout*). The baker uses this to drop the
# top-surface decoration sockets onto the slope so attached decorations rest on
# the ground instead of floating at the old flat y=0. Cells are 12u wide centered
# at +/-HALF; the four cells meet at the seams, where adjacent profiles agree
# (continuity), so the half-plane pick below is unambiguous in effect.
static func surface_height(cells: Array, x: float, z: float) -> float:
	var cx := -HALF if x < 0.0 else HALF
	var cz := -HALF if z < 0.0 else HALF
	for cell in cells:
		if is_equal_approx(cell.x, cx) and is_equal_approx(cell.z, cz):
			# tile-local -> cell-local -> un-rotate into the component's canonical frame
			var local := Basis(Vector3.UP, -deg_to_rad(cell.angle_deg)) * Vector3(x - cell.x, 0.0, z - cell.z)
			return _component_height(String(cell.component), local.x, local.z)
	return 0.0

static func _component_height(component: String, x: float, z: float) -> float:
	match component:
		"edge": return edge_height(x, z)
		"outer": return outer_corner_height(x, z)
		"inner": return inner_corner_height(x, z)
		"outer_stacked": return outer_corner_stacked_height(x, z)
		"inner_stacked": return inner_corner_stacked_height(x, z)
		_: return 0.0   # "top" (flat plateau) and anything unknown stay at y=0
