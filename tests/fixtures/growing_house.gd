extends RefCounted
## Growing-floor fixtures. A house under test fronts a one-cell lane at z = -1
## (native z -2..0); an optional facing house stands across it. Native frame:
## module 2 m, band 1.5 m, storey = 2 bands.

const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")

## A plain timber house of `storeys` identical floors with a ground door on `door_dir`.
static func house(id: StringName, rect: Rect2i, storeys: int, door_dir: int) -> BuildingMass:
	var mass := BuildingMass.new()
	mass.stable_id = id
	mass.seed = hash(String(id))
	mass.ground_band = 0
	for s in storeys:
		mass.add_storey(s * 2, BuildingMass.rect_cells(rect), BuildingMass.MATERIAL_TIMBER)
	var row := rect.position.y if door_dir == 3 else rect.end.y - 1
	mass.storeys[0].openings[BuildingMass.edge_key(Vector2i(rect.position.x + 1, row), door_dir)] = \
		BuildingMass.OPENING_DOOR
	return mass


## A timber house with a pitched roof over its whole rect (axis 1 = gable to the lane).
static func roofed(id: StringName, rect: Rect2i, storeys: int, door_dir: int, axis := 1,
		union := 7) -> BuildingMass:
	var mass := house(id, rect, storeys, door_dir)
	mass.add_roof(rect, axis, storeys * 2, &"red")["union_index"] = union
	return mass


## Builtin odds with growth forced on for the house under test; `step` fixes
## growth_step ("1.0" = the kit jetty, the default; "0.5" = the light step).
static func character(values: Dictionary = {}, step := &"1.0") -> TownCharacter:
	var fixed := {&"growing_house_chance": 1.0, &"growth_street_face_chance": 1.0,
		&"growth_other_face_chance": 0.0, &"growth_max_lean": 2.0, &"lane_sky_gap": 0.75}
	fixed.merge(values, true)
	var c := TownCharacter.draw(TownOddsProgram.builtin().with_overrides(fixed), 1, 0.5)
	c.values[&"growth_step"] = {&"0.5": 1.0 if step == &"0.5" else 0.0,
		&"1.0": 1.0 if step == &"1.0" else 0.0}
	return c


static func street(cell: Vector2i, band: int) -> bool:
	return cell.y == -1 and band <= 1


## No other building is solid anywhere. The one shared `solid(own, cell, band)` stub.
static func nothing_solid(_own: StringName, _cell: Vector2i, _band: int) -> bool:
	return false


## {kit, front, back, masses, result, leans, parts, solid}. `front` (Rect2i(0,0,3,2),
## south face dir 3 on the lane) is the house under test; `back` faces it across
## a lane of `lane` cells (z -lane..-1) when options.facing. Options: storeys (4),
## roof_axis / back_roof_axis (1 = gable to the lane, 0 = eave), lane (1), facing,
## back_grows, character, air, towers, reserved, block (dirs of the front kept out of
## its front, block_faces), lone (= block [0, 2]: only the south face steps; the
## house's door is on the south ground storey, a recessed shopfront), kit, extra (more
## masses), prepare (Callable(front) run before fitting), replace_front (a mass with
## its own roofs, id kit.fixture.front).
static func build(options: Dictionary = {}) -> Dictionary:
	var kit: BuildingKit = options.get("kit", SuntailBuildingKit.create())
	var storeys := int(options.get("storeys", 4))
	var lane := int(options.get("lane", 1))
	var front: BuildingMass = options.get("replace_front", null)
	if front == null:
		front = house(&"kit.fixture.front", Rect2i(0, 0, 3, 2), storeys, 3)
		var front_roof := front.add_roof(Rect2i(0, 0, 3, 2), int(options.get("roof_axis", 1)), storeys * 2, &"red")
		front_roof["union_index"] = 0
	front.grows = true
	if options.has("prepare"):
		(options.prepare as Callable).call(front)
	var blocked: Array = options.get("block", [0, 2] if bool(options.get("lone", false)) else [])
	if not blocked.is_empty():
		block_faces(front, blocked)
	var masses: Array[BuildingMass] = []
	var back: BuildingMass = null
	if bool(options.get("facing", false)):
		var back_rect := Rect2i(0, -lane - 2, 3, 2)
		back = house(&"kit.fixture.back", back_rect, storeys, 1)
		var back_roof := back.add_roof(back_rect, int(options.get("back_roof_axis", 1)), storeys * 2, &"red")
		back_roof["union_index"] = 1
		back.grows = bool(options.get("back_grows", false))
		masses.append(back) # "kit.fixture.back" sorts before "kit.fixture.front"
	masses.append(front)
	for mass: BuildingMass in options.get("extra", []):
		masses.append(mass)
	var kits := {}
	for mass: BuildingMass in masses:
		kits[StringName(String(mass.stable_id).trim_prefix("kit."))] = kit
	var solid := func(own: StringName, cell: Vector2i, band: int) -> bool:
		for mass: BuildingMass in masses:
			if StringName(String(mass.stable_id).trim_prefix("kit.")) != own \
					and mass.cells_at_band(band).has(cell):
				return true
		return false
	var reserved: Callable = options.get("reserved", nothing_solid)
	var street := func(cell: Vector2i, band: int) -> bool:
		return cell.y <= -1 and cell.y >= -lane and band <= 1
	var result := GROWTH.fit(masses, kits, kit, EnvironmentCatalog.load_default(),
		options.get("character", character()), options.get("air", [] as Array[Dictionary]),
		options.get("towers", [] as Array[Dictionary]), reserved, solid, street)
	var assembler := BuildingKitAssembler.new(kit)
	assembler.external_blocked = func(cell: Vector2i, band: int) -> bool:
		return solid.call(&"fixture.front", cell, band)
	return {"kit": kit, "front": front, "back": back, "masses": masses, "result": result,
		"leans": result.leans, "parts": assembler.assemble(front), "solid": solid}


## Keeps faces out of their front: a skywalk passage on the first upper storey's panel at
## the far end of each face in `dirs` (the +z or +x end, away from the south face), so
## the face cannot step at all (cause portal) and leaves the front; the panel at the
## south face's corner stays plain (the south step may cut it).
static func block_faces(mass: BuildingMass, dirs: Array) -> void:
	var first: Dictionary = GROWTH._storey_at(mass, mass.ground_band + 2)
	for run: Dictionary in BuildingKitAssembler.boundary_runs(first.cells):
		if not dirs.has(int(run.dir)):
			continue
		var edge := BuildingMass.edge_key(BuildingKitAssembler._inside_cell(int(run.dir), int(run.line),
			int(run.end) - 1), int(run.dir))
		first.openings[edge] = BuildingMass.OPENING_DOOR
		var passages: Dictionary = first.get("passage_edges", {})
		passages[edge] = true
		first["passage_edges"] = passages


## Lean of `mass` on face `dir` per storey index (0.0 where flush).
static func leans_on(mass: BuildingMass, dir: int) -> Array[float]:
	var out: Array[float] = []
	for storey: Dictionary in mass.storeys:
		out.append(float((storey.get("growth", {}) as Dictionary).get(dir, 0.0)))
	return out


## Writes a step-in on face `dir` exactly as KitGrowingFronts.apply does (spec
## Amendment 2): offsets[i] (native m, <= 0) for storey i from the ground up, a growth
## record on every storey that stands in or overhangs the one below. `run` lists the
## face's edges (default: every boundary edge facing `dir` of storey 0).
static func write_step_in(mass: BuildingMass, kit: BuildingKit, dir: int, offsets: Array[float],
		closures: Array = [&"return", &"return"], run: Array[Vector3i] = []) -> void:
	var edges: Array[Vector3i] = run.duplicate()
	if edges.is_empty():
		for cell: Vector2i in mass.storeys[0].cells:
			if not (mass.storeys[0].cells as Dictionary).has(cell + BuildingMass.DIRS[dir]):
				edges.append(BuildingMass.edge_key(cell, dir))
	var centres: Array[Vector2] = []
	for edge: Vector3i in edges:
		centres.append(Vector2(edge.x, edge.y) + Vector2.ONE * 0.5 + Vector2(BuildingMass.DIRS[dir]) * 0.5)
	var right := Vector2(BuildingKitAssembler.right_of(dir))
	centres.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.dot(right) < b.dot(right))
	for index in offsets.size():
		var storey: Dictionary = mass.storeys[index]
		var depth := offsets[index]
		var base := offsets[index - 1] if index > 0 else depth
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
		var fronts: Array = storey.get("projections", [])
		fronts.append({"edges": edges, "centres": centres, "dir": dir, "depth": depth, "base": base,
			"band": int(storey.floor_band), "growth": true, "closures": closures})
		storey["projections"] = fronts
