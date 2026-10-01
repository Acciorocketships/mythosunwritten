extends RefCounted

## Retain the actual September 9–10 input geography after the requested
## biome redesign. Hydraulic algorithms remain the current production code;
## these fixed photographs must still exercise their original wet ledges.
const Source := preload("res://tests/fixtures/september11/landforms/HeightSourceBefore.gd")

class PhotoWater extends WaterPlan:
	func smooth01(point: Vector2) -> float:
		return Source.height01(Vector3(point.x,0,point.y),world_seed,false)
	func noise_h(point: Vector2) -> float:
		return Source.height01(Vector3(point.x,0,point.y),world_seed,true)*amplitude
	func _shape_alluvial_reach(_trace: RiverTrace) -> void: pass
	func _fit_terminal_land(_trace: RiverTrace) -> void: pass

static func make_water(seed_value: int) -> WaterPlan:
	return PhotoWater.new(seed_value,32,8)

static func make_heightfield(seed_value: int,water: WaterPlan=null) -> HeightfieldPlan:
	var plan:=HeightfieldPlan.new(seed_value,32,8,"mean",3)
	# The override is keyed by 12 m terrain points (HeightfieldPlan.POINT): the
	# frozen continuous field is sampled at every dual-grid lattice point, so
	# the ground stays under the water plan's world-space rivers.
	plan.set_raw_height_override(func(i: int,j: int)->float:
		return Source.height01(Vector3(i*HeightfieldPlan.POINT,0,j*HeightfieldPlan.POINT),seed_value,true)*32.0)
	if water!=null: plan.set_water_plan(water)
	return plan
