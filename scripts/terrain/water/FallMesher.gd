# True waterfalls (>4m only): a swept ogee from the sheet's own lip contour.
# Lip vertices arrive from WaterMesher's cut records — the SAME Vector3s the
# sheet uses, so crest continuity is data flow, not float matching. The lip
# polyline is a waterline contour: its ends already bend into the banks, so
# the swept sides wrap into the ground; the bottom dives 0.5m below the
# plunge surface so the visible intersection is submerged under the churn.
class_name FallMesher
extends Object

# --- copied verbatim from the retired WaterSurfaceBuilder ---------------
const FALL_REACH := 0.35
const FALL_REACH_MIN := 1.5
const FALL_REACH_MAX := 6.0
const FALL_PAR_ROWS := 5         # accelerating-curve segments of the curtain
const FALL_FILLET_ROWS := 5      # circular ease-out segments at the plunge
const FALL_OVERLAP := 1.1        # upstream embed under the upper sheet
const FALL_BEND_SLOPE := 4.0     # world slope where the plunge arc takes over
const CREST_DROOP := 0.32        # sheet droop depth right at a curtained edge
const CREST_DROOP_RANGE := 3.0   # droop begins this far inside the cell


## The fall's downstream curve shared by fall_rows and fall_x_end: an
## accelerating quadratic leaving the drooped crest edge at slope s0, handed
## to a circular arc at FALL_BEND_SLOPE that flattens into the plunge.
static func _fall_curve(top: float, bottom: float) -> Dictionary:
	var h: float = maxf(top - bottom, 0.5)
	var reach: float = clampf(h * FALL_REACH, FALL_REACH_MIN, FALL_REACH_MAX)
	var y0: float = top - CREST_DROOP
	var s0: float = 2.0 * CREST_DROOP / CREST_DROOP_RANGE
	var h_eff: float = maxf(y0 - bottom, 0.4)
	var c: float = h_eff / (reach * reach)
	var x_star: float = minf((FALL_BEND_SLOPE - s0) / (2.0 * c), 0.97 * reach)
	# Never let the quadratic dive under the plunge before the arc takes over.
	var x_floor: float = (-s0 + sqrt(s0 * s0 + 4.0 * c * maxf(h_eff - 0.2, 0.1))) \
		/ (2.0 * c)
	x_star = minf(x_star, x_floor)
	var y_star: float = y0 - s0 * x_star - c * x_star * x_star
	var slope_star: float = s0 + 2.0 * c * x_star
	var th0: float = atan(slope_star)
	var arc_r: float = maxf(y_star - bottom, 0.02) / maxf(1.0 - cos(th0), 0.02)
	return {"y0": y0, "s0": s0, "c": c, "x_star": x_star, "y_star": y_star,
		"th0": th0, "arc_r": arc_r, "x_end": x_star + arc_r * sin(th0)}
# -------------------------------------------------------------------------


static func build(cuts: Array, _region) -> ArrayMesh:
	if cuts.is_empty():
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for rec: Dictionary in cuts:
		if rec.lip.size() >= 2:
			_sweep(st, rec, _region)
			any = true
	if not any:
		return null
	st.generate_normals()
	return st.commit()


static func _sweep(st: SurfaceTool, rec: Dictionary, _region) -> void:
	var cut: Dictionary = rec.cut
	var drop_h: float = maxf(cut.top - cut.bottom, 0.5)
	var cv: Dictionary = _fall_curve(cut.top, cut.bottom)
	var rows: Array = _rows(cv, cut, drop_h)   # [[along, y_below_lip, uv_y], ...]
	var thick: float = clampf(drop_h * 0.10, 0.4, 1.2)
	var cols: Array = []
	for v: Vector3 in rec.lip:
		var fcol: Array = []
		for row: Array in rows:
			fcol.append(Vector3(v.x + cut.dir.x * row[0], v.y - row[1],
				v.z + cut.dir.y * row[0]))
		cols.append(fcol)
	for ci in cols.size() - 1:
		var ux0: float = float(ci) / float(cols.size() - 1)
		var ux1: float = float(ci + 1) / float(cols.size() - 1)
		for ri in rows.size() - 1:
			_quad(st, [cols[ci][ri], cols[ci + 1][ri],
				cols[ci + 1][ri + 1], cols[ci][ri + 1]],
				[rows[ri][2], rows[ri][2], rows[ri + 1][2], rows[ri + 1][2]],
				[ux0, ux1, ux1, ux0], 0.0, drop_h)
		# Back sheet: offset upstream by `thick` along -dir, same rows.
		for ri in rows.size() - 1:
			var o := Vector3(-cut.dir.x, 0.0, -cut.dir.y) * thick
			_quad(st, [cols[ci][ri] + o, cols[ci][ri + 1] + o,
				cols[ci + 1][ri + 1] + o, cols[ci + 1][ri] + o],
				[rows[ri][2], rows[ri + 1][2], rows[ri + 1][2], rows[ri][2]],
				[ux0, ux0, ux1, ux1], 0.0, drop_h)
	# Lip cap between front row 0 and back row 0 (UV2.x = 1 marks it).
	for ci in cols.size() - 1:
		var o := Vector3(-cut.dir.x, 0.0, -cut.dir.y) * thick
		_quad(st, [cols[ci][0], cols[ci][0] + o,
			cols[ci + 1][0] + o, cols[ci + 1][0]],
			[0.0, 0.0, 0.0, 0.0],
			[float(ci) / float(cols.size() - 1), 0.0, 1.0, 1.0], 1.0, drop_h)


## rows are [along, y_below_lip, uv_y]; y_below_lip is measured from the LIP
## vertex's own y (== cut.top, per _sweep — FallMesher has no crest-droop
## pass of its own, so the lip it welds to sits exactly at cut.top, unlike
## the retired WaterSurfaceBuilder's own drooped sheet). The parabola/fillet
## rows use cv.y0 - y (NOT cut.top - y): at x=0 that is exactly 0, welding
## row 1 to the lip vertex bit-identically
## (test_falls_weld_to_lip_and_dive_under_the_pool) — cv.y0 is the curve's
## OWN origin, so an offset measured from it is what stays 0 at the crest.
## Deviation from the brief: its literal last row `cv.y0 - (cut.bottom -
## 0.5)` reused that same y0-relative convention, but the runout target
## bottom - 0.5 is an ABSOLUTE y (see WaterSurfaceBuilder.fall_rows' own
## runout rows, which place it straight in world space) — left as
## `cv.y0 - ...` the runout lands CREST_DROOP (0.32m) short, only
## bottom - 0.18, missing the "dives under bottom - 0.3" assertion. Fixed
## to measure from cut.top like every other absolute-position use here.
static func _rows(cv: Dictionary, cut: Dictionary, drop_h: float) -> Array:
	var rows: Array = []
	rows.append([-FALL_OVERLAP, 0.03, 0.0])
	for i in FALL_PAR_ROWS + 1:
		var x: float = cv.x_star * float(i) / float(FALL_PAR_ROWS)
		var y: float = cv.y0 - cv.s0 * x - cv.c * x * x
		rows.append([x, cv.y0 - y, (cut.top - y) / drop_h])
	for jj in range(1, FALL_FILLET_ROWS + 1):
		var th: float = cv.th0 * (1.0 - float(jj) / float(FALL_FILLET_ROWS))
		var x: float = cv.x_star + cv.arc_r * (sin(cv.th0) - sin(th))
		var y: float = cv.y_star - cv.arc_r * (cos(th) - cos(cv.th0))
		rows.append([x, cv.y0 - y, (cut.top - y) / drop_h])
	rows.append([cv.x_end + 1.6, cut.top - (cut.bottom - 0.5), 1.05])
	return rows


static func _quad(st: SurfaceTool, vs: Array, uv_y: Array, uv_x: Array,
		side: float, drop_h: float) -> void:
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_uv(Vector2(uv_x[k], uv_y[k]))
		st.set_uv2(Vector2(side, drop_h))
		st.add_vertex(vs[k])
