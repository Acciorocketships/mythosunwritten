extends RefCounted

## Finite native attachment, wholly inside the addressed panel's existing
## conservative envelope. Mount planes were measured from its actual triangles
## at x=1.1, y=2.75; mirrored panels use the mirrored point. The wall bracket's
## back lies at -0.20547369. No render resources are read during expansion.
const ASSET := &"lpfv.fabric.prop.lantern.table.01"
const BOUNDS := AABB(Vector3(-0.072903775,-0.002083109,-0.20547369),
	Vector3(0.14580758,0.4928235,0.27837747))
const MOUNTS := {
	"sfv.fabric.wall.wood.door.closed.001": -0.17869997024536,
	"sfv.fabric.wall.rock.door.closed.005": -0.01388502120972,
}

static func supports(asset_id: StringName) -> bool:
	for base: String in MOUNTS:
		if String(asset_id).begins_with(base): return true
	return false

static func attachment(panel: Dictionary) -> Dictionary:
	var id := String(panel.asset_id)
	for base: String in MOUNTS:
		if not id.begins_with(base): continue
		var hand := -1.0 if id.contains(".mirror_x") else 1.0
		var pose: Transform3D = panel.transform * Transform3D(Basis.IDENTITY,
			Vector3(1.1*hand,2.30,float(MOUNTS[base])+0.20547369-0.001))
		return {"asset_id":ASSET,"stable_id":StringName("%s/lantern"%panel.stable_id),
			"placement_id":StringName("%s.lantern"%panel.placement_id),
			"transform":pose,"bounds":pose*BOUNDS,"collision_pieces":0,
			"attachment_owner":panel.stable_id}
	return {}
