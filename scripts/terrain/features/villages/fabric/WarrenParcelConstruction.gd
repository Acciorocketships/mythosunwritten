class_name WarrenParcelConstruction
extends RefCounted

## Pure geometry contract shared by parcel planning, surface entrances, and the
## asset compiler. Footprint, local phase, yaw, and door threshold are decided
## once; palette and prefab choices cannot move them afterward. A parcel
## addressed from an upper route becomes one continuous inhabited stack rooted
## at the highest compatible natural-ground phase. It is never a short house on
## an abstract proof column.


static func proposal(parcel: WarrenBuildingParcel) -> Dictionary:
	var profile := profile_for(parcel)
	if profile.is_empty():
		return {}
	var yaw := _yaw_for_frontage(parcel.frontage_direction)
	if yaw < 0:
		return {}
	var origin := _matching_origin(parcel, profile, yaw)
	if origin.x == 2147483647:
		return {}
	var support_base := _support_base_band(parcel)
	if support_base > parcel.base_band \
			or posmod(parcel.base_band - support_base,
				WarrenBuildingParcel.STOREY_BANDS) != 0:
		return {}
	origin.y = support_base
	var lower_storeys := (parcel.base_band - support_base) \
		/ WarrenBuildingParcel.STOREY_BANDS
	var result := {
		"stable_id": parcel.stable_id,
		"kind": profile.kind,
		"origin": origin,
		"yaw_quarters": yaw,
		"storeys": parcel.storey_count() + lower_storeys,
		"route_y": parcel.base_band,
		"roof_feature": _roof_feature(parcel, profile),
	}
	result["occupied_cells"] = \
		StaggeredFabricCompiler.proposal_occupied_cells(result)
	return result


static func _roof_feature(parcel: WarrenBuildingParcel,
		profile: Dictionary) -> int:
	## Feature selection happens before measured-envelope qualification.  A
	## dormer therefore participates in the same broad phase as its roof and can
	## never appear later inside a neighbor.  Only the nine-metre longhouse has
	## enough uninterrupted authored slope for the initial reviewed vocabulary.
	var kind := StringName(profile.get("kind", ""))
	var seed := int(parcel.source.world_seed) if parcel.source != null else 0
	var value := seed ^ parcel.threshold_column.x * 73856093 \
		^ parcel.threshold_column.y * 19349663 ^ parcel.base_band * 83492791
	if kind == &"tower":
		return 3 if posmod(value, 3) == 0 else 0
	if kind == &"slim":
		return 3 if posmod(value, 4) == 0 else 0
	if kind == &"building":
		# Complete square roofs can now carry either handed dormer as well as a
		# chimney.  Selection is a parcel fact before measured-clearance packing;
		# these are different construction envelopes, not post-hoc decorations.
		var phase := posmod(value, 7)
		return 1 if phase in [0, 1] else 2 if phase in [2, 3] \
			else 3 if phase == 4 else 0
	if kind != &"long":
		return 0
	# Every longhouse receives a dormer. Plain long runs already exist in the
	# square/slim/tower vocabulary, while the long facade is the only reviewed
	# slope large enough for a pair of integrated attic projections. Values four
	# and five select the two-dormer finite recipes; side and count both remain
	# seed-dependent so the feature cannot become a repeated stamp.
	var phase := posmod(value, 6)
	return 1 if phase in [0, 1] else 2 if phase in [2, 3] else phase


static func retained_terrace_cells(parcel: WarrenBuildingParcel) \
		-> Array[Vector3i]:
	## The hill a raised house stands on, at construction resolution: source
	## mass between each footprint column's natural ground and the band the
	## stack actually stops descending at.
	##
	## Empty whenever the two coincide -- every route-first parcel, and every
	## mass-first house whose terrace IS its ground -- so declaring it costs
	## nothing where there is no hill. Deliberately NOT occupancy: it claims no
	## socket, collides with no recipe and never enters the visual-envelope
	## test. SettlementFabricAssembler renders it as retained stone, because
	## nothing else renders unbuilt massif mass and a house resting on an
	## unrendered terrace floats.
	var out: Array[Vector3i] = []
	if parcel == null or parcel.source == null or not parcel.is_sealed():
		return out
	var construction := proposal(parcel)
	if construction.is_empty():
		return out
	var support := (construction.origin as Vector3i).y
	for column: Vector2i in parcel.footprint:
		# From the column's own STAMPED GROUND, not from the declared bottom of
		# the solid: since the undercroft wave `ground_at` may sit below the
		# surface where a street tunnels under the column, and a plinth measured
		# from there would fill the tunnel with foundation stone. `bearing_at`
		# is the surface, which is where a plinth starts and where a house
		# grounds. The two are equal on every column no tunnel passes under, and
		# on every route-first parcel.
		for band in range(parcel.source.envelope.bearing_at(column), support):
			# Only mass is hill. A street cut through the gap -- the bore under
			# a plinth, or a secondary lane tunnelling beneath a terrace -- is
			# void the plan already removed, and declaring it as retained stone
			# would fill the passage in with rock. A footprint may legally span
			# such a column, since WarrenBuildingParcel requires continuous
			# bearing under only half of one.
			if not parcel.source.has_mass(Vector3i(column.x, band, column.y)):
				continue
			for x_offset in 2:
				for z_offset in 2:
					out.append(Vector3i(column.x * 2 + x_offset, band,
						column.y * 2 + z_offset))
	return out


static func threshold_cell(parcel: WarrenBuildingParcel) -> Vector3i:
	var profile := profile_for(parcel)
	var construction := proposal(parcel)
	if profile.is_empty() or construction.is_empty():
		return Vector3i(2147483647, 2147483647, 2147483647)
	var addressed_door := profile.door_cell as Vector3i
	addressed_door.y += parcel.base_band \
		- (construction.origin as Vector3i).y
	return FabricRecipe.transform_cell(addressed_door,
		construction.origin as Vector3i, int(construction.yaw_quarters))


static func addressed_unit_id(parcel: WarrenBuildingParcel) -> StringName:
	if parcel == null:
		return &""
	var construction := proposal(parcel)
	if construction.is_empty():
		return &""
	var addressed_level := (parcel.base_band \
		- (construction.origin as Vector3i).y) \
		/ WarrenBuildingParcel.STOREY_BANDS
	var role := "base" if addressed_level == 0 else "upper.%02d" % \
		addressed_level
	return StringName("volume.%s.%s" % [parcel.stable_id, role])


static func door_serves_address(parcel: WarrenBuildingParcel) -> bool:
	## A wide facade can have more than one macro cell, but the reviewed recipe
	## owns one exact doorway. The parcel address is valid only when that real
	## transformed threshold opens directly onto its claimed walk square.
	if parcel == null or not parcel.is_sealed():
		return false
	var threshold := threshold_cell(parcel)
	if threshold.x == 2147483647:
		return false
	var facing := Vector3i(parcel.frontage_direction.x, 0,
		parcel.frontage_direction.y)
	var landing := threshold + facing
	var address_origin := Vector3i(parcel.address_walk_cell.x * 2,
		parcel.address_walk_cell.y, parcel.address_walk_cell.z * 2)
	return landing.y == address_origin.y \
		and landing.x >= address_origin.x and landing.x <= address_origin.x + 1 \
		and landing.z >= address_origin.z and landing.z <= address_origin.z + 1


static func candidate_address_landing(parcel: WarrenBuildingParcel,
		volume: WarrenVolumePlan) -> Vector3i:
	## Preview the exact authored doorway of an unsealed partition candidate
	## without sealing (and therefore freezing) the candidate itself.  Roof-joint
	## repair may still step its top band down before the transaction is final.
	## The disposable clone applies the complete downstream parcel contract, so
	## this query cannot bless a door on a footprint the source volume rejects.
	var invalid := Vector3i(2147483647, 2147483647, 2147483647)
	if parcel == null or volume == null or not volume.is_sealed():
		return invalid
	var preview := WarrenBuildingParcel.new(parcel.stable_id,
		parcel.footprint, parcel.base_band, parcel.top_band,
		parcel.address_walk_cell, parcel.threshold_column,
		parcel.frontage_direction, parcel.address_door_phase)
	if not preview.seal(volume) or not door_serves_address(preview):
		return invalid
	var threshold := threshold_cell(preview)
	return threshold + Vector3i(preview.frontage_direction.x, 0,
		preview.frontage_direction.y)


static func profile_for(parcel: WarrenBuildingParcel) -> Dictionary:
	if parcel == null or not parcel.is_sealed():
		return {}
	if parcel.width_cells == 1 and parcel.depth_cells == 1:
		return {
			"kind": &"tower",
			"minimum": Vector3i(-1, 0, -1),
			"size": Vector3i(2, 1, 2),
			"door_cell": Vector3i(-parcel.address_door_phase, 0, 0),
		}
	if parcel.width_cells == 1 and parcel.depth_cells == 2:
		return {
			"kind": &"slim",
			"minimum": Vector3i(-1, 0, -2),
			"size": Vector3i(2, 1, 4),
			"door_cell": Vector3i(-parcel.address_door_phase, 0, 1),
		}
	if parcel.width_cells == 2 and parcel.depth_cells == 2:
		return {
			"kind": &"building",
			"minimum": Vector3i(-2, 0, -2),
			"size": Vector3i(4, 1, 4),
			"door_cell": Vector3i(-1 - parcel.address_door_phase, 0, 1),
		}
	if parcel.width_cells == 2 and parcel.depth_cells == 3:
		return {
			"kind": &"long",
			"minimum": Vector3i(-2, 0, -3),
			"size": Vector3i(4, 1, 6),
			"door_cell": Vector3i(-1 - parcel.address_door_phase, 0, 2),
		}
	return {}


static func _support_base_band(parcel: WarrenBuildingParcel) -> int:
	## A uniform room stack may descend only when every footprint column owns a
	## continuous source-mass bearing path. Mixed-span parcels intentionally stay
	## at their addressed level; a later explicit overhang/support recipe must
	## carry them without filling a public passage below.
	##
	## It descends to the envelope's BEARING datum, which is natural ground
	## unless the envelope declares a terrace above it. That distinction is the
	## whole difference between a hill town and a tower: a street eight bands up
	## flanked by six of mass stands on fourteen bands of solid, and descending a
	## house through all fourteen is what a viewer counts as seven storeys. The
	## mass below the terrace is hill, not house.
	##
	## PER COLUMN AND HONEST since the terrain milestone's Wave 5. The datum is
	## the HIGHEST bearing band under the footprint -- each column's own stamped
	## ground, sampled rather than inferred -- so the stack rests on the real
	## surface of the highest ground it covers and never floats over it. Where a
	## footprint straddles a terrace step, the columns below that datum are the
	## gap `retained_terrace_cells` declares and the assembler fills with
	## sfv.foundation.rock plinth stone: the downhill side gets the course of
	## stone that makes the house one storey taller, which is what a plinth is
	## FOR.
	##
	## THE STOREY PARITY, which is the whole of the old defect. A stack meets its
	## address only on a whole STOREY_BANDS boundary, and a ground band of the
	## wrong parity has to be resolved one way or the other. Resolving it DOWN --
	## `result -= 1` -- buries the house one band under its own ground, and that
	## single line, not hill geometry, is what put 211 of 424 mass-first houses
	## into the earth against zero plinths (task-23-report §4). An envelope that
	## declares a `plinth_budget_bands` resolves it UP instead, onto one band of
	## stone, which is a thing a viewer can see and a mason would build. The
	## budget also bounds it: a straddle whose plinth would exceed the allowance
	## falls back to the cut rather than growing a masonry terrace.
	##
	## Route-first envelopes leave the budget at zero and are byte-identical.
	if parcel == null or parcel.source == null \
			or parcel.bearing_columns.size() != parcel.footprint.size():
		return parcel.base_band if parcel != null else 0
	var envelope := parcel.source.envelope
	var highest_ground := -2147483648
	var lowest_ground := 2147483647
	for column: Vector2i in parcel.footprint:
		var ground := envelope.bearing_at(column)
		highest_ground = maxi(highest_ground, ground)
		lowest_ground = mini(lowest_ground, ground)
	return resolve_support_band(highest_ground, lowest_ground,
		parcel.base_band, envelope.plinth_budget_bands)


## Bands of apparent face a building must present before it stops reading as a
## shed. RESTATED, not moved: the rule production has always enforced is
## `WarrenParcelConstruction.proposal().storeys >= 2` counted from the support
## datum, and that datum was one band UNDER the ground whenever the address
## offset was odd -- so the old bar was six bands of face on an even offset and
## five on an odd one, and this single number is exactly that pair
## (`MIN_STOREYS * STOREY_BANDS + ROOF_RESERVATION_BANDS - 1`), because an even
## offset can only ever produce an even face. The equivalence is proved by test
## over the whole reachable input space rather than argued here.
##
## Why restate it at all: the storey form credited a room buried under the
## terrain, so it could not survive honest grounding (Wave 5), while the face
## form says the thing the reviewer actually judges -- how tall the building
## looks from the ground it stands on -- and counts the plinth stone that makes
## up the band an odd offset cannot buy.
const MIN_APPARENT_FACE_BANDS := 5


static func apparent_face_bands(parcel: WarrenBuildingParcel) -> int:
	## Bands of this building a viewer sees standing on the ground it is cut
	## into: its roof band minus the HIGHEST stamped ground under its own
	## footprint. Plinth stone counts (it is visible and load-bearing); anything
	## under the terrain does not.
	if parcel == null or parcel.source == null:
		return 0
	var ground := -2147483648
	for column: Vector2i in parcel.footprint:
		ground = maxi(ground, parcel.source.envelope.bearing_at(column))
	return parcel.top_band - mini(ground, parcel.base_band)


static func resolve_support_band(highest_ground: int, lowest_ground: int,
		base_band: int, plinth_budget: int) -> int:
	## The one place the support datum's storey parity is resolved. Shared
	## rather than restated because WarrenSolidPartitioner has to predict this
	## answer twice -- once to size an envelope (`_minimum_bands`) and once to
	## bucket an unowned street wall (`_wall_verdict`) -- and three copies of a
	## `result -= 1` are how a buried house becomes invisible to the audit that
	## exists to catch it.
	var result := mini(highest_ground, base_band)
	if posmod(base_band - result, WarrenBuildingParcel.STOREY_BANDS) != 0:
		if plinth_budget > 0 and result < base_band \
				and result + 1 - lowest_ground <= plinth_budget:
			result += 1
		else:
			result -= 1
	return mini(result, base_band)


static func _yaw_for_frontage(frontage: Vector2i) -> int:
	var target := Vector3i(frontage.x, 0, frontage.y)
	for yaw in 4:
		if FabricRecipe.transform_direction(Vector3i.BACK, yaw) == target:
			return yaw
	return -1


static func _matching_origin(parcel: WarrenBuildingParcel,
		profile: Dictionary, yaw: int) -> Vector3i:
	var target: Dictionary = {}
	for macro_column: Vector2i in parcel.footprint:
		for x_offset in 2:
			for z_offset in 2:
				target[Vector3i(macro_column.x * 2 + x_offset,
					parcel.base_band, macro_column.y * 2 + z_offset)] = true
	var local_cells := FabricRecipe.box_cells(profile.minimum as Vector3i,
		profile.size as Vector3i)
	var target_cells: Array[Vector3i] = []
	target_cells.assign(target.keys())
	target_cells.sort_custom(_cell_less)
	for target_anchor: Vector3i in target_cells:
		for local_anchor: Vector3i in local_cells:
			var rotated_anchor := FabricRecipe.transform_cell(local_anchor,
				Vector3i.ZERO, yaw)
			var origin := target_anchor - rotated_anchor
			var matched := true
			for local_cell: Vector3i in local_cells:
				if not target.has(FabricRecipe.transform_cell(local_cell,
						origin, yaw)):
					matched = false
					break
			if matched:
				return origin
	return Vector3i(2147483647, 2147483647, 2147483647)


static func _cell_less(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	if a.z != b.z:
		return a.z < b.z
	return a.x < b.x
