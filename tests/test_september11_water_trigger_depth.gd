extends GutTest

class DryWater extends WaterPlan:
	func river_for(_cell:Vector2i,_depth:int=2,_start:float=-1,_end:float=-1)->RiverTrace: return null

func test_buried_water_rims_do_not_create_inverted_swimming_volumes() -> void:
	var water:=DryWater.new(17,128,32)
	var plan:=HeightfieldPlan.new(17,128,32,"mean",3)
	plan.set_raw_height_override(func(_x:int,_z:int)->float:return 12.0)
	var region:=plan.compute_region(4,4,26)
	var context:=WaterField.ctx(water,Vector2i.ZERO,region)
	var state:={"region":region,"ctx":context,"verts":PackedVector3Array([Vector3(12,0,12)]),
		"rect":Rect2(Vector2.ZERO,Vector2.ONE*WaterField.CHUNK)}
	assert_eq(WaterSkin._triggers(state).size(),0,"A buried cap has no positive water volume above its ground")
	state.verts=PackedVector3Array([Vector3(12,15,12)])
	var wet:=WaterSkin._triggers(state)
	assert_eq(wet.size(),1)
	assert_gt(wet[0].top,wet[0].bottom)
