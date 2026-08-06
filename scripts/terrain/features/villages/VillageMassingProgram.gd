class_name VillageMassingProgram
extends RefCounted

## Compiled semantic roster and general density gates for the replacement
## urban-fabric solver. The program contains no terrain, resources, or fixed
## world coordinates.
const CORE_RADIUS := 42.0
const ARRIVAL_RADIUS := 8.0
## The reviewed structures are roughly 12–16 m wide. Twenty-four metres is
## still a local neighbour relation while leaving enough horizontal run for a
## full-level stair and a modest curve around an intervening eave.
const MAX_LINK_RADIUS := 24.0
## Same-floor upper doors must form at least one compact public-ground
## neighborhood. The platform stage may reject individual cell routes on exact
## geometry, but massing is responsible for supplying a plausible cluster.
const MAX_PLATFORM_JOIN_RADIUS := 24.0
const BUILDING_GAP := VillageProgram.MODULE
const ACCESS_CLEARANCE := 0.25
const MAX_ENTRANCE_STAIR_SEGMENTS := 4
const MAX_PUBLIC_STAIR_SEGMENTS := 8
const MIN_AERIAL_LINKS := 2
const MAX_AERIAL_LINKS := 8
const MIN_GROUND_STREET_RATIO := 0.50
const MIN_TERRAIN_SUPPORT_RATIO := 0.70
const MIN_ELEVATION_BANDS := 3
const MIN_PLATFORMIZABLE_PAIRS := 1
const MIN_BUILDINGS := {
	&"village": 7,
	&"town": 10,
}
const TARGET_BUILDINGS := {
	&"village": 10,
	&"town": 15,
}
const MIN_GROUND_BUILDINGS := {
	&"village": 3,
	&"town": 4,
}
const MAX_HALF_LEVEL_BAND := {
	&"village": 2,
	&"town": 3,
}

var slot_table: Dictionary = {}
var vertical_profile: VillageVerticalProfile
## The most compact stackable footprint in the production roster supplies the
## terrain-survey datum. This is an explicit compiled fact rather than an
## accidental consequence of slot order, so appending an accent structure
## cannot move every other building in the village.
var core_asset_id: StringName


static func compile(assets: Dictionary) -> VillageMassingProgram:
	var program := VillageMassingProgram.new()
	program.vertical_profile = VillageVerticalProfile.compile(assets)
	if program.vertical_profile == null:
		return null
	program.slot_table[&"village"] = _slots(&"core", 7, true, false)
	program.slot_table[&"town"] = _slots(&"core", 11, true, true)
	program.core_asset_id = _select_core_asset(program.slot_table, assets)
	if program.core_asset_id.is_empty():
		push_error("Village massing requires a stackable core footprint")
		return null
	for tier: StringName in VillageProgram.PRODUCTION_TIERS:
		var slots: Array[VillageMassingSlot] = []
		slots.assign(program.slot_table.get(tier, []))
		var keys: Dictionary = {}
		for slot: VillageMassingSlot in slots:
			if not slot.is_valid(assets, tier) or keys.has(slot.stable_key):
				push_error("Village massing roles require valid unique enterable slots: %s/%s" \
					% [String(tier), String(slot.stable_key)])
				return null
			keys[slot.stable_key] = true
		if slots.size() != int(TARGET_BUILDINGS[tier]):
			push_error("Village massing target count does not match its roster")
			return null
	return program


func slots_for_tier(tier: StringName) -> Array[VillageMassingSlot]:
	var out: Array[VillageMassingSlot] = []
	out.assign(slot_table.get(tier, []))
	return out


func minimum_buildings(tier: StringName) -> int:
	return int(MIN_BUILDINGS.get(tier, 0))


func minimum_ground_buildings(tier: StringName) -> int:
	return int(MIN_GROUND_BUILDINGS.get(tier, 0))


func maximum_half_level_band(tier: StringName) -> int:
	return int(MAX_HALF_LEVEL_BAND.get(tier, 0))


static func _select_core_asset(tables: Dictionary,
		assets: Dictionary) -> StringName:
	var candidates: Dictionary = {}
	for value: Variant in tables.values():
		for slot: VillageMassingSlot in value:
			var spec := assets.get(slot.asset_id) as VillageAssetSpec
			if spec != null and spec.is_stackable():
				candidates[slot.asset_id] = spec
	var selected := StringName()
	var selected_area := INF
	for asset_id: StringName in candidates:
		var spec := candidates[asset_id] as VillageAssetSpec
		var size := spec.ground_contact_local_rect.size
		var area := size.x * size.y
		if area < selected_area - 0.001 \
				or (is_equal_approx(area, selected_area) \
					and (selected.is_empty() \
						or String(asset_id) < String(selected))):
			selected = asset_id
			selected_area = area
	return selected


static func _slots(prefix: StringName, house_count: int,
		include_civic: bool, include_grand_house: bool
		) -> Array[VillageMassingSlot]:
	var out: Array[VillageMassingSlot] = []
	if include_civic:
		out.append(VillageMassingSlot.new(StringName("%s.civic" % prefix),
			&"aws.building.003"))
	for index in house_count:
		out.append(VillageMassingSlot.new(StringName("%s.house.%02d" \
			% [prefix, index]), &"sfv.building.interior.blue.001"))
	# Geometrically distinct silhouettes are additive accents. The complete
	# compact-house roster remains available underneath them, so admitting a
	# broader future asset can add variety but cannot invalidate an established
	# village merely because that asset does not fit one particular site.
	out.append(VillageMassingSlot.new(StringName("%s.house.accent.00" % prefix),
		&"sfv.building.interior.blue.006"))
	# Larger furnished silhouettes are ground anchors. They enrich the compact
	# centre without changing the stackable family's 6 m half-level rhythm.
	out.append(VillageMassingSlot.new(StringName("%s.house.accent.01" % prefix),
		&"sfv.building.interior.blue.002", 6.0, 33.0))
	if include_grand_house:
		out.append(VillageMassingSlot.new(
			StringName("%s.house.accent.02" % prefix),
			&"sfv.building.interior.blue.005", 18.0, CORE_RADIUS))
	return out
