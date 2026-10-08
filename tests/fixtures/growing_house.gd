extends RefCounted
## Growing-floor fixtures. A house under test fronts a one-cell lane at z = -1
## (native z -2..0); an optional facing house stands across it. Native frame:
## module 2 m, band 1.5 m, storey = 2 bands.

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
