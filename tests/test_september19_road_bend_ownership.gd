extends GutTest
const ROUTER = preload("res://scripts/terrain/features/villages/VillageWarrenRoadConnections.gd")
const EVIDENCE = "res://docs/qa/2026-09-19-manual/107-town-road-corner/field.bin"

func test_p02_incoming_road_yields_to_the_complete_rounded_bend() -> void:
	var data: Dictionary = FileAccess.open(EVIDENCE,FileAccess.READ).get_var()
	var occupied := Rect2()
	for shape: Dictionary in data.shapes:
		if String(shape.stable_id).ends_with(".street-domain"):
			occupied = Rect2(shape._a-shape._half_extents,shape._half_extents*2).grow(-6)
	var ground := FeatureGroundField.new([],[],4.5,data.masks,data.nodes,data.priorities)
	var contacts: Array[VillageCirculationNode] = [VillageCirculationNode.new(&"entry",VillageCirculationNode.Kind.TERRAIN_CONTACT,Vector2(-1032,1082),9,&"town",Vector2.UP)]
	var topology := ROUTER.topology(occupied,contacts,ground,&"photo")
	assert_eq(topology.paths[0].points,data.roads[0].points,"The owned bend must preserve the accepted route")
	var shapes: Array[FeatureGroundShape] = [topology.domain]
	shapes.append_array(topology.get("handoff_domains",[]))
	var road := PathProgram.filleted_path_shapes(topology.paths[0].points,2,1,120,&"road")
	shapes.append_array(road)
	var field := ground.extended(shapes,[])
	assert_eq(field.surface_at(Vector2(-1057.8,1051.8)),FeatureGroundField.NATURAL,"The square spur outside the actual curved route must disappear")
	var excess := 0
	var missing := 0
	for z in range(10461,10521):
		for x in range(-10580,-10539):
			var p := Vector2(x,z)*.1
			var on_road := false
			for shape: FeatureGroundShape in road:
				if shape.contains(p): on_road = true
			var painted := field.surface_at(p)==FeatureGroundField.WORN_PATH
			if painted and not on_road: excess += 1
			if on_road and not painted: missing += 1
	assert_eq(excess,0,"No residual old lattice road may square off the rounded approach")
	assert_eq(missing,0,"The full new walking width must remain painted")

func test_handoff_ownership_rotates_without_erasing_other_exterior_roads() -> void:
	for quarter in 4:
		var angle := quarter * PI * .5
		var masks := {}
		masks[Vector2i(Vector2(-1,0).rotated(angle).round())] = 3 if quarter%2==0 else 12
		masks[Vector2i(Vector2(-2,0).rotated(angle).round())] = 3 if quarter%2==0 else 12
		masks[Vector2i(Vector2(-2,1).rotated(angle).round())] = 3 if quarter%2==0 else 12
		var ground := FeatureGroundField.new([],[],4.5,masks)
		var contacts: Array[VillageCirculationNode] = [VillageCirculationNode.new(&"entry",VillageCirculationNode.Kind.TERRAIN_CONTACT,Vector2(0,-10).rotated(angle),0,&"town",Vector2.UP.rotated(angle))]
		var topology := ROUTER.topology(Rect2(-10,-10,20,20),contacts,ground,&"rotated")
		assert_eq(topology.paths.size(),1)
		assert_eq(topology.handoff_domains.size(),1)
		var domains: Array[FeatureGroundShape] = [topology.domain]
		domains.append_array(topology.handoff_domains)
		for path: Dictionary in topology.paths:
			domains.append_array(PathProgram.filleted_path_shapes(path.points,2,1,120,&"road"))
		var field := ground.extended(domains,[])
		for point: Vector2 in [Vector2(-30,0),Vector2(-48,24),Vector2(-42,24)]:
			assert_eq(ground.surface_at(point.rotated(angle)),FeatureGroundField.WORN_PATH,"Control actually contains this exterior road")
			assert_eq(field.surface_at(point.rotated(angle)),FeatureGroundField.WORN_PATH,"Other exterior roads retain their complete surface")
		var missing := 0
		var road := PathProgram.filleted_path_shapes(topology.paths[0].points,2,1,120,&"expected")
		for shape: FeatureGroundShape in road:
			if field.surface_at(shape._a)!=FeatureGroundField.WORN_PATH: missing += 1
		assert_eq(missing,0,"A natural handoff reservation cannot open a gap in the selected route")
		assert_eq(field.surface_at(Vector2(-17.8,1.8).rotated(angle)),FeatureGroundField.NATURAL,"Outside of the inward-turning approach stays rounded")
