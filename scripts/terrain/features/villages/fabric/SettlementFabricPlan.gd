class_name SettlementFabricPlan
extends RefCounted

## Sealed worker-safe urban-fabric record. Recipes provide one vocabulary for
## generated rooms, prefab anchors, markets, routes, and spans; this plan owns
## their exact occupancy and socket bonds without asset-specific branches.
var stable_id: StringName
var units: Array[FabricUnit] = []
var public_realm: SectionalPublicRealmPlan
var surface_plan: PublicRealmSurfacePlan
var volume_plan: FabricVolumePlan
var solid_void_plan: FabricSolidVoidPlan
var embedding_plan: StaggeredFabricEmbeddingPlan
## Source mass the town stands ON rather than IN: every cell of the standing
## solid no building occupies -- the plinth under a raised parcel, the terrace
## risers between houses, and the mass beside and above a street the excavation
## cut through the hill, which is what makes a covered route read as a passage
## instead of a trench. SettlementFabricAssembler draws only the part of it a
## building stands over -- a foundation plinth and the mountain substrate under
## it; a column nothing is built on is not drawn at all. Deliberately excluded
## from occupancy either way, so it claims no socket and enters no
## visual-envelope or solid/void test.
##
## Empty for a legacy town: the retired asset compiler declared the wider hill
## only where the massif provenance is present.
var retained_terrace_cells: Dictionary = {}
## Support cells directly beneath the plot model's one typed village-green
## rectangle. The source planner reserves the complete street-fronted rectangle
## before any house is packed; carrying that identity through compilation keeps
## the visible green, its traversal surface, guards, and furniture tied to the
## same topology fact instead of rediscovering a nearby patch of leftover turf.
var planned_plaza_cells: Dictionary = {}
## TASK I2. The town's own world seed, carried here because the retained-mass
## skin now has to answer a question only the seed can answer: WHICH TIMBER
## FAMILY a clad mass face belongs to. A fake storey and the real house beside
## it must share a palette, and the palette is
## `WarrenSpatialFabricCompiler.architectural_district_theme(origin, seed)` --
## the same district field every real room's recipe is chosen through. Deriving
## a second field off the plan's own id would give the mass its own colouring
## and put a blue wall against an orange neighbour on the same block.
##
## A PLAIN FIELD, not an audit key, because the skin is derived TWICE: once for
## the payload (on a sealed plan) and once for `_maze_stone_skin_audit` (on a
## plan the compiler has not sealed yet, whose `audit` is still empty). One
## field answers both. It rides outside `construction_signature()` on purpose --
## that signature is seed-independent by contract -- and a legacy plan leaves it
## 0, which is inert because a legacy plan tags no maze stone at all.
var world_seed: int = 0
## Plain measured local AABBs compiled by SettlementFabricProgram for every
## asset an adapter may emit.  They are construction inputs, not render
## resources: optional dressing is accepted against the finished town's exact
## module/skin envelopes before a payload is produced.
var asset_visual_bounds: Dictionary = {}
var audit: Dictionary = {}
## Derived at seal time from exact modular roof-run seams. Structural roof
## units remain the occupancy authority; this render construction plan removes
## their internal gables and unifies compatible repeats into one long roof.
var continuous_roof_plan: FabricContinuousRoofPlan
var _recipes: Dictionary = {}
var _by_id: Dictionary = {}
## Each accepted unit's clearance box, parallel to `units` and read by index.
##
## FIX ROUND 1, MINOR 1. Two invariants hold it up. The first is asserted where
## it grows in `add_unit`: `_clearance_bounds.size() == units.size()` before
## either append, so a unit can never be recorded twice or without its box.
## The second cannot be asserted cheaply and is stated instead: a unit's
## `recipe_id`, `lattice_origin` and `yaw_quarters` are FIXED once it has been
## accepted, so the box stays the one its transform implies. Nothing in this
## repository writes those three fields after construction (one test sets
## `lattice_origin` on a unit it never adds to a plan), and `validate()` is the
## backstop: it re-derives every unit's bounds from scratch at seal time and
## refuses a plan whose stored `bounds` no longer match, which is exactly the
## mutation that would make a stale clearance box possible.
var _clearance_bounds: Array[AABB] = []
var _solid_owner: Dictionary = {}
var _walk_owner: Dictionary = {}
var _headroom_owner: Dictionary = {}
var _terrace_declared := false
var _plaza_declared := false
var _sealed := false
## TASK I4 ROUND 7, r6 REVIEW MINOR 6 -- the derived module-footprint index,
## built at most once per plan.
##
## Round 6 shipped it as a free function over `expanded_placements()`, and five
## production call sites plus one per pin per town in the tests each built their
## own copy of the same answer. It is a pure function of the units, their
## recipes, and their suppressions, so ONE copy per plan is the same dictionary
## every caller built for itself; the two writers that can move it -- `add_unit`
## and `suppress_placement` -- clear it, so a mid-compile reader can never be
## handed a town that no longer exists.
var _module_footprints: Dictionary = {}
var _module_footprints_built := false
var last_rejection := ""


func _init(p_stable_id: StringName) -> void:
	stable_id = p_stable_id


func register_recipe(recipe: FabricRecipe) -> bool:
	if _sealed or recipe == null or not recipe.is_sealed() \
			or _recipes.has(recipe.recipe_id):
		return false
	_recipes[recipe.recipe_id] = recipe
	return true


func set_asset_visual_bounds(bounds: Dictionary) -> bool:
	if _sealed or not asset_visual_bounds.is_empty() or bounds.is_empty():
		return false
	for asset_value: Variant in bounds.keys():
		var asset_id := StringName(asset_value)
		var box := bounds[asset_value] as AABB
		if asset_id.is_empty() or not box.has_volume() \
				or not box.position.is_finite() or not box.size.is_finite():
			return false
	asset_visual_bounds = bounds.duplicate()
	return true


func set_public_realm(realm: SectionalPublicRealmPlan) -> bool:
	if _sealed or realm == null or not realm.is_sealed() or public_realm != null:
		return false
	public_realm = realm
	return true


func set_surface_plan(plan_value: PublicRealmSurfacePlan) -> bool:
	if _sealed or plan_value == null or not plan_value.is_sealed() \
			or surface_plan != null:
		return false
	# The plaza is topology, so it may be declared before the public surface is
	# solved (the guard solver needs its mouths). Accept the surface only when
	# every declared support cell really owns the promised public floor.
	for cell_value: Variant in planned_plaza_cells.keys():
		if not plan_value.has_cell((cell_value as Vector3i) + Vector3i.UP):
			return false
	surface_plan = plan_value
	return true


func set_volume_plan(plan_value: FabricVolumePlan) -> bool:
	if _sealed or plan_value == null or not plan_value.is_sealed() \
			or volume_plan != null:
		return false
	volume_plan = plan_value
	return true


func set_solid_void_plan(plan_value: FabricSolidVoidPlan) -> bool:
	if _sealed or plan_value == null or not plan_value.is_sealed() \
			or solid_void_plan != null:
		return false
	solid_void_plan = plan_value
	return true


func set_retained_terrace(cells: Dictionary) -> bool:
	## Declared once, before sealing, and never after: the hill is a fact about
	## the parcels this plan was compiled from, not something a later stage may
	## grow. A cell already claimed as solid is refused outright -- retained
	## stone must be mass nobody built in. `cells` is keyed by Vector3i lattice
	## cell, exactly as `WarrenSpatialFabricCompiler._retained_foundation_cells`
	## builds it; the value is the render tag.
	##
	## TASK F3 MEMBER 6. The solid check compared the WRONG KEY TYPE and could
	## never fire: `_solid_owner` is keyed by `_cell_key`'s `"x:y:z"` String,
	## `cells` by Vector3i, and `Dictionary.has` is exact. So from the day the
	## guard was written until this task it accepted every overlap it exists to
	## refuse, and the sentence above was a description of code that did
	## nothing. It is a real check now.
	##
	## MEASURED before the fix, so that turning it on is not a gamble: over the
	## 24-town corpus plus the production settlement, the retained channel and
	## the built solid set are DISJOINT on every town (worst intersection 0 of
	## 641-1390 retained cells against 344-734 solid cells). The compiler
	## already subtracts `transformed_cells(&"solid")` from the maze-stone half
	## and never proposes a plinth course inside a room, so the fixed guard
	## rejects nothing that ships today; it is the backstop for the case those
	## two rules stop covering.
	if _sealed or _terrace_declared:
		return false
	for cell_value: Variant in cells.keys():
		if _solid_owner.has(_cell_key(cell_value as Vector3i)):
			return false
	retained_terrace_cells = cells.duplicate()
	_terrace_declared = true
	return true


func set_planned_plaza(cells: Dictionary) -> bool:
	## Declared once before the public surface is solved. The square is a topology
	## fact, not late dressing: its exact cells are required while guards are
	## derived so every street mouth is open by construction. Cells name the solid
	## band under the walk plane, matching every retained-cap API in the fabric.
	## `set_surface_plan` subsequently proves that `cell + UP` is an actual public
	## claim; callers that already hold a surface receive the same check here.
	## Empty is a valid declaration for a source town whose bounded plot search
	## found no square, but no inferred garden may masquerade as this typed feature.
	if _sealed or _plaza_declared:
		return false
	var first_band := 0
	var first := true
	for cell_value: Variant in cells.keys():
		var cell := cell_value as Vector3i
		if surface_plan != null and not surface_plan.has_cell(
				cell + Vector3i.UP):
			return false
		if first:
			first_band = cell.y
			first = false
		elif cell.y != first_band:
			return false
	if not cells.is_empty():
		var unseen := cells.duplicate()
		var starts: Array[Vector3i] = []
		starts.assign(unseen.keys())
		var frontier: Array[Vector3i] = [starts[0]]
		unseen.erase(starts[0])
		while not frontier.is_empty():
			var cell: Vector3i = frontier.pop_back()
			for step: Vector3i in [Vector3i.RIGHT, Vector3i.LEFT,
					Vector3i.FORWARD, Vector3i.BACK]:
				if unseen.has(cell + step):
					unseen.erase(cell + step)
					frontier.append(cell + step)
		if not unseen.is_empty():
			return false
	planned_plaza_cells = cells.duplicate()
	_plaza_declared = true
	return true


func set_embedding_plan(plan_value: StaggeredFabricEmbeddingPlan) -> bool:
	if _sealed or plan_value == null or not plan_value.validate() \
			or embedding_plan != null:
		return false
	embedding_plan = plan_value
	return true


func add_unit(unit: FabricUnit) -> bool:
	last_rejection = ""
	if _sealed:
		return false
	# _accept_unit claims semantic cells as it validates them, and a later
	# visual-envelope rejection must not leave ghost claims that poison a
	# measured fallback attempted in the same plan.
	#
	# TASK F2. That used to be staged by DUPLICATING all three owner maps for
	# every unit — an O(town) copy per unit, three maps deep, in each of the
	# three plans a compile builds (the room-phase probe, the roof-selection
	# probe, and the result). It is now a journal: the claims go into the real
	# maps and a rejection erases exactly the keys they added. Contents AND
	# insertion order are restored, because `_claim_cells` refuses any key its
	# own map already holds — so every journalled key is one this call created.
	var journal: Array[Array] = []
	if not _accept_unit(unit, _by_id, _solid_owner, _walk_owner,
			_headroom_owner, journal):
		_rollback_claims(journal)
		return false
	var recipe := _recipes[unit.recipe_id] as FabricRecipe
	var transform := unit.transform()
	unit.bounds = transform * recipe.local_bounds
	var clearance_bounds := transform * recipe.local_clearance_bounds
	# TASK F2. `recipe.placements.is_empty()` does not depend on `existing`, so
	# it decides the whole loop rather than every iteration of it; and the
	# BOXES are tested before the relationship. `_units_declare_connection`
	# walks two bearing DAGs with a `visited` dictionary each, and it used to
	# run on every one of the ~125 000 pairs a compile makes, when only the few
	# hundred whose boxes actually meet can change the outcome. Both terms are
	# pure, so the pair this loop rejects — and the message it rejects it with
	# — are the same as before, at the same index.
	for index in units.size() if not recipe.placements.is_empty() else 0:
		var existing := units[index]
		# The accepted unit's clearance box, recorded when it was accepted. A
		# unit's origin, yaw and recipe are fixed at construction, so this is
		# the same product the loop used to recompute for every pair; `validate`
		# still derives both sides from scratch at seal time, which is where
		# the authoritative proof lives.
		var existing_clearance := _clearance_bounds[index]
		if _aabb_overlaps_volume(clearance_bounds, existing_clearance):
			var existing_recipe := _recipes[existing.recipe_id] as FabricRecipe
			if existing_recipe.placements.is_empty():
				continue
			if _units_declare_connection(unit, existing):
				if _connected_roof_seam_is_measured(unit, recipe,
						clearance_bounds, existing, existing_recipe,
						existing_clearance):
					continue
				last_rejection = ("roof envelope of %s (%s at %s/r%d) drives " \
					+ "into connected unit %s (%s) past its measured seam: " \
					+ "overlap %s") % [unit.stable_id, unit.recipe_id,
						unit.lattice_origin, unit.yaw_quarters, existing.stable_id,
						existing.recipe_id, _overlap_size(clearance_bounds,
							existing_clearance)]
				_rollback_claims(journal)
				return false
			if DIAGNOSTIC_ALLOW_CORNER_ENVELOPE_OVERLAP \
					and _is_corner_nick(clearance_bounds, existing_clearance):
				continue
			if DIAGNOSTIC_ALLOW_EDGE_ENVELOPE_OVERLAP \
					and _is_edge_nick(clearance_bounds, existing_clearance):
				continue
			last_rejection = \
				("visual envelope of %s (%s at %s/r%d) %s intersects " \
				+ "unrelated unit %s (%s at %s/r%d) %s") % [
					unit.stable_id, unit.recipe_id, unit.lattice_origin,
					unit.yaw_quarters, clearance_bounds, existing.stable_id,
					existing.recipe_id, existing.lattice_origin,
					existing.yaw_quarters, existing_clearance]
			_rollback_claims(journal)
			return false
	# FIX ROUND 1, MINOR 1. `_clearance_bounds` is parallel to `units` and is
	# read by index, so the two must grow together exactly once per accepted
	# unit. Every early return above this point leaves both untouched; this is
	# the only place either grows.
	assert(_clearance_bounds.size() == units.size(),
		"clearance bounds fell out of step with units")
	units.append(unit)
	_clearance_bounds.append(clearance_bounds)
	_by_id[unit.stable_id] = unit
	_module_footprints_built = false
	_module_footprints = {}
	return true


func _rollback_claims(journal: Array[Array]) -> void:
	## Undo exactly the claims this call made, newest first.
	for index in range(journal.size() - 1, -1, -1):
		var entry := journal[index]
		var owner := entry[0] as Dictionary
		for key: String in entry[1] as Array[String]:
			owner.erase(key)


func seal(p_audit: Dictionary = {}) -> bool:
	if _sealed or stable_id.is_empty() or units.is_empty():
		return false
	audit = p_audit.duplicate(true)
	if not validate():
		return false
	continuous_roof_plan = FabricContinuousRoofPlan.compile(self)
	if continuous_roof_plan == null or not continuous_roof_plan.is_valid():
		last_rejection = "continuous roof plan rejected: %s" % (
			continuous_roof_plan.last_rejection if continuous_roof_plan != null \
			else "missing compiler result")
		continuous_roof_plan = null
		return false
	_resolve_continuous_roof_endpoint_clearance()
	var roof_realization_conflict := _continuous_roof_realization_conflict()
	if not roof_realization_conflict.is_empty():
		last_rejection = "continuous roof realization intersects finished fabric: %s" \
			% roof_realization_conflict
		continuous_roof_plan = null
		return false
	var roof_audit := continuous_roof_plan.audit()
	for key_value: Variant in roof_audit.keys():
		audit[key_value] = roof_audit[key_value]
	_module_footprints_built = false
	_module_footprints = {}
	_sealed = true
	return true


func _resolve_continuous_roof_endpoint_clearance() -> void:
	## A maximal roof run keeps its complete authored exterior gables unless one
	## intersects unrelated finished fabric. Endpoint sections alone carry a baked
	## flush alternative ending at the semantic building plane. Selecting that
	## strict-subset envelope is monotone: it can remove an overlap, never create
	## one. This pass therefore converges without mesh offsets or seed-specific
	## repairs, while `_continuous_roof_realization_conflict` remains the final
	## unconditional proof.
	if continuous_roof_plan == null:
		return
	var realized := continuous_roof_plan.synthetic_placements
	for synthetic: Dictionary in realized:
		var alternative := synthetic.get("flush_alternative", {}) as Dictionary
		if alternative.is_empty():
			continue
		var current_bounds := synthetic.get("bounds", AABB()) as AABB
		var alternative_bounds := alternative.get("bounds", AABB()) as AABB
		if _continuous_roof_section_conflicts_with_finished_fabric(
				synthetic, current_bounds) \
				and not _continuous_roof_section_conflicts_with_finished_fabric(
					synthetic, alternative_bounds):
			continuous_roof_plan.select_flush_alternative(synthetic)
	# Endpoint alternatives are strict subsets, so resolving one synthetic pair
	# cannot invalidate a pair already visited. Restart after each selection only
	# to keep the preference for a complete eave deterministic.
	var changed := true
	while changed:
		changed = false
		for left_index in realized.size():
			var left := realized[left_index] as Dictionary
			var left_bounds := left.get("bounds", AABB()) as AABB
			for right_index in range(left_index + 1, realized.size()):
				var right := realized[right_index] as Dictionary
				var right_bounds := right.get("bounds", AABB()) as AABB
				if not _aabb_overlaps_volume(left_bounds, right_bounds) \
						or _continuous_components_have_measured_roof_junction(
							left, left_bounds, right, right_bounds):
					continue
				var left_alternative := left.get(
					"flush_alternative", {}) as Dictionary
				var right_alternative := right.get(
					"flush_alternative", {}) as Dictionary
				var left_alt_bounds := left_alternative.get(
					"bounds", AABB()) as AABB
				var right_alt_bounds := right_alternative.get(
					"bounds", AABB()) as AABB
				if left_alt_bounds.has_volume() \
						and not _continuous_roof_section_conflicts_with_finished_fabric(
							left, left_alt_bounds) \
						and not _aabb_overlaps_volume(left_alt_bounds, right_bounds):
					continuous_roof_plan.select_flush_alternative(left)
					changed = true
					break
				if right_alt_bounds.has_volume() \
						and not _continuous_roof_section_conflicts_with_finished_fabric(
							right, right_alt_bounds) \
						and not _aabb_overlaps_volume(left_bounds, right_alt_bounds):
					continuous_roof_plan.select_flush_alternative(right)
					changed = true
					break
				if left_alt_bounds.has_volume() and right_alt_bounds.has_volume() \
						and not _continuous_roof_section_conflicts_with_finished_fabric(
							left, left_alt_bounds) \
						and not _continuous_roof_section_conflicts_with_finished_fabric(
							right, right_alt_bounds) \
						and not _aabb_overlaps_volume(
							left_alt_bounds, right_alt_bounds):
					continuous_roof_plan.select_flush_alternative(left)
					continuous_roof_plan.select_flush_alternative(right)
					changed = true
					break
			if changed:
				break


func _continuous_roof_section_conflicts_with_finished_fabric(
		synthetic: Dictionary, roof_bounds: AABB) -> bool:
	# A run endpoint can project beyond every source roof section.  The public
	# surface is already sealed when this realization is compiled, so test the
	# final authored bounds against the same continuous body prism used by the
	# spatial compiler.  This is deliberately part of endpoint selection: where
	# the complete eave enters a lane, the finite flush alternative can still be
	# selected without moving the roof or editing an individual mesh.
	if _continuous_roof_bounds_enter_public_route(roof_bounds):
		return true
	var suppressed := continuous_roof_plan.suppressed_placement_ids
	var component_members: Dictionary = {}
	for unit_id: StringName in synthetic.get(
			"roof_component_unit_ids", []) as Array[StringName]:
		component_members[unit_id] = true
	var component_bearers: Dictionary = {}
	for unit_id: StringName in synthetic.get(
			"roof_component_bearing_ids", []) as Array[StringName]:
		component_bearers[unit_id] = true
	for unit_value: FabricUnit in units:
		if component_members.has(unit_value.stable_id):
			continue
		var unit_recipe := _recipes[unit_value.recipe_id] as FabricRecipe
		var unit_transform := unit_value.transform()
		for placement_index in unit_recipe.placements.size():
			var placement := unit_recipe.placements[placement_index] as Dictionary
			var stable_placement_id := StringName("%s/%s" % [
				unit_value.stable_id, StringName(placement.id)])
			if unit_value.suppressed_placement_ids.has(
					StringName(placement.id)) \
					or suppressed.has(stable_placement_id) \
					or placement_index >= unit_recipe.placement_bounds.size():
				continue
			if StringName(placement.id) == &"roof" \
					and unit_recipe.has_tag(&"roofed_facade_bay") \
					and _unit_bears_on_component(unit_value,
						component_members, component_bearers):
				continue
			var other_bounds := unit_transform \
				* unit_recipe.placement_bounds[placement_index]
			if _aabb_overlaps_volume(roof_bounds, other_bounds) \
					and not _continuous_component_has_measured_roof_junction(
						component_members, roof_bounds, unit_value,
						unit_recipe, other_bounds):
				return true
	return false


func _continuous_roof_bounds_enter_public_route(roof_bounds: AABB) -> bool:
	## The finished public-surface union is the traversal authority.  A stitched
	## roof must clear the real player prism above every one of its cells, even
	## when the smaller structural roof pieces it replaces each cleared on their
	## own.  Iterating the enum makes this automatically cover future public
	## surface kinds instead of maintaining a second list of streets/decks.
	if surface_plan == null or not roof_bounds.has_volume():
		return false
	for kind_value: Variant in PublicRealmSurfacePlan.SurfaceKind.values():
		for cell: Vector3i in surface_plan.cells_for_kind(int(kind_value)):
			var clearance := TraversalEnvelope.clearance_prism(cell,
				FabricRecipe.CELL_SIZE)
			if _aabb_overlaps_volume(roof_bounds, clearance):
				return true
	return false


func _continuous_roof_realization_conflict() -> String:
	## Layout reserves compact bays only to their exact party planes because an
	## outer eave does not exist until maximal connected runs are known. Prove the
	## actual synthetic roof geometry here, against actual unsuppressed placement
	## boxes rather than the broader recipe envelope, so the final eaves cannot
	## enter a wall, another crown, or an unrelated feature.
	if continuous_roof_plan == null:
		return ""
	var suppressed := continuous_roof_plan.suppressed_placement_ids
	var realized := continuous_roof_plan.synthetic_placements
	for synthetic_index in realized.size():
		var synthetic := realized[synthetic_index] as Dictionary
		var roof_bounds := synthetic.get("bounds", AABB()) as AABB
		if not roof_bounds.has_volume():
			return "%s has no measured bounds" % StringName(synthetic.stable_id)
		if _continuous_roof_bounds_enter_public_route(roof_bounds):
			return "%s enters a finished public traversal envelope" % \
				StringName(synthetic.stable_id)
		var component_members: Dictionary = {}
		for unit_id: StringName in synthetic.get(
				"roof_component_unit_ids", []) as Array[StringName]:
			component_members[unit_id] = true
		var component_bearers: Dictionary = {}
		for unit_id: StringName in synthetic.get(
				"roof_component_bearing_ids", []) as Array[StringName]:
			component_bearers[unit_id] = true
		for unit_value: FabricUnit in units:
			if component_members.has(unit_value.stable_id):
				continue
			var unit_recipe := _recipes[unit_value.recipe_id] as FabricRecipe
			var unit_transform := unit_value.transform()
			for placement_index in unit_recipe.placements.size():
				var placement := unit_recipe.placements[placement_index] as Dictionary
				var stable_placement_id := StringName("%s/%s" % [
					unit_value.stable_id, StringName(placement.id)])
				if unit_value.suppressed_placement_ids.has(
						StringName(placement.id)) \
						or suppressed.has(stable_placement_id):
					continue
				# A native-width facade bay is fastened into its bearing room at a
				# typed socket. Its little roof deliberately tucks under that room's
				# outer eave; treating the flashing joint as an unrelated collision
				# rejects an otherwise closed house. The exemption is deliberately
				# narrower than the unit: only the bay's named roof placement may meet
				# a continuous crown owned by its exact bearing parent. Its walls,
				# brackets, and every unattached roof remain subject to the same hard
				# overlap proof.
				if StringName(placement.id) == &"roof" \
						and unit_recipe.has_tag(&"roofed_facade_bay") \
						and _unit_bears_on_component(unit_value,
							component_members, component_bearers):
					continue
				if placement_index >= unit_recipe.placement_bounds.size():
					continue
				var other_bounds := unit_transform \
					* unit_recipe.placement_bounds[placement_index]
				if _aabb_overlaps_volume(roof_bounds, other_bounds):
					# Continuous realization changes only the roof skin; it does
					# not erase the exact junction contracts carried by the roof
					# units which contributed that skin. Re-evaluate those same
					# finite contracts against the realized section. This permits
					# an authored roof/roof flashing joint while stone, walls, and
					# undeclared neighbors remain unconditional hard conflicts.
					if _continuous_component_has_measured_roof_junction(
							component_members, roof_bounds, unit_value,
							unit_recipe, other_bounds):
						continue
					return "%s overlaps %s" % [
						StringName(synthetic.stable_id), stable_placement_id]
		for other_index in range(synthetic_index + 1, realized.size()):
			var other := realized[other_index] as Dictionary
			var other_bounds := other.get("bounds", AABB()) as AABB
			if _aabb_overlaps_volume(roof_bounds, other_bounds):
				if _continuous_components_have_measured_roof_junction(
						synthetic, roof_bounds, other, other_bounds):
					continue
				return "%s %s members=%s overlaps %s %s members=%s" % [
					StringName(synthetic.stable_id), str(roof_bounds),
					str(synthetic.get("roof_component_unit_ids", [])),
					StringName(other.stable_id), str(other_bounds),
					str(other.get("roof_component_unit_ids", []))]
	return ""


func _continuous_component_has_measured_roof_junction(
		component_members: Dictionary, realized_bounds: AABB,
		other: FabricUnit, other_recipe: FabricRecipe,
		other_bounds: AABB) -> bool:
	if not _contains_pitched_roof(other_recipe):
		return false
	for member_id_value: Variant in component_members.keys():
		var member_id := StringName(member_id_value)
		var member := _by_id.get(member_id) as FabricUnit
		if member == null or not _units_declare_connection(member, other):
			continue
		var member_recipe := _recipes.get(member.recipe_id) as FabricRecipe
		if member_recipe == null or not _contains_pitched_roof(member_recipe):
			continue
		if _connected_roof_seam_is_measured(member, member_recipe,
				realized_bounds, other, other_recipe, other_bounds):
			return true
	return false


func _continuous_components_have_measured_roof_junction(
		left: Dictionary, left_bounds: AABB,
		right: Dictionary, right_bounds: AABB) -> bool:
	## Two separately realized runs may touch only where their source roof units
	## already named one another. Re-use the same finite junction proof as the
	## ordinary placement gate against the final section boxes; proximity alone
	## can never turn crossing crowns into a legal roof intersection.
	for left_id: StringName in left.get(
			"roof_component_unit_ids", []) as Array[StringName]:
		var left_unit := _by_id.get(left_id) as FabricUnit
		if left_unit == null:
			continue
		var left_recipe := _recipes.get(left_unit.recipe_id) as FabricRecipe
		if left_recipe == null or not _contains_pitched_roof(left_recipe):
			continue
		for right_id: StringName in right.get(
				"roof_component_unit_ids", []) as Array[StringName]:
			var right_unit := _by_id.get(right_id) as FabricUnit
			if right_unit == null or not _units_declare_connection(
					left_unit, right_unit):
				continue
			var right_recipe := _recipes.get(right_unit.recipe_id) as FabricRecipe
			if right_recipe == null or not _contains_pitched_roof(right_recipe):
				continue
			if _connected_roof_seam_is_measured(left_unit, left_recipe,
					left_bounds, right_unit, right_recipe, right_bounds):
				return true
	return false


static func _unit_bears_on_component(unit_value: FabricUnit,
		component_members: Dictionary, component_bearers: Dictionary) -> bool:
	for parent_id: StringName in unit_value.parent_ids:
		if component_members.has(parent_id) or component_bearers.has(parent_id):
			return true
	return false


func validate() -> bool:
	last_rejection = ""
	if stable_id.is_empty() or units.is_empty() or _recipes.is_empty():
		last_rejection = "plan is missing its id, units, or recipe vocabulary"
		return false
	var seen: Dictionary = {}
	var solid: Dictionary = {}
	var walk: Dictionary = {}
	var headroom: Dictionary = {}
	for unit_value: FabricUnit in units:
		if not _accept_unit(unit_value, seen, solid, walk, headroom):
			if last_rejection.is_empty():
				last_rejection = "unit %s no longer satisfies occupancy or bonds" % \
					unit_value.stable_id
			return false
		var recipe := _recipes[unit_value.recipe_id] as FabricRecipe
		var expected_bounds := unit_value.transform() * recipe.local_bounds
		if not _aabb_is_equal(unit_value.bounds, expected_bounds):
			last_rejection = "unit %s has stale bounds" % unit_value.stable_id
			return false
		seen[unit_value.stable_id] = unit_value
	# TASK F2. Every unit's clearance box, derived once from scratch — this
	# remains the authoritative seal-time proof, and it is what `add_unit`'s
	# recorded boxes are checked against by being derived the same way. The
	# pairwise loop below then tests the BOXES before the relationship, for the
	# reason `add_unit` gives.
	var clearance_by_index: Array[AABB] = []
	for unit_value: FabricUnit in units:
		var unit_recipe := _recipes[unit_value.recipe_id] as FabricRecipe
		clearance_by_index.append(unit_value.transform() \
			* unit_recipe.local_clearance_bounds)
	for left_index in units.size():
		var left := units[left_index]
		var left_recipe := _recipes[left.recipe_id] as FabricRecipe
		if left_recipe.placements.is_empty():
			continue
		var left_clearance := clearance_by_index[left_index]
		for right_index in range(left_index + 1, units.size()):
			var right := units[right_index]
			var right_clearance := clearance_by_index[right_index]
			if not _aabb_overlaps_volume(left_clearance, right_clearance):
				continue
			var right_recipe := _recipes[right.recipe_id] as FabricRecipe
			if right_recipe.placements.is_empty():
				continue
			if _units_declare_connection(left, right):
				if _connected_roof_seam_is_measured(left, left_recipe,
						left_clearance, right, right_recipe, right_clearance):
					continue
				last_rejection = ("connected roof envelopes intersect past " \
					+ "their measured seam: %s and %s") % [left.stable_id,
						right.stable_id]
				return false
			if DIAGNOSTIC_ALLOW_CORNER_ENVELOPE_OVERLAP \
					and _is_corner_nick(left_clearance, right_clearance):
				continue
			if DIAGNOSTIC_ALLOW_EDGE_ENVELOPE_OVERLAP \
					and _is_edge_nick(left_clearance, right_clearance):
				continue
			last_rejection = "unrelated visual envelopes intersect: %s and %s" % [
				left.stable_id, right.stable_id]
			return false
	if surface_plan == null or not surface_plan.validate():
		last_rejection = "public surface plan is missing or invalid"
		return false
	if public_realm != null:
		if not public_realm.validate():
			last_rejection = "sectional public realm is invalid"
			return false
		if public_realm.air_realm != PublicRealmNode.AirRealm.EXTERIOR:
			last_rejection = "public realm is not exterior"
			return false
		if volume_plan == null or not volume_plan.validate():
			last_rejection = "exterior-air volume proof is missing or invalid"
			return false
		if solid_void_plan == null or not solid_void_plan.validate():
			last_rejection = "solid/void boundary proof is missing or invalid"
			return false
		if embedding_plan != null and not embedding_plan.validate():
			last_rejection = "staggered embedding lineage is invalid"
			return false
		if not _validate_public_realm_bindings():
			return false
		return _validate_surface_coverage()
	if not _all_public_walk_reaches_landing(seen):
		last_rejection = "public walk graph does not reach its landing"
		return false
	return _validate_surface_coverage()


func is_sealed() -> bool:
	return _sealed


func recipe(recipe_id: StringName) -> FabricRecipe:
	return _recipes.get(recipe_id) as FabricRecipe


func unit(stable_unit_id: StringName) -> FabricUnit:
	return _by_id.get(stable_unit_id) as FabricUnit


func asset_ids() -> Array[StringName]:
	var unique: Dictionary = {}
	for unit_value: FabricUnit in units:
		var unit_recipe := _recipes[unit_value.recipe_id] as FabricRecipe
		for placement: Dictionary in unit_recipe.placements:
			if unit_value.suppressed_placement_ids.has(
					StringName(placement.id)):
				continue
			unique[StringName(placement.asset_id)] = true
	if continuous_roof_plan != null:
		for asset_value: Variant in continuous_roof_plan.asset_overrides.values():
			unique[StringName(asset_value)] = true
		for placement: Dictionary in continuous_roof_plan.synthetic_placements:
			unique[StringName(placement.asset_id)] = true
	var out: Array[StringName] = []
	out.assign(unique.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out


func expanded_placements() -> Array[Dictionary]:
	## TASK I4 ROUND 6 adds `bounds`: the placement's own visual box in WORLD
	## space, `unit.transform() * recipe.placement_bounds[i]`. It is derived from
	## the same two facts the transform is -- the unit's pose and the sealed
	## recipe's measured box -- so it carries no new authority and cannot move a
	## signature; it is here because every caller that wanted "where is this
	## module really" was otherwise left with the recipe's ONE merged envelope.
	##
	## TASK I4 ROUND 7 adds `collision_pieces` beside it, off
	## `FabricRecipe.placement_collision_pieces`, for the same reason and under
	## the same contract: a rule that has to tell a slab a body walks INTO from a
	## leaf it walks THROUGH cannot read that out of a box.
	##
	## TASK I4 ROUND 8 FIX 1 adds `placement_id`, the recipe's own name for this
	## module, under that same contract. The DECOR class is keyed by asset and one
	## asset does two jobs -- the roof terrace's awning is also a covered market's
	## canopy -- so every reader of that class needs the name the recipe gave the
	## placement, and reconstructing it by splitting `stable_id` on a slash is a
	## parser where a field will do.
	var out: Array[Dictionary] = []
	for unit_value: FabricUnit in units:
		var unit_recipe := _recipes[unit_value.recipe_id] as FabricRecipe
		var unit_transform := unit_value.transform()
		for index in unit_recipe.placements.size():
			var placement := unit_recipe.placements[index]
			if unit_value.suppressed_placement_ids.has(
					StringName(placement.id)):
				continue
			out.append({
				"stable_id": StringName("%s/%s" % [unit_value.stable_id,
					StringName(placement.id)]),
				"placement_id": StringName(placement.id),
				"asset_id": StringName(placement.asset_id),
				"transform": unit_transform *
					(placement.transform as Transform3D),
				"bounds": unit_transform * unit_recipe.placement_bounds[index] \
					if index < unit_recipe.placement_bounds.size() else AABB(),
				"collision_pieces": \
					unit_recipe.placement_collision_pieces[index] \
					if index < unit_recipe.placement_collision_pieces.size() \
					else 0,
			})
	if continuous_roof_plan != null:
		return continuous_roof_plan.apply_to(out)
	return out


func suppress_placement(unit_id: StringName,
		placement_id: StringName) -> bool:
	## TASK I4 ROUND 7 -- withdraw ONE authored module from ONE built unit, before
	## the plan seals.
	##
	## WHY A MUTATOR AND NOT A CONSTRUCTOR ARGUMENT, which is the whole design
	## question. `_suppressed_party_wall_placements` decides off the sealed
	## SPATIAL GRID, which a room already holds when its unit is built. The two
	## suppressions round 7 adds decide off geometry that does not exist until
	## the units are in a plan -- the retained skin's own panels, and the public
	## realm's walk surfaces -- so the decision cannot be made at construction
	## without compiling the town twice.
	##
	## IT CANNOT WIDEN ANYTHING. A suppression only REMOVES a visual placement:
	## `transformed_cells` reads the recipe's semantic cells and never the
	## placements, `local_bounds` and `local_clearance_bounds` are the recipe's
	## own and are untouched, and `unit.bounds` is derived from `local_bounds`.
	## So every gate `add_unit` already passed -- occupancy, bearing, the
	## envelope-overlap proof -- holds unchanged, and `validate()` re-runs
	## `_accept_unit` over every unit at seal time, which is where the placement
	## id and the construction-run rule below are proved rather than assumed.
	##
	## What it DOES move is `construction_signature()`, which digests
	## suppressions -- by design: the record must say that this unit is missing a
	## module, and which one.
	last_rejection = ""
	if _sealed:
		last_rejection = "cannot suppress %s on a sealed plan" % placement_id
		return false
	var unit_value := _by_id.get(unit_id) as FabricUnit
	if unit_value == null:
		last_rejection = "no unit %s to suppress %s on" % [unit_id, placement_id]
		return false
	if unit_value.suppressed_placement_ids.has(placement_id):
		return true
	var unit_recipe := _recipes.get(unit_value.recipe_id) as FabricRecipe
	if unit_recipe == null:
		last_rejection = "unit %s references missing recipe %s" % [unit_id,
			unit_value.recipe_id]
		return false
	var known := false
	for placement: Dictionary in unit_recipe.placements:
		known = known or StringName(placement.id) == placement_id
	if not known:
		last_rejection = "unit %s has no placement %s to suppress" % [unit_id,
			placement_id]
		return false
	# The same rule `_accept_unit` enforces, stated here so a caller learns at the
	# decision rather than at the seal: a roof run is one construction and half of
	# it is not a thing that can be built.
	for run: Dictionary in unit_recipe.construction_runs:
		for run_placement: Variant in run.placement_ids as Array:
			if StringName(run_placement) == placement_id:
				last_rejection = ("placement %s belongs to construction run %s " \
					+ "and cannot be suppressed alone") % [placement_id, run.id]
				return false
	unit_value.suppressed_placement_ids.append(placement_id)
	unit_value.suppressed_placement_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b))
	_module_footprints_built = false
	_module_footprints = {}
	return true


func module_footprints() -> Dictionary:
	## The plan's own derived footprint index, built once. See
	## `SettlementFabricAssembler.maze_module_footprints`, which is the rule that
	## builds it and stays the one place the bucketing is written down.
	if not _module_footprints_built:
		_module_footprints = SettlementFabricAssembler \
			.build_maze_module_footprints(self)
		_module_footprints_built = true
	return _module_footprints


func visual_envelope_conflicts() -> Array[Dictionary]:
	## Diagnostic mirror of the hard construction gate. A sealed plan must
	## always return an empty list; exposing it keeps QA evidence inspectable.
	var conflicts: Array[Dictionary] = []
	for left_index in units.size():
		var left := units[left_index]
		var left_recipe := _recipes[left.recipe_id] as FabricRecipe
		if left_recipe.placements.is_empty():
			continue
		var left_bounds := left.transform() * left_recipe.local_clearance_bounds
		for right_index in range(left_index + 1, units.size()):
			var right := units[right_index]
			var right_recipe := _recipes[right.recipe_id] as FabricRecipe
			if right_recipe.placements.is_empty() \
					or _units_declare_connection(left, right):
				continue
			var right_bounds := right.transform() * right_recipe.local_clearance_bounds
			if _aabb_overlaps_volume(left_bounds, right_bounds):
				conflicts.append({"left": left.stable_id, "right": right.stable_id})
	return conflicts


func connected_visual_envelope_conflicts() -> Array[Dictionary]:
	## Connections permit one measured construction seam, not arbitrary mesh
	## interpenetration. The legacy gate exempted the complete AABBs of every
	## bearing ancestor/descendant pair, which could hide a roof cutting through
	## a related upper room. Keep this diagnostic separate while the existing
	## vocabulary is classified; it identifies exemptions that must become typed
	## seams before the rule can safely become a hard admission gate.
	var conflicts: Array[Dictionary] = []
	for left_index in units.size():
		var left := units[left_index]
		var left_recipe := _recipes[left.recipe_id] as FabricRecipe
		if left_recipe.placements.is_empty():
			continue
		var left_bounds := left.transform() * left_recipe.local_clearance_bounds
		for right_index in range(left_index + 1, units.size()):
			var right := units[right_index]
			var right_recipe := _recipes[right.recipe_id] as FabricRecipe
			if right_recipe.placements.is_empty() \
					or not _units_declare_connection(left, right):
				continue
			var right_bounds := right.transform() * \
				right_recipe.local_clearance_bounds
			if not _aabb_overlaps_volume(left_bounds, right_bounds):
				continue
			var overlap := _overlap_size(left_bounds, right_bounds)
			var direct_bearing := left.parent_ids.has(right.stable_id) \
				or right.parent_ids.has(left.stable_id)
			var lateral_seam := left.visual_seam_ids.has(right.stable_id) \
				or right.visual_seam_ids.has(left.stable_id) \
				or _has_direct_socket_target(left, right.stable_id) \
				or _has_direct_socket_target(right, left.stable_id)
			var bearing_seam_ok := direct_bearing and overlap.y <= 0.50
			var lateral_seam_ok := lateral_seam \
				and minf(overlap.x, overlap.z) <= 0.50
			var typed_flashing_ok := lateral_seam \
				and (left_recipe.has_tag(&"thin_roof_face") \
					or right_recipe.has_tag(&"thin_roof_face")) \
				and overlap.y <= TYPED_FLASHING_MAX_HEIGHT_M \
				and minf(overlap.x, overlap.z) \
					<= TYPED_FLASHING_MAX_HORIZONTAL_M
			var left_shed := left_recipe.has_tag(&"setback_shed")
			var right_shed := right_recipe.has_tag(&"setback_shed")
			var typed_shed_ok := lateral_seam and (
				(left_shed and _is_typed_shed_roof_contact(left_bounds,
					right_bounds) if right_recipe.has_tag(&"roof")
					else left_shed and _is_typed_shed_wall_contact(left_bounds,
						right_bounds))
				or (right_shed and _is_typed_shed_roof_contact(left_bounds,
					right_bounds) if left_recipe.has_tag(&"roof")
					else right_shed and _is_typed_shed_wall_contact(left_bounds,
						right_bounds)))
			if bearing_seam_ok or lateral_seam_ok or typed_flashing_ok \
					or typed_shed_ok:
				continue
			conflicts.append({
				"left": left.stable_id,
				"left_recipe": left.recipe_id,
				"right": right.stable_id,
				"right_recipe": right.recipe_id,
				"overlap_m": overlap,
				"direct_bearing": direct_bearing,
				"lateral_seam": lateral_seam,
				"transitive_only": not direct_bearing and not lateral_seam,
			})
	return conflicts


func _connected_roof_seam_is_measured(left: FabricUnit,
		left_recipe: FabricRecipe, left_bounds: AABB, right: FabricUnit,
		right_recipe: FabricRecipe, right_bounds: AABB) -> bool:
	## TASK I4, ANNOTATION 4 -- "glitch with roof disappearing into the wall".
	##
	## THE JUNCTION RULE THAT ADMITTED IT IS THIS EXEMPTION. `add_unit` and
	## `validate` both let ANY connected pair interpenetrate without bound:
	## bearing ancestry, a socket bond or a declared visual seam and the two
	## envelopes may pass through each other by any amount. A pitched roof and the
	## taller room it leans against are always connected -- they share a bearing
	## DAG -- so the roof was admitted however far its slope drove into the wall.
	##
	## `connected_visual_envelope_conflicts` has MEASURED that exemption since it
	## was written and says so in its own docstring: "it identifies exemptions
	## that must become typed seams before the rule can safely become a hard
	## admission gate". On the four planner towns it reads 10-20 pairs a town, and
	## the worst of them is a roof 1.198 m into an upper room over 3.0 m of height
	## -- which is the annotation, in numbers.
	##
	## THE GATE IS NOW ARMED, FOR ROOFS ONLY. The allowances are finite typed
	## construction seams; what changes is that
	## a pair one of whose sides is a `roof` recipe has to satisfy one of them
	## instead of being waved through. Pairs with no roof in them keep the old
	## unbounded exemption -- room-into-room is a different question with a
	## different vocabulary behind it, and arming it here would be a change this
	## annotation did not ask for and no capture has been read against.
	if not _contains_pitched_roof(left_recipe) \
			and not _contains_pitched_roof(right_recipe):
		return true
	var overlap := _overlap_size(left_bounds, right_bounds)
	# A roof RESTS on its own room, and that is a bearing seam rather than a
	# collision: the shell's lower course is meant to sit inside the wall head it
	# lands on. Only a DIRECT parent counts -- a transitive ancestor is the
	# unrelated tower three storeys down that the diagnostic keeps catching.
	var direct_bearing := left.parent_ids.has(right.stable_id) \
		or right.parent_ids.has(left.stable_id)
	# A direct bearing bond does not imply "vertically below". Occupied bridge
	# houses bind their two lateral endpoint buildings through the same socket
	# kind, and the old unconditional allowance let the bridge roof disappear
	# arbitrarily far into either endpoint. Only the thin wall-head course of a
	# genuinely vertical roof seat is a roof/bearing seam. Lateral bridge bonds
	# continue into the explicit eave/gable rules below.
	var vertical_bearing := direct_bearing \
		and _is_vertical_roof_bearing(left, left_recipe, left_bounds,
			right, right_recipe, right_bounds)
	if vertical_bearing:
		return true
	var lateral_seam := left.visual_seam_ids.has(right.stable_id) \
		or right.visual_seam_ids.has(left.stable_id) \
		or _has_direct_socket_target(left, right.stable_id) \
		or _has_direct_socket_target(right, left.stable_id)
	if lateral_seam and minf(overlap.x, overlap.z) <= 0.50:
		return true
	if lateral_seam and (left_recipe.has_tag(&"thin_roof_face") \
			or right_recipe.has_tag(&"thin_roof_face")) \
			and overlap.y <= TYPED_FLASHING_MAX_HEIGHT_M \
			and minf(overlap.x, overlap.z) <= TYPED_FLASHING_MAX_HORIZONTAL_M:
		return true
	var left_shed := left_recipe.has_tag(&"setback_shed")
	var right_shed := right_recipe.has_tag(&"setback_shed")
	if lateral_seam and (
			(left_shed and _is_typed_shed_roof_contact(left_bounds, right_bounds)
				if right_recipe.has_tag(&"roof")
				else left_shed and _is_typed_shed_wall_contact(left_bounds,
					right_bounds))
			or (right_shed and _is_typed_shed_roof_contact(left_bounds,
				right_bounds) if left_recipe.has_tag(&"roof")
				else right_shed and _is_typed_shed_wall_contact(left_bounds,
					right_bounds))):
		return true
	# Occupied bridge houses deliberately retain the ordinary side eave the
	# screenshot was missing, while their endpoint tower owns a footprint-tight
	# seam gable. The source topology names the direct visual seam; constrain its
	# permissible lap to one fine construction cell, the finite domain occupied
	# by that authored eave. This is not a general roof tolerance: both semantic
	# roles and the explicit connection are required.
	var typed_bridge_gable := lateral_seam and (
		(left_recipe.has_tag(&"bridge_eave_roof") \
			and right_recipe.has_tag(&"terminal_tight_gable"))
		or (right_recipe.has_tag(&"bridge_eave_roof") \
			and left_recipe.has_tag(&"terminal_tight_gable")))
	if typed_bridge_gable \
			and minf(overlap.x, overlap.z) <= FabricRecipe.CELL_SIZE:
		return true
	# Two pitched crowns may touch only through one of the finite junctions above.
	# The generic shallow-envelope fallback below exists for a roof meeting a wall
	# course; applying it to two full-height slopes admitted crossed or nested
	# crowns whose ridges could never tile as one roof.
	if _contains_pitched_roof(left_recipe) \
			and _contains_pitched_roof(right_recipe):
		return false
	# EVERYTHING ELSE IS A SEAM THE VOCABULARY HAS NOT TYPED YET, and the gate
	# does not pretend otherwise: it refuses only the overlaps that cannot be a
	# seam under any reading -- deeper than a flashing IN PLAN and taller than a
	# whole band. That is a shell standing INSIDE the thing it meets, which is
	# what "disappearing into the wall" is, and it is the only class this
	# annotation asks about. The narrower typed seams above stay the way a
	# junction is admitted; the untyped remainder stays exempt and stays on the
	# diagnostic, where the next roof task can read it.
	return minf(overlap.x, overlap.z) <= ROOF_EMBEDDED_MIN_HORIZONTAL_M \
		or overlap.y <= ROOF_EMBEDDED_MIN_HEIGHT_M


static func _contains_pitched_roof(recipe_value: FabricRecipe) -> bool:
	return recipe_value != null and (recipe_value.has_tag(&"roof") \
		or recipe_value.has_tag(&"integrated_pitched_roof"))


static func _is_vertical_roof_bearing(left: FabricUnit,
		left_recipe: FabricRecipe, left_bounds: AABB, right: FabricUnit,
		right_recipe: FabricRecipe, right_bounds: AABB) -> bool:
	## A roof-bearing seam is a horizontal wall-head plane. Parenthood by itself
	## cannot prove that orientation because occupied bridges also have lateral
	## bearing parents. Require the lower envelope to terminate at the upper
	## envelope's bearing course, with only the reviewed shallow embed in Y.
	var left_is_roof := _contains_pitched_roof(left_recipe)
	var right_is_roof := _contains_pitched_roof(right_recipe)
	if left_is_roof == right_is_roof:
		# An integrated roofed room can stand on another ordinary room, but two
		# roof-bearing envelopes meeting laterally are never a wall-head seat.
		if left_is_roof and right_is_roof:
			return false
		return true
	var roof_unit := left if left_is_roof else right
	var support_unit := right if left_is_roof else left
	if not roof_unit.parent_ids.has(support_unit.stable_id):
		return false
	var roof_bounds := left_bounds if left_is_roof else right_bounds
	var support_bounds := right_bounds if left_is_roof else left_bounds
	var overlap := _overlap_size(roof_bounds, support_bounds)
	return overlap.x > 0.0 and overlap.z > 0.0 \
		and overlap.y <= ROOF_EMBEDDED_MIN_HEIGHT_M \
		and absf(roof_bounds.position.y - support_bounds.end.y) \
			<= ROOF_EMBEDDED_MIN_HEIGHT_M


static func _has_direct_socket_target(unit_value: FabricUnit,
		target_id: StringName) -> bool:
	for bond: Dictionary in unit_value.socket_bonds:
		if StringName(bond.get("target_unit", &"")) == target_id:
			return true
	return false


static func _overlap_size(left: AABB, right: AABB) -> Vector3:
	return Vector3(
		minf(left.end.x, right.end.x) - maxf(left.position.x, right.position.x),
		minf(left.end.y, right.end.y) - maxf(left.position.y, right.position.y),
		minf(left.end.z, right.end.z) - maxf(left.position.z, right.position.z))


func _units_declare_connection(left: FabricUnit,
		right: FabricUnit) -> bool:
	if left.visual_seam_ids.has(right.stable_id) \
			or right.visual_seam_ids.has(left.stable_id):
		return true
	if left.parent_ids.has(right.stable_id) or right.parent_ids.has(left.stable_id):
		return true
	for bond: Dictionary in left.socket_bonds:
		if StringName(bond.get("target_unit", "")) == right.stable_id:
			return true
	for bond: Dictionary in right.socket_bonds:
		if StringName(bond.get("target_unit", "")) == left.stable_id:
			return true
	return _is_bearing_ancestor(left, right.stable_id) \
		or _is_bearing_ancestor(right, left.stable_id)


func _is_bearing_ancestor(unit_value: FabricUnit,
		candidate_ancestor: StringName) -> bool:
	var pending: Array[StringName] = []
	pending.assign(unit_value.parent_ids)
	var visited: Dictionary = {}
	while not pending.is_empty():
		var parent_id: StringName = pending.pop_back()
		if parent_id == candidate_ancestor:
			return true
		if visited.has(parent_id):
			continue
		visited[parent_id] = true
		var parent := _by_id.get(parent_id) as FabricUnit
		if parent != null:
			pending.append_array(parent.parent_ids)
	return false


## DIAGNOSTIC ONLY -- MUST NOT SHIP ENABLED. Exempts corner-only envelope
## overlaps, and nothing else, so a town whose sole remaining defect is that
## class can be composed and LOOKED AT. It does not make the geometry correct:
## two buildings meeting at a corner interpenetrate by roughly half a metre of
## roof overhang, because no authored roof is flush with its lattice footprint
## (measured: the tightest variant clears 0.234 m past it on every side, and
## rooms are flush, so the shorter house's roof always cuts into the taller
## one's wall). Enabling this is how to judge whether that reads badly on
## screen; it is not a tolerance until someone has looked and said so.
##
## Enable only from a review harness, never from a test:
##   SettlementFabricPlan.DIAGNOSTIC_ALLOW_CORNER_ENVELOPE_OVERLAP = true
static var DIAGNOSTIC_ALLOW_CORNER_ENVELOPE_OVERLAP := false
## DIAGNOSTIC ONLY -- MUST NOT SHIP ENABLED. Lets the rendered review harness
## expose a shallow roof/fascia edge intersection when the overlap is small on
## two of three axes. Production remains strict so the image can guide an
## authored seam/packing fix without normalizing the defect.
static var DIAGNOSTIC_ALLOW_EDGE_ENVELOPE_OVERLAP := false
## A corner nick is small on BOTH horizontal axes -- two footprints touching at
## a point, overlapping only by what their roofs project. A genuine face
## overlap runs the length of the shared wall, metres rather than centimetres,
## so this cannot silently forgive stacked or interpenetrating buildings.
## One lattice micro cell. Two roofs meeting at a corner overlap by twice
## their overhang -- measured at 0.66 m and 1.16 m on the two axes -- while a
## genuine face overlap runs the length of a shared wall, 3 m or more. A
## metre-and-a-half separates those cleanly; 1.0 m did not, and wrongly left
## roof-to-roof corners looking like a second, unexplained failure mode.
const DIAGNOSTIC_CORNER_NICK_METRES := 1.5
const DIAGNOSTIC_EDGE_NICK_METRES := 0.5
## Production typed-flashing bounds. These mirror the compiler's exact thin-cap
## seam: the cap is deliberately lowered beneath a pitched eave, so a shallow
## overlap is the weatherproof join rather than an unresolved collision.
const TYPED_FLASHING_MAX_HORIZONTAL_M := 0.90
const TYPED_FLASHING_MAX_HEIGHT_M := 0.25
## The authored setback shed is only 0.828 m tall.  Unlike a horizontal cap,
## its complete pitch must enter the adjoining facade/eave far enough to make a
## weatherproof T-junction.  These bounds are deliberately below one lattice
## cell and apply only to an explicitly named lateral construction seam.
const TYPED_SHED_WALL_MAX_HORIZONTAL_M := 0.90
const TYPED_SHED_ROOF_MAX_HORIZONTAL_M := 1.60
const TYPED_SHED_MAX_HEIGHT_M := 0.85
## TASK I4, ANNOTATION 4. How far into a connected neighbour a ROOF shell has to
## reach before the pair stops being a seam of any kind and becomes the
## "disappearing into the wall" the annotation circled. BOTH bounds have to be
## exceeded together, and both are read off the vocabulary rather than chosen:
##
## * IN PLAN, HALF A CELL. A roof that laps less than half a cell into the thing
##   beside it still has its body on its OWN side of the shared boundary, which
##   is a junction meeting a neighbour; past half a cell its body is centred
##   inside the neighbour's cell, which is a shell standing in it. The bound is
##   the lattice's own, not a taste: `FabricRecipe.CELL_SIZE * 0.5`.
## * IN HEIGHT, more than 1.00 m. The one-band contact a roof makes with the
##   wall head it lands on is exactly 1.5 m, so a bound at 1.5 admits every
##   embed the corpus actually has; but that contact is a DIRECT BEARING pair
##   and is exempted above by name. What is left at 1.5 m is a roof inside an
##   unrelated neighbour, and 1.00 m is comfortably under it while staying well
##   over the 0.25 m a typed flashing may overlap.
##
## THE PLAN BOUND WAS 0.50 m FIRST -- the lateral seam allowance `lateral_seam_ok`
## already admits -- AND THAT WAS TOO TIGHT, measured rather than argued. At
## 0.50 m the gate refused `roof.tower.orange` AND `roof.tower.chimney.orange` on
## `parcel.maze.house.004.part01.room00` of 3/standard, both against the same
## unrelated upper room and both by 0.583 m in plan; the compiler's fallback
## chain ran out and the crown shipped with NO ROOF UNIT ON TWO OF ITS FACES
## (`test_partial_plates_are_tiled`, and the production-site test with it). A
## hole in a roof is a worse artefact than the seam the bound was removing, so
## the bound moved to the first defensible number above it.
##
## MEASURED on the four planner towns at 0.75 m: the pairs it refuses read
## 0.77-1.20 m in plan over 1.5-3.4 m of height, and the annotation's own worst
## pair -- a roof 1.198 m into an upper room over 3.0 m -- is still refused, which
## is the whole point. The typed seams the vocabulary relies on read 0.16-0.50 m
## in plan and are untouched. Every planner town still composes AND still closes
## every crown.
const ROOF_EMBEDDED_MIN_HORIZONTAL_M := FabricRecipe.CELL_SIZE * 0.5
const ROOF_EMBEDDED_MIN_HEIGHT_M := 1.00


static func _is_corner_nick(left: AABB, right: AABB) -> bool:
	var overlap_x := minf(left.end.x, right.end.x) \
		- maxf(left.position.x, right.position.x)
	var overlap_z := minf(left.end.z, right.end.z) \
		- maxf(left.position.z, right.position.z)
	return overlap_x <= DIAGNOSTIC_CORNER_NICK_METRES \
		and overlap_z <= DIAGNOSTIC_CORNER_NICK_METRES


static func _is_edge_nick(left: AABB, right: AABB) -> bool:
	var overlaps := [
		minf(left.end.x, right.end.x) - maxf(left.position.x, right.position.x),
		minf(left.end.y, right.end.y) - maxf(left.position.y, right.position.y),
		minf(left.end.z, right.end.z) - maxf(left.position.z, right.position.z),
	]
	var shallow_axis_count := 0
	for overlap: float in overlaps:
		shallow_axis_count += int(overlap <= DIAGNOSTIC_EDGE_NICK_METRES)
	return shallow_axis_count >= 2


static func _is_typed_shed_wall_contact(left: AABB, right: AABB) -> bool:
	if not _aabb_overlaps_volume(left, right):
		return false
	var overlap := _overlap_size(left, right)
	return overlap.y <= TYPED_SHED_MAX_HEIGHT_M \
		and minf(overlap.x, overlap.z) <= TYPED_SHED_WALL_MAX_HORIZONTAL_M


static func _is_typed_shed_roof_contact(left: AABB, right: AABB) -> bool:
	if not _aabb_overlaps_volume(left, right):
		return false
	var overlap := _overlap_size(left, right)
	return overlap.y <= TYPED_SHED_MAX_HEIGHT_M \
		and minf(overlap.x, overlap.z) <= TYPED_SHED_ROOF_MAX_HORIZONTAL_M


static func _aabb_overlaps_volume(left: AABB, right: AABB,
		epsilon: float = 0.10) -> bool:
	# Authored floor/fascia seams overlap by at most 8.6 cm at nominal tile
	# pitch. Treat that reviewed join as contact; anything deeper is structure.
	var overlap_x := minf(left.end.x, right.end.x) \
		- maxf(left.position.x, right.position.x)
	var overlap_y := minf(left.end.y, right.end.y) \
		- maxf(left.position.y, right.position.y)
	var overlap_z := minf(left.end.z, right.end.z) \
		- maxf(left.position.z, right.position.z)
	return overlap_x > epsilon and overlap_y > epsilon and overlap_z > epsilon


func transformed_cells(layer: StringName,
		required_tag: StringName = &"") -> Dictionary:
	## Returns world-lattice cells owned by recipes in one semantic layer. The
	## value is the owning unit id; callers never need to inspect render assets.
	var out: Dictionary = {}
	for unit_value: FabricUnit in units:
		var unit_recipe := _recipes[unit_value.recipe_id] as FabricRecipe
		if not required_tag.is_empty() and not unit_recipe.has_tag(required_tag):
			continue
		var local_cells: Array[Vector3i] = []
		match layer:
			&"solid":
				local_cells = unit_recipe.solid_cells
			&"walk":
				local_cells = unit_recipe.walk_cells
			&"headroom":
				local_cells = unit_recipe.headroom_cells
			&"public_air":
				local_cells = unit_recipe.public_air_cells
			&"inhabited":
				local_cells = unit_recipe.inhabited_cells
			&"occluder":
				local_cells = unit_recipe.occluder_cells
			&"terrain_bearing":
				local_cells = unit_recipe.terrain_bearing_cells
			_:
				return {}
		for local_cell: Vector3i in local_cells:
			out[FabricRecipe.transform_cell(local_cell,
				unit_value.lattice_origin, unit_value.yaw_quarters)] = \
				unit_value.stable_id
	return out


func transformed_visual_clearance_cells() -> Dictionary:
	## Conservative lattice projection of measured visuals for upstream search.
	## It supplements semantic solids; it never replaces the exact envelope gate.
	var out: Dictionary = {}
	var half_cell := FabricRecipe.CELL_SIZE * 0.5
	for unit_value: FabricUnit in units:
		var unit_recipe := _recipes[unit_value.recipe_id] as FabricRecipe
		if unit_recipe.placements.is_empty():
			continue
		var bounds := unit_value.transform() * unit_recipe.local_clearance_bounds
		var minimum := Vector3i(
			ceili((bounds.position.x - half_cell) / FabricRecipe.CELL_SIZE),
			ceili((bounds.position.y - half_cell) / FabricRecipe.CELL_SIZE),
			ceili((bounds.position.z - half_cell) / FabricRecipe.CELL_SIZE))
		var maximum := Vector3i(
			floori((bounds.end.x + half_cell) / FabricRecipe.CELL_SIZE),
			floori((bounds.end.y + half_cell) / FabricRecipe.CELL_SIZE),
			floori((bounds.end.z + half_cell) / FabricRecipe.CELL_SIZE))
		for y in range(minimum.y, maximum.y + 1):
			for z in range(minimum.z, maximum.z + 1):
				for x in range(minimum.x, maximum.x + 1):
					out[Vector3i(x, y, z)] = unit_value.stable_id
	return out


func transformed_visual_clearance_bounds() -> Array[AABB]:
	## Exact continuous envelopes for coupled upstream solvers. The lattice
	## projection above is useful for broad-phase cell rejection; it cannot prove
	## that a roof peak misses the underside of a stair between cell centres.
	var out: Array[AABB] = []
	for unit_value: FabricUnit in units:
		var unit_recipe := _recipes[unit_value.recipe_id] as FabricRecipe
		if unit_recipe.placements.is_empty():
			continue
		out.append(unit_value.transform() * unit_recipe.local_clearance_bounds)
	return out


func _validate_public_realm_bindings() -> bool:
	var binding_count: Dictionary = {}
	for unit_value: FabricUnit in units:
		var unit_recipe := _recipes[unit_value.recipe_id] as FabricRecipe
		if not unit_recipe.has_tag(&"public_walk"):
			continue
		if unit_recipe.has_tag(&"interior_walk"):
			last_rejection = "interior-walk unit %s entered exterior realm" % \
				unit_value.stable_id
			return false
		if unit_value.public_node_id.is_empty():
			last_rejection = "public unit %s has no realm binding" % \
				unit_value.stable_id
			return false
		var node_value := public_realm.node(unit_value.public_node_id)
		if node_value == null:
			last_rejection = "public unit %s binds missing node %s" % [
				unit_value.stable_id, unit_value.public_node_id]
			return false
		binding_count[unit_value.public_node_id] = \
			int(binding_count.get(unit_value.public_node_id, 0)) + 1
		for local_cell: Vector3i in unit_recipe.walk_cells:
			var cell := FabricRecipe.transform_cell(local_cell,
				unit_value.lattice_origin, unit_value.yaw_quarters)
			if not node_value.has_cell(cell):
				last_rejection = "public unit %s cell %s lies outside node %s" % [
					unit_value.stable_id, cell, node_value.stable_id]
				return false
		for local_cell: Vector3i in unit_recipe.public_air_cells:
			var cell := FabricRecipe.transform_cell(local_cell,
				unit_value.lattice_origin, unit_value.yaw_quarters)
			if not node_value.has_air_cell(cell):
				last_rejection = "public unit %s air cell %s lies outside node %s" % [
					unit_value.stable_id, cell, node_value.stable_id]
				return false
	for node_value: PublicRealmNode in public_realm.nodes:
		if node_value.requires_fabric_unit \
				and int(binding_count.get(node_value.stable_id, 0)) == 0:
			last_rejection = "required node %s has no fabric unit" % \
				node_value.stable_id
			return false
	return true


func construction_signature() -> String:
	## Seed-independent signature of the actual sealed construction. It includes
	## every route, room, prefab, market, stair, projection, and skywalk transform;
	## changing only a seed label or audit field cannot change this value.
	var records := PackedStringArray()
	for unit_value: FabricUnit in units:
		var parent_ids := PackedStringArray()
		for parent_id: StringName in unit_value.parent_ids:
			parent_ids.append(String(parent_id))
		parent_ids.sort()
		var bond_records := PackedStringArray()
		for bond: Dictionary in unit_value.socket_bonds:
			bond_records.append("%s>%s:%s" % [bond.own_socket,
				bond.target_unit, bond.target_socket])
		bond_records.sort()
		var suppressed := PackedStringArray()
		for placement_id: StringName in unit_value.suppressed_placement_ids:
			suppressed.append(String(placement_id))
		suppressed.sort()
		var origin := unit_value.lattice_origin
		var suppression_suffix := "/x[%s]" % ",".join(suppressed) \
			if not suppressed.is_empty() else ""
		records.append("%s:%s@%d,%d,%d/r%d/p[%s]/b[%s]%s" % [
			unit_value.stable_id, unit_value.recipe_id, origin.x, origin.y,
			origin.z, unit_value.yaw_quarters, ",".join(parent_ids),
			",".join(bond_records), suppression_suffix])
	records.sort()
	return "|".join(records).sha256_text()


func _validate_surface_coverage() -> bool:
	var expected: Dictionary = {}
	var solids := transformed_cells(&"solid")
	if public_realm != null:
		for cell_value: Variant in public_realm.surface_claims():
			var cell := cell_value as Vector3i
			if solids.has(cell):
				last_rejection = "public surface %s overlaps structural solid" % cell
				return false
			expected[_cell_key(cell)] = true
	for unit_value: FabricUnit in units:
		var unit_recipe := _recipes[unit_value.recipe_id] as FabricRecipe
		if not unit_recipe.has_tag(&"public_walk"):
			continue
		for local_cell: Vector3i in unit_recipe.walk_cells:
			var cell := FabricRecipe.transform_cell(local_cell,
				unit_value.lattice_origin, unit_value.yaw_quarters)
			expected[_cell_key(cell)] = true
			if not surface_plan.has_cell(cell):
				last_rejection = "public unit %s has no surface at %s" % [
					unit_value.stable_id, cell]
				return false
	# The surface compiler's bounded concave-corner closure is a first-class
	# topology result. Name its exact cells in the expected union rather than
	# weakening the equality check that catches all other invented surfaces.
	for cell: Vector3i in surface_plan.derived_claim_cells():
		if solids.has(cell):
			last_rejection = "derived public surface %s overlaps structural solid" \
				% cell
			return false
		expected[_cell_key(cell)] = true
	if surface_plan.claim_count() != expected.size():
		last_rejection = "surface union has %d claims for %d expected cells" % [
			surface_plan.claim_count(), expected.size()]
		return false
	return true


func _accept_unit(unit_value: FabricUnit, seen: Dictionary,
		solid: Dictionary, walk: Dictionary, headroom: Dictionary,
		journal: Array[Array] = []) -> bool:
	if unit_value == null or not unit_value.is_valid():
		last_rejection = "null or invalid fabric unit"
		return false
	if seen.has(unit_value.stable_id):
		last_rejection = "duplicate unit id %s" % unit_value.stable_id
		return false
	if not _recipes.has(unit_value.recipe_id):
		last_rejection = "unit %s references missing recipe %s" % [
			unit_value.stable_id, unit_value.recipe_id]
		return false
	var unit_recipe := _recipes[unit_value.recipe_id] as FabricRecipe
	if unit_recipe.has_tag(&"pitched_roof") \
			and not unit_recipe.has_tag(&"partial_gable") \
			and not _pitched_roof_alignment_holds(unit_recipe):
		last_rejection = ("pitched roof %s is not centred and seated on its " \
			+ "declared lattice footprint") % unit_value.recipe_id
		return false
	var recipe_placement_ids: Dictionary = {}
	for placement: Dictionary in unit_recipe.placements:
		recipe_placement_ids[StringName(placement.id)] = true
	for placement_id: StringName in unit_value.suppressed_placement_ids:
		if not recipe_placement_ids.has(placement_id):
			last_rejection = "unit %s suppresses missing placement %s" % [
				unit_value.stable_id, placement_id]
			return false
	for run: Dictionary in unit_recipe.construction_runs:
		for placement_value: Variant in run.placement_ids as Array:
			if unit_value.suppressed_placement_ids.has(
					StringName(placement_value)):
				last_rejection = ("unit %s partially suppresses authored " \
					+ "construction run %s") % [unit_value.stable_id, run.id]
				return false
	if unit_value.parent_ids.size() != unit_recipe.bearing_parent_count:
		last_rejection = "unit %s has %d bearing parents; recipe requires %d" % [
			unit_value.stable_id, unit_value.parent_ids.size(),
			unit_recipe.bearing_parent_count]
		return false
	for parent_id: StringName in unit_value.parent_ids:
		if not seen.has(parent_id):
			last_rejection = "unit %s references unbuilt parent %s" % [
				unit_value.stable_id, parent_id]
			return false
	for seam_id: StringName in unit_value.visual_seam_ids:
		if not seen.has(seam_id):
			last_rejection = "unit %s references unbuilt visual seam %s" % [
				unit_value.stable_id, seam_id]
			return false
	var bearing_targets: Dictionary = {}
	for bond: Dictionary in unit_value.socket_bonds:
		var own_socket_id := StringName(bond.own_socket)
		var target_id := StringName(bond.target_unit)
		var target_socket_id := StringName(bond.target_socket)
		if not seen.has(target_id):
			last_rejection = "unit %s bond references unbuilt target %s" % [
				unit_value.stable_id, target_id]
			return false
		var target_unit := seen[target_id] as FabricUnit
		var target_recipe := _recipes[target_unit.recipe_id] as FabricRecipe
		var own_socket := unit_recipe.socket(own_socket_id)
		var target_socket := target_recipe.socket(target_socket_id)
		if own_socket.is_empty() or target_socket.is_empty() \
				or int(own_socket.kind) != int(target_socket.kind) \
				or not _sockets_meet(unit_value, own_socket,
					target_unit, target_socket):
			last_rejection = "unit %s socket %s does not meet %s.%s" % [
				unit_value.stable_id, own_socket_id, target_id, target_socket_id]
			return false
		if int(own_socket.kind) == FabricRecipe.SocketKind.BEARING:
			bearing_targets[target_id] = true
	if bearing_targets.size() != unit_value.parent_ids.size():
		last_rejection = "unit %s does not bind every bearing parent" % \
			unit_value.stable_id
		return false
	for parent_id: StringName in unit_value.parent_ids:
		if not bearing_targets.has(parent_id):
			last_rejection = "unit %s lacks a bearing bond to %s" % [
				unit_value.stable_id, parent_id]
			return false
	if not _claim_cells(unit_recipe.solid_cells, unit_value, solid,
			[solid, headroom, walk], &"solid", journal):
		return false
	if not _claim_cells(unit_recipe.headroom_cells, unit_value, headroom,
			[solid, headroom], &"headroom", journal):
		return false
	if not _claim_cells(unit_recipe.walk_cells, unit_value, walk,
			[solid, walk], &"walk", journal):
		return false
	return true


static func _pitched_roof_alignment_holds(recipe_value: FabricRecipe) -> bool:
	## A complete crown's lattice solid is its construction contract. Authored
	## eaves may extend outside it, but their measured union must remain centred
	## over the footprint and its lowest visual point must sit on the wall-top
	## band centre. This rejects floating/offset roofs before any unit can enter a
	## plan; render-time offsets are neither needed nor permitted.
	if recipe_value == null or recipe_value.solid_cells.is_empty() \
			or not recipe_value.local_bounds.has_volume():
		return false
	var local_min := Vector3(INF, INF, INF)
	var local_max := Vector3(-INF, -INF, -INF)
	for cell: Vector3i in recipe_value.solid_cells:
		var centre := Vector3(cell) * FabricRecipe.CELL_SIZE
		local_min = local_min.min(centre - Vector3.ONE \
			* FabricRecipe.CELL_SIZE * 0.5)
		local_max = local_max.max(centre + Vector3.ONE \
			* FabricRecipe.CELL_SIZE * 0.5)
	var logical_centre := (local_min + local_max) * 0.5
	var visual_centre := recipe_value.local_bounds.get_center()
	var horizontal_offset := Vector2(visual_centre.x, visual_centre.z) \
		.distance_to(Vector2(logical_centre.x, logical_centre.z))
	var bearing_y := local_min.y + FabricRecipe.CELL_SIZE * 0.5
	return horizontal_offset <= 0.01 \
		and absf(recipe_value.local_bounds.position.y - bearing_y) <= 0.01


func _all_public_walk_reaches_landing(by_id: Dictionary) -> bool:
	var public_ids: Dictionary = {}
	var landings: Dictionary = {}
	var adjacency: Dictionary = {}
	for unit_value: FabricUnit in units:
		var unit_recipe := _recipes[unit_value.recipe_id] as FabricRecipe
		if not unit_recipe.has_tag(&"public_walk"):
			continue
		public_ids[unit_value.stable_id] = true
		adjacency[unit_value.stable_id] = []
		if unit_recipe.has_tag(&"route_landing"):
			landings[unit_value.stable_id] = true
	if public_ids.is_empty():
		return true
	if landings.is_empty():
		return false
	for unit_value: FabricUnit in units:
		if not public_ids.has(unit_value.stable_id):
			continue
		var unit_recipe := _recipes[unit_value.recipe_id] as FabricRecipe
		for bond: Dictionary in unit_value.socket_bonds:
			var own_socket := unit_recipe.socket(StringName(bond.own_socket))
			if own_socket.is_empty() \
					or int(own_socket.kind) != FabricRecipe.SocketKind.WALK:
				continue
			var target_id := StringName(bond.target_unit)
			if not public_ids.has(target_id):
				continue
			(adjacency[unit_value.stable_id] as Array).append(target_id)
			(adjacency[target_id] as Array).append(unit_value.stable_id)
	var reached: Dictionary = {}
	var pending: Array[StringName] = []
	pending.assign(landings.keys())
	while not pending.is_empty():
		var current: StringName = pending.pop_back()
		if reached.has(current):
			continue
		reached[current] = true
		for neighbor: StringName in adjacency[current] as Array:
			if not reached.has(neighbor):
				pending.append(neighbor)
	return reached.size() == public_ids.size()


func _claim_cells(local_cells: Array[Vector3i], unit_value: FabricUnit,
		owner: Dictionary, conflicts: Array[Dictionary], layer: StringName,
		journal: Array[Array] = []) -> bool:
	var world_cells: Array[String] = []
	for local_cell: Vector3i in local_cells:
		var world_cell := FabricRecipe.transform_cell(local_cell,
			unit_value.lattice_origin, unit_value.yaw_quarters)
		var key := _cell_key(world_cell)
		for conflict: Dictionary in conflicts:
			if conflict.has(key):
				last_rejection = "%s cell %s for %s overlaps %s" % [layer,
					key, unit_value.stable_id, conflict[key]]
				return false
		world_cells.append(key)
	for key: String in world_cells:
		owner[key] = unit_value.stable_id
	# TASK F2. `owner` is always one of its own `conflicts`, so a key that
	# reached this loop was NOT already in `owner`: the journal therefore holds
	# only keys this call created, and erasing them is an exact undo.
	if not world_cells.is_empty():
		journal.append([owner, world_cells])
	return true


static func _sockets_meet(unit_a: FabricUnit, socket_a: Dictionary,
		unit_b: FabricUnit, socket_b: Dictionary) -> bool:
	var cell_a := FabricRecipe.transform_cell(socket_a.cell as Vector3i,
		unit_a.lattice_origin, unit_a.yaw_quarters)
	var cell_b := FabricRecipe.transform_cell(socket_b.cell as Vector3i,
		unit_b.lattice_origin, unit_b.yaw_quarters)
	var facing_a := FabricRecipe.transform_direction(socket_a.facing as Vector3i,
		unit_a.yaw_quarters)
	var facing_b := FabricRecipe.transform_direction(socket_b.facing as Vector3i,
		unit_b.yaw_quarters)
	return cell_a + facing_a == cell_b and cell_b + facing_b == cell_a


static func _aabb_is_equal(a: AABB, b: AABB) -> bool:
	return a.position.is_equal_approx(b.position) \
		and a.size.is_equal_approx(b.size)


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]
