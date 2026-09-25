class_name VillageSkirtDeckPlan
extends RefCounted

## Building-owned timber cells derived only from unsupported contact. Natural
## buildings deliberately validate with an empty plan.
var accepted: bool = false
var reason: StringName
var stable_id: StringName
var cells: Array[VillageTimberCell] = []


func validate(naturally_supported: bool) -> bool:
	if not accepted:
		return cells.is_empty()
	if stable_id.is_empty() or reason != &"accepted":
		return false
	if naturally_supported:
		return cells.is_empty()
	for cell: VillageTimberCell in cells:
		if cell.owner_id != stable_id \
				or cell.kind != VillageTimberCell.Kind.SKIRT:
			return false
	return true
