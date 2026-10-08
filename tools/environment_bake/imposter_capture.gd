extends RefCounted
## Captures a baked tree visual's distant imposter: FRAMES azimuth views, each
## an albedo+coverage frame and a normal frame whose alpha is the texel's tint
## response. Main thread only; needs a real renderer (run the bake windowed).
##
## Capture rules, each one avoiding a known trap of painted_leaf.gdshader:
## - A narrow-FOV PERSPECTIVE camera: the shader takes any orthographic
##   projection for the sun shadow pass and thins or kills the leaf cards.
## - leaf_lod_camera = (eye, 0.0001 m/px) and mesh_lod_threshold 0, so every
##   card and the finest bark LOD are drawn. The global cannot be read back
##   outside the editor, so it is reset to its project default afterwards.
## - Albedo: Viewport.DEBUG_DRAW_UNSHADED. Checked in Godot 4.5 Forward+: it
##   draws each material's own ALBEDO (the leaf shader's interior/underside
##   shading and tint noise included), honours ALPHA_SCISSOR, multiplies the
##   MultiMesh instance colour, and leaves the background transparent.
## - Normals: Viewport.DEBUG_DRAW_NORMAL_BUFFER. Its RGB is the raw view-space
##   normal * 0.5 + 0.5, not sRGB-encoded (decoded texels are unit length;
##   the leaf shader's back-face flip included); its background is opaque
##   grey, so coverage comes from the albedo pass. The background of all
##   three atlases is bled from the covered texels before mipmapping.
## - Tint response: two albedo captures with instance colour white and grey
##   0.5 through the runtime MultiMesh path; their ratio, taken in LINEAR
##   space (the shader multiplies linear albedo by the colour), is how fully
##   a texel scales with the instance tint. Both materials are measured, not
##   assumed: Meadow bark uses vertex colour as albedo, so it tints (~1) too.
## - A square frame about the asset's vertical axis (x = z = 0, the axis the
##   runtime billboard turns about): side = max(2 * the largest horizontal
##   vertex distance from the axis, height) * MARGIN, so every azimuth frames
##   the same world square and the runtime quad (size x size) maps it back
##   undistorted. pivot_height is the frame's bottom edge above the origin.
## - Normal basis: the normal atlas RGB is n * 0.5 + 0.5 in the FRAME basis of
##   frame f (azimuth a = TAU * f / FRAMES, eye at (sin a, 0, cos a) from the
##   axis): x = frame right (cos a, 0, -sin a), y = world up, z = toward the
##   capture eye (sin a, 0, cos a). The runtime rotates it into world space.

const FRAMES := 8
const FOV_DEGREES := 4.0
## Framing margin: >= 8 px of empty border at 128 px frames.
const MARGIN := 1.15
const GREY := 0.5
## Metres per pixel per metre for leaf_lod_camera: small enough to keep every card.
const FULL_DETAIL_PIXEL := 0.0001

## Renders `visual` from FRAMES azimuths and returns the imposter (textures in
## memory; the caller saves them). Main thread; needs a real renderer.
static func capture(tree: SceneTree, visual: EnvironmentVisual, frame_px: int = 256) -> EnvironmentImposter:
	assert(DisplayServer.get_name() != "headless", "imposter capture needs a renderer (run the bake without --headless)")
	if DisplayServer.get_name() == "headless":
		return null
	var viewport := SubViewport.new()
	viewport.size = Vector2i(frame_px, frame_px)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.mesh_lod_threshold = 0.0
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var instances := _instances(visual)
	for instance in instances:
		viewport.add_child(instance)
	# Frame about the asset's vertical axis (x = z = 0), which is what the
	# runtime billboard turns about: an off-axis crown then stays put between
	# azimuths instead of swimming during frame blends.
	var extent := _axis_extent(visual)
	var radius: float = extent.x
	var aabb := _aabb(visual)
	var axis_centre := Vector3(0.0, 0.5 * (extent.y + extent.z), 0.0)
	var side := maxf(2.0 * radius, extent.z - extent.y) * MARGIN
	var distance := 0.5 * side / tan(deg_to_rad(FOV_DEGREES * 0.5))
	var camera := Camera3D.new()
	camera.fov = FOV_DEGREES
	camera.near = maxf(distance - side * 2.0, 0.05)
	camera.far = distance + side * 2.0
	viewport.add_child(camera)
	camera.current = true
	var albedo := Image.create(frame_px * FRAMES, frame_px, false, Image.FORMAT_RGBA8)
	var normal := Image.create(frame_px * FRAMES, frame_px, false, Image.FORMAT_RGBA8)
	var response := Image.create(frame_px * FRAMES, frame_px, false, Image.FORMAT_RGBA8)
	for f in FRAMES:
		var azimuth := TAU * float(f) / float(FRAMES)
		camera.look_at_from_position(axis_centre + Vector3(sin(azimuth), 0.0, cos(azimuth)) * distance,
			axis_centre, Vector3.UP)
		var white: Image = await _render(tree, viewport, instances, Color.WHITE, Viewport.DEBUG_DRAW_UNSHADED)
		var grey: Image = await _render(tree, viewport, instances, Color(GREY, GREY, GREY), Viewport.DEBUG_DRAW_UNSHADED)
		var normals: Image = await _render(tree, viewport, instances, Color.WHITE, Viewport.DEBUG_DRAW_NORMAL_BUFFER)
		for y in frame_px:
			for x in frame_px:
				var w := white.get_pixel(x, y)
				var lw := w.srgb_to_linear().get_luminance()
				var lg := grey.get_pixel(x, y).srgb_to_linear().get_luminance()
				var r := clampf((lw - lg) / maxf(lw, 0.001) / (1.0 - GREY), 0.0, 1.0)
				albedo.set_pixel(f * frame_px + x, y, w)
				var n := normals.get_pixel(x, y)
				normal.set_pixel(f * frame_px + x, y, Color(n.r, n.g, n.b, w.a))
				response.set_pixel(f * frame_px + x, y, Color(r, r, r, w.a))
	# The global cannot be read back outside the editor: restore the project
	# default (AtmosphereDirector rewrites it every frame in game).
	var setting: Variant = ProjectSettings.get_setting("shader_globals/leaf_lod_camera", {})
	var default_lod: Variant = setting.get("value", Vector4.ZERO) if setting is Dictionary else Vector4.ZERO
	RenderingServer.global_shader_parameter_set(&"leaf_lod_camera", default_lod)
	viewport.queue_free()
	# Bleed covered texels into the empty background before mipmapping, so
	# neither the albedo, the normals nor the response darken toward the
	# background at the crown's edge in distant mips.
	albedo.fix_alpha_edges()
	normal.fix_alpha_edges()
	response.fix_alpha_edges()
	for y in normal.get_height():
		for x in normal.get_width():
			var n := normal.get_pixel(x, y)
			normal.set_pixel(x, y, Color(n.r, n.g, n.b, response.get_pixel(x, y).r))
	albedo.generate_mipmaps()
	normal.generate_mipmaps()
	var out := EnvironmentImposter.new()
	out.albedo = ImageTexture.create_from_image(albedo)
	out.normal = ImageTexture.create_from_image(normal)
	out.frames = FRAMES
	out.size = Vector2(side, side)
	out.pivot_height = axis_centre.y - 0.5 * side
	out.crown_centre = aabb.get_center()
	return out

## The visual drawn as production does (EnvironmentCommitQueue._commit_batch):
## one single-instance MultiMesh per piece at its local transform.
static func _instances(visual: EnvironmentVisual) -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	for piece: EnvironmentVisualPiece in visual.pieces:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = piece.use_instance_color
		multimesh.mesh = piece.mesh
		multimesh.instance_count = 1
		multimesh.set_instance_transform(0, piece.local_transform)
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = piece.material_override
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out.append(instance)
	return out

static func _aabb(visual: EnvironmentVisual) -> AABB:
	var out := AABB()
	for i in visual.pieces.size():
		var piece: EnvironmentVisualPiece = visual.pieces[i]
		var box := piece.local_transform * piece.mesh.get_aabb()
		out = box if i == 0 else out.merge(box)
	return out

## (max horizontal distance from the vertical axis, min y, max y) over every
## drawn vertex in asset space.
static func _axis_extent(visual: EnvironmentVisual) -> Vector3:
	var radius := 0.0
	var low := INF
	var high := -INF
	for piece: EnvironmentVisualPiece in visual.pieces:
		for surface in piece.mesh.get_surface_count():
			var vertices: PackedVector3Array = piece.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var p := piece.local_transform * vertex
				radius = maxf(radius, Vector2(p.x, p.z).length())
				low = minf(low, p.y)
				high = maxf(high, p.y)
	return Vector3(radius, low, high)

static func _render(tree: SceneTree, viewport: SubViewport, instances: Array[MultiMeshInstance3D],
		colour: Color, mode: Viewport.DebugDraw) -> Image:
	for instance in instances:
		if instance.multimesh.use_colors:
			instance.multimesh.set_instance_color(0, colour)
	viewport.debug_draw = mode
	# Set before every render so nothing else (a live AtmosphereDirector)
	# can re-thin the cards mid-capture.
	var eye := viewport.get_camera_3d().global_position
	RenderingServer.global_shader_parameter_set(&"leaf_lod_camera", Vector4(eye.x, eye.y, eye.z, FULL_DETAIL_PIXEL))
	for i in 5:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
