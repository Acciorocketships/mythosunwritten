extends GutTest

func test_a_village_grade_selects_native_tiles_before_surface_reconstruction() -> void:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-4,5):
		for x in range(-4,5):
			storeys[Vector2i(x,z)] = 6 if x <= 0 else 3
			levels[Vector2i(x,z)] = 0
	var natural := HeightfieldRegion.new(storeys,levels)
	var claims: Dictionary = {}
	for z in range(-3,4):
		for x in range(-3,2): claims[Vector2i(x,z)] = 20.0
	var graded := natural.with_terrain_grades([
		TerrainGradePatch.new(&"cliff_frontage",claims,Vector2.ZERO,3.0)])
	# The pad (world x -10.5..4.5) owns points -1..1; point 1 is filled up to
	# the pad and now stands two storeys over natural point 2: a cliff crown.
	# A fine construction collar cannot bend that crown down one side.
	assert_true(TerrainTileField.is_wall_edge(graded,Vector2i(1,0),Vector2i.RIGHT))
	var crown := graded.surface_height(1,0)
	var spread := 0.0
	for z: float in [-5.5,0.0,5.5]:
		for x: float in [6.5,12.0,17.5]:
			spread=maxf(spread,absf(TerrainTileField.surface_y_on_side(graded,x,z,Vector2i(1,0))-crown))
	assert_lt(spread,.00001,"A selected cliff crown must remain flat, including its outer corner quadrants")

func test_reported_native_ground_keeps_full_claimed_footprints_supported() -> void:
	for spot: String in ["P07","P08","P09"]:
		var original := preload("res://tests/fixtures/frozen_terrain_grade.gd").region(
			"res://docs/qa/2026-09-15-manual/01-grass/%s-field.txt"%spot)
		var native := original.without_terrain_grades().with_terrain_grades(original.terrain_grades)
		var largest_error := 0.0
		for grade: TerrainGradePatch in original.terrain_grades:
			for cell: Vector2i in grade._claims:
				for offset: Vector2 in [Vector2.ZERO,Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]:
					var point := grade._origin+(Vector2(cell)+offset*.499)*grade._targets.pitch
					largest_error=maxf(largest_error,absf(TerrainTileField.surface_y(native,point.x,point.y)-grade._claims[cell]))
		assert_lt(largest_error,.00001,spot+" entire reserved ground must retain its construction datum")
		var crown_spread := 0.0
		# Per edge (September 27): a native cliff crown holds its height along
		# each cliff side; its one-storey sides are ordinary slopes. Since
		# September 29 a cliff ending in a hillside also keeps its crown at
		# the edge midpoint (no special fade profile).
		for cell: Vector2i in native.native_control_heights:
			for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				if not TerrainTileField.is_wall_edge(native,cell,d): continue
				var point := Vector2(cell)*HeightfieldPlan.POINT+Vector2(d)*5.5
				crown_spread=maxf(crown_spread,absf(TerrainTileField.surface_y_on_side(native,point.x,point.y,cell)-native.surface_height(cell.x,cell.y)))
		assert_lt(crown_spread,.00001,spot+" native cliff crowns remain horizontal along their cliff sides")
		var copied := GrassSamplingContext._copy_region(native,{})
		assert_eq(copied.native_control_heights,native.native_control_heights,"grass and terrain share completed native controls")

func test_native_grades_keep_fractional_foundation_datums() -> void:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-4,5):
		for x in range(-4,5):
			storeys[Vector2i(x,z)] = 1
			levels[Vector2i(x,z)] = 0
	var original := HeightfieldRegion.new(storeys,levels)
	var grade := TerrainGradePatch.new(&"fractional",{Vector2i.ZERO:5.08},Vector2.ZERO,3)
	var native := original.with_terrain_grades([grade])
	assert_almost_eq(TerrainTileField.surface_y(native,0,0),5.08,.00001)
	assert_eq(original.surface_height(0,0),4.0,"ordinary source planning is immutable")

func test_native_grade_is_independent_of_query_window_and_order() -> void:
	var plan := HeightfieldPlan.new(2697992464,32,8)
	plan.set_raw_height_override(func(x:int,z:int)->float: return 24.0 if x<0 else (12.0 if z<0 else 16.0))
	var claims:Dictionary={}
	for z in range(-3,4):
		for x in range(-4,5): claims[Vector2i(x,z)]=20.0
	var first:=TerrainGradePatch.new(&"window",claims,Vector2(-9,-3),3)
	var second:=TerrainGradePatch.new(&"window",claims,Vector2(-9,-3),3)
	var west:=plan.compute_region(-3,0,4)
	var east:=plan.compute_region(3,0,4)
	var a:=west.with_terrain_grades([first])
	var b:=east.with_terrain_grades([first])
	var c:=east.with_terrain_grades([second])
	var d:=west.with_terrain_grades([second])
	assert_eq(a.native_control_heights,b.native_control_heights)
	assert_eq(a.native_control_heights,c.native_control_heights)
	assert_eq(a.native_control_heights,d.native_control_heights)
	var seam_error:=0.0
	for z in range(-36,37):
		seam_error=maxf(seam_error,absf(TerrainTileField.surface_y(a,12,z)-TerrainTileField.surface_y(b,12,z)))
	assert_lt(seam_error,.00001,"both query owners reconstruct identical boundary heights")

func test_continuous_road_samples_do_not_become_fixed_native_pads() -> void:
	var source := TerrainGradePatch.new(&"road",{Vector2i.ZERO:11.0},Vector2.ZERO,3)
	var inherited := source.with_continuous_extension({Vector2i.ZERO:11.0,Vector2i(2,0):10.1,Vector2i(5,0):8.0},8)
	var next := inherited.with_fixed_extension({Vector2i.ZERO:11.0,Vector2i(2,0):10.1,Vector2i(5,0):8.0,Vector2i(9,2):8.0})
	assert_eq(preload("res://scripts/terrain/field/NativeTerrainGrade.gd").fixed_claims(next),{Vector2i.ZERO:11.0,Vector2i(9,2):8.0},"only the house/pad owns a fixed elevation; inherited street samples keep their source semantics")

class OneSite extends SettlementPlan:
	func site_for(cell: Vector2i) -> Dictionary:
		return {"id":&"native.edge","cell":Vector2i.ZERO} if cell==Vector2i.ZERO else {}

func test_record_discovery_includes_native_controls_beyond_building_bounds() -> void:
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	program.villages.layout_record_radius=24
	program.villages.max_record_radius=24
	program.record_discovery_radius=24
	program.maximum_clearance=0
	var water := WaterPlan.new(1,1,1)
	var fields := WorldFieldBlockCache.new(HeightfieldPlan.new(1,32,8),water,program.query_margin,program.shore_distance_limit,program.field_cache_cap)
	var world := WorldFeaturePlan.new(1,water,fields,program,OneSite.new(1,water))
	var frame := VillageFrame.new()
	frame.settlement_id=&"native.edge"
	frame.centre=Vector2.ZERO
	world._frames[Vector2i.ZERO]=frame
	var record := VillageRecord.new(frame.settlement_id,Vector2.ZERO,Rect2(-72,-72,144,144),EnvironmentInstancePayload.new(),[],[],[])
	world._villages._records[frame.settlement_id]=record
	assert_eq(world._records_affecting(Rect2(60,-1,2,2)),[record],"a neighbouring chunk must find the terrain owner even when no building intersects it")
	assert_eq(world._records_affecting(Rect2(74,-1,2,2)),[],"complete record bounds still terminate the influence")


## Dual-grid terrain (September 30): a town grade writes per-POINT controls on
## the 12 m lattice, and every tile's surface depends on all four of its
## corners. A flat foundation pad is therefore flat at every point inside it
## only if every corner of every tile it touches holds its datum, including the
## odd points no 24 m cell centre touches. Sampled at 1 m over the whole pad.
static func _hillside() -> HeightfieldRegion:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-12, 13):
		for x in range(-12, 13):
			# A rising hillside (1 m per point in x, 1 m per two points in z):
			# the pad cuts into it on one side and fills on the other.
			var h := 20 + x + int(floor(z * 0.5))
			storeys[Vector2i(x, z)] = floori(h / 4.0)
			levels[Vector2i(x, z)] = posmod(h, 4)
	return HeightfieldRegion.new(storeys, levels)

static func _pad_variation(graded: HeightfieldRegion, grade: TerrainGradePatch) -> float:
	var worst := 0.0
	for cell: Vector2i in grade._claims:
		var datum := float(grade._claims[cell])
		var low: Vector2 = grade._origin + (Vector2(cell) - Vector2.ONE * 0.5) * grade._targets.pitch
		for dz in int(grade._targets.pitch) + 1:
			for dx in int(grade._targets.pitch) + 1:
				var p := low + Vector2(dx, dz)
				worst = maxf(worst, absf(TerrainTileField.surface_y(graded, p.x, p.y) - datum))
	return worst

func test_a_flat_pad_is_flat_at_every_point_inside_it() -> void:
	var natural := _hillside()
	# Pads straddling odd and even points, off the lattice phase, on cut and fill.
	for origin: Vector2 in [Vector2(5, -7), Vector2(-22, 13), Vector2(-3, 1)]:
		# The datum is the natural height at the pad's centre: the tiles it
		# touches hold corners both above (cut) and below (fill) that datum.
		var centre := origin + Vector2(1.5, 1.0) * 4.0
		var datum := natural.surface_height(roundi(centre.x / 12.0), roundi(centre.y / 12.0))
		var claims: Dictionary = {}
		for z in range(0, 3):
			for x in range(0, 4):
				claims[Vector2i(x, z)] = datum
		var grade := TerrainGradePatch.new(&"pad", claims, origin, 4.0)
		var graded := natural.with_terrain_grades([grade] as Array[TerrainGradePatch])
		assert_eq(_pad_variation(graded, grade), 0.0,
			"the pad at %s is flat at its datum at every 1 m sample" % origin)

func test_two_separate_pads_at_different_datums_are_each_flat() -> void:
	var natural := _hillside()
	var claims: Dictionary = {}
	for z in range(0, 3):
		for x in range(0, 3):
			claims[Vector2i(x, z)] = 18.0
			claims[Vector2i(x + 12, z)] = 26.0   # 48 m east, two storeys higher
	var grade := TerrainGradePatch.new(&"two.pads", claims, Vector2(-30, -5), 4.0)
	var graded := natural.with_terrain_grades([grade] as Array[TerrainGradePatch])
	assert_eq(_pad_variation(graded, grade), 0.0, "each pad keeps its own datum")


## The mixed-datum contract (review probe, September 30): one 12 m tile cannot
## hold two datums, so where two pads share a tile corner the LOWER datum owns
## it. The higher pad then ramps (one storey) or steps (a cliff at the tile
## midline) toward the lower datum inside itself, and the patch's height_bounds
## (its target) still reports it flat. What always holds: inside any pad the
## native ground never rises above that pad's datum (no pad is buried), and the
## lowest pad of a cluster is flat.
static func _flat_ground(storey: int) -> HeightfieldRegion:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-10, 11):
		for x in range(-10, 11):
			storeys[Vector2i(x, z)] = storey
			levels[Vector2i(x, z)] = 0
	return HeightfieldRegion.new(storeys, levels)

## Worst excess of the native ground over each claim's datum, and the
## variation over the claims at `flat_datum`, sampled at 1 m inside each square.
static func _pad_extrema(graded: HeightfieldRegion, grade: TerrainGradePatch,
		flat_datum: float) -> Vector2:
	var above := 0.0
	var variation := 0.0
	for cell: Vector2i in grade._claims:
		var datum := float(grade._claims[cell])
		var low: Vector2 = grade._origin + (Vector2(cell) - Vector2.ONE * 0.5) * grade._targets.pitch
		for dz in int(grade._targets.pitch) + 1:
			for dx in int(grade._targets.pitch) + 1:
				var p := low + Vector2(dx, dz)
				var y := TerrainTileField.surface_y(graded, p.x, p.y)
				above = maxf(above, y - datum)
				if datum == flat_datum:
					variation = maxf(variation, absf(y - datum))
	return Vector2(above, variation)

func test_mixed_datum_pads_never_bury_a_pad_and_keep_the_lowest_flat() -> void:
	var natural := _flat_ground(4)   # flat 16 m ground
	# Low pad at 12 m on world x [-2, 10]; high pad adjacent ([10, 22]) at 15 m
	# (a one-storey ramp inside it) or 21 m (a cliff inside it), or 8 m away
	# ([18, 30]) at 15 m. Every case shares 12 m tile corners with the low pad.
	var cases := [[3, 15.0], [3, 21.0], [5, 15.0]]
	for case: Array in cases:
		var claims: Dictionary = {}
		for z in range(-2, 3):
			for x in range(0, 3):
				claims[Vector2i(x, z)] = 12.0
				claims[Vector2i(int(case[0]) + x, z)] = float(case[1])
		var grade := TerrainGradePatch.new(&"mixed", claims, Vector2.ZERO, 4.0)
		var graded := natural.with_terrain_grades([grade] as Array[TerrainGradePatch])
		var extrema := _pad_extrema(graded, grade, 12.0)
		assert_lte(extrema.x, 0.00001,
			"high pad from fine x %d at %.0f m: no pad's native ground rises above its datum" % case)
		assert_eq(extrema.y, 0.0, "the lowest pad (12 m) is flat at every 1 m sample")
		# The documented limit: the high pad is NOT flat on its native ground,
		# although the patch target (height_bounds) reports it flat.
		var high_low := INF
		for cell: Vector2i in claims:
			if float(claims[cell]) == 12.0: continue
			var p := Vector2(cell) * 4.0
			for dx: float in [-2.0, 0.0, 1.999]:
				high_low = minf(high_low, TerrainTileField.surface_y(graded, p.x + dx, p.y))
		assert_lt(high_low, float(case[1]) - 0.5, "the high pad dips toward the lower datum")
		# The middle high claim: its whole target neighbourhood is at its datum.
		var middle_high := Vector2(int(case[0]) + 1, 0) * 4.0
		assert_eq(grade.height_bounds(Rect2(middle_high - Vector2.ONE * 2.0, Vector2.ONE * 4.0),
			Vector2(16, 16)), Vector2(case[1], case[1]), "while the patch target reports it flat")
