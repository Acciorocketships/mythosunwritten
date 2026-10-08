extends RefCounted

## One drawn instance of every prepared environment visual, built exactly as
## EnvironmentCommitQueue builds its batches (MultiMesh with the same
## transform/colour/custom-data format and material override), so the
## renderer compiles their pipelines while the loading screen is up instead
## of in the first gameplay frame that shows each one (200-1030 ms stalls),
## including the CanopyShadows proxy the queue attaches to tree crowns.
## The caller places the returned node in front of the active camera for a few
## frames and then frees it. Main thread only.
const LANTERN_LIGHTS := preload("res://scripts/terrain/environment/EnvironmentLanternLights.gd")
const CANOPY_SHADOWS := preload("res://scripts/terrain/biome/CanopyShadows.gd")

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
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = multimesh
			instance.material_override = LANTERN_LIGHTS.glass_material(asset_id, piece)
			root.add_child(instance)
			# Tree crowns also get the shadow-only canopy proxy, so its
			# shadow-pass pipeline compiles here too.
			CANOPY_SHADOWS.attach(instance)
			# Painted trees cast from their baked shadow proxy (LeafShadow), whose
			# materials are the bake's: the visible mesh draws crossfade copies.
			if piece.shadow_mesh != null:
				EnvironmentCommitQueue._attach_shadow_proxy(instance, piece.shadow_mesh)
			slot += 1
		if visual.imposter != null:
			# Its distant imposter card (EnvironmentCommitQueue._attach_imposter),
			# scaled like the pieces so the card stays in view.
			var size := maxf(visual.imposter.size.x, 0.001)
			var place := Vector3(float(slot % 16) - 7.5, float(slot / 16) * 0.5, 0.0) * 0.06
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_colors = true
			# Same instance format as the cards (colour, no custom data), so the
			# warmed pipeline is the one they draw with.
			multimesh.mesh = EnvironmentCommitQueue.imposter_quad()
			multimesh.instance_count = 1
			multimesh.set_instance_transform(0, Transform3D(Basis.from_scale(
				Vector3.ONE * (0.05 / size)), place))
			multimesh.set_instance_color(0, Color.WHITE)
			var card := MultiMeshInstance3D.new()
			card.multimesh = multimesh
			card.material_override = EnvironmentCommitQueue.imposter_material(visual.imposter)
			card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(card)
			slot += 1
	return root

