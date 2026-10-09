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
		street: Callable, roof_geometry: Dictionary = {}) -> Dictionary:
	var leans: Array[Dictionary] = []
	var ctx := {"catalog": catalog, "air": air, "towers": towers, "reserved": reserved,
		"solid": solid, "registry": {}, "obstacles": [], "gap": 0.0, "kit": base, "rejections": [],
		"riders": [], "buried": [], "lean": 0.0, "geometry": roof_geometry, "allowances": {},
		"inset_records": [], "eave_crowned": {}, "stepped": {}, "roofs": [],
		"front": {}, "active": [] as Array[int], "step": 0.0, "crown_kind": &"", "crown_why": &"", "masses": {}}
	if character == null or not masses.any(func(m: BuildingMass) -> bool: return m.grows):
		return {"leans": leans, "registry": ctx.registry, "rejections": ctx.rejections,
			"insets": ctx.inset_records, "roofs": ctx.roofs}
	ctx.gap = character.value(GAP_KNOB)
	for mass: BuildingMass in masses:
		ctx.masses[mass.stable_id] = mass
	ctx.obstacles = _obstacles(masses, kits, base, catalog, towers, solid)
	# Candidate faces come from every eligible house (a terrace row pulls its
	# coplanar neighbours); only growing houses seed a front and draw face rolls.
	var members: Array[Dictionary] = []
	for mass: BuildingMass in masses:
		if not kits.has(_own(mass)) or String(mass.stable_id).contains("wall-room"):
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
	return {"leans": leans, "registry": ctx.registry, "rejections": ctx.rejections,
		"insets": ctx.inset_records, "roofs": ctx.roofs}


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
	var half := false
	ctx.front = front
	ctx.active = active
	while not active.is_empty():
		var step := _front_step(front.members[active[0]], character, ctx)
		if not STEP_SIZES.has(step):
			return
		half = step < carried_step(front.members[active[0]].kit,
			float(String(character.pick(STEP_KNOB, String(front.members[active[0]].mass.stable_id)))))
		ctx.step = step
		var cap := step * float(mini(MAX_STEPS, floori(character.value(CAP_KNOB) / step + 0.0001)))
		var result := _front_profile(front, active, step, cap, ctx)
		if int(result.leaves) < 0:
			leans = result.leans
			break
		active.erase(int(result.leaves))
		left.append(int(result.leaves))
	var profiles := {}
	var closures := {}
	var buried := {}
	for m: int in active:
		var member: Dictionary = front.members[m]
		var profile: Array[float] = []
		var ends: Array = []
		var contacts: Array = []
		for k in (member.chain.storeys as Array).size():
			profile.append(leans[k])
			ctx.lean = profile[k]
			ctx.buried = []
			ends.append(_closures(front, active, m, k, ctx))
			contacts.append(ctx.buried)
		ctx.buried = []
		profiles[m] = profile
		closures[m] = ends
		buried[m] = contacts
	# Every member's yielding ornaments go before any member commits, each probed
	# with the row's riders, so the yields are exactly those the fit accepted.
	for m: int in active:
		var member: Dictionary = front.members[m]
		ctx.kit = member.kit
		_yield(member.mass, member.kit, member.chain, profiles[m], ctx, closures[m], front, active, m,
			buried[m])
	for m: int in active:
		var member: Dictionary = front.members[m]
		ctx.kit = member.kit
		_commit(member.mass, member.kit, member.chain, profiles[m], ctx, out, closures[m], buried[m])
	# An eave face its crown kept flush steps its ground run in instead (one face).
	for m: int in active:
		var member: Dictionary = front.members[m]
		var flat := (profiles[m] as Array).all(func(lean: float) -> bool: return lean <= 0.0)
		_record_roof(member, profiles[m], flat and _try_inset(member, ctx), half, ctx)
	for m: int in left:
		if bool(front.members[m].seed):
			_fit_front({"members": [front.members[m]], "joins": []}, character, ctx, out)
		else:
			var member: Dictionary = front.members[m]
			var flat: Array[float] = []
			flat.resize((member.chain.storeys as Array).size())
			flat.fill(0.0)
			_record_roof(member, flat, _try_inset(member, ctx), false, ctx)


## The step a leader carries. A kit jetty cannot pass under an eave: an
## eave-crowned leader keeps it where its ground run can step in by that jetty
## instead (the face leaves its front on its crown and takes the inset, so its
## partners keep the kit step); else it takes the light step where the measured
## cornice admits it (else its crown withdraws the step).
static func _front_step(leader: Dictionary, character: TownCharacter, ctx: Dictionary) -> float:
	var step := carried_step(leader.kit, float(String(character.pick(STEP_KNOB, String(leader.mass.stable_id)))))
	if step > 0.5:
		ctx.kit = leader.kit
		ctx.step = step
		var top := (leader.chain.storeys as Array).size() - 1
		var wing := crown_wing(leader.mass, leader.chain, top)
		if not wing.is_empty() and int(wing.axis) != int(leader.chain.dir) % 2 \
				and _eave_cap(wing, int(leader.chain.dir), ctx) < step \
				and _inset_cause(leader.mass, leader.kit, leader.chain, ctx) != &"" \
				and _eave_cap(wing, int(leader.chain.dir), ctx) >= 0.5 - 0.0001:
			step = 0.5
	return step


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
				return {"leaves": int(fault.member), "fault": fault}
			break
		var hold := _front_fault(front, active, k, held, held, ctx)
		if hold.is_empty():
			leans[k] = held
			k += 1
			continue
		_reject(ctx, front, hold, k, held)
		if active.size() > 1:
			return {"leaves": int(hold.member), "fault": hold}
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
		ctx.lean = lean
		_publish_riders(front, active, m, k, lean, base, ctx)
		# The buried contacts are member m's own (riders' closures are computed first).
		ctx.buried = []
		var closures := _closures(front, active, m, k, ctx)
		ctx.kit = member.kit
		var cause := &"ends" if closures.has(&"blocked") \
			else _fault(member.mass, member.chain, k, lean, base, ctx, closures)
		ctx.riders = []
		ctx.buried = []
		if cause != &"":
			var fault := {"member": m, "cause": cause}
			if cause == &"crown":
				fault["crown"] = ctx.crown_kind
				fault["why"] = ctx.crown_why
			return fault
	return {}


## The faces of the other active row members present at storey k (stepping to the
## same lean), published as ctx.riders while member m is tested: their pieces
## step with the row, so they are no obstacle to m.
static func _publish_riders(front: Dictionary, active: Array[int], m: int, k: int, lean: float,
		base: float, ctx: Dictionary) -> void:
	var riders: Array[Dictionary] = []
	for other: int in active:
		var partner: Dictionary = front.members[other]
		if other == m or partner.mass == front.members[m].mass \
				or k >= (partner.chain.storeys as Array).size():
			continue
		var probe := _candidate(partner.mass, partner.kit, partner.chain, k, lean, base, ctx.solid,
			_closures(front, active, other, k, ctx))
		riders.append({"owner": (partner.mass as BuildingMass).stable_id, "candidate": probe,
			"slab": _face_slab(probe, partner.kit), "kit": partner.kit,
			"crown": crown_index(partner.mass, partner.chain, k)})
	ctx.riders = riders


static func _reject(ctx: Dictionary, front: Dictionary, fault: Dictionary, k: int, lean: float) -> void:
	var record := {"chain": String(front.members[int(fault.member)].chain.key),
		"storey": k, "lean": lean, "cause": fault.cause}
	if fault.has("crown"):
		record["crown"] = fault.crown
		record["why"] = fault.get("why", &"")
		if StringName(fault.crown) == &"eave":
			ctx.eave_crowned[record.chain] = true
	ctx.rejections.append(record)


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
	if _end_open(member.mass, member.chain, at_end, k, ctx):
		return &"return"
	var contact := _bury_contact(member.mass, member.chain, at_end, k, float(ctx.get("lean", 0.0)), ctx)
	if not contact.is_empty():
		(ctx.buried as Array).append_array(contact)
		return &"bury"
	return &"blocked"


## Wall pieces a stepped end may run into (anything else on the wall withdraws the step).
## Plain panels, posts and framing beams (panel heads/joints are a kit's plain
## timber framing; retaining courses are plain masonry).
const PLAIN_CONTACT: Array[String] = ["wall.timber.plain", "wall.stone.plain", "wall.stone.retaining",
	"post.", "trim.floor_beam", "trim.panel_head", "trim.panel_joint"]
## The contact reaches below the floor by the kit brace's drop.
const BURY_DROP := 1.0


## The plain wall an end runs into at storey k, as the owner's obstacle records
## the contact box meets, or [] when this end cannot be buried. An own inside
## corner (the run ends concave: the house's wing stands beside and in front of
## the end) is run into the wing; a neighbour inside corner (another building
## diagonally in front of the end; beside it open, the house's own cell under that
## building, or a building) into that building's wall facing back along the run.
## The wall must not itself step (registry) and must be plain where the end meets it.
static func _bury_contact(mass: BuildingMass, chain: Dictionary, at_end: bool, k: int, lean: float,
		ctx: Dictionary) -> Array:
	if lean <= 0.0:
		return []
	var storey: Dictionary = mass.storeys[chain.storeys[k]]
	var dir := int(chain.dir)
	var along := Vector2i(0, 1) if dir % 2 == 0 else Vector2i(1, 0)
	var sign := 1 if at_end else -1
	var cell := BuildingKitAssembler._inside_cell(dir, int(chain.line),
		int(chain.end) - 1 if at_end else int(chain.start))
	var side := cell + along * sign
	var diagonal: Vector2i = side + BuildingMass.DIRS[dir]
	var band := int(storey.floor_band)
	var bands := range(band, band + int(storey.get("bands", 2)))
	var solid: Callable = ctx.solid
	var own := _own(mass)
	var concave := true
	for b: int in bands:
		concave = concave and mass.cells_at_band(b).has(side) and mass.cells_at_band(b).has(diagonal)
	if not concave:
		for b: int in bands:
			if mass.cells_at_band(b).has(diagonal) or not bool(solid.call(own, diagonal, b)):
				return []
	# The wall run into faces back along the run; it must stand where it was built.
	var facing := BuildingMass.DIRS.find(-along * sign)
	for b: int in bands:
		if float((ctx.registry as Dictionary).get(Vector4i(diagonal.x, diagonal.y, facing, b), 0.0)) > 0.0:
			return []
	var kit: BuildingKit = ctx.kit
	var vertex := Vector2(_point(chain, at_end)) * kit.module_width
	var out := Vector2(BuildingMass.DIRS[dir])
	var y0 := band * kit.band_height()
	var near := vertex - Vector2(along) * sign * 0.05
	# Out to the stepped face's outer skin (its pieces stand wall_face proud of the plane).
	var far := vertex + Vector2(along) * sign * 0.35 + out * (lean + kit.wall_face)
	var box := AABB(Vector3(minf(near.x, far.x), y0 - BURY_DROP, minf(near.y, far.y)),
		Vector3(absf(far.x - near.x), kit.storey_height + BURY_DROP, absf(far.y - near.y)))
	var contact: Array = []
	var walls := 0
	var crown := crown_index(mass, chain, k)
	for obstacle: Dictionary in ctx.obstacles:
		if bool(obstacle.get("gone", false)) or contact_clear(box, obstacle.bounds):
			continue
		# The wall run into is the own wing (concave) or another building's.
		if obstacle.owner == &"" or (obstacle.owner == mass.stable_id) != concave:
			continue
		# The roof closing this storey's own face rides with it (as in _parts_fault).
		if concave and crown >= 0 and int(obstacle.roof_index) == crown:
			continue
		var role := String(obstacle.role)
		# lo/hi: the obstacle's extent as (along the run, out of the face).
		var bounds: AABB = obstacle.bounds
		var lo := Vector2(bounds.position.x, bounds.position.z) if dir % 2 == 1 \
			else Vector2(bounds.position.z, bounds.position.x)
		var hi := Vector2(bounds.end.x, bounds.end.z) if dir % 2 == 1 \
			else Vector2(bounds.end.z, bounds.end.x)
		var at := vertex.x if dir % 2 == 1 else vertex.y
		var line := vertex.y if dir % 2 == 1 else vertex.x
		var outer := line + (out.y if dir % 2 == 1 else out.x) * lean
		# A wall panel thin out of the face belongs to a face parallel to this one.
		if role.begins_with("wall.") and hi.y - lo.y < kit.module_width * 0.5:
			# On the face line: the run-into building's face continuing this face's
			# line, facing away; the end meets only its inner half, inside the corner
			# (under the corner post and the wall run into).
			if lo.y < line - TOUCH and hi.y > line + TOUCH:
				contact.append(obstacle)
				continue
			# On the stepped plane: a face coplanar with the step (a row joint, not
			# a bury); the two skins would overlap, so the end stays blocked.
			if lo.y < outer - TOUCH and hi.y > outer + TOUCH:
				return []
		# A floor board wholly behind the wall plane is that building's floor (hidden).
		var behind := lo.x >= at - TOUCH if sign > 0 else hi.x <= at + TOUCH
		if role == "deck.board" and behind:
			contact.append(obstacle)
			continue
		if not PLAIN_CONTACT.any(func(prefix: String) -> bool: return role.begins_with(prefix)):
			return []
		if role.begins_with("wall."):
			walls += 1
		contact.append(obstacle)
	return contact if walls > 0 else []


## The former guardrail 4, per end: the run at storey k is the chain's run and
## convex at this end, nothing stands beside or diagonally beyond it, and the
## perpendicular face at this corner does not step.
static func _end_open(mass: BuildingMass, chain: Dictionary, at_end: bool, k: int, ctx: Dictionary) -> bool:
	var storey: Dictionary = mass.storeys[chain.storeys[k]]
	var dir := int(chain.dir)
	# The boundary run holding the chain's run (an exposed run may be part of a longer
	# boundary run, split where a neighbour covers it): convex only where this end is
	# also that run's end.
	var convex := false
	var point := int(chain.end) if at_end else int(chain.start)
	for run: Dictionary in BuildingKitAssembler.boundary_runs(storey.cells):
		if int(run.dir) == dir and int(run.line) == int(chain.line) \
				and int(run.start) <= int(chain.start) and int(run.end) >= int(chain.end) \
				and int(run.end if at_end else run.start) == point:
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
	for b in range(int(storey.floor_band), int(storey.floor_band) + int(storey.get("bands", 2))):
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
	var cause := _parts_fault(mass, candidate, crown_index(mass, chain, k), ctx)
	if cause != &"":
		return cause
	return _crown_fault(mass, chain, k, lean, ctx)


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


## Ornaments the new braces/strips of one member's steps meet yield: removes them
## and their obstacle parts (the house's own, or a row member's through `host`).
static func _yield(mass: BuildingMass, kit: BuildingKit, chain: Dictionary, profile: Array[float],
		ctx: Dictionary, closures: Array, front := {}, active: Array[int] = [], m := -1,
		buried: Array = []) -> void:
	for k in profile.size():
		if profile[k] <= 0.0:
			continue
		var base := 0.0 if k == 0 else profile[k - 1]
		ctx.lean = profile[k]
		if m >= 0:
			_publish_riders(front, active, m, k, profile[k], base, ctx)
		ctx.kit = kit
		ctx.buried = buried[k] if k < buried.size() else []
		var probe := _candidate(mass, kit, chain, k, profile[k], base, ctx.solid, closures[k])
		_parts_fault(mass, probe, crown_index(mass, chain, k), ctx)
		ctx.riders = []
		ctx.buried = []
		for obstacle: Dictionary in probe.yields:
			(obstacle.host as BuildingMass).decor.erase(obstacle.decor)
			_drop_decor(ctx, obstacle.decor)


static func _commit(mass: BuildingMass, kit: BuildingKit, chain: Dictionary,
		profile: Array[float], ctx: Dictionary, out: Array[Dictionary], closures: Array,
		buried: Array = []) -> void:
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
				"bounds": part.transform * catalog.descriptor(part.asset_id).measured_aabb,
				"stepped_host": mass.stable_id})
		out.append({"host": mass.stable_id, "dir": dir, "band": candidate.band, "lean": profile[k],
			"base": candidate.projection.base, "edges": candidate.edges, "bounds": candidate.bounds,
			"chain": chain.key, "closures": closures[k], "pulled": not mass.grows,
			"buried_into": _bury_owners(buried[k] if k < buried.size() else [])})
		(ctx.get("stepped", {}) as Dictionary)[mass.stable_id] = true
	# A gable-ended top storey carries its roof end out with it.
	var top := profile.size() - 1
	if top >= 0 and profile[top] > 0.0:
		var wing := crown_wing(mass, chain, top)
		if not wing.is_empty() and int(wing.axis) == dir % 2:
			wing["lean_max" if dir < 2 else "lean_min"] = profile[top]


## The owners of the walls a storey's buried ends run into (sorted, unique).
static func _bury_owners(contacts: Array) -> Array[String]:
	var owners: Array[String] = []
	for obstacle: Dictionary in contacts:
		if String(obstacle.role).begins_with("wall.") and not owners.has(String(obstacle.owner)):
			owners.append(String(obstacle.owner))
	owners.sort()
	return owners


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
# ornaments yield. An active terrace-row member's house (ctx.riders) is treated as
# the host is: its face steps with the row.
static func _parts_fault(mass: BuildingMass, candidate: Dictionary, crown: int,
		ctx: Dictionary) -> StringName:
	var catalog: EnvironmentCatalog = ctx.catalog
	var own: Array[Dictionary] = [{"candidate": candidate, "slab": _face_slab(candidate, ctx.kit),
		"crown": crown, "kit": ctx.kit}]
	var yields: Array = []
	candidate["yields"] = yields
	# The plain wall a buried end runs into (contact with it is the bury).
	var buried: Array = ctx.get("buried", [])
	for part: Dictionary in candidate.parts:
		var local: AABB = catalog.descriptor(part.asset_id).measured_aabb
		if CLEARANCE.intersects_air(local, part.transform, ctx.air):
			return &"air"
		var box: AABB = (part.transform * local).grow(-0.002)
		for obstacle: Dictionary in ctx.obstacles:
			if bool(obstacle.get("gone", false)) or contact_clear(box, obstacle.bounds) \
					or buried.has(obstacle):
				continue
			var faces := own if obstacle.owner == mass.stable_id else _riders_of(obstacle.owner, ctx)
			if faces.is_empty():
				return _obstacle_cause(obstacle, mass)
			match _host_part(obstacle, faces):
				&"rides":
					continue
				&"yields":
					if not yields.has(obstacle):
						yields.append(obstacle)
					continue
			return _obstacle_cause(obstacle, mass)
	return &""


## The stepping faces (as the host's own) of an active row member's house at the
## storey under test.
static func _riders_of(owner: StringName, ctx: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if owner == &"":
		return out
	for rider: Dictionary in ctx.get("riders", []):
		if rider.owner == owner:
			out.append(rider)
	return out


## How a part of a stepping house meets that house's stepping face(s): &"rides"
## (it is no obstacle: walls, posts, the closing crown, a bay on the face, decor
## `apply` moves out), &"yields" (an ornament of a yielding kind under the new
## braces) or &"blocks" (roofs, chimneys, rails, decks and other ornaments).
static func _host_part(obstacle: Dictionary, faces: Array[Dictionary]) -> StringName:
	var role := String(obstacle.role)
	for face: Dictionary in faces:
		if int(face.crown) >= 0 and int(obstacle.roof_index) == int(face.crown):
			return &"rides"
	if not OWN_OBSTACLES.any(func(prefix: String) -> bool: return role.begins_with(prefix)):
		return &"rides"
	if obstacle.has("decor"):
		for face: Dictionary in faces:
			var c: Dictionary = face.candidate
			if _moves(obstacle.decor, int(c.projection.dir), c.centres, int(c.first_band),
					int(c.band) + int(c.bands), face.kit):
				return &"rides"
		return &"yields" if StringName(obstacle.decor.kind) in YIELD_DECOR else &"blocks"
	if role.begins_with("bay."):
		for face: Dictionary in faces:
			if (face.slab as AABB).has_point((obstacle.bounds as AABB).get_center()):
				return &"rides"
	return &"blocks"


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


# --- roofs (G7: the last storey of a face must be closed above its step) ------

const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
## Keep the leaned wall face this far inside the eave's measured reach.
const EAVE_MARGIN := 0.1
## The cornice's top surface must stand this far above a leaned wall head.
const EAVE_COVER := 0.05
const EAVE_SAMPLE := 0.05


## Baked roof skins of every kit (read once on the caller's thread).
static func roof_geometry(kits: Array) -> Dictionary:
	var geometry := {}
	var loaded := {}
	for kit: BuildingKit in kits:
		UNION._load_geometry(kit, geometry, loaded)
	return geometry


## The roof wing closing this storey's crown over the face, or {} when the face is
## covered by a storey above (not the next leaned storey), a deck, or nothing.
static func crown_wing(mass: BuildingMass, chain: Dictionary, k: int) -> Dictionary:
	var storey: Dictionary = mass.storeys[chain.storeys[k]]
	var top := int(storey.floor_band) + int(storey.get("bands", 2))
	var above := mass.cells_at_band(top)
	for edge: Vector3i in _edges(chain):
		if above.has(Vector2i(edge.x, edge.y)):
			return {}
	var index := crown_index(mass, chain, k)
	for wing: Dictionary in mass.roofs:
		if int(wing.eave_band) == top and int(wing.get("union_index", -1)) == index:
			var rect: Rect2i = wing.rect
			if _edges(chain).all(func(e: Vector3i) -> bool: return rect.has_point(Vector2i(e.x, e.y))):
				return wing
	return {}


## How far (native m) a top storey may lean under this eave: the measured reach
## bounds the scan; the baked roof skin gives the cornice's top surface, which
## must cover the leaned wall head (lowered by OFFSET_WALL_DROP, posts +0.074).
static func eave_allowance(kit: BuildingKit, catalog: EnvironmentCatalog, geometry: Dictionary,
		wing: Dictionary, side: int) -> float:
	var colour := StringName(wing.colour)
	if bool(BuildingKitAssembler.tight_eave_sides(wing) & (1 << side)) \
			and kit.has_role(StringName("roof.%s.eave_tight" % colour)):
		return 0.0
	var role := StringName("roof.%s.eave" % colour)
	if not kit.has_role(role):
		return 0.0
	var id := kit.asset(role)
	var local := kit.anchor(role) * kit.asset_anchor(id)
	var reach: float = (local * catalog.descriptor(id).measured_aabb).end.z
	var surfaces: Array = geometry.get(id, geometry.get(kit.geometry_aliases.get(id, id), []))
	if surfaces.is_empty():
		return 0.0
	var head := -BuildingKitAssembler.OFFSET_WALL_DROP + 0.074 + EAVE_COVER
	var allowed := 0.0
	var z := kit.wall_face
	while z <= reach - EAVE_MARGIN:
		var top := -INF
		for surface: Dictionary in surfaces:
			for v: Vector3 in local * (surface.vertices as PackedVector3Array):
				if absf(v.z - z) <= EAVE_SAMPLE:
					top = maxf(top, v.y)
		if top < head:
			break
		allowed = z - kit.wall_face
		z += EAVE_SAMPLE
	return allowed


## Why this gable end cannot move out `lean` with its top storey (&"" when it can):
## caps (edge-capped families), open (an open, extended, tight-eaved end), verge
## (a fitted verge or clip), dormer (a dormer at the end), span (the wing is wider
## than the stepping face), filler (no baked skin to clip), air, obstacle.
static func _gable_shift_fault(mass: BuildingMass, chain: Dictionary, wing: Dictionary,
		lean: float, ctx: Dictionary) -> StringName:
	var kit: BuildingKit = ctx.kit
	if kit.roof_edge_caps:
		return &"caps" # capped families cannot be clipped cleanly (spec risk)
	var axis := int(wing.axis)
	var positive := int(chain.dir) < 2
	var rect: Rect2i = wing.rect
	if bool(wing.open_max if positive else wing.open_min) \
			or int(wing.extend_max if positive else wing.extend_min) != 0 \
			or BuildingKitAssembler.tight_eave_sides(wing) != 0:
		return &"open"
	for key: String in (["verge_max", "clip_max"] if positive else ["verge_min", "clip_min"]):
		if wing.has(key):
			return &"verge"
	var end_slot := rect.end[axis] if positive else rect.position[axis]
	for side in 2:
		if (wing.dormers as Dictionary).has(Vector2i(side, end_slot)):
			return &"dormer"
	if rect.position[1 - axis] != int(chain.start) or rect.end[1 - axis] != int(chain.end):
		return &"span"
	var probe := wing.duplicate()
	probe["lean_max" if positive else "lean_min"] = lean
	var geometry: Dictionary = ctx.geometry
	for part: Dictionary in BuildingKitAssembler.new(kit).roof_parts(mass, probe):
		if bool(part.get("lean_filler", false)) and not geometry.has(part.asset_id):
			return &"filler" # an unclippable filler would overlap the moved end
		# A filler stands where the end piece stood (clipped to the opened strip):
		# only the moved end can meet something new.
		if not bool(part.get("lean_end", false)):
			continue
		var local: AABB = (ctx.catalog as EnvironmentCatalog).descriptor(part.asset_id).measured_aabb
		if CLEARANCE.intersects_air(local, part.transform, ctx.air):
			return &"air"
		var box: AABB = (part.transform * local).grow(-0.002)
		for obstacle: Dictionary in ctx.obstacles:
			if bool(obstacle.get("gone", false)) or contact_clear(box, obstacle.bounds) \
					or not _blocks_gable(obstacle, mass, int(wing.get("union_index", -1))) \
					or (obstacle.owner == mass.stable_id and String(obstacle.role).begins_with("bay.") \
						and _on_face(obstacle.bounds, mass, chain, kit)) \
					or _moves_with_front(obstacle, ctx, box) \
					or not _skin_meets(part, geometry, (obstacle.bounds as AABB).grow(-TOUCH)):
				continue
			return StringName("%s.%s" % [_obstacle_cause(obstacle, mass), String(obstacle.role).get_slice(".", 0)])
	return &""


## Whether a placed piece's baked skin (when baked; else its box) enters `box`:
## a sloped roof piece's box is mostly air, so boxes alone over-block.
static func _skin_meets(part: Dictionary, geometry: Dictionary, box: AABB) -> bool:
	if not box.has_volume():
		return false
	var surfaces: Array = geometry.get(part.asset_id, [])
	if surfaces.is_empty():
		return true
	var transform: Transform3D = part.transform
	var corners: Array[Vector3] = []
	for i in 8:
		corners.append(box.get_endpoint(i))
	const BOX_EDGES := [[0, 1], [0, 2], [0, 4], [1, 3], [1, 5], [2, 3], [2, 6], [3, 7], [4, 5], [4, 6], [5, 7], [6, 7]]
	for surface: Dictionary in surfaces:
		var vertices: PackedVector3Array = transform * (surface.vertices as PackedVector3Array)
		var indices: PackedInt32Array = surface.get("indices", PackedInt32Array())
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for t in range(0, count - 2, 3):
			var a := vertices[indices[t] if not indices.is_empty() else t]
			var b := vertices[indices[t + 1] if not indices.is_empty() else t + 1]
			var c := vertices[indices[t + 2] if not indices.is_empty() else t + 2]
			if box.has_point(a) or box.intersects_segment(a, b) or box.intersects_segment(b, c) \
					or box.intersects_segment(c, a):
				return true
			for edge: Array in BOX_EDGES:
				if Geometry3D.segment_intersects_triangle(corners[edge[0]], corners[edge[1]], a, b, c) != null:
					return true
	return false


## True when a piece of the house stands on this stepping face (a bay on it rides
## out with the face, so its recorded box is where it no longer stands).
static func _on_face(bounds: AABB, mass: BuildingMass, chain: Dictionary, kit: BuildingKit) -> bool:
	var dir := int(chain.dir)
	var c := bounds.get_center() / kit.module_width
	var along := c.x if dir % 2 == 1 else c.z
	var across := (c.z if dir % 2 == 1 else c.x) - float(int(chain.line))
	var out := float(BuildingMass.DIRS[dir].y if dir % 2 == 1 else BuildingMass.DIRS[dir].x)
	var first: Dictionary = mass.storeys[chain.storeys[0]]
	var last: Dictionary = mass.storeys[chain.storeys[-1]]
	var y := bounds.get_center().y / kit.band_height()
	return along > float(int(chain.start)) and along < float(int(chain.end)) \
		and across * out > -0.5 and across * out < 1.5 \
		and y >= float(int(first.floor_band)) and y < float(int(last.floor_band) + int(last.get("bands", 2)))


## Whether a piece stands in a moved gable end's way: anything of another house
## (or a tower or committed step), and of its own house the roofs of its other
## wings, chimneys, bays, rails and decks; never its own roof wing or its walls
## (the stepped storey the gable now stands on).
static func _blocks_gable(obstacle: Dictionary, mass: BuildingMass, union_index: int) -> bool:
	if obstacle.owner != mass.stable_id:
		return true
	if union_index >= 0 and int(obstacle.get("roof_index", -1)) == union_index:
		return false
	var role := String(obstacle.role)
	return OWN_OBSTACLES.any(func(prefix: String) -> bool: return role.begins_with(prefix))


## A piece that is not in the way of a moved gable end: a row partner's own moving
## roof end (its crown wing; it steps with the row), or a piece of the building
## this member's end is buried in where the roof dies into that building
## (KitRoofMeshUnion trims roof triangles inside every storey volume): its plain
## walls, posts and beams, and anything the moved piece (`box`) meets from inside
## that building (its floors; the back of a wall facing away).
static func _moves_with_front(obstacle: Dictionary, ctx: Dictionary, box := AABB()) -> bool:
	for rider: Dictionary in ctx.get("riders", []):
		if rider.owner == obstacle.owner and int(obstacle.get("roof_index", -1)) == int(rider.get("crown", -2)):
			return true
	for contact: Dictionary in ctx.get("buried", []):
		if contact.owner != obstacle.owner:
			continue
		# Its roof skins: the union trims each roof skin inside every other roof's volume.
		if String(obstacle.role).begins_with("roof."):
			return true
		for prefix: String in PLAIN_CONTACT:
			if String(obstacle.role).begins_with(prefix):
				return true
		var host: BuildingMass = (ctx.get("masses", {}) as Dictionary).get(obstacle.owner, null)
		if host != null and box.has_volume() and _behind(host, obstacle.bounds, box, ctx.kit):
			return true
	return false


## True when `box` meets `bounds` (a piece of `host`) from inside `host`: past a
## wall's inner face, or at a piece that stands within the host's storeys.
static func _behind(host: BuildingMass, bounds: AABB, box: AABB, kit: BuildingKit) -> bool:
	var inside := func(p: Vector3) -> bool:
		var band := floori(p.y / kit.band_height())
		return host.cells_at_band(band).has(Vector2i(floori(p.x / kit.module_width), floori(p.z / kit.module_width)))
	var centre := bounds.get_center()
	var thin := 0 if bounds.size.x < bounds.size.z else 2
	if bounds.size[thin] > kit.module_width * 0.5:
		return bool(inside.call(centre)) # not a wall panel: a floor, beam or fitting
	# A wall panel: the side of it inside the host is its back.
	var probe := centre
	probe[thin] += bounds.size[thin] * 0.5 + 0.1
	var back := 1.0 if bool(inside.call(probe)) else -1.0
	if back < 0.0:
		probe[thin] -= bounds.size[thin] + 0.2
		if not bool(inside.call(probe)):
			return false # open on both sides: not a wall of this building
	var overlap := box.intersection(bounds).get_center()
	return signf(overlap[thin] - centre[thin]) == back


# G7 and the crown rule: the last storey of a face must be closed above its step:
# a gable end that moves with it, or an eave whose measured cornice covers it (the
# house's ground storey stepping in lowers the face by one jetty).
static func _crown_fault(mass: BuildingMass, chain: Dictionary, k: int, lean: float,
		ctx: Dictionary) -> StringName:
	if k < (chain.storeys as Array).size() - 1:
		return &"" # the next storey of the chain steps at least as far
	var wing := crown_wing(mass, chain, k)
	if wing.is_empty():
		ctx.crown_kind = &"open"
		ctx.crown_why = &"covered" if mass.cells_at_band(int(mass.storeys[chain.storeys[k]].floor_band) \
			+ int(mass.storeys[chain.storeys[k]].get("bands", 2))).has(Vector2i(_edges(chain)[0].x, _edges(chain)[0].y)) \
			else &"unroofed"
		return &"crown"
	var dir := int(chain.dir)
	if int(wing.axis) == dir % 2:
		ctx.crown_kind = &"gable"
		ctx.crown_why = _gable_shift_fault(mass, chain, wing, lean, ctx)
		return &"" if ctx.crown_why == &"" else &"crown"
	ctx.crown_kind = &"eave"
	ctx.crown_why = &"cornice"
	return &"" if lean <= _eave_cap(wing, dir, ctx) + 0.0001 else &"crown"


static func _eave_cap(wing: Dictionary, dir: int, ctx: Dictionary) -> float:
	var side := 0 if dir < 2 else 1
	var key := "%s|%s|%d|%d" % [ctx.kit.kit_id, wing.colour, side, BuildingKitAssembler.tight_eave_sides(wing)]
	if not (ctx.allowances as Dictionary).has(key):
		ctx.allowances[key] = eave_allowance(ctx.kit, ctx.catalog, ctx.geometry, wing, side)
	return float(ctx.allowances[key])


# --- the stepped-in ground run (eave faces; controller ruling, fix round 1) ----

## Kinds of the house's own ground dressing on the inset run that follow its wall in.
const INSET_DECOR: Array[StringName] = [&"window_box", &"ivy", &"ivy_corner"]
const NO_EDGE := Vector3i(-1048576, 0, 0)


## Why the ground storey cannot step in under this eave face (&"" when it can).
## One face only: the run's ground walls move in by the kit jetty (wall_offsets
## < 0), the perpendicular walls' corner panels give way to the baked d100 return
## strip (the jetty is half a module, so the strip is exactly the remaining half),
## and the storey above carries the overhang on its floor beam and the kit's own
## jetty braces. Causes: inset.kit (no jetty or strip, or the jetty is not half a
## module), inset.house (a pulled house), inset.course (stone, retaining, fortified,
## sunk, one-band, abutted or pent-eaved ground storey), inset.above (the storey
## above does not cover the run), inset.depth (under two modules deep), inset.portal
## (a door, passage, bay or blank on the run or on a corner panel that gives way),
## inset.party (anything touching the run or the corner panels: party walls never
## step in), inset.corner (the perpendicular face already stepped in), inset.decor
## (a porch canopy or post on the run), inset.air / inset.obstacle.* (the new
## pieces meet walking air or another building).
static func _inset_cause(mass: BuildingMass, kit: BuildingKit, chain: Dictionary, ctx: Dictionary) -> StringName:
	var depth := kit.jetty_depth
	if not kit.has_role(&"bracket.jetty") or not is_equal_approx(depth * 2.0, kit.module_width) \
			or not kit.has_role(StringName("frontage.return.%s" % BuildingKitAssembler.lean_suffix(depth))):
		return &"inset.kit"
	if not mass.grows:
		return &"inset.house"
	var g := ground_index(mass)
	var ground: Dictionary = mass.storeys[g]
	var band := int(ground.floor_band)
	if int(ground.get("bands", 2)) != 2 or ground.material != BuildingMass.MATERIAL_TIMBER \
			or bool(ground.get("retaining", false)) or bool(ground.get("fortified", false)) \
			or bool(ground.get("sunk", false)) or bool(ground.get("inset", false)) \
			or bool(ground.get("abutted", false)) or StringName(ground.get("pent_colour", &"")) != &"":
		return &"inset.course"
	var above := _storey_at(mass, band + 2)
	var dir := int(chain.dir)
	var out: Vector2i = BuildingMass.DIRS[dir]
	var own := _own(mass)
	var solid: Callable = ctx.solid
	var offsets: Dictionary = ground.get("wall_offsets", {})
	var cells: Dictionary = ground.cells
	var blocked := [BuildingMass.OPENING_DOOR, BuildingMass.OPENING_BAY, BuildingMass.OPENING_NONE]
	for edge: Vector3i in _edges(chain):
		var cell := Vector2i(edge.x, edge.y)
		if above.is_empty() or not (above.cells as Dictionary).has(cell):
			return &"inset.above"
		if not cells.has(cell) or cells.has(cell + out) or not cells.has(cell - out):
			return &"inset.depth"
		if StringName(ground.openings.get(edge, ground.default_opening)) in blocked \
				or (ground.get("passage_edges", {}) as Dictionary).has(edge):
			return &"inset.portal"
		for b in range(band, band + 2):
			if bool(solid.call(own, cell + out, b)):
				return &"inset.party"
	# The corner panel of each perpendicular face at a convex end gives way.
	for corner: Dictionary in _inset_corners(mass, chain):
		var edge: Vector3i = corner.edge
		if not corner.convex:
			return &"inset.party" # the run ends against its own wall: nothing to shorten cleanly
		if float(offsets.get(edge, 0.0)) != 0.0:
			return &"inset.corner"
		if StringName(ground.openings.get(edge, ground.default_opening)) in blocked \
				or (ground.get("passage_edges", {}) as Dictionary).has(edge):
			return &"inset.portal"
		for b in range(band, band + 2):
			if bool(solid.call(own, Vector2i(edge.x, edge.y) + BuildingMass.DIRS[edge.z], b)):
				return &"inset.party"
	for item: Dictionary in mass.decor:
		if _on_storey(item, ground, kit) and not (StringName(item.kind) in INSET_DECOR) \
				and _decor_edge(item) != NO_EDGE \
				and (_edges(chain).has(_decor_edge(item)) or _corner_edges(mass, chain).has(_decor_edge(item))):
			return &"inset.decor"
	return _inset_parts_fault(mass, kit, chain, ctx)


## The perpendicular ground faces at both ends of the run: {edge, convex}.
static func _inset_corners(mass: BuildingMass, chain: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := int(chain.dir)
	var along := Vector2i(0, 1) if dir % 2 == 0 else Vector2i(1, 0)
	var ground: Dictionary = mass.storeys[ground_index(mass)]
	for at_end: bool in [false, true]:
		var sign := 1 if at_end else -1
		var cell := BuildingKitAssembler._inside_cell(dir, int(chain.line), int(chain.end) - 1 if at_end else int(chain.start))
		var side := BuildingMass.DIRS.find(along * sign)
		out.append({"edge": BuildingMass.edge_key(cell, side),
			"convex": not (ground.cells as Dictionary).has(cell + along * sign)})
	return out


static func _corner_edges(mass: BuildingMass, chain: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for corner: Dictionary in _inset_corners(mass, chain):
		out.append(corner.edge)
	return out


## The wall edge a decor item stands on (its centre is a slot centre).
static func _decor_edge(item: Dictionary) -> Vector3i:
	if not item.has("dir") or not item.has("centre"):
		return NO_EDGE
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


## Writes the inset (ground wall offsets) into the house; returns the edges.
static func _write_inset(mass: BuildingMass, kit: BuildingKit, chain: Dictionary) -> void:
	var ground: Dictionary = mass.storeys[ground_index(mass)]
	var offsets: Dictionary = ground.get("wall_offsets", {})
	for edge: Vector3i in _edges(chain):
		offsets[edge] = -kit.jetty_depth / kit.module_width
	ground["wall_offsets"] = offsets


static func _erase_inset(mass: BuildingMass, chain: Dictionary) -> void:
	var ground: Dictionary = mass.storeys[ground_index(mass)]
	var offsets: Dictionary = ground.get("wall_offsets", {})
	for edge: Vector3i in _edges(chain):
		offsets.erase(edge)
	if offsets.is_empty():
		ground.erase("wall_offsets")


## The pieces the inset adds (the house assembled with and without it, compared):
## the side strips, posts, floor beams, braces and return beams.
static func _inset_parts(mass: BuildingMass, kit: BuildingKit, chain: Dictionary, ctx: Dictionary) -> Array[Dictionary]:
	var decor := mass.decor.duplicate()
	mass.decor.clear()
	var assembler := _assembler(mass, kit, ctx.solid)
	var before := {}
	for part: Dictionary in assembler.assemble(mass):
		before["%s|%s" % [part.asset_id, part.transform]] = true
	_write_inset(mass, kit, chain)
	var added: Array[Dictionary] = []
	for part: Dictionary in assembler.assemble(mass):
		if not before.has("%s|%s" % [part.asset_id, part.transform]):
			added.append(part)
	_erase_inset(mass, chain)
	mass.decor.assign(decor)
	return added


## The new pieces stay clear of walking air and of everything not this house.
static func _inset_parts_fault(mass: BuildingMass, kit: BuildingKit, chain: Dictionary, ctx: Dictionary) -> StringName:
	for part: Dictionary in _inset_parts(mass, kit, chain, ctx):
		var local: AABB = (ctx.catalog as EnvironmentCatalog).descriptor(part.asset_id).measured_aabb
		if CLEARANCE.intersects_air(local, part.transform, ctx.air):
			return &"inset.air"
		var box: AABB = (part.transform * local).grow(-0.002)
		for obstacle: Dictionary in ctx.obstacles:
			if bool(obstacle.get("gone", false)) or obstacle.owner == mass.stable_id \
					or contact_clear(box, obstacle.bounds):
				continue
			# This house's own committed steps stand on it: their braces bear on its
			# ground walls, their floor strips on its wall heads (a seated seam).
			if obstacle.get("stepped_host", &"") == mass.stable_id and (String(obstacle.role).begins_with("bracket.") \
					or _seated(box, obstacle.bounds)):
				continue
			return StringName("inset.%s" % String(_obstacle_cause(obstacle, mass)))
	return &""


## Steps one eave face's ground run in: its walls (and their window boxes and ivy)
## move in by the kit jetty, the corner panels of the perpendicular faces give way
## to the d100 strip (their dressing yields), and the new pieces join the obstacles.
static func _apply_inset(mass: BuildingMass, kit: BuildingKit, chain: Dictionary, ctx: Dictionary) -> void:
	var added := _inset_parts(mass, kit, chain, ctx)
	_write_inset(mass, kit, chain)
	var ground: Dictionary = mass.storeys[ground_index(mass)]
	var run := _edges(chain)
	var corners := _corner_edges(mass, chain)
	var catalog: EnvironmentCatalog = ctx.catalog
	var dir := int(chain.dir)
	for item: Dictionary in mass.decor.duplicate():
		if not _on_storey(item, ground, kit) or not (StringName(item.kind) in INSET_DECOR):
			continue
		var edge := _decor_edge(item)
		if corners.has(edge) or (StringName(item.kind) == &"ivy_corner" and corners.has(
				BuildingMass.edge_key(Vector2i(edge.x, edge.y), BuildingMass.DIRS.find(BuildingKitAssembler.right_of(edge.z))))):
			_drop_decor(ctx, item)
			mass.decor.erase(item)
		elif run.has(edge):
			_drop_decor(ctx, item)
			item.centre = (item.centre as Vector2) - Vector2(BuildingMass.DIRS[dir]) * kit.jetty_depth / kit.module_width
			var assembly := {"mass": mass, "out": [] as Array[Dictionary], "serial": 0}
			_assembler(mass, kit, ctx.solid)._assemble_decor(assembly, item)
			for part: Dictionary in assembly.out:
				var obstacle := _obstacle(mass, part, catalog)
				obstacle["decor"] = item
				obstacle["host"] = mass
				ctx.obstacles.append(obstacle)
	for part: Dictionary in added:
		ctx.obstacles.append(_obstacle(mass, part, catalog))
	ctx.inset_records.append({"host": mass.stable_id, "chain": String(chain.key), "depth": kit.jetty_depth})


## An eave face whose crown kept it flush (an eave-crown withdrawal, no step left)
## takes the inset where it can; recorded on the face's roof record.
static func _try_inset(member: Dictionary, ctx: Dictionary) -> bool:
	var chain: Dictionary = member.chain
	if not (ctx.eave_crowned as Dictionary).has(String(chain.key)):
		return false
	var mass: BuildingMass = member.mass
	ctx.kit = member.kit
	var cause := _inset_cause(mass, member.kit, chain, ctx)
	if cause != &"":
		ctx.rejections.append({"chain": String(chain.key), "storey": -1, "lean": -member.kit.jetty_depth,
			"cause": cause})
		return false
	_apply_inset(mass, member.kit, chain, ctx)
	return true


## How one member's roof closes its steps (for the corpus audit): gable (its top
## storey moved the gable end), inset (its ground run stepped in under the eave),
## half (an eave-crowned front fell back to the light step), eave (stays under the
## cornice), flush (no step at all).
static func _record_roof(member: Dictionary, profile: Array[float], inset: bool, half: bool,
		ctx: Dictionary) -> void:
	var mass: BuildingMass = member.mass
	var top := profile.size() - 1
	var wing := crown_wing(mass, member.chain, top) if top >= 0 else {}
	var gable := not wing.is_empty() and int(wing.axis) == int(member.chain.dir) % 2
	var kind := &"flush"
	if inset:
		kind = &"inset"
	elif top >= 0 and profile[top] > 0.0:
		kind = &"gable" if gable else &"half" if half else &"eave"
	ctx.roofs.append({"host": mass.stable_id, "chain": String(member.chain.key), "kind": kind})
