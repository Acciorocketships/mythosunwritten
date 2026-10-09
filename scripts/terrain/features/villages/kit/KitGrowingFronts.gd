extends RefCounted
## Growing upper floors (spec docs/superpowers/specs/2026-10-08-growing-upper-floors-design.md,
## Amendment 2): on chosen exposed faces of a growing house the roof and the top storey
## stay on the lot line and each lower storey steps one baked step further IN (the
## ground storey narrowest), every upper storey overhanging on the kit's jetty braces.
## Pure: reads masses, kits, catalog and callables; writes only BuildingMass data.

const HOUSE_KNOB := &"growing_house_chance"
const STREET_FACE_KNOB := &"growth_street_face_chance"
const OTHER_FACE_KNOB := &"growth_other_face_chance"
const STEP_KNOB := &"growth_step"
const CAP_KNOB := &"growth_max_lean"
const GAP_KNOB := &"lane_sky_gap"
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
## upward while each next storey repeats the same run (`ground` is the ground
## storey's index: under step-in it stands in too). Sorted by key.
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
			"end": int(run.end), "storeys": storeys, "ground": g,
			"street": _is_street(mass, run, int(first.floor_band), street),
			"first_band": int(first.floor_band), "start_convex": bool(run.start_convex),
			"end_convex": bool(run.end_convex),
			"key": "%s|%s" % [mass.stable_id, key]})
	chains.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.key) < String(b.key))
	return chains


## Houses growth never touches: the town's retaining wall rooms and landmark / prefab
## houses (ruling d).
static func _excluded(mass: BuildingMass) -> bool:
	var id := String(mass.stable_id)
	return id.contains("wall-room") or id.contains("landmark") or id.contains("prefab")


## Two stacked storeys (ground + one above) and at least one exposed face.
static func house_eligible(mass: BuildingMass, solid: Callable, street: Callable) -> bool:
	return not _excluded(mass) and not face_chains(mass, solid, street).is_empty()


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


## Steps every growing house in `masses` (already in sorted id order) in. Returns
## {leans, registry, rejections}: one growth record per storey that stands in or
## overhangs, the outward-offset registry later fitters read for facing gaps (always
## empty: growth never steps outward), and every withdrawn step with its cause. Faces
## step in FRONTS: a rolled face pulls the faces it meets at a convex corner (one hop)
## and coplanar row neighbours, and the front steps together, its corners wrapped.
static func fit(masses: Array[BuildingMass], kits: Dictionary, base: BuildingKit,
		catalog: EnvironmentCatalog, character: TownCharacter, air: Array[Dictionary],
		towers: Array[Dictionary], reserved: Callable, solid: Callable,
		street: Callable, grade: Callable = Callable()) -> Dictionary:
	var leans: Array[Dictionary] = []
	var ctx := {"catalog": catalog, "air": air, "towers": towers, "reserved": reserved,
		"solid": solid, "grade": grade, "registry": {}, "obstacles": [], "kit": base, "rejections": [],
		"planned": {}, "yields": {}, "front": {}, "active": [] as Array[int], "masses": {}}
	if character == null or not masses.any(func(m: BuildingMass) -> bool: return m.grows):
		return {"leans": leans, "registry": ctx.registry, "rejections": ctx.rejections}
	for mass: BuildingMass in masses:
		ctx.masses[mass.stable_id] = mass
	ctx.obstacles = _obstacles(masses, kits, base, catalog, towers, solid)
	# Candidate faces come from every eligible house (a terrace row pulls its
	# coplanar neighbours); only growing houses seed a front and draw face rolls.
	var members: Array[Dictionary] = []
	for mass: BuildingMass in masses:
		if not kits.has(_own(mass)) or _excluded(mass):
			continue
		var kit: BuildingKit = kits[_own(mass)]
		if not kit.has_role(StringName("frontage.return.%s" % BuildingKitAssembler.lean_suffix(STEP_SIZES[0]))):
			continue
		for chain: Dictionary in face_chains(mass, solid, street):
			var knob := STREET_FACE_KNOB if bool(chain.street) else OTHER_FACE_KNOB
			members.append({"mass": mass, "chain": chain, "kit": kit,
				"seed": mass.grows and character.chance(knob, String(chain.key))})
	for front: Dictionary in fronts(members):
		_fit_front(front, character, ctx, leans)
	return {"leans": leans, "registry": ctx.registry, "rejections": ctx.rejections}


## The lattice vertex at one end of a chain's run.
static func _point(chain: Dictionary, at_end: bool) -> Vector2i:
	var along := int(chain.end) if at_end else int(chain.start)
	return Vector2i(int(chain.line), along) if int(chain.dir) % 2 == 0 else Vector2i(along, int(chain.line))


## Joins between candidate faces, all on the same first upper storey (rows on
## stepped ground never join): two faces of one house that meet at a convex corner
## wrap; two faces of different houses on one line (same dir), end to start at a
## vertex where each is convex in its own cells, form a terrace-row joint.
static func _joins(members: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in members.size():
		for b in range(a + 1, members.size()):
			var ca: Dictionary = members[a].chain
			var cb: Dictionary = members[b].chain
			if int(ca.first_band) != int(cb.first_band):
				continue
			var same: bool = members[a].mass == members[b].mass
			if same and int(ca.dir) % 2 != int(cb.dir) % 2:
				for a_end: bool in [false, true]:
					for b_end: bool in [false, true]:
						if _point(ca, a_end) == _point(cb, b_end) and _convex(ca, a_end) and _convex(cb, b_end):
							out.append({"a": a, "a_end": a_end, "b": b, "b_end": b_end, "kind": &"wrap"})
			elif not same and int(ca.dir) == int(cb.dir) and int(ca.line) == int(cb.line):
				for a_end: bool in [false, true]:
					var b_end := not a_end
					if _point(ca, a_end) == _point(cb, b_end) and _convex(ca, a_end) and _convex(cb, b_end):
						out.append({"a": a, "a_end": a_end, "b": b, "b_end": b_end, "kind": &"joint"})
	return out


static func _convex(chain: Dictionary, at_end: bool) -> bool:
	return bool(chain.end_convex if at_end else chain.start_convex)


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


## The storeys of a face from its ground storey up.
static func _storeys(chain: Dictionary) -> Array[int]:
	var out: Array[int] = [int(chain.ground)]
	out.append_array(chain.storeys)
	return out


## Storey index of face storey k (k = -1: the ground storey).
static func _storey_index(chain: Dictionary, k: int) -> int:
	return int(chain.ground) if k < 0 else int(chain.storeys[k])


## Offsets (native m, <= 0) of a face's storeys from the ground up for one profile
## (spec Amendment 2): storey k stands `leans[k] - top` inside its line, the ground
## storey `-top`, so the top storey (and the roof on it) never moves.
static func offsets_of(leans: Array[float]) -> Array[float]:
	var top: float = leans.back() if not leans.is_empty() else 0.0
	var out: Array[float] = [-top]
	for lean: float in leans:
		out.append(lean - top)
	return out


## One front. The leader (its first active member that rolled growth) sets the step
## its kit carries and the cap; a member that leaves is dropped and the rest refit.
## Members that left are fitted alone afterwards if they were seeds.
static func _fit_front(front: Dictionary, character: TownCharacter, ctx: Dictionary,
		out: Array[Dictionary]) -> void:
	var active: Array[int] = []
	for m in (front.members as Array).size():
		active.append(m)
	var left: Array[int] = []
	var leans: Array[float] = []
	ctx.front = front
	ctx.active = active
	while not active.is_empty():
		var leader: Dictionary = front.members[_leader(front, active)]
		var step := carried_step(leader.kit, float(String(character.pick(STEP_KNOB, String(leader.mass.stable_id)))))
		if not STEP_SIZES.has(step):
			return
		var cap := step * float(mini(MAX_STEPS, floori(character.value(CAP_KNOB) / step + 0.0001)))
		var result := _front_profile(front, active, step, cap, ctx)
		if int(result.leaves) < 0:
			leans = result.leans
			break
		active.erase(int(result.leaves))
		left.append(int(result.leaves))
	if not leans.is_empty() and leans.max() > 0.0:
		var closures := {}
		for m: int in active:
			closures[m] = _member_closures(front, active, m, ctx)
		# Dressing on every corner panel a member cuts goes before any member is
		# written (a wrapped partner would otherwise move it along its own run).
		for m: int in active:
			_drop_cut_decor(front.members[m], _slice(leans, front.members[m]), closures[m], ctx)
		for m: int in active:
			ctx.kit = front.members[m].kit
			_commit(front.members[m], _slice(leans, front.members[m]), closures[m], ctx, out)
	for m: int in left:
		if bool(front.members[m].seed):
			_fit_front({"members": [front.members[m]], "joins": []}, character, ctx, out)


## The front's leader: its first active member that rolled growth (a pulled
## neighbour never sets the step; Task 6 deferred minor), else its first member.
static func _leader(front: Dictionary, active: Array[int]) -> int:
	for m: int in active:
		if bool(front.members[m].seed):
			return m
	return active[0]


## A member's part of the front's profile (one lean per storey of its chain).
static func _slice(leans: Array[float], member: Dictionary) -> Array[float]:
	var out: Array[float] = []
	out.assign(leans.slice(0, (member.chain.storeys as Array).size()))
	return out


## [left, right] closures of member m per storey from the ground up (index 0 = ground).
static func _member_closures(front: Dictionary, active: Array[int], m: int, ctx: Dictionary) -> Array:
	ctx.kit = front.members[m].kit
	var out: Array = []
	for i in _storeys(front.members[m].chain).size():
		out.append(_closures(front, active, m, i - 1, ctx))
	return out


## The front's monotone capped profile (index k = k-th storey above the ground storey),
## tested at its final step-in offsets: steps run only up to the shortest active
## member's top storey (every member's top is then the same, so joints and wraps stay
## equal at every shared storey; above it every member holds). On a failure the cap
## drops one step for the whole front (the old "hold from the failing storey up"); a
## member failing at the smallest cap leaves when others remain ({leaves: m}). A lone
## member failing there stays flush.
static func _front_profile(front: Dictionary, active: Array[int], step: float, cap: float,
		ctx: Dictionary) -> Dictionary:
	var depth := 0
	var reach := 1000
	for m: int in active:
		var n := (front.members[m].chain.storeys as Array).size()
		depth = maxi(depth, n)
		reach = mini(reach, n)
	var top := minf(cap, step * float(reach))
	while top > 0.0001:
		var leans: Array[float] = []
		for k in depth:
			leans.append(minf(float(k + 1) * step, top))
		var fault := _front_fault(front, active, leans, ctx)
		if fault.is_empty():
			return {"leans": leans, "leaves": -1}
		_reject(ctx, front, fault)
		if top <= step + 0.0001 and active.size() > 1:
			return {"leaves": int(fault.member), "fault": fault}
		top -= step
	var flat: Array[float] = []
	flat.resize(depth)
	flat.fill(0.0)
	return {"leans": flat, "leaves": -1}


## The first active member whose step-in fails at these leans, as {member, cause,
## storey (-1 = ground), depth}, or {} (each member's yielding ornaments are left in
## ctx.yields). Every storey from the ground up is tested at its final offset;
## ctx.planned holds every active member's offsets so opposite faces of one house see
## each other (bearing).
static func _front_fault(front: Dictionary, active: Array[int], leans: Array[float], ctx: Dictionary) -> Dictionary:
	ctx.planned = {}
	for m: int in active:
		var member: Dictionary = front.members[m]
		var offsets := offsets_of(_slice(leans, member))
		var indices := _storeys(member.chain)
		for i in indices.size():
			for edge: Vector3i in _edges(member.chain):
				ctx.planned["%s|%d|%s" % [member.mass.stable_id, indices[i], edge]] = offsets[i]
	for m: int in active:
		var member: Dictionary = front.members[m]
		var own := _slice(leans, member)
		var offsets := offsets_of(own)
		var closures := _member_closures(front, active, m, ctx)
		ctx.kit = member.kit
		for i in offsets.size():
			var base: float = offsets[i - 1] if i > 0 else offsets[i]
			if offsets[i] >= 0.0 and offsets[i] <= base:
				continue
			var cause := &"ends" if (closures[i] as Array).has(&"blocked") \
				else _fault(member.mass, member.chain, i - 1, offsets[i], base, ctx)
			if cause != &"":
				return {"member": m, "cause": cause, "storey": i - 1, "depth": offsets[i],
					"why": (ctx.get("end_why", {}) as Dictionary).get("%s|%d" % [member.chain.key, i - 1], &"")
						if cause == &"ends" else &""}
		var parts := _parts_fault(member, own, closures, ctx)
		if not parts.is_empty():
			parts["member"] = m
			return parts
	return {}


static func _reject(ctx: Dictionary, front: Dictionary, fault: Dictionary) -> void:
	var record := {"chain": String(front.members[int(fault.member)].chain.key),
		"storey": int(fault.storey), "lean": float(fault.depth), "cause": fault.cause}
	if StringName(fault.get("why", &"")) != &"":
		record["why"] = fault.why
	ctx.rejections.append(record)


## [left, right] closure kinds of member m at face storey k (-1 = ground; left = the
## centres.front() end; a piece's right points along +along for dirs 1 and 2).
static func _closures(front: Dictionary, active: Array[int], m: int, k: int, ctx: Dictionary) -> Array:
	var start := _end_kind(front, active, m, false, k, ctx)
	var end := _end_kind(front, active, m, true, k, ctx)
	var dir := int(front.members[m].chain.dir)
	return [start, end] if dir == 1 or dir == 2 else [end, start]


## How one end closes at face storey k (-1 = ground): a join to an active member
## present at k gives its kind; otherwise the step-in end rule (spec Amendment 2).
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
	return _inset_end(member.mass, member.chain, at_end, k, ctx)


## A stepped-in end with no front partner: &"bury" when the house's own cell stands
## beside it at both bands (a strip closes the recess); &"abut" when another building
## (a touching neighbour not stepping with it) stands beside it at both bands: the
## house's own strip closes the recess on the party plane, the neighbour's facade is
## left whole (ruling a; its pieces are tested by _parts_fault); &"return" when the cell
## beside it is open (the perpendicular corner panel shortens); else &"blocked": a cell
## beside it filled at one band only, the perpendicular face already stepped by an
## earlier front, or a door, passage or blank on the corner panel the step would cut. A
## designer bay there yields to a growing house's step (ruling b; dropped by `apply`).
static func _inset_end(mass: BuildingMass, chain: Dictionary, at_end: bool, k: int, ctx: Dictionary) -> StringName:
	var storey: Dictionary = mass.storeys[_storey_index(chain, k)]
	var dir := int(chain.dir)
	var along := Vector2i(0, 1) if dir % 2 == 0 else Vector2i(1, 0)
	var sign := 1 if at_end else -1
	var cell := BuildingKitAssembler._inside_cell(dir, int(chain.line),
		int(chain.end) - 1 if at_end else int(chain.start))
	var side := cell + along * sign
	var bands := range(int(storey.floor_band), int(storey.floor_band) + int(storey.get("bands", 2)))
	var own := 0
	var other := 0
	for b: int in bands:
		if mass.cells_at_band(b).has(side):
			own += 1
		elif bool((ctx.solid as Callable).call(_own(mass), side, b)):
			other += 1
	if own == bands.size():
		return &"bury"
	if other == bands.size():
		return &"abut"
	if own > 0 or other > 0:
		return _blocked_end(ctx, chain, k, &"partial")
	var corner := BuildingMass.edge_key(cell, BuildingMass.DIRS.find(along * sign))
	if float((storey.get("wall_offsets", {}) as Dictionary).get(corner, 0.0)) != 0.0:
		return _blocked_end(ctx, chain, k, &"stepped")
	var opening := StringName(storey.openings.get(corner, storey.default_opening))
	if (storey.get("passage_edges", {}) as Dictionary).has(corner):
		return _blocked_end(ctx, chain, k, &"passage")
	if opening in [BuildingMass.OPENING_DOOR, BuildingMass.OPENING_NONE] \
			or (opening == BuildingMass.OPENING_BAY and not mass.grows):
		return _blocked_end(ctx, chain, k, StringName(opening))
	return &"return"


## Records why an end is blocked (rejection `why`, for the corpus audit).
static func _blocked_end(ctx: Dictionary, chain: Dictionary, k: int, why: StringName) -> StringName:
	if not ctx.has("end_why"):
		ctx["end_why"] = {}
	ctx.end_why["%s|%d" % [chain.key, k]] = why
	return &"blocked"


## The first guardrail face storey k (-1 = ground) fails standing `depth` (<= 0)
## inside its line over a storey standing `base` inside, or &"" when it fits
## (spec Amendment 2 "Guardrails under step-in"; ends are checked by _front_fault).
static func _fault(mass: BuildingMass, chain: Dictionary, k: int, depth: float, base: float,
		ctx: Dictionary) -> StringName:
	var storey: Dictionary = mass.storeys[_storey_index(chain, k)]
	if depth > base and (storey.material != BuildingMass.MATERIAL_TIMBER \
			or bool(storey.get("inset", false)) or bool(storey.get("retaining", false)) \
			or bool(storey.get("fortified", false))):
		return &"material" # an overhanging storey is timber on the kit's jetty
	if not _no_portal(mass, chain, k, depth, base):
		return &"portal"
	if depth < 0.0:
		if not _steps_in(storey, depth, ctx.kit):
			return &"material"
		if k < 0 and not _graded(mass, chain, ctx):
			return &"grade"
		if not _exposed(mass, chain, k, ctx):
			return &"party"
		if not _recess_free(mass, chain, k, ctx):
			return &"columns"
		if not _bears(mass, chain, k, depth, ctx):
			return &"bearing"
		if not _decor_ok(mass, chain, k):
			return &"decor"
	return &""


## A storey that can stand inside its line: two bands, not a terrace skin, sunk or
## abutted course, kit jetty or pent eave; a non-timber storey only by whole modules
## (the kit bakes no stone half strip).
static func _steps_in(storey: Dictionary, depth: float, kit: BuildingKit) -> bool:
	if int(storey.get("bands", 2)) != 2 or bool(storey.get("retaining", false)) \
			or bool(storey.get("fortified", false)) or bool(storey.get("sunk", false)) \
			or bool(storey.get("abutted", false)) or bool(storey.get("inset", false)) \
			or StringName(storey.get("pent_colour", &"")) != &"":
		return false
	if storey.material == BuildingMass.MATERIAL_TIMBER:
		return true
	var modules := -depth / kit.module_width
	return absf(modules - roundf(modules)) < 0.0001


## Grades ctx.grade(cell, dir, band) answers per edge of a ground run (an invalid
## callable: everywhere at grade).
const GRADE_AT := 2 ## the ground outside stands at the floor: whole boards (the walk)
const GRADE_PLINTH := 1 ## off grade, solid bearing under the vacated strip: a stone top
const GRADE_NONE := 0 ## air or a public walk under the strip: no step


## Ruling (e, fix round 2): the ground storey stands in only where every edge of its run
## is at grade or has solid bearing under the strip it vacates (and the kit has the
## stone cap that closes it). Off-grade edges are listed in ctx.plinth[chain key]:
## `apply` trims their boards to the wall and the assembler caps the strip in stone, so
## it reads as the plinth's top, never a board ledge.
static func _graded(mass: BuildingMass, chain: Dictionary, ctx: Dictionary) -> bool:
	var grade: Callable = ctx.get("grade", Callable())
	var plinth: Array[Vector3i] = []
	if grade.is_valid():
		var band := int(mass.storeys[int(chain.ground)].floor_band)
		for edge: Vector3i in _edges(chain):
			var at := int(grade.call(Vector2i(edge.x, edge.y), int(chain.dir), band))
			if at == GRADE_NONE or (at == GRADE_PLINTH and not (ctx.kit as BuildingKit).has_role(&"plinth.cap")):
				return false
			if at == GRADE_PLINTH:
				plinth.append(edge)
	if not ctx.has("plinth"):
		ctx["plinth"] = {}
	ctx.plinth[String(chain.key)] = plinth
	return true


## Party rule: the run is exposed at both bands (no party wall, no touching neighbour
## in front of it, a lower neighbour against the ground storey included).
static func _exposed(mass: BuildingMass, chain: Dictionary, k: int, ctx: Dictionary) -> bool:
	var storey: Dictionary = mass.storeys[_storey_index(chain, k)]
	var band := int(storey.floor_band)
	for edge: Vector3i in _edges(chain):
		var outward := Vector2i(edge.x, edge.y) + BuildingMass.DIRS[int(chain.dir)]
		for b in range(band, band + int(storey.get("bands", 2))):
			if mass.cells_at_band(b).has(outward) or bool((ctx.solid as Callable).call(_own(mass), outward, b)):
				return false
	return true


## G3 under step-in: the recess cells themselves carry no passage, podium or other
## owner's claim (nothing beyond the face matters any more).
static func _recess_free(mass: BuildingMass, chain: Dictionary, k: int, ctx: Dictionary) -> bool:
	var storey: Dictionary = mass.storeys[_storey_index(chain, k)]
	var band := int(storey.floor_band)
	for edge: Vector3i in _edges(chain):
		for b in range(band, band + int(storey.get("bands", 2))):
			if bool((ctx.reserved as Callable).call(_own(mass), Vector2i(edge.x, edge.y), b)):
				return false
	return true


## Bearing: behind every stepped-in edge at least one module of floor remains, at
## least two across an axis stepped in from both sides (the kit's jetty never leaves a
## one-module stalk), counting the opposite face's committed or same-front offset.
static func _bears(mass: BuildingMass, chain: Dictionary, k: int, depth: float, ctx: Dictionary) -> bool:
	var kit: BuildingKit = ctx.kit
	var index := _storey_index(chain, k)
	var cells: Dictionary = mass.storeys[index].cells
	var dir := int(chain.dir)
	var inward: Vector2i = -BuildingMass.DIRS[dir]
	var back := (dir + 2) % 4
	for edge: Vector3i in _edges(chain):
		var far := Vector2i(edge.x, edge.y)
		var modules := 1
		while cells.has(far + inward):
			far += inward
			modules += 1
		var opposite := _planned(mass, index, BuildingMass.edge_key(far, back), kit, ctx)
		var keep := float(modules) * kit.module_width + depth + opposite
		var need := (2.0 if opposite < 0.0 else 1.0) * kit.module_width
		if keep < need - 0.0001:
			return false
	return true


## The offset (native m, <= 0) one edge will stand at: this front's plan, else committed.
static func _planned(mass: BuildingMass, index: int, edge: Vector3i, kit: BuildingKit, ctx: Dictionary) -> float:
	var key := "%s|%d|%s" % [mass.stable_id, index, edge]
	if (ctx.planned as Dictionary).has(key):
		return minf(0.0, float(ctx.planned[key]))
	return minf(0.0, float((mass.storeys[index].get("wall_offsets", {}) as Dictionary).get(edge, 0.0))) * kit.module_width


## A porch post standing on or within one module in front of the run (at the storey's
## bands) would be left in the recess or cut by the moved wall: the step is withdrawn.
static func _decor_ok(mass: BuildingMass, chain: Dictionary, k: int) -> bool:
	var storey: Dictionary = mass.storeys[_storey_index(chain, k)]
	var lo := int(storey.floor_band)
	var hi := lo + int(storey.get("bands", 2))
	var dir := int(chain.dir)
	var sign := 1.0 if dir < 2 else -1.0
	for item: Dictionary in mass.decor:
		if StringName(item.kind) != &"post" or int(item.get("from_band", hi)) >= hi \
				or int(item.get("to_band", lo)) <= lo:
			continue
		var vertex: Vector2 = item.centre
		var line := vertex.x if dir % 2 == 0 else vertex.y
		var along := vertex.y if dir % 2 == 0 else vertex.x
		var ahead := (line - float(chain.line)) * sign
		if ahead >= -0.001 and ahead <= 1.001 and along >= float(chain.start) - 0.001 \
				and along <= float(chain.end) + 0.001:
			return false
	return true


# G6 under step-in: a storey with a skywalk/bridge passage or a blank on its run, or
# whose wall (or the storey above's) bears a balcony, neither stands in nor overhangs
# (depth == base == 0). A bay or a door on a stepped-in UPPER storey withdraws the
# step; a door on the ground storey is a recessed shopfront (it moves in with its wall).
static func _no_portal(mass: BuildingMass, chain: Dictionary, k: int, depth: float, base: float) -> bool:
	if depth >= 0.0 and base >= 0.0:
		return true
	var storey: Dictionary = mass.storeys[_storey_index(chain, k)]
	if bool(storey.get("bears_balcony", false)):
		return false
	var above := _storey_at(mass, int(storey.floor_band) + int(storey.get("bands", 2)))
	if not above.is_empty() and bool(above.get("bears_balcony", false)):
		return false
	var passages: Dictionary = storey.get("passage_edges", {})
	for edge: Vector3i in _edges(chain):
		if passages.has(edge):
			return false
		var opening := StringName(storey.openings.get(edge, storey.default_opening))
		if opening == BuildingMass.OPENING_NONE:
			return false
		if depth < 0.0 and (opening == BuildingMass.OPENING_BAY or (opening == BuildingMass.OPENING_DOOR and k >= 0)):
			return false
	return true


## An assembler that sees other buildings as the final assembly does, so a
## candidate's slots and an obstacle's parts match what is finally built.
static func _assembler(mass: BuildingMass, kit: BuildingKit, solid: Callable) -> BuildingKitAssembler:
	var assembler := BuildingKitAssembler.new(kit)
	if solid.is_valid():
		var own := _own(mass)
		assembler.external_blocked = func(cell: Vector2i, band: int) -> bool:
			return bool(solid.call(own, cell, band))
	return assembler


## Marks every obstacle record of one decor item gone.
static func _drop_decor(ctx: Dictionary, item: Dictionary) -> void:
	for other: Dictionary in ctx.obstacles:
		if other.has("decor") and is_same(other.decor, item):
			other["gone"] = true


# --- guardrails -------------------------------------------------------------

## Furthest facing facade (in modules) a lane is measured to for the sky gap.
const MAX_LANE_MODULES := 4


## Every house's assembled parts plus towers; the pieces each accepted step-in adds are appended by _commit.
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


## Two pieces stacked with a seated seam: they overlap no deeper than 0.15 m
## vertically (a corner post rises 0.074 past the wall head into the floor above).
static func _seated(box: AABB, other: AABB) -> bool:
	return box.intersection(other).size.y <= 0.15


static func contact_clear(box: AABB, other: AABB) -> bool:
	if not box.intersects(other):
		return true
	var overlap := box.intersection(other).size
	return minf(overlap.x, minf(overlap.y, overlap.z)) <= TOUCH


static func _obstacle_cause(obstacle: Dictionary, mass: BuildingMass) -> StringName:
	if obstacle.owner == mass.stable_id:
		return &"obstacle.own"
	if obstacle.owner == &"":
		return &"obstacle.tower" if String(obstacle.role) == "tower" else &"obstacle.lean"
	var token := String(obstacle.owner).trim_prefix("kit.")
	return StringName("obstacle.%s" % token.get_slice(".", 0))


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


## Pieces a step-in adds that dressing may meet (the jetty: braces, beams, strips).
const JETTY_ROLES: Array[String] = ["bracket.", "trim.floor_beam", "frontage."]


## The face storey (k, -1 = ground) a piece at height y belongs to.
static func _storey_at_y(member: Dictionary, y: float, kit: BuildingKit) -> int:
	var indices := _storeys(member.chain)
	var found := -1
	for i in indices.size():
		if float((member.mass as BuildingMass).storeys[indices[i]].floor_band) * kit.band_height() <= y + 0.001:
			found = i - 1
	return found


static func _snapshot(mass: BuildingMass, chain: Dictionary) -> Dictionary:
	var storeys := {}
	for index: int in _storeys(chain):
		var storey: Dictionary = mass.storeys[index]
		var keep := {}
		for key: String in ["wall_offsets", "growth", "plinth_edges"]:
			if storey.has(key):
				keep[key] = (storey[key] as Dictionary).duplicate(true)
		if storey.has("projections"):
			keep["projections"] = (storey.projections as Array).duplicate(true)
		# Openings and bay roles are restored in place (a yielding bay is dropped by apply).
		keep["openings"] = (storey.openings as Dictionary).duplicate()
		keep["bay_roles"] = (storey.get("bay_roles", {}) as Dictionary).duplicate()
		storeys[index] = keep
	var centres := []
	for item: Dictionary in mass.decor:
		centres.append([item, item.get("centre")])
	return {"storeys": storeys, "centres": centres}


static func _restore(mass: BuildingMass, saved: Dictionary) -> void:
	for index: int in saved.storeys:
		var storey: Dictionary = mass.storeys[index]
		var keep: Dictionary = (saved.storeys[index] as Dictionary).duplicate()
		for key: String in ["openings", "bay_roles"]:
			var live: Dictionary = storey.get(key, {})
			live.clear()
			live.merge(keep[key])
			if key == "bay_roles" and live.is_empty():
				storey.erase(key)
			keep.erase(key)
		for key: String in ["wall_offsets", "projections", "growth", "plinth_edges"]:
			storey.erase(key)
		storey.merge(keep)
	for pair: Array in saved.centres:
		(pair[0] as Dictionary)["centre"] = pair[1]


## One member's step-in written onto its house and undone again: the architecture
## it adds (the house assembled with and without it, compared by asset and pose) and
## the dressing it moves, with that dressing's new pieces.
static func _added_parts(member: Dictionary, leans: Array[float], closures: Array, ctx: Dictionary) -> Dictionary:
	var mass: BuildingMass = member.mass
	var assembler := _assembler(mass, member.kit, ctx.solid)
	var decor := mass.decor.duplicate()
	mass.decor.clear()
	var before := {}
	for part: Dictionary in assembler.assemble(mass):
		before["%s|%s" % [part.asset_id, part.transform]] = true
	mass.decor.assign(decor)
	var saved := _snapshot(mass, member.chain)
	var moved: Array = apply(mass, member.kit, member.chain, leans, closures, _plinth_of(member, ctx)).moved
	mass.decor.clear()
	var added: Array[Dictionary] = []
	for part: Dictionary in assembler.assemble(mass):
		if not before.has("%s|%s" % [part.asset_id, part.transform]):
			added.append(part)
	mass.decor.assign(decor)
	var dressing: Array[Dictionary] = []
	for item: Dictionary in moved:
		var assembly := {"mass": mass, "out": [] as Array[Dictionary], "serial": 0}
		assembler._assemble_decor(assembly, item)
		dressing.append({"item": item, "parts": assembly.out})
	_restore(mass, saved)
	return {"added": added, "moved": dressing}


## G1 + G3 under step-in: the pieces one member's step-in adds clear walking air and
## every other building (its own architecture, and an active row partner's, is what the
## step-in rebuilds). Dressing the new jetty pieces meet — kept dressing of the house or
## a partner, or dressing the step moved — yields when of a yielding kind (ctx.yields),
## else the step is withdrawn (obstacle.own). Returns {cause, storey, depth} or {}.
static func _parts_fault(member: Dictionary, leans: Array[float], closures: Array, ctx: Dictionary) -> Dictionary:
	var mass: BuildingMass = member.mass
	var catalog: EnvironmentCatalog = ctx.catalog
	var probe := _added_parts(member, leans, closures, ctx)
	var partners := {}
	for m: int in ctx.active:
		partners[(ctx.front.members[m].mass as BuildingMass).stable_id] = true
	var moved: Array = (probe.moved as Array).map(func(d: Dictionary) -> Dictionary: return d.item)
	var yields: Array = []
	var top: float = leans.back()
	for part: Dictionary in probe.added:
		var local: AABB = catalog.descriptor(part.asset_id).measured_aabb
		var box: AABB = (part.transform * local).grow(-0.002)
		var fault := {"cause": &"", "storey": _storey_at_y(member, box.get_center().y, member.kit), "depth": -top}
		if CLEARANCE.intersects_air(local, part.transform, ctx.air):
			fault.cause = &"air"
			return fault
		var jetty := JETTY_ROLES.any(func(prefix: String) -> bool: return String(part.role).begins_with(prefix))
		for obstacle: Dictionary in ctx.obstacles:
			if bool(obstacle.get("gone", false)) or contact_clear(box, obstacle.bounds):
				continue
			if not partners.has(obstacle.owner):
				if _at_their_lot(box.intersection(obstacle.bounds), ctx.get("masses", {}).get(obstacle.owner), member.kit):
					continue
				fault.cause = _obstacle_cause(obstacle, mass)
				return fault
			if not jetty or not obstacle.has("decor") or moved.any(func(i: Dictionary) -> bool: return is_same(i, obstacle.decor)):
				continue # rebuilt architecture, or dressing whose new place is tested below
			if StringName(obstacle.decor.kind) in YIELD_DECOR:
				if not yields.any(func(i: Dictionary) -> bool: return is_same(i, obstacle.decor)):
					yields.append(obstacle.decor)
				continue
			fault.cause = &"obstacle.own"
			return fault
		if not jetty:
			continue
		for dressed: Dictionary in probe.moved:
			for piece: Dictionary in dressed.parts:
				if contact_clear(box, piece.transform * catalog.descriptor(piece.asset_id).measured_aabb):
					continue
				if not (StringName(dressed.item.kind) in YIELD_DECOR):
					fault.cause = &"obstacle.own"
					return fault
				if not yields.any(func(i: Dictionary) -> bool: return is_same(i, dressed.item)):
					yields.append(dressed.item)
	for dressed: Dictionary in probe.moved:
		for piece: Dictionary in dressed.parts:
			var local: AABB = catalog.descriptor(piece.asset_id).measured_aabb
			if CLEARANCE.intersects_air(local, piece.transform, ctx.air):
				return {"cause": &"air", "storey": _storey_at_y(member, (piece.transform * local).get_center().y,
					member.kit), "depth": -top}
	(ctx.yields as Dictionary)[String(member.chain.key)] = yields
	return {}


## G3 under step-in: another building's piece meets an added piece only where it
## stands proud of its own lot by no more than its wall face (+ touching contact), as
## at a vertex two houses share diagonally (their corner posts already meet there):
## it does not reach into the recess. Every corner of the overlap lies within that
## margin (per axis) of one of the owner's cells at the overlap's bands.
static func _at_their_lot(overlap: AABB, owner: BuildingMass, kit: BuildingKit) -> bool:
	if owner == null:
		return false
	var margin := kit.wall_face + TOUCH
	var w := kit.module_width
	var cells := {}
	for band in range(floori(overlap.position.y / kit.band_height()), floori(overlap.end.y / kit.band_height()) + 1):
		cells.merge(owner.cells_at_band(band))
	for corner: Vector2 in [Vector2(overlap.position.x, overlap.position.z), Vector2(overlap.end.x, overlap.position.z),
			Vector2(overlap.position.x, overlap.end.z), Vector2(overlap.end.x, overlap.end.z)]:
		var near := false
		var at := Vector2i((corner / w).floor())
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var cell := at + Vector2i(dx, dz)
				if not cells.has(cell):
					continue
				var lo := Vector2(cell) * w
				var gap := Vector2(maxf(maxf(lo.x - corner.x, corner.x - lo.x - w), 0.0),
					maxf(maxf(lo.y - corner.y, corner.y - lo.y - w), 0.0))
				near = near or maxf(gap.x, gap.y) <= margin
		if not near:
			return false
	return true


## Dressing on the corner panels this member's stepped-in storeys cut (the
## perpendicular face's end panel at a `return` or `wrap` end; a corner climber on the
## face's own end panel there) goes: its panel is shortened or gone.
static func _drop_cut_decor(member: Dictionary, leans: Array[float], closures: Array, ctx: Dictionary) -> void:
	var mass: BuildingMass = member.mass
	var chain: Dictionary = member.chain
	var dir := int(chain.dir)
	var along := Vector2i(0, 1) if dir % 2 == 0 else Vector2i(1, 0)
	var offsets := offsets_of(leans)
	var indices := _storeys(chain)
	for i in indices.size():
		if offsets[i] >= 0.0:
			continue
		var storey: Dictionary = mass.storeys[indices[i]]
		for at_end: bool in [false, true]:
			# _closures' order: [start, end] for dirs 1 and 2, [end, start] otherwise.
			var side := (1 if at_end else 0) if (dir == 1 or dir == 2) else (0 if at_end else 1)
			if not (StringName(closures[i][side]) in [&"return", &"wrap"]):
				continue
			var sign := 1 if at_end else -1
			var cell := BuildingKitAssembler._inside_cell(dir, int(chain.line), int(chain.end) - 1 if at_end else int(chain.start))
			var cut := [BuildingMass.edge_key(cell, BuildingMass.DIRS.find(along * sign)), BuildingMass.edge_key(cell, dir)]
			for item: Dictionary in mass.decor.duplicate():
				var edge := _decor_edge(item)
				if _on_storey(item, storey, member.kit) and (edge == cut[0] \
						or (StringName(item.kind) == &"ivy_corner" and edge == cut[1])):
					mass.decor.erase(item)
					_drop_decor(ctx, item)


static func _commit(member: Dictionary, leans: Array[float], closures: Array, ctx: Dictionary,
		out: Array[Dictionary]) -> void:
	var mass: BuildingMass = member.mass
	var kit: BuildingKit = member.kit
	var catalog: EnvironmentCatalog = ctx.catalog
	for item: Dictionary in (ctx.yields as Dictionary).get(String(member.chain.key), []):
		mass.decor.erase(item)
		_drop_decor(ctx, item)
	var probe := _added_parts(member, leans, closures, ctx)
	var written := apply(mass, kit, member.chain, leans, closures, _plinth_of(member, ctx))
	# A bay the step dropped is no obstacle any more.
	for dropped: Dictionary in written.dropped:
		_drop_bay_obstacles(ctx, mass, dropped, kit)
	for item: Dictionary in written.moved:
		_drop_decor(ctx, item)
		var assembly := {"mass": mass, "out": [] as Array[Dictionary], "serial": 0}
		_assembler(mass, kit, ctx.solid)._assemble_decor(assembly, item)
		for part: Dictionary in assembly.out:
			var obstacle := _obstacle(mass, part, catalog)
			obstacle["decor"] = item
			obstacle["host"] = mass
			ctx.obstacles.append(obstacle)
	for part: Dictionary in probe.added:
		ctx.obstacles.append(_obstacle(mass, part, catalog))
	for record: Dictionary in written.records:
		out.append({"host": mass.stable_id, "dir": int(member.chain.dir), "band": int(record.band),
			"lean": float(record.depth), "base": float(record.base), "edges": record.edges,
			"bounds": record.bounds, "chain": member.chain.key, "closures": record.closures,
			"pulled": not mass.grows})


## The off-grade edges of a member's ground run (see _graded).
static func _plinth_of(member: Dictionary, ctx: Dictionary) -> Array:
	return (ctx.get("plinth", {}) as Dictionary).get(String(member.chain.key), [])


## Marks the obstacle records of a dropped bay gone: the bay pieces of `mass` standing
## at that edge's panel (within a module of its centre) on that storey.
static func _drop_bay_obstacles(ctx: Dictionary, mass: BuildingMass, dropped: Dictionary, kit: BuildingKit) -> void:
	var edge: Vector3i = dropped.edge
	var at := (Vector2(edge.x, edge.y) + Vector2.ONE * 0.5 + Vector2(BuildingMass.DIRS[edge.z]) * 0.5) * kit.module_width
	var y0 := float(dropped.band) * kit.band_height()
	for obstacle: Dictionary in ctx.obstacles:
		if obstacle.owner != mass.stable_id or not String(obstacle.role).begins_with("bay."):
			continue
		var centre: Vector3 = (obstacle.bounds as AABB).get_center()
		if Vector2(centre.x, centre.z).distance_to(at) <= kit.module_width \
				and centre.y >= y0 - 0.5 and centre.y <= y0 + kit.storey_height + 0.5:
			obstacle["gone"] = true


## Writes one face's step-in into its house (spec Amendment 2): storey k of the chain
## stands `leans[k] - top` inside its line and the ground storey `-top` (offsets_of),
## with a growth record on every storey that stands in or overhangs the one below and
## `storey.growth[dir]` on every storey of the face (0.0 on held tops, so room
## projections and bays keep off the face). Dressing on a stepped-in run moves in with
## its wall. `closures[i]` belongs to storey i from the ground up. `plinth` lists the
## ground run's off-grade edges (storey.plinth_edges: boards trimmed to the wall, the
## strip capped in stone). A designer bay the step cuts is dropped. Returns {records,
## moved, dropped: [{edge, band}]}.
static func apply(mass: BuildingMass, kit: BuildingKit, chain: Dictionary, leans: Array[float],
		closures: Array, plinth: Array = []) -> Dictionary:
	var dir := int(chain.dir)
	var edges := _edges(chain)
	var offsets := offsets_of(leans)
	var indices := _storeys(chain)
	var records: Array[Dictionary] = []
	var moved: Array[Dictionary] = []
	var dropped: Array[Dictionary] = []
	for i in indices.size():
		var storey: Dictionary = mass.storeys[indices[i]]
		var depth: float = offsets[i]
		var base: float = offsets[i - 1] if i > 0 else depth
		var growth: Dictionary = storey.get("growth", {})
		growth[dir] = depth
		storey["growth"] = growth
		if depth >= 0.0 and depth <= base:
			continue
		if depth < 0.0:
			var wall_offsets: Dictionary = storey.get("wall_offsets", {})
			for edge: Vector3i in edges:
				wall_offsets[edge] = depth / kit.module_width
			storey["wall_offsets"] = wall_offsets
			for item: Dictionary in mass.decor:
				if item.has("dir") and int(item.dir) == dir and edges.has(_decor_edge(item)) \
						and _on_storey(item, storey, kit) and not moved.any(func(d: Dictionary) -> bool: return is_same(d, item)):
					item.centre = (item.centre as Vector2) + Vector2(BuildingMass.DIRS[dir]) * depth / kit.module_width
					moved.append(item)
			if mass.grows:
				for edge: Vector3i in _drop_cut_bays(chain, storey, closures[i]):
					dropped.append({"edge": edge, "band": int(storey.floor_band)})
			if i == 0 and not plinth.is_empty():
				var trimmed: Dictionary = storey.get("plinth_edges", {})
				for edge: Vector3i in plinth:
					trimmed[edge] = true
				storey["plinth_edges"] = trimmed
		var record := _record(kit, chain, storey, depth, base, closures[i])
		var fronts_at: Array = storey.get("projections", [])
		fronts_at.append(record.projection)
		storey["projections"] = fronts_at
		records.append(record)
	return {"records": records, "moved": moved, "dropped": dropped}


## Ruling (b): a designer bay on a corner panel this stepped-in storey cuts (the
## perpendicular face's end panel at a `return` or `wrap` end) yields: it is dropped
## and the panel takes the storey's default opening.
static func _drop_cut_bays(chain: Dictionary, storey: Dictionary, closures: Array) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var dir := int(chain.dir)
	var along := Vector2i(0, 1) if dir % 2 == 0 else Vector2i(1, 0)
	for at_end: bool in [false, true]:
		# _closures' order: [start, end] for dirs 1 and 2, [end, start] otherwise.
		var side := (1 if at_end else 0) if (dir == 1 or dir == 2) else (0 if at_end else 1)
		if not (StringName(closures[side]) in [&"return", &"wrap"]):
			continue
		var sign := 1 if at_end else -1
		var cell := BuildingKitAssembler._inside_cell(dir, int(chain.line), int(chain.end) - 1 if at_end else int(chain.start))
		var corner := BuildingMass.edge_key(cell, BuildingMass.DIRS.find(along * sign))
		if StringName(storey.openings.get(corner, storey.default_opening)) != BuildingMass.OPENING_BAY:
			continue
		storey.openings.erase(corner)
		if StringName(storey.default_opening) == BuildingMass.OPENING_BAY:
			storey.openings[corner] = BuildingMass.OPENING_WINDOW
		if storey.has("bay_roles"):
			(storey.bay_roles as Dictionary).erase(corner)
		out.append(corner)
	return out


## One storey's growth record and its recess: the space between its wall (or the wall
## below, whichever stands further in) and the lot line, from one brace drop under its
## floor to its ceiling.
static func _record(kit: BuildingKit, chain: Dictionary, storey: Dictionary, depth: float, base: float,
		closures: Array) -> Dictionary:
	var dir := int(chain.dir)
	var edges := _edges(chain)
	var centres: Array[Vector2] = []
	for edge: Vector3i in edges:
		centres.append(Vector2(edge.x, edge.y) + Vector2.ONE * .5 + Vector2(BuildingMass.DIRS[dir]) * .5)
	var right := Vector2(BuildingKitAssembler.right_of(dir))
	centres.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.dot(right) < b.dot(right))
	var band := int(storey.floor_band)
	var at: Vector2 = centres.front() * kit.module_width
	var pose := Transform3D(Basis(Vector3.UP, BuildingKitAssembler.yaw_for_dir(dir)),
		Vector3(at.x, band * kit.band_height(), at.y))
	var inner := minf(depth, base)
	var body := AABB(Vector3(-kit.module_width * .5, -kit.jetty_depth, inner),
		Vector3(centres.size() * kit.module_width, kit.storey_height + kit.jetty_depth, -inner))
	return {"band": band, "depth": depth, "base": base, "edges": edges, "closures": closures,
		"bounds": pose * body,
		"projection": {"edges": edges, "centres": centres, "dir": dir, "depth": depth, "base": base,
			"band": band, "growth": true, "closures": closures}}


## The wall edge a decor item stands on (its centre is a slot centre).
static func _decor_edge(item: Dictionary) -> Vector3i:
	if not item.has("dir") or not item.has("centre"):
		return Vector3i(-1048576, 0, 0) # dressing without a face
	var dir := int(item.dir)
	var centre: Vector2 = item.centre
	var cell := Vector2i((centre - Vector2(BuildingMass.DIRS[dir]) * 0.5 - Vector2.ONE * 0.5).round())
	return BuildingMass.edge_key(cell, dir)


## True when a decor item stands on (or reaches into) this storey's height.
static func _on_storey(item: Dictionary, storey: Dictionary, kit: BuildingKit) -> bool:
	var lo := int(storey.floor_band)
	var hi := lo + int(storey.get("bands", 2))
	if item.has("from_band"):
		return int(item.from_band) < hi and int(item.get("to_band", item.from_band)) > lo
	var y := float(item.get("y", float(int(item.get("y_band", -1000))) * kit.band_height()))
	return y >= lo * kit.band_height() - 0.01 and y < hi * kit.band_height()
