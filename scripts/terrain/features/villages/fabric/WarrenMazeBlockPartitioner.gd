class_name WarrenMazeBlockPartitioner
extends RefCounted

## One-pass parcel adapter for a sealed WarrenMazeSourcePlan. The maze already
## decided the public graph and the solid it left behind; this stage assigns
## complete authored construction envelopes to that solid without generating
## or ranking alternative partitions.
##
## A frontage parcel may be one or two macro columns wide and up to three deep,
## matching WarrenParcelConstruction's measured tower/slim/row/building/long
## vocabulary. Deep-core columns which no complete frontage envelope consumes
## remain explicit in the audit for M4's later upper/back-mass ownership pass;
## they are never silently reported as buildings.
const SHAPES: Array[Vector2i] = [
	Vector2i(2, 3), Vector2i(2, 2), Vector2i(1, 2),
	Vector2i(2, 1), Vector2i(1, 1),
]
const CARDINALS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
]
const MIN_PARCELS := 10

static var last_failure := ""
static var last_diagnostic: Dictionary = {}


static func partition(source: WarrenMazeSourcePlan,
		volume: WarrenVolumePlan) -> WarrenParcelPlan:
	last_failure = ""
	last_diagnostic = {}
	if source == null or not source.is_sealed() or volume == null \
			or not volume.is_sealed() \
			or volume.mass_context.get(&"maze_source_plan") != source:
		last_failure = "missing or mismatched sealed maze source and volume"
		return null
	var faces := _frontage_faces(source, volume)
	last_diagnostic = {"frontage_face_count": faces.size(),
		"candidate_rejections": {}}
	var claimed_columns: Dictionary = {}
	var parcels: Array[WarrenBuildingParcel] = []
	var inherited_faces := 0
	var stranded_faces := 0
	for face: Dictionary in faces:
		if _face_is_owned(face, parcels):
			inherited_faces += 1
			continue
		var parcel := _parcel_for_face(source, volume, face,
			claimed_columns, parcels.size())
		if parcel == null:
			stranded_faces += 1
			continue
		for column: Vector2i in parcel.footprint:
			claimed_columns[column] = parcel.stable_id
		parcels.append(parcel)
	if parcels.size() < MIN_PARCELS:
		last_diagnostic["parcel_count"] = parcels.size()
		last_diagnostic["stranded_frontage_face_count"] = stranded_faces
		last_failure = "one-pass maze partition formed only %d parcels: %s" \
			% [parcels.size(), str(last_diagnostic)]
		return null
	var plan := WarrenParcelPlan.new(
		StringName("%s.maze_parcels" % volume.stable_id), volume)
	if not plan.seal(parcels):
		last_failure = "maze parcel plan rejected: %s" % plan.last_rejection
		return null
	var ownership := _ownership_audit(source, volume, parcels)
	last_diagnostic = {
		"frontage_face_count": faces.size(),
		"inherited_frontage_face_count": inherited_faces,
		"stranded_frontage_face_count": stranded_faces,
		"parcel_count": parcels.size(),
		"claimed_column_count": claimed_columns.size(),
	}
	last_diagnostic.merge(ownership, true)
	for key: Variant in last_diagnostic.keys():
		plan.audit["maze_%s" % String(key)] = last_diagnostic[key]
	return plan


static func _frontage_faces(source: WarrenMazeSourcePlan,
		volume: WarrenVolumePlan) -> Array[Dictionary]:
	## Delegates to WarrenMazeStampPass.frontage_faces_from_plan, the single
	## shared implementation (a duplication finding on an earlier round
	## flagged this method and P4's own copy as byte-for-byte duplicates that
	## could drift; see that method's own comment for the full equivalence
	## argument). `volume` is unused in the body now -- the shared
	## implementation reads solidity through `source` directly -- but the
	## parameter stays for call-site/signature stability; `partition()` still
	## has a sealed `volume` in hand and still passes it here.
	return WarrenMazeStampPass.frontage_faces_from_plan(source)


static func _face_is_owned(face: Dictionary,
		parcels: Array[WarrenBuildingParcel]) -> bool:
	var column := face.column as Vector2i
	var base := (face.walk as Vector3i).y
	for parcel: WarrenBuildingParcel in parcels:
		if parcel.footprint.has(column) and parcel.base_band <= base \
				and parcel.top_band >= base + WarrenMazeSourcePlan.MIN_HOUSE_BANDS:
			return true
	return false


static func _parcel_for_face(source: WarrenMazeSourcePlan,
		volume: WarrenVolumePlan, face: Dictionary,
		claimed_columns: Dictionary, parcel_index: int) -> WarrenBuildingParcel:
	var walk := face.walk as Vector3i
	var threshold := face.column as Vector2i
	var into_block := face.into_block as Vector2i
	var stable_id := StringName("parcel.maze.%04d" % parcel_index)
	var candidates: Array[Dictionary] = []
	for shape_index in SHAPES.size():
		var shape := SHAPES[shape_index]
		var footprint := _footprint(walk, into_block, shape.x, shape.y)
		if _has_claimed_column(footprint, claimed_columns):
			_count_rejection(&"claimed")
			continue
		var top := _top_band(source, volume, footprint, walk.y)
		if top <= walk.y:
			_count_rejection(&"no_top")
			continue
		for door_phase in 2:
			var parcel := WarrenBuildingParcel.new(stable_id, footprint,
				walk.y, top, walk, threshold, -into_block, door_phase)
			if not parcel.seal(volume) \
					or not WarrenParcelConstruction.door_serves_address(parcel):
				_count_rejection(&"parcel_contract")
				continue
			var landing := WarrenParcelConstruction.threshold_cell(parcel) \
				+ Vector3i(parcel.frontage_direction.x, 0,
					parcel.frontage_direction.y)
			if not volume.has_exact_route_surface(landing):
				_count_rejection(&"no_exact_landing")
				continue
			if WarrenParcelConstruction.touches_envelope_boundary(parcel) \
					and not WarrenParcelConstruction.has_perimeter_grounding(parcel) \
					and WarrenParcelConstruction.perimeter_gateway_support(
						parcel).is_empty():
				_count_rejection(&"perimeter_support")
				continue
			var contact := _neighbor_contact_count(footprint, claimed_columns)
			var score := footprint.size() * 10000 + contact * 400 \
				+ parcel.storey_count() * 20 - shape_index * 2 - door_phase
			candidates.append({"parcel": parcel, "score": score})
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left.score) != int(right.score):
			return int(left.score) > int(right.score)
		return String((left.parcel as WarrenBuildingParcel).stable_id) \
			< String((right.parcel as WarrenBuildingParcel).stable_id))
	return candidates[0].parcel as WarrenBuildingParcel


static func _count_rejection(kind: StringName) -> void:
	var counts := last_diagnostic.get("candidate_rejections", {}) as Dictionary
	counts[kind] = int(counts.get(kind, 0)) + 1
	last_diagnostic["candidate_rejections"] = counts


static func _footprint(walk: Vector3i, into_block: Vector2i,
		width: int, depth: int) -> Array[Vector2i]:
	## The authored wide profiles place their door at the negative-perpendicular
	## end. Keeping the threshold there makes the semantic door socket and the
	## public landing agree without a visual offset.
	var perpendicular := Vector2i(-into_block.y, into_block.x)
	var threshold := Vector2i(walk.x, walk.z) + into_block
	var out: Array[Vector2i] = []
	for depth_offset in depth:
		for width_offset in width:
			out.append(threshold + into_block * depth_offset \
				+ perpendicular * width_offset)
	return out


static func _top_band(source: WarrenMazeSourcePlan, volume: WarrenVolumePlan,
		footprint: Array[Vector2i], base: int) -> int:
	var top := 2147483647
	var bearing_count := 0
	for column: Vector2i in footprint:
		if not source.massif.has_column(column) \
				or source.massif.base_at(column) > base:
			_count_rejection(&"top_outside_or_raised_base")
			return base
		var column_top := base
		while column_top < source.massif.top_at(column) \
				and volume.has_mass(Vector3i(column.x, column_top, column.y)):
			column_top += 1
		top = mini(top, column_top)
		bearing_count += int(_has_bearing(volume, column, base))
	if bearing_count * 2 < footprint.size():
		_count_rejection(&"top_bearing")
		return base
	if not WarrenSolidPartitioner.footprint_fits_plinth_budget(source.massif,
			footprint, base if bearing_count < footprint.size() else 1 << 30):
		_count_rejection(&"top_plinth")
		return base
	top -= posmod(top - base, WarrenBuildingParcel.STOREY_BANDS)
	if top < base + WarrenMazeSourcePlan.MIN_HOUSE_BANDS:
		_count_rejection(&"top_below_required_wall")
	return top if top >= base + WarrenMazeSourcePlan.MIN_HOUSE_BANDS else base


static func _has_bearing(volume: WarrenVolumePlan, column: Vector2i,
		base: int) -> bool:
	var ground := volume.envelope.ground_at(column)
	if ground > base:
		return false
	for y in range(ground, base):
		if not volume.has_mass(Vector3i(column.x, y, column.y)):
			return false
	return true


static func _has_claimed_column(footprint: Array[Vector2i],
		claimed_columns: Dictionary) -> bool:
	for column: Vector2i in footprint:
		if claimed_columns.has(column):
			return true
	return false


static func _neighbor_contact_count(footprint: Array[Vector2i],
		claimed_columns: Dictionary) -> int:
	var footprint_set: Dictionary = {}
	for column: Vector2i in footprint:
		footprint_set[column] = true
	var contacts: Dictionary = {}
	for column: Vector2i in footprint:
		for direction: Vector2i in CARDINALS:
			var neighbor := column + direction
			if not footprint_set.has(neighbor) and claimed_columns.has(neighbor):
				contacts[neighbor] = true
	return contacts.size()


static func _ownership_audit(source: WarrenMazeSourcePlan,
		volume: WarrenVolumePlan,
		parcels: Array[WarrenBuildingParcel]) -> Dictionary:
	var owned: Dictionary = {}
	var owned_columns: Dictionary = {}
	var family_counts: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels:
		var proposal := WarrenParcelConstruction.proposal(parcel)
		for cell: Vector3i in proposal.get("occupied_cells", []):
			if volume.has_mass(cell):
				owned[cell] = parcel.stable_id
				owned_columns[Vector2i(cell.x, cell.z)] = parcel.stable_id
		var family := "%dx%d" % [parcel.width_cells, parcel.depth_cells]
		family_counts[family] = int(family_counts.get(family, 0)) + 1
	var post_carve_solid := volume.mass_cells.size()
	return {
		"post_carve_solid_cell_count": post_carve_solid,
		"owned_solid_cell_count": owned.size(),
		"owned_solid_ratio": float(owned.size()) \
			/ float(maxi(1, post_carve_solid)),
		"owned_column_count": owned_columns.size(),
		"footprint_family_counts": family_counts,
	}
