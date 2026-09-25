extends GutTest

class CountingBubble extends CameraVisibilityBubble:
	var reads := 0
	func _source_parameter(source: Material,name: StringName) -> Variant:
		reads += 1
		return super._source_parameter(source,name)

func test_shared_source_is_sampled_once_when_installing_multiple_components() -> void:
	var bubble := CountingBubble.new()
	add_child_autofree(bubble)
	var source := StandardMaterial3D.new()
	var first := bubble._adapt(source,{"materials":[],"sources":[]})
	var first_reads := bubble.reads
	var second := bubble._adapt(source,{"materials":[],"sources":[]})
	assert_eq(bubble.reads,first_reads,"New components reuse the shared source snapshot, without synchronous per-wrapper reads")
	assert_same(first.shader,second.shader)
	assert_same(first,second,"Components with the same source share one adapted material")

func test_shared_material_keeps_independent_geometry_fades_and_restores_overrides() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var target := Node3D.new()
	world.add_child(target)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,16,26)
	var source := StandardMaterial3D.new()
	var bubble := CameraVisibilityBubble.new()
	world.add_child(bubble)
	var nodes: Array[MeshInstance3D] = []
	for initial: float in [0.1,0.8]:
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mesh.material_override = source
		world.add_child(mesh)
		var state := bubble._install(mesh)
		state.strength = initial
		bubble._active[mesh.get_instance_id()] = state
		nodes.append(mesh)
	bubble._query_in = INF
	bubble._last_eye = camera.position
	bubble.update_bubble(camera,target,Vector3.ZERO,3.8,.12,.05)
	assert_same(nodes[0].material_override,nodes[1].material_override)
	assert_almost_eq(float(nodes[0].get_instance_shader_parameter("tactical_strength")),.4,.0001)
	assert_eq(float(nodes[1].get_instance_shader_parameter("tactical_strength")),1.0)
	bubble.clear()
	for mesh: MeshInstance3D in nodes:
		assert_same(mesh.material_override,source)
		assert_null(mesh.get_instance_shader_parameter("tactical_strength"))

func test_turning_away_and_back_reuses_the_same_compiled_shader() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var target := Node3D.new()
	world.add_child(target)
	var camera := Camera3D.new()
	world.add_child(camera)
	var bubble := CameraVisibilityBubble.new()
	world.add_child(bubble)
	var source := StandardMaterial3D.new()
	var state := {"materials":[],"sources":[]}
	var first := bubble._adapt(source,state)
	# Empty neighbourhood releases source owners; returning still uses the
	# identical shader program rather than compiling it during camera motion.
	bubble._select(camera,target,Vector3.ZERO,3.8)
	var second := bubble._adapt(source,{"materials":[],"sources":[]})
	assert_same(first.shader,second.shader)

func test_shader_history_is_bounded_and_does_not_retain_source_materials() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var target := Node3D.new()
	world.add_child(target)
	var camera := Camera3D.new()
	world.add_child(camera)
	var bubble := CameraVisibilityBubble.new()
	world.add_child(bubble)
	for index in 40:
		var source := ShaderMaterial.new()
		source.shader = Shader.new()
		source.shader.code = "shader_type spatial; void fragment() { ALBEDO=vec3(%f); }" % (index/40.0)
		bubble._adapt(source,{"materials":[],"sources":[]})
		bubble._select(camera,target,Vector3.ZERO,3.8)
		assert_true(bubble._materials.is_empty(),"Compiled history must release material/texture owners")
		assert_lte(bubble._shaders.size(),32)
	assert_eq(bubble._shaders.size(),32)
	bubble.clear()
	assert_true(bubble._shaders.is_empty())

func test_single_surface_batch_fades_without_copying_its_instance_buffer() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var bubble := CameraVisibilityBubble.new()
	world.add_child(bubble)
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = BoxMesh.new()
	batch.multimesh.mesh.material = StandardMaterial3D.new()
	batch.multimesh.instance_count = 2
	batch.multimesh.set_instance_transform(1,Transform3D(Basis.IDENTITY,Vector3(4,2,6)))
	world.add_child(batch)
	var original := batch.multimesh
	var state := bubble._install(batch)
	assert_same(batch.multimesh,original,"A material fade must not read back/copy a single-surface instance buffer")
	assert_true(batch.material_override is ShaderMaterial)
	# A live producer still owns the displayed transforms while fading.
	var moved := Transform3D(Basis.IDENTITY,Vector3(8,2,6))
	original.set_instance_transform(1,moved)
	assert_same(batch.multimesh,original,"Producer changes must reach the displayed batch")
	bubble._restore(batch,state)
	assert_null(batch.material_override)
	assert_same(batch.multimesh,original)

func test_multiple_surfaces_keep_distinct_materials_and_restore_the_source() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var bubble := CameraVisibilityBubble.new()
	world.add_child(bubble)
	var mesh := ArrayMesh.new()
	var box := BoxMesh.new()
	for color: Color in [Color.RED,Color.BLUE]:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,box.get_mesh_arrays())
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		mesh.surface_set_material(mesh.get_surface_count()-1,material)
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = 1
	var pose := Transform3D(Basis.IDENTITY,Vector3(4,2,6))
	batch.multimesh.set_instance_transform(0,pose)
	world.add_child(batch)
	var original := batch.multimesh
	var state := bubble._install(batch)
	assert_null(batch.material_override,"Distinct surfaces must not collapse to one material")
	assert_same(batch.multimesh,original,"Multiple-surface fading must retain the producer's live instance buffer too")
	assert_same(batch.multimesh.mesh,mesh,"Fading must not read back and duplicate native mesh geometry")
	assert_eq(state.materials.size(),2)
	assert_ne(batch.multimesh.mesh.surface_get_material(0),batch.multimesh.mesh.surface_get_material(1))
	assert_true(mesh.surface_get_material(0) is StandardMaterial3D,"The source asset keeps its own surface materials")
	var sibling := MultiMeshInstance3D.new()
	sibling.multimesh = original
	world.add_child(sibling)
	var sibling_state := bubble._install(sibling)
	assert_same(sibling.multimesh.mesh,batch.multimesh.mesh,"Shared batches share the reversible material mesh")
	var live_pose := pose.translated(Vector3(2,1,0))
	original.set_instance_transform(0,live_pose)
	if DisplayServer.get_name() != "headless":
		assert_eq(batch.multimesh.get_instance_transform(0),live_pose)
	bubble._restore(batch,state)
	assert_same(batch.multimesh,original)
	if DisplayServer.get_name() != "headless":
		assert_eq(RenderingServer.mesh_surface_get_material(mesh.get_rid(),0),sibling_state.materials[0].get_rid(),"One owner's restoration must not remove the other owner's fade")
	bubble._active[sibling.get_instance_id()] = sibling_state
	sibling.free()
	bubble.clear()
	assert_same(original.mesh,mesh,"Even a freed final owner retains the native mesh")
	if DisplayServer.get_name() != "headless":
		assert_eq(RenderingServer.mesh_surface_get_material(mesh.get_rid(),0),mesh.surface_get_material(0).get_rid(),"The final owner restores the native renderer binding")
