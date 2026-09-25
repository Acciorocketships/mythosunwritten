extends "res://tests/harness/september11_bubble_qa.gd"
const EVENING_BEFORE := preload("res://tests/fixtures/september13/evening_before/CameraVisibilityBubble.gd")
const GROUND_BEFORE := preload("res://tests/fixtures/september13/CameraVisibilityBubble.gd")
const BACKGROUND_BEFORE := preload("res://tests/fixtures/september13/background_before/CameraVisibilityBubble.gd")
const ORIGINAL_GROUND_BEFORE := preload("res://tests/fixtures/september12/VisibilityBefore.gd")

func _read_args() -> void:
	super._read_args()
	var args := OS.get_cmdline_user_args()
	if args.has("--single"):
		var index := args.find("--spot")
		assert(index >= 0 and index+1 < args.size(),"A single replay requires --spot followed by its source ID")
		assert(args[index+1] == _spot[0],"Unknown source photo ID")

func _spots() -> Array:
	return [
		["P43_cutaway", "2026-09-13 5.36.42 PM", Vector3(540.4,4,-623.6), Vector3(535.5,8,-625.3)],
		["P44_buried", "2026-09-13 5.35.55 PM", Vector3(435.9,8,-637.7), Vector3(432.5,12,-633.8)],
		["P45_tree", "2026-09-13 5.37.13 PM", Vector3(616.8,4,-545.8), Vector3(616.8,5.2,-546.2)],
		["P46_edge", "2026-09-13 5.36.24 PM", Vector3(519.5,4,-642.3), Vector3(519.1,5.2,-642.4)],
		["P47_bush", "2026-09-13 5.35.43 PM", Vector3(428.2,12,-629.8), Vector3(428.3,13.2,-630.2)],
		["P49_cap", "2026-09-13 5.35.09 PM", Vector3(442.6,9.9,-636.6), Vector3(444,11.9,-635.6)],
		["P50_canopy", "2026-09-13 5.38.07 PM", Vector3(607.4,12,-241.1), Vector3(607.4,13.2,-241.5)],
		["P51_background", "2026-09-13 5.37.49 PM", Vector3(624.2,12,-344), Vector3(624.1,13.2,-344.4)],
		["P01_spawn", "2026-09-12 11.56.57 AM", Vector3(6.5,0,-7.4), Vector3(6.9,1.2,-7.5)],
		["P26_heath", "2026-09-12 12.27.00 PM", Vector3(-419.6,21.9,-660.4), Vector3(-424.8,28,-653.2)],
		["P30_heath", "2026-09-12 12.34.46 PM", Vector3(805.8,24,-1860.4), Vector3(796,32,-1853.4)],
		["P31_town", "2026-09-12 12.35.28 PM", Vector3(956.3,16,-2065.3), Vector3(956.1,17.2,-2064.9)],
		["P03_near", "2026-09-12 11.59.20 AM", Vector3(-93.6,5,-722.9), Vector3(-93.3,6.2,-722.7)],
		["P32_canopy", "2026-09-13 12.23.17 PM", Vector3(114.7,4,-129.7), Vector3(114.3,5.2,-129.5)],
		["P33_background", "2026-09-13 12.28.32 PM", Vector3(-233.6,23.5,-944.6), Vector3(-225.6,30.5,-938)],
		["P06_house", "2026-09-12 12.01.38 PM", Vector3(-215.1,29.1,-960), Vector3(-215.2,30.4,-959.6)]]

func _run() -> void:
	await get_tree().create_timer(5).timeout
	if _frozen:
		_capture_view = SubViewport.new()
		_capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_capture_view)
		_character.get_parent().get_parent().reparent(_capture_view)
		_camera.make_current()
		_show_capture_view()
	assert(_capture_view != null,"Use --offscreen so live workers never reparent")
	_capture_view.size = Vector2i(1716,1033)
	if _spot[0] == "P32_canopy": _capture_view.size = Vector2i(1920,1080)
	_camera = _capture_view.get_camera_3d()
	_camera.set_physics_process(false)
	_camera.set_process_input(false)
	_camera.set_process_unhandled_input(false)
	var world := _character.get_parent().get_parent()
	var output := _output_dir
	var poses: Array[Dictionary] = []
	var selected: Array = [_spot] if OS.get_cmdline_user_args().has("--single") else _spots()
	var batch_argument := OS.get_cmdline_user_args().find("--batch-spots")
	if batch_argument >= 0:
		var wanted := OS.get_cmdline_user_args()[batch_argument+1].split(",")
		selected = _spots().filter(func(spot: Array): return spot[0] in wanted)
	for spot: Array in selected:
		_spot = spot
		world.process_mode = Node.PROCESS_MODE_INHERIT
		_character.set_physics_process(false)
		_character.global_position = spot[2]
		print("SEPT12_WAIT ",spot[0])
		if not _frozen: assert(await _wait_for_site())
		_camera._visibility.clear()
		_character.set_physics_process(false)
		_character.global_position = spot[2]
		_character.step_visual_offset_y = 0
		_character._update_step_visual_smoothing(0)
		_character.anim_tree.active = false
		# Frozen animation must not remove the collision used by visibility.
		for body: Node in world.find_children("*","CollisionObject3D",true,false):
			body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
		world.process_mode = Node.PROCESS_MODE_DISABLED
		var site_dir := output.path_join(spot[0])
		DirAccess.make_dir_recursive_absolute(site_dir)
		if not _frozen:
			preload("res://tests/harness/september11_snapshot.gd").save(world,_character,site_dir.path_join("world.scn"))
		if OS.get_cmdline_user_args().has("--evening-review"):
			# Upgrade only the semantic water role in pre-change frozen snapshots.
			for water: Node in world.find_children("WaterSheet","MeshInstance3D",true,false):
				water.add_to_group("tactical_preserve_surface",true)
			# Unlike flattened geometry names, the explicit full-heightfield shape
			# name is retained beneath each separately copied static body.
			for shape: CollisionShape3D in world.find_children("CollisionShape3D","CollisionShape3D",true,false):
				if shape.shape is ConcavePolygonShape3D: shape.add_to_group("tactical_terrain_volume",true)

		if OS.get_cmdline_user_args().has("--renew-native-owners"):
			_upgrade_native_owners(world)
		# Freeze shader clocks for paired pixel evidence while retaining the
		# actual production geometry and all published shader field textures.
		_freeze_material_clocks(world)
		var eye := ReviewCam.solve_cam(spot[2],spot[3],26,16,1)
		var angles: Array = [0,-8,8]
		var angle_argument := OS.get_cmdline_user_args().find("--angle")
		if angle_argument >= 0:
			angles = [float(OS.get_cmdline_user_args()[angle_argument+1])]
		for angle: float in angles:
			_camera.global_position = Vector3(spot[2])+(eye-Vector3(spot[2])).rotated(Vector3.UP,deg_to_rad(angle))
			_camera.look_at(Vector3(spot[2])+Vector3.UP)
			poses.append({"spot":spot[0],"player":str(spot[2]),"crosshair":str(spot[3]),"angle":angle,"camera":str(_camera.global_transform),"size":str(_capture_view.size)})
			for phase: String in ["opaque","before","after"]:
				var background_review := OS.get_cmdline_user_args().has("--background-review")
				var bubble: Node = (BACKGROUND_BEFORE.new() if background_review else GROUND_BEFORE.new()) if phase == "before" else CameraVisibilityBubble.new()
				if phase == "before" and OS.get_cmdline_user_args().has("--ground-review"):
					bubble.free()
					bubble = ORIGINAL_GROUND_BEFORE.new()
				if phase == "before" and OS.get_cmdline_user_args().has("--evening-review"):
					bubble.free()
					bubble = EVENING_BEFORE.new()
				add_child(bubble)
				for frame in 16:
					bubble.update_bubble(_camera,_character,spot[2],CameraVisibilityBubble.screen_radius(_camera,spot[2]),.12 if phase == "before" and not background_review else _camera.obstruction_opacity,.1)
					await get_tree().process_frame
				if phase == "opaque":
					for id: int in bubble._active:
						instance_from_id(id).set_instance_shader_parameter("tactical_strength",0.0)
				if OS.get_cmdline_user_args().has("--measure-visibility") and phase != "opaque":
					var measured: Array[SubViewport] = [_capture_view,bubble._receivers._view,bubble._receivers._front_view]
					if phase == "after": measured.append(bubble._receivers._terrain_view)
					for view: SubViewport in measured: RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(),true)
					var samples: Array[Dictionary] = []
					for frame in 150:
						var start := Time.get_ticks_usec()
						bubble.update_bubble(_camera,_character,spot[2],CameraVisibilityBubble.screen_radius(_camera,spot[2]),_camera.obstruction_opacity,.1)
						var cpu := Time.get_ticks_usec()-start
						await get_tree().process_frame
						if frame < 30: continue
						var gpu: Array[float] = []
						for view: SubViewport in measured: gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid()))
						samples.append({"cpu_us":cpu,"gpu_ms":gpu})
					FileAccess.open(site_dir.path_join("%s-time-%d.json"%[phase,int(angle)]),FileAccess.WRITE).store_string(JSON.stringify(samples))
				_output_dir = site_dir.path_join(phase)
				DirAccess.make_dir_recursive_absolute(_output_dir)
				await _shot("%s_%d"%[spot[0],int(angle)])
				if phase == "after":
					bubble._receivers.texture().get_image().save_png(site_dir.path_join("receiver_%d.png"%int(angle)))
					if OS.get_cmdline_user_args().has("--receiver-diagnostics"):
						var depths: Image = bubble._receivers.texture().get_image()
						var terrain: Image = bubble._receivers._terrain_view.get_texture().get_image()
						var bounds: Vector4 = bubble._receivers._native_material.get_shader_parameter("receiver_terrain_bounds")
						for pixel: Vector2 in [Vector2(1030,460),Vector2(1000,475),Vector2(1100,455),Vector2(1100,430)]:
							var color := depths.get_pixelv(pixel)
							var depth := (roundf(color.r*255)+roundf(color.g*255)*256+roundf(color.b*255)*65536)*.001
							var ray := _camera.project_ray_normal(pixel)
							var point := _camera.global_position+ray*depth/(-_camera.global_basis.z.dot(ray))
							var uv := (Vector2(point.x,point.z)-Vector2(bounds.x,bounds.y))/bounds.z
							color = terrain.get_pixelv(uv*Vector2(terrain.get_size()))
							var top := bounds.w-(roundf(color.r*255)+roundf(color.g*255)*256+roundf(color.b*255)*65536)*.001
							var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*100,point-Vector3.UP*100))
							print("RECEIVER_PROBE ",pixel," world=",point," terrain_y=",top," uv=",uv," projected=",bubble._receivers._terrain_camera.unproject_position(point)/Vector2(terrain.get_size())," bounds=",bounds," physical=",hit)
				print("SEPT12_SHOT ",spot[0]," ",angle," ",phase)
				bubble.clear()
				bubble.free()
			if OS.get_cmdline_user_args().has("--background-control"):
				await _background_control(world,spot[2],site_dir,angle)
		FileAccess.open(site_dir.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
		_character.anim_tree.active = true
	FileAccess.open(output.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	world.process_mode = Node.PROCESS_MODE_INHERIT
	if _frozen: _streamer.free()
	get_tree().quit()

func _freeze_material_clocks(world: Node3D) -> void:
	var materials := {}
	for node: Node in world.find_children("*","GeometryInstance3D",true,false):
		var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh != null else null
		if node.material_override != null: materials[node.material_override.get_instance_id()] = node.material_override
		if mesh != null:
			for surface in mesh.get_surface_count():
				var material := mesh.surface_get_material(surface)
				if material != null: materials[material.get_instance_id()] = material
	for material: Material in materials.values():
		if material is ShaderMaterial and material.shader != null and material.shader.code.contains("TIME"):
			var shader := Shader.new()
			shader.code = material.shader.code.replace("TIME","0.0")
			material.shader = shader

func _background_control(world: Node3D, feet: Vector3, directory: String, angle: float) -> void:
	# Independent native reference: omit complete foreground owners, with no
	# visibility material. This distinguishes a revealed exterior from an
	# interior created by the cutaway. Original meshes/transforms are restored.
	var direction := Vector2(_camera.global_position.x-feet.x,_camera.global_position.z-feet.z).normalized()
	var saved := []
	for node: Node in world.find_children("*","GeometryInstance3D",true,false):
		if not node.is_in_group("tactical_closed_shell"): continue
		if node is MultiMeshInstance3D and node.multimesh.use_custom_data:
			var source: MultiMesh = node.multimesh
			var kept := []
			for index in source.instance_count:
				var c := source.get_instance_custom_data(index)
				if not _owner_is_foreground(node,Vector4(c.r,c.g,c.b,c.a),feet,direction): kept.append(index)
			var copy := MultiMesh.new()
			copy.transform_format = source.transform_format
			copy.use_colors = source.use_colors
			copy.use_custom_data = source.use_custom_data
			copy.mesh = source.mesh
			copy.instance_count = kept.size()
			for i in kept.size():
				copy.set_instance_transform(i,source.get_instance_transform(kept[i]))
				copy.set_instance_custom_data(i,source.get_instance_custom_data(kept[i]))
				if source.use_colors: copy.set_instance_color(i,source.get_instance_color(kept[i]))
			saved.append([node,source,node.visible])
			node.multimesh = copy
		else:
			var bounds: AABB = node.get_aabb()
			var owner: Vector4 = node.get_meta("tactical_owner_rect") if node.has_meta("tactical_owner_rect") else Vector4(bounds.position.x,bounds.position.z,bounds.end.x,bounds.end.z)
			saved.append([node,null,node.visible])
			if _owner_is_foreground(node,owner,feet,direction): node.hide()
	_output_dir = directory.path_join("background-only")
	DirAccess.make_dir_recursive_absolute(_output_dir)
	await _shot("%s_%d"%[_spot[0],int(angle)])
	for entry in saved:
		if entry[1] != null: entry[0].multimesh = entry[1]
		entry[0].visible = entry[2]

func _owner_is_foreground(node: Node3D, rect: Vector4, feet: Vector3, direction: Vector2) -> bool:
	var nearest := -INF
	for x in [rect.x,rect.z]:
		for z in [rect.y,rect.w]:
			var point := node.global_transform * Vector3(x,0,z)
			nearest = maxf(nearest,Vector2(point.x-feet.x,point.z-feet.z).dot(direction))
	return nearest > -0.25

func _upgrade_native_owners(world: Node3D) -> void:
	# Frozen pre-change buffers have no per-asset owner attributes. Reconstruct
	# the exact normal commit attributes from the saved native transforms.
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var names := {}
	for id: StringName in catalog.ids(): names[String(id).replace(".","_")] = id
	var count := 0
	for node: Node in world.find_children("*","MultiMeshInstance3D",true,false):
		if node.has_meta("tactical_owner_footprints"): continue
		var name := String(node.name)
		var split := name.rfind("_")
		if split < 0 or not name.substr(split+1).is_valid_int(): continue
		var key := name.substr(0,split)
		if not names.has(key): continue
		var visual := cache.visual(names[key])
		var piece_index := int(name.substr(split+1))
		assert(piece_index < visual.pieces.size())
		var native_bounds := AABB()
		for piece: EnvironmentVisualPiece in visual.pieces:
			var box := piece.local_transform * piece.mesh.get_aabb()
			native_bounds = native_bounds.merge(box) if native_bounds.has_volume() else box
		var source: MultiMesh = node.multimesh
		assert(not source.use_custom_data)
		var copy := MultiMesh.new()
		copy.transform_format = source.transform_format
		copy.use_colors = source.use_colors
		copy.use_custom_data = true
		copy.mesh = source.mesh
		copy.instance_count = source.instance_count
		for index in source.instance_count:
			var pose := source.get_instance_transform(index)
			copy.set_instance_transform(index,pose)
			if source.use_colors: copy.set_instance_color(index,source.get_instance_color(index))
			var asset_pose: Transform3D = pose * visual.pieces[piece_index].local_transform.affine_inverse()
			var bounds: AABB = asset_pose * native_bounds
			copy.set_instance_custom_data(index,Color(bounds.position.x,bounds.position.z,bounds.end.x,bounds.end.z))
		node.multimesh = copy
		node.set_meta("tactical_owner_footprints",true)
		count += 1
	print("EVENING_NATIVE_OWNERS ",count)
