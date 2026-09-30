extends RefCounted
## Review probe for cliff_site_review: swaps the slope rocks' and slope
## sheet's materials for unshaded copies (albedo only), or back, so a
## following `recapture` compares their colours without lighting.
static var _saved: Dictionary = {}

func run(review: Node) -> void:
	var count := 0
	for node: Node in review.get_tree().root.find_children("*", "MultiMeshInstance3D", true, false):
		var path := String(node.get_path())
		if not path.contains("CliffRockFormations"):
			continue
		var mmi := node as MultiMeshInstance3D
		if _saved.has(mmi.get_instance_id()):
			var saved: Array = _saved[mmi.get_instance_id()]
			mmi.material_override = saved[0]
			if saved[1] != null:
				mmi.multimesh.mesh.surface_set_material(0, saved[1])
			continue
		var override := mmi.material_override as ShaderMaterial
		var surface: ShaderMaterial = null
		if mmi.multimesh.mesh != null and mmi.multimesh.mesh.get_surface_count() > 0:
			surface = mmi.multimesh.mesh.surface_get_material(0) as ShaderMaterial
		_saved[mmi.get_instance_id()] = [override, surface]
		for material: ShaderMaterial in [override, surface]:
			if material == null or material.shader.code.contains("render_mode unshaded"):
				continue
			var copy := material.duplicate() as ShaderMaterial
			var shader := Shader.new()
			shader.code = material.shader.code.replace("shader_type spatial;", "shader_type spatial;\nrender_mode unshaded;")
			copy.shader = shader
			if material == override:
				mmi.material_override = copy
			else:
				mmi.multimesh.mesh.surface_set_material(0, copy)
			count += 1
	# The terrain surfaces too, so both sides of a rock's contact compare.
	for node: Node in review.get_tree().root.find_children("Surface", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var material := mi.get_active_material(0) as ShaderMaterial
		if material == null or material.shader.code.contains("render_mode unshaded"):
			continue
		var copy := material.duplicate() as ShaderMaterial
		var shader := Shader.new()
		shader.code = material.shader.code.replace("shader_type spatial;", "shader_type spatial;\nrender_mode unshaded;")
		copy.shader = shader
		mi.material_override = copy
		count += 1
	print("[unshaded_rock] swapped ", count)
