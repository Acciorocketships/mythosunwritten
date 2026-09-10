extends GutTest

class BasinWater extends WaterPlan:
	var pond: PondStamp
	func _init(level := 1) -> void:
		super(123, 32, 8)
		pond = PondStamp.new(Vector2(96,96), 500, 7, level, 3.5)
	func bodies_near(_center: Vector2i, _radius: int) -> Dictionary:
		return {"ponds": [pond], "rivers": []}

func _flat() -> HeightfieldRegion:
	var values := {}
	for z in range(-16,25):
		for x in range(-16,25): values[Vector2i(x,z)] = 0
	return HeightfieldRegion.new(values,values)

func test_submerged_chunk_renders_even_when_its_shore_is_outside_the_chunk() -> void:
	var water := BasinWater.new()
	var region := _flat()
	var ctx := WaterField.ctx(water,Vector2i.ZERO,region)
	assert_true(WaterField.wet(ctx,region,Vector2(96,96)))
	assert_true(WaterContour.curves(ctx,Rect2(0,0,192,192)).is_empty())
	var skin := WaterSkin.build(water,Vector2i.ZERO,region)
	assert_false(skin.is_empty(), "fully wet chunks must not become rectangular holes")
	if skin.is_empty(): return
	var vertices: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	var bounds := AABB(vertices[0],Vector3.ZERO)
	for vertex in vertices: bounds = bounds.expand(vertex)
	assert_eq(bounds.position.x,0.0)
	assert_eq(bounds.end.x,192.0)
	assert_eq(bounds.position.z,0.0)
	assert_eq(bounds.end.z,192.0)
	assert_gt(skin.arrays[Mesh.ARRAY_INDEX].size(),0)
	assert_false(skin.triggers.is_empty())

func test_dry_chunk_with_distant_water_stays_empty() -> void:
	assert_true(WaterSkin.build(BasinWater.new(0),Vector2i.ZERO,_flat()).is_empty())
