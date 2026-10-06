extends RefCounted
## Replace an existing solid facade panel, never attach a projection to it.
const WINDOW := &"pure_village.wall.stone.window"
const CONTACTS := preload("res://scripts/terrain/features/villages/kit/KitFacadeRoofContacts.gd")

static func replace(wall: Dictionary, catalog: EnvironmentCatalog, air: Array[Dictionary],
		context: Dictionary) -> bool:
	if context.is_empty() or wall.get("retaining_recess",false): return false
	var before: AABB = catalog.descriptor(wall.asset_id).measured_aabb
	var source: AABB = catalog.descriptor(WINDOW).measured_aabb
	var seat := Transform3D(Basis.IDENTITY,Vector3(0,0,before.end.z-source.end.z))
	var after := seat * source
	# The street-facing envelope is already occupied by the backing panel.
	# A replacement may only extend inward, not widen or raise that envelope.
	if after.position.x < before.position.x-0.001 or after.end.x > before.end.x+0.001 \
			or after.position.y < before.position.y-0.001 or after.end.y > before.end.y+0.001:
		return false
	var pose: Transform3D = wall.transform * seat
	if after.position.z < before.position.z:
		var inward := AABB(after.position,Vector3(after.size.x,after.size.y,
			before.position.z-after.position.z))
		if not preload("res://scripts/terrain/features/villages/kit/KitTownFacadeBays.gd").clear_of(wall.transform*inward,air):
			return false
	if CONTACTS.obstructed(WINDOW,pose,context): return false
	wall.asset_id = WINDOW
	wall.transform = pose
	wall.retaining_recess = true
	return true
