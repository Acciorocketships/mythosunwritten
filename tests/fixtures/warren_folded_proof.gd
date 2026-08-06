extends RefCounted

const WarrenRisingRingPlanner = preload(
	"res://scripts/terrain/features/villages/fabric/WarrenRisingRingPlanner.gd")

## Fixed adversarial composition for the warren grammar. It deliberately uses
## only ordinary recipe records: production search must eventually emit the
## same data, while this fixture remains a stable visual regression target.

const REQUIREMENTS := {
	"route_cell_count": 40,
	"public_walk_unit_count": 14,
	"room_unit_count": 8,
	"generated_building_count": 6,
	"prefab_anchor_count": 2,
	"prefab_source_family_count": 2,
	"market_count": 4,
	"market_family_count": 4,
	"outcropping_count": 3,
	"skywalk_count": 2,
	"overhead_occupied_count": 4,
	"stair_count": 3,
	"vertical_span_cells": 6,
	"sectional_elevation_change_count": 6,
	"primary_has_court": {"equals": true},
	"primary_exterior_stair_count": 5,
	"primary_covered_episode_count": 1,
	"public_interior_node_count": {"max": 0},
	"unreachable_exterior_air_count": {"max": 0},
	"public_air_occupied_overlap_count": {"max": 0},
	"structural_court_cell_count": 31,
	"daylight_void_cell_count": 1,
	"daylight_void_bounded_edge_count": 4,
	"daylight_void_unbounded_edge_count": {"max": 0},
	"stair_endpoint_gap_count": {"max": 0},
	"platform_dead_end_count": {"max": 0},
	"unsupported_platform_count": {"max": 0},
	"unsupported_stair_count": {"max": 0},
	"platform_bearing_parent_count": 2,
	"continuous_sectional_path_count": 1,
	"served_entrance_count": 1,
	"unserved_entrance_count": {"max": 0},
	"served_structural_entrance_count": 1,
	"entrance_guard_conflict_count": {"max": 0},
	"derived_guard_segment_count": 4,
	"unclassified_interval_count": {"max": 0},
	"visual_envelope_overlap_count": {"max": 0},
}

const REVIEW_TARGETS := {
	"max_straight_run_m": {"max": 9.0},
	"max_constant_elevation_run_m": {"max": 12.0},
	"elevation_change_count": {"min": 4},
	"has_up_down_up": {"equals": true},
	"frontage_ratio": {"min": 0.85},
	"overhead_route_ratio": {"min": 0.45, "max": 0.65},
	"through_sightline_count": {"max": 0},
	"max_sightline_m": {"max": 12.0},
	"skywalk_link_count": {"min": 2},
	"outcropping_count": {"min": 4},
	"prefab_source_family_count": {"min": 2},
	"market_family_count": {"min": 4},
	"tent_count": {"max": 0},
	"isolated_platform_count": {"max": 0},
	"solid_void_frontage_ratio": {"min": 0.85},
	"unbounded_route_side_count": {"max": 0},
	"half_level_neighbor_pair_count": {"min": 4},
	"building_base_band_count": {"min": 4},
	"solid_void_core_width_cells": {"max": 24},
	"solid_void_core_depth_cells": {"max": 24},
	"level_changing_loop_count": {"min": 1},
}

const PRIMARY_ITINERARY: Array[StringName] = [
	&"route.entry",
	&"route.lower.e1",
	&"route.lower.turn.n1",
	&"route.rise.early",
	&"route.high.turn.w",
	&"route.high.w1",
	&"route.high.turn.n",
	&"route.desc.early",
	&"route.lower.turn.n2",
	&"route.lower.n2",
	&"route.lower.turn.rise",
	&"route.rise.full",
	&"route.middle.turn.w",
	&"route.middle.w1",
	&"route.middle.turn.n",
	&"city.west.approach",
	&"city.stair_house",
	&"city.high.passage",
	&"city.high.rise",
	&"city.high.arrival",
	&"city.upper.court",
	&"city.descent.full",
	&"city.descent.turn",
	&"city.descent.half",
	&"city.lower.passage",
]


static func solve(program: SettlementFabricProgram,
		world_seed: int = 0) -> SettlementFabricPlan:
	if program == null:
		return null
	# The visual fixture and production-facing procedural entry deliberately use
	# one planner. Keeping the retired hand-authored proof below temporarily
	# preserves useful grammar examples while screenshots now exercise exactly
	# the data path intended for seeded runtime generation.
	return WarrenRisingRingPlanner.new().solve(program, world_seed, {})
	@warning_ignore("unreachable_code")
	var specs: Array[Dictionary] = []
	var by_id: Dictionary = {}

	# The route changes direction and elevation as one coupled motif. Its main
	# chain rises, descends, rises, descends, and rises again; no long flat street
	# is authored and no stair is decorative or disconnected.
	_put(specs, by_id, SettlementFabricSolver.unit_spec(&"route.entry",
		&"route.landing", Vector3i(0, 0, 0)))
	_attach(program, specs, by_id, &"route.lower.e1", &"route.straight",
		&"route.entry", &"walk.west", &"walk.east", 0)
	_attach(program, specs, by_id, &"route.lower.turn.n1", &"route.corner",
		&"route.lower.e1", &"walk.west", &"walk.east", 0)
	_attach(program, specs, by_id, &"route.rise.early", &"stair.half",
		&"route.lower.turn.n1", &"walk.low", &"walk.north", 0,
		[&"route.lower.turn.n1"], [
			FabricUnit.bond(&"bearing.low", &"route.lower.turn.n1", &"bearing.north"),
		])
	_attach(program, specs, by_id, &"route.high.turn.w", &"route.corner",
		&"route.rise.early", &"walk.south", &"walk.high", 0)
	_attach(program, specs, by_id, &"route.high.w1", &"route.straight",
		&"route.high.turn.w", &"walk.east", &"walk.west", 0)
	_attach(program, specs, by_id, &"route.high.turn.n", &"route.corner",
		&"route.high.w1", &"walk.east", &"walk.west", 0)
	_attach(program, specs, by_id, &"route.desc.early", &"stair.half",
		&"route.high.turn.n", &"walk.high", &"walk.north", 2,
		[&"route.high.turn.n"], [
			FabricUnit.bond(&"bearing.high", &"route.high.turn.n", &"bearing.north"),
		])
	_attach(program, specs, by_id, &"route.lower.turn.n2", &"route.corner",
		&"route.desc.early", &"walk.south", &"walk.low", 0)
	_attach(program, specs, by_id, &"route.lower.n2", &"route.straight",
		&"route.lower.turn.n2", &"walk.west", &"walk.north", 1)
	_attach(program, specs, by_id, &"route.lower.turn.rise", &"route.corner",
		&"route.lower.n2", &"walk.south", &"walk.east", 0)
	_attach(program, specs, by_id, &"route.rise.full", &"stair.full",
		&"route.lower.turn.rise", &"walk.low", &"walk.north", 0,
		[&"route.lower.turn.rise"], [
			FabricUnit.bond(&"bearing.low", &"route.lower.turn.rise", &"bearing.north"),
		])
	_attach(program, specs, by_id, &"route.middle.turn.w", &"route.corner",
		&"route.rise.full", &"walk.south", &"walk.high", 0)
	_attach(program, specs, by_id, &"route.middle.w1", &"route.straight",
		&"route.middle.turn.w", &"walk.east", &"walk.west", 0)
	_attach(program, specs, by_id, &"route.middle.turn.n", &"route.corner",
		&"route.middle.w1", &"walk.east", &"walk.west", 0)
	_attach(program, specs, by_id, &"city.west.approach", &"route.straight",
		&"route.middle.turn.n", &"walk.east", &"walk.west", 0)

	# The main journey climbs beside an occupied facade and remains outside its
	# room envelope. The upper court is local ground borne by inhabited rooms;
	# occupied skywalks cross the district overhead but are not public paths.
	_attach(program, specs, by_id, &"city.stair_house",
		&"stair.facade.full.terrain.orange", &"city.west.approach",
		&"walk.low", &"walk.north", 0)
	_attach(program, specs, by_id, &"city.high.passage",
		&"route.corner", &"city.stair_house", &"walk.south",
		&"walk.high", 0)
	_attach(program, specs, by_id, &"city.high.rise", &"stair.full",
		&"city.high.passage", &"walk.low", &"walk.east", 3,
		[&"city.high.passage"], [
			FabricUnit.bond(&"bearing.low", &"city.high.passage", &"bearing.east"),
		])
	_attach(program, specs, by_id, &"city.high.arrival", &"route.corner",
		&"city.high.rise", &"walk.west", &"walk.high", 0)
	var court_origin := _attached_origin(program,
		program.recipe(&"court.supported.12x6"), &"walk.west", 0,
		by_id[&"city.high.arrival"] as Dictionary, &"walk.east")
	var court_supports: Array[StringName] = []
	for support: Dictionary in [
		{"suffix": &"west", "socket": &"bearing.bottom.west", "theme": &"blue"},
		{"suffix": &"east", "socket": &"bearing.bottom.east", "theme": &"orange"},
	]:
		var support_id := _add_vertical_support_stack(program, specs, by_id,
			StringName("city.court.support.%s" % support.suffix), court_origin,
			0, program.recipe(&"court.supported.12x6").socket(
				StringName(support.socket)).cell as Vector3i,
			StringName(support.theme))
		court_supports.append(support_id)
	_put(specs, by_id, SettlementFabricSolver.unit_spec(&"city.upper.court",
		&"court.supported.12x6", court_origin, 0, court_supports, [
			FabricUnit.bond(&"walk.west", &"city.high.arrival", &"walk.east"),
			FabricUnit.bond(&"bearing.bottom.west", court_supports[0],
				&"bearing.top"),
			FabricUnit.bond(&"bearing.bottom.east", court_supports[1],
				&"bearing.top"),
		]))
	var west_passage_origin := _attached_origin(program,
		program.recipe(&"room.passage.blue"), &"walk.east", 0,
		by_id[&"city.upper.court"] as Dictionary, &"walk.west") \
		+ Vector3i(-4, 2, -3)
	var west_support := _add_vertical_support_stack(program, specs, by_id,
		&"skywalk.passage.west.support", west_passage_origin, 0,
		Vector3i.ZERO, &"orange")
	_put(specs, by_id, SettlementFabricSolver.unit_spec(&"skywalk.passage.west",
		&"room.passage.blue", west_passage_origin, 0, [west_support], [
			FabricUnit.bond(&"bearing.bottom", west_support, &"bearing.top"),
		]))
	var west_passage := by_id[&"skywalk.passage.west"] as Dictionary
	var east_origin := (west_passage.origin as Vector3i) + Vector3i(10, 0, 0)
	_put(specs, by_id, SettlementFabricSolver.unit_spec(&"skywalk.passage.east",
		&"room.passage.terrain.orange", east_origin, 0))
	_attach(program, specs, by_id, &"skywalk.passage.west.roof", &"roof.blue",
		&"skywalk.passage.west", &"bearing.bottom", &"bearing.top", 0,
		[&"skywalk.passage.west"])
	_attach(program, specs, by_id, &"skywalk.passage.east.roof", &"roof.orange",
		&"skywalk.passage.east", &"bearing.bottom", &"bearing.top", 0,
		[&"skywalk.passage.east"])
	_attach(program, specs, by_id, &"skywalk.market.tunnel",
		&"skywalk.9.blue", &"skywalk.passage.west", &"room.west",
		&"room.east", 0,
		[&"skywalk.passage.west", &"skywalk.passage.east"], [
			FabricUnit.bond(&"bearing.west", &"skywalk.passage.west",
				&"bearing.east"),
			FabricUnit.bond(&"bearing.east", &"skywalk.passage.east",
				&"bearing.west"),
			FabricUnit.bond(&"room.east", &"skywalk.passage.east", &"room.west"),
		], [&"skywalk.passage.west.roof", &"skywalk.passage.east.roof"])
	_attach(program, specs, by_id, &"city.descent.full", &"stair.full",
		&"city.upper.court", &"walk.high", &"walk.south", 0,
		[&"city.upper.court"], [
			FabricUnit.bond(&"bearing.high", &"city.upper.court",
				&"bearing.edge.south"),
		])
	_attach(program, specs, by_id, &"city.descent.turn", &"route.corner",
		&"city.descent.full", &"walk.north", &"walk.low", 0)
	_attach(program, specs, by_id, &"city.descent.half", &"stair.half",
		&"city.descent.turn", &"walk.high", &"walk.east", 1,
		[&"city.descent.turn"], [
			FabricUnit.bond(&"bearing.high", &"city.descent.turn",
				&"bearing.east"),
		])
	_attach(program, specs, by_id, &"city.lower.passage",
		&"route.corner", &"city.descent.half", &"walk.east",
		&"walk.low", 2)

	# A second occupied span crosses directly over the lower folded route. Both
	# end rooms use compact terrain perches and its floor starts one clear cell
	# above public headroom; there is no detached access stair or empty platform.
	var valley_west_origin := Vector3i(6, 3, -4)
	_put(specs, by_id, SettlementFabricSolver.unit_spec(&"skywalk.valley.west",
		&"room.passage.terrain.orange", valley_west_origin, 0))
	var valley_west := by_id[&"skywalk.valley.west"] as Dictionary
	var valley_east_origin := (valley_west.origin as Vector3i) - Vector3i(0, 0, 6)
	_put(specs, by_id, SettlementFabricSolver.unit_spec(&"skywalk.valley.east",
		&"room.passage.terrain.blue", valley_east_origin, 0))
	_attach(program, specs, by_id, &"skywalk.valley.west.roof", &"roof.orange",
		&"skywalk.valley.west", &"bearing.bottom", &"bearing.top", 0,
		[&"skywalk.valley.west"])
	_attach(program, specs, by_id, &"skywalk.valley.east.roof", &"roof.blue",
		&"skywalk.valley.east", &"bearing.bottom", &"bearing.top", 0,
		[&"skywalk.valley.east"])
	_attach(program, specs, by_id, &"skywalk.valley.tunnel", &"skywalk.3.blue",
		&"skywalk.valley.west", &"room.west", &"room.north", 1,
		[&"skywalk.valley.west", &"skywalk.valley.east"], [
			FabricUnit.bond(&"bearing.west", &"skywalk.valley.west",
				&"bearing.north"),
			FabricUnit.bond(&"bearing.east", &"skywalk.valley.east", &"bearing.south"),
			FabricUnit.bond(&"room.east", &"skywalk.valley.east", &"room.south"),
		], [&"skywalk.valley.west.roof", &"skywalk.valley.east.roof"])

	# Closely packed lower masses form alley walls. Upper rooms and roofs inherit
	# their bearing through explicit vertical bonds.
	_add_building_stack(program, specs, by_id, &"mass.lower.west",
		Vector3i(0, 0, 3), 1, &"blue", true)
	_add_building_stack(program, specs, by_id, &"mass.lower.east",
		Vector3i(4, 0, 3), 3, &"orange", true)
	# Preserve an adjacent half-level band after the court-facing stack displaced
	# the former mass at this height. It closes the upper approach instead of
	# becoming an isolated skyline object.
	_add_building_stack(program, specs, by_id, &"mass.upper.northeast",
		Vector3i(15, 3, -20), 0, &"blue", true)
	# A deliberately addressed room closes the east side of the upper
	# court. Its exact door threshold opens onto the planked surface, while a
	# complete vertical bearing chain carries it to the frozen terrain perch.
	var court_address_base := &"court.address.east.base"
	var court_address_middle := &"court.address.east.middle"
	var court_address_room := &"court.address.east.room"
	_put(specs, by_id, SettlementFabricSolver.unit_spec(court_address_base,
		&"room.base.rock.closed", Vector3i(9, 2, -22), 3))
	_put(specs, by_id, SettlementFabricSolver.unit_spec(court_address_middle,
		&"room.upper.orange", Vector3i(9, 4, -22), 3,
		[court_address_base], [
			FabricUnit.bond(&"bearing.bottom", court_address_base, &"bearing.top"),
		]))
	_put(specs, by_id, SettlementFabricSolver.unit_spec(court_address_room,
		&"room.upper.address.blue", Vector3i(9, 6, -22), 3,
		[court_address_middle], [
			FabricUnit.bond(&"bearing.bottom", court_address_middle, &"bearing.top"),
		]))
	_put(specs, by_id, SettlementFabricSolver.unit_spec(&"court.address.east.roof",
		&"roof.blue", Vector3i(9, 8, -22), 3, [court_address_room], [
			FabricUnit.bond(&"bearing.bottom", court_address_room, &"bearing.top"),
		]))
	_put(specs, by_id, SettlementFabricSolver.unit_spec(&"anchor.fantasy_village",
		&"anchor.prefab.00", Vector3i(12, 0, -12), 2))
	_put(specs, by_id, SettlementFabricSolver.unit_spec(&"anchor.alchemy",
		&"anchor.prefab.02", Vector3i(-8, 0, -10), 0))

	# Market canopies line the first two bends; their post-only occupancy leaves
	# the alley itself navigable and permits the cloth to overhang its headroom.
	_attach(program, specs, by_id, &"market.alchemy", &"market.stall.00",
		&"mass.lower.west.base", &"market.back", &"market.north", 3,
		[], [], [&"mass.lower.west.upper"])
	_attach(program, specs, by_id, &"market.butcher", &"market.stall.04",
		&"mass.lower.east.base", &"market.back", &"market.north", 1,
		[], [], [&"mass.lower.east.upper"])
	_attach(program, specs, by_id, &"market.forge", &"market.stall.01",
		&"mass.lower.west.base", &"market.back", &"market.west", 0,
		[], [], [&"mass.lower.west.upper"])
	_attach(program, specs, by_id, &"market.fish", &"market.stall.02",
		&"mass.lower.east.base", &"market.back", &"market.east", 0,
		[], [], [&"mass.lower.east.upper"])

	# Occupied outcroppings deliberately project into the volume above the lower
	# route. They are rooms with braces, not empty suspended platforms.
	_attach(program, specs, by_id, &"outcrop.lower.west", &"outcrop.blue",
		&"mass.lower.west.upper", &"bearing.back", &"bearing.east", 2,
		[&"mass.lower.west.upper"], [], [&"mass.lower.west.roof"])
	_attach(program, specs, by_id, &"outcrop.lower.east", &"outcrop.orange",
		&"mass.lower.east.upper", &"bearing.back", &"bearing.west", 2,
		[&"mass.lower.east.upper"], [], [&"mass.lower.east.roof"])
	_attach(program, specs, by_id, &"outcrop.middle.west", &"outcrop.orange",
		&"city.court.support.west.upper", &"bearing.back", &"bearing.north", 2,
		[&"city.court.support.west.upper"])

	var episode_overrides := {
		&"route.lower.n2": PublicRealmNode.EpisodeKind.UNDERCROFT,
	}
	var realm := SectionalPublicRealmBuilder.from_specs(
		&"warren.folded.proof.v2/realm", program, specs, PRIMARY_ITINERARY,
		episode_overrides)
	if realm == null:
		push_error("Could not compile folded proof sectional public realm: %s" %
			SectionalPublicRealmBuilder.last_failure)
		return null
	var solver := SettlementFabricSolver.new(program)
	var seed_plan := solver.solve_sectional(&"warren.folded.proof.v2.seed", realm,
		SectionalPublicRealmBuilder.bind_specs(specs, program), REQUIREMENTS)
	if seed_plan == null:
		push_error("Folded proof rejected: %s" % solver.failure_reason)
		return null
	var embedding := StaggeredFabricEmbedder.solve(
		&"warren.folded.proof.v2.embedding", seed_plan.solid_void_plan,
		seed_plan.public_realm.air_claims(),
		_occupied_or_occluding_cells(seed_plan),
		seed_plan.transformed_cells(&"inhabited"), 24, 28, program,
		seed_plan.transformed_visual_clearance_bounds(), true)
	if embedding == null or not StaggeredFabricCompiler.append_specs(program,
			embedding, specs, by_id):
		push_error("Could not compile staggered solid/void embedding")
		return null
	# Rebuild every coupled fact from the compiled structural units. The seed is
	# diagnostic only; no surface, air, or boundary result is copied forward.
	realm = SectionalPublicRealmBuilder.from_specs(
		&"warren.folded.proof.v2/embedded-realm", program, specs,
		PRIMARY_ITINERARY, episode_overrides)
	if realm == null:
		push_error("Could not rebuild embedded public realm: %s" %
			SectionalPublicRealmBuilder.last_failure)
		return null
	var plan := solver.solve_sectional(&"warren.folded.proof.v2", realm,
		SectionalPublicRealmBuilder.bind_specs(specs, program), REQUIREMENTS,
		embedding)
	if plan == null:
		push_error("Embedded folded proof rejected: %s" % solver.failure_reason)
	return plan


static func _occupied_or_occluding_cells(plan: SettlementFabricPlan) -> Dictionary:
	var out := plan.transformed_cells(&"solid")
	for cell_value: Variant in plan.transformed_cells(&"occluder"):
		out[cell_value as Vector3i] = true
	for cell_value: Variant in plan.transformed_visual_clearance_cells():
		out[cell_value as Vector3i] = true
	return out


static func _add_building_stack(program: SettlementFabricProgram,
		specs: Array[Dictionary], by_id: Dictionary, prefix: StringName,
		origin: Vector3i, yaw: int, theme: StringName, add_roof: bool) -> void:
	var base_id := StringName("%s.base" % prefix)
	var upper_id := StringName("%s.upper" % prefix)
	_put(specs, by_id, SettlementFabricSolver.unit_spec(base_id,
		&"room.base.rock.closed", origin, yaw))
	_attach(program, specs, by_id, upper_id,
		&"room.upper.orange" if theme == &"orange" else &"room.upper.blue",
		base_id, &"bearing.bottom", &"bearing.top", yaw, [base_id])
	if add_roof:
		_attach(program, specs, by_id, StringName("%s.roof" % prefix),
			&"roof.orange" if theme == &"orange" else &"roof.blue",
			upper_id, &"bearing.bottom", &"bearing.top", yaw, [upper_id])


static func _add_vertical_support_stack(program: SettlementFabricProgram,
		specs: Array[Dictionary], by_id: Dictionary, prefix: StringName,
		child_origin: Vector3i, child_yaw: int, child_bearing_cell: Vector3i,
		theme: StringName) -> StringName:
	## Place the top socket of an inhabited two-storey stack directly beneath a
	## future downward-facing bearing socket. The helper is recipe geometry, not
	## a court special case: callers supply the exact child bearing cell.
	var world_bearing_cell := FabricRecipe.transform_cell(child_bearing_cell,
		child_origin, child_yaw)
	var upper_origin := world_bearing_cell - Vector3i(0, 2, 0)
	var base_origin := upper_origin - Vector3i(0, 2, 0)
	var base_id := StringName("%s.base" % prefix)
	var upper_id := StringName("%s.upper" % prefix)
	_put(specs, by_id, SettlementFabricSolver.unit_spec(base_id,
		&"room.base.rock.closed", base_origin))
	_attach(program, specs, by_id, upper_id,
		&"room.upper.orange" if theme == &"orange" else &"room.upper.blue",
		base_id, &"bearing.bottom", &"bearing.top", 0, [base_id])
	return upper_id


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


static func _attach(program: SettlementFabricProgram, specs: Array[Dictionary],
		by_id: Dictionary, stable_id: StringName, recipe_id: StringName,
		parent_id: StringName, own_socket_id: StringName,
		parent_socket_id: StringName, yaw: int,
		parents: Array[StringName] = [],
		extra_bonds: Array[Dictionary] = [],
		visual_seams: Array[StringName] = []) -> void:
	var child_recipe := program.recipe(recipe_id)
	var parent_spec := by_id[parent_id] as Dictionary
	var parent_recipe := program.recipe(StringName(parent_spec.recipe_id))
	assert(child_recipe != null and parent_recipe != null)
	var origin := _attached_origin(program, child_recipe, own_socket_id, yaw,
		parent_spec, parent_socket_id)
	var bonds: Array[Dictionary] = [FabricUnit.bond(own_socket_id, parent_id,
		parent_socket_id)]
	bonds.append_array(extra_bonds)
	_put(specs, by_id, SettlementFabricSolver.unit_spec(stable_id, recipe_id,
		origin, yaw, parents, bonds, &"", visual_seams))


static func _put(specs: Array[Dictionary], by_id: Dictionary,
		spec: Dictionary) -> void:
	var stable_id := StringName(spec.stable_id)
	assert(not by_id.has(stable_id))
	specs.append(spec)
	by_id[stable_id] = spec
