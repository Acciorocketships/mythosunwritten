extends GutTest
const WIDTH=preload("res://tests/helpers/cliff_tread_width.gd")
const CRAGS = preload("res://scripts/terrain/field/CliffRockCrags.gd")

## Ledges are off by default for now (owner, September 24); these tests
## cover the ledge generator itself.
const _LEDGE_STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func before_all()->void:_LEDGE_STYLE.ledges=true
func after_all()->void:_LEDGE_STYLE.apply("chosen")

func test_photo_projections_keep_lower_bearing_and_tuck_beneath_crown() -> void:
	var path := OS.get_environment("STORY_BUTTRESS_GENERATOR")
	var generator: GDScript = CRAGS if path.is_empty() else load(path)
	var anchors: Array = FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin", FileAccess.READ).get_var()
	var recession := 0.0
	var crown_excess := 0.0
	var wide_area := 0.0
	for a: Array in anchors:
		var form: Dictionary = generator.make(a[0], a[1], a[2], 2697992464, null, a[3], a[4])[0]
		var columns: Dictionary = {}
		for p: Vector3 in form.faces:
			if p.z < -.4 or p.y < 0: continue
			if not columns.has(p.x): columns[p.x] = {}
			columns[p.x][p.y] = maxf(columns[p.x].get(p.y, -INF), p.z)
			if p.y > a[2] - .5:
				var u: float = a[0].origin.dot(a[0].basis.x) + p.x
				crown_excess = maxf(crown_excess, p.z - generator._native_depth(u, p.y))
		for column: Dictionary in columns.values():
			var heights: Array = column.keys(); heights.sort(); heights.reverse()
			var upper := -INF
			for y: float in heights:
				if y > a[2] - 1: continue
				recession = maxf(recession, upper - column[y])
				upper = maxf(upper, column[y])
		var widths:=WIDTH.at_vertices(form.green)
		for i in range(0, form.green.size(), 3):
			var tread:=WIDTH.triangle(form.green,i,widths)
			if tread>=1.5:
				wide_area+=(form.green[i+2]-form.green[i]).cross(form.green[i+1]-form.green[i]).length()*.5
	print("BUTTRESS_PHOTOS recession=", recession, " crown_excess=", crown_excess, " wide_tread_area=", wide_area)
	assert_lt(recession, .85, "Projected bodies need substantial lower bearing; retain only shallow recesses")
	assert_lt(crown_excess, .35, "Added rock must tuck into the native wall beneath the turf crown")
	assert_gt(wide_area, 80.0, "Restore occasional substantial shelves at least 1.5 metres deep")

func test_photographed_convex_projections_keep_lower_bearing() -> void:
	var path := OS.get_environment("STORY_BUTTRESS_CORNER")
	var generator: GDScript = preload("res://scripts/terrain/field/CliffCornerCrags.gd") if path.is_empty() else load(path)
	var rows: Array = FileAccess.open("res://tests/fixtures/september17/cliff-corners/photographed-rows.bin", FileAccess.READ).get_var()
	var recession := 0.0
	var columns_checked := 0
	for form: Dictionary in generator.formations(rows, 2697992464):
		var height: float = form.top - form.anchor.y
		var columns: Dictionary = {}
		for p: Vector3 in form.faces:
			if p.x <= -1.499 or p.z <= -1.499 or p.y < 0 or p.y > height - 1: continue
			var offset := Vector2(p.x+1.5, p.z+1.5)
			var radius := offset.length() - 1.5
			if radius < .7: continue
			# Every mapped source column has one fixed angle; snapping only
			# removes the builder's 0.1 mm coordinate rounding.
			var column := roundi(atan2(offset.x, offset.y) * 100.0)
			if not columns.has(column): columns[column] = {}
			columns[column][p.y] = maxf(columns[column].get(p.y, -INF), radius)
		for column: Dictionary in columns.values():
			var heights: Array = column.keys(); heights.sort(); heights.reverse()
			var upper := -INF
			for y: float in heights:
				recession = maxf(recession, upper - column[y])
				upper = maxf(upper, column[y])
			columns_checked += 1
	print("BUTTRESS_CORNERS recession=", recession, " columns=", columns_checked)
	assert_gt(columns_checked, 100, "Exercise actual rounded photo corners")
	assert_lt(recession, .85, "Convex turns must preserve the support beneath their projections too")
