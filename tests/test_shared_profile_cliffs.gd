extends GutTest
const Region := preload("res://tests/fixtures/tile_point_region.gd")
var saved_mode: int

func before_each() -> void:
	saved_mode = TerrainTileField.cliff_end
	TerrainTileField.cliff_end = TerrainTileField.CliffEnd.SHARED_PROFILE

func after_each() -> void:
	TerrainTileField.cliff_end = saved_mode

func test_rounded_cliff_keeps_semantic_shoulder_and_foot_lines() -> void:
	var heights := {}
	for z in range(-4,5):
		for x in range(-4,5): heights[Vector2i(x,z)] = 12.0 if x<=0 else 0.0
	var region := Region.new(heights)
	assert_eq(TerrainTileField.surface_y_on_side(region,6,0,Vector2i.ZERO),TerrainTileField.surface_y_on_side(region,6,0,Vector2i.RIGHT),"the actual terrain has no discontinuity")
	assert_true(TerrainTileField.wall_segments(region,Rect2(1,-5,10,10)).is_empty(),"grass and terrain meshing still see no vertical wall")
	var walls := TerrainTileField.wall_segments(region,Rect2(1,-5,10,10),true)
	assert_eq(walls.size(),2)
	for wall: Dictionary in walls:
		assert_eq(wall.sample_offset,6.0)
		assert_eq(wall.top,Vector2(12,12))
		assert_eq(wall.bottom,Vector2.ZERO)
		assert_eq(wall.normal,Vector2.RIGHT)

func test_ordinary_slope_does_not_acquire_a_cliff_foot_line() -> void:
	var heights := {}
	for z in range(-4,5):
		for x in range(-4,5): heights[Vector2i(x,z)] = 4.0 if x<=0 else 0.0
	assert_true(TerrainTileField.wall_segments(Region.new(heights),Rect2(1,-5,10,10),true).is_empty())

func test_shared_bedrock_preserves_slopes_and_wet_ground() -> void:
	const E = preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
	const N = preload("res://scripts/native/NativeCliffEnvelope.gd")
	for rise in [4.0,24.0]:
		var ground := func(q:Vector2)->float:return rise*SlopeProfile.smootherstep(clampf((q.x+6.0)/12.0,0.0,1.0))
		var dry = E._build(N.window(Vector2.ZERO,14),ground,Callable(),99,Callable(),Callable(),Callable(),true,1)
		var wet = E._build(N.window(Vector2.ZERO,14),ground,Callable(),99,func(_q:Vector2)->float:return 30.0,Callable(),Callable(),true,1)
		assert_eq(wet.surface,wet.ground,"submerged geometry stays exact")
		assert_eq(wet.rock.count(0.0),wet.rock.size())
		if rise==4.0:
			assert_eq(dry.surface,dry.ground,"ordinary slope stays exact")
			assert_eq(dry.rock.count(0.0),dry.rock.size())
		else:
			assert_gt(Array(dry.rock).max(),0.0,"steep faces carry exposed rock")
			var bounded := true
			for i in dry.surface.size():
				bounded = bounded and dry.surface[i]>=dry.ground[i] and dry.surface[i]<=dry.ground[i]+.3
			assert_true(bounded,"bedrock cannot dig a trench or raise a large shoulder")
