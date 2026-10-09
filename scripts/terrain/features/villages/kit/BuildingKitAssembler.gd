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
## Public floors at the same band on both sides make an internal walk
## seam, not an exposed parapet rim (notably at a split gate landing).
var public_floor: Callable = Callable()
## Native solid room bounds, shared by the town adapter. Gate frames meet
## carried rooms from below rather than continuing through their facades.
var overhead_solids: Array[Dictionary] = []
## Native scale of player-sized props (doorstep clutter, deck pots) inside
## this kit's frame; the production adapters keep them at their pre-upscale
## world size (`VillageWorldScale.kit_human_prop_scale`).
var prop_scale := 1.0
## Whole optional assemblies must fit before any of their pieces are emitted.
## The town supplies finished route and neighbour geometry; isolated studies
## may leave this unset.
var ornament_clear: Callable = Callable()
## A leaned or projected storey's walls stand this far below its floor so the
## panels overlap the jetty beam (shared by growth guardrails).
const OFFSET_WALL_DROP := 0.14


func _init(p_kit: BuildingKit) -> void:
	kit = p_kit


func assemble(mass: BuildingMass) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ctx := {"mass": mass, "out": out, "serial": 0}
	for index in mass.storeys.size():
		var start := out.size()
		_assemble_storey(ctx, index)
		var storey: Dictionary = mass.storeys[index]
		if bool(storey.get("ceiling", false)):
			var top := int(storey.floor_band) + int(storey.get("bands", 2))
			var above := mass.cells_at_band(top)
			for cell: Vector2i in storey.cells:
				if above.has(cell): continue # The upper room already supplies this floor.
				_emit(ctx, &"deck.board", Vector2(cell) + Vector2(0.5, 0.5),
					float(top) * kit.band_height(), 0.0)
		if bool(storey.get("retaining",false)) and not bool(storey.get("fortified",false)):
			for part in range(start,out.size()):
				var role := String(out[part].role)
				if role.begins_with("wall.") or role == "post.timber":
					out[part]["retaining_ceiling"] = float(int(storey.floor_band)+int(storey.get("bands",2)))*kit.band_height()
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


## Shared floor placements for rendering and cross-building opening fitting.
func inhabited_floors(mass: BuildingMass) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ctx := {"mass":mass,"out":out,"serial":0}
	for storey: Dictionary in mass.storeys:
		_emit_inhabited_floor(ctx,storey)
	return out

func _emit_inhabited_floor(ctx: Dictionary, storey: Dictionary) -> void:
	if bool(storey.get("retaining",false)) or bool(storey.get("fortified",false)):
		return
	var y := float(storey.floor_band)*kit.band_height()
	for cell: Vector2i in storey.cells:
		_emit(ctx,&"deck.board",Vector2(cell)+Vector2(0.5,0.5),y,0.0)
	_emit_front_floors(ctx,storey)


func _emit_front_floors(ctx: Dictionary, storey: Dictionary) -> void:
	var y := float(storey.floor_band)*kit.band_height()
	for projection:Dictionary in storey.get("projections",[]):
		var dir:=int(projection.dir)
		var out:=Vector2(BuildingMass.DIRS[dir])
		for centre:Vector2 in projection.centres:
			_emit(ctx,_front_role(&"frontage.floor",projection),centre+out*float(projection.depth)*.5/kit.module_width,y,yaw_for_dir(dir))


## Growth fronts use the baked piece for their cumulative depth.
func _front_role(role: StringName, projection: Dictionary) -> StringName:
	if not bool(projection.get("growth", false)):
		return role
	return StringName("%s.%s" % [role, lean_suffix(float(projection.depth))])


func _emit_projected_front(ctx:Dictionary,storey:Dictionary)->void:
	var y:=float(storey.floor_band)*kit.band_height()
	for projection:Dictionary in storey.get("projections",[]):
		var dir:=int(projection.dir)
		var depth:=float(projection.depth)
		# A growing storey's brackets bear on the leaned face of the storey below.
		var base:=float(projection.get("base",0.0))
		var out:=Vector2(BuildingMass.DIRS[dir])
		var right:=Vector2(right_of(dir))
		var centres:Array=projection.centres
		for centre:Vector2 in centres:
			_emit(ctx,_front_role(&"frontage.floor",projection),centre+out*depth*.5/kit.module_width,y+kit.storey_height-.12772,yaw_for_dir(dir))
			_emit(ctx,&"trim.floor_beam",centre+out*depth/kit.module_width,y,yaw_for_dir(dir))
		var closures:Array=projection.get("closures",[&"return",&"return"])
		for side:int in [-1,1]:
			var centre:Vector2=centres.front() if side<0 else centres.back()
			match StringName(closures[0 if side<0 else 1]):
				&"return":
					var at:=centre+right*.5*side+out*depth*.5/kit.module_width
					var yaw:=yaw_for_dir(dir)+PI*.5*side
					_emit(ctx,_front_role(&"frontage.return",projection),at,y,yaw,0,Transform3D.IDENTITY,storey.get("tint",Color.WHITE))
					_emit(ctx,_front_role(&"frontage.return_beam",projection),at,y,yaw)
					_emit(ctx,_front_role(&"frontage.return_beam",projection),at,y+kit.storey_height-.143,yaw)
				&"wrap":
					_emit_wrap_end(ctx,storey,projection,centre,side,y)
				_:
					pass # joint / bury (Tasks 6, 7): the neighbouring face continues the wall
		if depth<=base+.001:
			continue # a held storey adds no overhang: nothing to bracket
		if absf(depth-base-kit.jetty_depth)<.001 and kit.has_role(&"bracket.jetty"):
			# A kit-sized step rides the kit's own jetty brace: one per module, on the
			# storey below's (stepped) face, as _emit_jetty_trim places it.
			for centre:Vector2 in centres:
				_emit(ctx,&"bracket.jetty",centre+out*base/kit.module_width,y-kit.jetty_depth,yaw_for_dir(dir))
			continue
		for joint in range(centres.size()+1):
			var at:Vector2=centres.front()+right*(joint-.5)-out*(.15-base)/kit.module_width
			_emit(ctx,&"bracket.small",at,y-.706295,yaw_for_dir(dir))


## Native offset (along the face's outward normal) that makes a wrap strip's outer
## face coplanar with the face's wall panels; measured in Task 5 Step 6.
const WRAP_INSET := 0.030


## A wrapped convex corner: the face's wall runs on `depth` past its last module (a
## baked return strip turned to face out) with its floor beam; the face whose RIGHT
## end the corner is also lays the corner floor and ceiling squares (one owner).
func _emit_wrap_end(ctx: Dictionary, storey: Dictionary, projection: Dictionary,
		centre: Vector2, side: int, y: float) -> void:
	var dir := int(projection.dir)
	var depth := float(projection.depth)
	var w := kit.module_width
	var out := Vector2(BuildingMass.DIRS[dir])
	var right := Vector2(right_of(dir))
	var yaw := yaw_for_dir(dir)
	var strip := centre + right * side * (0.5 + depth * 0.5 / w) + out * (depth + WRAP_INSET) / w
	_emit(ctx, _front_role(&"frontage.return", projection), strip, y - OFFSET_WALL_DROP, yaw, 0,
		Transform3D.IDENTITY, storey.get("tint", Color.WHITE))
	_emit(ctx, _front_role(&"frontage.return_beam", projection), strip, y, yaw)
	if side > 0:
		var corner := centre + right * (0.5 + depth * 0.5 / w) + out * depth * 0.5 / w
		_emit(ctx, _front_role(&"frontage.corner", projection), corner, y, yaw)
		_emit(ctx, _front_role(&"frontage.corner", projection), corner, y + kit.storey_height - .12772, yaw)


## The pieces one candidate front adds (its moved wall slots, corner post,
## floor/ceiling strips, beams, returns, brackets), for fitters to test before
## committing. The storey itself is not changed.
func face_parts(mass: BuildingMass, index: int, projection: Dictionary) -> Array[Dictionary]:
	var storey: Dictionary = mass.storeys[index]
	var probe := storey.duplicate()
	var offsets: Dictionary = (storey.get("wall_offsets", {}) as Dictionary).duplicate()
	var edges := {}
	for edge: Vector3i in projection.edges:
		offsets[edge] = float(projection.depth) / kit.module_width
		edges[edge] = true
	# A wrapped right end: its partner face steps too, so the corner post stands
	# where the final assembly puts it.
	var closures: Array = projection.get("closures", [&"return", &"return"])
	if StringName(closures[1]) == &"wrap":
		var dir := int(projection.dir)
		var last: Vector2 = (projection.centres as Array).back()
		var cell := Vector2i((last - Vector2(BuildingMass.DIRS[dir]) * .5 - Vector2.ONE * .5).round())
		var side := BuildingMass.DIRS.find(right_of(dir))
		offsets[BuildingMass.edge_key(cell, side)] = float(projection.depth) / kit.module_width
	probe["wall_offsets"] = offsets
	probe["projections"] = [projection]
	var out: Array[Dictionary] = []
	var ctx := {"mass": mass, "out": out, "serial": 0}
	var y := float(probe.floor_band) * kit.band_height()
	var bands := int(probe.get("bands", 2))
	for slot: Dictionary in storey_slots(probe, _edge_exposure(mass, int(probe.floor_band), bands)):
		if not edges.has(slot.edge):
			continue
		# The panel _assemble_storey picks (same pick, plain cadence and asset).
		var yaw := yaw_for_dir(int(slot.dir))
		var tint := probe.get("tint", Color.WHITE) as Color
		var pick := _hash(mass, index, int(slot.centre.x * 2.0), int(slot.centre.y * 2.0))
		var kind := StringName(probe.openings.get(slot.edge, probe.default_opening))
		var plain_every := int(probe.get("plain_every", 0))
		if kind == BuildingMass.OPENING_WINDOW and plain_every > 0 and pick % plain_every == 0:
			kind = BuildingMass.OPENING_PLAIN
		if kind == BuildingMass.OPENING_BAY:
			# A bay replaces the panel (no post); a spire bay stands on a plain
			# panel; a bay the kit lacks falls back to a window.
			var bay_role := _emit_bay(ctx, probe, slot, y - OFFSET_WALL_DROP, yaw, pick, tint)
			if bay_role != &"" and bay_role != &"bay.spire":
				continue
			kind = BuildingMass.OPENING_PLAIN if bay_role == &"bay.spire" else BuildingMass.OPENING_WINDOW
		var role := StringName("wall.%s.%s" % [probe.material, kind])
		if not kit.has_role(role):
			role = StringName("wall.%s.window" % probe.material)
		_emit(ctx, role, slot.centre, y - OFFSET_WALL_DROP, yaw, pick, Transform3D.IDENTITY, tint,
			StringName((probe.get("opening_assets", {}) as Dictionary).get(slot.edge, &""))
				if kind == BuildingMass.OPENING_WINDOW else &"")
		_emit_corner_post(ctx, slot, y - OFFSET_WALL_DROP, bands, kit.wall_face)
	_emit_front_floors(ctx, probe)
	_emit_projected_front(ctx, probe)
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


## Name suffix of the baked front family for one cumulative lean, native m:
## 0.25 -> "d025" (`frontage.return.d025`).
static func lean_suffix(depth: float) -> String:
	return "d%03d" % roundi(depth * 100.0)


## Native +X of a piece facing `dir` (its right, seen from outside).
static func right_of(dir: int) -> Vector2i:
	match dir:
		0: return Vector2i(0, -1)
		1: return Vector2i(1, 0)
		2: return Vector2i(0, 1)
		_: return Vector2i(-1, 0)


func _emit(ctx: Dictionary, role: StringName, position_cells: Vector2,
		y: float, yaw: float, pick := 0, extra := Transform3D.IDENTITY,
		color := Color.WHITE, asset_override: StringName = &"") -> void:
	if not kit.has_role(role):
		return
	var w := kit.module_width
	var basis := Basis(Vector3.UP, yaw)
	var asset_id := kit.asset(role, pick) if asset_override == &"" else asset_override
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
				"left_concave": start_inner if right_is_forward else end_inner,
				"right_concave": end_inner if right_is_forward else start_inner,
				"outside": outside, "index": k, "count": count,
				"inset": float(run.shift) > 0.0,
			})
	return slots


static func storey_slots(storey: Dictionary, exposed: Callable = Callable()) -> Array[Dictionary]:
	var slots := wall_slots(storey.cells,bool(storey.get("inset",false)),exposed)
	var offsets:Dictionary=storey.get("wall_offsets",{})
	for slot:Dictionary in slots:
		slot["wall_offset"]=float(offsets.get(slot.edge,0.0))
		slot.centre+=Vector2(BuildingMass.DIRS[int(slot.dir)])*float(slot.wall_offset)
		# A wrapped convex corner: this face and the face to its right both step
		# out, so the corner (and its post) lies that much further along. 0 where
		# either face is flush (a return closes a lone step; room projections).
		slot["right_extend"]=0.0
		if bool(slot.right_convex) and float(slot.wall_offset)>0.0:
			var side:=BuildingMass.DIRS.find(right_of(int(slot.dir)))
			var edge:Vector3i=slot.edge
			slot["right_extend"]=float(offsets.get(BuildingMass.edge_key(Vector2i(edge.x,edge.y),side),0.0))
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
	# Every inhabited storey has a walked floor, including endpoint rooms on
	# lower rooms or retained stone. Visibility from below only controls the
	# soffit trim; it cannot decide whether the floor and collision exist.
	_emit_inhabited_floor(ctx, storey)
	if floor_band > mass.ground_band or bool(storey.get("soffit", false)):
		_assemble_soffit(ctx, storey, y)
	var bands := int(storey.get("bands", 2))
	var tint := storey.get("tint", Color.WHITE) as Color
	var retaining := bool(storey.get("retaining", false))
	var pent_colour := StringName(storey.get("pent_colour", &""))
	var pent_slots: Dictionary = {}
	var above_offsets:Dictionary={}
	for other:Dictionary in mass.storeys:
		if int(other.floor_band)==floor_band+bands:above_offsets=other.get("wall_offsets",{})
	var above_openings: Dictionary = {}
	for other: Dictionary in mass.storeys:
		if int(other.floor_band) == floor_band + bands:
			above_openings = other.openings
	for slot: Dictionary in storey_slots(storey,
			_edge_exposure(mass, floor_band, bands)):
		var wall_y := y - (OFFSET_WALL_DROP if float(slot.get("wall_offset",0.0))>0.0 else 0.0)
		var jettied := below_inset.has(slot.edge)
		if not _slot_exposed(mass, slot, floor_band, bands):
			continue
		if bands == 1:
			var sunk := bool(storey.get("sunk", false)) and kit.has_role(&"wall.stone.retaining")
			if retaining and kit.has_role(&"wall.stone.retaining_half"):
				# The source pack has an actual half-height masonry course.
				# Keep its stone scale instead of compressing a framed Suntail wall.
				_emit(ctx, &"wall.stone.retaining_half", slot.centre as Vector2, wall_y,
					yaw_for_dir(int(slot.dir)))
				_emit_corner_post(ctx, slot, wall_y, 1, kit.wall_face)
			elif sunk:
				# Standing on the ground: a full storey panel whose lower band
				# is buried, so the course keeps the storeys' masonry.
				_emit(ctx, &"wall.stone.retaining", slot.centre as Vector2,
					wall_y - kit.band_height(), yaw_for_dir(int(slot.dir)))
				_emit_corner_post(ctx, slot, wall_y - kit.band_height(), 2, kit.wall_face)
			else:
				_emit(ctx, &"wall.stone.course", slot.centre as Vector2, wall_y,
					yaw_for_dir(int(slot.dir)))
				_emit_corner_post(ctx, slot, wall_y, 1, kit.wall_face)
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
			# The bay replaces this wall panel and belongs to the same house finish.
			var bay_role := _emit_bay(ctx, storey, slot, wall_y, yaw, pick, tint)
			if bay_role != &"" and bay_role != &"bay.spire":
				_emit_jetty_trim(ctx, slot, wall_y, yaw, jettied, pick)
				continue
			kind = BuildingMass.OPENING_PLAIN if bay_role == &"bay.spire" else BuildingMass.OPENING_WINDOW
		var role := StringName("wall.%s.%s" % [material, kind])
		if kind == BuildingMass.OPENING_DOOR \
				and (storey.get("passage_edges", {}) as Dictionary).has(slot.edge):
			role = StringName("wall.%s.passage" % material)
		if retaining and kit.has_role(StringName("wall.%s.retaining" % material)):
			# Retaining faces (terrace skins) stay flush with the lawn above.
			role = StringName("wall.%s.retaining" % material)
		if not kit.has_role(role):
			role = StringName("wall.%s.window" % material)
		_emit(ctx, role, centre, wall_y, yaw, pick, Transform3D.IDENTITY, tint,
			StringName((storey.get("opening_assets",{}) as Dictionary).get(slot.edge,&""))
				if kind == BuildingMass.OPENING_WINDOW else &"")

		# A high opening borrowed from an unframed family needs the native
		# timber joints that the usual Suntail panel carries in its mesh.
		var selected_asset := StringName((storey.get("opening_assets",{}) as Dictionary).get(slot.edge,&""))
		if kind == BuildingMass.OPENING_WINDOW and not kit.has_role(&"trim.panel_joint") \
				and selected_asset in kit.roles.get(&"wall.timber.window.high",[]):
			_emit(ctx,&"trim.high_window_head",centre,wall_y+kit.storey_height-0.075,yaw)
			for side in [-1.0,1.0]:
				_emit(ctx,&"trim.high_window_joint",centre+Vector2(right_of(dir))*0.5*side,wall_y,yaw)
		_emit_corner_post(ctx, slot, wall_y, bands, kit.face_of(material, retaining))
		# Kits with unframed plaster panels supply their joining timbers as
		# separate roles. Each internal seam has one owner; corners keep their
		# existing full-height post. Never cross a masonry opening with timber.
		if material == BuildingMass.MATERIAL_TIMBER and not retaining:
			_emit(ctx, &"trim.panel_head", centre, wall_y + kit.storey_height - 0.075, yaw)
			if not bool(slot.right_convex) and not bool(slot.get("right_concave", false)):
				_emit(ctx, &"trim.panel_joint", centre + Vector2(right_of(dir)) * 0.5, wall_y, yaw)
		elif material == BuildingMass.MATERIAL_STONE and not retaining \
				and _gable_starts_at(mass, slot, floor_band + bands):
			# Unframed plaster gables need a sill even over masonry. Timber
			# storeys already supply this beam through trim.panel_head above.
			_emit(ctx, &"trim.panel_head", centre + Vector2(BuildingMass.DIRS[dir]) \
				* kit.masonry_depth / kit.module_width,
				wall_y + float(bands) * kit.band_height() - 0.075, yaw)
		if pent_colour != &"" and _covered_above(mass, slot, floor_band + bands) \
				and StringName(above_openings.get(slot.edge, &"")) != BuildingMass.OPENING_BAY \
				and not above_offsets.has(slot.edge):
			var back:Vector2=centre-Vector2(BuildingMass.DIRS[dir])*float(slot.get("wall_offset",0.0))
			pent_slots[back] = slot
		if bool(storey.plinth) and not _solid_below(mass, slot, floor_band):
			_emit(ctx, &"plinth.stone", centre, wall_y - kit.plinth_height, yaw, pick)
		_emit_jetty_trim(ctx, slot, wall_y, yaw, jettied, pick)
	_emit_pent_eaves(ctx, pent_slots, pent_colour, y + float(bands) * kit.band_height())
	_emit_projected_front(ctx,storey)


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
	var at := (slot.centre as Vector2) + right * (0.5 + float(slot.get("right_extend", 0.0))) \
		+ (out + right) * inset
	var height := float(bands) * kit.band_height() + (0.074 if bands >= 2 else 0.0)
	var girth := half / kit.corner_post_half
	_emit(ctx, &"post.timber", at, y, yaw_for_dir(dir), 0,
		Transform3D(Basis.from_scale(Vector3(girth, height, girth)), Vector3.ZERO))


## A pent eave course runs along consecutive slots of one face; lone slots are
## dropped and every open end is closed with a barge board.
func _emit_pent_eaves(ctx: Dictionary, slots: Dictionary, colour: StringName,
		y: float) -> void:
	var visited := {}
	var accepted: Array[Dictionary] = []
	var heights := _hood_attachment_heights(slots, y)
	for seed_centre: Vector2 in slots:
		if visited.has(seed_centre): continue
		var slot: Dictionary = slots[seed_centre]
		var dir := int(slot.dir)
		var right := Vector2(right_of(dir))
		var first := seed_centre
		while slots.has(first-right) and int(slots[first-right].dir)==dir:
			first -= right
		var run: Array[Vector2] = []
		var centre := first
		while slots.has(centre) and int(slots[centre].dir)==dir:
			visited[centre] = true
			run.append(centre)
			centre += right
		if run.size()<2: continue
		# Admission belongs to one complete shed roof, not every face of
		# the room. A blocked alley-side end must not erase a clear street
		# frontage on the other side. Keep both end boards with their run.
		var pending: Array[Dictionary] = []
		var candidate := {"mass":ctx.mass,"out":pending,"serial":ctx.serial}
		var yaw := yaw_for_dir(dir)
		var hood_y: float = heights[first]
		if kit.has_role(&"wallhood.middle") and kit.has_role(&"wallhood.left") and kit.has_role(&"wallhood.right"):
			# A wall hood is only the shallow bottom course. A complete
			# gable-slope strip would climb a storey into the retained cap.
			for i in run.size():
				var role := &"wallhood.left" if i==0 else (&"wallhood.right" if i==run.size()-1 else &"wallhood.middle")
				_emit(candidate,role,run[i],hood_y,yaw)
		else:
			for at: Vector2 in run:
				_emit(candidate,StringName("roof.%s.eave" % colour),at,y,yaw)
			_emit(candidate,&"trim.barge.eave",run.front()-right*0.5,y,yaw-PI*0.5)
			_emit(candidate,&"trim.barge.eave",run.back()+right*0.5,y,yaw-PI*0.5)
		var clear := true
		for part: Dictionary in pending:
			if ornament_clear.is_valid() and not bool(ornament_clear.call(part.asset_id,part.transform)):
				clear = false
				break
		if not clear: continue
		(ctx.out as Array).append_array(pending)
		ctx.serial = candidate.serial
		accepted.append({"run":run,"parts":pending,"dir":dir,"y":hood_y})
	_join_hood_corners(ctx, accepted, slots)


## A projecting facade needs extra window-head clearance. Its connected
## cornice must share that datum around corners; lifting just one face
## produces stepped, disconnected roof ends. Separate courses stay independent.
static func _hood_attachment_heights(slots: Dictionary, y: float) -> Dictionary:
	var endpoints := {}
	for centre: Vector2 in slots:
		var side := Vector2(right_of(int(slots[centre].dir))) * 0.5
		for vertex: Vector2 in [centre-side, centre+side]:
			if not endpoints.has(vertex): endpoints[vertex] = []
			endpoints[vertex].append(centre)
	var heights := {}
	for seed_centre: Vector2 in slots:
		if heights.has(seed_centre): continue
		var component: Array[Vector2] = [seed_centre]
		var seen := {seed_centre:true}
		var top := y
		var index := 0
		while index < component.size():
			var centre := component[index]
			index += 1
			if float(slots[centre].get("wall_offset",0.0)) > 0.0: top = y + 0.35
			var side := Vector2(right_of(int(slots[centre].dir))) * 0.5
			for vertex: Vector2 in [centre-side, centre+side]:
				for neighbor: Vector2 in endpoints[vertex]:
					if seen.has(neighbor): continue
					seen[neighbor] = true
					component.append(neighbor)
		for centre: Vector2 in component: heights[centre] = top
	return heights


## Native canopy grammar: StreetHouse_7 supplies the convex connection;
## House_10 reserves 1.5 m along both faces for an inward valley. Open ends
## retain their caps. Decide this only after both faces have survived their
## independent admission, so a blocked alley cannot erase a street frontage.
func _join_hood_corners(ctx: Dictionary, runs: Array[Dictionary], slots: Dictionary) -> void:
	if not kit.has_role(&"wallhood.outer_corner"): return
	for left: Dictionary in runs:
		var dir := int(left.dir)
		var first: Vector2 = left.run.front()
		var inner := bool(slots[first].get("left_concave",false))
		if not bool(slots[first].left_convex) and not inner: continue
		if inner and (not kit.has_role(&"wallhood.inner_corner") or not kit.has_role(&"wallhood.middle_half")): continue
		var vertex := first - Vector2(right_of(dir)) * 0.5
		for right: Dictionary in runs:
			var other_dir := (dir+3)%4 if inner else (dir+1)%4
			if int(right.dir) != other_dir or not is_equal_approx(float(left.y),float(right.y)): continue
			var last: Vector2 = right.run.back()
			if not bool(slots[last].get("right_concave" if inner else "right_convex",false)): continue
			if not vertex.is_equal_approx(last + Vector2(right_of(right.dir))*0.5): continue
			var parts: Array[Dictionary] = []
			var candidate := {"mass":ctx.mass,"out":parts,"serial":ctx.serial}
			if inner:
				# House_10's valley occupies 1.5 native metres along BOTH
				# faces. Only 0.5 m of each two-metre end bay remains; keep
				# its source tile scale and move that short strip away from
				# the valley instead of laying full strips through it.
				_emit(candidate,&"wallhood.inner_corner",vertex,left.y,yaw_for_dir(other_dir))
				_emit(candidate,&"wallhood.middle_half",first+Vector2(right_of(dir))*.375,left.y,yaw_for_dir(dir))
				_emit(candidate,&"wallhood.middle_half",last-Vector2(right_of(other_dir))*.375,right.y,yaw_for_dir(other_dir))
			else:
				_emit(candidate,&"wallhood.outer_corner",vertex,left.y,yaw_for_dir(dir))
				_emit(candidate,&"wallhood.middle",first,left.y,yaw_for_dir(dir))
				_emit(candidate,&"wallhood.middle",last,right.y,yaw_for_dir(right.dir))
			var clear := true
			for part: Dictionary in parts:
				if ornament_clear.is_valid() and not bool(ornament_clear.call(part.asset_id,part.transform)):
					clear = false
					break
			if not clear: continue
			# Mutate the dictionaries already owned by the emitted payload;
			# retain each straight bay's stable identity when replacing its cap.
			for pair: Array in [[left.parts.front(),parts[1]],[right.parts.back(),parts[2]]]:
				for key: String in ["asset_id","role","transform"]:
					pair[0][key] = pair[1][key]
			(ctx.out as Array).append(parts[0])
			ctx.serial = candidate.serial
			break


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
		if bool(storey.get("retaining", false)):
			_emit(ctx, &"deck.board", Vector2(cell) + Vector2(0.5, 0.5), y, 0.0)

	# A retained tunnel crown starts at its own datum but explicitly hangs
	# over a passage. Its boards need the same rim closure as upper rooms.
	if datum and overhang.is_empty() and not bool(storey.get("soffit", false)): return
	# Every overhanging rim needs the same continuous timber edge as jetties
	# (and only the actual exposed rim: no internal grid seams). Without it the
	# wall panels' plaster bottoms met the boards' outer edge in one plane and
	# flickered along a bridge-house's underside (September 29 photo 8).
	for slot: Dictionary in wall_slots(storey.cells, false):
		if not boarded.has(Vector2i(slot.edge.x, slot.edge.y)): continue
		if not _slot_exposed(mass, slot, floor_band, 2): continue
		var role := &"trim.floor_beam_corner" if slot.left_convex else &"trim.floor_beam"
		_emit(ctx, role, slot.centre, y, yaw_for_dir(slot.dir))
		if bool(storey.get("retaining", false)) and kit.has_role(&"wall.stone.retaining"):
			var part: Dictionary = ctx.out.back()
			var stone := kit.asset(&"wall.stone.retaining")
			part["soffit_stone_asset"] = stone
			part["soffit_stone_transform"] = Transform3D(Basis(Vector3.UP,yaw_for_dir(slot.dir)),
				Vector3(slot.centre.x*kit.module_width,y,slot.centre.y*kit.module_width)) \
				* kit.anchor(&"wall.stone.retaining") * kit.asset_anchor(stone)

	_assemble_cantilever_brackets(ctx, storey, y, below, boarded)


## A one-module upper room projects over a lower wall. Native curved
## brackets bear on that wall's joints and meet its boarded floor above.
## Longer spans need a different structural assembly, not stretched brackets.
func _assemble_cantilever_brackets(ctx:Dictionary,storey:Dictionary,y:float,below:Dictionary,overhang:Dictionary)->void:
	if not kit.has_role(&"bracket.cantilever") or bool(storey.get("retaining",false)):return
	if bool(storey.get("inset",false)) or below.is_empty():return
	var mass:BuildingMass=ctx.mass
	var lower:=_bearing_storey_at(mass,int(storey.floor_band))
	if lower.is_empty() or bool(lower.get("inset",false)):return
	var seen:Dictionary={}
	for slot:Dictionary in wall_slots(below,false):
		var dir:=int(slot.dir)
		var step:Vector2i=BuildingMass.DIRS[dir]
		var cell:=Vector2i(slot.edge.x,slot.edge.y)
		# Both the wall-bearing room and its outward bay must belong to
		# this floor; a bridge ending at another building is a different case.
		if not storey.cells.has(cell) or not overhang.has(cell+step):continue
		if storey.cells.has(cell+step*2):continue
		if not mass.cells_at_band(int(storey.floor_band)-2).has(cell):continue
		var lower_offsets:Dictionary=lower.get("wall_offsets",{})
		if lower_offsets.has(slot.edge):continue
		for side:int in [-1,1]:
			var joint:Vector2=slot.centre+Vector2(right_of(dir))*float(side)*.5
			var key:=Vector3i(roundi(joint.x),roundi(joint.y),dir)
			if seen.has(key):continue
			seen[key]=true
			var pending:Array[Dictionary]=[]
			var candidate:Dictionary={"mass":mass,"out":pending,"serial":ctx.serial}
			_emit(candidate,&"bracket.cantilever",joint+Vector2(step)*kit.wall_face/kit.module_width,y+.04,yaw_for_dir(dir))
			var part:Dictionary=pending[0]
			if ornament_clear.is_valid() and not bool(ornament_clear.call(part.asset_id,part.transform)):continue
			(ctx.out as Array).append(part)
			ctx.serial=candidate.serial


static func _bearing_storey_at(mass:BuildingMass,band:int)->Dictionary:
	for floor:Dictionary in mass.storeys:
		if int(floor.floor_band)<=band-1 and int(floor.floor_band)+int(floor.get("bands",2))>=band:return floor
	return {}


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


## A closed gable meets this exact wall head, rather than an eave, open
## branch junction or a roof above a different storey.
static func _gable_starts_at(mass: BuildingMass, slot: Dictionary, band: int) -> bool:
	var dir := int(slot.dir)
	var axis := 0 if dir % 2 == 0 else 1
	var positive := dir < 2
	var centre: Vector2 = slot.centre
	for wing: Dictionary in mass.roofs:
		if int(wing.eave_band) != band or int(wing.axis) != axis:
			continue
		if bool(wing.open_max if positive else wing.open_min):
			continue
		var rect: Rect2i = wing.rect
		var end := rect.end[axis] if positive else rect.position[axis]
		if is_equal_approx(centre[axis], float(end)) \
				and centre[1-axis] > rect.position[1-axis] \
				and centre[1-axis] < rect.end[1-axis]:
			return true
	return false


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


## A bay replacing this wall panel: the role it placed, or &"" when none.
func _emit_bay(ctx: Dictionary, storey: Dictionary, slot: Dictionary, wall_y: float, yaw: float,
		pick: int, tint: Color) -> StringName:
	var colour := StringName(storey.get("bay_colour", &"red"))
	var bay_role := StringName((storey.get("bay_roles",{}) as Dictionary).get(slot.edge,StringName("bay.%s" % colour)))
	if not kit.has_role(bay_role):
		return &""
	var offset: Vector2 = (storey.get("bay_offsets",{}) as Dictionary).get(slot.edge,Vector2.ZERO)
	_emit(ctx, bay_role, (slot.centre as Vector2)+offset, wall_y + kit.band_height() * 2.0 / 3.0, yaw, pick, Transform3D.IDENTITY, tint)
	return bay_role


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
	var tight_sides := tight_eave_sides(wing) if kit.has_role(StringName("roof.%s.eave_tight" % colour)) else 0
	# Sides: 0 = +v face, 1 = -v face.
	for side in 2:
		var tight := bool(tight_sides & (1 << side))
		var side_start: int = ctx.out.size()
		var dir := (1 if axis == 0 else 0) if side == 0 else (3 if axis == 0 else 2)
		var yaw := yaw_for_dir(dir)
		for k in rows:
			var line := float(v1 - k) if side == 0 else float(v0 + k)
			var y := eave_y + float(k) * kit.roof_row_rise
			for p in range(p_min, p_max + 1):
				var role := StringName("roof.%s.slope" % colour)
				if k == 0:
					role = StringName("roof.%s.%s" % [colour,"eave_tight" if tight else "eave"])
					if dormers.has(Vector2i(side, p)) and (not tight or kit.has_role(StringName("roof.%s.eave_tight_dormer" % colour))):
						role = StringName("roof.%s.%s" % [colour,"eave_tight_dormer" if tight else "eave_dormer"])
				if kit.roof_edge_caps and p == p_max: continue
				var at := float(p) + (0.5 if kit.roof_edge_caps else 0.0)
				if not kit.roof_edge_caps:
					role = _roof_end_role(role, p, p_min, p_max, right_of(dir)[axis])
				_emit(ctx, role, _uv(axis, at, line), y, yaw,
					_hash(mass, p, k, side))
			if kit.roof_edge_caps:
				var role := StringName("roof.%s.%s" % [colour, "eave" if k == 0 else "slope"])
				if k == 0 and tight: role = StringName("roof.%s.eave_tight" % colour)
				for end: int in [p_min,p_max]:
					var along := right_of(dir)[axis]
					var end_role := _roof_end_role(role,end,p_min,p_max,along)
					var at := _roof_cap_at(wing,end_role,end,p_min,along)
					_emit(ctx, end_role, _uv(axis,at,line),y,yaw)
		if tight and kit.has_role(&"trim.eave_tight"):
			var line := float(v1 if side == 0 else v0)
			for p in range(u0,u1):
				_emit(ctx,&"trim.eave_tight",_uv(axis,float(p)+0.5,line),eave_y,yaw)
		for part_index in range(side_start,ctx.out.size()):
			ctx.out[part_index]["roof_side"] = side
			var part: Dictionary = ctx.out[part_index]
			if tight and kit.tight_eave_joint_clip and String(part.role).begins_with("roof.") \
					and String(part.role).contains(".eave_tight"):
				# The translated stock meets the unchanged next row (or ridge)
				# at the original joint. Cut only the hidden uphill surplus.
				var seam := float(v1 - 1 if side == 0 else v0 + 1) * kit.module_width
				var bounds := AABB(Vector3.ONE * -10000.0, Vector3.ONE * 20000.0)
				var cross_axis := 2 if axis == 0 else 0
				if side == 0:
					bounds.size[cross_axis] = seam - bounds.position[cross_axis]
				else:
					bounds.position[cross_axis] = seam
					bounds.size[cross_axis] = 10000.0 - seam
				var clips: Array = part.get("clip_volumes",[])
				clips.append(preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd").box_volume(bounds))
				part["clip_volumes"] = clips
	if bool(profile.top):
		var top_y := eave_y + float(rows) * kit.roof_row_rise
		var mid := float(v0 + v1) * 0.5
		for p in range(p_min, p_max + 1):
			if kit.roof_edge_caps and p == p_max: continue
			var role := StringName("roof.%s.top" % colour)
			if not kit.roof_edge_caps:
				role = _roof_end_role(role,p,p_min,p_max,1 if axis == 0 else -1)
			_emit(ctx, role, _uv(axis, float(p) + (0.5 if kit.roof_edge_caps else 0.0), mid),
				top_y, 0.0 if axis == 0 else PI * 0.5)
		if kit.roof_edge_caps:
			for end: int in [p_min,p_max]:
				var along := 1 if axis == 0 else -1
				var end_role := _roof_end_role(StringName("roof.%s.top" % colour),end,p_min,p_max,along)
				var at := _roof_cap_at(wing,end_role,end,p_min,along)
				_emit(ctx, end_role, _uv(axis,at,mid),top_y,0.0 if axis == 0 else PI * 0.5)
	# A wall-backed mono-pitch ends in the host wall, not a free ridge.
	if not wing.get("backed_shed",false):
		_assemble_ridge(ctx, wing, axis, float(v0 + v1) * 0.5, eave_y, profile,
			p_min, p_max)
	if bool(wing.get("chimney", false)) and u1 - u0 >= 3:
		# A rubble stack straddling the ridge one module in from a gable:
		# blocks rise from inside the roof to clear the ridge, then the top.
		var at_u := float(u1 - 1) if int(wing.get("chimney_end", 1)) == 1 else float(u0 + 1)
		at_u = float(wing.get("chimney_u", at_u))
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
			eave_y, profile, float(wing.get("verge_min" if end == 0 else "verge_max", -1.0)), tight_sides)


func _roof_cap_at(wing: Dictionary, role: StringName, end: int, first: int,
		along: int) -> float:
	var key := "verge_min" if end == first else "verge_max"
	if not wing.has(key): return float(end)
	var id := kit.asset(role)
	if not kit.roof_cap_x_bounds.has(id): return float(end)
	var bounds: Vector2 = kit.roof_cap_x_bounds[id]
	var native_positive := (end != first) == (along > 0)
	var reach := bounds.y if native_positive else -bounds.x
	var shift := maxf(0.0, reach - float(wing[key])) / kit.module_width
	return float(end) + (shift if end == first else -shift)


func _roof_end_role(role: StringName, at: int, first: int, last: int,
		along: int) -> StringName:
	if at != first and at != last: return role
	var start := (at == first) == (along > 0)
	var edge := StringName("%s.%s" % [role, "start" if start else "end"])
	return edge if kit.has_role(edge) else role


func _uv(axis: int, u: float, v: float) -> Vector2:
	return Vector2(u, v) if axis == 0 else Vector2(v, u)


func _assemble_ridge(ctx: Dictionary, wing: Dictionary, axis: int, mid: float,
		eave_y: float, profile: Dictionary, p_min: int, p_max: int) -> void:
	var ridge_y := eave_y + float(profile.height)
	ridge_y += kit.roof_ridge_lift.y if bool(profile.top) else kit.roof_ridge_lift.x
	var yaw := 0.0 if axis == 0 else PI * 1.5
	var inset := Vector2.ZERO
	var body_clips: Array[Dictionary] = []
	if kit.roof_edge_caps:
		if wing.has("verge_min"): inset.x = maxf(0.0,kit.ridge_cap_reach.x-float(wing.verge_min))
		if wing.has("verge_max"): inset.y = maxf(0.0,kit.ridge_cap_reach.y-float(wing.verge_max))
		var body := {"axis":axis}
		if inset.x>0.0: body.clip_min = float(p_min)+inset.x/kit.module_width
		if inset.y>0.0: body.clip_max = float(p_max)-inset.y/kit.module_width
		body_clips = preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd").clip_volumes(body,kit)
	for p in range(p_min, p_max + 1):
		if kit.roof_edge_caps and p == p_max: continue
		var role := &"trim.ridge" if kit.roof_edge_caps else _roof_end_role(&"trim.ridge",p,p_min,p_max,1)
		_emit(ctx, role, _uv(axis, float(p) + (0.5 if kit.roof_edge_caps else 0.0), mid), ridge_y, yaw)
		if not body_clips.is_empty(): ctx.out.back()["clip_volumes"] = body_clips
		if bool(wing.ridge_peaks) and p > p_min and p < p_max:
			_emit(ctx, &"trim.ridge_peak", _uv(axis, float(p), mid), ridge_y, yaw)

	if kit.roof_edge_caps:
		for end: int in [p_min,p_max]:
			# Move the complete end into a shortened verge. The regular ridge
			# is trimmed to its new seam, retaining the original cap overlap.
			var at := float(end)+(inset.x if end==p_min else -inset.y)/kit.module_width
			_emit(ctx, _roof_end_role(&"trim.ridge",end,p_min,p_max,1),
				_uv(axis,at,mid),ridge_y,yaw)


func _assemble_gable(ctx: Dictionary, axis: int, end: int, u: int, v0: int,
		v1: int, eave_y: float, profile: Dictionary, verge := -1.0, tight_sides := 0) -> void:
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
	# The trim follows the fitted roof end; ordinary verges reach half a module.
	var reach := 0.5 if verge < 0.0 else maxf(0.0, verge - kit.barge_half_depth) / kit.module_width
	var outward := reach if end == 1 else -reach
	for side in 2:
		var row_dir := (1 if axis == 0 else 0) if side == 0 else (3 if axis == 0 else 2)
		var board_yaw := yaw_for_dir(row_dir) - PI * 0.5
		for k in rows:
			var line := float(v1 - k) if side == 0 else float(v0 + k)
			var y := eave_y + float(k) * kit.roof_row_rise
			var role := &"trim.barge.eave" if k == 0 and not bool(tight_sides & (1 << side)) else &"trim.barge.slope"
			_emit(ctx, role, _uv(axis, float(u) + outward, line), y, board_yaw)
			ctx.out.back()["roof_side"] = side
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
			if not kit.has_role(&"window_box"): return
			_emit(ctx, &"window_box", centre + out * (0.17 / w), y + 0.75, yaw, pick)
			var box_part: Dictionary = ctx.out.back()
			box_part["window_wall_centre"] = centre * w
			box_part["window_storey_y"] = y
			box_part["window_ground_y"] = float(mass.ground_band) * kit.band_height()
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
# Native stone-window sill starts at 0.5603 m; the footing stays below it.
const FORT_FOOT_HEIGHT := 0.5
const FORT_FOOT_DEPTH := 4.0
const FORT_PIER_SIZE := 0.7
const FORT_GATE_PIER_SIZE := 1.0
const FORT_TURRET_SIZE := 1.3
const FORT_TURRET_RISE := 1.5
const FORT_GATE_RISE := 4.2
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
			var courses := maxi(1,ceili(height/panel_height))
			var rise := height/float(courses)
			for course in courses:
				_emit(ctx, &"wall.fort", centre, y+float(course)*rise, yaw, 0,
					Transform3D(Basis.from_scale(Vector3(1.0,rise/panel_height,1.0)),
						Vector3(0,0,-0.16)))
			if not gates.has(edge) and not above.has(inside):
				_assemble_fort_relief(ctx,slot,y,height,yaw)
			if is_foot:
				for course in 2:
					for along: float in [-0.25,0.25]:
						_emit_fort_block(ctx,centre,y+float(course)*FORT_FOOT_HEIGHT*.5,yaw,
							Vector3(kit.module_width*.5,FORT_FOOT_HEIGHT*.5,FORT_PANEL_DEPTH*FORT_FOOT_DEPTH),
							Vector3(along*kit.module_width,0,0))
		var rim := not above.has(inside)
		var gate := gates.has(edge)
		var walk_seam := public_floor.is_valid() \
			and bool(public_floor.call(inside,top_band)) \
			and bool(public_floor.call(inside+BuildingMass.DIRS[dir],top_band))
		if rim and (gate or walk_seam):
			continue
		var built_on := rim and external_blocked.is_valid() \
			and (bool(external_blocked.call(inside,top_band)) \
				or bool(external_blocked.call(inside+BuildingMass.DIRS[dir],top_band)))
		# A room on either side closes this edge. Battlements in front of
		# the adjacent room would conceal its windows and doorway.
		if built_on: continue
		if rim:
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
				var bottom := float(mass.ground_band)*kit.band_height()
				var pier_top := y+height+FORT_TURRET_RISE
				if _fort_pier_clear(at,bottom,pier_top,FORT_TURRET_SIZE):
					_emit_pier(ctx,at,bottom,pier_top,FORT_TURRET_SIZE)
			elif exposed:
				_emit_pier(ctx, corner, y, y + height, FORT_PIER_SIZE)
	var frames: Dictionary = storey.get("gate_frames",gates)
	for key: Variant in frames:
		var edge := key as Vector3i
		if not bool(frames[key]):
			continue
		_emit_gate(ctx, edge, y + height)


## Corner turrets are decorative; omit the complete tower when its descent
## would obstruct a lower passage. Never leave a floating fragment above it.
func _fort_pier_clear(at: Vector2, bottom: float, top: float, size: float) -> bool:
	var half := size*0.5+FORT_PANEL_DEPTH
	var centre := at*kit.module_width
	var box := AABB(Vector3(centre.x-half,bottom,centre.y-half),
		Vector3(half*2,top-bottom+FORT_MERLON_HEIGHT+FORT_PANEL_DEPTH,half*2))
	for volume: Dictionary in overhead_solids:
		if bool(volume.get("open",false)) and box.intersects(volume.bounds): return false
	return true


func _fort_panel_height() -> float:
	return FORT_PANEL_HEIGHT


func _fort_relief_piece(ctx: Dictionary, slot: Dictionary, y: float, yaw: float,
		centre: Vector2, size: Vector2, angle: float, detail: StringName) -> void:
	# Native closed blocks supply the rim trim, not squashed wall textures.
	var count := maxi(1,ceili(size.x))
	var width := size.x/float(count)
	for i in count:
		var x := centre.x-size.x*.5+(float(i)+.5)*width
		_emit_fort_block(ctx,slot.centre,y+centre.y-size.y*.5,yaw,
			Vector3(width,size.y,.18),Vector3(x,0,-.002))
		var part: Dictionary = (ctx.out as Array).back()
		part["fort_detail"] = detail
		part["fort_detail_edge"] = slot.edge


func _assemble_fort_relief(ctx: Dictionary, slot: Dictionary, y: float,
		height: float, yaw: float) -> void:
	var width := kit.module_width
	_fort_relief_piece(ctx,slot,y,yaw,Vector2(0,height-0.11),
		Vector2(width,0.22),0,&"course")


## A plain stone parapet course with merlons, facing outward over one module.
func _emit_fort_block(ctx: Dictionary, centre: Vector2, y: float, yaw: float,
		size: Vector3, offset := Vector3.ZERO) -> void:
	# Stone_Block_4 retains all six authored faces, including exposed ends.
	var native_size := Vector3(0.999427,0.463352,0.521328)
	_emit(ctx,&"fort.block",centre,y,yaw,0,
		Transform3D(Basis.from_scale(size/native_size),offset))


func _emit_parapet(ctx: Dictionary, centre: Vector2, y: float, yaw: float) -> void:
	var first := (ctx.out as Array).size()
	var width := kit.module_width
	var depth := FORT_PANEL_DEPTH*1.6
	for along: float in [-0.25,0.25]:
		_emit_fort_block(ctx,centre,y,yaw,Vector3(width*.5,FORT_PARAPET_HEIGHT,depth),
			Vector3(along*width,0,0))
		_emit_fort_block(ctx,centre,y+FORT_PARAPET_HEIGHT,yaw,
			Vector3(FORT_MERLON_WIDTH,FORT_MERLON_HEIGHT,depth),Vector3(along*width,0,0))

	# The parapet base carries its merlons. Clearance may remove the whole
	# section, never just the base and leave floating individual blocks.
	if (ctx.out as Array).size() > first:
		var group := StringName("%s/parapet" % ctx.out[first].stable_id)
		for index in range(first,(ctx.out as Array).size()):
			ctx.out[index]["clearance_group"] = group


## A square stone pier centred on `at` (cells) from `bottom` to `top` (native
## metres): four plain faces and a stone cap, crowned with merlons.
func _emit_pier(ctx: Dictionary, at: Vector2, bottom: float, top: float,
		size: float, crowned := true) -> void:
	var panel_height := _fort_panel_height()
	var width := kit.module_width
	var half := size * 0.5 / width
	# A tall pier is built in masonry courses. Stretching one source panel
	# from ground to battlement turned ordinary bricks into vertical slabs.
	var courses := maxi(1,ceili((top-bottom)/panel_height))
	var rise := (top-bottom)/float(courses)
	for course in courses:
		for dir in 4:
			var face := at + Vector2(BuildingMass.DIRS[dir]) * half
			_emit(ctx, &"wall.fort", face, bottom+float(course)*rise, yaw_for_dir(dir), 0,
				Transform3D(Basis.from_scale(Vector3(size / width,
					rise / panel_height, 1.0)), Vector3.ZERO))
	_emit_fort_block(ctx,at,top-FORT_PANEL_DEPTH,0.0,
		Vector3(size,FORT_PANEL_DEPTH,size))
	if not crowned: return
	for dir in 4:
		var face := at + Vector2(BuildingMass.DIRS[dir]) * half
		_emit_fort_block(ctx,face,top,yaw_for_dir(dir),
			Vector3(size*.34,FORT_MERLON_HEIGHT,FORT_PANEL_DEPTH))


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
	var top := gate_top(edge, rim_y)
	if top - rim_y < FORT_LINTEL_HEIGHT \
			+ TraversalEnvelope.MIN_HEADROOM / VillageWorldScale.KIT_WORLD_SCALE:
		return # The carried room supplies the header where stone cannot fit.
	var covered := top < rim_y + FORT_GATE_RISE - 0.001
	for end: Vector2 in ends:
		_emit_pier(ctx, end, rim_y, top, pier, not covered)
	var middle := (left_end + right_end) * 0.5 - out * inset
	if kit.has_role(&"gate.arch"):
		# Pure Village StoneArch_3: baked about its measured bottom-centre.
		# Its native molded opening remains intact; only the complete header
		# is fitted between the gate's proved piers and overhead limit.
		var native_size := kit.gate_arch_size
		var rise := minf(native_size.y,top-rim_y-TraversalEnvelope.MIN_HEADROOM/VillageWorldScale.KIT_WORLD_SCALE)
		_emit(ctx,&"gate.arch",middle,top-rise,yaw_for_dir(dir),0,
			Transform3D(Basis.from_scale(Vector3(span*width/native_size.x,
				rise/native_size.y,pier/native_size.z)),Vector3.ZERO))
	else:
		# Match the source masonry's aspect ratio across the broad header too.
		# A single panel stretched across both bays produced flattened bricks.
		var header_width := span*width
		var blocks := maxi(1,ceili(header_width/(FORT_LINTEL_HEIGHT*width/panel_height)))
		var block_width := header_width/float(blocks)
		for block in blocks:
			var along := (float(block)+0.5)*block_width-header_width*0.5
			_emit(ctx, &"wall.fort", middle+right*along/width, top-FORT_LINTEL_HEIGHT,
				yaw_for_dir(dir),0,Transform3D(Basis.from_scale(Vector3(block_width/width,
					FORT_LINTEL_HEIGHT/panel_height,pier/FORT_PANEL_DEPTH)),Vector3.ZERO))
	if covered:
		return
	for along: float in [-0.5, 0.5]:
		_emit_parapet(ctx, middle + right * along + out * inset,
			rim_y + FORT_GATE_RISE - (kit.gate_arch_cap_lap if kit.has_role(&"gate.arch") else 0.0), yaw_for_dir(dir))


func gate_top(edge: Vector3i, rim_y: float) -> float:
	var out := Vector2(BuildingMass.DIRS[edge.z])
	var right := Vector2(right_of(edge.z))
	var centre := (Vector2(edge.x, edge.y) + Vector2(0.5, 0.5) + out * 0.5
		+ right * float(FORT_GATE_SPAN - 1) * 0.5) * kit.module_width
	var half := right.abs() * float(FORT_GATE_SPAN) * kit.module_width * 0.5 \
		+ out.abs() * FORT_GATE_PIER_SIZE
	var footprint := Rect2(centre - half, half * 2.0).grow(-0.001)
	var top := rim_y + FORT_GATE_RISE
	for solid: Dictionary in overhead_solids:
		if bool(solid.get("open", false)):
			continue
		var box: AABB = solid.bounds
		if box.position.y <= rim_y + 0.001 or box.position.y >= top:
			continue
		if footprint.intersects(Rect2(Vector2(box.position.x, box.position.z),
				Vector2(box.size.x, box.size.z))):
			top = box.position.y
	return top


## Side 0 faces +v, side 1 faces -v, where v is across the ridge.
## Legacy authored tight roofs retain both sides unless a measured mask exists.
static func tight_eave_sides(wing: Dictionary) -> int:
	return int(wing.get("tight_eave_sides",3 if bool(wing.get("tight_eave",false)) else 0))
