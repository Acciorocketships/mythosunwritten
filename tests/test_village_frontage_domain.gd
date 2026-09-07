extends GutTest

func test_frontage_subtracts_the_whole_house_footprint_in_both_directions() -> void:
	var intervals: Array[Vector2] = [Vector2(-20,20)]
	var house := Rect2(Vector2(-3,2),Vector2(6,8))
	var blockers: Array[Rect2] = [Rect2(Vector2(-2,4),Vector2(4,2))]
	for tangent: Vector2 in [Vector2.RIGHT,Vector2.LEFT]:
		var free := VillageFrontageDomain.subtract_obstacles(intervals,Vector2.ZERO,tangent,house,blockers,0.0)
		assert_eq(free,[Vector2(-20,-5),Vector2(5,20)] as Array[Vector2])
		for interval: Vector2 in free:
			for fraction: float in [0.0,0.25,0.5,0.75,1.0]:
				var placed := house
				placed.position += tangent * lerpf(interval.x,interval.y,fraction)
				assert_false(placed.intersects(blockers[0]),"every coordinate in the domain is free")

func test_allocation_constructs_disjoint_lots_without_placement_trials() -> void:
	var domains: Array[Dictionary] = []
	for row in 2:
		domains.append({"id":"row.%d" % row,"group":row,"origin":Vector2(0,row*20),
			"tangent":Vector2.RIGHT,"bounds":Rect2(Vector2(-3,2),Vector2(6,8)),
			"area":48.0,"intervals":[Vector2(-30,30)] as Array[Vector2]})
	var lots := VillageFrontageDomain.allocate(domains,8,123)
	assert_eq(lots.size(),8)
	assert_eq(lots,VillageFrontageDomain.allocate(domains,8,123))
	for i in lots.size():
		for j in range(i+1,lots.size()):
			assert_false((lots[i].world_bounds as Rect2).intersects(lots[j].world_bounds))
	assert_eq(domains[0].intervals,[Vector2(-30,30)] as Array[Vector2],"input domains are immutable")
