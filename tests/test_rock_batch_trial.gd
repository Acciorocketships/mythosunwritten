extends GutTest
const TRIAL = preload("res://tests/harness/RockBatchTrial.gd")

func test_rebatch_preserves_instances_and_render_resources() -> void:
	if DisplayServer.get_name() == "headless":
		pending("Requires real renderer: dummy MultiMesh readback returns identity")
		return
	var mesh := BoxMesh.new()
	var material := StandardMaterial3D.new()
	var sources: Array[MultiMeshInstance3D] = []
	var expected := {}
	for tile in 3:
		var node := MultiMeshInstance3D.new()
		node.transform.origin = Vector3(tile * 32, 0, -32)
		node.material_override = material
		node.lod_bias = .75
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = 3
		for i in 3:
			var pose := Transform3D(Basis(Vector3.UP,i*.3),Vector3(i*6, i*3, 4))
			mm.set_instance_transform(i,pose)
			mm.set_instance_color(i,Color(.1 * i,.2,.3,.4))
			mm.set_instance_custom_data(i,Color(.2,.4,33+i,.6))
			expected[node.transform * pose] = [mm.get_instance_color(i),mm.get_instance_custom_data(i)]
		node.multimesh = mm
		sources.append(node)
	for size in [64.0,96.0]:
		var merged := TRIAL.rebatch(sources,size)
		assert_lt(merged.get_child_count(),sources.size())
		var actual := {}
		var count := 0
		for node: MultiMeshInstance3D in merged.get_children():
			assert_same(node.multimesh.mesh,mesh)
			assert_same(node.material_override,material)
			assert_eq(node.lod_bias,.75)
			count += node.multimesh.instance_count
			for i in node.multimesh.instance_count:
				var mm := node.multimesh
				actual[mm.get_instance_transform(i)] = [mm.get_instance_color(i),mm.get_instance_custom_data(i)]
		assert_eq(count,9,"each source instance appears exactly once")
		assert_eq(actual,expected,"all transforms, tints and contact planes remain exact")
		merged.free()
	for node in sources: node.free()
