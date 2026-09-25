extends RefCounted
## Share the photographed geography with current production hydraulics.
## New biome landforms move these ledges, so keep their original input field.
const Geography = preload("res://tests/fixtures/september11/landforms/PhotoGeography.gd")
static var _fields:WorldFieldBlockCache
static func get_fields()->WorldFieldBlockCache:
	if _fields==null:
		var water:=Geography.make_water(2697992464)
		var plan:=Geography.make_heightfield(2697992464,water)
		_fields=WorldFieldBlockCache.new(plan,water,0,0,64)
	return _fields
