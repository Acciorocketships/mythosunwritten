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
		# The parcel's own roof contract, carried to composition (Task C5,
		# controller ruling 1). Something stands ON a flat-roofed parcel, so
		# its crown is a slab and never a pitched shell. FALSE on every parcel
		# the route-first and mass-first partitioners build, and the legacy
		# staggered compiler still OVERWRITES this key with its own pairwise
		# flattening verdict (`WarrenAssetCompiler` :951/:987), so seeding it
		# here changes no legacy proposal.
		"flat_roof": parcel.flat_roof,
		# The parcel's roof PREFERENCE beside its roof contract (Task C5d
		# ruling 2). Empty on every legacy proposal and on most maze houses;
		# `&"pitched"` names a crown the roof compiler should try the authored
		# pitched shell on before falling back to the slab.
		"roof_preference": parcel.roof_preference,
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
		var tower_phase := posmod(value, 8)
		return 1 if tower_phase == 0 else 2 if tower_phase == 1 \
			else 3 if tower_phase == 2 else 0
	if kind == &"slim":
		var slim_phase := posmod(value, 8)
		return 1 if slim_phase in [0, 1] else 2 if slim_phase in [2, 3] \
			else 3 if slim_phase == 4 else 0
	if kind == &"building":
		# Complete square roofs can now carry either handed dormer as well as a
		# chimney.  Selection is a parcel fact before measured-clearance packing;
		# these are different construction envelopes, not post-hoc decorations.
		var phase := posmod(value, 7)
		# Most complete square roofs receive an integrated dormer, split across
		# both eaves. One phase keeps a chimney and one stays quiet, so a roofscape
		# gains readable cadence instead of either uniform repetition or confetti.
		return 1 if phase in [0, 1, 2] else 2 if phase in [3, 4] \
			else 3 if phase == 5 else 0
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


static func address_door_phase_for_room(kind: StringName, origin: Vector3i,
		yaw_quarters: int, threshold: Vector3i,
		frontage: Vector3i) -> int:
	## Recomposition may move or reshape one complete room block while preserving
	## the parcel's exact world-space threshold. The original parcel phase is no
	## longer meaningful after that move; derive the finite authored door variant
	## from the final room geometry so the visual aperture and topology cannot
	## diverge by one 1.5 m half-cell.
	if FabricRecipe.transform_direction(Vector3i.BACK, yaw_quarters) != frontage:
		return -1
	var phase_zero := Vector3i.ZERO
	match kind:
		&"tower":
			phase_zero = Vector3i(0, 0, 0)
		&"slim":
			phase_zero = Vector3i(0, 0, 1)
		&"row":
			phase_zero = Vector3i(-1, 0, 0)
		&"building":
			phase_zero = Vector3i(-1, 0, 1)
		&"long":
			phase_zero = Vector3i(-1, 0, 2)
		_:
			return -1
	for phase in 2:
		var local_door := phase_zero + Vector3i.LEFT * phase
		if FabricRecipe.transform_cell(local_door, origin, yaw_quarters) \
				== threshold:
			return phase
	return -1


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
		parcel.frontage_direction, parcel.address_door_phase,
		parcel.flat_roof)
	if not parcel.support_parent_parcel_id.is_empty() \
			and not preview.set_building_support(
				parcel.support_parent_parcel_id,
				parcel.support_parent_storey_index):
		return invalid
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
	if parcel.width_cells == 2 and parcel.depth_cells == 1:
		return {
			"kind": &"row",
			"minimum": Vector3i(-2, 0, -1),
			"size": Vector3i(4, 1, 2),
			"door_cell": Vector3i(-1 - parcel.address_door_phase, 0, 0),
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
	if parcel != null and not parcel.support_parent_parcel_id.is_empty():
		return parcel.base_band
	if parcel == null or parcel.source == null \
			or parcel.bearing_columns.size() != parcel.footprint.size():
		return parcel.base_band if parcel != null else 0
	# A MAZE PARCEL NEVER DESCENDS THROUGH ANOTHER PLOT (Task C5c ruling 4).
	#
	# Descent is a route-first idea: there, a parcel addressed from an upper
	# street is a short house on an abstract proof column unless it is rooted
	# at natural ground, and the mass it descends through is unclaimed massif.
	# In MAZE mode the mass under a plot is either derived rock -- which a
	# house may still take, and does, so a hill column becomes storeys rather
	# than a podium -- or ANOTHER PLOT, which is somebody else's building.
	#
	# Descending into that other plot made two parcels claim one cell in
	# `_partition_rooms`'s protected-owner map, and `_plate_fits` then refused
	# BOTH of them: measured as 9 of 29, 12 of 32 and 6 of 35 parcels composing
	# no lineage on the three sealing seeds, in mutually-blocking pairs, which
	# was the single largest source of unroomed plot mass.
	#
	# `rock_shoulder` is the source's own answer for the top of derived rock on
	# a column, and on a column carrying plots it IS that column's lowest plot
	# floor. So a parcel whose floor stands above it on any column has a plot
	# underneath and stays where the plot planner put it; a parcel sitting
	# directly on the rock descends exactly as it did before, which is what
	# keeps every rock-borne house in this corpus byte-identical.
	#
	# MEASURED AND REVERTED TWICE: NO DESCENT AT ALL. Returning `base_band`
	# for every maze parcel -- the plot model taken literally, so a house on a
	# hill column becomes a short house on a tall stone base rather than
	# storeys -- was better on C5c's number (12/compact 0.200 unroomed with 1
	# uncomposed parcel of 29, against 0.267 and 6) and cost 4/compact and
	# 3/standard their towns at PITCHED roof gates. Task C5d made maze houses
	# flat-roofed by default, removed those crowns, and re-applied it: on the
	# 24-seed maze sweep it went 10/24 sealed DOWN to 9/24, and 3/standard
	# lost its town again -- at `roof remainder for
	# spatial.parcel.maze.house.033 ... 1-cell exposed sliver`, a partial
	# plate, which is the one roof family flat-first does not remove because
	# no authored `roof.flat.*` module covers half a footprint. Reverted
	# again. What has to move first is the partial-plate vocabulary, not this
	# rule.
	var maze_source := parcel.source.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if maze_source != null:
		for column: Vector2i in parcel.footprint:
			if maze_source.rock_shoulder(column) < parcel.base_band:
				return parcel.base_band
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


static func touches_envelope_boundary(parcel: WarrenBuildingParcel) -> bool:
	## Perimeter is the buildable frontier of the same tapered 3D envelope the
	## parcel was cut from. An outer neighbor may still contain one or two low
	## bands of authored massif; that is hillside, not enough volume for another
	## complete roofed room at this address. Treating it as interior made the
	## visible edge audit vacuous even though the Gaussian correctly tapered.
	## This remains a volumetric capability test, not a radial band or a later
	## cosmetic ring.
	if parcel == null or parcel.source == null:
		return false
	var minimum_neighbor_top := parcel.base_band \
		+ WarrenBuildingParcel.STOREY_BANDS \
		+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS
	for column: Vector2i in parcel.footprint:
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
				Vector2i.UP, Vector2i.DOWN]:
			var neighbor := column + direction
			if not parcel.source.envelope.contains_column(neighbor) \
					or parcel.source.envelope.top_at(neighbor) \
						< minimum_neighbor_top:
				return true
	return false


static func has_perimeter_grounding(parcel: WarrenBuildingParcel) -> bool:
	## A boundary parcel either descends through its own complete room stack to
	## terrain, or names an explicit lower building parent. A mixed-span facade
	## hovering at an upper street datum is useful inside the maze but cannot be
	## the town's outer silhouette.
	if parcel == null or parcel.source == null:
		return false
	if not parcel.support_parent_parcel_id.is_empty():
		return true
	if parcel.bearing_columns.size() != parcel.footprint.size():
		return false
	var construction := proposal(parcel)
	if construction.is_empty():
		return false
	# THE PLOT MODEL'S LOAD PATH IS THE MOUNTAIN (Task C5c ruling 4). The test
	# below asks whether the parcel's own room stack descends to natural
	# ground, which is the right question when the mass under a boundary house
	# is unclaimed massif the stack may take. In MAZE mode it is not: it is the
	# plot below, or the derived rock the source retains and Task C5 renders as
	# stone, and `_support_base_band` deliberately refuses to descend through
	# either. What remains to prove is the continuity of that mass, and the
	# `bearing_columns == footprint` test above has already proved it for every
	# column -- including a column bearing on a tunnel roof.
	if parcel.source.mass_context.has(&"maze_source_plan"):
		return true
	var highest_ground := -2147483648
	for column: Vector2i in parcel.footprint:
		highest_ground = maxi(highest_ground,
			parcel.source.envelope.bearing_at(column))
	return (construction.origin as Vector3i).y - highest_ground \
		<= parcel.source.envelope.plinth_budget_bands


static func perimeter_gateway_support(parcel: WarrenBuildingParcel) \
		-> Dictionary:
	## One deliberately narrow exception to direct terrain bearing: a 3 x 6 m
	## frontier house may cantilever its second 3 m bay over an already-authored
	## public passage when its first bay has a complete terrain load path.  This
	## is the hill-town gateway motif, not permission for an elevated edge row.
	## The returned bearing seam is consumed by the fine-grid feature transaction
	## and realized as a measured two-bracket course beneath the room.
	if parcel == null or parcel.source == null \
			or not touches_envelope_boundary(parcel) \
			or parcel.support_mode != &"mixed_span" \
			or not parcel.support_parent_parcel_id.is_empty() \
			or parcel.width_cells != 1 or parcel.depth_cells != 2 \
			or parcel.footprint.size() != 2 or parcel.bearing_columns.size() != 1 \
			or not parcel.has_occupied_overpass:
		return {}
	var bearing := parcel.bearing_columns[0]
	var unsupported := parcel.footprint[0] if parcel.footprint[1] == bearing \
		else parcel.footprint[1]
	var direction := unsupported - bearing
	if absi(direction.x) + absi(direction.y) != 1:
		return {}
	# The unsupported bay must cover the real route, not merely a random hole in
	# the source massif.  Its lower public floor and swept headroom are immutable
	# source-plan facts, so the bracket contract can never manufacture a tunnel.
	var route_y := -2147483648
	for walk: Vector3i in parcel.source.walk_cells:
		if Vector2i(walk.x, walk.z) == unsupported \
				and parcel.base_band - walk.y >= WarrenVolumePlan.HEADROOM_BANDS:
			route_y = maxi(route_y, walk.y)
	if route_y == -2147483648:
		return {}
	return {
		"parcel_id": parcel.stable_id,
		"bearing_column": bearing,
		"unsupported_column": unsupported,
		"projection_direction": direction,
		"base_band": parcel.base_band,
		"route_band": route_y,
	}


static func has_perimeter_load_path(parcel: WarrenBuildingParcel) -> bool:
	return has_perimeter_grounding(parcel) \
		or not perimeter_gateway_support(parcel).is_empty()


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
