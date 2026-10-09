extends RefCounted
## Growing upper floors (spec docs/superpowers/specs/2026-10-08-growing-upper-floors-design.md).
## On chosen street faces of a growing house each storey above the ground storey
## leans one baked step further over the lane, closed like a room projection.
## Pure: reads masses, kits, catalog and callables; writes only BuildingMass data.

const HOUSE_KNOB := &"growing_house_chance"
const STREET_FACE_KNOB := &"growth_street_face_chance"
const OTHER_FACE_KNOB := &"growth_other_face_chance"
const STEP_KNOB := &"growth_step"
const CAP_KNOB := &"growth_max_lean"
const GAP_KNOB := &"lane_sky_gap"
const BOOST_KNOB := &"growth_gable_front_boost"
## Baked step sizes (native m): 0.5 on bracket.small, 1.0 = the kit jetty on bracket.jetty.
const STEP_SIZES: Array[float] = [0.5, 1.0]
const MAX_STEPS := 4
const LEAN_DEPTHS: Array[float] = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0]
const FRONT_ROLES: Array[StringName] = [&"frontage.floor", &"frontage.return", &"frontage.return_beam",
	&"frontage.corner"]


## The step this kit can carry: a kit-sized step needs the kit's own jetty brace
## spanning exactly that depth; otherwise the light step.
static func carried_step(kit: BuildingKit, step: float) -> float:
	if step > 0.5 and not (kit.has_role(&"bracket.jetty") and is_equal_approx(kit.jetty_depth, step)):
		return 0.5
	return step


static func _own(mass: BuildingMass) -> StringName:
	return StringName(String(mass.stable_id).trim_prefix("kit."))


static func _storey_at(mass: BuildingMass, floor_band: int) -> Dictionary:
	for storey: Dictionary in mass.storeys:
		if int(storey.floor_band) == floor_band:
			return storey
	return {}


## Index of the storey standing at the house datum (else the lowest storey).
static func ground_index(mass: BuildingMass) -> int:
	for index in mass.storeys.size():
		if int(mass.storeys[index].floor_band) == mass.ground_band:
			return index
	return 0 if not mass.storeys.is_empty() else -1


static func _run_key(run: Dictionary) -> String:
	return "%d:%d:%d:%d" % [int(run.dir), int(run.line), int(run.start), int(run.end)]


## Exposed boundary runs of one storey, keyed by _run_key.
static func _exposed_runs(mass: BuildingMass, storey: Dictionary, solid: Callable) -> Dictionary:
	var own := _own(mass)
	var blocked := func(cell: Vector2i, band: int) -> bool: return bool(solid.call(own, cell, band))
	var out := {}
	for run: Dictionary in BuildingKitAssembler.boundary_runs(storey.cells,
			BuildingKitAssembler.exposure_for(mass, int(storey.floor_band),
				int(storey.get("bands", 2)), blocked)):
		if bool(run.exposed):
			out[_run_key(run)] = run
	return out


## A face fronts a street when every edge's outward column is public air at
## some band from the house datum up to the storey (lane, stair, court, plaza).
## Upper bands over a lane are not guaranteed PUBLIC_AIR, so this is a column test.
static func _is_street(mass: BuildingMass, run: Dictionary, floor_band: int, street: Callable) -> bool:
	var dir := int(run.dir)
	for along in range(int(run.start), int(run.end)):
		var outward: Vector2i = BuildingKitAssembler._inside_cell(dir, int(run.line), along) \
			+ BuildingMass.DIRS[dir]
		var open := false
		for band in range(mass.ground_band, floor_band + 2):
			open = open or bool(street.call(outward, band))
		if not open:
			return false
	return true


## Faces that can grow: an exposed run on the first storey above the ground
## storey, identical (guardrail 5, per edge run) on the storey below, followed
## upward while each next storey repeats the same run. Sorted by key.
static func face_chains(mass: BuildingMass, solid: Callable, street: Callable) -> Array[Dictionary]:
	var chains: Array[Dictionary] = []
	var g := ground_index(mass)
	if g < 0:
		return chains
	var ground: Dictionary = mass.storeys[g]
	var first := _storey_at(mass, int(ground.floor_band) + int(ground.get("bands", 2)))
	if first.is_empty():
		return chains
	# Exposed runs per storey band, computed once for every chain key.
	var runs_at := {}
	var first_runs := _exposed_runs(mass, first, solid)
	for key: String in first_runs:
		var run: Dictionary = first_runs[key]
		# Guardrail 5 per edge: every edge of the face is also a boundary edge of the
		# storey below (exposed there or not: a lower neighbour or roof may cover it).
		var matching := true
		for along in range(int(run.start), int(run.end)):
			var cell := BuildingKitAssembler._inside_cell(int(run.dir), int(run.line), along)
			if not (ground.cells as Dictionary).has(cell) \
					or (ground.cells as Dictionary).has(cell + BuildingMass.DIRS[int(run.dir)]):
				matching = false
		if not matching:
			continue
		var storeys: Array[int] = [mass.storeys.find(first)]
		var band := int(first.floor_band) + int(first.get("bands", 2))
		while true:
			var upper := _storey_at(mass, band)
			if upper.is_empty():
				break
			if not runs_at.has(band):
				runs_at[band] = _exposed_runs(mass, upper, solid)
			if not (runs_at[band] as Dictionary).has(key):
				break
			storeys.append(mass.storeys.find(upper))
			band += int(upper.get("bands", 2))
		chains.append({"dir": int(run.dir), "line": int(run.line), "start": int(run.start),
			"end": int(run.end), "storeys": storeys,
			"street": _is_street(mass, run, int(first.floor_band), street),
			"first_band": int(first.floor_band), "start_convex": bool(run.start_convex),
			"end_convex": bool(run.end_convex),
			"key": "%s|%s" % [mass.stable_id, key]})
	chains.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.key) < String(b.key))
	return chains


## Two stacked storeys (ground + one above) and at least one exposed face.
static func house_eligible(mass: BuildingMass, solid: Callable, street: Callable) -> bool:
	return not String(mass.stable_id).contains("wall-room") \
		and not face_chains(mass, solid, street).is_empty()


## Eligibility first, so an ineligible house consumes no roll (rolls are keyed,
## so this changes nothing for other houses either).
static func house_grows(character: TownCharacter, mass: BuildingMass, solid: Callable,
		street: Callable) -> bool:
	if character == null or character.value(HOUSE_KNOB) <= 0.0 \
			or not house_eligible(mass, solid, street):
		return false
	return character.chance(HOUSE_KNOB, String(mass.stable_id))


const CLEARANCE := preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")


static func _edges(chain: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var dir := int(chain.dir)
	for along in range(int(chain.start), int(chain.end)):
		out.append(BuildingMass.edge_key(BuildingKitAssembler._inside_cell(dir, int(chain.line), along), dir))
	return out


## Leans every growing house in `masses` (already in sorted id order). Returns
## {leans, registry, rejections}: one entry per leaned storey face, the accepted
## lean per Vector4i(cell.x, cell.z, dir, band) for facing-gap checks by later
## fitters, and every withdrawn step with its cause. Faces step in FRONTS: a
## rolled face pulls the faces it meets at a convex corner (one hop), and the
## front steps together, its corners wrapped.
static func fit(masses: Array[BuildingMass], kits: Dictionary, base: BuildingKit,
		catalog: EnvironmentCatalog, character: TownCharacter, air: Array[Dictionary],
		towers: Array[Dictionary], reserved: Callable, solid: Callable,
		street: Callable) -> Dictionary:
	var leans: Array[Dictionary] = []
	var ctx := {"catalog": catalog, "air": air, "towers": towers, "reserved": reserved,
		"solid": solid, "registry": {}, "obstacles": [], "gap": 0.0, "kit": base, "rejections": []}
	if character == null or not masses.any(func(m: BuildingMass) -> bool: return m.grows):
		return {"leans": leans, "registry": ctx.registry, "rejections": ctx.rejections}
	ctx.gap = character.value(GAP_KNOB)
	ctx.obstacles = _obstacles(masses, kits, base, catalog, towers, solid)
	var members: Array[Dictionary] = []
	for mass: BuildingMass in masses:
		if not mass.grows or not kits.has(_own(mass)):
			continue
		var kit: BuildingKit = kits[_own(mass)]
		if not kit.has_role(StringName("frontage.return.%s" % BuildingKitAssembler.lean_suffix(STEP_SIZES[0]))):
			continue
		for chain: Dictionary in face_chains(mass, solid, street):
			var knob := STREET_FACE_KNOB if bool(chain.street) else OTHER_FACE_KNOB
			members.append({"mass": mass, "chain": chain, "kit": kit,
				"seed": character.chance(knob, String(chain.key))})
	for front: Dictionary in fronts(members):
		_fit_front(front, character, ctx, leans)
	return {"leans": leans, "registry": ctx.registry, "rejections": ctx.rejections}


## The lattice vertex at one end of a chain's run.
static func _point(chain: Dictionary, at_end: bool) -> Vector2i:
	var along := int(chain.end) if at_end else int(chain.start)
	return Vector2i(int(chain.line), along) if int(chain.dir) % 2 == 0 else Vector2i(along, int(chain.line))


## Joins between candidate faces: two faces of one house that meet at a convex
## corner of the first upper storey (same first band) wrap (Task 6 adds joints).
static func _joins(members: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in members.size():
		for b in range(a + 1, members.size()):
			var ca: Dictionary = members[a].chain
			var cb: Dictionary = members[b].chain
			if members[a].mass != members[b].mass or int(ca.dir) % 2 == int(cb.dir) % 2 \
					or int(ca.first_band) != int(cb.first_band):
				continue
			for a_end: bool in [false, true]:
				for b_end: bool in [false, true]:
					if _point(ca, a_end) == _point(cb, b_end) \
							and bool(ca.end_convex if a_end else ca.start_convex) \
							and bool(cb.end_convex if b_end else cb.start_convex):
						out.append({"a": a, "a_end": a_end, "b": b, "b_end": b_end, "kind": &"wrap"})
	return out


## Seeds and their direct join partners; one front per connected component that
## holds a seed (pulling is one hop: a partner pulls nothing further unless it is a
## seed itself). Members sorted by chain key (the first is the leader).
static func fronts(members: Array[Dictionary]) -> Array[Dictionary]:
	var joins := _joins(members)
	var keep := {}
	for m in members.size():
		if bool(members[m].seed):
			keep[m] = true
	for join: Dictionary in joins:
		if bool(members[join.a].seed):
			keep[join.b] = true
		if bool(members[join.b].seed):
			keep[join.a] = true
	var root := {}
	for m: int in keep:
		root[m] = m
	var find := func(m: int, self_ref: Callable) -> int:
		return m if int(root[m]) == m else int(self_ref.call(int(root[m]), self_ref))
	for join: Dictionary in joins:
		if keep.has(join.a) and keep.has(join.b):
			root[find.call(join.a, find)] = find.call(join.b, find)
	var groups := {}
	for m: int in keep:
		var r: int = find.call(m, find)
		if not groups.has(r):
			groups[r] = []
		(groups[r] as Array).append(m)
	var out: Array[Dictionary] = []
	for r: int in groups:
		var ids: Array = groups[r]
		if not ids.any(func(m: int) -> bool: return bool(members[m].seed)):
			continue
		ids.sort_custom(func(x: int, y: int) -> bool:
			return String(members[x].chain.key) < String(members[y].chain.key))
		var index := {}
		var front_members: Array[Dictionary] = []
		for m: int in ids:
			index[m] = front_members.size()
			front_members.append(members[m])
		var front_joins: Array[Dictionary] = []
		for join: Dictionary in joins:
			if index.has(join.a) and index.has(join.b):
				front_joins.append({"a": index[join.a], "a_end": join.a_end, "b": index[join.b],
					"b_end": join.b_end, "kind": join.kind})
		out.append({"members": front_members, "joins": front_joins})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return String(x.members[0].chain.key) < String(y.members[0].chain.key))
	return out


## One front. The leader (first active member) sets the step its kit carries and the
## cap; a member that leaves the front is dropped and the rest refit (the leader may
## change). Members that left are fitted alone afterwards if they were seeds.
static func _fit_front(front: Dictionary, character: TownCharacter, ctx: Dictionary,
		out: Array[Dictionary]) -> void:
	var active: Array[int] = []
	for m in (front.members as Array).size():
		active.append(m)
	var left: Array[int] = []
	var leans: Array[float] = []
	while not active.is_empty():
		var step := _front_step(front.members[active[0]], character, ctx)
		if not STEP_SIZES.has(step):
			return
		var cap := step * float(mini(MAX_STEPS, floori(character.value(CAP_KNOB) / step + 0.0001)))
		var result := _front_profile(front, active, step, cap, ctx)
		if int(result.leaves) < 0:
			leans = result.leans
			break
		active.erase(int(result.leaves))
		left.append(int(result.leaves))
	for m: int in active:
		var member: Dictionary = front.members[m]
		var profile: Array[float] = []
		var closures: Array = []
		for k in (member.chain.storeys as Array).size():
			profile.append(leans[k])
			closures.append(_closures(front, active, m, k, ctx))
		ctx.kit = member.kit
		_commit(member.mass, member.kit, member.chain, profile, ctx, out, closures)
	for m: int in left:
		if bool(front.members[m].seed):
			_fit_front({"members": [front.members[m]], "joins": []}, character, ctx, out)


## The step a leader carries (Task 8 adds the eave fallback here).
static func _front_step(leader: Dictionary, character: TownCharacter, _ctx: Dictionary) -> float:
	return carried_step(leader.kit, float(String(character.pick(STEP_KNOB, String(leader.mass.stable_id)))))


## Monotone cumulative steps for a fixed set of active members (index k = k-th
## storey above the shared first upper storey). A failing step is withdrawn for the
## whole front (every member holds). Returns {leans, leaves: -1}, or {leaves: m} when
## member m cannot hold a storey, or cannot take the first step while others are
## active (it leaves; the caller refits). A lone member that cannot hold drops the
## cap one step and refits (no inward ledge).
static func _front_profile(front: Dictionary, active: Array[int], step: float, cap: float,
		ctx: Dictionary) -> Dictionary:
	var depth := 0
	for m: int in active:
		depth = maxi(depth, (front.members[m].chain.storeys as Array).size())
	var leans: Array[float] = []
	leans.resize(depth)
	leans.fill(0.0)
	var face_cap := cap
	var k := 0
	while k < depth:
		var held := 0.0 if k == 0 else leans[k - 1]
		var want := minf(float(k + 1) * step, face_cap)
		var fault := _front_fault(front, active, k, want, held, ctx) if want > held else {"held": true}
		if fault.is_empty():
			leans[k] = want
			k += 1
			continue
		if not fault.has("held"):
			_reject(ctx, front, fault, k, want)
		face_cap = held
		if held <= 0.0:
			if active.size() > 1 and fault.has("member"):
				return {"leaves": int(fault.member)}
			break
		var hold := _front_fault(front, active, k, held, held, ctx)
		if hold.is_empty():
			leans[k] = held
			k += 1
			continue
		_reject(ctx, front, hold, k, held)
		if active.size() > 1:
			return {"leaves": int(hold.member)}
		face_cap = held - step
		leans.fill(0.0)
		k = 0
	return {"leans": leans, "leaves": -1}


## The first active member present at storey k that fails, as {member, cause}, or {}.
static func _front_fault(front: Dictionary, active: Array[int], k: int, lean: float, base: float,
		ctx: Dictionary) -> Dictionary:
	for m: int in active:
		var member: Dictionary = front.members[m]
		if k >= (member.chain.storeys as Array).size():
			continue
		ctx.kit = member.kit
		var closures := _closures(front, active, m, k, ctx)
		var cause := &"ends" if closures.has(&"blocked") \
			else _fault(member.mass, member.chain, k, lean, base, ctx, closures)
		if cause != &"":
			return {"member": m, "cause": cause}
	return {}


static func _reject(ctx: Dictionary, front: Dictionary, fault: Dictionary, k: int, lean: float) -> void:
	ctx.rejections.append({"chain": String(front.members[int(fault.member)].chain.key),
		"storey": k, "lean": lean, "cause": fault.cause})


## [left, right] closure kinds of member m at storey k (left = the centres.front()
## end; a piece's right points along +along for dirs 1 and 2).
static func _closures(front: Dictionary, active: Array[int], m: int, k: int, ctx: Dictionary) -> Array:
	var start := _end_kind(front, active, m, false, k, ctx)
	var end := _end_kind(front, active, m, true, k, ctx)
	var dir := int(front.members[m].chain.dir)
	return [start, end] if dir == 1 or dir == 2 else [end, start]


## How one end closes at storey k: a join to an active member present at k gives
## its kind; otherwise &"return" where the end is open, else &"blocked".
static func _end_kind(front: Dictionary, active: Array[int], m: int, at_end: bool, k: int,
		ctx: Dictionary) -> StringName:
	for join: Dictionary in front.joins:
		var partner := -1
		if int(join.a) == m and bool(join.a_end) == at_end:
			partner = int(join.b)
		elif int(join.b) == m and bool(join.b_end) == at_end:
			partner = int(join.a)
		if partner >= 0 and active.has(partner) \
				and k < (front.members[partner].chain.storeys as Array).size():
			return StringName(join.kind)
	var member: Dictionary = front.members[m]
	return &"return" if _end_open(member.mass, member.chain, at_end, k, ctx) else &"blocked"


## The former guardrail 4, per end: the run at storey k is the chain's run and
## convex at this end, nothing stands beside or diagonally beyond it, and the
## perpendicular face at this corner does not step.
static func _end_open(mass: BuildingMass, chain: Dictionary, at_end: bool, k: int, ctx: Dictionary) -> bool:
	var storey: Dictionary = mass.storeys[chain.storeys[k]]
	var dir := int(chain.dir)
	var convex := false
	for run: Dictionary in BuildingKitAssembler.boundary_runs(storey.cells):
		if int(run.dir) == dir and int(run.line) == int(chain.line) \
				and int(run.start) == int(chain.start) and int(run.end) == int(chain.end):
			convex = bool(run.end_convex if at_end else run.start_convex)
	if not convex:
		return false
	var along := Vector2i(0, 1) if dir % 2 == 0 else Vector2i(1, 0)
	var sign := 1 if at_end else -1
	var cell := BuildingKitAssembler._inside_cell(dir, int(chain.line),
		int(chain.end) - 1 if at_end else int(chain.start))
	var perp := BuildingMass.DIRS.find(along * sign)
	if float((storey.get("wall_offsets", {}) as Dictionary).get(BuildingMass.edge_key(cell, perp), 0.0)) > 0.0:
		return false
	var side := cell + along * sign
	var diagonal: Vector2i = side + BuildingMass.DIRS[dir]
	var solid: Callable = ctx.solid
	var own := _own(mass)
	for b in [int(storey.floor_band), int(storey.floor_band) + 1]:
		if bool(solid.call(own, side, b)) or bool(solid.call(own, diagonal, b)) \
				or mass.cells_at_band(b).has(diagonal):
			return false
	return true


## The first guardrail storey k fails at `lean` over `base` with these end
## closures, or &"" when it fits (ends are checked by _front_fault).
static func _fault(mass: BuildingMass, chain: Dictionary, k: int, lean: float, base: float,
		ctx: Dictionary, closures: Array = [&"return", &"return"]) -> StringName:
	var storey: Dictionary = mass.storeys[chain.storeys[k]]
	if storey.material != BuildingMass.MATERIAL_TIMBER or bool(storey.get("inset", false)) \
			or bool(storey.get("retaining", false)) or bool(storey.get("fortified", false)):
		return &"material"
	if not _no_portal(mass, chain, k):
		return &"portal"
	if not _columns_free(mass, chain, k, ctx):
		return &"columns"
	if not gap_ok(ctx.registry, ctx.solid, _own(mass), _edges(chain), int(chain.dir),
			int(storey.floor_band), lean, ctx.kit, float(ctx.gap)):
		return &"gap"
	var candidate := _candidate(mass, ctx.kit, chain, k, lean, base, ctx.solid, closures)
	return _parts_fault(mass, candidate, crown_index(mass, chain, k), ctx)


## One storey's leaned front: its projection record, outer body box and pieces.
static func _candidate(mass: BuildingMass, kit: BuildingKit, chain: Dictionary, k: int,
		lean: float, base: float, solid: Callable, closures: Array = [&"return", &"return"]) -> Dictionary:
	var index: int = chain.storeys[k]
	var storey: Dictionary = mass.storeys[index]
	var dir := int(chain.dir)
	var edges := _edges(chain)
	var centres: Array[Vector2] = []
	for edge: Vector3i in edges:
		centres.append(Vector2(edge.x, edge.y) + Vector2.ONE * .5 + Vector2(BuildingMass.DIRS[dir]) * .5)
	var right := Vector2(BuildingKitAssembler.right_of(dir))
	centres.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.dot(right) < b.dot(right))
	var band := int(storey.floor_band)
	var projection := {"edges": edges, "centres": centres, "dir": dir, "depth": lean,
		"base": base, "band": band, "growth": true, "closures": closures}
	var at: Vector2 = centres.front() * kit.module_width
	var pose := Transform3D(Basis(Vector3.UP, BuildingKitAssembler.yaw_for_dir(dir)),
		Vector3(at.x, band * kit.band_height(), at.y))
	var body := AABB(Vector3(-kit.module_width * .5, 0, 0),
		Vector3(centres.size() * kit.module_width, kit.storey_height, lean + kit.wall_face))
	return {"index": index, "k": k, "projection": projection, "edges": edges, "centres": centres,
		"band": band, "bands": int(storey.get("bands", 2)),
		"first_band": int(chain.first_band), "pose": pose, "bounds": pose * body,
		"parts": _assembler(mass, kit, solid).face_parts(mass, index, projection)}


## An assembler that sees other buildings as the final assembly does, so a
## candidate's slots and an obstacle's parts match what is finally built.
static func _assembler(mass: BuildingMass, kit: BuildingKit, solid: Callable) -> BuildingKitAssembler:
	var assembler := BuildingKitAssembler.new(kit)
	if solid.is_valid():
		var own := _own(mass)
		assembler.external_blocked = func(cell: Vector2i, band: int) -> bool:
			return bool(solid.call(own, cell, band))
	return assembler


## Decor `apply` moves out with a stepping face: on the face (same dir, a module
## centre of the run) and standing within bands [lo_band, hi_band).
static func _moves(item: Dictionary, dir: int, centres: Array, lo_band: int, hi_band: int,
		kit: BuildingKit) -> bool:
	if not item.has("dir") or int(item.dir) != dir or not centres.has(item.get("centre")):
		return false
	var y := float(item.get("y", -INF))
	return y >= lo_band * kit.band_height() - .01 and y < hi_band * kit.band_height()


## Writes one face's steps into its house (wall offsets, projection with closures,
## storey growth, decor on the face moved out) and returns the candidates (each
## lists the decor it moved under "moved").
static func apply(mass: BuildingMass, kit: BuildingKit, chain: Dictionary, profile: Array[float],
		closures: Array, solid := Callable()) -> Array[Dictionary]:
	var dir := int(chain.dir)
	var out: Array[Dictionary] = []
	for k in profile.size():
		var lean := profile[k]
		if lean <= 0.0:
			continue
		var base := 0.0 if k == 0 else profile[k - 1]
		var candidate := _candidate(mass, kit, chain, k, lean, base, solid, closures[k])
		var storey: Dictionary = mass.storeys[candidate.index]
		var offsets: Dictionary = storey.get("wall_offsets", {})
		for edge: Vector3i in candidate.edges:
			offsets[edge] = lean / kit.module_width
		storey["wall_offsets"] = offsets
		var fronts_at: Array = storey.get("projections", [])
		fronts_at.append(candidate.projection)
		storey["projections"] = fronts_at
		var leaning: Dictionary = storey.get("growth", {})
		leaning[dir] = lean
		storey["growth"] = leaning
		# Decor on the face of this storey moves out with it (as projections do).
		var moved: Array = []
		for item: Dictionary in mass.decor:
			if _moves(item, dir, candidate.centres, candidate.band, candidate.band + candidate.bands, kit):
				moved.append(item)
		for item: Dictionary in moved:
			item.centre += Vector2(BuildingMass.DIRS[dir]) * lean / kit.module_width
			item.y = float(item.y) - BuildingKitAssembler.OFFSET_WALL_DROP
		candidate["moved"] = moved
		out.append(candidate)
	return out


static func _commit(mass: BuildingMass, kit: BuildingKit, chain: Dictionary,
		profile: Array[float], ctx: Dictionary, out: Array[Dictionary], closures: Array) -> void:
	# Own ornaments the new braces/strips meet yield: remove them and their parts.
	for k in profile.size():
		if profile[k] <= 0.0:
			continue
		var probe := _candidate(mass, kit, chain, k, profile[k], 0.0 if k == 0 else profile[k - 1],
			ctx.solid, closures[k])
		_parts_fault(mass, probe, crown_index(mass, chain, k), ctx)
		for obstacle: Dictionary in probe.yields:
			(obstacle.host as BuildingMass).decor.erase(obstacle.decor)
			_drop_decor(ctx, obstacle.decor)
	var dir := int(chain.dir)
	var catalog: EnvironmentCatalog = ctx.catalog
	for candidate: Dictionary in apply(mass, kit, chain, profile, closures, ctx.solid):
		var k := int(candidate.k)
		# Moved decor stands somewhere else now: refresh its obstacle bounds.
		for item: Dictionary in candidate.moved:
			_drop_decor(ctx, item)
			var assembly := {"mass": mass, "out": [] as Array[Dictionary], "serial": 0}
			_assembler(mass, kit, ctx.solid)._assemble_decor(assembly, item)
			for part: Dictionary in assembly.out:
				var obstacle := _obstacle(mass, part, catalog)
				obstacle["decor"] = item
				obstacle["host"] = mass
				ctx.obstacles.append(obstacle)
		for band in range(candidate.band, candidate.band + candidate.bands):
			for edge: Vector3i in candidate.edges:
				ctx.registry[Vector4i(edge.x, edge.y, dir, band)] = profile[k]
		for part: Dictionary in candidate.parts:
			ctx.obstacles.append({"owner": &"", "role": String(part.role), "roof_index": -1,
				"bounds": part.transform * catalog.descriptor(part.asset_id).measured_aabb})
		out.append({"host": mass.stable_id, "dir": dir, "band": candidate.band, "lean": profile[k],
			"base": candidate.projection.base, "edges": candidate.edges, "bounds": candidate.bounds,
			"chain": chain.key, "closures": closures[k]})


## Marks every obstacle record of one decor item gone.
static func _drop_decor(ctx: Dictionary, item: Dictionary) -> void:
	for other: Dictionary in ctx.obstacles:
		if other.has("decor") and is_same(other.decor, item):
			other["gone"] = true


# --- guardrails -------------------------------------------------------------

## Furthest facing facade (in modules) a lane is measured to for the sky gap.
const MAX_LANE_MODULES := 4
## Own-house parts a lean must also clear (the rest of the house is its host).
const OWN_OBSTACLES: Array[String] = ["awning", "ivy.", "bay.", "deck.platform", "rail.",
	"chimney.", "roof.", "trim.ridge", "trim.barge", "gable."]


## Every house's assembled parts plus towers; accepted leans are appended by _commit.
static func _obstacles(masses: Array[BuildingMass], kits: Dictionary, base: BuildingKit,
		catalog: EnvironmentCatalog, towers: Array[Dictionary], solid: Callable) -> Array:
	var out: Array = []
	for mass: BuildingMass in masses:
		var assembler := _assembler(mass, kits.get(_own(mass), base), solid)
		var decor := mass.decor.duplicate()
		mass.decor.clear()
		var parts := assembler.assemble(mass)
		mass.decor.assign(decor)
		for part: Dictionary in parts:
			out.append(_obstacle(mass, part, catalog))
		for item: Dictionary in decor:
			var ctx := {"mass": mass, "out": [] as Array[Dictionary], "serial": 0}
			assembler._assemble_decor(ctx, item)
			for part: Dictionary in ctx.out:
				var obstacle := _obstacle(mass, part, catalog)
				obstacle["decor"] = item
				obstacle["host"] = mass
				out.append(obstacle)
	for tower: Dictionary in towers:
		out.append({"owner": &"", "role": "tower", "roof_index": -1, "bounds": tower.bounds})
	return out


static func _obstacle(mass: BuildingMass, part: Dictionary, catalog: EnvironmentCatalog) -> Dictionary:
	return {"owner": mass.stable_id, "role": String(part.role),
		"roof_index": int(part.get("roof_index", -1)),
		"bounds": part.transform * catalog.descriptor(part.asset_id).measured_aabb}


## union_index of the roof wing whose eave or gable closes this storey's face (else -1).
static func crown_index(mass: BuildingMass, chain: Dictionary, k: int) -> int:
	var storey: Dictionary = mass.storeys[chain.storeys[k]]
	var top := int(storey.floor_band) + int(storey.get("bands", 2))
	var dir := int(chain.dir)
	for wing: Dictionary in mass.roofs:
		if int(wing.eave_band) != top:
			continue
		var rect: Rect2i = wing.rect
		var boundary := rect.end.x if dir == 0 else rect.end.y if dir == 1 \
			else rect.position.x if dir == 2 else rect.position.y
		if boundary != int(chain.line):
			continue
		if _edges(chain).all(func(e: Vector3i) -> bool: return rect.has_point(Vector2i(e.x, e.y))):
			return int(wing.get("union_index", -1))
	return -1


static func _blocks(obstacle: Dictionary, mass: BuildingMass, crown: int) -> bool:
	if obstacle.owner != mass.stable_id:
		return true
	if crown >= 0 and int(obstacle.roof_index) == crown:
		return false
	for prefix: String in OWN_OBSTACLES:
		if String(obstacle.role).begins_with(prefix):
			return true
	return false


## The one "is this box blocked" loop shared with the town's ornament fitter:
## false when `box` meets the bounds of any obstacle `blocks` keeps.
static func clear_of(box: AABB, obstacles: Array, blocks: Callable) -> bool:
	for obstacle: Dictionary in obstacles:
		if bool(blocks.call(obstacle)) and box.intersects(obstacle.bounds):
			return false
	return true


## Contact this shallow (native m) is touching, not a collision.
const TOUCH := 0.05
## The house's own ornaments that yield (are removed) where a new step's pieces meet them.
const YIELD_DECOR: Array[StringName] = [&"ivy", &"ivy_corner", &"window_box", &"awning"]


static func contact_clear(box: AABB, other: AABB) -> bool:
	if not box.intersects(other):
		return true
	var overlap := box.intersection(other).size
	return minf(overlap.x, minf(overlap.y, overlap.z)) <= TOUCH


## The stepping storey's own face: its pieces (and a bay or ornament on it) move out with it.
## Its stepping storeys below (same face, same profile) carry theirs out too, so the
## slab spans the face from the chain's first storey up to this one.
static func _face_slab(candidate: Dictionary, kit: BuildingKit) -> AABB:
	var n := (candidate.centres as Array).size()
	var below := int(candidate.get("k", 0)) * kit.storey_height
	return candidate.pose * AABB(Vector3(-kit.module_width * .5 - .3, -below, -.6),
		Vector3(n * kit.module_width + .6, kit.storey_height + below,
			float(candidate.projection.depth) + 1.8))


static func _obstacle_cause(obstacle: Dictionary, mass: BuildingMass) -> StringName:
	if obstacle.owner == mass.stable_id:
		return &"obstacle.own"
	if obstacle.owner == &"":
		return &"obstacle.tower" if String(obstacle.role) == "tower" else &"obstacle.lean"
	var token := String(obstacle.owner).trim_prefix("kit.")
	return StringName("obstacle.%s" % token.get_slice(".", 0))


# G1 + G3 with the false blockers removed: touching contact is clear, the face's own
# bays and the ornaments `apply` moves ride out with it, the house's other yielding
# ornaments yield.
static func _parts_fault(mass: BuildingMass, candidate: Dictionary, crown: int,
		ctx: Dictionary) -> StringName:
	var catalog: EnvironmentCatalog = ctx.catalog
	var slab := _face_slab(candidate, ctx.kit)
	var yields: Array = []
	candidate["yields"] = yields
	for part: Dictionary in candidate.parts:
		var local: AABB = catalog.descriptor(part.asset_id).measured_aabb
		if CLEARANCE.intersects_air(local, part.transform, ctx.air):
			return &"air"
		var box: AABB = (part.transform * local).grow(-0.002)
		for obstacle: Dictionary in ctx.obstacles:
			if bool(obstacle.get("gone", false)) or not _blocks(obstacle, mass, crown) \
					or contact_clear(box, obstacle.bounds):
				continue
			if obstacle.owner == mass.stable_id:
				if obstacle.has("decor"):
					# Only decor `apply` moves out with this face rides; the house's
					# other ornaments of the yielding kinds yield (are removed).
					if _moves(obstacle.decor, int(candidate.projection.dir), candidate.centres,
							int(candidate.first_band), int(candidate.band) + int(candidate.bands), ctx.kit):
						continue
					if StringName(obstacle.decor.kind) in YIELD_DECOR:
						if not yields.has(obstacle):
							yields.append(obstacle)
						continue
				elif String(obstacle.role).begins_with("bay.") \
						and slab.has_point((obstacle.bounds as AABB).get_center()):
					continue
			return _obstacle_cause(obstacle, mass)
	return &""


# G2: distance to the facing facade across the lane, minus both leans, keeps the sky gap.
static func gap_ok(registry: Dictionary, solid: Callable, own: StringName, edges: Array[Vector3i],
		dir: int, band: int, depth: float, kit: BuildingKit, gap: float) -> bool:
	var step: Vector2i = BuildingMass.DIRS[dir]
	var back := (dir + 2) % 4
	for edge: Vector3i in edges:
		var cell := Vector2i(edge.x, edge.y)
		for n in range(1, MAX_LANE_MODULES + 1):
			var column := cell + step * n
			if not (bool(solid.call(own, column, band)) or bool(solid.call(own, column, band + 1))):
				continue
			var facing := maxf(float(registry.get(Vector4i(column.x, column.y, back, band), 0.0)),
				float(registry.get(Vector4i(column.x, column.y, back, band + 1), 0.0)))
			if float(n - 1) * kit.module_width - depth - facing < gap - 0.0001:
				return false
			break
	return true


# G3: reserved grid claims (structure, service voids, other owners, passages) beyond the face.
static func _columns_free(mass: BuildingMass, chain: Dictionary, k: int, ctx: Dictionary) -> bool:
	var storey: Dictionary = mass.storeys[chain.storeys[k]]
	var band := int(storey.floor_band)
	for edge: Vector3i in _edges(chain):
		var outward := Vector2i(edge.x, edge.y) + BuildingMass.DIRS[int(chain.dir)]
		for b in [band, band + 1]:
			if bool((ctx.reserved as Callable).call(_own(mass), outward, b)):
				return false
	return true


# G6: a storey whose face carries a door, a skywalk/bridge-house portal or a
# passage, or whose wall bears a balcony's rakers (it or the storey above), stays put.
static func _no_portal(mass: BuildingMass, chain: Dictionary, k: int) -> bool:
	var storey: Dictionary = mass.storeys[chain.storeys[k]]
	if bool(storey.get("bears_balcony", false)):
		return false
	var above := _storey_at(mass, int(storey.floor_band) + int(storey.get("bands", 2)))
	if not above.is_empty() and bool(above.get("bears_balcony", false)):
		return false
	var passages: Dictionary = storey.get("passage_edges", {})
	for edge: Vector3i in _edges(chain):
		if passages.has(edge):
			return false
		if StringName(storey.openings.get(edge, storey.default_opening)) \
				in [BuildingMass.OPENING_DOOR, BuildingMass.OPENING_NONE]:
			return false
	return true
