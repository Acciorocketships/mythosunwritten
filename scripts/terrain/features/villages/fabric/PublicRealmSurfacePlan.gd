class_name PublicRealmSurfacePlan
extends RefCounted

## Resource-free union of every public floor claim. Mesh and collision arrays
## are computed together so visual coverage cannot diverge from traversal.
enum SurfaceKind {
	TERRAIN_STREET,
	STRUCTURAL_COURT,
	INTERIOR_PASSAGE,
	STAIR,
	BRIDGE,
}

const CELL_SIZE := FabricRecipe.CELL_SIZE
const FLOOR_THICKNESS := 0.16
const GUARD_HEIGHT := 1.15
const GUARD_BEAM := 0.14

var stable_id: StringName
var patches: Array[Dictionary] = []
var mesh_payloads: Array[Dictionary] = []
var guard_segments: Array[Dictionary] = []
var guard_mesh_payload: Dictionary = {}
var entrance_records: Array[Dictionary] = []
var unserved_entrances: Array[Dictionary] = []
var unclassified_required_cells: Array[Vector3i] = []
var _claims: Dictionary = {}
var _entrance_openings: Dictionary = {}
var _entrance_forecourt_join_points: Dictionary = {}
var _public_openings: Dictionary = {}
var _structural_solid_cells: Dictionary = {}
var _daylight_void_cells: Array[Vector3i] = []
var _transition_mesh_payloads: Array[Dictionary] = []
var _transition_claim_owners: Dictionary = {}
## Optional construction datum supplied by the topology owner. A structural
## surface can then distinguish a half-level retained terrace from a genuine
## full-headroom undercroft without sampling terrain again in the renderer.
var _support_base_bands: Dictionary = {}
var _sealed := false
var _omitted_guard_post_count := 0
var last_rejection := ""


func _init(p_stable_id: StringName) -> void:
	stable_id = p_stable_id


func add_claim(cell: Vector3i, kind: SurfaceKind, owner_id: StringName) -> bool:
	last_rejection = ""
	if _sealed or owner_id.is_empty() or kind < SurfaceKind.TERRAIN_STREET \
			or kind > SurfaceKind.BRIDGE:
		last_rejection = "invalid surface claim"
		return false
	var key := _cell_key(cell)
	if _claims.has(key):
		var existing := _claims[key] as Dictionary
		if int(existing.kind) != kind:
			last_rejection = "surface kind conflict at %s" % key
			return false
		var owners := existing.owners as Array
		if not owners.has(owner_id):
			owners.append(owner_id)
			owners.sort_custom(func(a: StringName, b: StringName) -> bool:
				return String(a) < String(b))
		return true
	_claims[key] = {
		"cell": cell,
		"kind": kind,
		"owners": [owner_id],
	}
	return true


func add_transition_mesh_payload(payload: Dictionary) -> bool:
	## Transition geometry is admitted only when it is collision-bearing and
	## names every STAIR claim it materializes. This keeps logical circulation,
	## visible treads/ramps, and physics from becoming three independent lists.
	last_rejection = ""
	if _sealed or not _valid_transition_payload(payload):
		last_rejection = "invalid transition mesh payload"
		return false
	for cell: Vector3i in payload.claim_cells as Array[Vector3i]:
		var key := _cell_key(cell)
		if _transition_claim_owners.has(key):
			last_rejection = "duplicate transition geometry at %s" % key
			return false
		var claim := _claims.get(key, {}) as Dictionary
		if claim.is_empty() or int(claim.kind) != SurfaceKind.STAIR:
			last_rejection = "transition geometry has no STAIR claim at %s" % key
			return false
	for cell: Vector3i in payload.claim_cells as Array[Vector3i]:
		_transition_claim_owners[_cell_key(cell)] = StringName(
			payload.get("stable_id", ""))
	_transition_mesh_payloads.append(payload.duplicate(true))
	return true


func set_support_base(cell: Vector3i, base_band: int) -> bool:
	last_rejection = ""
	var key := _cell_key(cell)
	var claim := _claims.get(key, {}) as Dictionary
	if _sealed or claim.is_empty() or base_band > cell.y \
			or int(claim.kind) not in [SurfaceKind.STRUCTURAL_COURT,
				SurfaceKind.BRIDGE]:
		last_rejection = "invalid structural support datum at %s" % cell
		return false
	_support_base_bands[key] = base_band
	return true


func has_support_base(cell: Vector3i) -> bool:
	return _support_base_bands.has(_cell_key(cell))


func support_base_at(cell: Vector3i) -> int:
	return int(_support_base_bands.get(_cell_key(cell), 0))


func seal(required_cells: Array[Vector3i] = [],
		other_classified_cells: Dictionary = {},
		structural_solid_cells: Dictionary = {},
		entrances: Array[Dictionary] = [],
		daylight_void_cells: Array[Vector3i] = [],
		transition_seams: Array[Dictionary] = []) -> bool:
	last_rejection = ""
	if _sealed or stable_id.is_empty() or _claims.is_empty():
		last_rejection = "missing surface id or claims"
		return false
	var required_seen: Dictionary = {}
	for cell: Vector3i in required_cells:
		var key := _cell_key(cell)
		if required_seen.has(key):
			last_rejection = "duplicate required classification cell %s" % key
			return false
		required_seen[key] = true
		if not _claims.has(key) and not other_classified_cells.has(key):
			unclassified_required_cells.append(cell)
	if not unclassified_required_cells.is_empty():
		last_rejection = "%d required intervals are unclassified" % \
			unclassified_required_cells.size()
		return false
	_build_patches()
	_build_mesh_payloads()
	if not _all_stair_claims_have_geometry():
		last_rejection = "STAIR claims lack one collision-bearing transition mesh"
		return false
	mesh_payloads.append_array(_transition_mesh_payloads)
	_classify_entrances(entrances)
	# A visible exterior door is a traversal promise, not facade decoration.
	# Keeping an unserved record for a later audit allowed a plan to seal and a
	# door to render with empty air below its threshold.  Refuse that geometry at
	# the surface transaction, where both the exact aperture and final landing
	# union are known.
	if not unserved_entrances.is_empty():
		last_rejection = "%d exterior entrances have no exact public landing" % \
			unserved_entrances.size()
		return false
	_classify_public_openings(transition_seams)
	_structural_solid_cells = structural_solid_cells.duplicate()
	_daylight_void_cells.assign(daylight_void_cells)
	_build_guards(structural_solid_cells, daylight_void_cells)
	_sealed = not patches.is_empty()
	return _sealed


func validate() -> bool:
	if not _sealed or stable_id.is_empty() or _claims.is_empty() \
			or not unclassified_required_cells.is_empty() \
			or not unserved_entrances.is_empty():
		return false
	var patch_cells: Dictionary = {}
	for patch: Dictionary in patches:
		for cell: Vector3i in patch.cells as Array[Vector3i]:
			var key := _cell_key(cell)
			if patch_cells.has(key) or not _claims.has(key) \
					or int((_claims[key] as Dictionary).kind) != int(patch.kind):
				return false
			patch_cells[key] = true
	return patch_cells.size() == _claims.size() \
		and _all_stair_claims_have_geometry()


func is_sealed() -> bool:
	return _sealed


func has_cell(cell: Vector3i) -> bool:
	return _claims.has(_cell_key(cell))


func kind_at(cell: Vector3i) -> int:
	return int((_claims.get(_cell_key(cell), {"kind": -1}) as Dictionary).kind)


func claim_count() -> int:
	return _claims.size()


func cells_for_kind(kind: SurfaceKind) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for claim: Dictionary in _claims.values():
		if int(claim.kind) == kind:
			out.append(claim.cell as Vector3i)
	out.sort_custom(_cell_less)
	return out


func cells_owned_by_prefix(owner_prefix: String) -> Array[Vector3i]:
	## Owner identity is sealed topology provenance. This query allows a visual
	## adapter to style one explicitly named episode without guessing from a
	## platform's shape, height, or neighborhood.
	var out: Array[Vector3i] = []
	if owner_prefix.is_empty():
		return out
	for claim: Dictionary in _claims.values():
		for owner_value: Variant in claim.owners as Array:
			if String(StringName(owner_value)).begins_with(owner_prefix):
				out.append(claim.cell as Vector3i)
				break
	out.sort_custom(_cell_less)
	return out


func audit() -> Dictionary:
	var counts: Dictionary = {}
	for claim: Dictionary in _claims.values():
		counts[int(claim.kind)] = int(counts.get(int(claim.kind), 0)) + 1
	var result := {
		"surface_cell_count": _claims.size(),
		"surface_patch_count": patches.size(),
		"unclassified_interval_count": unclassified_required_cells.size(),
		"terrain_street_cell_count": int(counts.get(SurfaceKind.TERRAIN_STREET, 0)),
		"structural_court_cell_count": int(counts.get(SurfaceKind.STRUCTURAL_COURT, 0)),
		"structural_court_interior_cell_count":
			_structural_court_interior_cell_count(),
		"exterior_public_interior_cell_count":
			_exterior_public_interior_cell_count(),
		"max_exterior_public_interior_component_size":
			_max_exterior_public_interior_component_size(),
		"public_walk_interior_cell_count":
			_public_walk_interior_cells().size(),
		"max_public_walk_interior_component_size":
			_max_public_walk_interior_component_size(),
		"interior_passage_cell_count": int(counts.get(SurfaceKind.INTERIOR_PASSAGE, 0)),
		"stair_surface_cell_count": int(counts.get(SurfaceKind.STAIR, 0)),
		"bridge_surface_cell_count": int(counts.get(SurfaceKind.BRIDGE, 0)),
		"retained_half_level_surface_cell_count":
			_retained_half_level_surface_cell_count(),
		"structural_support_datum_count": _support_base_bands.size(),
		"transition_mesh_count": _transition_mesh_payloads.size(),
		"transition_triangle_count": _transition_triangle_count(),
		"derived_guard_segment_count": guard_segments.size(),
		"entrance_count": entrance_records.size(),
		"served_entrance_count": entrance_records.size() \
			- unserved_entrances.size(),
		"unserved_entrance_count": unserved_entrances.size(),
		"served_structural_entrance_count": _served_structural_entrance_count(),
		"entrance_guard_conflict_count": _entrance_guard_conflict_count(),
		"entrance_forecourt_join_count": _omitted_guard_post_count,
		"wide_entrance_guard_opening_count": _wide_entrance_guard_opening_count(),
		"daylight_void_guard_segment_count": guard_segments.filter(
			func(value: Dictionary) -> bool:
				return StringName(value.get("boundary_kind", "")) \
					== &"daylight_void").size(),
	}
	result.merge(_daylight_void_boundary_audit(), true)
	result.merge(_walk_network_audit(), true)
	return result


func _walk_network_audit() -> Dictionary:
	## Sealed facts for the reviewed street character: the walk network must be
	## ONE connected system spanning the settlement's bands. Same-band
	## neighbors connect directly; a band change is walkable only through a
	## STAIR claim, exactly like the player. Both-flank boundedness lives on
	## the solid/void plan, which owns the real construction cells.
	var cells: Array[Vector3i] = []
	var cell_set: Dictionary = {}
	var stair_set: Dictionary = {}
	for claim: Dictionary in _claims.values():
		var cell := claim.cell as Vector3i
		cells.append(cell)
		cell_set[_cell_key(cell)] = cell
		if int(claim.kind) == SurfaceKind.STAIR:
			stair_set[_cell_key(cell)] = true
	if cells.is_empty():
		return {"walk_surface_component_count": 0, "walk_band_span": 0}
	var bands: Dictionary = {}
	var component_of: Dictionary = {}
	var component_count := 0
	for cell: Vector3i in cells:
		bands[cell.y] = true
		if component_of.has(_cell_key(cell)):
			continue
		component_count += 1
		var frontier: Array[Vector3i] = [cell]
		component_of[_cell_key(cell)] = component_count
		while not frontier.is_empty():
			var current: Vector3i = frontier.pop_back()
			var current_is_stair: bool = stair_set.has(_cell_key(current))
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				for band_step in range(-1, 2):
					var neighbor: Vector3i = current + direction \
						+ Vector3i.UP * band_step
					var neighbor_key := _cell_key(neighbor)
					if not cell_set.has(neighbor_key) \
							or component_of.has(neighbor_key):
						continue
					if band_step != 0 and not current_is_stair \
							and not stair_set.has(neighbor_key):
						continue
					component_of[neighbor_key] = component_count
					frontier.append(neighbor)
	return {
		"walk_surface_component_count": component_count,
		"walk_band_span": bands.size(),
	}


func _structural_court_interior_cell_count() -> int:
	## Total area cannot distinguish a long one-cell-wide gallery from an empty
	## plaza. Count only cells surrounded by structural floor on all four sides
	## at the same height. A two-lane path, turn, stair landing, and lightwell rim
	## have no such interior; a broad suspended ground plane necessarily does.
	var result := 0
	var directions: Array[Vector3i] = [
		Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK,
	]
	for claim: Dictionary in _claims.values():
		if int(claim.kind) != SurfaceKind.STRUCTURAL_COURT:
			continue
		var cell := claim.cell as Vector3i
		var is_interior := true
		for direction: Vector3i in directions:
			var neighbor := _claims.get(_cell_key(cell + direction), {}) \
				as Dictionary
			if neighbor.is_empty() or int(neighbor.kind) \
					!= SurfaceKind.STRUCTURAL_COURT:
				is_interior = false
				break
		result += int(is_interior)
	return result


func _exterior_public_interior_cell_count() -> int:
	## A plaza can be assembled from several claim kinds and therefore evade the
	## structural-court-only diagnostic above. Count the interior of their exact
	## exterior union instead. Stairs are deliberately excluded: a landing may
	## touch streets and courts on all sides without becoming an empty suspended
	## floor. Interior passages are private building mass, never public streets.
	return _exterior_public_interior_cells().size()


func _exterior_public_interior_cells() -> Dictionary:
	var result: Dictionary = {}
	var exterior_kinds: Dictionary = {
		SurfaceKind.TERRAIN_STREET: true,
		SurfaceKind.STRUCTURAL_COURT: true,
		SurfaceKind.BRIDGE: true,
	}
	var directions: Array[Vector3i] = [
		Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK,
	]
	for claim: Dictionary in _claims.values():
		if not exterior_kinds.has(int(claim.kind)):
			continue
		var cell := claim.cell as Vector3i
		var is_interior := true
		for direction: Vector3i in directions:
			var neighbor := _claims.get(_cell_key(cell + direction), {}) \
				as Dictionary
			if neighbor.is_empty() or not exterior_kinds.has(int(neighbor.kind)):
				is_interior = false
				break
		if is_interior:
			result[_cell_key(cell)] = cell
	return result


func _max_exterior_public_interior_component_size() -> int:
	return _max_cell_component_size(_exterior_public_interior_cells())


func _public_walk_interior_cells() -> Dictionary:
	## Review the floor the player actually sees, not its producer labels. Stair
	## landings and shallow ramp treads can interleave with courts so every kind
	## individually looks narrow while their rendered union is a broad pale slab.
	## Interior passages remain excluded because they are deferred private mass.
	var result: Dictionary = {}
	var public_kinds: Dictionary = {
		SurfaceKind.TERRAIN_STREET: true,
		SurfaceKind.STRUCTURAL_COURT: true,
		SurfaceKind.STAIR: true,
		SurfaceKind.BRIDGE: true,
	}
	var directions: Array[Vector3i] = [
		Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK,
	]
	for claim: Dictionary in _claims.values():
		if not public_kinds.has(int(claim.kind)):
			continue
		var cell := claim.cell as Vector3i
		var is_interior := true
		for direction: Vector3i in directions:
			var neighbor := _claims.get(_cell_key(cell + direction), {}) \
				as Dictionary
			if neighbor.is_empty() or not public_kinds.has(int(neighbor.kind)):
				is_interior = false
				break
		if is_interior:
			result[_cell_key(cell)] = cell
	return result


func _max_public_walk_interior_component_size() -> int:
	return _max_cell_component_size(_public_walk_interior_cells())


static func _max_cell_component_size(cells: Dictionary) -> int:
	var remaining := cells.duplicate()
	var maximum := 0
	var directions: Array[Vector3i] = [
		Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK,
	]
	while not remaining.is_empty():
		var first_key := String(remaining.keys()[0])
		var frontier: Array[Vector3i] = [remaining[first_key] as Vector3i]
		remaining.erase(first_key)
		var size := 0
		while not frontier.is_empty():
			var cell: Vector3i = frontier.pop_back()
			size += 1
			for direction: Vector3i in directions:
				var neighbor_key := _cell_key(cell + direction)
				if not remaining.has(neighbor_key):
					continue
				frontier.append(remaining[neighbor_key] as Vector3i)
				remaining.erase(neighbor_key)
		maximum = maxi(maximum, size)
	return maximum


func _retained_half_level_surface_cell_count() -> int:
	var count := 0
	for key_value: Variant in _support_base_bands.keys():
		var key := String(key_value)
		var claim := _claims.get(key, {}) as Dictionary
		if not claim.is_empty():
			var cell := claim.cell as Vector3i
			count += int(cell.y - int(_support_base_bands[key]) == 1)
	return count


func _all_stair_claims_have_geometry() -> bool:
	# Existing sectional recipes intentionally keep reviewed authored stair
	# assets as their authority. Volumetric plans opt into generated transition
	# authority by registering at least one payload; partial registration is then
	# forbidden.
	if _transition_mesh_payloads.is_empty():
		return true
	var stair_count := 0
	for claim: Dictionary in _claims.values():
		if int(claim.kind) != SurfaceKind.STAIR:
			continue
		stair_count += 1
		if not _transition_claim_owners.has(_cell_key(claim.cell as Vector3i)):
			return false
	return stair_count == _transition_claim_owners.size()


func _transition_triangle_count() -> int:
	var count := 0
	for payload: Dictionary in _transition_mesh_payloads:
		count += (payload.indices as PackedInt32Array).size() / 3
	return count


static func _valid_transition_payload(payload: Dictionary) -> bool:
	if StringName(payload.get("stable_id", "")).is_empty() \
			or not payload.has("claim_cells") \
			or not payload.has("vertices") or not payload.has("normals") \
			or not payload.has("uvs") or not payload.has("indices") \
			or not payload.has("collision_faces"):
		return false
	var claim_cells := payload.claim_cells as Array[Vector3i]
	var vertices := payload.vertices as PackedVector3Array
	var normals := payload.normals as PackedVector3Array
	var uvs := payload.uvs as PackedVector2Array
	var indices := payload.indices as PackedInt32Array
	var collision := payload.collision_faces as PackedVector3Array
	if claim_cells.is_empty() or vertices.is_empty() \
			or normals.size() != vertices.size() or uvs.size() != vertices.size() \
			or indices.is_empty() or indices.size() % 3 != 0 \
			or collision.is_empty() or collision.size() % 3 != 0:
		return false
	for index: int in indices:
		if index < 0 or index >= vertices.size():
			return false
	return true


func _daylight_void_boundary_audit() -> Dictionary:
	## A wall is as valid a fall barrier as a rail. Counting only rail meshes made
	## a lightwell closed by three rails and an inhabited facade look incomplete,
	## and encouraged the compiler to put a redundant guard through that wall.
	var void_set: Dictionary = {}
	for cell: Vector3i in _daylight_void_cells:
		void_set[_cell_key(cell)] = true
	var guard_edges: Dictionary = {}
	for segment: Dictionary in guard_segments:
		if StringName(segment.get("boundary_kind", "")) == &"daylight_void":
			guard_edges[String(segment.stable_key)] = true
	var edge_count := 0
	var guard_count := 0
	var solid_count := 0
	var unbounded_count := 0
	for cell: Vector3i in _daylight_void_cells:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if void_set.has(_cell_key(neighbor)):
				continue
			edge_count += 1
			if _structural_solid_cells.has(_cell_key(neighbor)) \
					or _structural_solid_cells.has(_cell_key(neighbor + Vector3i.UP)):
				solid_count += 1
				continue
			var guard_key := "%d:%d:%d:%d:%d" % [neighbor.x, neighbor.y,
				neighbor.z, -direction.x, -direction.z]
			if guard_edges.has(guard_key):
				guard_count += 1
			else:
				unbounded_count += 1
	return {
		"daylight_void_boundary_edge_count": edge_count,
		"daylight_void_guarded_edge_count": guard_count,
		"daylight_void_solid_edge_count": solid_count,
		"daylight_void_bounded_edge_count": guard_count + solid_count,
		"daylight_void_unbounded_edge_count": unbounded_count,
	}


func _served_structural_entrance_count() -> int:
	var count := 0
	for entrance: Dictionary in entrance_records:
		if not bool(entrance.served):
			continue
		var kind := kind_at(entrance.landing_cell as Vector3i)
		if kind == SurfaceKind.STRUCTURAL_COURT or kind == SurfaceKind.BRIDGE:
			count += 1
	return count


func _entrance_guard_conflict_count() -> int:
	var guarded_edges: Dictionary = {}
	for segment: Dictionary in guard_segments:
		guarded_edges[String(segment.stable_key)] = true
	var count := 0
	for entrance: Dictionary in entrance_records:
		if not bool(entrance.served):
			continue
		var facing := entrance.facing as Vector3i
		var opening_cells: Array = entrance.get("guard_opening_cells", []) as Array
		if opening_cells.is_empty():
			opening_cells = [entrance.landing_cell as Vector3i]
		for cell_value: Variant in opening_cells:
			var landing := cell_value as Vector3i
			var stable_key := "%d:%d:%d:%d:%d" % [landing.x, landing.y,
				landing.z, -facing.x, -facing.z]
			if guarded_edges.has(stable_key):
				count += 1
	return count


func _wide_entrance_guard_opening_count() -> int:
	var count := 0
	for entrance: Dictionary in entrance_records:
		var opening_cells: Array = entrance.get("guard_opening_cells", []) as Array
		if opening_cells.size() > 1:
			count += 1
	return count


func _build_patches() -> void:
	patches.clear()
	var pending: Dictionary = _claims.duplicate(true)
	var keys: Array[String] = []
	keys.assign(pending.keys())
	keys.sort()
	for start_key: String in keys:
		if not pending.has(start_key):
			continue
		var start := pending[start_key] as Dictionary
		var kind := int(start.kind)
		var cells: Array[Vector3i] = []
		var frontier: Array[Vector3i] = [start.cell as Vector3i]
		pending.erase(start_key)
		while not frontier.is_empty():
			var cell: Vector3i = frontier.pop_back()
			cells.append(cell)
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				var neighbor := cell + direction
				var neighbor_key := _cell_key(neighbor)
				if not pending.has(neighbor_key):
					continue
				var neighbor_claim := pending[neighbor_key] as Dictionary
				if int(neighbor_claim.kind) != kind:
					continue
				pending.erase(neighbor_key)
				frontier.append(neighbor)
		cells.sort_custom(_cell_less)
		patches.append({"kind": kind, "cells": cells})


func _build_mesh_payloads() -> void:
	mesh_payloads.clear()
	for kind in SurfaceKind.values():
		if kind == SurfaceKind.STAIR:
			# Reviewed stair assets remain the visual/collision authority; their
			# cells still participate in topology and closure audits.
			continue
		var cells: Array[Vector3i] = []
		for claim: Dictionary in _claims.values():
			if int(claim.kind) == kind:
				cells.append(claim.cell as Vector3i)
		if cells.is_empty():
			continue
		cells.sort_custom(_cell_less)
		mesh_payloads.append(_mesh_for_cells(kind, cells))


func _classify_entrances(entrances: Array[Dictionary]) -> void:
	entrance_records.clear()
	unserved_entrances.clear()
	_entrance_openings.clear()
	_entrance_forecourt_join_points.clear()
	for source: Dictionary in entrances:
		var entrance := source.duplicate()
		var landing := entrance.get("landing_cell", Vector3i()) as Vector3i
		var facing := entrance.get("facing", Vector3i()) as Vector3i
		var served := _claims.has(_cell_key(landing))
		var guard_opening_cells: Array[Vector3i] = [landing]
		var door_phase := int(entrance.get("door_phase", -1))
		if door_phase in [0, 1]:
			# Generated facade doors are complete 3 m modules on a 1.5 m public
			# lattice.  The declared threshold is the actually walkable half; the
			# companion half changes with the mirrored door phase.  Open its guard
			# only when a real public surface owns it, so the full authored arch is
			# unobstructed without turning neighboring empty air into a promise.
			var local_left: Vector3i = Vector3i(-facing.z, 0, facing.x)
			var companion: Vector3i = landing + (local_left if door_phase == 0 \
				else -local_left)
			if _claims.has(_cell_key(companion)):
				guard_opening_cells.append(companion)
		entrance["served"] = served
		entrance["guard_opening_cells"] = guard_opening_cells
		entrance_records.append(entrance)
		if not served:
			unserved_entrances.append(entrance)
			continue
		for opening_cell: Vector3i in guard_opening_cells:
			var opening_direction := -facing
			_entrance_openings[_transition_key(opening_cell,
				opening_direction)] = true
		# A shallow forecourt can continue to either side of the handed threshold.
		# Its two 1.5 m railing repeats otherwise put a terminal post directly on
		# the doorway sightline. Mark both possible joints; guard construction joins
		# one only when the finished surface actually owns exactly two collinear
		# sections there, so this never invents a landing or removes a corner post.
		var forecourt_guard := _guard_segment(landing, facing,
			&"entrance_forecourt")
		for forecourt_point: Vector3 in [forecourt_guard.a as Vector3,
				forecourt_guard.b as Vector3]:
			_entrance_forecourt_join_points[_point_key(forecourt_point)] = \
				forecourt_point
	entrance_records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.stable_id) < String(b.stable_id))
	unserved_entrances.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.stable_id) < String(b.stable_id))


func _classify_public_openings(transition_seams: Array[Dictionary]) -> void:
	_public_openings.clear()
	for seam: Dictionary in transition_seams:
		var from_cell := seam.get("from_cell", Vector3i()) as Vector3i
		var to_cell := seam.get("to_cell", Vector3i()) as Vector3i
		var from_direction := Vector3i(to_cell.x - from_cell.x, 0,
			to_cell.z - from_cell.z)
		_public_openings[_transition_key(from_cell, from_direction)] = true
		_public_openings[_transition_key(to_cell, -from_direction)] = true


func _build_guards(structural_solid_cells: Dictionary,
		daylight_void_cells: Array[Vector3i]) -> void:
	guard_segments.clear()
	guard_mesh_payload = {}
	_omitted_guard_post_count = 0
	var daylight_void_set: Dictionary = {}
	for cell: Vector3i in daylight_void_cells:
		daylight_void_set[_cell_key(cell)] = true
	for claim: Dictionary in _claims.values():
		if int(claim.kind) != SurfaceKind.STRUCTURAL_COURT:
			continue
		var cell := claim.cell as Vector3i
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			if _has_public_transition(cell, direction) \
					or _entrance_openings.has(_transition_key(cell, direction)):
				continue
			var neighbor := cell + direction
			if structural_solid_cells.has(_cell_key(neighbor)) \
					or structural_solid_cells.has(_cell_key(neighbor + Vector3i.UP)):
				# A wall or occupied facade is already the fall barrier. Guarding it
				# would create a rail through a doorway/building edge.
				continue
			var segment := _guard_segment(cell, direction,
				&"daylight_void" if daylight_void_set.has(_cell_key(neighbor)) \
				else &"exposed_edge")
			guard_segments.append(segment)
	guard_segments.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.stable_key) < String(b.stable_key))
	if guard_segments.is_empty():
		return
	var segments_by_point: Dictionary = {}
	for segment_index in guard_segments.size():
		var segment := guard_segments[segment_index]
		for point: Vector3 in [segment.a as Vector3, segment.b as Vector3]:
			var key := _point_key(point)
			if not segments_by_point.has(key):
				segments_by_point[key] = [] as Array[int]
			(segments_by_point[key] as Array[int]).append(segment_index)
	var joined_points: Dictionary = {}
	for key_value: Variant in _entrance_forecourt_join_points.keys():
		var key := String(key_value)
		var indices: Array = segments_by_point.get(key, []) as Array
		if indices.size() != 2:
			continue
		var first := guard_segments[int(indices[0])]
		var second := guard_segments[int(indices[1])]
		var first_span := (first.b as Vector3) - (first.a as Vector3)
		var second_span := (second.b as Vector3) - (second.a as Vector3)
		if first_span.normalized().cross(second_span.normalized()).length() > 0.001:
			continue
		joined_points[key] = _entrance_forecourt_join_points[key]
		first["visual_join_point"] = _entrance_forecourt_join_points[key]
		second["visual_join_point"] = _entrance_forecourt_join_points[key]
		guard_segments[int(indices[0])] = first
		guard_segments[int(indices[1])] = second
	_omitted_guard_post_count = joined_points.size()
	var post_centers: Dictionary = {}
	for segment: Dictionary in guard_segments:
		for point: Vector3 in [segment.a as Vector3, segment.b as Vector3]:
			var key := _point_key(point)
			if not joined_points.has(key):
				post_centers[key] = point
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var collision_faces := PackedVector3Array()
	for segment: Dictionary in guard_segments:
		var a := segment.a as Vector3
		var b := segment.b as Vector3
		var span := b - a
		var horizontal_size := Vector3(
			maxf(absf(span.x), GUARD_BEAM), GUARD_BEAM,
			maxf(absf(span.z), GUARD_BEAM))
		for height in [GUARD_HEIGHT * 0.52, GUARD_HEIGHT]:
			_append_box(vertices, normals, uvs, indices, collision_faces,
				(a + b) * 0.5 + Vector3.UP * height, horizontal_size)
	var post_keys: Array[String] = []
	post_keys.assign(post_centers.keys())
	post_keys.sort()
	for post_key: String in post_keys:
		var foot := post_centers[post_key] as Vector3
		_append_box(vertices, normals, uvs, indices, collision_faces,
			foot + Vector3.UP * GUARD_HEIGHT * 0.5,
			Vector3(GUARD_BEAM, GUARD_HEIGHT, GUARD_BEAM))
	guard_mesh_payload = {
		"kind": -1,
		"is_guard": true,
		"vertices": vertices,
		"normals": normals,
		"uvs": uvs,
		"indices": indices,
		"collision_faces": collision_faces,
	}


func _has_public_transition(cell: Vector3i, direction: Vector3i) -> bool:
	# Same-height union edges are continuous by construction. A vertical offset
	# opens a guard only when the public graph names that exact seam; nearby
	# floors at another level do not silently become a stair connection.
	return _claims.has(_cell_key(cell + direction)) \
		or _public_openings.has(_transition_key(cell, direction))


static func _guard_segment(cell: Vector3i, direction: Vector3i,
		boundary_kind: StringName) -> Dictionary:
	var center := Vector3(float(cell.x) * CELL_SIZE,
		float(cell.y) * CELL_SIZE + 0.025, float(cell.z) * CELL_SIZE)
	var tangent := Vector3.FORWARD if direction.x != 0 else Vector3.RIGHT
	var edge_center := center + Vector3(direction.x, 0.0, direction.z) \
		* CELL_SIZE * 0.5
	var a := edge_center - tangent * CELL_SIZE * 0.5
	var b := edge_center + tangent * CELL_SIZE * 0.5
	return {
		"a": a,
		"b": b,
		"stable_key": "%d:%d:%d:%d:%d" % [cell.x, cell.y, cell.z,
			direction.x, direction.z],
		"boundary_kind": boundary_kind,
	}


static func _transition_key(cell: Vector3i, direction: Vector3i) -> String:
	return "%d:%d:%d/%d:%d" % [cell.x, cell.y, cell.z,
		direction.x, direction.z]


func _mesh_for_cells(kind: int, cells: Array[Vector3i]) -> Dictionary:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var collision_faces := PackedVector3Array()
	var all_cells: Dictionary = {}
	for cell: Vector3i in cells:
		all_cells[_cell_key(cell)] = true
	for cell: Vector3i in cells:
		var x0 := float(cell.x) * CELL_SIZE - CELL_SIZE * 0.5
		var x1 := x0 + CELL_SIZE
		var z0 := float(cell.z) * CELL_SIZE - CELL_SIZE * 0.5
		var z1 := z0 + CELL_SIZE
		var y := float(cell.y) * CELL_SIZE + 0.025
		var a := Vector3(x0, y, z0)
		var b := Vector3(x1, y, z0)
		var c := Vector3(x1, y, z1)
		var d := Vector3(x0, y, z1)
		_append_quad(vertices, normals, uvs, indices, a, d, c, b, Vector3.UP)
		_append_collision_quad(collision_faces, a, d, c, b)
		if kind != SurfaceKind.TERRAIN_STREET:
			var bottom_a := a - Vector3(0, FLOOR_THICKNESS, 0)
			var bottom_b := b - Vector3(0, FLOOR_THICKNESS, 0)
			var bottom_c := c - Vector3(0, FLOOR_THICKNESS, 0)
			var bottom_d := d - Vector3(0, FLOOR_THICKNESS, 0)
			_append_quad(vertices, normals, uvs, indices, bottom_a, bottom_b,
				bottom_c, bottom_d, Vector3.DOWN)
			_append_collision_quad(collision_faces, bottom_a, bottom_b,
				bottom_c, bottom_d)
		var sides: Array[Dictionary] = [
			{"direction": Vector3i.LEFT, "a": a, "b": d, "normal": Vector3.LEFT},
			{"direction": Vector3i.RIGHT, "a": c, "b": b, "normal": Vector3.RIGHT},
			{"direction": Vector3i.FORWARD, "a": b, "b": a, "normal": Vector3.FORWARD},
			{"direction": Vector3i.BACK, "a": d, "b": c, "normal": Vector3.BACK},
		]
		for side: Dictionary in sides:
			var neighbor := cell + (side.direction as Vector3i)
			if all_cells.has(_cell_key(neighbor)):
				continue
			var top_a := side.a as Vector3
			var top_b := side.b as Vector3
			var side_bottom_a := top_a - Vector3(0, FLOOR_THICKNESS, 0)
			var side_bottom_b := top_b - Vector3(0, FLOOR_THICKNESS, 0)
			_append_quad(vertices, normals, uvs, indices, top_a, top_b,
				side_bottom_b, side_bottom_a, side.normal as Vector3)
			_append_collision_quad(collision_faces, top_a, top_b,
				side_bottom_b, side_bottom_a)
	return {
		"kind": kind,
		"vertices": vertices,
		"normals": normals,
		"uvs": uvs,
		"indices": indices,
		"collision_faces": collision_faces,
	}


static func _append_quad(vertices: PackedVector3Array,
		normals: PackedVector3Array, uvs: PackedVector2Array,
		indices: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, normal: Vector3) -> void:
	var base := vertices.size()
	vertices.append_array(PackedVector3Array([a, b, c, d]))
	for _index in 4:
		normals.append(normal)
	uvs.append_array(PackedVector2Array([
		Vector2(a.x, a.z) / 3.0,
		Vector2(b.x, b.z) / 3.0,
		Vector2(c.x, c.z) / 3.0,
		Vector2(d.x, d.z) / 3.0,
	]))
	# Reversed fan: the callers' historical corner order put every top face's
	# FRONT downward, which unshaded materials hid and lit shading exposed as
	# near-black backface surfaces. Collision is orientation-tolerant
	# (backface collision), so only the render winding flips.
	indices.append_array(PackedInt32Array([
		base, base + 2, base + 1,
		base, base + 3, base + 2,
	]))


static func _append_collision_quad(faces: PackedVector3Array, a: Vector3,
		b: Vector3, c: Vector3, d: Vector3) -> void:
	faces.append_array(PackedVector3Array([a, b, c, a, c, d]))


static func _append_box(vertices: PackedVector3Array,
		normals: PackedVector3Array, uvs: PackedVector2Array,
		indices: PackedInt32Array, collision_faces: PackedVector3Array,
		center: Vector3, size: Vector3) -> void:
	var half := size * 0.5
	var nnn := center + Vector3(-half.x, -half.y, -half.z)
	var pnn := center + Vector3(half.x, -half.y, -half.z)
	var ppn := center + Vector3(half.x, half.y, -half.z)
	var npn := center + Vector3(-half.x, half.y, -half.z)
	var nnp := center + Vector3(-half.x, -half.y, half.z)
	var pnp := center + Vector3(half.x, -half.y, half.z)
	var ppp := center + Vector3(half.x, half.y, half.z)
	var npp := center + Vector3(-half.x, half.y, half.z)
	var faces: Array[Dictionary] = [
		{"a": nnp, "b": npp, "c": ppp, "d": pnp, "normal": Vector3.BACK},
		{"a": pnn, "b": ppn, "c": npn, "d": nnn, "normal": Vector3.FORWARD},
		{"a": nnn, "b": npn, "c": npp, "d": nnp, "normal": Vector3.LEFT},
		{"a": pnp, "b": ppp, "c": ppn, "d": pnn, "normal": Vector3.RIGHT},
		{"a": npn, "b": ppn, "c": ppp, "d": npp, "normal": Vector3.UP},
		{"a": nnn, "b": nnp, "c": pnp, "d": pnn, "normal": Vector3.DOWN},
	]
	for face: Dictionary in faces:
		_append_quad(vertices, normals, uvs, indices, face.a as Vector3,
			face.b as Vector3, face.c as Vector3, face.d as Vector3,
			face.normal as Vector3)
		_append_collision_quad(collision_faces, face.a as Vector3,
			face.b as Vector3, face.c as Vector3, face.d as Vector3)


static func _cell_less(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	if a.z != b.z:
		return a.z < b.z
	return a.x < b.x


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]


static func _point_key(point: Vector3) -> String:
	return "%.3f:%.3f:%.3f" % [point.x, point.y, point.z]
