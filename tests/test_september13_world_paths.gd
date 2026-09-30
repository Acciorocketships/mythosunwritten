extends GutTest

const Nodes = preload("res://tests/test_path_plan_nodes.gd")
const Solver = preload("res://scripts/terrain/features/PathRouteSolver.gd")

func test_real_hillside_node_keeps_its_walkable_narrow_exit() -> void:
	var seed_value := 2697992464
	var water := Nodes.DryPlanningWater.new(seed_value)
	var heights := TerrainWorldTuning.make_heightfield(seed_value)
	var program := PathProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heights,water,program.query_margin,
		program.shore_distance_limit,program.FIELD_CACHE_CAP)
	var paths := PathPlan.new(seed_value,water,fields,program,program.query_margin,
		SettlementPlan.new(seed_value,water))
	var cell := Vector2i(-20,-13)
	var a := {"id":&"hill-town","cell":cell}
	var b := {"id":&"hill-exit","cell":cell+Vector2i.LEFT}
	var route := paths._compute_route(a,b,"hill-town|hill-exit")
	assert_false(route.is_empty(),"The road's centre is continuous; its outer edge has only a 14 cm step")
	# Per edge (owner, September 27): its other two faces are walkable exactly
	# when they are not cliff edges; a one-storey side of a cliff cell is an
	# ordinary slope, and a two-storey side remains forbidden.
	var region := fields.region_at(Vector2(cell)*TerrainSurfaceField.TILE)
	for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
		assert_eq(TerrainSurfaceField.is_walkable_edge(region,cell,d,PathProgram.PATH_HALF_WIDTH),
			not TerrainSurfaceField.is_cliff_edge(region,cell.x,cell.y,d), "face %s" % d)

func test_route_goes_around_a_finite_cliff_without_crossing_it() -> void:
	var seed_value := 2697992464
	var water := Nodes.DryPlanningWater.new(seed_value)
	var heights := HeightfieldPlan.new(seed_value, 12.0, 4, "mean", 3)
	heights.set_raw_height_override(func(x: int, z: int) -> float:
		return 12.0 if absi(x) <= 1 and absi(z) <= 1 else 0.0)
	var program := PathProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heights, water, program.query_margin,
		program.shore_distance_limit, program.FIELD_CACHE_CAP)
	var paths := PathPlan.new(seed_value, water, fields, program,
		program.query_margin, SettlementPlan.new(seed_value,water))
	for direction: Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
		var a := {"id":&"a","cell":-direction*6}
		var b := {"id":&"b","cell":direction*6}
		var route := paths.route_for(a,b)
		assert_false(route.is_empty(),"Town roads need a bounded detour around a finite cliff")
		if route.is_empty(): continue
		var detoured := false
		for edge: Dictionary in route.connections:
			var p := (Vector2(edge.a)+Vector2(edge.b))*TerrainSurfaceField.TILE*.5
			assert_true(TerrainSurfaceField.is_walkable_edge(fields.region_at(p),edge.a,edge.b-edge.a))
			detoured = detoured or Vector2(edge.a).cross(Vector2(direction)) != 0
		assert_true(detoured,"The road follows ground around the obstacle")
		assert_eq(paths.route_for(b,a),route,"Both towns share the same canonical connection")

func test_road_can_climb_between_towns_in_the_current_height_range() -> void:
	var seed_value := 2697992464
	var water := Nodes.DryPlanningWater.new(seed_value)
	var heights := HeightfieldPlan.new(seed_value,128.0,32,"mean",3)
	heights.set_raw_height_override(func(x: int, _z: int) -> float:
		return clampf(float(x)*2.0,0.0,64.0))
	var program := PathProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heights,water,program.query_margin,
		program.shore_distance_limit,program.FIELD_CACHE_CAP)
	var paths := PathPlan.new(seed_value,water,fields,program,program.query_margin,
		SettlementPlan.new(seed_value,water))
	var route := paths.route_for({"id":&"low","cell":Vector2i.ZERO},
		{"id":&"high","cell":Vector2i(32,0)})
	assert_false(route.is_empty(),"A gentle 64 m climb is valid in the 128 m world")
	if not route.is_empty():
		assert_eq(route.connections.size(),32)
		for edge: Dictionary in route.connections:
			var p := (Vector2(edge.a)+Vector2(edge.b))*TerrainSurfaceField.TILE*.5
			assert_true(TerrainSurfaceField.is_walkable_edge(fields.region_at(p),edge.a,edge.b-edge.a,
				PathProgram.PATH_HALF_WIDTH))

func test_solver_revisits_cells_after_a_detour_instead_of_using_a_dag_order() -> void:
	# The only route is 0 -> 3 -> 1 -> 2 -> 4. A monotone pass visits 1
	# before it is reachable. The positive-cost back edge also tests termination.
	var edges := {0:[_edge(3)],3:[_edge(1)],1:[_edge(2)],2:[_edge(4),_edge(3)]}
	var record := {"start":0,"goal":4,"heights":PackedInt32Array([0,0,0,0,0]),
		"edges":edges,"order":[0,1,2,3,4],"vertical_budget":28,"turn_cost":2.0,"pair_hash":17}
	var solved := Solver.solve(record)
	assert_false(solved.is_empty(),"A legal road may turn away before approaching its destination")
	if not solved.is_empty():
		assert_eq(solved.edges.size(),4)
		assert_eq(float(solved.cost),4.0)

func _edge(to: int) -> Dictionary:
	return {"to":to,"dir":0,"variation":0,"cost":1.0,"bridge_key":"","connections":[]}

func test_detour_corridor_is_discovered_outside_the_endpoint_rectangle() -> void:
	var fixture := Nodes.new()
	var paths := fixture._plan()
	fixture.free()
	var sc := Vector2i(-1,-1)
	for direction: Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
		var bounds := paths._possible_pair_rect(sc,direction)
		var west := Vector2(sc * PathProgram.SUPER_CELLS + Vector2i(8,8)) * TerrainSurfaceField.TILE
		var detour := west - Vector2.ONE * TerrainSurfaceField.TILE * 3.5
		assert_true(bounds.has_point(detour))
		var pairs := paths._coarse_pairs(Rect2(detour,Vector2.ONE))
		assert_true(pairs.has([sc,sc+direction]),"A streamed detour still discovers its owning road pair")

func test_solver_keeps_distinct_near_equal_costs() -> void:
	var expensive := _edge(1)
	expensive.cost = 100.0001
	var cheap := _edge(2)
	cheap.cost = 100.0
	var record := {"start":0,"goal":3,"heights":PackedInt32Array([0,0,0,0]),
		"edges":{0:[expensive,cheap],1:[_edge(3)],2:[_edge(3)]},
		"order":[0,1,2,3],"vertical_budget":28,"turn_cost":2.0,"pair_hash":17}
	var solved := Solver.solve(record)
	assert_eq(float(solved.cost),101.0)
	assert_eq(solved.edges[0].to,2)

class BentApproach extends PathPlan:
	func node_for(key: Vector2i) -> Dictionary:
		if key not in [Vector2i.ZERO,Vector2i.RIGHT]: return {}
		return {"id":str(key),"cell":key*PathProgram.SUPER_CELLS}
	func _hash(_salt:int,_values:Array)->int: return 0
	func route_for(_a:Dictionary,_b:Dictionary)->Dictionary:
		var connections: Array[Dictionary] = []
		var cursor := Vector2i.ZERO
		for next: Vector2i in [Vector2i.UP]:
			connections.append({"a":cursor,"b":next})
			cursor = next
		for x in PathProgram.SUPER_CELLS:
			connections.append({"a":cursor,"b":cursor+Vector2i.RIGHT})
			cursor += Vector2i.RIGHT
		connections.append({"a":cursor,"b":cursor+Vector2i.DOWN})
		return {"key":"bent","node_a":node_for(Vector2i.ZERO),"node_b":node_for(Vector2i.RIGHT),
			"cost":1.0,"connections":connections,"bridges":[],"pair_hash":0}

func test_town_gates_use_the_actual_road_approach_after_a_detour() -> void:
	var fixture := Nodes.new()
	var source := fixture._plan()
	fixture.free()
	var paths := BentApproach.new(4242,source._water_plan,source._fields,source._program,
		source._program.query_margin,source._settlements)
	assert_eq(paths.accepted_mask_for_node(Vector2i.ZERO),8,"The west town's road leaves north, not east")
	assert_eq(paths.accepted_mask_for_node(Vector2i.RIGHT),8,"The east town's road also arrives from north")

func test_accepted_road_width_has_no_hidden_step_between_boundary_controls() -> void:
	var heights := TerrainWorldTuning.make_heightfield(2697992464)
	var accepted := 0
	for cell:Vector2i in [Vector2i(-20,-13),Vector2i(-9,-41),Vector2i(10,-16),Vector2i(21,-49),Vector2i(38,45),Vector2i(19,32)]:
		var region := heights.compute_region(cell.x,cell.y,2)
		for direction:Vector2i in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
			if not TerrainSurfaceField.is_walkable_edge(region,cell,direction,PathProgram.PATH_HALF_WIDTH): continue
			accepted += 1
			var boundary := (Vector2(cell)+Vector2(direction)*.5)*TerrainSurfaceField.TILE
			var tangent := Vector2(-direction.y,direction.x)
			for index in 81:
				var point := boundary+tangent*lerpf(-2.0,2.0,float(index)/80.0)
				var a := TerrainSurfaceField.surface_y_in_cell(region,point.x,point.y,cell.x,cell.y)
				var b := TerrainSurfaceField.surface_y_in_cell(region,point.x,point.y,cell.x+direction.x,cell.y+direction.y)
				assert_lte(absf(a-b),TerrainSurfaceField.EXPOSE_EPS+.000001)
	assert_gt(accepted,8,"The dense audit must inspect legal crossings, not only reject walls")

func test_graph_search_matches_exhaustive_simple_paths_with_detours() -> void:
	for variant in 24:
		var heights := PackedInt32Array([0,variant%3,4,1,(variant/3)%5,2])
		var edges := {}
		for pair:Array in [[0,3],[3,1],[1,2],[2,5],[0,4],[4,1],[4,5],[2,3]]:
			for reverse:bool in [false,true]:
				var a:int = pair[1] if reverse else pair[0]
				var b:int = pair[0] if reverse else pair[1]
				var edge := _edge(b)
				edge.dir = (a+b)%4
				edge.variation = absi(heights[a]-heights[b])
				edge.cost = 1.0+float((a*3+b+variant)%5)*.2
				if not edges.has(a): edges[a] = []
				edges[a].append(edge)
		var record := {"start":0,"goal":5,"heights":heights,"edges":edges,"order":[0,1,2,3,4,5],"vertical_budget":3+variant%4,"turn_cost":.5,"pair_hash":variant}
		var expected := _simple_oracle(record,0,-1,0,0.0,1)
		var actual := Solver.solve(record)
		assert_eq(actual.is_empty(),is_inf(expected))
		if not actual.is_empty(): assert_almost_eq(float(actual.cost),expected,.000001)

func _simple_oracle(record:Dictionary,cell:int,direction:int,variation:int,cost:float,visited:int)->float:
	if cell == int(record.goal): return cost
	var best := INF
	for edge:Dictionary in record.edges.get(cell,[]):
		if visited & (1<<int(edge.to)): continue
		var next_variation := variation+int(edge.variation)
		if next_variation+absi(int(record.heights[edge.to])-int(record.heights[record.start]))>int(record.vertical_budget)*2: continue
		var next_cost := cost+float(edge.cost)
		if direction>=0 and direction!=int(edge.dir): next_cost += float(record.turn_cost)
		best = minf(best,_simple_oracle(record,edge.to,edge.dir,next_variation,next_cost,visited|(1<<int(edge.to))))
	return best

class CountedEdges extends PathPlan:
	var classified := 0
	func _planning_intervals_cells(a:Vector2i,b:Vector2i)->Array[Vector2]:
		classified += 1
		return super._planning_intervals_cells(a,b)

func test_route_search_does_not_prepare_every_unused_detour_edge() -> void:
	var fixture := Nodes.new()
	var source := fixture._plan()
	fixture.free()
	var paths := CountedEdges.new(4242,source._water_plan,source._fields,source._program,source._program.query_margin,source._settlements)
	var record := paths._route_record(Vector2i.ZERO,Vector2i(32,0),"work")
	assert_eq(paths.classified,0,"Building the search domain must not prepare water for unused detours")
	var solved := Solver.solve(record)
	assert_false(solved.is_empty())
	assert_gt(paths.classified,0,"Visited ground still receives its real legal-edge checks")
	assert_lt(paths.classified,record.heights.size()*2,"The clear straight route leaves most detour edges unprepared")
