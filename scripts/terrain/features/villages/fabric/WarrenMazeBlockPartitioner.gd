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
	if not source.parcel_claims.is_empty():
		return _translate_claims(source, volume)
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


static func _translate_claims(source: WarrenMazeSourcePlan,
		volume: WarrenVolumePlan) -> WarrenParcelPlan:
	## The maze's own enumeration, scoring and shape choice already happened
	## in WarrenMazeStampPass; a sealed `source.parcel_claims` is a finished
	## decision, not raw material for a second search. This stage only proves
	## each claim's real construction contract -- a sealed WarrenBuildingParcel
	## whose threshold actually serves its own claimed address -- and
	## translates it 1:1. No shapes menu, no scoring, no claiming loop: a
	## claim that cannot seal on either door phase is a generator bug (a claim
	## the stamp pass should never have produced), not a shape this stage may
	## silently substitute or drop.
	var parcels: Array[WarrenBuildingParcel] = []
	var lineage_hints: Dictionary = {}
	var failures: Array[String] = []
	for index in source.parcel_claims.size():
		var claim := source.parcel_claims[index] as Dictionary
		var stable_id := StringName("parcel.maze.%04d" % index)
		var footprint := claim.get("footprint", []) as Array[Vector2i]
		var parcel := _seal_claim(stable_id, claim, footprint, volume)
		if parcel == null:
			failures.append("claim %d at door_column %s (shape %s)" % [
				index, claim.get("door_column", Vector2i.ZERO),
				String(claim.get("shape_id", &""))])
			continue
		parcels.append(parcel)
		var lineage_hint := StringName(claim.get("lineage_hint", &""))
		if not lineage_hint.is_empty():
			lineage_hints[String(stable_id)] = lineage_hint
	if not failures.is_empty():
		last_failure = "translation dropped %d/%d claims (generator bug): %s" \
			% [failures.size(), source.parcel_claims.size(),
				"; ".join(failures)]
		return null
	var plan := WarrenParcelPlan.new(
		StringName("%s.maze_parcels" % volume.stable_id), volume)
	if not plan.seal(parcels):
		last_failure = "maze parcel plan rejected: %s" % plan.last_rejection
		return null
	var ownership := _ownership_audit_translated(source, volume, parcels)
	last_diagnostic = {
		"translated_claim_count": source.parcel_claims.size(),
		"parcel_count": parcels.size(),
	}
	last_diagnostic.merge(ownership, true)
	for key: Variant in last_diagnostic.keys():
		plan.audit["maze_%s" % String(key)] = last_diagnostic[key]
	# WarrenBuildingParcel has no metadata slot of its own (it is pure
	# geometry/address), so the claim's authored lineage grouping -- which the
	# construction/composition stages need to treat several claims as one
	# building -- is carried on the plan's own audit instead, keyed by the
	# stable parcel id it was translated onto.
	if not lineage_hints.is_empty():
		plan.audit["maze_lineage_hints"] = lineage_hints
	# Column-level breakdown of the source massif, mirroring the classification
	# Task 4's round-4 fix report instrumented by hand (task-4-report.md,
	# "Fix report round 4"): every massif column is claimed by a translated
	# parcel, reserved by P3, geometrically buildable but never claimed, or
	# neither. This is the M4/slice-2 diagnostic the ownership ratio alone
	# can't give a fix a lever against -- see the ratio's own comment for why
	# 0.85 is no longer measured here.
	plan.audit["maze_ownership_breakdown"] = _ownership_breakdown(source,
		parcels)
	return plan


static func _seal_claim(stable_id: StringName, claim: Dictionary,
		footprint: Array[Vector2i],
		volume: WarrenVolumePlan) -> WarrenBuildingParcel:
	var floor_band := int(claim.get("floor_band", 0))
	var top_band := int(claim.get("top_band", 0))
	var door_walk := claim.get("door_walk", Vector3i.ZERO) as Vector3i
	var door_column := claim.get("door_column", Vector2i.ZERO) as Vector2i
	var frontage := claim.get("frontage", Vector2i.ZERO) as Vector2i
	for door_phase in 2:
		var parcel := WarrenBuildingParcel.new(stable_id, footprint, floor_band,
			top_band, door_walk, door_column, frontage, door_phase)
		if parcel.seal(volume) \
				and WarrenParcelConstruction.door_serves_address(parcel):
			return parcel
	return null


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
	## LEGACY-path ownership audit only (the greedy shapes-menu path in
	## `partition()`). Its fixtures always carve directly and never run
	## P3/P4, so `source.reservations`/`column_edits`/`foundation_columns` are
	## always empty here and this stays byte-identical to what it always was.
	## The TRANSLATED path (`_translate_claims`) uses `_ownership_audit_translated`
	## below instead -- see that function's own header for why.
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
	# Reservation footprints (the market approach flanks, a landmark or
	# skywalk landing -- any of P3's typed large features) and the rock
	# foundation under a ledger-raised floor are both deliberate construction
	# the maze's own ledger already committed to; neither is a
	# WarrenBuildingParcel (a reservation is never translated into one, and a
	# foundation is the ledger's own below-floor stonework, not a room), so
	# neither ever appears in a parcel's own occupied_cells -- but they are
	# not unclaimed waste either. Controller ruling: count them as owned
	# solid too. Marked directly at the same macro (column, band) resolution
	# `volume.mass_cells`/`has_mass` use, which is NOT the resolution a
	# parcel's own `proposal().occupied_cells` is expressed in (the fine
	# FabricRecipe render grid, doubled in x/z) -- that mismatch is exactly
	# why the loop above only ever registers a coincidental few of a
	# parcel's own cells as "owned". On THIS (legacy) path the two loops
	# below are always a no-op (empty reservations/foundation_columns, per
	# this function's own header); the aliasing bug in the loop above stays
	# untouched here -- it only matters for the translated path, which reads
	# real ledger data and gets the fix in `_ownership_audit_translated`.
	for reservation: Dictionary in source.reservations:
		for column: Vector2i in reservation.get("cells", []) as Array[Vector2i]:
			_mark_owned_column_range(volume, column,
				source.effective_base(column), source.effective_top(column),
				&"maze.reservation", owned, owned_columns)
	var foundation_columns := source.audit.get("foundation_columns", {}) \
		as Dictionary
	for column_value: Variant in foundation_columns.keys():
		var column := column_value as Vector2i
		_mark_owned_column_range(volume, column, source.massif.base_at(column),
			source.effective_base(column), &"maze.foundation", owned,
			owned_columns)
	var post_carve_solid := volume.mass_cells.size()
	return {
		"post_carve_solid_cell_count": post_carve_solid,
		"owned_solid_cell_count": owned.size(),
		"owned_solid_ratio": float(owned.size()) \
			/ float(maxi(1, post_carve_solid)),
		"owned_column_count": owned_columns.size(),
		"footprint_family_counts": family_counts,
	}


static func _ownership_audit_translated(source: WarrenMazeSourcePlan,
		volume: WarrenVolumePlan,
		parcels: Array[WarrenBuildingParcel]) -> Dictionary:
	## TRANSLATED-path ownership audit. `_ownership_audit` above (kept for the
	## legacy greedy path only) reads a parcel's owned cells through
	## `WarrenParcelConstruction.proposal(parcel).occupied_cells`, which is
	## expressed on the FINE render grid (doubled in x/z -- see that
	## function's own comment) and only coincidentally aliases against
	## `volume.has_mass`'s MACRO cells; on the legacy path that mismatch was
	## always moot (its fixtures never populate reservations/column_edits), but
	## on the translated path it silently mis-counts almost every claim's own
	## footprint by coincidental grid alias -- sometimes crediting cells that
	## are not really the claim's own, sometimes missing cells that are, with
	## no consistent direction (measured both ways across the pinned seeds:
	## see the final-fix report for old vs. new numbers).
	##
	## `WarrenBuildingParcel.occupied_cells()` (as opposed to
	## `WarrenParcelConstruction.proposal(parcel)`'s fine-grid field of the
	## same name) is already exactly footprint x [base_band, top_band) at the
	## SAME macro resolution `volume.has_mass` reads -- `seal()` built it that
	## way and required `has_mass` true for every cell in it before it would
	## even seal -- so this reads that directly instead of going through the
	## fine-grid detour.
	##
	## Reservation footprints are read exactly as the legacy audit already
	## reads them (effective_base/effective_top over a reservation's own
	## cells -- already macro-resolution, no bug there). The legacy audit's
	## foundation-crediting loop (marking [massif.base_at, effective_base) as
	## owned) is dropped here outright: WarrenMazeVolumeAdapter._edited_massif
	## raises an edited column's OWN base to effective_base before building
	## `volume`, so `volume` never contains mass below that raised floor to
	## begin with -- the range that loop marks can never be solid in `volume`,
	## so it could never register anything. Measured as a no-op, not kept as
	## a conservative extra check.
	var owned: Dictionary = {}
	var owned_columns: Dictionary = {}
	var family_counts: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels:
		for cell: Vector3i in parcel.occupied_cells():
			owned[cell] = parcel.stable_id
			owned_columns[Vector2i(cell.x, cell.z)] = parcel.stable_id
		var family := "%dx%d" % [parcel.width_cells, parcel.depth_cells]
		family_counts[family] = int(family_counts.get(family, 0)) + 1
	for reservation: Dictionary in source.reservations:
		for column: Vector2i in reservation.get("cells", []) as Array[Vector2i]:
			_mark_owned_column_range(volume, column,
				source.effective_base(column), source.effective_top(column),
				&"maze.reservation", owned, owned_columns)
	var post_carve_solid := volume.mass_cells.size()
	return {
		"post_carve_solid_cell_count": post_carve_solid,
		"owned_solid_cell_count": owned.size(),
		"owned_solid_ratio": float(owned.size()) \
			/ float(maxi(1, post_carve_solid)),
		"owned_column_count": owned_columns.size(),
		"footprint_family_counts": family_counts,
	}


static func _mark_owned_column_range(volume: WarrenVolumePlan,
		column: Vector2i, base: int, top: int, marker: StringName,
		owned: Dictionary, owned_columns: Dictionary) -> void:
	for y in range(base, top):
		var cell := Vector3i(column.x, y, column.y)
		if volume.has_mass(cell):
			owned[cell] = marker
			owned_columns[Vector2i(cell.x, cell.z)] = marker


static func _ownership_breakdown(source: WarrenMazeSourcePlan,
		parcels: Array[WarrenBuildingParcel]) -> Dictionary:
	## Every massif column falls into exactly one bucket: claimed by a
	## translated parcel, reserved by P3, geometrically buildable from its own
	## effective floor but never claimed, or neither. `claimed`/`reserved`
	## come straight off the sealed facts (a parcel's own footprint, a
	## reservation's own cells); `buildable` reuses the SAME ceiling test
	## WarrenMazeStampPass enumerates candidates against
	## (`_column_ceiling`/`MIN_HOUSE_BANDS`), just restated here rather than
	## reached into that file's own private helper, so this stays a read of
	## public source-plan facts only.
	var claimed: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels:
		for column: Vector2i in parcel.footprint:
			claimed[column] = true
	var reserved: Dictionary = {}
	for reservation: Dictionary in source.reservations:
		for column: Vector2i in reservation.get("cells", []) as Array[Vector2i]:
			reserved[column] = true
	var buildable_unclaimed := 0
	var unbuildable := 0
	for column: Vector2i in source.massif.columns:
		if claimed.has(column) or reserved.has(column):
			continue
		var floor_band := source.effective_base(column)
		if _column_ceiling(source, column, floor_band) - floor_band \
				>= WarrenMazeSourcePlan.MIN_HOUSE_BANDS:
			buildable_unclaimed += 1
		else:
			unbuildable += 1
	return {
		"claimed": claimed.size(),
		"reserved": reserved.size(),
		"buildable_unclaimed": buildable_unclaimed,
		"unbuildable": unbuildable,
	}


static func _column_ceiling(source: WarrenMazeSourcePlan, column: Vector2i,
		floor_band: int) -> int:
	## Mirrors WarrenMazeStampPass._column_ceiling exactly (continuous SOLID
	## state from `floor_band` up to the massif's own top): the highest band
	## this column could carry a claim to if one were placed here, read
	## through the public `state_at` contract rather than that file's own
	## private helper.
	var top_limit := source.massif.top_at(column)
	var y := floor_band
	while y < top_limit and source.state_at(Vector3i(column.x, y, column.y)) \
			== WarrenMazeSourcePlan.CellState.SOLID:
		y += 1
	return y
