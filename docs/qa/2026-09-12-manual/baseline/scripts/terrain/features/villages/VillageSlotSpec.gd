class_name VillageSlotSpec
extends RefCounted

## One immutable semantic frontage candidate. Every lot is addressed against
## a compiled street segment. The planner therefore cannot regress to a
## wheel-and-spokes layout by giving each building its own plaza ray.

var stable_key: StringName
var asset_id: StringName
var street_key: StringName
var distance: float
var side: int
var setback: float


static func compile(data: Dictionary, assets: Dictionary) -> VillageSlotSpec:
	var slot := VillageSlotSpec.new()
	slot.stable_key = StringName(data.get("key", ""))
	slot.asset_id = StringName(data.get("asset_id", ""))
	slot.street_key = StringName(data.get("street_key", ""))
	slot.distance = float(data.get("distance", 0.0))
	slot.side = int(data.get("side", 0))
	slot.setback = float(data.get("setback", 0.5))
	if slot.stable_key.is_empty() or not assets.has(slot.asset_id) \
			or slot.street_key.is_empty() or not is_finite(slot.distance) \
			or slot.distance < 0.0 or absi(slot.side) != 1 \
			or not is_finite(slot.setback) or slot.setback < 0.0:
		push_error("Village slot requires a stable key and available asset")
		return null
	return slot
