class_name WarrenOverheadSolver
extends RefCounted

## Derives inhabited overhead candidates from the already-proved exterior
## route and building facades. This solver never invents an empty bridge: each
## outcrop has one inhabited bearing parent and each skywalk joins two real
## room sockets. The caller admits candidates transactionally through the
## common SettlementFabricSolver, so occupancy, continuous envelopes, support,
## and public-air clearance remain one gate.

static func candidate_specs(program: SettlementFabricProgram,
		plan: SettlementFabricPlan, world_seed: int,
		qualify_against_plan: bool = true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if program == null or plan == null or not plan.is_sealed():
		return out
	var endpoints := _room_endpoints(plan)
	var route_cells := _public_route_cells(plan)
	out.append_array(_skywalk_candidates(program, plan, endpoints, route_cells))
	out.append_array(_corner_skywalk_candidates(program, plan, endpoints,
		route_cells))
	out.append_array(_outcrop_candidates(program, plan, endpoints, route_cells))
	if not qualify_against_plan:
		return out
	# Candidate enumeration is intentionally generous, but a full settlement
	# transaction is far too expensive to use as its broad phase. Reject the
	# exact cell and measured-envelope conflicts that are already frozen in the
	# sealed plan before ranking. The common solver still performs the socket,
	# exterior-volume, surface, and final validation for every survivor.
	var qualified: Array[Dictionary] = []
	for candidate: Dictionary in out:
		if not _passes_sealed_plan_broad_phase(program, plan, candidate):
			continue
		candidate["lower_route_cover_count"] = _candidate_lower_route_cover_count(
			candidate, program, route_cells)
		qualified.append(candidate)
	qualified.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_rank := 0 if StringName(a.category) == &"skywalk" else 1
		var b_rank := 0 if StringName(b.category) == &"skywalk" else 1
		if a_rank != b_rank:
			return a_rank < b_rank
		var a_cover := int(a.lower_route_cover_count)
		var b_cover := int(b.lower_route_cover_count)
		if a_cover != b_cover:
			return a_cover > b_cover
		# Once route shelter is equal, articulate the upper portions of the tallest
		# stacks first. A bounded outcrop budget should break up repeated high
		# storeys, not spend all its bays on already varied ground-level facades.
		var a_source_level := int(a.get("source_level", -2147483648))
		var b_source_level := int(b.get("source_level", -2147483648))
		if a_source_level != b_source_level:
			return a_source_level > b_source_level
		var a_key := String(a.stable_id)
		var b_key := String(b.stable_id)
		var a_hash := _seeded_hash(a_key, world_seed)
		var b_hash := _seeded_hash(b_key, world_seed)
		return a_hash < b_hash if a_hash != b_hash else a_key < b_key)
	return qualified


static func _public_route_cells(plan: SettlementFabricPlan) -> Dictionary:
	## Older sectional proofs materialize public routes as ordinary recipe units;
	## volumetric towns instead compile the same facts into one authoritative
	## surface payload. Consumers ask for public route cells, not one producer's
	## representation.
	var out := plan.transformed_cells(&"walk", &"route")
	if plan.public_realm != null:
		for cell_value: Variant in plan.public_realm.surface_claims():
			out[cell_value as Vector3i] = &"public_realm"
	return out


static func _passes_sealed_plan_broad_phase(program: SettlementFabricProgram,
		plan: SettlementFabricPlan, candidate: Dictionary) -> bool:
	return candidate_set_passes(program, plan, [candidate])


static func candidate_set_passes(program: SettlementFabricProgram,
		plan: SettlementFabricPlan, candidates: Array) -> bool:
	## Mirror only facts the sealed plan already owns. This is deliberately not a
	## second admission policy: surviving candidates still go through
	## SettlementFabricSolver, while impossible candidates never cause a complete
	## public-surface and exterior-volume reconstruction.
	if program == null or plan == null or candidates.is_empty():
		return false
	var solid := plan.transformed_cells(&"solid")
	var walk := plan.transformed_cells(&"walk")
	var headroom := plan.transformed_cells(&"headroom")
	var public_air := plan.public_realm.air_claims() \
		if plan.public_realm != null else {}
	var candidate_solid: Dictionary = {}
	var candidate_walk: Dictionary = {}
	var candidate_headroom: Dictionary = {}
	var candidate_bounds: Array[Dictionary] = []
	for candidate_index in candidates.size():
		var candidate := candidates[candidate_index] as Dictionary
		for spec: Dictionary in candidate.specs as Array:
			if not _append_spec_broad_phase(program, spec, candidate_index,
					solid, walk, headroom, public_air, candidate_solid, candidate_walk,
					candidate_headroom, candidate_bounds):
				return false
	var existing_bounds: Array[Dictionary] = []
	for unit_value: FabricUnit in plan.units:
		var recipe_value := plan.recipe(unit_value.recipe_id)
		if recipe_value.placements.is_empty():
			continue
		existing_bounds.append({
			"unit_id": unit_value.stable_id,
			"bounds": unit_value.transform() * recipe_value.local_clearance_bounds,
		})
	for candidate_record: Dictionary in candidate_bounds:
		for existing_record: Dictionary in existing_bounds:
			if (candidate_record.allowed as Dictionary).has(
					existing_record.unit_id):
				continue
			if _aabb_overlaps_volume(candidate_record.bounds as AABB,
					existing_record.bounds as AABB):
				return false
	for left_index in candidate_bounds.size():
		var left := candidate_bounds[left_index] as Dictionary
		for right_index in range(left_index + 1, candidate_bounds.size()):
			var right := candidate_bounds[right_index] as Dictionary
			if int(left.group) == int(right.group) \
					or (left.allowed as Dictionary).has(right.unit_id) \
					or (right.allowed as Dictionary).has(left.unit_id):
				continue
			if _aabb_overlaps_volume(left.bounds as AABB, right.bounds as AABB):
				return false
	return true


static func _append_spec_broad_phase(program: SettlementFabricProgram,
		spec: Dictionary, group: int, solid: Dictionary, walk: Dictionary,
		headroom: Dictionary, public_air: Dictionary,
		candidate_solid: Dictionary,
		candidate_walk: Dictionary, candidate_headroom: Dictionary,
		candidate_bounds: Array[Dictionary]) -> bool:
	var recipe_value := program.recipe(StringName(spec.recipe_id))
	if recipe_value == null:
		return false
	var origin := spec.origin as Vector3i
	var yaw := int(spec.yaw_quarters)
	for local_cell: Vector3i in recipe_value.solid_cells:
		var cell := FabricRecipe.transform_cell(local_cell, origin, yaw)
		if solid.has(cell) or walk.has(cell) or headroom.has(cell) \
				or candidate_solid.has(cell) or candidate_walk.has(cell) \
				or candidate_headroom.has(cell):
			return false
		candidate_solid[cell] = true
	for local_cell: Vector3i in recipe_value.headroom_cells:
		var cell := FabricRecipe.transform_cell(local_cell, origin, yaw)
		if solid.has(cell) or headroom.has(cell) \
				or candidate_solid.has(cell) or candidate_headroom.has(cell):
			return false
		candidate_headroom[cell] = true
	for local_cell: Vector3i in recipe_value.walk_cells:
		var cell := FabricRecipe.transform_cell(local_cell, origin, yaw)
		if solid.has(cell) or walk.has(cell) \
				or candidate_solid.has(cell) or candidate_walk.has(cell):
			return false
		candidate_walk[cell] = true
	for local_cell: Vector3i in recipe_value.inhabited_cells:
		if public_air.has(FabricRecipe.transform_cell(local_cell, origin, yaw)):
			return false
	if recipe_value.placements.is_empty():
		return true
	var basis := Basis(Vector3.UP, float(posmod(yaw, 4)) * PI * 0.5)
	var bounds := Transform3D(basis,
		Vector3(origin) * FabricRecipe.CELL_SIZE) \
		* recipe_value.local_clearance_bounds
	var allowed: Dictionary = {}
	for id_value: Variant in spec.get("parents", []):
		allowed[StringName(id_value)] = true
	for id_value: Variant in spec.get("visual_seams", []):
		allowed[StringName(id_value)] = true
	for bond: Dictionary in spec.get("bonds", []):
		allowed[StringName(bond.target_unit)] = true
	candidate_bounds.append({
		"unit_id": StringName(spec.stable_id),
		"group": group,
		"bounds": bounds,
		"allowed": allowed,
	})
	return true


static func _aabb_overlaps_volume(left: AABB, right: AABB) -> bool:
	var overlap_x := minf(left.end.x, right.end.x) \
		- maxf(left.position.x, right.position.x)
	var overlap_y := minf(left.end.y, right.end.y) \
		- maxf(left.position.y, right.position.y)
	var overlap_z := minf(left.end.z, right.end.z) \
		- maxf(left.position.z, right.position.z)
	return overlap_x > 0.10 and overlap_y > 0.10 and overlap_z > 0.10


static func _candidate_lower_route_cover_count(candidate: Dictionary,
		program: SettlementFabricProgram, route_cells: Dictionary) -> int:
	## Rank inhabited overhead by the public maze it actually shelters. This is
	## deliberately only an ordering fact: the common transaction still decides
	## whether the candidate's complete occupied and visual envelopes fit.
	var covered: Dictionary = {}
	for spec: Dictionary in candidate.specs as Array:
		var recipe_value := program.recipe(StringName(spec.recipe_id))
		if recipe_value == null:
			continue
		var origin := spec.origin as Vector3i
		var yaw := int(spec.yaw_quarters)
		for local_cell: Vector3i in recipe_value.occluder_cells:
			var world_cell := FabricRecipe.transform_cell(local_cell, origin, yaw)
			for route_value: Variant in route_cells:
				var route_cell := route_value as Vector3i
				if route_cell.x == world_cell.x and route_cell.z == world_cell.z \
						and route_cell.y + 2 <= world_cell.y:
					covered[route_cell] = true
	return covered.size()


static func _room_endpoints(plan: SettlementFabricPlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for unit_value: FabricUnit in plan.units:
		var recipe_value := plan.recipe(unit_value.recipe_id)
		if recipe_value == null or (not recipe_value.has_tag(&"generated_building") \
				and not recipe_value.has_tag(&"outcropping") \
				and not recipe_value.has_tag(&"prefab_anchor")) \
				or recipe_value.has_tag(&"roof"):
			continue
		for socket: Dictionary in recipe_value.sockets:
			if int(socket.kind) != FabricRecipe.SocketKind.ROOM:
				continue
			var socket_id := StringName(socket.id)
			if not String(socket_id).begins_with("room."):
				continue
			var bearing_socket_id := StringName(String(socket_id).replace(
				"room.", "bearing."))
			var bearing_socket := recipe_value.socket(bearing_socket_id)
			if bearing_socket.is_empty() \
					or int(bearing_socket.kind) != FabricRecipe.SocketKind.BEARING:
				continue
			out.append({
				"unit_id": unit_value.stable_id,
				"socket_id": socket_id,
				"bearing_socket_id": bearing_socket_id,
				"cell": FabricRecipe.transform_cell(socket.cell as Vector3i,
					unit_value.lattice_origin, unit_value.yaw_quarters),
				"facing": FabricRecipe.transform_direction(
					socket.facing as Vector3i, unit_value.yaw_quarters),
				"bearing_cell": FabricRecipe.transform_cell(
					bearing_socket.cell as Vector3i, unit_value.lattice_origin,
					unit_value.yaw_quarters),
				"bearing_facing": FabricRecipe.transform_direction(
					bearing_socket.facing as Vector3i, unit_value.yaw_quarters),
			})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_key := "%s/%s" % [a.unit_id, a.socket_id]
		var b_key := "%s/%s" % [b.unit_id, b.socket_id]
		return a_key < b_key)
	return out


static func _skywalk_candidates(program: SettlementFabricProgram,
		plan: SettlementFabricPlan, endpoints: Array[Dictionary],
		_route_cells: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for left_index in endpoints.size():
		var left := endpoints[left_index]
		if String(left.socket_id).contains(".corner."):
			continue
		for right_index in range(left_index + 1, endpoints.size()):
			var right := endpoints[right_index]
			if String(right.socket_id).contains(".corner.") \
					or left.unit_id == right.unit_id \
					or (left.cell as Vector3i).y != (right.cell as Vector3i).y \
					or (left.facing as Vector3i) != -(right.facing as Vector3i):
				continue
			var delta := (right.cell as Vector3i) - (left.cell as Vector3i)
			var forward := left.facing as Vector3i
			var distance: int = delta.x * forward.x + delta.y * forward.y \
				+ delta.z * forward.z
			if distance < 3 or distance > 7 or distance % 2 == 0 \
					or delta != forward * distance:
				continue
			var segments: int = (distance - 1) / 2
			var recipe_id := &"skywalk.3.blue" if segments == 1 \
				else &"skywalk.6.orange" if segments == 2 else &"skywalk.9.blue"
			var recipe_value := program.recipe(recipe_id)
			var yaw := _yaw_for_facing(Vector3i.LEFT, -forward)
			var origin := _attached_origin(recipe_value, &"room.west", yaw,
				left.cell as Vector3i, forward)
			var stable_id := StringName("overhead.skywalk.%s.%s" % [
				_sanitize(left.unit_id), _sanitize(right.unit_id)])
			var visual_seams := _stack_visual_seams(plan,
				StringName(left.unit_id))
			for seam_id: StringName in _stack_visual_seams(plan,
					StringName(right.unit_id)):
				if not visual_seams.has(seam_id):
					visual_seams.append(seam_id)
			out.append({
				"category": &"skywalk",
				"source_ids": [left.unit_id, right.unit_id],
				"stable_id": stable_id,
				"specs": [SettlementFabricSolver.unit_spec(stable_id, recipe_id,
					origin, yaw, [left.unit_id, right.unit_id], [
						FabricUnit.bond(&"room.west", left.unit_id,
							left.socket_id),
						FabricUnit.bond(&"bearing.west", left.unit_id,
							left.bearing_socket_id),
						FabricUnit.bond(&"room.east", right.unit_id,
							right.socket_id),
						FabricUnit.bond(&"bearing.east", right.unit_id,
							right.bearing_socket_id),
					], &"", visual_seams)],
			})
	return out


static func _corner_skywalk_candidates(program: SettlementFabricProgram,
		plan: SettlementFabricPlan, endpoints: Array[Dictionary],
		_route_cells: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var corner_recipe := program.recipe(&"skywalk.corner.orange")
	for left_index in endpoints.size():
		var left := endpoints[left_index]
		if String(left.socket_id).contains(".corner."):
			continue
		for right_index in range(left_index + 1, endpoints.size()):
			var right := endpoints[right_index]
			var left_facing := left.facing as Vector3i
			var right_facing := right.facing as Vector3i
			if String(right.socket_id).contains(".corner.") \
					or left.unit_id == right.unit_id \
					or (left.cell as Vector3i).y != (right.cell as Vector3i).y \
					or left_facing.y != 0 or right_facing.y != 0 \
					or left_facing.x * right_facing.x \
						+ left_facing.z * right_facing.z != 0:
				continue
			for corner_yaw in 4:
				var left_corner_socket := _socket_facing(corner_recipe,
					FabricRecipe.SocketKind.ROOM, -left_facing, corner_yaw)
				var right_corner_socket := _socket_facing(corner_recipe,
					FabricRecipe.SocketKind.ROOM, -right_facing, corner_yaw)
				if left_corner_socket.is_empty() or right_corner_socket.is_empty() \
						or left_corner_socket.id == right_corner_socket.id:
					continue
				for left_distance in [3, 5, 7]:
					var desired_left: Vector3i = (left.cell as Vector3i) \
						+ left_facing * left_distance
					var corner_origin: Vector3i = desired_left \
						- FabricRecipe.transform_cell(
							left_corner_socket.cell as Vector3i,
							Vector3i.ZERO, corner_yaw)
					var right_corner_cell := FabricRecipe.transform_cell(
						right_corner_socket.cell as Vector3i, corner_origin,
						corner_yaw)
					var right_delta := right_corner_cell \
						- (right.cell as Vector3i)
					var right_distance := right_delta.x * right_facing.x \
						+ right_delta.z * right_facing.z
					if not [3, 5, 7].has(right_distance) \
							or right_delta != right_facing * right_distance:
						continue
					var candidate := _corner_motif(program, plan, left, right,
						left_corner_socket, right_corner_socket, corner_origin,
						corner_yaw, left_distance, right_distance)
					# A skywalk's semantic job is to join two inhabited stacks. It need
					# not happen to cross a cell on the primary itinerary: in a dense
					# three-dimensional maze, a short link over an occupied courtyard or
					# secondary void is still real circulation. Exact occupancy, bearing,
					# envelope, and reachability validation remain mandatory.
					if candidate.is_empty():
						continue
					out.append(candidate)
	return out


static func _corner_motif(program: SettlementFabricProgram,
		plan: SettlementFabricPlan, left: Dictionary, right: Dictionary,
		left_corner_socket: Dictionary,
		right_corner_socket: Dictionary, corner_origin: Vector3i,
		corner_yaw: int, left_distance: int, right_distance: int) -> Dictionary:
	var left_segments: int = (left_distance - 1) / 2
	var right_segments: int = (right_distance - 1) / 2
	var left_recipe_id := _cantilever_recipe(left_segments)
	var right_recipe_id := _cantilever_recipe(right_segments)
	var left_recipe := program.recipe(left_recipe_id)
	var right_recipe := program.recipe(right_recipe_id)
	var left_facing := left.facing as Vector3i
	var right_facing := right.facing as Vector3i
	var left_yaw := _yaw_for_facing(Vector3i.LEFT, -left_facing)
	var right_yaw := _yaw_for_facing(Vector3i.LEFT, right_facing)
	if left_yaw < 0 or right_yaw < 0:
		return {}
	var left_origin := _attached_origin(left_recipe, &"room.west", left_yaw,
		left.cell as Vector3i, left_facing)
	var corner_room_left := StringName(left_corner_socket.id)
	var corner_bearing_left := StringName(String(corner_room_left).replace(
		"room.", "bearing."))
	var corner_room_right := StringName(right_corner_socket.id)
	var corner_bearing_right := StringName(String(corner_room_right).replace(
		"room.", "bearing."))
	var corner_cell_right := FabricRecipe.transform_cell(
		right_corner_socket.cell as Vector3i, corner_origin, corner_yaw)
	var corner_facing_right := FabricRecipe.transform_direction(
		right_corner_socket.facing as Vector3i, corner_yaw)
	var right_origin := _attached_origin(right_recipe, &"room.west", right_yaw,
		corner_cell_right, corner_facing_right)
	var prefix := "overhead.corner.%s.%s" % [_sanitize(left.unit_id),
		_sanitize(right.unit_id)]
	var left_id := StringName("%s.arm-a" % prefix)
	var corner_id := StringName("%s.corner" % prefix)
	var right_id := StringName("%s.arm-b" % prefix)
	var left_visual_seams := _stack_visual_seams(plan,
		StringName(left.unit_id))
	var right_visual_seams := _stack_visual_seams(plan,
		StringName(right.unit_id))
	var specs: Array[Dictionary] = [
		SettlementFabricSolver.unit_spec(left_id, left_recipe_id, left_origin,
			left_yaw, [left.unit_id], [
				FabricUnit.bond(&"room.west", left.unit_id, left.socket_id),
				FabricUnit.bond(&"bearing.west", left.unit_id,
					left.bearing_socket_id),
			], &"", left_visual_seams),
		SettlementFabricSolver.unit_spec(corner_id, &"skywalk.corner.orange",
			corner_origin, corner_yaw, [left_id], [
				FabricUnit.bond(corner_room_left, left_id, &"room.east"),
				FabricUnit.bond(corner_bearing_left, left_id, &"bearing.east"),
			]),
		SettlementFabricSolver.unit_spec(right_id, right_recipe_id, right_origin,
			right_yaw, [corner_id], [
				FabricUnit.bond(&"room.west", corner_id, corner_room_right),
				FabricUnit.bond(&"bearing.west", corner_id,
					corner_bearing_right),
				FabricUnit.bond(&"room.east", right.unit_id, right.socket_id),
			], &"", right_visual_seams),
	]
	return {
		"category": &"skywalk",
		"source_ids": [left.unit_id, right.unit_id],
		"stable_id": StringName(prefix),
		"specs": specs,
		"components": [
			{"recipe": left_recipe, "origin": left_origin, "yaw": left_yaw},
			{"recipe": program.recipe(&"skywalk.corner.orange"),
				"origin": corner_origin, "yaw": corner_yaw},
			{"recipe": right_recipe, "origin": right_origin, "yaw": right_yaw},
		],
	}


static func _cantilever_recipe(segments: int) -> StringName:
	return &"skywalk.cantilever.3.blue" if segments == 1 \
		else &"skywalk.cantilever.6.orange" if segments == 2 \
		else &"skywalk.cantilever.9.blue"


static func _socket_facing(recipe_value: FabricRecipe, kind: int,
		world_facing: Vector3i, yaw: int) -> Dictionary:
	for socket: Dictionary in recipe_value.sockets:
		if int(socket.kind) == kind and FabricRecipe.transform_direction(
				socket.facing as Vector3i, yaw) == world_facing:
			return socket
	return {}


static func _outcrop_candidates(program: SettlementFabricProgram,
		plan: SettlementFabricPlan,
		endpoints: Array[Dictionary], route_cells: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for endpoint: Dictionary in endpoints:
		# Projections may frame a ground-rooted generated/prefab stack, but they
		# never become new cantilever roots. Recursively treating an accepted
		# outcrop as another facade generated weightless room chains whose bonds
		# were technically valid yet whose silhouette read as detached buildings.
		var source_unit := plan.unit(StringName(endpoint.unit_id))
		var source_recipe := plan.recipe(source_unit.recipe_id) \
			if source_unit != null else null
		if source_recipe == null or source_recipe.has_tag(&"outcropping"):
			continue
		# A projection must read as part of its parent house: every bay is one
		# shallow module deep, its wood (where it has wood walls) follows the
		# parent's wall family, and a roofed bay is an authored dormer whose
		# roof family matches the parent stack's roof. The seed-stable hash
		# keeps gable, shed, and flat-capped bays mixed across the town instead
		# of stamping one silhouette.
		var parent_socket := source_recipe.socket(StringName(endpoint.socket_id))
		if parent_socket.is_empty():
			continue
		var cool_stack := _stack_has_cool_roof(plan,
			StringName(endpoint.unit_id))
		var endpoint_cell := endpoint.cell as Vector3i
		var wood_family := _wood_family(source_unit.recipe_id)
		var orange := posmod(endpoint_cell.x * 31 + endpoint_cell.y * 17
			+ endpoint_cell.z * 13, 2) == 0
		# A wood-walled bay wears its parent's timber family, including the
		# third family the vocabulary wave added. Falling back to the parity
		# hash for an unrecognised parent would put an orange jetty on an amber
		# house -- the exact "projection reads as a different building" defect
		# `test_warren_outcrops` exists to catch.
		var bay_family := wood_family if wood_family != &"" \
			else &"orange" if orange else &"blue"
		if String(endpoint.socket_id).contains(".corner."):
			_append_corner_wrap_candidate(out, program, plan, endpoint,
				source_unit, bay_family)
			continue
		var variant_roll := posmod(endpoint_cell.x * 53 + endpoint_cell.y * 29
			+ endpoint_cell.z * 41, 4)
		var roof_token := "teal" if cool_stack else "orange"
		# A fourth bay family from the bake wave: the flat-capped jetty with an
		# authored flue standing on its deck. It is the same occupied bay as
		# `capped.corner` -- same cells, same sockets, same bonds -- so the only
		# thing the roll changes is which silhouette the facade cuts.
		var bay_variant := "dormer.gable.%s" % roof_token if variant_roll == 0 \
			else "dormer.shed.%s" % roof_token if variant_roll == 1 \
			else "capped.corner" if variant_roll == 2 else "flue.corner"
		# A half-raised occupied bay needs an authored internal stair before its
		# ROOM seam is traversable. Interiors are deliberately deferred, so only
		# level facade bays enter the external-circulation transaction for now.
		# The style list holds the two constructible half-face positions; the
		# former "centre" entry anchored to the same cells as corner.left and
		# only produced duplicate candidates.
		for style: StringName in [&"left", &"right"]:
			var half_raised := false
			var recipe_id := StringName("outcrop.%s.%s%s" % [
				bay_variant, String(style),
				".%s" % bay_family if bay_variant == "capped.corner" \
					or bay_variant == "flue.corner" else "",
			])
			var recipe_value := program.recipe(recipe_id)
			assert(recipe_value != null, String(recipe_id))
			var outward := endpoint.bearing_facing as Vector3i
			var yaw := _yaw_for_facing(Vector3i.FORWARD, -outward)
			var origin := _attached_origin(recipe_value, &"bearing.back", yaw,
				endpoint.bearing_cell as Vector3i, outward)
			# Route cover remains the first ranking signal, but facade articulation is
			# independently useful on a tall stack. Requiring every bay to overhang a
			# lower route left all middle storeys as identical uninterrupted panels.
			# Exact occupancy, parent seams, public air, and measured visual envelopes
			# still reject every impossible projection in the common transaction.
			var stable_id := StringName("overhead.outcrop.%s.%s.%s%s" % [
				_sanitize(endpoint.unit_id),
				String(endpoint.socket_id).trim_prefix("room."),
				String(style).replace(".", "-"),
				".half" if half_raised else ""])
			var visual_seams := _stack_visual_seams(plan,
				StringName(endpoint.unit_id))
			# The stack-facade key reserves one jetty per building column SIDE:
			# stacked repeats on one face read as a stamp, while bays on
			# different faces of the same column articulate it — and shallow
			# bays need that capacity to keep covering flanked streets.
			var stack_source := StringName("%s|%s" % [_stack_prefix(
				StringName(endpoint.unit_id)),
				endpoint.bearing_facing])
			out.append({
				"category": &"outcrop",
				"source_ids": [endpoint.unit_id, stack_source],
				"source_level": endpoint_cell.y,
				"stable_id": stable_id,
				"specs": [SettlementFabricSolver.unit_spec(stable_id, recipe_id,
					origin, yaw, [endpoint.unit_id], [
						FabricUnit.bond(&"bearing.back", endpoint.unit_id,
							endpoint.bearing_socket_id),
						# The projection is an occupied extension of the room, not a
						# weight-only decoration. Freeze the matching room seam so
						# reachability and future interior compilation cannot disagree.
						FabricUnit.bond(&"room.back", endpoint.unit_id,
							endpoint.socket_id),
					], &"", visual_seams)],
			})
	return out


static func _wood_family(recipe_id: StringName) -> StringName:
	var text := String(recipe_id)
	for family: StringName in WarrenAssetCompiler.UPPER_FACADE_FAMILIES:
		if text.contains(String(family)):
			return family
	return &""


static func _append_corner_wrap_candidate(out: Array[Dictionary],
		program: SettlementFabricProgram, plan: SettlementFabricPlan,
		endpoint: Dictionary, source_unit: FabricUnit,
		bay_family: StringName) -> void:
	## One corner oriel candidate per end-of-face socket: two overlapping
	## squares sharing the parent corner's diagonal. The wrap hand follows
	## which end of the face the socket names, resolved through both the
	## parent's and the bay's world yaws.
	var id_text := String(endpoint.socket_id)
	var side := id_text.get_slice(".", 3)
	var side_local: Vector3i = {
		"west": Vector3i(-1, 0, 0), "east": Vector3i(1, 0, 0),
		"north": Vector3i(0, 0, -1), "south": Vector3i(0, 0, 1),
	}.get(side, Vector3i.ZERO)
	if side_local == Vector3i.ZERO:
		return
	var outward := endpoint.bearing_facing as Vector3i
	var yaw := _yaw_for_facing(Vector3i.FORWARD, -outward)
	if yaw < 0:
		return
	var side_world := FabricRecipe.transform_direction(side_local,
		source_unit.yaw_quarters)
	var bay_right := FabricRecipe.transform_direction(Vector3i.RIGHT, yaw)
	var hand := "right" if side_world == bay_right else "left"
	var recipe_id := StringName("outcrop.corner.wrap.%s.%s" % [hand,
		bay_family])
	var recipe_value := program.recipe(recipe_id)
	assert(recipe_value != null, String(recipe_id))
	var origin := _attached_origin(recipe_value, &"bearing.back", yaw,
		endpoint.bearing_cell as Vector3i, outward)
	var stable_id := StringName("overhead.outcrop.%s.%s.wrap" % [
		_sanitize(endpoint.unit_id),
		String(endpoint.socket_id).trim_prefix("room.corner.")])
	var visual_seams := _stack_visual_seams(plan,
		StringName(endpoint.unit_id))
	var stack_source := StringName("%s|%s" % [_stack_prefix(
		StringName(endpoint.unit_id)), outward])
	out.append({
		"category": &"outcrop",
		"source_ids": [endpoint.unit_id, stack_source],
		"source_level": (endpoint.cell as Vector3i).y,
		"stable_id": stable_id,
		"specs": [SettlementFabricSolver.unit_spec(stable_id, recipe_id,
			origin, yaw, [endpoint.unit_id], [
				FabricUnit.bond(&"bearing.back", endpoint.unit_id,
					endpoint.bearing_socket_id),
				FabricUnit.bond(&"room.back", endpoint.unit_id,
					endpoint.socket_id),
			], &"", visual_seams)],
	})


static func _stack_prefix(unit_id: StringName) -> String:
	var id_text := String(unit_id)
	var marker := id_text.find(".base")
	if marker < 0:
		marker = id_text.find(".upper.")
	return id_text.substr(0, marker) if marker >= 0 else id_text


static func _stack_has_cool_roof(plan: SettlementFabricPlan,
		unit_id: StringName) -> bool:
	## The parent stack's roof units decide whether the always-orange compact
	## bay gable can join it. Asset ids are the authority: recipe names also
	## contain colour tokens, but only placements name the rendered material.
	var prefix := _stack_prefix(unit_id)
	for candidate: FabricUnit in plan.units:
		if not String(candidate.stable_id).begins_with(prefix + "."):
			continue
		var recipe_value := plan.recipe(candidate.recipe_id)
		if recipe_value == null or not recipe_value.has_tag(&"roof"):
			continue
		for placement: Dictionary in recipe_value.placements:
			if String(placement.asset_id).contains(".blue."):
				return true
	return false


static func _stack_visual_seams(plan: SettlementFabricPlan,
		unit_id: StringName) -> Array[StringName]:
	## An outcrop is framed into one vertical building stack. Eaves and the next
	## storey's facade may deliberately meet that framed joint, so declare the
	## complete semantic stack—not unrelated neighbors—as its construction seam.
	var id_text := String(unit_id)
	var marker := id_text.find(".base")
	if marker < 0:
		marker = id_text.find(".upper.")
	var prefix := id_text.substr(0, marker) if marker >= 0 else id_text
	var out: Array[StringName] = []
	for candidate: FabricUnit in plan.units:
		if String(candidate.stable_id).begins_with(prefix + "."):
			out.append(candidate.stable_id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out


static func _covers_lower_route(recipe_value: FabricRecipe, origin: Vector3i,
		yaw: int, route_cells: Dictionary) -> bool:
	for local_cell: Vector3i in recipe_value.occluder_cells:
		var world_cell := FabricRecipe.transform_cell(local_cell, origin, yaw)
		for route_value: Variant in route_cells:
			var route_cell := route_value as Vector3i
			if route_cell.x == world_cell.x and route_cell.z == world_cell.z \
					and route_cell.y + 2 <= origin.y:
				return true
	return false


static func _attached_origin(recipe_value: FabricRecipe,
		own_socket_id: StringName, yaw: int, target_cell: Vector3i,
		target_facing: Vector3i) -> Vector3i:
	var own_socket := recipe_value.socket(own_socket_id)
	var rotated_own_cell := FabricRecipe.transform_cell(own_socket.cell,
		Vector3i.ZERO, yaw)
	return target_cell + target_facing - rotated_own_cell


static func _yaw_for_facing(local_facing: Vector3i,
		world_facing: Vector3i) -> int:
	for yaw in 4:
		if FabricRecipe.transform_direction(local_facing, yaw) == world_facing:
			return yaw
	return -1


static func _seeded_hash(value: String, seed: int) -> int:
	var hash_value := seed ^ 0x4f1bbcdc
	for byte in value.to_utf8_buffer():
		hash_value = int((hash_value ^ int(byte)) * 16777619) & 0x7fffffff
	return hash_value


static func _sanitize(value: StringName) -> String:
	return String(value).replace(".", "-")
