class_name VillageTimberFabricPlan
extends RefCounted

## Atomic worker payload for all fixed-cell elevated public fabric. A caller
## either commits every floor/railing/support piece and occupancy volume or
## discards the whole plan.
var accepted: bool = false
var reason: StringName
var cells: Array[VillageTimberCell] = []
var entries: Array[Dictionary] = []
var volumes: Array[VillageOccupancyVolume] = []
var support_count: int = 0
var support_piece_count: int = 0
var railing_count: int = 0


func validate() -> bool:
	return rejection_reason().is_empty()


func rejection_reason() -> StringName:
	if not accepted:
		return &"" if cells.is_empty() and entries.is_empty() \
			and volumes.is_empty() else &"rejected_payload"
	if reason != &"accepted":
		return &"reason"
	if cells.is_empty():
		return &"cells"
	if entries.is_empty():
		return &"entries"
	if volumes.is_empty():
		return &"volumes"
	if support_count <= 0:
		return &"supports"
	if support_piece_count < support_count:
		return &"support_pieces"
	if railing_count <= 0:
		return &"railings"
	for cell: VillageTimberCell in cells:
		if cell == null:
			return &"cell"
	for entry: Dictionary in entries:
		if StringName(entry.get("asset_id", "")).is_empty():
			return &"entry_asset"
		if StringName(entry.get("stable_id", "")).is_empty():
			return &"entry_id"
		if not entry.get("transform", null) is Transform3D:
			return &"entry_transform"
	return &""
