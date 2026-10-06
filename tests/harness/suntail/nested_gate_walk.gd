extends SceneTree

class WalkController extends CharacterController:
	var direction := Vector2.ZERO
	func get_move_vector(_character: CharacterBody3D,_delta: float) -> Vector2:
		return direction

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[args.find("--seed")+1]) if args.has("--seed") else 13
	var profile := StringName(args[args.find("--profile")+1]) if args.has("--profile") else &"grand"
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var scale_profile := WarrenVillageScaleProfile.select(seed_value) if args.has("--production-size") else WarrenVillageScaleProfile.for_id(profile)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read(args[args.find("--frozen-source")+1]),program) \
		if args.has("--frozen-source") else WarrenVolumetricSolver.generate(seed_value,{},program,scale_profile)
	assert(spatial != null)
	var fabric := spatial.compiled_fabric_cache()
	var stage := Node3D.new()
	root.add_child(stage)
	var payload := preload("res://tests/harness/suntail/kit_town_review.gd").town_payload(spatial,fabric,false)
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	cache.prepare(payload.asset_ids())
	EnvironmentCollisionBuilder.commit(stage,payload,cache,&"StairTown")
	if OS.get_cmdline_user_args().has("--dump-colliders"):
		var count := 0
		for asset: StringName in payload.asset_ids():
			var batch: Dictionary = payload.batches[asset]
			for index in batch.transforms.size():
				var flags: Array = batch.get("collision_enabled",[])
				if not flags.is_empty() and not flags[index]: continue
				for piece: EnvironmentCollisionPiece in cache.visual(asset).collisions:
					var matches := count == int(args[args.find("--collider-index")+1]) \
						if args.has("--collider-index") else asset == &"suntail.stone.stone_wall_plain"
					if args.has("--collider-asset"):
						matches = asset == StringName(args[args.find("--collider-asset") + 1])
					if matches:
						print("COLLIDER ",count," ",batch.ids[index]," ",batch.transforms[index]," piece=",piece.local_transform)
					count += 1
		quit()
		return
	var surfaces := StaticBody3D.new()
	stage.add_child(surfaces)
	for mesh: Dictionary in payload.surface_meshes:
		if bool(mesh.get("visual_only",false)): continue
		var faces: PackedVector3Array = mesh.get("collision_faces",PackedVector3Array())
		if faces.is_empty(): continue
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision=true
		shape.set_faces(faces)
		var node := CollisionShape3D.new()
		node.shape=shape
		node.set_meta("surface_id", String(mesh.get("stable_id", "")))
		surfaces.add_child(node)
	for cell: Vector3i in fabric.surface_plan.cells_for_kind(PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET):
		var shape := BoxShape3D.new()
		shape.size=Vector3(1.5,0.1,1.5)
		var node := CollisionShape3D.new()
		node.shape=shape
		node.position=Vector3(cell)*1.5-Vector3.UP*0.05
		surfaces.add_child(node)
	if args.has("--native"):
		# This harness generates flat natural ground at datum zero. Include
		# that terrain collision under the private stair approach too.
		var terrain := CollisionShape3D.new()
		var ground_box := BoxShape3D.new()
		ground_box.size = Vector3(500, .1, 500)
		terrain.shape = ground_box
		terrain.position.y = -.05
		surfaces.add_child(terrain)
	stage.scale = VillageWorldScale.frame_scale()
	var player := (load("res://characters/character.tscn") as PackedScene).instantiate() as CharacterBody3D
	var controller := WalkController.new()
	player.controller = controller
	player.set_physics_process(false)
	root.add_child(player)
	player.set_physics_process(false)
	assert(player.body_model_root != null,"Import the character source models before running player traversal")
	await physics_frame
	await physics_frame
	var results: Array = []
	var source := spatial.source_volume.mass_context[&"maze_source_plan"] as WarrenMazeSourcePlan
	var routes := _routes(source, fabric, args.has("--skywalks"), spatial)
	for route: Dictionary in routes:
		var cells: Array = []
		for point: Vector3 in route.points:
			var world := stage.transform * point
			var query := PhysicsRayQueryParameters3D.create(world + Vector3.UP * 2.0,
				world - Vector3.UP * 2.0)
			query.exclude = [player.get_rid()]
			var hit := stage.get_world_3d().direct_space_state.intersect_ray(query)
			print("WALK_SURFACE ", route.label, " expected=", world,
				" floor=", hit.get("position", "missing"))
			if not hit.is_empty() and (hit.normal as Vector3).y > 0.5:
				world.y = (hit.position as Vector3).y
			cells.append(world)
		for reverse in [false,true]:
			var waypoints := cells.duplicate()
			if reverse: waypoints.reverse()
			var first: Vector3 = waypoints[0]
			player.global_position = first + Vector3.UP * 0.1
			player.velocity = Vector3.ZERO
			controller.direction = Vector2.ZERO
			for tick in 30:
				await physics_frame
				player._physics_process(1.0/60)
			var passed := true
			var trace := []
			for index in range(1,waypoints.size()):
				var cell: Vector3 = waypoints[index]
				var target := cell
				# Intermediate excavation cells can lie below a rising tread.
				# Follow their XZ route; require the correct height at the endpoint.
				var reached := false
				for tick in 600:
					var delta := Vector2(target.x-player.global_position.x,target.z-player.global_position.z)
					# A capsule can stand on the adjacent tread rather than the
					# centre-ray height. Bound that difference by its real step
					# capability and require physical support at the destination.
					if delta.length() < 0.3 and (index < waypoints.size() - 1 or
							(player.is_on_floor() and absf(player.global_position.y - target.y)
							< player.MAX_STEP_HEIGHT)) :
						reached = true
						break
					controller.direction = delta.normalized()*0.75
					await physics_frame
					player._physics_process(1.0/60)
					if tick%30==0: trace.append({"waypoint":index,"tick":tick,"position":str(player.global_position),"target":str(target),"floor":player.is_on_floor()})
				if not reached:
					for collision_index in player.get_slide_collision_count():
						var collision := player.get_slide_collision(collision_index)
						var collider := collision.get_collider() as CollisionObject3D
						if collider != null:
							var owner := collision.get_collider_shape() as Node
							trace.append({"collision":str(owner.get_path()),"surface_id":owner.get_meta("surface_id",""),"position":str(collision.get_position()),"normal":str(collision.get_normal())})
					passed = false
					break
			results.append({"gate":route.label,"reverse":reverse,"passed":passed,"trace":trace})
			print("TOWN_ROUTE_WALK ",route.label," reverse=",reverse," passed=",passed," end=",player.global_position)
	var output := args[args.find("--output")+1] if args.has("--output") else "/tmp/october1-nested-gate-walk.json"
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	player.queue_free()
	stage.queue_free()
	await process_frame
	var passed := not results.is_empty()
	for row: Dictionary in results: passed = passed and bool(row.passed)
	quit(0 if passed else 1)


static func _macro_point(cell: Vector3i) -> Vector3:
	return Vector3(cell.x * 3.0 + 0.75, cell.y * 1.5, cell.z * 3.0 + 0.75)


static func _routes(source: WarrenMazeSourcePlan, fabric,
		skywalks: bool, spatial: WarrenSpatialPlan) -> Array[Dictionary]:
	var routes: Array[Dictionary] = []
	var args := OS.get_cmdline_user_args()
	if args.has("--native"):
		for unit: FabricUnit in fabric.units:
			var recipe: FabricRecipe = fabric.recipe(unit.recipe_id)
			if not recipe.has_tag(&"native_grammar"): continue
			var arrival := unit.transform() * Vector3.ZERO
			var facing := unit.transform().basis * Vector3.BACK
			var landing := arrival + facing * FabricRecipe.CELL_SIZE
			if String(recipe.recipe_id).begins_with("anchor.z_native.turret."):
				var config := {}
				for item: Dictionary in preload("res://scripts/terrain/features/villages/grammar/NativeHouseVocabulary.gd").CONFIGURATIONS:
					if item.id == recipe.recipe_id: config = item
				assert(not config.is_empty())
				var site := preload("res://scripts/terrain/features/villages/grammar/NativeTurretSite.gd").place(EnvironmentCatalog.load_default(), config.extra_upper_storeys, VillageWorldScale.KIT_WORLD_SCALE, Vector3.ZERO, Vector3.BACK, true)
				assert(site.ok)
				var points: Array[Vector3] = [landing]
				for point: Vector3 in site.entry_route:
					points.append(unit.transform() * ((point + Vector3.UP * VillageWorldScale.GROUND_DATUM_GUARD) / VillageWorldScale.frame_scale()))
				routes.append({"label": String(unit.stable_id), "points": points})
				continue
			var top := Vector3.ZERO
			var found := false
			for part: Dictionary in recipe.placements:
				if String(part.asset_id).begins_with("pure_village.native.door_") or String(part.asset_id).begins_with("pure_village.arcade.door_"):
					top = unit.transform() * part.transform * Vector3(0, 0, .4)
					found = true
			assert(found, "Native entry recipe must contain its actual closed door")
			routes.append({"label": String(unit.stable_id), "points": [landing, arrival, top]})
		assert(not routes.is_empty(), "Town must exercise native placement")
		return routes
	if args.has("--flight"):
		var endpoints := args[args.find("--flight")+1].split(":")
		var cells: Array[Vector3i] = []
		for endpoint: String in endpoints:
			var values := endpoint.split(",")
			cells.append(Vector3i(int(values[0]),int(values[1]),int(values[2])))
		for flight: WarrenVolumeTransition in spatial.source_volume.transitions:
			if flight.from_cell==cells[0] and flight.to_cell==cells[1]:
				routes.append({"label":"flight.%s" % flight.stable_id,
					"points":[_macro_point(cells[0]),_macro_point(cells[1])]})
		assert(routes.size()==1,"Requested flight must be a published transition")
		return routes
	if args.has("--covered-cell"):
		var values := args[args.find("--covered-cell")+1].split(",")
		var cell := Vector3i(int(values[0]),int(values[1]),int(values[2]))
		assert(source.passage_kinds.has(cell),"Requested cell must be a published passage")
		var neighbours: Array[Vector3i] = []
		for edge:Dictionary in source.excavation.walk_edges():
			var other:Vector3i=edge.b if edge.a==cell else edge.a
			if edge.a!=cell and edge.b!=cell:continue
			if other.y==cell.y and not neighbours.has(other):neighbours.append(other)
		neighbours.sort_custom(func(a:Vector3i,b:Vector3i)->bool:return a.x<b.x if a.x!=b.x else a.z<b.z)
		for a:Vector3i in neighbours:
			var b:=cell*2-a
			if not neighbours.has(b):continue
			routes.append({"label":"covered.%s" % cell,"points":[_macro_point(a),_macro_point(cell),_macro_point(b)]})
			break
		# A bored corner has two adjacent, not opposite, published edges.
		# Walk through the actual centre waypoint so the probe tests its turn
		# instead of cutting diagonally through the supporting jamb.
		if routes.is_empty() and neighbours.size()>=2:
			routes.append({"label":"covered.turn.%s" % cell,"points":[_macro_point(neighbours[0]),_macro_point(cell),_macro_point(neighbours[1])]})
		if routes.is_empty() and args.has("--covered-access"):
			var approach := _public_route(source,cell)
			assert(approach.size()>=2,"Covered destination needs a published approach")
			var points: Array = []
			for step:Vector3i in approach:points.append(_macro_point(step))
			routes.append({"label":"covered.access.%s"%cell,"points":points})
		assert(not routes.is_empty(),"Requested passage must have two published walk edges")
		return routes
	if args.has("--districts") or args.has("--cottage-access"):
		for lane: Dictionary in source.excavation.lanes:
			var feature := &"house_site_access" if args.has("--cottage-access") else &"district_access"
			if lane.get("feature_kind",&"") != feature: continue
			var approach := _public_route(source,lane.cells.back())
			assert(not approach.is_empty(),"district has no connected route from entry")
			var points: Array = []
			for cell: Vector3i in approach: points.append(_macro_point(cell))
			routes.append({"label":"%s.%s" % [feature,lane.cells.back()],"points":points})
		return routes
	if args.has("--wall-tunnels"):
		for lane: Dictionary in source.excavation.lanes:
			if lane.get("feature_kind",&"")!=&"wall_tunnel": continue
			var points: Array = [_macro_point(lane.anchor)]
			for cell: Vector3i in lane.cells: points.append(_macro_point(cell))
			for edge: Dictionary in source.excavation.loop_edges:
				if edge.from==lane.cells.back(): points.append(_macro_point(edge.to))
			routes.append({"label":"wall-tunnel.%s" % lane.anchor,"points":points})
		return routes
	if args.has("--wall-rooms") or args.has("--upper-wall-rooms"):
		var limit := int(args[args.find("--wall-room-limit")+1]) if args.has("--wall-room-limit") else 1000
		for plot: Dictionary in source.plots:
			if not bool(plot.get("wall_room",false)) or routes.size()>=limit: continue
			if args.has("--upper-wall-rooms") and int(plot.floor)<=source.massif.base_at(plot.cells[0]): continue
			var approach := _public_route(source,plot.door_walk)
			assert(not approach.is_empty(),"wall room has no route from town entrance")
			var points: Array = []
			for cell: Vector3i in approach: points.append(_macro_point(cell))
			if args.has("--door-thresholds"):
				if args.has("--door-only"): points = [points.back()]
				var found := false
				for building: WarrenBuildingVolume in spatial.buildings:
					if not String(KitVillageBuildings.house_id_for(building.stable_id)).ends_with(String(plot.id)): continue
					for threshold: Dictionary in building.thresholds:
						var cell: Vector3i = threshold.public_cell
						var public_point := Vector3(cell)*FabricRecipe.CELL_SIZE
						points.append(public_point)
						var toward := Vector3((threshold.private_cell as Vector3i)-cell).normalized()
						# Stop outside the closed door, leaving the character's
						# radius plus wall/door relief clear of its face.
						var margin := 0.65/VillageWorldScale.frame_scale().x
						points.append(public_point+toward*(FabricRecipe.CELL_SIZE*0.5-margin))
						found = true
						break
				assert(found,"wall room must have a realized doorway threshold")
			routes.append({"label":"wall-room.%s" % plot.id,"points":points})
		return routes
	if args.has("--court-doors"):
		var floors := WarrenVolumetricSolver._maze_deck_walk_cells(spatial.source_volume)
		for building: WarrenBuildingVolume in spatial.buildings:
			for threshold: Dictionary in building.thresholds:
				var cell: Vector3i = threshold.public_cell
				if not floors.has(cell): continue
				var direction: Vector3i = (threshold.private_cell as Vector3i)-cell
				var start := cell-direction
				if not floors.has(start): continue
				var public_point := Vector3(cell)*FabricRecipe.CELL_SIZE
				var margin := 0.65/VillageWorldScale.frame_scale().x
				var end := public_point+Vector3(direction).normalized()*(FabricRecipe.CELL_SIZE*0.5-margin)
				routes.append({"label":"court-door.%s.%s" % [building.stable_id,cell],
					"points":[Vector3(start)*FabricRecipe.CELL_SIZE,public_point,end]})
		assert(not routes.is_empty(),"Expected an actual doorway facing a paved court")
		return routes
	if OS.get_cmdline_user_args().has("--courts"):
		for plot: Dictionary in source.plots:
			if plot.kind != WarrenMazeSourcePlan.PLOT_DECK: continue
			if args.has("--court-plot") and String(plot.id) != args[args.find("--court-plot")+1]: continue
			var approach := _court_approach(source,plot)
			assert(not approach.is_empty(),"courtyard has no route from the entrance")
			var points: Array = []
			for cell: Vector3i in approach: points.append(_macro_point(cell))
			points.append_array(_court_walk_points(plot,fabric,points.back()))
			routes.append({"label":"court.%s" % plot.id,"points":points})
		return routes
	if not skywalks:
		for lane: Dictionary in source.excavation.lanes:
			if StringName(lane.get("feature_kind", &"")) != &"citadel_gate":
				continue
			var points: Array = [_macro_point(lane.anchor)]
			if OS.get_cmdline_user_args().has("--from-entry"):
				var approach := _public_route(source, lane.anchor)
				assert(not approach.is_empty(), "fortified gate has no public route from town entrance")
				points.clear()
				for cell: Vector3i in approach:
					points.append(_macro_point(cell))
			for cell: Vector3i in lane.cells:
				points.append(_macro_point(cell))
			routes.append({"label": str(lane.cells.back()), "points": points})
		return routes
	for span: Dictionary in SettlementFabricAssembler.maze_skywalk_spans(fabric):
		var near: Vector3i = span.cell
		var far: Vector3i = near + (span.step as Vector3i) * (int(span.gap) + 1)
		routes.append({"label": "skywalk.%d" % routes.size(),
			"points": [Vector3(near) * 1.5, Vector3(far) * 1.5]})
	var stamped: Dictionary = {}
	for outcome: Dictionary in spatial.audit.get("maze_bridge_outcomes", []):
		if outcome.outcome == "stamped":
			stamped[StringName(outcome.id)] = true
	var proofs: Array = source.excavation.bridge_span_audit.get("seeded", [])
	for index in proofs.size():
		if not stamped.has(StringName("bridge.%02d" % index)):
			continue
		var proof: Dictionary = proofs[index]
		var groups: Array = proof.endpoint_groups
		var points: Array = []
		var best := INF
		for a: Vector2i in groups[0]:
			for b: Vector2i in groups[1]:
				var distance := Vector2(a).distance_squared_to(Vector2(b))
				if distance < best:
					best = distance
					points = [_macro_point(Vector3i(a.x, proof.floor, a.y)),
						_macro_point(Vector3i(b.x, proof.floor, b.y))]
		routes.append({"label": "source_bridge.%02d" % index, "points": points})
	var walks: Array = [source.excavation.route]
	for lane: Dictionary in source.excavation.lanes:
		var walk: Array = [lane.anchor]
		walk.append_array(lane.cells)
		walks.append(walk)
	for span: Array in source.excavation.bridge_spans:
		for walk: Array in walks:
			var first := walk.find(span[0])
			var last := walk.find(span.back())
			if first < 1 or last < first or last + 1 >= walk.size():
				continue
			var points: Array = []
			for index in range(first - 1, last + 2):
				points.append(_macro_point(walk[index]))
			routes.append({"label": "underpass.%s" % str(span[0]), "points": points})
			break
	return routes


static func _court_approach(source: WarrenMazeSourcePlan, plot: Dictionary) -> Array[Vector3i]:
	# The original reservation address may be pruned when another entrance
	# survives. Select a real final landing, never an inferred spatial shortcut.
	var landings := {}
	for edge: Dictionary in source.excavation.walk_edges():
		landings[edge.a] = true
		landings[edge.b] = true
	var candidates: Array[Vector3i] = []
	for column: Vector2i in plot.cells:
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var cell := Vector3i(column.x+direction.x,plot.floor,column.y+direction.y)
			if landings.has(cell) and source.passage_kinds.has(cell) and not candidates.has(cell):
				candidates.append(cell)
	candidates.sort_custom(WarrenMazeSourcePlan._cell_less)
	var best: Array[Vector3i] = []
	for candidate: Vector3i in candidates:
		var route := _public_route(source,candidate)
		if not route.is_empty() and (best.is_empty() or route.size()<best.size()):
			best = route
	return best


static func _public_route(source: WarrenMazeSourcePlan, target: Vector3i) -> Array[Vector3i]:
	# Use only published walk edges. A geometric nearest-neighbour shortcut
	# could cross a wall or join different storeys and conceal an access defect.
	var graph := {}
	for edge: Dictionary in source.excavation.walk_edges():
		var a: Vector3i = edge.a
		var b: Vector3i = edge.b
		if not graph.has(a): graph[a] = []
		if not graph.has(b): graph[b] = []
		if not graph[a].has(b): graph[a].append(b)
		if not graph[b].has(a): graph[b].append(a)
	var entry: Vector3i = source.excavation.route.front()
	var queue: Array[Vector3i] = [entry]
	var parent := {entry: entry}
	var cursor := 0
	while cursor < queue.size() and not parent.has(target):
		var cell := queue[cursor]
		cursor += 1
		for next: Vector3i in graph.get(cell,[]):
			if parent.has(next): continue
			parent[next] = cell
			queue.append(next)
	var result: Array[Vector3i] = []
	if not parent.has(target): return result
	var cell := target
	while cell != entry:
		result.append(cell)
		cell = parent[cell]
	result.append(entry)
	result.reverse()
	return result


static func _court_walk_points(plot: Dictionary, fabric: SettlementFabricPlan,
		approach: Vector3) -> Array:
	var floors := {}
	for column: Vector2i in WarrenMazeSourcePlan.deck_flat_columns(plot):
		for dx in 2:
			for dz in 2:
				var cell := Vector3i(column.x*2+dx,plot.floor,column.y*2+dz)
				if fabric.surface_plan.has_cell(cell): floors[cell] = true
	var remaining: Array = floors.keys()
	var at := approach
	var points: Array = []
	var current := Vector3i.ZERO
	while not remaining.is_empty():
		remaining.sort_custom(func(a: Vector3i,b: Vector3i) -> bool:
			var da := (Vector3(a)*FabricRecipe.CELL_SIZE-at).length_squared()
			var db := (Vector3(b)*FabricRecipe.CELL_SIZE-at).length_squared()
			return da<db if not is_equal_approx(da,db) else (a.x<b.x if a.x!=b.x else a.z<b.z))
		var target: Vector3i = remaining.pop_front()
		if points.is_empty():
			points.append(Vector3(target)*FabricRecipe.CELL_SIZE)
		else:
			var queue: Array[Vector3i] = [current]
			var parent := {current:current}
			var cursor := 0
			while cursor<queue.size() and not parent.has(target):
				var cell := queue[cursor]
				cursor += 1
				for step: Vector3i in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
					var next := cell+step
					if floors.has(next) and not parent.has(next):
						parent[next] = cell
						queue.append(next)
			assert(parent.has(target),"court walking ring is disconnected")
			var chain: Array = []
			var cell := target
			while cell != current:
				chain.push_front(Vector3(cell)*FabricRecipe.CELL_SIZE)
				cell = parent[cell]
			points.append_array(chain)
		current = target
		at = Vector3(current)*FabricRecipe.CELL_SIZE
	return points
