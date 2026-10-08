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
## Baked step sizes and the cumulative depths 1-4 steps of each produce (native m).
const STEP_SIZES: Array[float] = [0.25, 0.5]
const MAX_STEPS := 4
const LEAN_DEPTHS: Array[float] = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0]
const FRONT_ROLES: Array[StringName] = [&"frontage.floor", &"frontage.return", &"frontage.return_beam"]


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
	var below := _exposed_runs(mass, ground, solid)
	# Exposed runs per storey band, computed once for every chain key.
	var runs_at := {}
	for key: String in _exposed_runs(mass, first, solid):
		if not below.has(key):
			continue
		var run: Dictionary = below[key]
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
			"key": "%s|%s" % [mass.stable_id, key]})
	chains.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.key) < String(b.key))
	return chains


## At least one storey above the ground storey on a street face (2+ storeys total).
static func house_eligible(mass: BuildingMass, solid: Callable, street: Callable) -> bool:
	if String(mass.stable_id).contains("wall-room"):
		return false
	for chain: Dictionary in face_chains(mass, solid, street):
		if bool(chain.street) and (chain.storeys as Array).size() >= 1:
			return true
	return false


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
## {leans, registry}: one entry per leaned storey face, and the accepted lean per
## Vector4i(cell.x, cell.z, dir, band) for facing-gap checks by later fitters.
static func fit(masses: Array[BuildingMass], kits: Dictionary, base: BuildingKit,
		catalog: EnvironmentCatalog, character: TownCharacter, air: Array[Dictionary],
		towers: Array[Dictionary], reserved: Callable, solid: Callable,
		street: Callable) -> Dictionary:
	var leans: Array[Dictionary] = []
	var ctx := {"catalog": catalog, "air": air, "towers": towers, "reserved": reserved,
		"solid": solid, "registry": {}, "obstacles": [], "gap": 0.0, "kit": base}
	if character == null or not masses.any(func(m: BuildingMass) -> bool: return m.grows):
		return {"leans": leans, "registry": ctx.registry}
	ctx.gap = character.value(GAP_KNOB)
	ctx.obstacles = _obstacles(masses, kits, base, catalog, towers, solid)
	for mass: BuildingMass in masses:
		if not mass.grows or not kits.has(_own(mass)):
			continue
		var kit: BuildingKit = kits[_own(mass)]
		ctx.kit = kit
		if not kit.has_role(StringName("frontage.return.%s" % BuildingKitAssembler.lean_suffix(STEP_SIZES[0]))):
			continue
		var step := float(String(character.pick(STEP_KNOB, String(mass.stable_id))))
		if not STEP_SIZES.has(step):
			continue
		var cap := step * float(mini(MAX_STEPS, floori(character.value(CAP_KNOB) / step + 0.0001)))
		for chain: Dictionary in face_chains(mass, solid, street):
			var knob := STREET_FACE_KNOB if bool(chain.street) else OTHER_FACE_KNOB
			if not character.chance(knob, String(chain.key)):
				continue
			_commit(mass, kit, chain, _profile(mass, chain, step, cap, ctx), ctx, leans)
	return {"leans": leans, "registry": ctx.registry}


## Monotone cumulative leans for one face (index k = k-th storey of the chain):
## storey k wants min((k+1) step, cap). A failing step is withdrawn and every
## storey above keeps the last accepted lean; a storey that cannot hold even that
## drops the face cap one step and the face is fitted again from the bottom, so
## leans never decrease upward.
static func _profile(mass: BuildingMass, chain: Dictionary, step: float, cap: float,
		ctx: Dictionary) -> Array[float]:
	var n := (chain.storeys as Array).size()
	var leans: Array[float] = []
	leans.resize(n)
	leans.fill(0.0)
	var face_cap := cap
	var k := 0
	while k < n:
		var held := 0.0 if k == 0 else leans[k - 1]
		var want := minf(float(k + 1) * step, face_cap)
		if want > held and _fits(mass, chain, k, want, held, ctx):
			leans[k] = want
			k += 1
			continue
		# Withdraw this storey's step: it and every storey above keep the last accepted lean.
		face_cap = held
		if held <= 0.0:
			break
		if _fits(mass, chain, k, held, held, ctx):
			leans[k] = held
			k += 1
			continue
		# This storey cannot hold even the lean below it: an inward step would leave
		# an open ledge, so the whole face drops one step and is fitted again.
		face_cap = held - step
		leans.fill(0.0)
		k = 0
	return leans


## Guardrails for storey k of a face at `lean` over `base` (Task 5 extends).
static func _fits(mass: BuildingMass, chain: Dictionary, k: int, lean: float, base: float,
		ctx: Dictionary) -> bool:
	var storey: Dictionary = mass.storeys[chain.storeys[k]]
	if storey.material != BuildingMass.MATERIAL_TIMBER or bool(storey.get("inset", false)) \
			or bool(storey.get("retaining", false)) or bool(storey.get("fortified", false)):
		return false
	if not _no_portal(mass, chain, k) or not _ends_clear(mass, chain, k, ctx) \
			or not _columns_free(mass, chain, k, ctx):
		return false
	if not gap_ok(ctx.registry, ctx.solid, _own(mass), _edges(chain), int(chain.dir),
			int(storey.floor_band), lean, ctx.kit, float(ctx.gap)):
		return false
	var candidate := _candidate(mass, ctx.kit, chain, k, lean, base, ctx.solid)
	return _parts_clear(mass, candidate, crown_index(mass, chain, k), ctx)


## One storey's leaned front: its projection record, outer body box and pieces.
static func _candidate(mass: BuildingMass, kit: BuildingKit, chain: Dictionary, k: int,
		lean: float, base: float, solid: Callable) -> Dictionary:
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
		"base": base, "band": band, "growth": true}
	var at: Vector2 = centres.front() * kit.module_width
	var pose := Transform3D(Basis(Vector3.UP, BuildingKitAssembler.yaw_for_dir(dir)),
		Vector3(at.x, band * kit.band_height(), at.y))
	var body := AABB(Vector3(-kit.module_width * .5, 0, 0),
		Vector3(centres.size() * kit.module_width, kit.storey_height, lean + kit.wall_face))
	return {"index": index, "projection": projection, "edges": edges, "centres": centres,
		"band": band, "pose": pose, "bounds": pose * body,
		"parts": _assembler(mass, kit, solid).face_parts(mass, index, projection)}


## An assembler that sees other buildings as the final assembly does, so a
## candidate's slots and an obstacle's parts match what is finally built.
static func _assembler(mass: BuildingMass, kit: BuildingKit, solid: Callable) -> BuildingKitAssembler:
	var assembler := BuildingKitAssembler.new(kit)
	var own := _own(mass)
	assembler.external_blocked = func(cell: Vector2i, band: int) -> bool:
		return bool(solid.call(own, cell, band))
	return assembler


static func _commit(mass: BuildingMass, kit: BuildingKit, chain: Dictionary,
		profile: Array[float], ctx: Dictionary, out: Array[Dictionary]) -> void:
	var dir := int(chain.dir)
	for k in profile.size():
		var lean := profile[k]
		if lean <= 0.0:
			continue
		var base := 0.0 if k == 0 else profile[k - 1]
		var candidate := _candidate(mass, kit, chain, k, lean, base, ctx.solid)
		var storey: Dictionary = mass.storeys[candidate.index]
		var offsets: Dictionary = storey.get("wall_offsets", {})
		for edge: Vector3i in candidate.edges:
			offsets[edge] = lean / kit.module_width
		storey["wall_offsets"] = offsets
		var fronts: Array = storey.get("projections", [])
		fronts.append(candidate.projection)
		storey["projections"] = fronts
		var leaning: Dictionary = storey.get("growth", {})
		leaning[dir] = lean
		storey["growth"] = leaning
		# Window boxes on the face move out with it (as projections do).
		for item: Dictionary in mass.decor:
			if not item.has("dir") or int(item.dir) != dir \
					or absf(float(item.get("y", -INF)) - candidate.band * kit.band_height()) > .01:
				continue
			if (candidate.centres as Array).has(item.centre):
				item.centre += Vector2(BuildingMass.DIRS[dir]) * lean / kit.module_width
				item.y = float(item.y) - BuildingKitAssembler.OFFSET_WALL_DROP
		for band in [candidate.band, candidate.band + 1]:
			for edge: Vector3i in candidate.edges:
				ctx.registry[Vector4i(edge.x, edge.y, dir, band)] = lean
		for part: Dictionary in candidate.parts:
			ctx.obstacles.append({"owner": &"", "role": String(part.role), "roof_index": -1,
				"bounds": part.transform * (ctx.catalog as EnvironmentCatalog).descriptor(part.asset_id).measured_aabb})
		out.append({"host": mass.stable_id, "dir": dir, "band": candidate.band, "lean": lean,
			"base": base, "edges": candidate.edges, "bounds": candidate.bounds, "chain": chain.key})


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
		for part: Dictionary in _assembler(mass, kits.get(_own(mass), base), solid).assemble(mass):
			out.append({"owner": mass.stable_id, "role": String(part.role),
				"roof_index": int(part.get("roof_index", -1)),
				"bounds": part.transform * catalog.descriptor(part.asset_id).measured_aabb})
	for tower: Dictionary in towers:
		out.append({"owner": &"", "role": "tower", "roof_index": -1, "bounds": tower.bounds})
	return out


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


# G1 + G3: no leaned piece enters public walking air or a skywalk's air (G1), nor
# another building, skywalk, tower, balcony, canopy or own roof/ornament (G3).
static func _parts_clear(mass: BuildingMass, candidate: Dictionary, crown: int,
		ctx: Dictionary) -> bool:
	var catalog: EnvironmentCatalog = ctx.catalog
	var blocks := func(obstacle: Dictionary) -> bool: return _blocks(obstacle, mass, crown)
	for part: Dictionary in candidate.parts:
		var local: AABB = catalog.descriptor(part.asset_id).measured_aabb
		if CLEARANCE.intersects_air(local, part.transform, ctx.air):
			return false
		if not clear_of((part.transform * local).grow(-0.002), ctx.obstacles, blocks):
			return false
	return true


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


# G4: the run is a whole convex face with nothing beside or diagonally beyond its
# ends, and no perpendicular face of this storey leans (returns would collide).
static func _ends_clear(mass: BuildingMass, chain: Dictionary, k: int, ctx: Dictionary) -> bool:
	var storey: Dictionary = mass.storeys[chain.storeys[k]]
	var dir := int(chain.dir)
	var leaning: Dictionary = storey.get("growth", {})
	if leaning.has((dir + 1) % 4) or leaning.has((dir + 3) % 4):
		return false
	var whole := false
	for run: Dictionary in BuildingKitAssembler.boundary_runs(storey.cells):
		if int(run.dir) == dir and int(run.line) == int(chain.line) \
				and int(run.start) == int(chain.start) and int(run.end) == int(chain.end):
			whole = bool(run.start_convex) and bool(run.end_convex)
	if not whole:
		return false
	var own := _own(mass)
	var solid: Callable = ctx.solid
	var band := int(storey.floor_band)
	var along := Vector2i(0, 1) if dir % 2 == 0 else Vector2i(1, 0)
	for end: Array in [[int(chain.start), -1], [int(chain.end) - 1, 1]]:
		var side: Vector2i = BuildingKitAssembler._inside_cell(dir, int(chain.line), end[0]) + along * int(end[1])
		var diagonal: Vector2i = side + BuildingMass.DIRS[dir]
		for b in [band, band + 1]:
			if bool(solid.call(own, side, b)) or bool(solid.call(own, diagonal, b)) \
					or mass.cells_at_band(b).has(diagonal):
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
