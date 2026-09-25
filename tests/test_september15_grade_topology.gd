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
	# A cliff tile must have one horizontal native crown. A fine construction
	# collar cannot bend that crown down one side after choosing its corner.
	assert_true(TerrainSurfaceField._is_cliff_top(graded,0,0))
	var crown := TerrainSurfaceField.surface_y_in_cell(graded,0,0,0,0)
	var spread := 0.0
	for z: float in [-10.5,0.0,10.5]:
		for x: float in [-10.5,0.0,10.5]:
			spread=maxf(spread,absf(TerrainSurfaceField.surface_y_in_cell(graded,x,z,0,0)-crown))
	assert_lt(spread,.00001,"A selected cliff crown must remain flat, including its standard outer corner")

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
					largest_error=maxf(largest_error,absf(TerrainSurfaceField.surface_y(native,point.x,point.y)-grade._claims[cell]))
		assert_lt(largest_error,.00001,spot+" entire reserved ground must retain its construction datum")
		var crown_spread := 0.0
		for cell: Vector2i in native.native_control_heights:
			if not TerrainSurfaceField._is_cliff_top(native,cell.x,cell.y): continue
			for offset: Vector2 in [Vector2(-10.5,-10.5),Vector2(-10.5,10.5),Vector2(10.5,-10.5),Vector2(10.5,10.5)]:
				var point := Vector2(cell)*24+offset
				crown_spread=maxf(crown_spread,absf(TerrainSurfaceField.surface_y_in_cell(native,point.x,point.y,cell.x,cell.y)-native.surface_height(cell.x,cell.y)))
		assert_lt(crown_spread,.00001,spot+" native cliff crowns and corners remain horizontal")
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
	assert_almost_eq(TerrainSurfaceField.surface_y(native,0,0),5.08,.00001)
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
		seam_error=maxf(seam_error,absf(TerrainSurfaceField.surface_y(a,12,z)-TerrainSurfaceField.surface_y(b,12,z)))
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
