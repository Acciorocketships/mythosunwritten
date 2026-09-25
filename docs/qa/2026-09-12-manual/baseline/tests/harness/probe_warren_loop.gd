extends SceneTree

## Headless design probe for the compact orthogonal rising-ring route. This
## prints exact lattice poses and validates every two-lane seam before the
## pattern is admitted to the visual fixture.


func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	assert(program != null)
	var specs: Array[Dictionary] = []
	var by_id: Dictionary = {}
	var itinerary: Array[StringName] = []
	_put(specs, by_id, SettlementFabricSolver.unit_spec(
		&"ring.entry", &"route.landing", Vector3i.ZERO))
	itinerary.append(&"ring.entry")
	_chain(program, specs, by_id, itinerary, &"ring.east", &"route.straight",
		&"ring.entry", &"walk.west", &"walk.east", 0)
	_chain(program, specs, by_id, itinerary, &"ring.turn.north", &"route.corner",
		&"ring.east", &"walk.west", &"walk.east", 0)
	_chain(program, specs, by_id, itinerary, &"ring.rise.half", &"stair.half",
		&"ring.turn.north", &"walk.low", &"walk.north", 0)
	_chain(program, specs, by_id, itinerary, &"ring.upper.turn.west", &"route.corner",
		&"ring.rise.half", &"walk.south", &"walk.high", 0)
	_chain(program, specs, by_id, itinerary, &"ring.upper.west", &"route.straight",
		&"ring.upper.turn.west", &"walk.east", &"walk.west", 0)
	_chain(program, specs, by_id, itinerary, &"ring.upper.turn.north", &"route.corner",
		&"ring.upper.west", &"walk.east", &"walk.west", 0)
	_chain(program, specs, by_id, itinerary, &"ring.drop.half", &"stair.half",
		&"ring.upper.turn.north", &"walk.high", &"walk.north", 2)
	_chain(program, specs, by_id, itinerary, &"ring.lower.turn.east", &"route.corner",
		&"ring.drop.half", &"walk.south", &"walk.low", 0)
	_chain(program, specs, by_id, itinerary, &"ring.rise.full", &"stair.full",
		&"ring.lower.turn.east", &"walk.low", &"walk.east", 3)
	_chain(program, specs, by_id, itinerary, &"ring.middle.rise.half", &"stair.half",
		&"ring.rise.full", &"walk.low", &"walk.high", 3)
	_chain(program, specs, by_id, itinerary, &"ring.middle.east.approach", &"route.straight",
		&"ring.middle.rise.half", &"walk.west", &"walk.high", 0)
	_chain(program, specs, by_id, itinerary, &"ring.middle.turn.south", &"route.corner",
		&"ring.middle.east.approach", &"walk.west", &"walk.east", 0)
	_chain(program, specs, by_id, itinerary, &"ring.middle.south", &"route.straight",
		&"ring.middle.turn.south", &"walk.east", &"walk.south", 1)
	_chain(program, specs, by_id, itinerary, &"ring.middle.south.2", &"route.straight",
		&"ring.middle.south", &"walk.east", &"walk.west", 1)
	_chain(program, specs, by_id, itinerary, &"ring.middle.turn.west", &"route.corner",
		&"ring.middle.south.2", &"walk.north", &"walk.west", 0)
	_chain(program, specs, by_id, itinerary, &"ring.middle.west", &"route.straight",
		&"ring.middle.turn.west", &"walk.east", &"walk.west", 0)
	_chain(program, specs, by_id, itinerary, &"ring.middle.west.2", &"route.straight",
		&"ring.middle.west", &"walk.east", &"walk.west", 0)
	_chain(program, specs, by_id, itinerary, &"ring.middle.west.3", &"route.straight",
		&"ring.middle.west.2", &"walk.east", &"walk.west", 0)
	_chain(program, specs, by_id, itinerary, &"ring.drop.middle", &"stair.half",
		&"ring.middle.west.3", &"walk.high", &"walk.west", 3)
	_chain(program, specs, by_id, itinerary, &"ring.return.turn.south", &"route.corner",
		&"ring.drop.middle", &"walk.east", &"walk.low", 0)
	_chain(program, specs, by_id, itinerary, &"ring.return.south", &"route.straight",
		&"ring.return.turn.south", &"walk.east", &"walk.south", 1)
	_chain(program, specs, by_id, itinerary, &"ring.return.turn.west", &"route.corner",
		&"ring.return.south", &"walk.north", &"walk.west", 0)
	_chain(program, specs, by_id, itinerary, &"ring.final.rise", &"stair.full",
		&"ring.return.turn.west", &"walk.low", &"walk.east", 3)
	_chain(program, specs, by_id, itinerary, &"ring.high.arrival", &"route.corner",
		&"ring.final.rise", &"walk.west", &"walk.high", 0)
	_chain(program, specs, by_id, itinerary, &"ring.top.rise", &"stair.full",
		&"ring.high.arrival", &"walk.low", &"walk.north", 0)
	_chain(program, specs, by_id, itinerary, &"ring.top.arrival", &"route.corner",
		&"ring.top.rise", &"walk.south", &"walk.high", 0)
	_chain(program, specs, by_id, itinerary, &"ring.top.east", &"route.straight",
		&"ring.top.arrival", &"walk.west", &"walk.east", 0)
	_chain(program, specs, by_id, itinerary, &"ring.top.east.2", &"route.straight",
		&"ring.top.east", &"walk.west", &"walk.east", 0)

	for spec: Dictionary in specs:
		print("%s %s origin=%s yaw=%d" % [spec.stable_id, spec.recipe_id,
			spec.origin, spec.yaw_quarters])
	var realm := SectionalPublicRealmBuilder.from_specs(&"probe.rising-ring",
		program, specs, itinerary)
	print("realm=%s failure=%s" % [realm != null,
		SectionalPublicRealmBuilder.last_failure])
	if realm != null:
		print("audit=%s" % realm.audit)
		_print_surface_maps(realm)
		_print_loop_stair_candidates(program, specs, by_id)
	quit(0 if realm != null else 1)


static func _print_surface_maps(realm: SectionalPublicRealmPlan) -> void:
	var cells := realm.surface_claims()
	print("-- projected --")
	for z in range(-11, 5):
		var projected := ""
		for x in range(-5, 9):
			var hit := false
			for y in range(0, 6):
				hit = hit or cells.has(Vector3i(x, y, z))
			projected += "#" if hit else "."
		print("%3d %s" % [z, projected])
	for y in range(0, 6):
		print("-- y=%d --" % y)
		for z in range(-11, 5):
			var line := ""
			for x in range(-5, 9):
				line += "#" if cells.has(Vector3i(x, y, z)) else "."
			print("%3d %s" % [z, line])


static func _print_loop_stair_candidates(program: SettlementFabricProgram,
		specs: Array[Dictionary], by_id: Dictionary) -> void:
	var occupied: Dictionary = {}
	for spec: Dictionary in specs:
		var recipe_value := program.recipe(StringName(spec.recipe_id))
		for cell: Vector3i in recipe_value.walk_cells:
			occupied[FabricRecipe.transform_cell(cell, spec.origin,
				int(spec.yaw_quarters))] = StringName(spec.stable_id)
	for parent_spec: Dictionary in specs:
		var parent_recipe := program.recipe(StringName(parent_spec.recipe_id))
		for parent_socket: Dictionary in parent_recipe.sockets:
			if int(parent_socket.kind) != FabricRecipe.SocketKind.WALK:
				continue
			for stair_id: StringName in [&"stair.half", &"stair.full"]:
				var stair := program.recipe(stair_id)
				for own_socket_id: StringName in [&"walk.low", &"walk.high"]:
					var other_socket_id := &"walk.high" \
						if own_socket_id == &"walk.low" else &"walk.low"
					for yaw in 4:
						var own_socket := stair.socket(own_socket_id)
						var parent_facing := FabricRecipe.transform_direction(
							parent_socket.facing, int(parent_spec.yaw_quarters))
						if FabricRecipe.transform_direction(own_socket.facing, yaw) \
								!= -parent_facing:
							continue
						var origin := _attached_origin(program, stair, own_socket_id,
							yaw, parent_spec, StringName(parent_socket.id))
						var overlaps := false
						for local_cell: Vector3i in stair.walk_cells:
							if occupied.has(FabricRecipe.transform_cell(local_cell,
									origin, yaw)):
								overlaps = true
								break
						if overlaps:
							continue
						var other_socket := stair.socket(other_socket_id)
						var other_cell := FabricRecipe.transform_cell(other_socket.cell,
							origin, yaw)
						var other_facing := FabricRecipe.transform_direction(
							other_socket.facing, yaw)
						for target_spec: Dictionary in specs:
							if target_spec.stable_id == parent_spec.stable_id:
								continue
							var target_recipe := program.recipe(StringName(
								target_spec.recipe_id))
							for target_socket: Dictionary in target_recipe.sockets:
								if int(target_socket.kind) != FabricRecipe.SocketKind.WALK:
									continue
								var target_cell := FabricRecipe.transform_cell(
									target_socket.cell, target_spec.origin,
									int(target_spec.yaw_quarters))
								var target_facing := FabricRecipe.transform_direction(
									target_socket.facing, int(target_spec.yaw_quarters))
								if other_facing == -target_facing \
										and other_cell == target_cell + target_facing:
									print("LOOP %s/%s -> %s/%s via %s origin=%s yaw=%d (%s/%s)" % [
										parent_spec.stable_id, parent_socket.id,
										target_spec.stable_id, target_socket.id,
										stair_id, origin, yaw, own_socket_id,
										other_socket_id])


static func _chain(program: SettlementFabricProgram,
		specs: Array[Dictionary], by_id: Dictionary,
		itinerary: Array[StringName], stable_id: StringName,
		recipe_id: StringName, parent_id: StringName,
		own_socket_id: StringName, parent_socket_id: StringName,
		yaw: int) -> void:
	var child_recipe := program.recipe(recipe_id)
	var parent_spec := by_id[parent_id] as Dictionary
	var origin := _attached_origin(program, child_recipe, own_socket_id, yaw,
		parent_spec, parent_socket_id)
	_put(specs, by_id, SettlementFabricSolver.unit_spec(stable_id, recipe_id,
		origin, yaw, [], [FabricUnit.bond(own_socket_id, parent_id,
			parent_socket_id)]))
	itinerary.append(stable_id)


static func _attached_origin(program: SettlementFabricProgram,
		child_recipe: FabricRecipe, child_socket_id: StringName, child_yaw: int,
		parent_spec: Dictionary, parent_socket_id: StringName) -> Vector3i:
	var parent_recipe := program.recipe(StringName(parent_spec.recipe_id))
	var own_socket := child_recipe.socket(child_socket_id)
	var parent_socket := parent_recipe.socket(parent_socket_id)
	assert(not own_socket.is_empty() and not parent_socket.is_empty())
	var parent_yaw := int(parent_spec.yaw_quarters)
	var parent_cell := FabricRecipe.transform_cell(parent_socket.cell,
		parent_spec.origin as Vector3i, parent_yaw)
	var parent_facing := FabricRecipe.transform_direction(parent_socket.facing,
		parent_yaw)
	var own_facing := FabricRecipe.transform_direction(own_socket.facing,
		child_yaw)
	assert(own_facing == -parent_facing)
	var rotated_own_cell := FabricRecipe.transform_cell(own_socket.cell,
		Vector3i.ZERO, child_yaw)
	return parent_cell + parent_facing - rotated_own_cell


static func _put(specs: Array[Dictionary], by_id: Dictionary,
		spec: Dictionary) -> void:
	var stable_id := StringName(spec.stable_id)
	assert(not by_id.has(stable_id))
	specs.append(spec)
	by_id[stable_id] = spec
