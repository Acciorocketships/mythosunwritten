extends RefCounted

## One drawn instance of every prepared environment visual, built exactly as
## EnvironmentCommitQueue builds its batches (MultiMesh with the same
## transform/colour/custom-data format and material override), so the
## renderer compiles their pipelines while the loading screen is up instead
## of in the first gameplay frame that shows each one (200-1030 ms stalls).
## The caller places the returned node in front of the active camera for a few
## frames and then frees it. Main thread only.
const LANTERN_LIGHTS := preload("res://scripts/terrain/environment/EnvironmentLanternLights.gd")

static func build(render_cache: EnvironmentRenderCache,
		asset_ids: Array[StringName]) -> Node3D:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	var root := Node3D.new()
	root.name = "RenderWarmup"
	var slot := 0
	for asset_id: StringName in asset_ids:
		var visual := render_cache.visual(asset_id)
		if visual == null:
			continue
		for piece_index in visual.pieces.size():
			var piece: EnvironmentVisualPiece = visual.pieces[piece_index]
			if piece == null or piece.mesh == null:
				continue
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_colors = piece.use_instance_color
			multimesh.use_custom_data = true
			multimesh.mesh = piece.mesh
			multimesh.instance_count = 1
			# Tiny and spread on a small grid: every piece is on screen.
			var size := maxf(piece.mesh.get_aabb().get_longest_axis_size(), 0.001)
			var place := Vector3(float(slot % 16) - 7.5, float(slot / 16) * 0.5, 0.0) * 0.06
			multimesh.set_instance_transform(0, Transform3D(Basis.from_scale(
				Vector3.ONE * (0.05 / size)), place))
			if piece.use_instance_color:
				multimesh.set_instance_color(0, Color.WHITE)
			multimesh.set_instance_custom_data(0, Color(0, 0, 0, 0))
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = multimesh
			instance.material_override = LANTERN_LIGHTS.glass_material(asset_id, piece)
			root.add_child(instance)
			slot += 1
	return root
