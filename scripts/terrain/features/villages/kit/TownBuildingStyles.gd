extends RefCounted
## One architectural family per merged house, with a town-wide seeded mix.
## Fixed module/storey datums let adjacent families share party walls, doors
## and bridge landings. Geometry planning remains independent of style.
const PURE := preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")

static func for_house(base: BuildingKit, town_seed: int, house_id: StringName, native_roofs := true) -> BuildingKit:
	if base.kit_id != &"suntail": return base
	var share := 0.2 + 0.6 * _roll(town_seed, "town.facade_mix")
	if _roll(town_seed, String(house_id)) >= share: return base
	var style := hash([town_seed, String(house_id), "opening_family"])
	if not native_roofs: return PURE.create(style)
	var kit := PURE.roof_study(style)
	var palette := preload("res://scripts/terrain/features/villages/kit/TownRoofPalette.gd")
	palette.apply(kit, palette.choose(town_seed, house_id))
	var finish: StringName = [&"native", &"oak", &"walnut"][posmod(hash([town_seed, String(house_id), "frame.finish"]), 3)]
	preload("res://scripts/terrain/features/villages/kit/TownFramePalette.gd").apply(kit, finish)
	return kit

static func _roll(seed_value: int, key: String) -> float:
	return float(posmod(hash([seed_value, key]), 1000000)) / 1000000.0
