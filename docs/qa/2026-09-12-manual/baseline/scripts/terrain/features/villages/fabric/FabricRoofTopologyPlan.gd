class_name FabricRoofTopologyPlan
extends RefCounted

## Sealed roof-neighbourhood facts for a complete parcel arrangement.  This is
## the roof equivalent of the terrain cliff classifier: construction recipes
## consume a finite seam signature and never guess how nearby roofs meet from
## render placements.  The first vocabulary covers the relationships the
## current orthogonal grammar can actually create; adding hips, valleys, or
## cross-gables extends this classifier and its module table, not parcel code.
enum JunctionKind {
	RIDGE_CONTINUATION,
	PARALLEL_VALLEY,
	PERPENDICULAR_VALLEY,
	STEPPED_EAVE_WALL,
	STEPPED_GABLE_WALL,
}

enum Side {
	RIDGE_NEGATIVE,
	RIDGE_POSITIVE,
	EAVE_NEGATIVE,
	EAVE_POSITIVE,
}

var facts: Dictionary = {}
var audit: Dictionary = {}
var last_rejection := ""
var _sealed := false


static func build(proposals: Array[Dictionary]) -> FabricRoofTopologyPlan:
	var result := FabricRoofTopologyPlan.new()
	if not result._seal(proposals):
		return null
	return result


func fact(proposal_id: StringName) -> Dictionary:
	return (facts.get(proposal_id, {}) as Dictionary).duplicate(true)


func is_sealed() -> bool:
	return _sealed


func deterministic_signature() -> String:
	var parts := PackedStringArray()
	for proposal_id_value: Variant in facts.keys():
		var proposal_id := StringName(proposal_id_value)
		var roof_fact := facts[proposal_id] as Dictionary
		var seams := PackedStringArray()
		for seam: Dictionary in roof_fact.junctions as Array:
			seams.append("%d:%d:%s:%d:%d:%d" % [int(seam.kind), int(seam.side),
				StringName(seam.neighbor_id), int(seam.height_delta),
				int(seam.face_cells), int(seam.run_offset_half_steps)])
		seams.sort()
		parts.append("%s=%s" % [proposal_id, ",".join(seams)])
	parts.sort()
	return "|".join(parts)


func _seal(proposals: Array[Dictionary]) -> bool:
	if _sealed or proposals.is_empty():
		return _reject("missing roof proposals")
	var by_id: Dictionary = {}
	for proposal: Dictionary in proposals:
		var proposal_id := StringName(proposal.get("stable_id", ""))
		var kind := StringName(proposal.get("kind", ""))
		if proposal_id.is_empty() or by_id.has(proposal_id) \
				or not [&"building", &"tower", &"slim", &"row", &"long"].has(kind):
			return _reject("invalid or duplicate roof proposal")
		var axes := _axes(proposal)
		var columns := _columns(proposal)
		if axes.is_empty() or columns.is_empty():
			return _reject("proposal lacks orthogonal roof axes or footprint")
		by_id[proposal_id] = proposal
		facts[proposal_id] = {
			"proposal_id": proposal_id,
			"roof_base_band": _roof_base(proposal),
			"ridge_axis": axes.ridge,
			"eave_axis": axes.eave,
			"junctions": [] as Array[Dictionary],
			"signature": &"isolated",
		}
	var ids: Array[StringName] = []
	ids.assign(by_id.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	var kind_counts: Dictionary = {}
	var joined_ids: Dictionary = {}
	for left_index in ids.size():
		var left_id := ids[left_index]
		var left := by_id[left_id] as Dictionary
		for right_index in range(left_index + 1, ids.size()):
			var right_id := ids[right_index]
			var right := by_id[right_id] as Dictionary
			var contact := _contact(left, right)
			if contact.is_empty():
				continue
			var left_side := _side(left, contact.direction as Vector2i)
			var right_side := _side(right, -(contact.direction as Vector2i))
			if left_side < 0 or right_side < 0:
				return _reject("roof contact is not on an orthogonal seam")
			var height_delta := _roof_base(right) - _roof_base(left)
			var junction_kind := _junction_kind(left, right, left_side,
				right_side, height_delta)
			var left_contact_columns: Array[Vector2i] = []
			left_contact_columns.assign(contact.left_columns as Array)
			var right_contact_columns: Array[Vector2i] = []
			for column: Vector2i in left_contact_columns:
				right_contact_columns.append(column + (contact.direction as Vector2i))
			_add_junction(left_id, right_id, junction_kind, left_side,
				height_delta, int(contact.face_cells),
				_contact_offset_half_steps(left, left_side, left_contact_columns))
			_add_junction(right_id, left_id, junction_kind, right_side,
				-height_delta, int(contact.face_cells),
				_contact_offset_half_steps(right, right_side, right_contact_columns))
			kind_counts[junction_kind] = int(kind_counts.get(junction_kind, 0)) + 1
			joined_ids[left_id] = true
			joined_ids[right_id] = true
	for proposal_id: StringName in ids:
		var roof_fact := facts[proposal_id] as Dictionary
		var junctions := roof_fact.junctions as Array
		junctions.sort_custom(_junction_less)
		roof_fact.signature = _signature(junctions)
		facts[proposal_id] = roof_fact
	if not _reciprocal():
		return _reject("roof junctions are not reciprocal")
	audit = {
		"roof_count": proposals.size(),
		"joined_roof_count": joined_ids.size(),
		"isolated_roof_count": proposals.size() - joined_ids.size(),
		"junction_count": _junction_count(),
		"ridge_continuation_count": int(kind_counts.get(
			JunctionKind.RIDGE_CONTINUATION, 0)),
		"parallel_valley_count": int(kind_counts.get(
			JunctionKind.PARALLEL_VALLEY, 0)),
		"perpendicular_valley_count": int(kind_counts.get(
			JunctionKind.PERPENDICULAR_VALLEY, 0)),
		"stepped_eave_wall_count": int(kind_counts.get(
			JunctionKind.STEPPED_EAVE_WALL, 0)),
		"stepped_gable_wall_count": int(kind_counts.get(
			JunctionKind.STEPPED_GABLE_WALL, 0)),
	}
	_sealed = true
	return true


func _add_junction(owner_id: StringName, neighbor_id: StringName,
		kind: JunctionKind, side: int, height_delta: int,
		face_cells: int, run_offset_half_steps: int) -> void:
	var roof_fact := facts[owner_id] as Dictionary
	(roof_fact.junctions as Array[Dictionary]).append({
		"neighbor_id": neighbor_id,
		"kind": kind,
		"side": side,
		"height_delta": height_delta,
		"face_cells": face_cells,
		"run_offset_half_steps": run_offset_half_steps,
	})
	facts[owner_id] = roof_fact


func _reciprocal() -> bool:
	for owner_id_value: Variant in facts.keys():
		var owner_id := StringName(owner_id_value)
		for seam: Dictionary in (facts[owner_id] as Dictionary).junctions as Array:
			var matched := false
			for reverse: Dictionary in (facts[StringName(seam.neighbor_id)] \
					as Dictionary).junctions as Array:
				if StringName(reverse.neighbor_id) == owner_id \
						and int(reverse.kind) == int(seam.kind) \
						and int(reverse.height_delta) == -int(seam.height_delta):
					matched = true
					break
			if not matched:
				return false
	return true


func _junction_count() -> int:
	var directed := 0
	for roof_fact: Dictionary in facts.values():
		directed += (roof_fact.junctions as Array).size()
	return directed / 2


static func _junction_kind(left: Dictionary, right: Dictionary,
		left_side: int, right_side: int, height_delta: int) -> JunctionKind:
	var left_axes := _axes(left)
	var right_axes := _axes(right)
	var left_ridge := left_axes.ridge as Vector2i
	var right_ridge := right_axes.ridge as Vector2i
	var same_ridge_orientation := left_ridge == right_ridge \
		or left_ridge == -right_ridge
	var left_is_ridge_end := left_side == Side.RIDGE_NEGATIVE \
		or left_side == Side.RIDGE_POSITIVE
	var right_is_ridge_end := right_side == Side.RIDGE_NEGATIVE \
		or right_side == Side.RIDGE_POSITIVE
	if height_delta == 0:
		if same_ridge_orientation and left_is_ridge_end and right_is_ridge_end:
			return JunctionKind.RIDGE_CONTINUATION
		if same_ridge_orientation:
			return JunctionKind.PARALLEL_VALLEY
		return JunctionKind.PERPENDICULAR_VALLEY
	if not left_is_ridge_end and not right_is_ridge_end:
		return JunctionKind.STEPPED_EAVE_WALL
	return JunctionKind.STEPPED_GABLE_WALL


static func _contact(left: Dictionary, right: Dictionary) -> Dictionary:
	var left_columns := _columns(left)
	var right_columns := _columns(right)
	for column_value: Variant in left_columns.keys():
		if right_columns.has(column_value):
			return {}
	var counts: Dictionary = {}
	var contact_columns: Dictionary = {}
	for column_value: Variant in left_columns.keys():
		var column := column_value as Vector2i
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
				Vector2i.UP, Vector2i.DOWN]:
			if right_columns.has(column + direction):
				counts[direction] = int(counts.get(direction, 0)) + 1
				if not contact_columns.has(direction):
					contact_columns[direction] = [] as Array[Vector2i]
				(contact_columns[direction] as Array[Vector2i]).append(column)
	if counts.is_empty():
		return {}
	var best_direction := Vector2i.ZERO
	var best_count := 0
	for direction_value: Variant in counts.keys():
		var direction := direction_value as Vector2i
		var count := int(counts[direction])
		if count > best_count:
			best_direction = direction
			best_count = count
	return {"direction": best_direction, "face_cells": best_count,
		"left_columns": contact_columns[best_direction] as Array}


static func _contact_offset_half_steps(proposal: Dictionary, side: int,
		contact_columns: Array[Vector2i]) -> int:
	## Offset is measured in 1.5 m lattice steps from the complete roof-run
	## centre.  Roofs have even-cell runs and legal seam modules span an even
	## number of cells, so every supported segment centre lands on an integer
	## step and never needs an arbitrary visual translation.
	if contact_columns.is_empty():
		return 0
	var axes := _axes(proposal)
	var run_axis := axes.ridge as Vector2i if side == Side.EAVE_NEGATIVE \
		or side == Side.EAVE_POSITIVE else axes.eave as Vector2i
	var all_columns := _columns(proposal)
	var origin := proposal.get("origin", Vector3i()) as Vector3i
	var origin_2d := Vector2i(origin.x, origin.z)
	var all_min := 2147483647
	var all_max := -2147483648
	for column_value: Variant in all_columns.keys():
		var delta := (column_value as Vector2i) - origin_2d
		var coordinate: int = delta.x * run_axis.x + delta.y * run_axis.y
		all_min = mini(all_min, coordinate)
		all_max = maxi(all_max, coordinate)
	var contact_min := 2147483647
	var contact_max := -2147483648
	for column: Vector2i in contact_columns:
		var delta := column - origin_2d
		var coordinate: int = delta.x * run_axis.x + delta.y * run_axis.y
		contact_min = mini(contact_min, coordinate)
		contact_max = maxi(contact_max, coordinate)
	# Twice the centre difference avoids float rounding. One unit is half a
	# lattice cell (0.75 m); parallel eave modules use the even subset, while the
	# complete signature can still describe perpendicular contacts exactly.
	var doubled_offset := contact_min + contact_max - all_min - all_max
	return doubled_offset


static func _columns(proposal: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var origin := proposal.get("origin", Vector3i()) as Vector3i
	for cell: Vector3i in StaggeredFabricCompiler.proposal_occupied_cells(
			proposal):
		if cell.y == origin.y:
			out[Vector2i(cell.x, cell.z)] = true
	return out


static func _axes(proposal: Dictionary) -> Dictionary:
	var yaw := int(proposal.get("yaw_quarters", -1))
	if yaw < 0 or yaw > 3:
		return {}
	# Wide/shallow rowhouses use their broad facade as an eave and therefore run
	# the ridge along local X. Every other current room family is ridge-Z.
	var ridge_local := Vector3i.RIGHT \
		if StringName(proposal.get("kind", &"")) == &"row" else Vector3i.BACK
	var eave_local := Vector3i.BACK \
		if StringName(proposal.get("kind", &"")) == &"row" else Vector3i.RIGHT
	var ridge_3d := FabricRecipe.transform_direction(ridge_local, yaw)
	var eave_3d := FabricRecipe.transform_direction(eave_local, yaw)
	return {
		"ridge": Vector2i(ridge_3d.x, ridge_3d.z),
		"eave": Vector2i(eave_3d.x, eave_3d.z),
	}


static func _side(proposal: Dictionary, direction: Vector2i) -> int:
	var axes := _axes(proposal)
	if axes.is_empty():
		return -1
	var ridge := axes.ridge as Vector2i
	var eave := axes.eave as Vector2i
	if direction == -ridge:
		return Side.RIDGE_NEGATIVE
	if direction == ridge:
		return Side.RIDGE_POSITIVE
	if direction == -eave:
		return Side.EAVE_NEGATIVE
	if direction == eave:
		return Side.EAVE_POSITIVE
	return -1


static func _roof_base(proposal: Dictionary) -> int:
	return (proposal.get("origin", Vector3i()) as Vector3i).y \
		+ int(proposal.get("storeys", 0)) * WarrenBuildingParcel.STOREY_BANDS


static func _signature(junctions: Array) -> StringName:
	if junctions.is_empty():
		return &"isolated"
	var parts := PackedStringArray()
	for seam: Dictionary in junctions:
		parts.append("%d.%d.%d.%d.%d" % [int(seam.side), int(seam.kind),
			signi(int(seam.height_delta)), int(seam.face_cells),
			int(seam.run_offset_half_steps)])
	return StringName("+".join(parts))


static func _junction_less(a: Dictionary, b: Dictionary) -> bool:
	if int(a.side) != int(b.side):
		return int(a.side) < int(b.side)
	if int(a.kind) != int(b.kind):
		return int(a.kind) < int(b.kind)
	return String(a.neighbor_id) < String(b.neighbor_id)


func _reject(reason: String) -> bool:
	last_rejection = reason
	return false
