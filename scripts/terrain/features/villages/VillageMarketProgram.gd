class_name VillageMarketProgram
extends RefCounted

## Compiled market grammar. Topology is a small family of connected orthogonal
## alley loops; stalls are selected from every reviewed MARKET asset through
## one shared placement contract.
const STREET_HALF_WIDTH := VillageProgram.MODULE
const STREET_CLEARANCE := STREET_HALF_WIDTH + 0.5
const STALL_EDGE_GAP := 0.35
const STALL_SAMPLE_STRIDE := 4
const END_CLEARANCE_MODULES := 2
const MINIMUM_STALLS := {
	&"village": 6,
	&"town": 8,
}
const TARGET_STALLS := {
	&"village": 10,
	&"town": 12,
}

var stall_specs: Array[VillageAssetSpec] = []


static func compile(assets: Dictionary) -> VillageMarketProgram:
	var program := VillageMarketProgram.new()
	for value: Variant in assets.values():
		var spec := value as VillageAssetSpec
		if spec != null and spec.role == VillageAssetSpec.Role.MARKET:
			if spec.access_kind != VillageAssetSpec.AccessKind.SERVICE_FRONT \
					or spec.is_stackable():
				push_error("Market frontage must be a ground-only service structure")
				return null
			program.stall_specs.append(spec)
	program.stall_specs.sort_custom(func(a: VillageAssetSpec,
			b: VillageAssetSpec) -> bool:
		return String(a.asset_id) < String(b.asset_id))
	if program.stall_specs.is_empty():
		push_error("Village market grammar requires reviewed stall frontage")
		return null
	return program


func minimum_stalls(tier: StringName) -> int:
	return int(MINIMUM_STALLS.get(tier, 0))


func target_stalls(tier: StringName) -> int:
	return int(TARGET_STALLS.get(tier, 0))


func spec_for_index(index: int) -> VillageAssetSpec:
	assert(not stall_specs.is_empty())
	return stall_specs[posmod(index, stall_specs.size())]


func local_topologies() -> Array[Dictionary]:
	# Largest first. Every topology is an alley loop joined to the arrival at
	# (0, 0); shortening is a normal ranked grammar choice, not a repair path.
	return [
		_topology(&"broad", 18.0, 18.0, 6.0),
		_topology(&"compact", 15.0, 15.0, 4.5),
		_topology(&"tight", 12.0, 12.0, 3.0),
	]


static func _topology(key: StringName, half_width: float, depth: float,
		crook: float) -> Dictionary:
	return {
		"key": key,
		"nodes": {
			&"arrival": Vector2.ZERO,
			&"west": Vector2(-half_width, 0.0),
			&"east": Vector2(half_width, 0.0),
			&"north_west": Vector2(-half_width, depth),
			&"north_middle": Vector2(crook, depth),
			&"north_east": Vector2(half_width, depth),
		},
		"edges": [
			[&"west", &"arrival"], [&"arrival", &"east"],
			[&"west", &"north_west"],
			[&"north_west", &"north_middle"],
			[&"north_middle", &"north_east"],
			[&"north_east", &"east"],
		],
	}
