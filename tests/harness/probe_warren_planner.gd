extends SceneTree

const RisingRingPlanner = preload(
	"res://scripts/terrain/features/villages/fabric/WarrenRisingRingPlanner.gd")
const PlotVoidPlanner = preload(
	"res://scripts/terrain/features/villages/fabric/WarrenPlotVoidPlanner.gd")


func _init() -> void:
	var world_seed := 0
	var args := OS.get_cmdline_user_args()
	var summary_only := args.has("--summary")
	for index in args.size():
		if args[index] == "--seed" and index + 1 < args.size():
			world_seed = int(args[index + 1])
	if args.has("--first-grammar"):
		for attempt in PlotVoidPlanner.MAX_GRAMMAR_ATTEMPTS:
			var grammar := WarrenPlotVoidGrammar.build(world_seed, attempt)
			if grammar != null:
				print("seed=%d first_attempt=%d signature=%s canonical=%s" % [
					world_seed, attempt, grammar.geometry_signature().sha256_text(),
					grammar.canonical_coarse_route_signature().sha256_text()])
				quit(0)
				return
		print("seed=%d no_grammar" % world_seed)
		quit(1)
		return
	if args.has("--grammar-corpus"):
		var count_index := args.find("--grammar-corpus") + 1
		var count := int(args[count_index]) if count_index < args.size() else 64
		for attempt in count:
			var grammar := WarrenPlotVoidGrammar.build(world_seed, attempt)
			if grammar == null:
				print("grammar_attempt=%d rejected" % attempt)
				continue
			var bounds := grammar.coarse_route_bounds()
			print("grammar_attempt=%d bounds=%s size=%s signature=%s" % [attempt,
				bounds, bounds.size, grammar.geometry_signature().sha256_text()])
		quit(0)
		return
	if args.has("--grammar-ranking"):
		var ranked: Array[Dictionary] = []
		var ranked_seen: Dictionary = {}
		for attempt in 64:
			var grammar := WarrenPlotVoidGrammar.build(world_seed, attempt)
			if grammar == null:
				continue
			var signature := grammar.geometry_signature()
			if ranked_seen.has(signature):
				continue
			ranked_seen[signature] = true
			var bounds := grammar.coarse_route_bounds()
			if bounds.size.x > PlotVoidPlanner.MAX_COARSE_ROUTE_SPAN_CELLS \
					or bounds.size.y > PlotVoidPlanner.MAX_COARSE_ROUTE_SPAN_CELLS:
				continue
			ranked.append({"attempt": attempt, "grammar": grammar,
				"bounds": bounds, "seed_rank": PlotVoidPlanner._seeded_geometry_rank(
					signature, world_seed)})
		ranked.sort_custom(PlotVoidPlanner._coarse_candidate_less)
		for candidate: Dictionary in ranked:
			print("ranked_attempt=%d size=%s rank=%d signature=%s" % [
				int(candidate.attempt), (candidate.bounds as Rect2i).size,
				int(candidate.seed_rank), (candidate.grammar as WarrenPlotVoidPlan)
					.geometry_signature().sha256_text()])
		quit(0)
		return
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	if args.has("--recipes"):
		for recipe_value: FabricRecipe in program.recipes():
			if recipe_value.has_tag(&"room") or recipe_value.has_tag(&"roof") \
					or recipe_value.has_tag(&"prefab_anchor") \
					or recipe_value.has_tag(&"themed_stall") \
					or args.has("--recipes-all"):
				print("recipe=%s bounds=%s solid=%d occluder=%d placements=%d" % [
					recipe_value.recipe_id, recipe_value.local_clearance_bounds,
					recipe_value.solid_cells.size(), recipe_value.occluder_cells.size(),
					recipe_value.placements.size()])
				if args.has("--recipes-all"):
					for socket_record: Dictionary in recipe_value.sockets:
						var socket_id := StringName(socket_record.id)
						var socket := recipe_value.socket(socket_id)
						print("  socket=%s kind=%d cell=%s facing=%s" % [socket_id,
							socket.kind, socket.cell, socket.facing])
	var planner = PlotVoidPlanner.new() if args.has("--plot-void") \
		else RisingRingPlanner.new()
	var plan: SettlementFabricPlan
	if args.has("--attempt") and planner is WarrenPlotVoidPlanner:
		var attempt_index := args.find("--attempt") + 1
		var attempt := int(args[attempt_index]) if attempt_index < args.size() else 0
		var grammar := WarrenPlotVoidGrammar.build(world_seed, attempt)
		if grammar != null and args.has("--route-specs"):
			var route_specs: Array[Dictionary] = []
			var route_by_id: Dictionary = {}
			var route_itinerary: Array[StringName] = []
			if planner._compile_route(program, grammar, route_specs, route_by_id,
					route_itinerary):
				for route_spec: Dictionary in route_specs:
					print("route_spec=%s recipe=%s origin=%s yaw=%d" % [
						route_spec.stable_id, route_spec.recipe_id,
						route_spec.origin, int(route_spec.yaw_quarters)])
		plan = planner._solve_grammar(program, world_seed, {}, grammar) \
			if grammar != null else null
		print("grammar_attempt=%d" % attempt)
	else:
		plan = planner.solve(program, world_seed)
	print("world_seed=%d" % world_seed)
	print("plan=%s failure=%s" % [plan != null, planner.failure_reason])
	if plan != null:
		print(JSON.stringify(plan.audit, "  ", false))
		print("embedding=%s" % plan.embedding_plan.deterministic_signature())
		if args.has("--plots") and plan.embedding_plan != null:
			for proposal: Dictionary in plan.embedding_plan.barrier_proposals:
				print("plot=%s" % JSON.stringify(proposal, "", false))
		if args.has("--prefabs"):
			for unit: FabricUnit in plan.units:
				var unit_recipe := plan.recipe(unit.recipe_id)
				if unit_recipe != null and unit_recipe.has_tag(&"prefab_anchor"):
					print("prefab_unit=%s recipe=%s assets=%s origin=%s yaw=%d" % [
						unit.stable_id, unit.recipe_id, unit_recipe.asset_ids(),
						unit.lattice_origin, unit.yaw_quarters])
		if args.has("--markets"):
			for unit: FabricUnit in plan.units:
				var unit_recipe := plan.recipe(unit.recipe_id)
				if unit_recipe != null and unit_recipe.has_tag(&"market"):
					print("market_unit=%s recipe=%s assets=%s origin=%s yaw=%d" % [
						unit.stable_id, unit.recipe_id, unit_recipe.asset_ids(),
						unit.lattice_origin, unit.yaw_quarters])
		if args.has("--court-candidates"):
			_print_court_candidates(program, plan)
		if args.has("--loop-candidates"):
			_print_loop_candidates(program, plan)
		if args.has("--upper-court-candidates"):
			_print_upper_court_candidates(program, plan, world_seed)
		if args.has("--entrances") and plan.surface_plan != null:
			for entrance: Dictionary in plan.surface_plan.entrance_records:
				print("entrance=%s" % JSON.stringify(entrance, "", false))
		if args.has("--open") and plan.solid_void_plan != null:
			var claims := plan.public_realm.surface_claims()
			for obligation: Dictionary in plan.solid_void_plan.unbounded_obligations:
				var record := claims.get(obligation.surface_cell, {}) as Dictionary
				print("open=%s side=%s owner=%s" % [obligation.surface_cell,
					obligation.side, record.get("owner", &"")])
				if args.has("--open-candidates") \
						and StringName(record.get("owner", "")) == &"maze.high.arrival":
					for kind: StringName in [&"tower", &"building"]:
						for candidate: Dictionary in StaggeredFabricEmbedder._candidate_origins(
								obligation, kind):
							print("candidate=%s" % JSON.stringify(candidate, "", false))
		if summary_only:
			quit(0)
			return
		for unit: FabricUnit in plan.units:
			var recipe_value := plan.recipe(unit.recipe_id)
			if recipe_value != null and recipe_value.has_tag(&"public_walk"):
				print("route_unit=%s recipe=%s origin=%s yaw=%d" % [
					unit.stable_id, unit.recipe_id, unit.lattice_origin,
					unit.yaw_quarters])
		var overhead := WarrenOverheadSolver.candidate_specs(program, plan,
			world_seed)
		print("overhead_candidates=%d" % overhead.size())
		for candidate: Dictionary in overhead:
			print("  %s %s" % [candidate.category, candidate.stable_id])
			if args.has("--overhead-specs"):
				print("    %s" % JSON.stringify(candidate.specs, "", false))
		_print_layers(plan)
	quit(0 if plan != null else 1)


func _print_court_candidates(program: SettlementFabricProgram,
		plan: SettlementFabricPlan) -> void:
	var court := program.recipe(&"court.bridged.6x6")
	var candidates: Dictionary = {}
	for unit_value: FabricUnit in plan.units:
		var target_recipe := plan.recipe(unit_value.recipe_id)
		if target_recipe == null or not target_recipe.has_tag(&"public_walk"):
			continue
		for target_socket: Dictionary in target_recipe.sockets:
			if int(target_socket.kind) != FabricRecipe.SocketKind.WALK:
				continue
			for own_socket: Dictionary in court.sockets:
				if int(own_socket.kind) != FabricRecipe.SocketKind.WALK:
					continue
				for yaw: int in 4:
					var target_facing := FabricRecipe.transform_direction(
						target_socket.facing, unit_value.yaw_quarters)
					var own_facing := FabricRecipe.transform_direction(
						own_socket.facing, yaw)
					if own_facing != -target_facing:
						continue
					var target_cell := FabricRecipe.transform_cell(
						target_socket.cell, unit_value.lattice_origin,
						unit_value.yaw_quarters)
					var rotated_own := FabricRecipe.transform_cell(
						own_socket.cell, Vector3i.ZERO, yaw)
					var origin := target_cell + target_facing - rotated_own
					candidates["%s/%d" % [origin, yaw]] = {
						"origin": origin, "yaw": yaw,
					}
	var solver := SettlementFabricSolver.new(program)
	var valid_count := 0
	for key: String in candidates.keys():
		var candidate := candidates[key] as Dictionary
		var origin := candidate.origin as Vector3i
		var yaw := int(candidate.yaw)
		var walk_bonds := _matching_bonds(plan, court, origin, yaw,
			FabricRecipe.SocketKind.WALK)
		var bearing_bonds := _matching_bonds(plan, court, origin, yaw,
			FabricRecipe.SocketKind.BEARING)
		var walk_targets: Dictionary = {}
		for bond: Dictionary in walk_bonds:
			walk_targets[StringName(bond.target_unit)] = true
		var bearing_by_socket: Dictionary = {}
		for bond: Dictionary in bearing_bonds:
			var own_socket := StringName(bond.own_socket)
			if own_socket == &"bearing.west" or own_socket == &"bearing.east":
				bearing_by_socket[own_socket] = bond
		if OS.get_cmdline_user_args().has("--court-geometric") \
				and walk_targets.size() >= 2:
			print("court_geometric origin=%s yaw=%d walk=%s bearing=%s" % [
				origin, yaw, walk_bonds, bearing_bonds])
		if walk_targets.size() < 2 or bearing_by_socket.size() != 2:
			continue
		var west := bearing_by_socket[&"bearing.west"] as Dictionary
		var east := bearing_by_socket[&"bearing.east"] as Dictionary
		if StringName(west.target_unit) == StringName(east.target_unit):
			continue
		var bonds: Array[Dictionary] = [west, east]
		var used_walk_sockets: Dictionary = {}
		for bond: Dictionary in walk_bonds:
			var own_socket := StringName(bond.own_socket)
			if used_walk_sockets.has(own_socket):
				continue
			used_walk_sockets[own_socket] = true
			bonds.append(bond)
		var parents: Array[StringName] = [StringName(west.target_unit),
			StringName(east.target_unit)]
		var specs := _specs_from_plan(plan)
		specs.append(SettlementFabricSolver.unit_spec(&"probe.court",
			&"court.bridged.6x6", origin, yaw, parents, bonds))
		var primary: Array[StringName] = []
		primary.assign(plan.public_realm.primary_itinerary)
		var realm := SectionalPublicRealmBuilder.from_specs(&"probe.court.realm",
			program, specs, primary)
		if realm == null:
			continue
		var trial := solver.solve_sectional(&"probe.court", realm,
			SectionalPublicRealmBuilder.bind_specs(specs, program), {},
			plan.embedding_plan)
		if trial == null:
			continue
		valid_count += 1
		print("court_candidate origin=%s yaw=%d walk=%s bearing=%s audit=%s" % [
			origin, yaw, walk_bonds, [west, east], JSON.stringify(trial.audit)])
	print("valid_court_candidates=%d searched=%d" % [valid_count,
		candidates.size()])


func _print_loop_candidates(program: SettlementFabricProgram,
		plan: SettlementFabricPlan) -> void:
	var solver := SettlementFabricSolver.new(program)
	var searched: Dictionary = {}
	var valid_count := 0
	for stair_id: StringName in [&"stair.half", &"stair.full"]:
		var stair := program.recipe(stair_id)
		for unit_value: FabricUnit in plan.units:
			var target_recipe := plan.recipe(unit_value.recipe_id)
			if target_recipe == null or not target_recipe.has_tag(&"public_walk"):
				continue
			for target_socket: Dictionary in target_recipe.sockets:
				if int(target_socket.kind) != FabricRecipe.SocketKind.WALK:
					continue
				for own_socket: Dictionary in stair.sockets:
					if int(own_socket.kind) != FabricRecipe.SocketKind.WALK:
						continue
					for yaw: int in 4:
						var target_facing := FabricRecipe.transform_direction(
							target_socket.facing, unit_value.yaw_quarters)
						var own_facing := FabricRecipe.transform_direction(
							own_socket.facing, yaw)
						if own_facing != -target_facing:
							continue
						var target_cell := FabricRecipe.transform_cell(
							target_socket.cell, unit_value.lattice_origin,
							unit_value.yaw_quarters)
						var rotated_own := FabricRecipe.transform_cell(
							own_socket.cell, Vector3i.ZERO, yaw)
						var origin := target_cell + target_facing - rotated_own
						searched["%s/%s/%d" % [stair_id, origin, yaw]] = {
							"recipe_id": stair_id, "origin": origin, "yaw": yaw,
						}
	for key: String in searched.keys():
		var candidate := searched[key] as Dictionary
		var stair_id := StringName(candidate.recipe_id)
		var stair := program.recipe(stair_id)
		var origin := candidate.origin as Vector3i
		var yaw := int(candidate.yaw)
		var walk_bonds := _matching_bonds(plan, stair, origin, yaw,
			FabricRecipe.SocketKind.WALK)
		var walk_by_socket: Dictionary = {}
		var walk_targets: Dictionary = {}
		for bond: Dictionary in walk_bonds:
			walk_by_socket[StringName(bond.own_socket)] = bond
			walk_targets[StringName(bond.target_unit)] = true
		if not walk_by_socket.has(&"walk.low") \
				or not walk_by_socket.has(&"walk.high") \
				or walk_targets.size() < 2:
			continue
		var bearing_bonds := _matching_bonds(plan, stair, origin, yaw,
			FabricRecipe.SocketKind.BEARING)
		var bearing: Dictionary = {}
		for bond: Dictionary in bearing_bonds:
			if StringName(bond.own_socket) == &"bearing.low":
				bearing = bond
				break
		if bearing.is_empty():
			continue
		var bonds: Array[Dictionary] = [walk_by_socket[&"walk.low"],
			walk_by_socket[&"walk.high"], bearing]
		var parents: Array[StringName] = [StringName(bearing.target_unit)]
		var specs := _specs_from_plan(plan)
		specs.append(SettlementFabricSolver.unit_spec(&"probe.loop", stair_id,
			origin, yaw, parents, bonds))
		var primary: Array[StringName] = []
		primary.assign(plan.public_realm.primary_itinerary)
		var realm := SectionalPublicRealmBuilder.from_specs(&"probe.loop.realm",
			program, specs, primary)
		if realm == null:
			continue
		var trial := solver.solve_sectional(&"probe.loop", realm,
			SectionalPublicRealmBuilder.bind_specs(specs, program), {},
			plan.embedding_plan)
		if trial == null:
			continue
		valid_count += 1
		print("loop_candidate recipe=%s origin=%s yaw=%d walk=%s bearing=%s audit=%s" % [
			stair_id, origin, yaw, walk_bonds, bearing,
			JSON.stringify(trial.audit)])
	print("valid_loop_candidates=%d searched=%d" % [valid_count,
		searched.size()])


func _print_upper_court_candidates(program: SettlementFabricProgram,
		plan: SettlementFabricPlan, world_seed: int) -> void:
	var terminal := plan.unit(&"maze.band3.turn.west")
	var terminal_recipe := plan.recipe(terminal.recipe_id) if terminal != null else null
	var stair := program.recipe(&"stair.half")
	var court := program.recipe(&"court.supported.6x6")
	if terminal_recipe == null or stair == null or court == null:
		print("valid_upper_court_candidates=0 missing_recipe=true")
		return
	var solver := SettlementFabricSolver.new(program)
	var searched := 0
	var valid := 0
	for terminal_socket: Dictionary in terminal_recipe.sockets:
		if int(terminal_socket.kind) != FabricRecipe.SocketKind.WALK:
			continue
		var terminal_cell := FabricRecipe.transform_cell(terminal_socket.cell,
			terminal.lattice_origin, terminal.yaw_quarters)
		var terminal_facing := FabricRecipe.transform_direction(
			terminal_socket.facing, terminal.yaw_quarters)
		for stair_yaw in 4:
			var low := stair.socket(&"walk.low")
			if FabricRecipe.transform_direction(low.facing, stair_yaw) \
					!= -terminal_facing:
				continue
			var stair_origin := terminal_cell + terminal_facing \
				- FabricRecipe.transform_cell(low.cell, Vector3i.ZERO, stair_yaw)
			var high := stair.socket(&"walk.high")
			var high_cell := FabricRecipe.transform_cell(high.cell, stair_origin,
				stair_yaw)
			var high_facing := FabricRecipe.transform_direction(high.facing,
				stair_yaw)
			for court_socket: Dictionary in court.sockets:
				if int(court_socket.kind) != FabricRecipe.SocketKind.WALK:
					continue
				for court_yaw in 4:
					if FabricRecipe.transform_direction(court_socket.facing,
							court_yaw) != -high_facing:
						continue
					searched += 1
					var court_origin := high_cell + high_facing \
						- FabricRecipe.transform_cell(court_socket.cell,
							Vector3i.ZERO, court_yaw)
					var candidate_specs := _specs_from_plan(plan)
					var stair_id := StringName("probe.upper.stair")
					candidate_specs.append(SettlementFabricSolver.unit_spec(stair_id,
						&"stair.half", stair_origin, stair_yaw,
						[terminal.stable_id], [
							FabricUnit.bond(&"walk.low", terminal.stable_id,
								StringName(terminal_socket.id)),
							FabricUnit.bond(&"bearing.low", terminal.stable_id,
								StringName(String(terminal_socket.id).replace(
									"walk.", "bearing."))),
						]))
					var support_ids: Array[StringName] = []
					for support_index in 2:
						var suffix := "north" if support_index == 0 else "south"
						var socket_id := StringName("bearing.bottom.%s" % suffix)
						var bearing := court.socket(socket_id)
						var bearing_cell := FabricRecipe.transform_cell(bearing.cell,
							court_origin, court_yaw)
						var base_id := StringName("probe.upper.support.%s.base" % suffix)
						var upper_id := StringName("probe.upper.support.%s.upper" % suffix)
						var upper_origin := bearing_cell - Vector3i(0, 2, 0)
						var base_origin := upper_origin - Vector3i(0, 2, 0)
						candidate_specs.append(SettlementFabricSolver.unit_spec(base_id,
							&"room.pier.base.rock", base_origin))
						candidate_specs.append(SettlementFabricSolver.unit_spec(upper_id,
							&"room.pier.upper.orange" if posmod(world_seed \
								+ support_index, 2) == 0 else &"room.pier.upper.blue",
							upper_origin, 0, [base_id], [
								FabricUnit.bond(&"bearing.bottom", base_id,
									&"bearing.top"),
							]))
						support_ids.append(upper_id)
					candidate_specs.append(SettlementFabricSolver.unit_spec(
						&"probe.upper.court", &"court.supported.6x6",
						court_origin, court_yaw, support_ids, [
							FabricUnit.bond(StringName(court_socket.id), stair_id,
								&"walk.high"),
							FabricUnit.bond(&"bearing.bottom.north", support_ids[0],
								&"bearing.top"),
							FabricUnit.bond(&"bearing.bottom.south", support_ids[1],
								&"bearing.top"),
						]))
					var primary: Array[StringName] = []
					primary.assign(plan.public_realm.primary_itinerary)
					primary.append(stair_id)
					primary.append(&"probe.upper.court")
					var realm := SectionalPublicRealmBuilder.from_specs(
						&"probe.upper-court.realm", program, candidate_specs, primary)
					if realm == null:
						continue
					var trial := solver.solve_sectional(&"probe.upper-court", realm,
						SectionalPublicRealmBuilder.bind_specs(candidate_specs, program),
						{}, plan.embedding_plan)
					if trial == null:
						continue
					valid += 1
					print("upper_court_candidate terminal=%s stair=%s/%d court=%s/%d audit=%s" % [
						terminal_socket.id, stair_origin, stair_yaw, court_origin,
						court_yaw, JSON.stringify(trial.audit)])
	print("valid_upper_court_candidates=%d searched=%d last_failure=%s" % [
		valid, searched, solver.failure_reason])


func _matching_bonds(plan: SettlementFabricPlan, recipe_value: FabricRecipe,
		origin: Vector3i, yaw: int, socket_kind: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for own_socket: Dictionary in recipe_value.sockets:
		if int(own_socket.kind) != socket_kind:
			continue
		var own_cell := FabricRecipe.transform_cell(own_socket.cell, origin, yaw)
		var own_facing := FabricRecipe.transform_direction(own_socket.facing, yaw)
		for target: FabricUnit in plan.units:
			var target_recipe := plan.recipe(target.recipe_id)
			if target_recipe == null:
				continue
			for target_socket: Dictionary in target_recipe.sockets:
				if int(target_socket.kind) != socket_kind:
					continue
				var target_cell := FabricRecipe.transform_cell(target_socket.cell,
					target.lattice_origin, target.yaw_quarters)
				var target_facing := FabricRecipe.transform_direction(
					target_socket.facing, target.yaw_quarters)
				if own_cell + own_facing == target_cell \
						and target_cell + target_facing == own_cell:
					out.append(FabricUnit.bond(StringName(own_socket.id),
						target.stable_id, StringName(target_socket.id)))
	return out


func _specs_from_plan(plan: SettlementFabricPlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for unit_value: FabricUnit in plan.units:
		out.append(SettlementFabricSolver.unit_spec(unit_value.stable_id,
			unit_value.recipe_id, unit_value.lattice_origin,
			unit_value.yaw_quarters, unit_value.parent_ids,
			unit_value.socket_bonds, unit_value.public_node_id,
			unit_value.visual_seam_ids))
	return out


func _print_layers(plan: SettlementFabricPlan) -> void:
	var walk := plan.transformed_cells(&"walk", &"route")
	var solid := plan.transformed_cells(&"solid")
	for y in range(0, 8):
		print("layer y=%d" % y)
		for z in range(-14, 7):
			var row := ""
			for x in range(-7, 17):
				var cell := Vector3i(x, y, z)
				row += "@" if walk.has(cell) and solid.has(cell) \
					else "R" if walk.has(cell) else "#" if solid.has(cell) else "."
			print(row)
