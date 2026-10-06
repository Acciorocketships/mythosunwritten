extends RefCounted


## Reconstruction oracle only. Production must bake these material bindings;
## it must not load a source prefab to obtain its material resources at runtime.
static func instantiate(
	document: Dictionary, reference: Node3D, additional_materials: Dictionary = {}
) -> Node3D:
	assert(document.complete)
	var materials := additional_materials.duplicate()
	for mesh: MeshInstance3D in reference.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			materials[material.resource_name] = material
	var result := Node3D.new()
	for part: Dictionary in document.parts:
		var source: String = part.get(
			"module_source", "assets/PureVillage/Models/Architecture/" + part.module + ".glb"
		)
		var instance: Node3D = load("res://" + source.trim_prefix("res://")).instantiate()
		for joint: Dictionary in part.get("joints", []):
			assert(joint.rule == "suntail.cupboard.drawer_slide")
			var sockets := instance.find_children(joint.node, "MeshInstance3D", true, false)
			assert(sockets.size() == 1, "Sliding drawer must name exactly one native mesh")
			var drawer := sockets[0] as MeshInstance3D
			assert(
				(
					float(joint.displacement) >= 0
					and float(joint.displacement) <= drawer.get_aabb().size.z * 0.5
				)
			)
			drawer.position.z += float(joint.displacement)
		var m: Array = part.matrix
		instance.transform = Transform3D(
			Basis(Vector3(m[0], m[1], m[2]), Vector3(m[4], m[5], m[6]), Vector3(m[8], m[9], m[10])),
			Vector3(m[12], m[13], m[14])
		)
		var meshes := instance.find_children("*", "MeshInstance3D", true, false)
		assert(meshes.size() == part.materials.size())
		for index in meshes.size():
			var mesh: MeshInstance3D = meshes[index]
			for surface in mesh.mesh.get_surface_count():
				var name: String = part.materials[index][surface]
				assert(materials.has(name), "Missing source material: " + name)
				mesh.set_surface_override_material(surface, materials[name])
		result.add_child(instance)
	return result
