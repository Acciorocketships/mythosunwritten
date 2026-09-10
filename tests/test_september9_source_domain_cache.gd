extends GutTest

class CountedPlan extends HeightfieldPlan:
	var builds := 0
	func compute_region(x:int,z:int,r:int)->HeightfieldRegion:
		builds += 1
		return super.compute_region(x,z,r)

class Inventory extends RefCounted:
	var ponds: Array = []
	func bodies_in_rect(_bounds:Rect2)->Dictionary:
		return {"rivers":[],"ponds":ponds}

func test_same_solve_domain_reuses_complete_inventory_across_local_source_lists()->void:
	var plan:=CountedPlan.new(281)
	# Retention requires a real enclosing rim; the cache key test must not
	# rely on an unsupported eight-metre head on an open flat.
	plan.set_raw_height_override(func(x:int,z:int)->float:return 12.0 if absi(x)>=3 or absi(z)>=3 else 0.0)
	var region:=plan.compute_region(0,0,1)
	var outer:=PondStamp.new(Vector2.ZERO,60,8,1,3)
	var inner:=PondStamp.new(Vector2.ZERO,5,9,1,3)
	var inventory:=Inventory.new()
	inventory.ponds=[outer,inner]
	plan.builds=0
	var a:=WaterField._source_fill({"water":inventory,"rivers":[],"ponds":[outer]},region)
	var b:=WaterField._source_fill({"water":inventory,"rivers":[],"ponds":[outer,inner]},region)
	assert_eq(a.base,b.base)
	assert_eq(a.size,b.size)
	assert_eq(a.levels,b.levels,"both solves already use the complete identical domain inventory")
	assert_eq(plan.builds,1,"a different initiating subset must not repeat the same full solve")
	var other:=Inventory.new()
	var different:=WaterField._source_fill({"water":other,"rivers":[],"ponds":[outer]},region)
	assert_eq(plan.builds,2,"a different water owner must retain an independent solve")
	assert_ne(different.levels,a.levels,"an empty independent inventory cannot inherit wet samples")
