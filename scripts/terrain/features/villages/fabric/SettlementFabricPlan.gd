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
## Empty for a route-first town: WarrenFabricCompiler declares the wider hill
## only where the massif provenance is present.
var retained_terrace_cells: Dictionary = {}
var audit: Dictionary = {}
var _recipes: Dictionary = {}
var _by_id: Dictionary = {}
var _solid_owner: Dictionary = {}
var _walk_owner: Dictionary = {}
var _headroom_owner: Dictionary = {}
var _terrace_declared := false
var _sealed := false
var last_rejection := ""


func _init(p_stable_id: StringName) -> void:
	stable_id = p_stable_id


func register_recipe(recipe: FabricRecipe) -> bool:
	if _sealed or recipe == null or not recipe.is_sealed() \
			or _recipes.has(recipe.recipe_id):
		return false
	_recipes[recipe.recipe_id] = recipe
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
	## stone must be mass nobody built in.
	if _sealed or _terrace_declared:
		return false
	for cell_value: Variant in cells.keys():
		if _solid_owner.has(cell_value):
			return false
	retained_terrace_cells = cells.duplicate()
	_terrace_declared = true
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
	# _accept_unit claims semantic cells as it validates them. Stage those
	# mutations so a later visual-envelope rejection cannot leave ghost claims
	# that poison a measured fallback attempted in the same plan.
	var trial_solid := _solid_owner.duplicate()
	var trial_walk := _walk_owner.duplicate()
	var trial_headroom := _headroom_owner.duplicate()
	if not _accept_unit(unit, _by_id, trial_solid,
			trial_walk, trial_headroom):
		return false
	var recipe := _recipes[unit.recipe_id] as FabricRecipe
	var transform := unit.transform()
	unit.bounds = transform * recipe.local_bounds
	var clearance_bounds := transform * recipe.local_clearance_bounds
	for existing: FabricUnit in units:
		var existing_recipe := _recipes[existing.recipe_id] as FabricRecipe
		if recipe.placements.is_empty() or existing_recipe.placements.is_empty() \
				or _units_declare_connection(unit, existing):
			continue
		var existing_clearance := existing.transform() * \
			existing_recipe.local_clearance_bounds
		if _aabb_overlaps_volume(clearance_bounds, existing_clearance):
			if DIAGNOSTIC_ALLOW_CORNER_ENVELOPE_OVERLAP \
					and _is_corner_nick(clearance_bounds, existing_clearance):
				continue
			if DIAGNOSTIC_ALLOW_EDGE_ENVELOPE_OVERLAP \
					and _is_edge_nick(clearance_bounds, existing_clearance):
				continue
			last_rejection = \
				"visual envelope of %s %s intersects unrelated unit %s %s" % [
					unit.stable_id, clearance_bounds, existing.stable_id,
					existing_clearance]
			return false
	_solid_owner = trial_solid
	_walk_owner = trial_walk
	_headroom_owner = trial_headroom
	units.append(unit)
	_by_id[unit.stable_id] = unit
	return true


func seal(p_audit: Dictionary = {}) -> bool:
	if _sealed or stable_id.is_empty() or units.is_empty():
		return false
	audit = p_audit.duplicate(true)
	if not validate():
		return false
	_sealed = true
	return true


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
	for left_index in units.size():
		var left := units[left_index]
		var left_recipe := _recipes[left.recipe_id] as FabricRecipe
		if left_recipe.placements.is_empty():
			continue
		var left_clearance := left.transform() * left_recipe.local_clearance_bounds
		for right_index in range(left_index + 1, units.size()):
			var right := units[right_index]
			var right_recipe := _recipes[right.recipe_id] as FabricRecipe
			if right_recipe.placements.is_empty() \
					or _units_declare_connection(left, right):
				continue
			var right_clearance := right.transform() * \
				right_recipe.local_clearance_bounds
			if _aabb_overlaps_volume(left_clearance, right_clearance):
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
		for asset_id: StringName in unit_recipe.asset_ids():
			unique[asset_id] = true
	var out: Array[StringName] = []
	out.assign(unique.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out


func expanded_placements() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for unit_value: FabricUnit in units:
		var unit_recipe := _recipes[unit_value.recipe_id] as FabricRecipe
		for placement: Dictionary in unit_recipe.placements:
			out.append({
				"stable_id": StringName("%s/%s" % [unit_value.stable_id,
					StringName(placement.id)]),
				"asset_id": StringName(placement.asset_id),
				"transform": unit_value.transform() *
					(placement.transform as Transform3D),
			})
	return out


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
			if bearing_seam_ok or lateral_seam_ok:
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
		var origin := unit_value.lattice_origin
		records.append("%s:%s@%d,%d,%d/r%d/p[%s]/b[%s]" % [
			unit_value.stable_id, unit_value.recipe_id, origin.x, origin.y,
			origin.z, unit_value.yaw_quarters, ",".join(parent_ids),
			",".join(bond_records)])
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
	if surface_plan.claim_count() != expected.size():
		last_rejection = "surface union has %d claims for %d expected cells" % [
			surface_plan.claim_count(), expected.size()]
		return false
	return true


func _accept_unit(unit_value: FabricUnit, seen: Dictionary,
		solid: Dictionary, walk: Dictionary, headroom: Dictionary) -> bool:
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
			[solid, headroom, walk], &"solid"):
		return false
	if not _claim_cells(unit_recipe.headroom_cells, unit_value, headroom,
			[solid, headroom], &"headroom"):
		return false
	if not _claim_cells(unit_recipe.walk_cells, unit_value, walk,
			[solid, walk], &"walk"):
		return false
	return true


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
		owner: Dictionary, conflicts: Array[Dictionary], layer: StringName) -> bool:
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
