extends "res://scripts/terrain/field/WorldFieldBlockCache.gd"
## Native review adapter for the isolated candidate. No production references.
const FIELD = preload("res://tests/fixtures/september19/hillside-mouth-contact/candidate_field.gd")
func water(key: Vector2i) -> WaterFieldContext:
	var entry := _entry(key)
	if entry.water != null:
		_touch(key,entry)
		return entry.water
	assert(_shore_limit==0,"This review adapter does not precompute shore curves")
	var r := region(key)
	entry=_entries[key]
	var field := WaterFieldContext.new()
	field._ctx=FIELD.ctx(_water_plan,key,r)
	field._region=r
	field._coverage=Rect2(Vector2(key)*BLOCK_WORLD,Vector2.ONE*BLOCK_WORLD).grow(_query_margin)
	field._shore_limit=_shore_limit
	entry.water=field
	_touch(key,entry)
	return field
