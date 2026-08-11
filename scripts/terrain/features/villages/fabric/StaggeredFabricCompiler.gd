class_name StaggeredFabricCompiler
extends RefCounted

## Converts plain-data solid/void proposals into the same supported FabricUnit
## specs used by authored proofs and future production generation. Every
## proposal becomes a complete ground-rooted room stack with a roof; no
## proposal is ever rendered as a proxy box or admitted without ancestry. A
## half-level base is an explicit retained-perch obligation, never permission to
## invent a tall natural-terrain column.
const ROOM_MINIMUM := Vector3i(-2, 0, -2)
const MARKET_MINIMUM := Vector3i(-2, 0, -1)
const MARKET_SIZE := Vector3i(4, 3, 2)
const TOWER_MINIMUM := Vector3i(-1, 0, -1)
const MICRO_MINIMUM := Vector3i(-1, 0, -2)
const SLIM_MINIMUM := Vector3i(-1, 0, -2)
const LONG_MINIMUM := Vector3i(-2, 0, -3)
const MAX_PROPOSAL_STOREYS := 8


static func append_specs(program: SettlementFabricProgram,
		embedding: StaggeredFabricEmbeddingPlan, specs: Array[Dictionary],
		by_id: Dictionary) -> bool:
	if program == null or embedding == null or not embedding.validate():
		return false
	for recipe_id: StringName in [&"room.base.rock", &"room.base.rock.closed",
			&"room.base.blue", &"room.base.blue.closed",
			&"room.base.orange", &"room.base.orange.closed",
			&"room.base.amber", &"room.base.amber.closed",
			&"room.upper.blue", &"room.upper.orange", &"room.upper.amber",
			&"room.upper.stone",
			&"room.upper.blue.b", &"room.upper.orange.b", &"room.upper.amber.b",
			&"room.upper.stone.b",
			&"room.upper.address.blue", &"room.upper.address.orange",
			&"room.upper.address.amber",
			&"room.upper.address.stone", &"room.upper.address.blue.b",
			&"room.upper.address.orange.b", &"room.upper.address.amber.b",
			&"room.upper.address.stone.b",
			&"room.long.base.rock", &"room.long.base.rock.closed",
			&"room.long.base.blue", &"room.long.base.blue.closed",
			&"room.long.base.orange", &"room.long.base.orange.closed",
			&"room.long.base.amber", &"room.long.base.amber.closed",
			&"room.long.upper.blue.a", &"room.long.upper.blue.b",
			&"room.long.upper.orange.a", &"room.long.upper.orange.b",
			&"room.long.upper.amber.a", &"room.long.upper.amber.b",
			&"room.long.upper.stone.a", &"room.long.upper.stone.b",
			&"room.long.upper.address.blue.a",
			&"room.long.upper.address.blue.b",
			&"room.long.upper.address.orange.a",
			&"room.long.upper.address.orange.b",
			&"room.long.upper.address.amber.a",
			&"room.long.upper.address.amber.b",
			&"room.long.upper.address.stone.a",
			&"room.long.upper.address.stone.b",
			&"roof.long.blue", &"roof.long.orange",
			&"roof.long.blue.dormer.left", &"roof.long.blue.dormer.right",
			&"roof.long.orange.dormer.left", &"roof.long.orange.dormer.right",
			&"roof.long.blue.dormer.pair.left",
			&"roof.long.blue.dormer.pair.right",
			&"roof.long.orange.dormer.pair.left",
			&"roof.long.orange.dormer.pair.right",
			&"roof.square.01", &"roof.square.02", &"roof.square.04",
			&"roof.square.05",
			&"roof.square.blue.plain", &"roof.square.orange.plain",
			&"room.tower.base.rock", &"room.tower.base.rock.closed",
			&"room.tower.base.blue", &"room.tower.base.blue.closed",
			&"room.tower.base.orange", &"room.tower.base.orange.closed",
			&"room.tower.base.amber", &"room.tower.base.amber.closed",
			&"room.tower.upper.blue", &"room.tower.upper.orange",
			&"room.tower.upper.amber",
			&"room.tower.upper.stone", &"room.tower.upper.blue.b",
			&"room.tower.upper.orange.b", &"room.tower.upper.amber.b",
			&"room.tower.upper.stone.b",
			&"room.tower.upper.address.blue", &"room.tower.upper.address.orange",
			&"room.tower.upper.address.amber",
			&"room.tower.upper.address.stone",
			&"room.tower.upper.address.blue.b",
			&"room.tower.upper.address.orange.b",
			&"room.tower.upper.address.amber.b",
			&"room.tower.upper.address.stone.b",
			&"roof.tower.blue", &"roof.tower.orange",
			&"roof.tower.chimney.blue", &"roof.tower.chimney.orange",
			&"roof.tower.short.blue", &"roof.tower.short.orange",
			&"roof.flat.tower", &"roof.flat.slim", &"roof.flat.square",
			&"roof.flat.long",
			&"room.slim.base.rock", &"room.slim.base.rock.closed",
			&"room.slim.base.blue", &"room.slim.base.blue.closed",
			&"room.slim.base.orange", &"room.slim.base.orange.closed",
			&"room.slim.base.amber", &"room.slim.base.amber.closed",
			&"room.slim.upper.blue", &"room.slim.upper.orange",
			&"room.slim.upper.amber",
			&"room.slim.upper.stone", &"room.slim.upper.blue.b",
			&"room.slim.upper.orange.b", &"room.slim.upper.amber.b",
			&"room.slim.upper.stone.b",
			&"room.slim.upper.address.blue", &"room.slim.upper.address.orange",
			&"room.slim.upper.address.amber",
			&"room.slim.upper.address.stone",
			&"room.slim.upper.address.blue.b",
			&"room.slim.upper.address.orange.b",
			&"room.slim.upper.address.amber.b",
			&"room.slim.upper.address.stone.b",
			&"roof.slim.blue", &"roof.slim.orange",
			&"roof.slim.chimney.blue", &"roof.slim.chimney.orange",
			&"roof.slim.short.blue", &"roof.slim.short.orange",
			&"roof.blue", &"roof.orange",
			&"roof.short.blue", &"roof.short.orange",
			&"room.micro.terrain.blue", &"room.micro.terrain.orange"]:
		if program.recipe(recipe_id) == null:
			return false
	var seams_by_proposal := _tower_seams(embedding.barrier_proposals)
	for proposal: Dictionary in embedding.barrier_proposals:
		if not _append_proposal(program, proposal, specs, by_id,
				seams_by_proposal.get(StringName(proposal.stable_id), []) as Array):
			return false
	return true


static func append_proposals(program: SettlementFabricProgram,
		proposals: Array[Dictionary], specs: Array[Dictionary],
		by_id: Dictionary) -> bool:
	## Compile a small set of proposals that another coupled search stage has
	## already chosen. This is the same expansion used by the general embedder;
	## it exists so an itinerary episode can atomically reserve the occupied
	## corner or central mass that gives the route its shape before the remaining
	## frontage search runs. It is not a proxy-building shortcut: every proposal
	## still becomes the complete supported room/floor/roof stack and the common
	## transaction remains authoritative.
	if program == null or proposals.is_empty():
		return false
	var normalized: Array[Dictionary] = []
	for source: Dictionary in proposals:
		var proposal := source.duplicate(true)
		if (proposal.get("occupied_cells", []) as Array).is_empty():
			proposal["occupied_cells"] = proposal_occupied_cells(proposal)
		normalized.append(proposal)
	var seams_by_proposal := _tower_seams(normalized)
	for proposal: Dictionary in normalized:
		var proposal_id := StringName(proposal.get("stable_id", ""))
		if proposal_id.is_empty() or not _append_proposal(program, proposal,
				specs, by_id, seams_by_proposal.get(proposal_id, []) as Array):
			return false
	return true


static func proposal_occupied_cells(proposal: Dictionary) -> Array[Vector3i]:
	## Canonical conservative construction envelope for grammar-owned plots and
	## search candidates. Keeping it beside proposal_components() means a motif
	## never copies search-only footprint arithmetic to establish party walls.
	var origin := proposal.get("origin", Vector3i()) as Vector3i
	var storeys := int(proposal.get("storeys", 0))
	var yaw := int(proposal.get("yaw_quarters", 0))
	var kind := StringName(proposal.get("kind", ""))
	var minimum := ROOM_MINIMUM
	var size := Vector3i(4, storeys * 2 + 2, 4)
	if kind == &"market":
		minimum = MARKET_MINIMUM
		size = MARKET_SIZE
	elif kind == &"tower":
		minimum = TOWER_MINIMUM
		size = Vector3i(2, storeys * 2 + 2, 2)
	elif kind == &"micro":
		minimum = MICRO_MINIMUM
		size = Vector3i(2, 4, 4)
	elif kind == &"slim":
		minimum = SLIM_MINIMUM
		size = Vector3i(2, storeys * 2 + 2, 4)
	elif kind == &"long":
		minimum = LONG_MINIMUM
		size = Vector3i(4, storeys * 2 + 2, 6)
	var out: Array[Vector3i] = []
	for local_cell: Vector3i in FabricRecipe.box_cells(minimum, size):
		out.append(FabricRecipe.transform_cell(local_cell, origin, yaw))
	return out


static func classified_roof_seam_compatible(left: Dictionary,
		right: Dictionary) -> bool:
	## The roof classifier and module table are the sole authority for intentional
	## party-wall overlap. This mirrors cliff construction: adjacency produces a
	## finite local signature, and only a signature with an implemented module may
	## bypass generic AABB rejection. Keeping a second handwritten yaw/height/eave
	## predicate here let search and final roof assembly drift apart.
	var topology := FabricRoofTopologyPlan.build([left, right])
	if topology == null or int(topology.audit.junction_count) != 1:
		return false
	var left_id := StringName(left.get("stable_id", ""))
	var seams := topology.fact(left_id).get("junctions", []) as Array
	if seams.size() != 1:
		return false
	# The finite module table is also the clearance contract. Continuous ridges
	# and closed gable abutments need their authored eaves to meet, so leaving
	# them under generic visual-AABB clearance creates artificial alleys between
	# every otherwise legal party wall. Conversely, perpendicular valleys remain
	# ineligible because their atomic bisected-roof substitution is not yet
	# implemented. Do not duplicate that distinction here: a new topology becomes
	# admissible only when the construction table can build it.
	return not FabricRoofJunctionModuleTable.build([left, right], topology).is_empty()


static func inhabited_party_wall_compatible(left: Dictionary,
		right: Dictionary) -> bool:
	## Dense massif parcels are allowed to meet on a logical construction face
	## even when their roofs finish at different levels.  Test exact 3-D room
	## occupancy rather than only the ground footprint: the partition may stack a
	## second house above an earlier roof as well as place party walls side by
	## side.  Disjointness plus six-neighbour contact means this cannot turn a
	## street gap, corner nick, or unsupported overhang into a seam.
	var left_cells := proposal_occupied_cells(left)
	var right_cells := proposal_occupied_cells(right)
	if left_cells.is_empty() or right_cells.is_empty():
		return false
	var right_set: Dictionary = {}
	for cell: Vector3i in right_cells:
		right_set[cell] = true
	for cell: Vector3i in left_cells:
		if right_set.has(cell):
			return false
	for cell: Vector3i in left_cells:
		for direction: Vector3i in [Vector3i.RIGHT, Vector3i.LEFT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			if right_set.has(cell + direction):
				return true
	return false


static func proposals_share_corner(left: Dictionary,
		right: Dictionary) -> bool:
	## Exact diagonal macro contact. Pitched roofs overhang this point and need
	## a flush cap on both participants; face neighbours remain ordinary party
	## walls with classified roof junctions.
	var left_columns := _proposal_ground_columns(left)
	var right_columns := _proposal_ground_columns(right)
	if left_columns.is_empty() or right_columns.is_empty():
		return false
	for column: Vector2i in left_columns:
		if right_columns.has(column):
			return false
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
				Vector2i.UP, Vector2i.DOWN]:
			if right_columns.has(column + direction):
				return false
	for column: Vector2i in left_columns:
		for diagonal: Vector2i in [Vector2i(1, 1), Vector2i(1, -1),
				Vector2i(-1, 1), Vector2i(-1, -1)]:
			if right_columns.has(column + diagonal):
				return true
	return false


static func tower_seam_compatible(left: Dictionary,
		right: Dictionary) -> bool:
	## Compatibility alias retained for older diagnostic fixtures. New code names
	## the actual invariant instead of the original tower-only implementation.
	return classified_roof_seam_compatible(left, right)


static func _proposal_ground_columns(proposal: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var origin := proposal.get("origin", Vector3i()) as Vector3i
	var kind := StringName(proposal.get("kind", ""))
	var minimum := ROOM_MINIMUM
	var size := Vector3i(4, 1, 4)
	if kind == &"tower":
		minimum = TOWER_MINIMUM
		size = Vector3i(2, 1, 2)
	elif kind == &"slim":
		minimum = SLIM_MINIMUM
		size = Vector3i(2, 1, 4)
	elif kind == &"long":
		minimum = LONG_MINIMUM
		size = Vector3i(4, 1, 6)
	else:
		if kind != &"building":
			return out
	var yaw := int(proposal.get("yaw_quarters", -1))
	if yaw < 0 or yaw > 3:
		return out
	for cell: Vector3i in FabricRecipe.box_cells(minimum, size):
		var world := FabricRecipe.transform_cell(cell, origin, yaw)
		out[Vector2i(world.x, world.z)] = true
	return out


static func _tower_seams(proposals: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for proposal: Dictionary in proposals:
		out[StringName(proposal.stable_id)] = [] as Array[StringName]
	for left_index in proposals.size():
		var left := proposals[left_index]
		for right_index in range(left_index + 1, proposals.size()):
			var right := proposals[right_index]
			if not classified_roof_seam_compatible(left, right):
				continue
			var left_id := StringName(left.stable_id)
			var right_id := StringName(right.stable_id)
			var right_seams := out[right_id] as Array[StringName]
			# Units are committed in proposal order and visual seam references obey
			# the same sealed-parent rule as every other relationship. Only the later
			# tower needs to name already-built neighbours; a symmetric future
			# reference made otherwise valid party-wall rows fail transactionally.
			right_seams.append_array(_component_ids(left))
	return out


static func _component_ids(proposal: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var prefix := StringName("embedding.%s" % StringName(proposal.stable_id))
	for component: Dictionary in proposal_components(proposal):
		var role := StringName(component.role)
		out.append(prefix if role == &"market" \
			else StringName("%s.%s" % [prefix, role]))
	return out


static func proposal_components(proposal: Dictionary) -> Array[Dictionary]:
	## The one canonical expansion from a search proposal to its complete visual
	## stack. Both search-time envelope qualification and final spec compilation
	## consume this result, so a roof or theme variant can never appear only
	## after a candidate has been accepted.
	var out: Array[Dictionary] = []
	var proposal_id := StringName(proposal.get("stable_id", ""))
	var origin := proposal.get("origin", Vector3i()) as Vector3i
	var storeys := int(proposal.get("storeys", 0))
	var route_y := int(proposal.get("route_y", -2147483648))
	var yaw := int(proposal.get("yaw_quarters", -1))
	var kind := StringName(proposal.get("kind", ""))
	# Search candidates do not receive their semantic stable id until accepted;
	# their component geometry must nevertheless be identical to final output.
	if yaw < 0 or yaw > 3:
		return out
	if kind == &"market":
		var family := int(proposal.get("market_family", market_family(origin)))
		if family < 0 or family >= SettlementFabricProgram.MARKET_STALLS.size():
			return out
		out.append({
			"role": &"market",
			"recipe_id": StringName("market.stall.%02d" % family),
			"origin": origin,
			"yaw_quarters": yaw,
		})
		return out
	if kind == &"micro":
		out.append({
			"role": &"base",
			"recipe_id": &"room.micro.terrain.orange" \
				if _orange_theme(origin) else &"room.micro.terrain.blue",
			"origin": origin,
			"yaw_quarters": yaw,
		})
		return out
	if kind != &"building" and kind != &"tower" and kind != &"slim" \
			and kind != &"long" \
			or storeys < 1 or storeys > MAX_PROPOSAL_STOREYS:
		return out
	var is_tower := kind == &"tower"
	var is_slim := kind == &"slim"
	var is_long := kind == &"long"
	var facade_family := _proposal_facade_family(proposal, origin)
	var ground_theme := StringName(proposal.get("ground_theme", &"rock"))
	if ground_theme not in [&"rock", &"blue", &"orange", &"amber"]:
		return out
	var storey_themes := proposal.get("storey_themes", []) as Array
	var flush_facades := bool(proposal.get("flush_facades", false))
	var roof_orange := StringName(proposal.get("roof_theme",
		&"orange" if _orange_theme(origin) else &"blue")) == &"orange"
	var facade_phase := int(proposal.get("facade_phase",
		posmod(origin.x + origin.z, 2)))
	var base_prefix := "room.long.base" if is_long \
		else "room.slim.base" if is_slim \
		else "room.tower.base" if is_tower else "room.base"
	var base_recipe := StringName("%s.%s%s" % [base_prefix,
		String(ground_theme), "" if origin.y == route_y else ".closed"])
	out.append({"role": &"base", "recipe_id": base_recipe,
		"origin": origin, "yaw_quarters": yaw})
	for level in range(1, storeys):
		var addressed_upper := origin.y + level * 2 == route_y
		var level_theme := facade_family
		if level < storey_themes.size():
			level_theme = StringName(storey_themes[level])
		if level_theme == &"rock":
			level_theme = &"stone"
		if level_theme not in [&"blue", &"orange", &"amber", &"stone"]:
			return []
		var use_phase_b := not flush_facades \
			and posmod(facade_phase + level, 2) != 0
		var long_phase := "b" if use_phase_b \
			else "a"
		var long_theme := String(level_theme)
		var long_prefix := "room.long.upper.address" if addressed_upper \
			else "room.long.upper"
		var upper_recipe: StringName
		if is_long:
			upper_recipe = StringName("%s.%s.%s" % [long_prefix, long_theme,
				long_phase])
		elif is_slim:
			var slim_prefix := "room.slim.upper.address" if addressed_upper \
				else "room.slim.upper"
			var slim_theme := String(level_theme)
			var slim_phase := ".b" if use_phase_b else ""
			upper_recipe = StringName("%s.%s%s" % [slim_prefix,
				slim_theme, slim_phase])
		else:
			var prefix := "room.tower.upper" if is_tower else "room.upper"
			if addressed_upper:
				prefix += ".address"
			var theme := String(level_theme)
			var phase_suffix := ".b" if use_phase_b else ""
			upper_recipe = StringName("%s.%s%s" % [prefix, theme, phase_suffix])
		out.append({
			"role": StringName("upper.%02d" % level),
			"recipe_id": upper_recipe,
			"origin": origin + Vector3i(0, level * 2, 0),
			"yaw_quarters": yaw,
		})
	var roof_feature := int(proposal.get("roof_feature", 0))
	# Dormer colour is part of the finite roof recipe, never a tint applied after
	# clearance. The source vocabulary contains distinct orange and blue attic
	# shells, so both roof families can keep their material seam continuous.
	var roof_junction_rules := proposal.get("roof_junction_rules", []) as Array
	var atomic_valley_rules: Array[Dictionary] = []
	for rule: Dictionary in roof_junction_rules:
		if StringName(rule.get("module_family", "")) == &"bisected_valley":
			atomic_valley_rules.append(rule)
	# One roof may own one atomic T-junction. A multi-valley roof needs a distinct
	# finite cross-gable recipe and remains ineligible until that vocabulary is
	# authored; silently choosing one rule would reintroduce intersecting meshes.
	if atomic_valley_rules.size() > 1:
		return []
	# Equal-band ridge continuations and parallel valleys visually join two
	# roofs through shared flashing. The LPFV complete shells sit ~0.6 m lower
	# than the SFV modular runs, so a joined pair mixing the two families reads
	# as a broken ridge; joined square roofs therefore always build from the
	# modular family, and the shells stay vocabulary for stepped or isolated
	# roofs.
	var equal_band_flashed := false
	for rule: Dictionary in roof_junction_rules:
		if int(rule.get("height_delta", 1)) == 0 and int(rule.get("kind", -1)) in [
				FabricRoofTopologyPlan.JunctionKind.RIDGE_CONTINUATION,
				FabricRoofTopologyPlan.JunctionKind.PARALLEL_VALLEY]:
			equal_band_flashed = true
	var roof_recipe := &""
	var flat_roof := bool(proposal.get("flat_roof", false))
	if flat_roof:
		roof_recipe = &"roof.flat.long" if is_long \
			else &"roof.flat.slim" if is_slim \
			else &"roof.flat.tower" if is_tower else &"roof.flat.square"
	elif atomic_valley_rules.size() == 1:
		var atomic_rule := atomic_valley_rules[0]
		var theme := &"orange" if roof_orange else &"blue"
		var atomic_role := StringName(atomic_rule.get("atomic_role", ""))
		if atomic_role == &"host":
			roof_recipe = FabricRoofJunctionModuleTable \
				.bisected_valley_recipe_id(kind, theme,
					int(atomic_rule.run_offset_half_steps), int(atomic_rule.side))
		elif atomic_role == &"branch":
			roof_recipe = FabricRoofJunctionModuleTable.open_gable_recipe_id(
				kind, theme, int(atomic_rule.side))
		if roof_recipe.is_empty():
			return []
	else:
		roof_recipe = StringName("roof.long.%s.dormer.%s%s" % [
			"orange" if roof_orange else "blue",
				"pair." if roof_feature in [4, 5] else "",
				"left" if roof_feature in [1, 4] else "right"]) \
			if is_long and roof_feature in [1, 2, 4, 5] \
		else &"roof.long.orange" if is_long and roof_orange \
		else &"roof.long.blue" if is_long \
		else &"roof.slim.chimney.orange" if is_slim \
		and roof_feature == 3 and roof_orange \
		else &"roof.slim.chimney.blue" if is_slim and roof_feature == 3 \
		else &"roof.slim.short.orange" \
		if is_slim and storeys == 1 and roof_orange \
		else &"roof.slim.short.blue" if is_slim and storeys == 1 \
		else &"roof.slim.orange" if is_slim and roof_orange \
		else &"roof.slim.blue" if is_slim \
		else &"roof.tower.chimney.orange" if is_tower \
		and roof_feature == 3 and roof_orange \
		else &"roof.tower.chimney.blue" if is_tower and roof_feature == 3 \
		else &"roof.tower.short.orange" if is_tower and storeys == 1 \
		and roof_orange \
		else &"roof.tower.short.blue" if is_tower and storeys == 1 \
		else &"roof.tower.orange" if is_tower and roof_orange \
		else &"roof.tower.blue" if is_tower \
		else &"roof.short.orange" if storeys == 1 and roof_orange \
		else &"roof.short.blue" if storeys == 1 \
		else StringName("roof.square.%s.dormer.%s" % [
			"orange" if roof_orange else "blue",
			"left" if roof_feature == 1 else "right"]) \
			if roof_feature in [1, 2] \
		else &"roof.square.orange.plain" if equal_band_flashed and roof_orange \
		else &"roof.square.blue.plain" if equal_band_flashed \
		else &"roof.square.04" if roof_orange and roof_feature == 3 \
		else &"roof.square.01" if roof_orange \
		else &"roof.square.05" if roof_feature == 3 else &"roof.square.02"
	out.append({"role": &"roof", "recipe_id": roof_recipe,
		"origin": origin + Vector3i(0, storeys * 2, 0),
		"yaw_quarters": yaw})
	for rule_index in roof_junction_rules.size():
		if flat_roof:
			break
		var rule := roof_junction_rules[rule_index] as Dictionary
		if not bool(rule.get("emits_module", false)) \
				or StringName(rule.get("module_family", "")) != &"eave_seam":
			continue
		var side := int(rule.side)
		if side != FabricRoofTopologyPlan.Side.EAVE_NEGATIVE \
				and side != FabricRoofTopologyPlan.Side.EAVE_POSITIVE:
			continue
		var side_name := "negative" \
			if side == FabricRoofTopologyPlan.Side.EAVE_NEGATIVE else "positive"
		var seam_recipe_id := FabricRoofJunctionModuleTable.eave_seam_recipe_id(
			kind, int(rule.face_cells), int(rule.run_offset_half_steps), side)
		if seam_recipe_id.is_empty():
			return []
		out.append({
			"role": StringName("roof.trim.%s.%02d" % [side_name, rule_index]),
			"recipe_id": seam_recipe_id,
			"origin": origin + Vector3i(0, storeys * 2, 0),
			"yaw_quarters": yaw,
			"roof_junction_side": side,
		})
	return out


static func market_family(origin: Vector3i) -> int:
	## Market stalls form a visible run, so consecutive plots should cycle rather
	## than accidentally collide under a generic world hash. The diagonal lattice
	## phase changes on either orthogonal step and remains independent of proposal
	## order; the search can therefore reason about actual family diversity.
	return posmod(origin.x + origin.z + floori(float(origin.z) / 5.0),
		SettlementFabricProgram.MARKET_STALLS.size())


static func _append_proposal(program: SettlementFabricProgram,
		proposal: Dictionary, specs: Array[Dictionary], by_id: Dictionary,
		party_wall_seams: Array = []) -> bool:
	var proposal_id := StringName(proposal.get("stable_id", ""))
	var components := proposal_components(proposal)
	if proposal_id.is_empty() or components.is_empty():
		return false
	var prefix := StringName("embedding.%s" % proposal_id)
	var parent_id := &""
	var roof_id := &""
	for component: Dictionary in components:
		var recipe_id := StringName(component.recipe_id)
		if program.recipe(recipe_id) == null:
			return false
		var role := StringName(component.role)
		var stable_id := prefix if role == &"market" \
			else StringName("%s.%s" % [prefix, role])
		var parents: Array[StringName] = []
		var bonds: Array[Dictionary] = []
		if role == &"roof":
			roof_id = stable_id
		if String(role).begins_with("roof.trim."):
			if roof_id.is_empty():
				return false
			parents.append(roof_id)
			var side_name := "negative" if int(component.roof_junction_side) \
				== FabricRoofTopologyPlan.Side.EAVE_NEGATIVE else "positive"
			bonds.append(FabricUnit.bond(&"bearing.bottom", roof_id,
				StringName("bearing.junction.eave.%s" % side_name)))
		elif not parent_id.is_empty():
			parents.append(parent_id)
			bonds.append(FabricUnit.bond(&"bearing.bottom", parent_id,
				&"bearing.top"))
		if not _put(specs, by_id, SettlementFabricSolver.unit_spec(stable_id,
				recipe_id, component.origin as Vector3i,
				int(component.yaw_quarters), parents, bonds, &"", party_wall_seams,
				role == &"market")):
			return false
		if not String(role).begins_with("roof.trim."):
			parent_id = stable_id
	return true


static func _put(specs: Array[Dictionary], by_id: Dictionary,
		spec: Dictionary) -> bool:
	var stable_id := StringName(spec.get("stable_id", ""))
	if stable_id.is_empty() or by_id.has(stable_id):
		return false
	specs.append(spec)
	by_id[stable_id] = spec
	return true


static func _orange_theme(origin: Vector3i) -> bool:
	# Spatial parity keeps neighboring stacks varied while remaining stable
	# under query order and independent of proposal insertion ordinals.
	return posmod(origin.x * 31 + origin.y * 17 + origin.z * 13, 2) == 0


static func _proposal_facade_family(proposal: Dictionary,
		origin: Vector3i) -> StringName:
	var theme := StringName(proposal.get("theme", ""))
	assert(theme.is_empty() or theme in [&"blue", &"orange", &"amber",
		&"stone"])
	return theme if not theme.is_empty() \
		else &"orange" if _orange_theme(origin) else &"blue"
