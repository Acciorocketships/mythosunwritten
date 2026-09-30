class_name BuildingKitAssembler
extends RefCounted

## Realizes a pack-agnostic `BuildingMass` with one `BuildingKit`.
##
## Pure and worker-safe: returns plain placement dictionaries in the kit's
## NATIVE building-local metres (x/z = module cell * module_width, y = band *
## band_height). The caller maps them into its frame. The assembler never
## chooses architecture; every decision lives in the mass.

var kit: BuildingKit
## Optional Callable(cell: Vector2i, band: int) -> bool: true when a cell
## outside this mass is already solid (a neighbouring building), so a wall
## facing it would be sandwiched and is omitted.
var external_blocked: Callable = Callable()
## Native scale of player-sized props (doorstep clutter, deck pots) inside
## this kit's frame; the production adapters keep them at their pre-upscale
## world size (`VillageWorldScale.kit_human_prop_scale`).
var prop_scale := 1.0


func _init(p_kit: BuildingKit) -> void:
	kit = p_kit


func assemble(mass: BuildingMass) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ctx := {"mass": mass, "out": out, "serial": 0}
	for index in mass.storeys.size():
		_assemble_storey(ctx, index)
	for wing: Dictionary in mass.roofs:
		var start := out.size()
		_assemble_roof(ctx, wing)
		for i in range(start, out.size()):
			out[i]["roof_index"] = int(wing.get("union_index", -1))
		_assemble_attic_ceiling(ctx, wing)
	for deck: Dictionary in mass.decks:
		_assemble_deck(ctx, deck)
	for item: Dictionary in mass.decor:
		_assemble_decor(ctx, item)
	return out


## Maps native placements into an EnvironmentInstancePayload. `native_to_frame`
## is the affine map from native building metres into the payload frame (it
## may be anisotropic; see `VillageWorldScale`).
static func append_to_payload(placements: Array[Dictionary],
		native_to_frame: Transform3D, payload: EnvironmentInstancePayload,
		color := Color.WHITE) -> void:
	for placement: Dictionary in placements:
		payload.add(placement.asset_id,
			native_to_frame * (placement.transform as Transform3D),
			placement.get("color", color), placement.stable_id,
			bool(placement.get("collision", true)))


# --- geometry helpers -------------------------------------------------------

static func yaw_for_dir(dir: int) -> float:
	# Outward +X, +Z, -X, -Z; a piece's native +Z faces outward.
	match dir:
		0: return PI * 0.5
		1: return 0.0
		2: return PI * 1.5
		_: return PI


## Native +X of a piece facing `dir` (its right, seen from outside).
static func right_of(dir: int) -> Vector2i:
	match dir:
		0: return Vector2i(0, -1)
		1: return Vector2i(1, 0)
		2: return Vector2i(0, 1)
		_: return Vector2i(-1, 0)


func _emit(ctx: Dictionary, role: StringName, position_cells: Vector2,
		y: float, yaw: float, pick := 0, extra := Transform3D.IDENTITY,
		color := Color.WHITE) -> void:
	if not kit.has_role(role):
		return
	var w := kit.module_width
	var basis := Basis(Vector3.UP, yaw)
	var asset_id := kit.asset(role, pick)
	var t := Transform3D(basis, Vector3(position_cells.x * w, y,
		position_cells.y * w)) * extra * kit.anchor(role) * kit.asset_anchor(asset_id)
	var serial := int(ctx.serial)
	ctx.serial = serial + 1
	(ctx.out as Array).append({
		"asset_id": asset_id, "transform": t, "role": role,
		"stable_id": StringName("%s/k%04d" % [(ctx.mass as BuildingMass).stable_id, serial]),
		"color": color,
	})


func _hash(mass: BuildingMass, a: int, b := 0, c := 0) -> int:
	var h := hash([mass.seed, a, b, c])
	return absi(h)


# --- walls ----------------------------------------------------------------

## Boundary runs of a cell set: {dir, line, start, end, start_convex,
## end_convex, exposed}. `line` is the face coordinate (x for dirs 0/2, z for
## 1/3) on the cell-edge lattice; `start..end` runs along the other axis in
## increasing order. With `exposed` (Callable(edge: Vector3i) -> bool) runs
## also split where exposure changes.
static func boundary_runs(cells: Dictionary,
		exposed: Callable = Callable()) -> Array[Dictionary]:
	var buckets: Dictionary = {}
	for cell: Vector2i in cells:
		for dir in 4:
			if cells.has(cell + BuildingMass.DIRS[dir]):
				continue
			var line: int
			var along: int
			match dir:
				0: line = cell.x + 1; along = cell.y
				1: line = cell.y + 1; along = cell.x
				2: line = cell.x; along = cell.y
				_: line = cell.y; along = cell.x
			var key := Vector2i(dir, line)
			if not buckets.has(key):
				buckets[key] = []
			(buckets[key] as Array).append(along)
	var runs: Array[Dictionary] = []
	var keys := buckets.keys()
	keys.sort()
	for key: Vector2i in keys:
		var values: Array = buckets[key]
		values.sort()
		var start := int(values[0])
		var previous := start
		var state := _edge_exposed(exposed, key.x, key.y, start)
		for i in range(1, values.size() + 1):
			var value := int(values[i]) if i < values.size() else 1000000000
			var next_state := _edge_exposed(exposed, key.x, key.y, value) \
				if i < values.size() else state
			if value == previous + 1 and next_state == state:
				previous = value
				continue
			var run := _run(cells, key.x, key.y, start, previous + 1)
			run.exposed = state
			runs.append(run)
			start = value
			previous = value
			state = next_state
	return runs


static func _edge_exposed(exposed: Callable, dir: int, line: int, along: int) -> bool:
	if not exposed.is_valid():
		return true
	return bool(exposed.call(BuildingMass.edge_key(_inside_cell(dir, line, along), dir)))


static func _inside_cell(dir: int, line: int, along: int) -> Vector2i:
	match dir:
		0: return Vector2i(line - 1, along)
		1: return Vector2i(along, line - 1)
		2: return Vector2i(line, along)
		_: return Vector2i(along, line)


static func _run(cells: Dictionary, dir: int, line: int, start: int,
		end: int) -> Dictionary:
	# A run end is convex when the inside cell just beyond it is empty, and
	# concave when the face turns outward there (the cell beyond and outside
	# it is part of the footprint).
	var out := BuildingMass.DIRS[dir]
	return {
		"dir": dir, "line": line, "start": start, "end": end,
		"start_convex": not cells.has(_inside_cell(dir, line, start - 1)),
		"end_convex": not cells.has(_inside_cell(dir, line, end)),
		"start_concave": cells.has(_inside_cell(dir, line, start - 1)) \
			and cells.has(_inside_cell(dir, line, start - 1) + out),
		"end_concave": cells.has(_inside_cell(dir, line, end)) \
			and cells.has(_inside_cell(dir, line, end) + out),
		"exposed": true,
	}


static func _run_point(run: Dictionary, at_end: bool) -> Vector2i:
	var along := int(run.end) if at_end else int(run.start)
	var dir := int(run.dir)
	return Vector2i(int(run.line), along) if dir == 0 or dir == 2 \
		else Vector2i(along, int(run.line))


## Wall slots of a storey: each {centre: Vector2 (cells), dir, edge: Vector3i,
## left_convex, right_convex, outside: Array[Vector2i], inset: bool}. With
## `inset`, only EXPOSED runs step half a module inside (a jetty never opens a
## slot against a neighbour); each run end follows the perpendicular run's
## inset so the wall ring stays closed.
static func wall_slots(cells: Dictionary, inset: bool,
		exposed: Callable = Callable()) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var runs := boundary_runs(cells, exposed)
	var shift_of: Dictionary = {}
	var by_point: Dictionary = {}
	for run: Dictionary in runs:
		run.shift = 0.5 if inset and bool(run.exposed) else 0.0
		for at_end in [false, true]:
			var point := _run_point(run, at_end)
			if not by_point.has(point):
				by_point[point] = []
			(by_point[point] as Array).append(run)
	for run: Dictionary in runs:
		var dir := int(run.dir)
		var axis := dir % 2
		var ends := [0.0, 0.0]
		for e in 2:
			for other: Dictionary in by_point.get(_run_point(run, e == 1), []):
				if other != run and int(other.dir) % 2 != axis:
					ends[e] = float(other.shift)
		var start := float(run.start)
		var end := float(run.end)
		start += ends[0] if run.start_convex else -ends[0]
		end += -ends[1] if run.end_convex else ends[1]
		var count := int(round(end - start))
		if count <= 0:
			continue
		var inward := -1.0 if dir == 0 or dir == 1 else 1.0
		var line := float(run.line) + inward * float(run.shift)
		for k in count:
			var along := start + 0.5 + float(k)
			var centre := Vector2(line, along) if dir == 0 or dir == 2 \
				else Vector2(along, line)
			var edge_along := clampi(int(floor(along)), int(run.start),
				int(run.end) - 1)
			var inside := _inside_cell(dir, int(run.line), edge_along)
			var outside: Array[Vector2i] = []
			for probe: float in [along - 0.25, along + 0.25]:
				var a := clampi(int(floor(probe)), int(run.start), int(run.end) - 1)
				var cell := _inside_cell(dir, int(run.line), a) + BuildingMass.DIRS[dir]
				if not outside.has(cell):
					outside.append(cell)
			# Which slot end is the run's start depends on the facing: a
			# piece's right (+X native) points along +along for dirs 1 and 2.
			var right_is_forward := dir == 1 or dir == 2
			var start_corner := k == 0 and bool(run.start_convex)
			var end_corner := k == count - 1 and bool(run.end_convex)
			var start_inner := k == 0 and bool(run.start_concave)
			var end_inner := k == count - 1 and bool(run.end_concave)
			slots.append({
				"centre": centre, "dir": dir,
				"edge": BuildingMass.edge_key(inside, dir),
				"right_convex": end_corner if right_is_forward else start_corner,
				"left_convex": start_corner if right_is_forward else end_corner,
				"right_concave": end_inner if right_is_forward else start_inner,
				"outside": outside, "index": k, "count": count,
				"inset": float(run.shift) > 0.0,
			})
	return slots


func _slot_exposed(mass: BuildingMass, slot: Dictionary, floor_band: int,
		bands := 2) -> bool:
	for band in range(floor_band, floor_band + bands):
		var own := mass.cells_at_band(band)
		var covered := true
		for cell: Vector2i in slot.outside:
			var solid := own.has(cell)
			if not solid and external_blocked.is_valid():
				solid = bool(external_blocked.call(cell, band))
			covered = covered and solid
		if not covered:
			return true
	return false


## Callable(edge) -> bool: the cell beyond this storey edge is open at
## either of its bands (party edges against solid neighbours are not).
func _edge_exposure(mass: BuildingMass, floor_band: int, bands: int) -> Callable:
	return exposure_for(mass, floor_band, bands, external_blocked)


## Shared by the designer and assembler so both see the same wall slots.
static func exposure_for(mass: BuildingMass, floor_band: int, bands: int,
		blocked: Callable) -> Callable:
	return func(edge: Vector3i) -> bool:
		var outside := Vector2i(edge.x, edge.y) + BuildingMass.DIRS[edge.z]
		for band in range(floor_band, floor_band + bands):
			var solid := mass.cells_at_band(band).has(outside)
			if not solid and blocked.is_valid():
				solid = bool(blocked.call(outside, band))
			if not solid:
				return true
		return false


func _storey_below(mass: BuildingMass, index: int) -> Dictionary:
	var floor := int(mass.storeys[index].floor_band)
	for other: Dictionary in mass.storeys:
		if int(other.floor_band) + 2 == floor:
			return other
	return {}


func _assemble_storey(ctx: Dictionary, index: int) -> void:
	var mass: BuildingMass = ctx.mass
	var storey: Dictionary = mass.storeys[index]
	var floor_band := int(storey.floor_band)
	var y := float(floor_band) * kit.band_height()
	var material := StringName(storey.material)
	var inset := bool(storey.inset)
	var below := _storey_below(mass, index)
	var below_inset: Dictionary = {}
	if not below.is_empty() and bool(below.get("inset", false)):
		# Every cell edge of an inset (exposed) run below carries the jetty.
		for run: Dictionary in boundary_runs(below.cells,
				_edge_exposure(mass, int(below.floor_band), int(below.get("bands", 2)))):
			if bool(run.exposed):
				for along in range(int(run.start), int(run.end)):
					below_inset[BuildingMass.edge_key(_inside_cell(int(run.dir),
						int(run.line), along), int(run.dir))] = true
	if bool(storey.get("fortified", false)) and kit.has_role(&"wall.fort"):
		_assemble_fortified(ctx, storey)
		return
	var openings: Dictionary = storey.openings
	var plain_every := int(storey.get("plain_every", 0))
	if floor_band > mass.ground_band or bool(storey.get("soffit", false)):
		_assemble_soffit(ctx, storey, y)
	var bands := int(storey.get("bands", 2))
	var tint := storey.get("tint", Color.WHITE) as Color
	var retaining := bool(storey.get("retaining", false))
	var pent_colour := StringName(storey.get("pent_colour", &""))
	var pent_slots: Dictionary = {}
	var above_openings: Dictionary = {}
	for other: Dictionary in mass.storeys:
		if int(other.floor_band) == floor_band + bands:
			above_openings = other.openings
	for slot: Dictionary in wall_slots(storey.cells, inset,
			_edge_exposure(mass, floor_band, bands)):
		var jettied := below_inset.has(slot.edge)
		if not _slot_exposed(mass, slot, floor_band, bands):
			continue
		if bands == 1:
			var sunk := bool(storey.get("sunk", false)) and kit.has_role(&"wall.stone.retaining")
			if sunk:
				# Standing on the ground: a full storey panel whose lower band
				# is buried, so the course keeps the storeys' masonry.
				_emit(ctx, &"wall.stone.retaining", slot.centre as Vector2,
					y - kit.band_height(), yaw_for_dir(int(slot.dir)))
				_emit_corner_post(ctx, slot, y - kit.band_height(), 2, kit.wall_face)
			else:
				_emit(ctx, &"wall.stone.course", slot.centre as Vector2, y,
					yaw_for_dir(int(slot.dir)))
				_emit_corner_post(ctx, slot, y, 1, kit.wall_face)
			continue
		var dir := int(slot.dir)
		var yaw := yaw_for_dir(dir)
		var centre := slot.centre as Vector2
		var kind := StringName(openings.get(slot.edge, storey.default_opening))
		if kind == BuildingMass.OPENING_NONE:
			continue
		var pick := _hash(mass, index, int(centre.x * 2.0), int(centre.y * 2.0))
		if kind == BuildingMass.OPENING_WINDOW and plain_every > 0 \
				and pick % plain_every == 0:
			kind = BuildingMass.OPENING_PLAIN
		if kind == BuildingMass.OPENING_BAY:
			var colour := StringName(storey.get("bay_colour", &"red"))
			var bay_role := StringName("bay.%s" % colour)
			if kit.has_role(bay_role):
				_emit(ctx, bay_role, centre, y + kit.band_height() * 2.0 / 3.0, yaw, pick)
				_emit_jetty_trim(ctx, slot, y, yaw, jettied, pick)
				continue
			kind = BuildingMass.OPENING_WINDOW
		var role := StringName("wall.%s.%s" % [material, kind])
		if retaining and kit.has_role(StringName("wall.%s.retaining" % material)):
			# Retaining faces (terrace skins) stay flush with the lawn above.
			role = StringName("wall.%s.retaining" % material)
		if not kit.has_role(role):
			role = StringName("wall.%s.window" % material)
		_emit(ctx, role, centre, y, yaw, pick, Transform3D.IDENTITY, tint)
		_emit_corner_post(ctx, slot, y, bands, kit.face_of(material, retaining))
		if pent_colour != &"" and _covered_above(mass, slot, floor_band + bands) \
				and StringName(above_openings.get(slot.edge, &"")) != BuildingMass.OPENING_BAY:
			pent_slots[centre] = slot
		if bool(storey.plinth) and not _solid_below(mass, slot, floor_band):
			_emit(ctx, &"plinth.stone", centre, y - kit.plinth_height, yaw, pick)
		_emit_jetty_trim(ctx, slot, y, yaw, jettied, pick)
	_emit_pent_eaves(ctx, pent_slots, pent_colour, y + float(bands) * kit.band_height())


## Two wall panels meeting at a convex corner each end at their own module:
## the top beams stop short of one another and the edge posts stand side by
## side, leaving a stepped notch. The slot owning the corner at its right end
## (exactly one per corner) closes it with one post flush with both outer
## faces, rising to the panels' top beam.
## `face` is the panels' outer-face distance: a deep masonry storey closes
## its thicker corner with a post grown to cover both faces.
func _emit_corner_post(ctx: Dictionary, slot: Dictionary, y: float, bands: int,
		face: float) -> void:
	# Deep masonry also leaves the square [0, face]^2 open at an inner corner
	# (both panels stop at the corner line); the same post fills it.
	var inner := bool(slot.get("right_concave", false)) and face > kit.wall_face + 0.001
	if not (bool(slot.right_convex) or inner) or kit.corner_post_half <= 0.0:
		return
	var dir := int(slot.dir)
	var out := Vector2(BuildingMass.DIRS[dir])
	var right := Vector2(right_of(dir))
	# The post covers the corner square [0, face] of both faces.
	var half := maxf(kit.corner_post_half, face * 0.5 + 0.02)
	var inset := (face - half) / kit.module_width
	var at := (slot.centre as Vector2) + right * 0.5 + (out + right) * inset
	var height := float(bands) * kit.band_height() + (0.074 if bands >= 2 else 0.0)
	var girth := half / kit.corner_post_half
	_emit(ctx, &"post.timber", at, y, yaw_for_dir(dir), 0,
		Transform3D(Basis.from_scale(Vector3(girth, height, girth)), Vector3.ZERO))


## A pent eave course runs along consecutive slots of one face; lone slots are
## dropped and every open end is closed with a barge board.
func _emit_pent_eaves(ctx: Dictionary, slots: Dictionary, colour: StringName,
		y: float) -> void:
	for centre: Vector2 in slots:
		var slot: Dictionary = slots[centre]
		var dir := int(slot.dir)
		var right := Vector2(right_of(dir))
		var has_left := slots.has(centre - right)
		var has_right := slots.has(centre + right)
		if not has_left and not has_right:
			continue
		var yaw := yaw_for_dir(dir)
		_emit(ctx, StringName("roof.%s.eave" % colour), centre, y, yaw)
		if not has_left:
			_emit(ctx, &"trim.barge.eave", centre - right * 0.5, y, yaw - PI * 0.5)
		if not has_right:
			_emit(ctx, &"trim.barge.eave", centre + right * 0.5, y, yaw - PI * 0.5)


## Boards close the underside of cells that overhang empty space (bridge
## rooms, cantilevers); cells standing on anything solid need none.
func _assemble_soffit(ctx: Dictionary, storey: Dictionary, y: float) -> void:
	var mass: BuildingMass = ctx.mass
	var floor_band := int(storey.floor_band)
	var below := mass.cells_at_band(floor_band - 1)
	# A storey at the house datum hangs over air only where its adapter says so
	# (`soffit_cells`: a bridge-house over a lane); elsewhere it stands.
	var datum := floor_band <= mass.ground_band
	var overhang: Dictionary = storey.get("soffit_cells", {})
	var boarded: Dictionary = {}
	# Cells of a compound's member standing on its own (higher) ground.
	var grounded: Dictionary = storey.get("grounded", {})
	for cell: Vector2i in storey.cells:
		if below.has(cell) or grounded.has(cell):
			continue
		if external_blocked.is_valid() and bool(external_blocked.call(cell, floor_band - 1)):
			continue
		if datum and not overhang.is_empty() and not overhang.has(cell):
			continue
		boarded[cell] = true
		_emit(ctx, &"deck.board", Vector2(cell) + Vector2(0.5, 0.5), y, 0.0)

	if datum and overhang.is_empty(): return
	# Every overhanging rim needs the same continuous timber edge as jetties
	# (and only the actual exposed rim: no internal grid seams). Without it the
	# wall panels' plaster bottoms met the boards' outer edge in one plane and
	# flickered along a bridge-house's underside (September 29 photo 8).
	for slot: Dictionary in wall_slots(storey.cells, false):
		if not boarded.has(Vector2i(slot.edge.x, slot.edge.y)): continue
		if not _slot_exposed(mass, slot, floor_band, 2): continue
		var role := &"trim.floor_beam_corner" if slot.left_convex else &"trim.floor_beam"
		_emit(ctx, role, slot.centre, y, yaw_for_dir(slot.dir))


## Roof over free air (a loggia recessed into the top storey, a porch) would
## open the hollow attic to the street: roof boards, gable walls from behind,
## a chimney base. Boards close it at the eave, as the floor of a storey above
## closes a lower loggia (September 29 photo 9, "no roof").
func _assemble_attic_ceiling(ctx: Dictionary, wing: Dictionary) -> void:
	var mass: BuildingMass = ctx.mass
	var eave := int(wing.eave_band)
	var below := mass.cells_at_band(eave - 1)
	var level := mass.cells_at_band(eave)
	for cell: Vector2i in BuildingMass.rect_cells(wing.rect as Rect2i):
		if below.has(cell) or level.has(cell):
			continue
		if external_blocked.is_valid() and bool(external_blocked.call(cell, eave - 1)):
			continue
		_emit(ctx, &"deck.board", Vector2(cell) + Vector2(0.5, 0.5),
			float(eave) * kit.band_height(), 0.0)


## True when a storey (this building or another) stands directly under the
## slot: a plinth there would band the top of that wall instead of meeting
## the ground.
func _solid_below(mass: BuildingMass, slot: Dictionary, floor_band: int) -> bool:
	var inside := Vector2i(slot.edge.x, slot.edge.y)
	if mass.cells_at_band(floor_band - 1).has(inside):
		return true
	return external_blocked.is_valid() and bool(external_blocked.call(inside, floor_band - 1))


## True when the wall above this slot's inside cell is flush with it: the
## cell above is solid (this building or another) and the slot's outside above
## is open, so a pent eave at the storey line reads as a skirt roof.
func _covered_above(mass: BuildingMass, slot: Dictionary, band: int) -> bool:
	var inside := Vector2i(slot.edge.x, slot.edge.y)
	var above := mass.cells_at_band(band)
	var solid := above.has(inside)
	if not solid and external_blocked.is_valid():
		solid = bool(external_blocked.call(inside, band))
	if not solid:
		return false
	for cell: Vector2i in slot.outside:
		if above.has(cell):
			return false
		if external_blocked.is_valid() and bool(external_blocked.call(cell, band)):
			return false
	return true


func _emit_jetty_trim(ctx: Dictionary, slot: Dictionary, y: float, yaw: float,
		jettied: bool, pick: int) -> void:
	if not jettied:
		return
	var centre := slot.centre as Vector2
	var dir := int(slot.dir)
	var inward := -Vector2(BuildingMass.DIRS[dir]) * 0.5
	# The floor beam closes the jetty line; its corner variant carries the
	# return around the convex corner at the slot's native -X (left) end.
	var beam_role := &"trim.floor_beam_corner" if bool(slot.left_convex) \
		else &"trim.floor_beam"
	_emit(ctx, beam_role, centre, y, yaw, pick)
	_emit(ctx, &"bracket.jetty", centre + inward, y - kit.jetty_depth, yaw, pick)


# --- roofs ----------------------------------------------------------------

func _assemble_roof(ctx: Dictionary, wing: Dictionary) -> void:
	var mass: BuildingMass = ctx.mass
	var rect := wing.rect as Rect2i
	var axis := int(wing.axis)
	var colour := StringName(wing.colour)
	var eave_y := float(int(wing.eave_band)) * kit.band_height()
	# Local frame: `u` runs along the ridge, `v` across it.
	var u0 := rect.position.x if axis == 0 else rect.position.y
	var u1 := rect.end.x if axis == 0 else rect.end.y
	var v0 := rect.position.y if axis == 0 else rect.position.x
	var v1 := rect.end.y if axis == 0 else rect.end.x
	var depth := v1 - v0
	var profile := kit.roof_profile(depth)
	var rows := int(profile.rows)
	var p_min := u0 - int(wing.extend_min)
	var p_max := u1 + int(wing.extend_max)
	var dormers: Dictionary = wing.dormers
	# Sides: 0 = +v face, 1 = -v face.
	for side in 2:
		var dir := (1 if axis == 0 else 0) if side == 0 else (3 if axis == 0 else 2)
		var yaw := yaw_for_dir(dir)
		for k in rows:
			var line := float(v1 - k) if side == 0 else float(v0 + k)
			var y := eave_y + float(k) * kit.roof_row_rise
			for p in range(p_min, p_max + 1):
				var role := StringName("roof.%s.slope" % colour)
				if k == 0:
					role = StringName("roof.%s.eave" % colour)
					if dormers.has(Vector2i(side, p)):
						role = StringName("roof.%s.eave_dormer" % colour)
				_emit(ctx, role, _uv(axis, float(p), line), y, yaw,
					_hash(mass, p, k, side))
	if bool(profile.top):
		var top_y := eave_y + float(rows) * kit.roof_row_rise
		var mid := float(v0 + v1) * 0.5
		for p in range(p_min, p_max + 1):
			_emit(ctx, StringName("roof.%s.top" % colour), _uv(axis, float(p), mid),
				top_y, 0.0 if axis == 0 else PI * 0.5)
	_assemble_ridge(ctx, wing, axis, float(v0 + v1) * 0.5, eave_y, profile,
		p_min, p_max)
	if bool(wing.get("chimney", false)) and u1 - u0 >= 3:
		# A rubble stack straddling the ridge one module in from a gable:
		# blocks rise from inside the roof to clear the ridge, then the top.
		var at_u := float(u1 - 1) if int(wing.get("chimney_end", 1)) == 1 else float(u0 + 1)
		var at_v := float(v0 + v1) * 0.5
		var ridge := eave_y + float(profile.height)
		var chimney_yaw := 0.0 if axis == 0 else PI * 0.5
		var top := ridge + 1.1
		var y := ridge - 1.6
		while y + 1.0 < top:
			_emit(ctx, &"chimney.course", _uv(axis, at_u, at_v), y, chimney_yaw)
			y += 1.0
		_emit(ctx, &"chimney.cap", _uv(axis, at_u, at_v), y, chimney_yaw)
	for end in 2:
		if bool(wing.open_min if end == 0 else wing.open_max):
			continue
		_assemble_gable(ctx, axis, end, u0 if end == 0 else u1, v0, v1,
			eave_y, profile)


func _uv(axis: int, u: float, v: float) -> Vector2:
	return Vector2(u, v) if axis == 0 else Vector2(v, u)


func _assemble_ridge(ctx: Dictionary, wing: Dictionary, axis: int, mid: float,
		eave_y: float, profile: Dictionary, p_min: int, p_max: int) -> void:
	var ridge_y := eave_y + float(profile.height)
	ridge_y += 0.19 if bool(profile.top) else 0.3
	var yaw := 0.0 if axis == 0 else PI * 1.5
	for p in range(p_min, p_max + 1):
		_emit(ctx, &"trim.ridge", _uv(axis, float(p), mid), ridge_y, yaw)
		if bool(wing.ridge_peaks) and p > p_min and p < p_max:
			_emit(ctx, &"trim.ridge_peak", _uv(axis, float(p), mid), ridge_y, yaw)


func _assemble_gable(ctx: Dictionary, axis: int, end: int, u: int, v0: int,
		v1: int, eave_y: float, profile: Dictionary) -> void:
	var mass: BuildingMass = ctx.mass
	# Gable faces outward along the ridge axis.
	var dir := (0 if axis == 0 else 1) if end == 1 else (2 if axis == 0 else 3)
	var yaw := yaw_for_dir(dir)
	var right := right_of(dir)
	var right_sign := right.y if axis == 0 else right.x
	var rows := int(profile.rows)
	for k in rows:
		var lo := v0 + k
		var hi := v1 - k
		var y := eave_y + float(k) * kit.roof_row_rise
		for v in range(lo, hi):
			var centre := float(v) + 0.5
			var role := &"gable.wall"
			var low_end := v == lo
			var high_end := v == hi - 1
			if low_end or high_end:
				# The +v outermost piece is on the viewer's right when the
				# gable's native +X points along +v.
				var is_right := (high_end and right_sign > 0) or (low_end and right_sign < 0)
				role = &"gable.right" if is_right else &"gable.left"
			_emit(ctx, role, _uv(axis, float(u), centre), y, yaw,
				_hash(mass, u, v, k))
	if bool(profile.top):
		var top_y := eave_y + float(rows) * kit.roof_row_rise
		_emit(ctx, &"gable.small", _uv(axis, float(u), float(v0 + v1) * 0.5),
			top_y, yaw)
	# Barge boards one half module beyond the gable wall.
	var outward := 0.5 if end == 1 else -0.5
	for side in 2:
		var row_dir := (1 if axis == 0 else 0) if side == 0 else (3 if axis == 0 else 2)
		var board_yaw := yaw_for_dir(row_dir) - PI * 0.5
		for k in rows:
			var line := float(v1 - k) if side == 0 else float(v0 + k)
			var y := eave_y + float(k) * kit.roof_row_rise
			var role := &"trim.barge.eave" if k == 0 else &"trim.barge.slope"
			_emit(ctx, role, _uv(axis, float(u) + outward, line), y, board_yaw)
	if bool(profile.top):
		var top_y := eave_y + float(rows) * kit.roof_row_rise + 1.0
		var top_yaw := yaw_for_dir((1 if axis == 0 else 0)) - PI * 0.5
		_emit(ctx, &"trim.barge.top", _uv(axis, float(u) + outward,
			float(v0 + v1) * 0.5), top_y, top_yaw)


# --- decks and dressing ------------------------------------------------------

## Height/depth fit of the canonical awning under one storey line.
static func awning_fit(p_kit: BuildingKit) -> float:
	return (p_kit.storey_height - 0.2) / p_kit.awning_height \
		if p_kit.awning_height > 0.0 else 1.0


## Plan footprint (module cells) of an awning decor item: exactly what the
## assembler builds, so designers can reserve the ground its posts stand on.
static func awning_footprint(p_kit: BuildingKit, item: Dictionary) -> Rect2:
	var dir := int(item.dir)
	var out := Vector2(BuildingMass.DIRS[dir])
	var right := Vector2(right_of(dir))
	var centre := item.centre as Vector2
	var near := (p_kit.wall_face + float(item.get("proud", 0.0))) / p_kit.module_width
	var far := near + p_kit.awning_depth * awning_fit(p_kit) / p_kit.module_width
	var half := p_kit.awning_width * 0.5
	var a := centre - right * half + out * near
	var b := centre + right * half + out * far
	return Rect2(a.min(b), (a - b).abs())

func _assemble_deck(ctx: Dictionary, deck: Dictionary) -> void:
	var y := float(int(deck.band)) * kit.band_height()
	var cells: Dictionary = deck.cells
	for cell: Vector2i in cells:
		_emit(ctx, &"deck.board", Vector2(cell) + Vector2(0.5, 0.5), y, 0.0)
	if not bool(deck.get("rails", true)):
		return
	var open_edges: Dictionary = deck.get("open_edges", {})
	for slot: Dictionary in wall_slots(cells, false):
		if open_edges.has(slot.edge):
			continue
		var blocked := external_blocked.is_valid()
		if blocked:
			for cell: Vector2i in slot.outside:
				blocked = blocked and bool(external_blocked.call(cell, int(deck.band)))
		if blocked:
			continue
		var dir := int(slot.dir)
		var centre := slot.centre as Vector2
		# Rails run along native +X from their pivot: two 1 m rails per module.
		var right := Vector2(right_of(dir))
		var start := centre - right * 0.5
		_emit(ctx, &"rail.low", start, y, yaw_for_dir(dir))
		_emit(ctx, &"rail.low", start + right * 0.5, y, yaw_for_dir(dir))
		if bool(slot.right_convex):
			_emit(ctx, &"rail.post", start + right, y, yaw_for_dir(dir))


func _assemble_decor(ctx: Dictionary, item: Dictionary) -> void:
	var mass: BuildingMass = ctx.mass
	var kind := StringName(item.kind)
	var centre := item.centre as Vector2
	var dir := int(item.dir)
	var yaw := yaw_for_dir(dir)
	var y := float(item.get("y", 0.0))
	if item.has("y_band"):
		y = float(int(item.y_band)) * kit.band_height()
	var pick := _hash(mass, int(centre.x * 4.0), int(centre.y * 4.0), dir)
	var out := Vector2(BuildingMass.DIRS[dir])
	var w := kit.module_width
	# Items on a deep masonry storey stand on its (prouder) outer face.
	var proud := float(item.get("proud", 0.0)) / w
	match kind:
		&"awning":
			# One module wide (the role anchor), fitted under the storey line,
			# its back posts on the wall's outer face.
			var fit := awning_fit(kit)
			_emit(ctx, &"awning", centre + out * (kit.wall_face / w + proud), y, yaw, pick,
				Transform3D(Basis.from_scale(Vector3(1.0, fit, fit)), Vector3.ZERO))
		&"window_box":
			_emit(ctx, &"window_box", centre + out * (0.17 / w), y + 0.75, yaw, pick)
		&"ivy_corner":
			# Seated at the corner of the slot's right end (pack placement:
			# 0.08 m proud of the face, 0.12 m past the corner).
			var right := Vector2(right_of(dir))
			_emit(ctx, &"ivy.corner", centre + right * (0.5 + 0.12 / w + proud) \
				+ out * (0.08 / w + proud), y, yaw, pick)
		&"ivy":
			_emit(ctx, &"ivy.wall", centre + out * (0.14 / w + proud), y, yaw, pick)
		&"doorstep":
			# A few loose props against the wall beside the door; visual only
			# so they never narrow a walked lane.
			var right := Vector2(right_of(dir))
			for i in int(item.get("count", 1)):
				var along := float(item.get("side", 1.0)) * (0.36 + 0.2 * float(i))
				_emit(ctx, &"prop.doorstep", centre + right * along + out * (0.22 + 0.08 * float(i) + proud),
					y, yaw + float(i) * 0.7, pick + i * 7,
					Transform3D(Basis.from_scale(Vector3.ONE * prop_scale), Vector3.ZERO))
				(ctx.out as Array).back()["collision"] = false
		&"entry_stair":
			_emit(ctx, &"stair.entry", centre + out * (1.0 / w), y, yaw, pick)
		&"post":
			# A stone footing, then one timber post stretched to the soffit.
			var bottom := float(int(item.from_band)) * kit.band_height()
			var top := float(int(item.to_band)) * kit.band_height() - 0.1
			var footing := 1.0
			if top - bottom < footing + 0.2:
				return
			_emit(ctx, &"post.base", centre, bottom, yaw, pick)
			_emit(ctx, &"post.timber", centre, bottom + footing, yaw, pick,
				Transform3D(Basis.from_scale(Vector3(1.0, top - bottom - footing, 1.0))))
		&"frame_post":
			var bottom := float(int(item.from_band)) * kit.band_height()
			var top := float(int(item.to_band)) * kit.band_height()
			_emit(ctx, &"post.timber", centre, bottom, yaw, pick,
				Transform3D(Basis.from_scale(Vector3(1.2, top - bottom, 1.2))))
		&"raker":
			var from := item.from as Vector3
			var to := item.to as Vector3
			from *= Vector3(w, kit.band_height(), w)
			to *= Vector3(w, kit.band_height(), w)
			var delta := to - from
			if delta.length() < 0.05: return
			var basis := Basis(Quaternion(Vector3.UP, delta.normalized())).scaled(Vector3(0.8, delta.length(), 0.8))
			_emit(ctx, &"post.timber", Vector2(from.x, from.z) / w, from.y, 0.0, pick,
				Transform3D(basis, Vector3.ZERO))

		&"bracket":
			_emit(ctx, &"bracket.jetty", centre, y - kit.jetty_depth, yaw, pick)
		&"planter":
			_emit(ctx, &"prop.pot", centre, y + 0.13, yaw, pick,
				Transform3D(Basis.from_scale(Vector3.ONE * prop_scale), Vector3.ZERO))


# --- fortification (September 29, WarrenTownPlatform) ----------------------
# A raised district's plinth is a fortification, not a house's stone ground
# floor: continuous plain coursed stone (no timber frame, no corner posts),
# a battered foot course, stone piers at its convex corners rising into
# turrets, a crenellated parapet along every rim edge the upper town leaves
# open, and a stone-framed gate (two piers and a lintel) where the gate
# flight enters the district. Built from `wall.fort` alone.

## Native metres (the kit's own frame; the town frame scales them).
const FORT_PARAPET_HEIGHT := WarrenTownPlatform.PARAPET_HEIGHT
const FORT_MERLON_HEIGHT := 0.55
const FORT_MERLON_WIDTH := 0.55
const FORT_FOOT_HEIGHT := 0.9
const FORT_FOOT_DEPTH := 4.0
const FORT_PIER_SIZE := 0.7
const FORT_GATE_PIER_SIZE := 1.0
const FORT_TURRET_SIZE := 1.3
const FORT_TURRET_RISE := 1.5
const FORT_GATE_RISE := 5.8
const FORT_LINTEL_HEIGHT := 1.2
## The `wall.fort` panel's measured native size (Suntail plain stone wall).
const FORT_PANEL_HEIGHT := 3.0
const FORT_PANEL_DEPTH := 0.188
## A gate spans one macro street cell: two module cells.
const FORT_GATE_SPAN := 2


func _assemble_fortified(ctx: Dictionary, storey: Dictionary) -> void:
	var mass: BuildingMass = ctx.mass
	var floor_band := int(storey.floor_band)
	var bands := int(storey.get("bands", 2))
	var y := float(floor_band) * kit.band_height()
	var height := float(bands) * kit.band_height()
	var panel_height := _fort_panel_height()
	var top_band := floor_band + bands
	var above := mass.cells_at_band(top_band)
	var is_foot := floor_band <= mass.ground_band
	var gates: Dictionary = storey.get("gates", {})
	for slot: Dictionary in wall_slots(storey.cells, false,
			_edge_exposure(mass, floor_band, bands)):
		var dir := int(slot.dir)
		var yaw := yaw_for_dir(dir)
		var centre := slot.centre as Vector2
		var edge := slot.edge as Vector3i
		var inside := Vector2i(edge.x, edge.y)
		var exposed := _slot_exposed(mass, slot, floor_band, bands)
		if exposed:
			_emit(ctx, &"wall.fort", centre, y, yaw, 0,
				Transform3D(Basis.from_scale(Vector3(1.0, height / panel_height, 1.0)),
					Vector3.ZERO))
			if is_foot:
				_emit(ctx, &"wall.fort", centre, y, yaw, 0,
					Transform3D(Basis.from_scale(Vector3(1.0,
						FORT_FOOT_HEIGHT / panel_height, FORT_FOOT_DEPTH)), Vector3.ZERO))
		var rim := not above.has(inside)
		var gate := gates.has(edge)
		if rim and gate:
			continue
		var built_on := rim and external_blocked.is_valid() \
			and bool(external_blocked.call(inside, top_band))
		if rim and not built_on:
			_emit_parapet(ctx, centre, y + height, yaw)
		if bool(slot.right_convex):
			var right := Vector2(right_of(dir))
			var corner := centre + right * 0.5
			var out := Vector2(BuildingMass.DIRS[dir])
			if rim:
				# A turret: a stone tower on the corner, standing forward of
				# both faces from the foot of the wall.
				var at := corner + (out + right) * (FORT_TURRET_SIZE * 0.5 - 0.05) \
					/ kit.module_width
				_emit_pier(ctx, at, float(mass.ground_band) * kit.band_height(),
					y + height + FORT_TURRET_RISE, FORT_TURRET_SIZE)
			elif exposed:
				_emit_pier(ctx, corner, y, y + height, FORT_PIER_SIZE)
	for key: Variant in gates:
		var edge := key as Vector3i
		if not bool(gates[key]):
			continue
		_emit_gate(ctx, edge, y + height)


func _fort_panel_height() -> float:
	return FORT_PANEL_HEIGHT


## A plain stone parapet course with merlons, facing outward over one module.
func _emit_parapet(ctx: Dictionary, centre: Vector2, y: float, yaw: float) -> void:
	var panel_height := _fort_panel_height()
	_emit(ctx, &"wall.fort", centre, y, yaw, 0,
		Transform3D(Basis.from_scale(Vector3(1.0, FORT_PARAPET_HEIGHT / panel_height,
			1.6)), Vector3.ZERO))
	var width := kit.module_width
	for along: float in [-0.25, 0.25]:
		_emit(ctx, &"wall.fort", centre, y + FORT_PARAPET_HEIGHT, yaw, 0,
			Transform3D(Basis.from_scale(Vector3(FORT_MERLON_WIDTH / width,
				FORT_MERLON_HEIGHT / panel_height, 1.6)), Vector3(along * width, 0.0, 0.0)))


## A square stone pier centred on `at` (cells) from `bottom` to `top` (native
## metres): four plain faces and a stone cap, crowned with merlons.
func _emit_pier(ctx: Dictionary, at: Vector2, bottom: float, top: float,
		size: float) -> void:
	var panel_height := _fort_panel_height()
	var width := kit.module_width
	var half := size * 0.5 / width
	for dir in 4:
		var face := at + Vector2(BuildingMass.DIRS[dir]) * half
		_emit(ctx, &"wall.fort", face, bottom, yaw_for_dir(dir), 0,
			Transform3D(Basis.from_scale(Vector3(size / width,
				(top - bottom) / panel_height, 1.0)), Vector3.ZERO))
	# Cap: a panel laid flat across the pier's top.
	_emit(ctx, &"wall.fort", at, top, 0.0, 0,
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3(
			size / width, size / panel_height, 1.0)), Vector3(0.0, 0.0, size * 0.5)))
	for dir in 4:
		var face := at + Vector2(BuildingMass.DIRS[dir]) * half
		_emit(ctx, &"wall.fort", face, top, yaw_for_dir(dir), 0,
			Transform3D(Basis.from_scale(Vector3(size * 0.34 / width,
				FORT_MERLON_HEIGHT / panel_height, 1.0)), Vector3.ZERO))


## The gate into the district over one rim edge: two stone piers at its ends
## rising past the walk's headroom, joined by a lintel.
func _emit_gate(ctx: Dictionary, edge: Vector3i, rim_y: float) -> void:
	var dir := edge.z
	var inside := Vector2i(edge.x, edge.y)
	var out := Vector2(BuildingMass.DIRS[dir])
	var right := Vector2(right_of(dir))
	var line := Vector2(inside) + Vector2(0.5, 0.5) + out * 0.5
	var span := float(FORT_GATE_SPAN)
	# `edge` is the gate's left cell (seen from outside); it spans `span` cells.
	var left_end := line - right * 0.5
	var right_end := left_end + right * span
	var panel_height := _fort_panel_height()
	var width := kit.module_width
	# Gate piers stand just inside the rim at the opening's two ends (clear
	# of the flight arriving outside), joined by a deep lintel carrying a
	# crenellated parapet across the opening.
	var pier := FORT_GATE_PIER_SIZE
	var inset := pier * 0.5 / width
	var ends: Array[Vector2] = [left_end + right * inset - out * inset,
		right_end - right * inset - out * inset]
	for end: Vector2 in ends:
		_emit_pier(ctx, end, rim_y, rim_y + FORT_GATE_RISE, pier)
	var middle := (left_end + right_end) * 0.5 - out * inset
	_emit(ctx, &"wall.fort", middle, rim_y + FORT_GATE_RISE - FORT_LINTEL_HEIGHT,
		yaw_for_dir(dir), 0, Transform3D(Basis.from_scale(Vector3(span,
			FORT_LINTEL_HEIGHT / panel_height, pier / FORT_PANEL_DEPTH)), Vector3.ZERO))
	for along: float in [-0.5, 0.5]:
		_emit_parapet(ctx, middle + right * along + out * inset,
			rim_y + FORT_GATE_RISE, yaw_for_dir(dir))

