extends WaterPlan

var trace: RiverTrace

func _init(shaped := true) -> void:
	super._init(17,128,32)
	trace=RiverTrace.new()
	trace.source_cell=Vector2i(1,1)
	for i in 61:
		trace.points.append(Vector2(1008+i*12,1008))
		trace.beds.append(2.5)
		trace.widths.append(22.0)
	if shaped: _shape_alluvial_reach(trace)
	trace.pond=PondStamp.new(trace.points[-1],70,17,2,3.5)
	trace.pond.surface_ceiling=4.0

func noise_h(_point: Vector2) -> float: return 12.0
func _alluvial_wetness(_point: Vector2) -> float: return 1.0
func river_for(cell: Vector2i,_depth: int=2,_start: float=-1,_end: float=-1) -> RiverTrace:
	return trace if cell==Vector2i(1,1) else null

func heightfield() -> HeightfieldPlan:
	var result := HeightfieldPlan.new(17,128,32,"mean",3)
	result.set_raw_height_override(func(_x: int,_z: int)->float: return 12.0)
	result.set_water_plan(self)
	return result
