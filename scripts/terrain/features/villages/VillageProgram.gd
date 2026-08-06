class_name VillageProgram
extends RefCounted

## Compiled, resource-free global village limits. Asset-specific metrics join
## this program after the Phase-0 bake probes; the spatial contract is already
## enforced here so later content cannot silently expand discovery reach.
const MODULE := 1.5
const STOREY := 3.0
const MAX_ANCHOR_RADIUS := 144.0
const SETTLEMENT_INSET := 192.0
const DECK_TIERS := Vector2(3.7, 4.8)
const ALLEY_WIDTHS: Array[float] = [3.0, 4.5, 6.0]
const THEMES: Array[StringName] = [&"blue", &"orange"]
const TIERS: Array[StringName] = [&"hamlet", &"village", &"town"]
## Only tiers whose grammar guarantees a dense inhabited multi-height fabric are
## selected in production. Hamlet remains a compiled authored vocabulary so it
## can return later without changing asset or slot contracts.
const PRODUCTION_TIERS: Array[StringName] = [&"village", &"town"]
const PRODUCTION_TIER_WEIGHTS: Array[float] = [0.85, 0.15]

var max_asset_reach: float
var max_ground_shape_reach: float
var max_record_radius: float
var maximum_clearance: float
var geometry_halo: int
var referenced_asset_ids: Array[StringName] = []
var assets: Dictionary = {}
var asset_specs_by_runtime_id: Dictionary = {}
var prop_assets: Dictionary = {}
var prop_specs_by_runtime_id: Dictionary = {}
var runtime_aabbs: Dictionary = {}
var street_table: Dictionary = {}
var slot_table: Dictionary = {}
var prop_slot_table: Dictionary = {}
var elevated_program: VillageElevatedProgram
var massing_program: VillageMassingProgram
var market_program: VillageMarketProgram
var outskirts_program: VillageOutskirtsProgram
## Common sectional vocabulary used by the production warren solver.  It is
## compiled once beside the legacy terrain-led programs; runtime planning owns
## no resources and only consumes this immutable recipe table.
var settlement_fabric_program: SettlementFabricProgram
var layout_anchor_radius: float
var layout_record_radius: float
var foundation_asset_id: StringName
var foundation_module_width: float
var foundation_module_depth: float
var foundation_module_height: float
var foundation_max_depth: float
var foundation_max_burial: float
var foundation_local_bottom_y: float

const DEFAULT_ASSETS: Array[Dictionary] = [
	{
		"id": &"sfv.building.interior.blue.001",
		"role": VillageAssetSpec.Role.HOUSE,
		"access_kind": VillageAssetSpec.AccessKind.ENTERABLE,
		"foundation_kind": VillageAssetSpec.FoundationKind.PERIMETER,
		"vertical_policy": VillageAssetSpec.VerticalPolicy.STACKABLE,
		"enclosed_interior": true,
		# Reviewed front door on the +Z façade. The later physics battery
		# validates this exact metric with the canonical capsule.
		# Measured from the authored jambs after the closed leaf is excluded
		# during bake; the opening is centred between x=-0.803 and x=1.247.
		"entrance_local": Vector2(0.222, 6.17),
		"entrance_outward": Vector2.DOWN,
		"entrance_floor_y": 0.522,
		# Foundation-bearing contacts are authored on the fixed 1.5 m module
		# grid and conservatively inset from the visual shell. The solver can
		# therefore put the module's outside face directly under the building
		# instead of rounding the perimeter outward into a detached stone ring.
		"ground_contact_rect": Rect2(-4.325, -4.785, 9.0, 12.0),
		"interior_rect": Rect2(-4.325, -4.785, 9.0, 12.0),
		"theme_variants": {
			&"blue": &"sfv.building.interior.blue.001",
			&"orange": &"sfv.building.interior.orange.001",
		},
		"tiers": [&"hamlet", &"village", &"town"],
	},
	{
		"id": &"sfv.building.interior.blue.006",
		"role": VillageAssetSpec.Role.HOUSE,
		"access_kind": VillageAssetSpec.AccessKind.ENTERABLE,
		"foundation_kind": VillageAssetSpec.FoundationKind.PERIMETER,
		"vertical_policy": VillageAssetSpec.VerticalPolicy.STACKABLE,
		"enclosed_interior": true,
		# The two authored front leaves are bake-excluded. This point is centred
		# in the resulting opening and the floor sits on the reviewed threshold.
		"entrance_local": Vector2(0.019, 7.55),
		"entrance_outward": Vector2.DOWN,
		"entrance_floor_y": 0.0,
		"ground_contact_rect": Rect2(-4.635, -3.968, 10.5, 10.5),
		"interior_rect": Rect2(-4.635, -3.968, 10.5, 10.5),
		"theme_variants": {
			&"blue": &"sfv.building.interior.blue.006",
			&"orange": &"sfv.building.interior.orange.006",
		},
		"tiers": [&"hamlet", &"village", &"town"],
	},
	{
		"id": &"sfv.building.interior.blue.002",
		"role": VillageAssetSpec.Role.HOUSE,
		"access_kind": VillageAssetSpec.AccessKind.ENTERABLE,
		"foundation_kind": VillageAssetSpec.FoundationKind.PERIMETER,
		"vertical_policy": VillageAssetSpec.VerticalPolicy.GROUND_ONLY,
		"enclosed_interior": true,
		"entrance_local": Vector2(0.024, 5.85),
		"entrance_outward": Vector2.DOWN,
		"entrance_floor_y": 0.0,
		"ground_contact_rect": Rect2(-2.267, -1.93, 7.5, 7.5),
		"interior_rect": Rect2(-2.267, -1.93, 7.5, 7.5),
		"theme_variants": {
			&"blue": &"sfv.building.interior.blue.002",
			&"orange": &"sfv.building.interior.orange.002",
		},
		"tiers": [&"village", &"town"],
	},
	{
		"id": &"sfv.building.interior.blue.005",
		"role": VillageAssetSpec.Role.HOUSE,
		"access_kind": VillageAssetSpec.AccessKind.ENTERABLE,
		"foundation_kind": VillageAssetSpec.FoundationKind.PERIMETER,
		"vertical_policy": VillageAssetSpec.VerticalPolicy.GROUND_ONLY,
		"enclosed_interior": true,
		"entrance_local": Vector2(-0.65, 8.528),
		"entrance_outward": Vector2.DOWN,
		"entrance_floor_y": 0.0,
		"ground_contact_rect": Rect2(-5.15, -5.72, 15.0, 13.5),
		"interior_rect": Rect2(-5.15, -5.72, 15.0, 13.5),
		"theme_variants": {
			&"blue": &"sfv.building.interior.blue.005",
			&"orange": &"sfv.building.interior.orange.005",
		},
		"tiers": [&"town"],
	},
	{
		"id": &"aws.building.003",
		"role": VillageAssetSpec.Role.CIVIC,
		"access_kind": VillageAssetSpec.AccessKind.ENTERABLE,
		"foundation_kind": VillageAssetSpec.FoundationKind.PERIMETER,
		"vertical_policy": VillageAssetSpec.VerticalPolicy.GROUND_ONLY,
		"enclosed_interior": true,
		# Centre of the authored front jamb pair.
		"entrance_local": Vector2(-0.298, 5.82),
		"entrance_outward": Vector2.DOWN,
		"ground_contact_rect": Rect2(-6.135, -5.80, 12.0, 12.0),
		"interior_rect": Rect2(-6.135, -5.80, 12.0, 12.0),
		"tiers": [&"village", &"town"],
	},
	{
		"id": &"sft.building.001",
		"role": VillageAssetSpec.Role.CIVIC,
		"access_kind": VillageAssetSpec.AccessKind.ENTERABLE,
		"foundation_kind": VillageAssetSpec.FoundationKind.PERIMETER,
		"vertical_policy": VillageAssetSpec.VerticalPolicy.GROUND_ONLY,
		"enclosed_interior": true,
		# Centre of the authored double leaves on the +Z facade.
		"entrance_local": Vector2(-9.4044, 15.588),
		"entrance_outward": Vector2.DOWN,
		# The reviewed 1.2x family correction gives the real arch enough width
		# and headroom for the shared capsule. Its shallow threshold remains
		# well below the finished-step contract.
		"entrance_floor_y": 0.24,
		"ground_contact_rect": Rect2(-17.964, -15.75, 36.0, 31.5),
		"interior_rect": Rect2(-17.964, -15.75, 36.0, 31.5),
		"tiers": [&"town"],
	},
	{
		"id": &"sfbp.tent.dormitory1.001",
		"role": VillageAssetSpec.Role.SHELTER,
		"access_kind": VillageAssetSpec.AccessKind.ENTERABLE,
		"foundation_kind": VillageAssetSpec.FoundationKind.NONE,
		"vertical_policy": VillageAssetSpec.VerticalPolicy.GROUND_ONLY,
		"enclosed_interior": false,
		"entrance_local": Vector2(0.0, 3.95),
		"entrance_outward": Vector2.DOWN,
		"ground_contact_rect": Rect2(-2.80, -2.85, 5.60, 6.80),
		"interior_rect": Rect2(-2.80, -2.85, 5.60, 6.80),
		"tiers": [&"hamlet", &"village", &"town"],
		"max_ground_relief": 0.3,
	},
	{
		"id": &"sfbp.tent.armory.001",
		"role": VillageAssetSpec.Role.SHELTER,
		"access_kind": VillageAssetSpec.AccessKind.ENTERABLE,
		"foundation_kind": VillageAssetSpec.FoundationKind.NONE,
		"vertical_policy": VillageAssetSpec.VerticalPolicy.GROUND_ONLY,
		"enclosed_interior": false,
		"entrance_local": Vector2(0.0, 4.30),
		"entrance_outward": Vector2.DOWN,
		"ground_contact_rect": Rect2(-3.55, -2.95, 7.00, 7.25),
		"interior_rect": Rect2(-3.55, -2.95, 7.00, 7.25),
		"tiers": [&"hamlet", &"village", &"town"],
		"max_ground_relief": 0.3,
	},
	{
		"id": &"sfbp.tent.dormitory2.001",
		"role": VillageAssetSpec.Role.SHELTER,
		"access_kind": VillageAssetSpec.AccessKind.ENTERABLE,
		"foundation_kind": VillageAssetSpec.FoundationKind.NONE,
		"vertical_policy": VillageAssetSpec.VerticalPolicy.GROUND_ONLY,
		"enclosed_interior": false,
		"entrance_local": Vector2(0.0, 3.70),
		"entrance_outward": Vector2.DOWN,
		"entrance_floor_y": 0.0,
		"ground_contact_rect": Rect2(-3.55, -1.90, 6.00, 5.60),
		"interior_rect": Rect2(-3.55, -1.90, 6.00, 5.60),
		"tiers": [&"hamlet", &"village", &"town"],
		"max_ground_relief": 0.3,
	},
	{
		"id": &"sfbp.tent.forge.001",
		"role": VillageAssetSpec.Role.SHELTER,
		"access_kind": VillageAssetSpec.AccessKind.ENTERABLE,
		"foundation_kind": VillageAssetSpec.FoundationKind.NONE,
		"vertical_policy": VillageAssetSpec.VerticalPolicy.GROUND_ONLY,
		"enclosed_interior": false,
		"entrance_local": Vector2(0.0, 3.80),
		"entrance_outward": Vector2.DOWN,
		"entrance_floor_y": 0.0,
		"ground_contact_rect": Rect2(-3.55, -1.90, 6.55, 5.70),
		"interior_rect": Rect2(-3.55, -1.90, 6.55, 5.70),
		"tiers": [&"hamlet", &"village", &"town"],
		"max_ground_relief": 0.3,
	},
	{
		"id": &"sfm.stall.blue.007",
		"role": VillageAssetSpec.Role.MARKET,
		"access_kind": VillageAssetSpec.AccessKind.SERVICE_FRONT,
		"foundation_kind": VillageAssetSpec.FoundationKind.NONE,
		"vertical_policy": VillageAssetSpec.VerticalPolicy.GROUND_ONLY,
		"enclosed_interior": false,
		# Public service front at +Z; this is an interaction approach, not a
		# doorway through the fabric counter. The reviewed low band owns contact.
		"entrance_local": Vector2(0.0, 1.35),
		"entrance_outward": Vector2.DOWN,
		"ground_contact_rect": Rect2(-2.23, -1.27, 4.46, 2.48),
		"interior_rect": Rect2(-2.23, -1.27, 4.46, 2.48),
		"theme_variants": {
			&"blue": &"sfm.stall.blue.007",
			&"orange": &"sfm.stall.orange.006",
		},
		"tiers": [&"hamlet", &"village", &"town"],
		"max_ground_relief": 0.3,
		"lot_padding": 0.8,
		"attachments": [{
			"key": &"stocked_table",
			"id": &"sfm.table.fishmonger.001",
			"local_offset": Vector3(0.0, 0.0, -0.15),
		}],
	},
	{
		"id": &"sfm.stall.teal.008",
		"role": VillageAssetSpec.Role.MARKET,
		"access_kind": VillageAssetSpec.AccessKind.SERVICE_FRONT,
		"foundation_kind": VillageAssetSpec.FoundationKind.NONE,
		"vertical_policy": VillageAssetSpec.VerticalPolicy.GROUND_ONLY,
		"enclosed_interior": false,
		"entrance_local": Vector2(0.0, 1.35),
		"entrance_outward": Vector2.DOWN,
		"ground_contact_rect": Rect2(-2.23, -1.27, 4.46, 2.48),
		"interior_rect": Rect2(-2.23, -1.27, 4.46, 2.48),
		"theme_variants": {
			&"blue": &"sfm.stall.teal.008",
			&"orange": &"sfm.stall.neutral.009",
		},
		"tiers": [&"hamlet", &"village", &"town"],
		"max_ground_relief": 0.3,
		"lot_padding": 0.8,
	},
	{
		"id": &"sfm.stall.butcher.001",
		"role": VillageAssetSpec.Role.MARKET,
		"access_kind": VillageAssetSpec.AccessKind.SERVICE_FRONT,
		"foundation_kind": VillageAssetSpec.FoundationKind.NONE,
		"vertical_policy": VillageAssetSpec.VerticalPolicy.GROUND_ONLY,
		"enclosed_interior": false,
		"entrance_local": Vector2(0.0, 1.35),
		"entrance_outward": Vector2.DOWN,
		"ground_contact_rect": Rect2(-2.23, -1.27, 4.46, 2.48),
		"interior_rect": Rect2(-2.23, -1.27, 4.46, 2.48),
		"theme_variants": {
			&"blue": &"sfm.stall.butcher.001",
			&"orange": &"sfm.stall.butcher.003",
		},
		"tiers": [&"hamlet", &"village", &"town"],
		"max_ground_relief": 0.3,
		"lot_padding": 0.8,
	},
]

const DEFAULT_PROP_ASSETS: Array[Dictionary] = [
	{
		"id": &"sfv.well.001",
		"ground_contact_rect": Rect2(-1.56, -1.06, 3.15, 2.12),
		"max_ground_relief": 0.35,
		"lot_padding": 0.7,
	},
	{
		"id": &"sfv.quest_board.001",
		"ground_contact_rect": Rect2(-0.84, -0.14, 1.68, 0.28),
		"max_ground_relief": 0.2,
		"lot_padding": 0.6,
	},
	{
		"id": &"sfbp.campfire.001",
		"ground_contact_rect": Rect2(-0.87, -0.58, 1.74, 1.16),
		"max_ground_relief": 0.2,
		"lot_padding": 0.8,
	},
	{
		"id": &"sfv.fence.001",
		"ground_contact_rect": Rect2(-1.10, -0.065, 2.20, 0.13),
		"max_ground_relief": 0.15,
		"lot_padding": 0.25,
	},
]

const DEFAULT_STREET_TABLE := {
	&"hamlet": [
		{"key": &"main", "start": Vector2(-45.0, 0.0),
			"end": Vector2(45.0, 0.0)},
		{"key": &"cross.east", "start": Vector2(22.5, -30.0),
			"end": Vector2(22.5, 30.0)},
	],
	&"village": [
		{"key": &"main", "start": Vector2(-60.0, 0.0),
			"end": Vector2(60.0, 0.0)},
		{"key": &"cross.west", "start": Vector2(-30.0, -42.0),
			"end": Vector2(-30.0, 42.0)},
		{"key": &"cross.east", "start": Vector2(30.0, -42.0),
			"end": Vector2(30.0, 42.0)},
		{"key": &"lane.north", "start": Vector2(-30.0, -30.0),
			"end": Vector2(30.0, -30.0)},
		{"key": &"lane.south", "start": Vector2(-30.0, 30.0),
			"end": Vector2(30.0, 30.0)},
	],
	&"town": [
		{"key": &"main", "start": Vector2(-75.0, 0.0),
			"end": Vector2(75.0, 0.0)},
		{"key": &"cross.west", "start": Vector2(-45.0, -54.0),
			"end": Vector2(-45.0, 54.0)},
		{"key": &"cross.centre", "start": Vector2(0.0, -54.0),
			"end": Vector2(0.0, 54.0)},
		{"key": &"cross.east", "start": Vector2(45.0, -54.0),
			"end": Vector2(45.0, 54.0)},
		{"key": &"lane.north", "start": Vector2(-45.0, -36.0),
			"end": Vector2(45.0, -36.0)},
		{"key": &"lane.south", "start": Vector2(-45.0, 36.0),
			"end": Vector2(45.0, 36.0)},
	],
}

const DEFAULT_SLOT_TABLE := {
	&"hamlet": [
		{"key": &"street.house.west", "asset_id": &"sfv.building.interior.blue.001",
			"street_key": &"main", "distance": 9.0, "side": -1},
		{"key": &"street.market", "asset_id": &"sfm.stall.blue.007",
			"street_key": &"main", "distance": 30.0, "side": 1},
		{"key": &"street.shelter", "asset_id": &"sfbp.tent.dormitory1.001",
			"street_key": &"main", "distance": 54.0, "side": 1},
		{"key": &"street.house.east", "asset_id": &"sfv.building.interior.blue.001",
			"street_key": &"main", "distance": 75.0, "side": -1},
		{"key": &"cross.house.south", "asset_id": &"sfv.building.interior.blue.001",
			"street_key": &"cross.east", "distance": 6.0, "side": -1},
		{"key": &"cross.house.middle", "asset_id": &"sfv.building.interior.blue.001",
			"street_key": &"cross.east", "distance": 30.0, "side": 1},
		{"key": &"cross.house.north", "asset_id": &"sfv.building.interior.blue.001",
			"street_key": &"cross.east", "distance": 52.5, "side": -1},
	],
	&"village": [
		{"key": &"main.house.plaza", "asset_id": &"sfv.building.interior.blue.001",
			"street_key": &"main", "distance": 45.0, "side": -1},
		{"key": &"main.market", "asset_id": &"sfm.stall.blue.007",
			"street_key": &"main", "distance": 45.0, "side": 1},
		{"key": &"main.house.east", "asset_id": &"sfv.building.interior.blue.001",
			"street_key": &"main", "distance": 75.0, "side": -1},
		{"key": &"main.alchemy", "asset_id": &"aws.building.003",
			"street_key": &"main", "distance": 78.0, "side": 1},
		{"key": &"main.shelter", "asset_id": &"sfbp.tent.dormitory1.001",
			"street_key": &"main", "distance": 105.0, "side": -1},
		{"key": &"west.house.south", "asset_id": &"sfv.building.interior.blue.001",
			"street_key": &"cross.west", "distance": 15.0, "side": -1},
		{"key": &"west.house.north", "asset_id": &"sfv.building.interior.blue.001",
			"street_key": &"cross.west", "distance": 63.0, "side": 1},
		{"key": &"east.market", "asset_id": &"sfm.stall.blue.007",
			"street_key": &"cross.east", "distance": 18.0, "side": 1},
		{"key": &"north.house", "asset_id": &"sfv.building.interior.blue.001",
			"street_key": &"lane.north", "distance": 15.0, "side": 1},
		{"key": &"south.house", "asset_id": &"sfv.building.interior.blue.001",
			"street_key": &"lane.south", "distance": 45.0, "side": 1},
	],
	&"town": [
		{"key": &"main.tavern", "asset_id": &"sft.building.001",
			"street_key": &"main", "distance": 24.0, "side": 1},
		{"key": &"main.market.west", "asset_id": &"sfm.stall.blue.007",
			"street_key": &"main", "distance": 57.0, "side": 1},
		{"key": &"main.house.plaza", "asset_id": &"sfv.building.interior.blue.001",
			"street_key": &"main", "distance": 57.0, "side": -1},
		{"key": &"main.alchemy", "asset_id": &"aws.building.003",
			"street_key": &"main", "distance": 87.0, "side": 1},
		{"key": &"main.shelter", "asset_id": &"sfbp.tent.dormitory1.001",
			"street_key": &"main", "distance": 117.0, "side": -1},
		{"key": &"west.house.south", "asset_id": &"sfv.building.interior.blue.001",
			"street_key": &"cross.west", "distance": 15.0, "side": -1},
		{"key": &"west.house.north", "asset_id": &"sfv.building.interior.blue.001",
			"street_key": &"cross.west", "distance": 84.0, "side": 1},
		{"key": &"centre.house.south", "asset_id": &"sfv.building.interior.blue.001",
			"street_key": &"cross.centre", "distance": 18.0, "side": 1},
		{"key": &"centre.house.north", "asset_id": &"sfv.building.interior.blue.001",
			"street_key": &"cross.centre", "distance": 87.0, "side": -1},
		{"key": &"east.market.south", "asset_id": &"sfm.stall.blue.007",
			"street_key": &"cross.east", "distance": 21.0, "side": 1},
		{"key": &"east.market.north", "asset_id": &"sfm.stall.blue.007",
			"street_key": &"cross.east", "distance": 84.0, "side": -1},
		{"key": &"north.house.west", "asset_id": &"sfv.building.interior.blue.001",
			"street_key": &"lane.north", "distance": 15.0, "side": -1},
		{"key": &"north.house.east", "asset_id": &"sfv.building.interior.blue.001",
			"street_key": &"lane.north", "distance": 69.0, "side": 1},
		{"key": &"south.house.west", "asset_id": &"sfv.building.interior.blue.001",
			"street_key": &"lane.south", "distance": 21.0, "side": 1},
		{"key": &"south.house.east", "asset_id": &"sfv.building.interior.blue.001",
			"street_key": &"lane.south", "distance": 72.0, "side": -1},
	],
}

const DEFAULT_PROP_SLOT_TABLE := {
	&"hamlet": [
		{"key": &"plaza.quest_board", "asset_id": &"sfv.quest_board.001",
			"local_anchor": Vector2(0.0, 6.0),
			"path_policy": VillagePropSlotSpec.PathPolicy.ALLOW_BASE_SURFACE},
		{"key": &"outskirts.campfire", "asset_id": &"sfbp.campfire.001",
			"local_anchor": Vector2(36.0, 24.0), "local_facing": Vector2.LEFT},
		{"key": &"outskirts.fence.a", "asset_id": &"sfv.fence.001",
			"local_anchor": Vector2(27.0, -36.0)},
		{"key": &"outskirts.fence.b", "asset_id": &"sfv.fence.001",
			"local_anchor": Vector2(29.25, -36.0)},
	],
	&"village": [
		{"key": &"plaza.well", "asset_id": &"sfv.well.001",
			"local_anchor": Vector2(0.0, 6.0),
			"path_policy": VillagePropSlotSpec.PathPolicy.ALLOW_BASE_SURFACE},
		{"key": &"plaza.quest_board", "asset_id": &"sfv.quest_board.001",
			"local_anchor": Vector2(0.0, -6.0), "local_facing": Vector2.UP,
			"path_policy": VillagePropSlotSpec.PathPolicy.ALLOW_BASE_SURFACE},
		{"key": &"outskirts.campfire", "asset_id": &"sfbp.campfire.001",
			"local_anchor": Vector2(48.0, 42.0), "local_facing": Vector2.LEFT},
		{"key": &"outskirts.fence.a", "asset_id": &"sfv.fence.001",
			"local_anchor": Vector2(-3.0, 54.0)},
		{"key": &"outskirts.fence.b", "asset_id": &"sfv.fence.001",
			"local_anchor": Vector2(-0.75, 54.0)},
		{"key": &"outskirts.fence.c", "asset_id": &"sfv.fence.001",
			"local_anchor": Vector2(1.5, 54.0)},
	],
	&"town": [
		{"key": &"plaza.well", "asset_id": &"sfv.well.001",
			"local_anchor": Vector2(0.0, 6.0),
			"path_policy": VillagePropSlotSpec.PathPolicy.ALLOW_BASE_SURFACE},
		{"key": &"plaza.quest_board", "asset_id": &"sfv.quest_board.001",
			"local_anchor": Vector2(0.0, -6.0), "local_facing": Vector2.UP,
			"path_policy": VillagePropSlotSpec.PathPolicy.ALLOW_BASE_SURFACE},
		{"key": &"outskirts.campfire", "asset_id": &"sfbp.campfire.001",
			"local_anchor": Vector2(72.0, 54.0), "local_facing": Vector2.LEFT},
		{"key": &"outskirts.fence.a", "asset_id": &"sfv.fence.001",
			"local_anchor": Vector2(-4.5, 66.0)},
		{"key": &"outskirts.fence.b", "asset_id": &"sfv.fence.001",
			"local_anchor": Vector2(-2.25, 66.0)},
		{"key": &"outskirts.fence.c", "asset_id": &"sfv.fence.001",
			"local_anchor": Vector2(0.0, 66.0)},
		{"key": &"outskirts.fence.d", "asset_id": &"sfv.fence.001",
			"local_anchor": Vector2(2.25, 66.0)},
		{"key": &"outskirts.fence.e", "asset_id": &"sfv.fence.001",
			"local_anchor": Vector2(4.5, 66.0)},
	],
}

static func compile(authored: Dictionary = {},
		catalog: EnvironmentCatalog = null) -> VillageProgram:
	var program := VillageProgram.new()
	var asset_data: Array = authored.get("assets",
		DEFAULT_ASSETS if authored.is_empty() else [])
	var seen: Dictionary = {}
	for value: Variant in asset_data:
		if not value is Dictionary:
			push_error("VillageProgram assets must be dictionaries")
			return null
		var spec := VillageAssetSpec.compile(value, catalog)
		if spec == null:
			return null
		for runtime_id: StringName in spec.runtime_asset_ids():
			if seen.has(runtime_id):
				push_error("VillageProgram runtime asset IDs must be unique")
				return null
			seen[runtime_id] = true
			program.referenced_asset_ids.append(runtime_id)
			program.runtime_aabbs[runtime_id] = catalog.descriptor(
				runtime_id).measured_aabb
		for runtime_id: StringName in spec.primary_runtime_asset_ids():
			program.asset_specs_by_runtime_id[runtime_id] = spec
		program.assets[spec.asset_id] = spec
		program.max_asset_reach = maxf(program.max_asset_reach,
			spec.local_reach())
	var prop_asset_data: Array = authored.get("prop_assets",
		DEFAULT_PROP_ASSETS if authored.is_empty() else [])
	for value: Variant in prop_asset_data:
		if not value is Dictionary:
			push_error("VillageProgram prop assets must be dictionaries")
			return null
		var prop_spec := VillagePropSpec.compile(value, catalog)
		if prop_spec == null or program.prop_assets.has(prop_spec.asset_id):
			if prop_spec != null:
				push_error("VillageProgram prop asset IDs must be unique")
			return null
		for runtime_id: StringName in prop_spec.runtime_asset_ids():
			if seen.has(runtime_id):
				push_error("VillageProgram runtime asset IDs must be unique")
				return null
			seen[runtime_id] = true
			program.referenced_asset_ids.append(runtime_id)
			program.runtime_aabbs[runtime_id] = catalog.descriptor(
				runtime_id).measured_aabb
			program.prop_specs_by_runtime_id[runtime_id] = prop_spec
		program.prop_assets[prop_spec.asset_id] = prop_spec
		program.max_asset_reach = maxf(program.max_asset_reach,
			prop_spec.local_reach())
	if authored.is_empty():
		program.settlement_fabric_program = SettlementFabricProgram.compile(catalog)
		if program.settlement_fabric_program == null:
			return null
		# Fabric recipes and their production surface/support adapters share the
		# ordinary feature demand path.  Merge by runtime id so an asset used by
		# both planners is still warmed and committed exactly once.
		var fabric_asset_ids := program.settlement_fabric_program.referenced_asset_ids.duplicate()
		for adapter_id: StringName in [
			SettlementFabricAssembler.PLANK_FLOOR,
			SettlementFabricAssembler.PLANK_GALLERY,
			SettlementFabricAssembler.PLANK_SINGLE,
			SettlementFabricAssembler.PLANK_RAILING,
			SettlementFabricAssembler.TIMBER_SUPPORT,
		]:
			if not fabric_asset_ids.has(adapter_id):
				fabric_asset_ids.append(adapter_id)
		for runtime_id: StringName in fabric_asset_ids:
			var descriptor := catalog.descriptor(runtime_id)
			if descriptor == null:
				push_error("Warren fabric references an unavailable runtime asset: %s" %
					String(runtime_id))
				return null
			if not seen.has(runtime_id):
				seen[runtime_id] = true
				program.referenced_asset_ids.append(runtime_id)
				program.runtime_aabbs[runtime_id] = descriptor.measured_aabb
			var local_aabb: AABB = descriptor.measured_aabb
			var local_reach := maxf(Vector2(local_aabb.position.x,
				local_aabb.position.z).length(), Vector2(local_aabb.end.x,
				local_aabb.end.z).length())
			program.max_asset_reach = maxf(program.max_asset_reach, local_reach)
		program.market_program = VillageMarketProgram.compile(program.assets)
		if program.market_program == null:
			return null
		program.outskirts_program = VillageOutskirtsProgram.compile(
			program.assets)
		if program.outskirts_program == null:
			return null
		program.massing_program = VillageMassingProgram.compile(program.assets)
		if program.massing_program == null:
			return null
		program.elevated_program = VillageElevatedProgram.compile(catalog,
			program.assets)
		if program.elevated_program == null:
			return null
		for runtime_id: StringName in program.elevated_program.referenced_asset_ids:
			var descriptor := catalog.descriptor(runtime_id)
			if not seen.has(runtime_id):
				seen[runtime_id] = true
				program.referenced_asset_ids.append(runtime_id)
				program.runtime_aabbs[runtime_id] = descriptor.measured_aabb
			var local_aabb: AABB = descriptor.measured_aabb
			var local_reach := maxf(Vector2(local_aabb.position.x,
				local_aabb.position.z).length(), Vector2(local_aabb.end.x,
				local_aabb.end.z).length())
			program.max_asset_reach = maxf(program.max_asset_reach, local_reach)
	program.max_asset_reach = maxf(program.max_asset_reach,
		float(authored.get("max_asset_reach", 0.0)))
	program.max_ground_shape_reach = float(
		authored.get("max_ground_shape_reach", 0.0))
	program.maximum_clearance = float(authored.get("maximum_clearance",
		4.5 if not asset_data.is_empty() or not prop_asset_data.is_empty()
		else 0.0))
	for value: float in [program.max_asset_reach,
			program.max_ground_shape_reach, program.maximum_clearance]:
		if not is_finite(value) or value < 0.0:
			push_error("VillageProgram reaches must be finite and non-negative")
			return null
	program.max_record_radius = MAX_ANCHOR_RADIUS + maxf(
		program.max_asset_reach, program.max_ground_shape_reach)
	if program.max_record_radius > SETTLEMENT_INSET:
		push_error("VillageProgram record radius exceeds settlement inset")
		return null
	program.geometry_halo = ceili(program.max_asset_reach \
		/ TerrainChunkMesher.CHUNK_WORLD)
	var ids: Array = authored.get("referenced_asset_ids", [])
	for value: Variant in ids:
		var asset_id := StringName(value)
		if asset_id.is_empty() or seen.has(asset_id):
			push_error("VillageProgram asset ids must be non-empty and unique")
			return null
		seen[asset_id] = true
		program.referenced_asset_ids.append(asset_id)
	var foundation_data: Dictionary = authored.get("foundation", {
		"asset_id": &"sfv.foundation.rock.001",
		"module_width": 1.5,
		"module_height": 3.0,
		"max_depth": 2.75,
		"max_burial": 3.0,
	} if authored.is_empty() else {})
	if not foundation_data.is_empty():
		program.foundation_asset_id = StringName(
			foundation_data.get("asset_id", ""))
		var foundation_descriptor := catalog.descriptor(
			program.foundation_asset_id) if catalog != null else null
		if program.foundation_asset_id.is_empty() \
				or foundation_descriptor == null \
				or not foundation_descriptor.tags.has(&"foundation") \
				or foundation_descriptor.collision_piece_count <= 0 \
				or seen.has(program.foundation_asset_id):
			push_error("VillageProgram requires one unique collidable foundation asset")
			return null
		program.foundation_module_width = float(
			foundation_data.get("module_width", 0.0))
		program.foundation_module_depth = foundation_descriptor.measured_aabb.size.z
		program.foundation_module_height = float(
			foundation_data.get("module_height", 0.0))
		program.foundation_max_depth = float(
			foundation_data.get("max_depth", 0.0))
		program.foundation_max_burial = float(
			foundation_data.get("max_burial", 0.0))
		program.foundation_local_bottom_y = \
			foundation_descriptor.measured_aabb.position.y
		for metric: float in [program.foundation_module_width,
				program.foundation_module_depth,
				program.foundation_module_height, program.foundation_max_depth,
				program.foundation_max_burial]:
			if not is_finite(metric) or metric <= 0.0:
				push_error("VillageProgram foundation metrics must be finite and positive")
				return null
		seen[program.foundation_asset_id] = true
		program.referenced_asset_ids.append(program.foundation_asset_id)
		program.runtime_aabbs[program.foundation_asset_id] = \
			foundation_descriptor.measured_aabb
	for value: Variant in program.assets.values():
		var spec := value as VillageAssetSpec
		if spec == null or not spec.requires_foundation():
			continue
		if program.foundation_asset_id.is_empty() \
				or not _module_aligned(spec.ground_contact_local_rect.size.x,
					program.foundation_module_width) \
				or not _module_aligned(spec.ground_contact_local_rect.size.y,
					program.foundation_module_width):
			push_error("Ground-bearing village contacts must fit the compiled foundation grid: %s" \
				% String(spec.asset_id))
			return null
	program.referenced_asset_ids.sort_custom(func(a: StringName,
			b: StringName) -> bool:
		return String(a) < String(b))
	var authored_streets: Dictionary = authored.get("street_table",
		DEFAULT_STREET_TABLE if authored.is_empty() else {})
	for tier: StringName in TIERS:
		var compiled_streets: Array[VillageStreetSpec] = []
		var street_keys: Dictionary = {}
		for value: Variant in authored_streets.get(tier, []):
			if not value is Dictionary:
				push_error("Village streets must be dictionaries")
				return null
			var street := VillageStreetSpec.compile(value)
			if street == null or street_keys.has(street.stable_key):
				if street != null:
					push_error("Village street keys must be unique within a tier")
				return null
			street_keys[street.stable_key] = true
			compiled_streets.append(street)
			program.layout_anchor_radius = maxf(program.layout_anchor_radius,
				maxf(street.local_start.length(), street.local_end.length()))
		if not _street_graph_is_connected(compiled_streets):
			push_error("Village street graph must be orthogonal and connected to the plaza")
			return null
		program.street_table[tier] = compiled_streets
	var authored_slots: Dictionary = authored.get("slot_table",
		DEFAULT_SLOT_TABLE if authored.is_empty() else {})
	for tier: StringName in TIERS:
		var compiled_slots: Array[VillageSlotSpec] = []
		var slot_keys: Dictionary = {}
		for value: Variant in authored_slots.get(tier, []):
			var data: Dictionary
			if value is Dictionary:
				data = value
			else:
				# Compact authored programs retain a stable key equal to the ID.
				data = {"key": StringName(value), "asset_id": StringName(value)}
			var slot := VillageSlotSpec.compile(data, program.assets)
			if slot == null or slot_keys.has(slot.stable_key):
				if slot != null:
					push_error("Village slot keys must be unique within a tier")
				return null
			slot_keys[slot.stable_key] = true
			var asset_id := slot.asset_id
			var spec := program.assets.get(asset_id) as VillageAssetSpec
			if spec == null or not spec.allowed_in(tier):
				push_error("Village slot references an unavailable asset for %s: %s" % [
					String(tier), String(asset_id)])
				return null
			var street := program.street_for(tier, slot.street_key)
			if street == null or slot.distance > street.length() + 0.001:
				push_error("Village slot frontage lies outside its street: %s" \
					% String(slot.stable_key))
				return null
			compiled_slots.append(slot)
		program.slot_table[tier] = compiled_slots
	var authored_prop_slots: Dictionary = authored.get("prop_slot_table",
		DEFAULT_PROP_SLOT_TABLE if authored.is_empty() else {})
	for tier: StringName in TIERS:
		var compiled_prop_slots: Array[VillagePropSlotSpec] = []
		var prop_slot_keys: Dictionary = {}
		for value: Variant in authored_prop_slots.get(tier, []):
			if not value is Dictionary:
				push_error("Village prop slots must be dictionaries")
				return null
			var prop_slot := VillagePropSlotSpec.compile(value,
				program.prop_assets)
			if prop_slot == null or prop_slot_keys.has(prop_slot.stable_key):
				if prop_slot != null:
					push_error("Village prop slot keys must be unique within a tier")
				return null
			prop_slot_keys[prop_slot.stable_key] = true
			compiled_prop_slots.append(prop_slot)
			program.layout_anchor_radius = maxf(program.layout_anchor_radius,
				prop_slot.local_anchor.length())
		program.prop_slot_table[tier] = compiled_prop_slots
		if program.elevated_program != null:
			program.layout_anchor_radius = maxf(program.layout_anchor_radius,
				program.elevated_program.maximum_local_reach(tier))
	program.layout_record_radius = program.layout_anchor_radius \
		+ program.max_asset_reach
	return program

func assets_for_tier(tier: StringName) -> Array[VillageAssetSpec]:
	var out: Array[VillageAssetSpec] = []
	for asset_id: StringName in referenced_asset_ids:
		var spec := assets.get(asset_id) as VillageAssetSpec
		if spec != null and spec.allowed_in(tier):
			out.append(spec)
	return out

func slots_for_tier(tier: StringName) -> Array[VillageSlotSpec]:
	var out: Array[VillageSlotSpec] = []
	out.assign(slot_table.get(tier, []))
	return out

func massing_slots_for_tier(tier: StringName) -> Array[VillageMassingSlot]:
	return [] if massing_program == null \
		else massing_program.slots_for_tier(tier)

func streets_for_tier(tier: StringName) -> Array[VillageStreetSpec]:
	var out: Array[VillageStreetSpec] = []
	out.assign(street_table.get(tier, []))
	return out

func street_for(tier: StringName, key: StringName) -> VillageStreetSpec:
	for street: VillageStreetSpec in streets_for_tier(tier):
		if street.stable_key == key:
			return street
	return null

func prop_slots_for_tier(tier: StringName) -> Array[VillagePropSlotSpec]:
	var out: Array[VillagePropSlotSpec] = []
	out.assign(prop_slot_table.get(tier, []))
	return out

func spec_for_asset(asset_id: StringName) -> VillageAssetSpec:
	return asset_specs_by_runtime_id.get(asset_id) as VillageAssetSpec

func prop_spec_for_asset(asset_id: StringName) -> VillagePropSpec:
	return prop_specs_by_runtime_id.get(asset_id) as VillagePropSpec

func anchor_allowed(plaza: Vector2, anchor: Vector2) -> bool:
	return plaza.distance_squared_to(anchor) \
		<= MAX_ANCHOR_RADIUS * MAX_ANCHOR_RADIUS

static func production_tier(roll: float) -> StringName:
	assert(roll >= 0.0 and roll < 1.0)
	assert(PRODUCTION_TIERS.size() == PRODUCTION_TIER_WEIGHTS.size())
	var cumulative := 0.0
	for index in PRODUCTION_TIERS.size():
		cumulative += PRODUCTION_TIER_WEIGHTS[index]
		if roll < cumulative:
			return PRODUCTION_TIERS[index]
	return PRODUCTION_TIERS[-1]

func record_bound(plaza: Vector2) -> Rect2:
	return Rect2(plaza - Vector2.ONE * max_record_radius,
		Vector2.ONE * max_record_radius * 2.0)

static func _module_aligned(length: float, module: float) -> bool:
	return module > 0.0 and absf(length / module \
		- roundf(length / module)) <= 0.001

static func _street_graph_is_connected(streets: Array[VillageStreetSpec]) -> bool:
	if streets.is_empty():
		return true
	var connected: Array[VillageStreetSpec] = []
	for street: VillageStreetSpec in streets:
		var joins := _segment_distance_to_point(street.local_start,
			street.local_end, Vector2.ZERO) <= PathProgram.PLAZA_RADIUS
		for prior: VillageStreetSpec in connected:
			joins = joins or _orthogonal_segments_intersect(street.local_start,
				street.local_end, prior.local_start, prior.local_end)
		if not joins:
			return false
		connected.append(street)
	return true

static func _segment_distance_to_point(a: Vector2, b: Vector2,
		point: Vector2) -> float:
	var delta := b - a
	var t := clampf((point - a).dot(delta) / delta.length_squared(), 0.0, 1.0)
	return point.distance_to(a + delta * t)

static func _orthogonal_segments_intersect(a0: Vector2, a1: Vector2,
		b0: Vector2, b1: Vector2) -> bool:
	var a_bounds := Rect2(a0.min(a1), (a1 - a0).abs()).grow(0.001)
	var b_bounds := Rect2(b0.min(b1), (b1 - b0).abs()).grow(0.001)
	return a_bounds.intersects(b_bounds, true)
