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


## Builtin odds with growth forced on for the house under test; `step` fixes growth_step.
static func character(values: Dictionary = {}, step := &"0.25") -> TownCharacter:
	var fixed := {&"growing_house_chance": 1.0, &"growth_street_face_chance": 1.0,
		&"growth_other_face_chance": 0.0, &"growth_max_lean": 1.0, &"lane_sky_gap": 0.75}
	fixed.merge(values, true)
	var c := TownCharacter.draw(TownOddsProgram.builtin().with_overrides(fixed), 1, 0.5)
	c.values[&"growth_step"] = {&"0.25": 1.0 if step == &"0.25" else 0.0,
		&"0.5": 1.0 if step == &"0.5" else 0.0}
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
## back_grows, character, air, towers, reserved, kit, extra (more masses),
## prepare (Callable(front) run before fitting), replace_front (a mass with its
## own roofs, id kit.fixture.front).
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


## Lean of `mass` on face `dir` per storey index (0.0 where flush).
static func leans_on(mass: BuildingMass, dir: int) -> Array[float]:
	var out: Array[float] = []
	for storey: Dictionary in mass.storeys:
		out.append(float((storey.get("growth", {}) as Dictionary).get(dir, 0.0)))
	return out
