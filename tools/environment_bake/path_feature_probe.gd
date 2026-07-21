@tool
extends SceneTree

## Bake-owned source-pack probe. Runtime and terrain tests consume only the
## checked-in measurements produced here, never these source paths.
const SOURCES := {
	&"sfv.arch.001": "res://assets/FantasyVillageFBX/FBX/Exterior Props/Arch/SFV_Arch_001.fbx",
	&"sfv.arch.002": "res://assets/FantasyVillageFBX/FBX/Exterior Props/Arch/SFV_Arch_002.fbx",
	&"sfv.bridge.001": "res://assets/FantasyVillageFBX/FBX/Exterior Props/Bridge/SFV_Bridge_001.fbx",
	&"sfv.entrance_arch.001": "res://assets/FantasyVillageFBX/FBX/Exterior Props/Arch/SFV_Entrance_Arch_001.fbx",
	&"sfv.light_pole.001": "res://assets/FantasyVillageFBX/FBX/Exterior Props/Light Pole/SFV_Light_Pole_001.fbx",
}
const BRIDGE_SCALES := [
	Vector3(1.0, 1.0, 4.0),
	Vector3(1.1, 1.0, 5.0),
	Vector3(1.2, 1.0, 6.0),
]

func _init() -> void:
	for asset_id: StringName in SOURCES:
		var bounds := _source_bounds(SOURCES[asset_id])
		assert(bounds.has_volume(), "Source asset has no visual bounds: %s" % asset_id)
		print("%s min=%s max=%s size=%s" % [asset_id, bounds.position,
			bounds.end, bounds.size])
		if asset_id == &"sfv.bridge.001":
			for scale: Vector3 in BRIDGE_SCALES:
				var scaled := AABB(bounds.position * scale, bounds.size * scale)
				print("  scale=%s size=%s min=%s max=%s" % [
					scale, scaled.size, scaled.position, scaled.end])
	quit()

static func _source_bounds(path: String) -> AABB:
	var packed := load(path) as PackedScene
	assert(packed != null, "Missing imported source scene: %s" % path)
	var root := packed.instantiate()
	var bounds := AABB()
	var found := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var piece := _relative_transform(mesh_instance, root) * mesh_instance.mesh.get_aabb()
		bounds = piece if not found else bounds.merge(piece)
		found = true
	root.free()
	return bounds

static func _relative_transform(node: Node3D, root: Node) -> Transform3D:
	var out := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor != null and cursor != root:
		var node_3d := cursor as Node3D
		if node_3d != null:
			out = node_3d.transform * out
		cursor = cursor.get_parent()
	return out
