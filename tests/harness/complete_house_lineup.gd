extends SceneTree

## Source-only visual qualification for every authored complete-building family.
## This deliberately reviews source scenes before catalog admission: a mesh whose
## filename says "Building" may still be an empty collision shell or an attachable.
const GROUPS: Array[Dictionary] = [
	{"id": "lpfv", "sources": [
		{"label": "House 01", "path": "res://assets/LowPolyFantasyVillage/Models/Houses/House_01.glb"},
		{"label": "House 02", "path": "res://assets/LowPolyFantasyVillage/Models/Houses/House_02.glb"},
		{"label": "House 03", "path": "res://assets/LowPolyFantasyVillage/Models/Houses/House_03.glb"},
		{"label": "House 04", "path": "res://assets/LowPolyFantasyVillage/Models/Houses/House_04.glb"},
		{"label": "House 05", "path": "res://assets/LowPolyFantasyVillage/Models/Houses/House_05.glb"},
		{"label": "House 06", "path": "res://assets/LowPolyFantasyVillage/Models/Houses/House_06.glb"},
		{"label": "House 07", "path": "res://assets/LowPolyFantasyVillage/Models/Houses/House_07.glb"},
		{"label": "Church", "path": "res://assets/LowPolyFantasyVillage/Models/Houses/Church.glb"},
	]},
	{"id": "sfv", "sources": [
		{"label": "Blue 01", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Blue_001.fbx"},
		{"label": "Blue 02", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Blue_002.fbx"},
		{"label": "Blue 03", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Blue_003.fbx"},
		{"label": "Blue 04", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Blue_004.fbx"},
		{"label": "Blue 05", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Blue_005.fbx"},
		{"label": "Blue 06", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Blue_006.fbx"},
		{"label": "Orange 01", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Orange_001.fbx"},
		{"label": "Orange 02", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Orange_002.fbx"},
		{"label": "Orange 03", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Orange_003.fbx"},
		{"label": "Orange 04", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Orange_004.fbx"},
		{"label": "Orange 05", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Orange_005.fbx"},
		{"label": "Orange 06", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Orange_006.fbx"},
	]},
	{"id": "tavern", "sources": [
		{"label": "Tavern 01", "path": "res://assets/TavernandKitchenFBX/FBX/Building/SFT_Building_001.fbx"},
		{"label": "Tavern 02", "path": "res://assets/TavernandKitchenFBX/FBX/Building/SFT_Building_002.fbx"},
		{"label": "Tavern 03", "path": "res://assets/TavernandKitchenFBX/FBX/Building/SFT_Building_003.fbx"},
		{"label": "Tavern 04", "path": "res://assets/TavernandKitchenFBX/FBX/Building/SFT_Building_004.fbx"},
		{"label": "Tavern 05", "path": "res://assets/TavernandKitchenFBX/FBX/Building/SFT_Building_005.fbx"},
		{"label": "Tavern 06", "path": "res://assets/TavernandKitchenFBX/FBX/Building/SFT_Building_006.fbx"},
		{"label": "Tavern 07", "path": "res://assets/TavernandKitchenFBX/FBX/Building/SFT_Building_007.fbx"},
	]},
	{"id": "alchemy", "sources": [
		{"label": "Alchemy 01", "path": "res://assets/AlchemyPackFBX/FBX/Building and Attachables/AWS_Building_001.fbx"},
		{"label": "Alchemy 02", "path": "res://assets/AlchemyPackFBX/FBX/Building and Attachables/AWS_Building_002.fbx"},
		{"label": "Alchemy 03", "path": "res://assets/AlchemyPackFBX/FBX/Building and Attachables/AWS_Building_003.fbx"},
	]},
	{"id": "forge", "sources": [
		{"label": "Forge 01", "path": "res://assets/ForgeFBX/FBX/Forge Building/SFFA_Building_001.fbx"},
		{"label": "Forge 02", "path": "res://assets/ForgeFBX/FBX/Forge Building/SFFA_Building_002.fbx"},
	]},
	{"id": "sfv_fake", "sources": [
		{"label": "Blue Empty 01", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Fake Buildings/SFV_Building_Empty_Blue_001.fbx"},
		{"label": "Blue Empty 02", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Fake Buildings/SFV_Building_Empty_Blue_002.fbx"},
		{"label": "Blue Empty 03", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Fake Buildings/SFV_Building_Empty_Blue_003.fbx"},
		{"label": "Blue Empty 04", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Fake Buildings/SFV_Building_Empty_Blue_004.fbx"},
		{"label": "Blue Empty 05", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Fake Buildings/SFV_Building_Empty_Blue_005.fbx"},
		{"label": "Blue Empty 06", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Fake Buildings/SFV_Building_Empty_Blue_006.fbx"},
		{"label": "Orange Empty 01", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Fake Buildings/SFV_Building_Empty_Orange_001.fbx"},
		{"label": "Orange Empty 02", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Fake Buildings/SFV_Building_Empty_Orange_002.fbx"},
		{"label": "Orange Empty 03", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Fake Buildings/SFV_Building_Empty_Orange_003.fbx"},
		{"label": "Orange Empty 04", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Fake Buildings/SFV_Building_Empty_Orange_004.fbx"},
		{"label": "Orange Empty 05", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Fake Buildings/SFV_Building_Empty_Orange_005.fbx"},
		{"label": "Orange Empty 06", "path": "res://assets/FantasyVillageFBX/FBX/Buildings/Fake Buildings/SFV_Building_Empty_Orange_006.fbx"},
	]},
	{"id": "other_exteriors", "sources": [
		{"label": "Alchemy Fake 01", "path": "res://assets/AlchemyPackFBX/FBX/Building and Attachables/AWS_Building_Fake_001.fbx"},
		{"label": "Alchemy Fake 02", "path": "res://assets/AlchemyPackFBX/FBX/Building and Attachables/AWS_Building_Fake_002.fbx"},
		{"label": "Alchemy Fake 03", "path": "res://assets/AlchemyPackFBX/FBX/Building and Attachables/AWS_Building_Fake_003.fbx"},
		{"label": "Tavern Fake 01", "path": "res://assets/TavernandKitchenFBX/FBX/Building/SFT_Building_Fake_001.fbx"},
		{"label": "Tavern Fake 02", "path": "res://assets/TavernandKitchenFBX/FBX/Building/SFT_Building_Fake_002.fbx"},
		{"label": "Forge Empty 01", "path": "res://assets/ForgeFBX/FBX/Forge Building/SFFA_Building_Empty_001.fbx"},
		{"label": "Forge Empty 02", "path": "res://assets/ForgeFBX/FBX/Forge Building/SFFA_Building_Empty_002.fbx"},
	]},
	{"id": "windmills", "sources": [
		{"label": "Windmill 01", "path": "res://assets/FantasyVillageFBX/FBX/Windmill/SFV_Windmill_001.fbx"},
		{"label": "Windmill 02", "path": "res://assets/FantasyVillageFBX/FBX/Windmill/SFV_Windmill_002.fbx"},
		{"label": "Windmill 03", "path": "res://assets/FantasyVillageFBX/FBX/Windmill/SFV_Windmill_003.fbx"},
	]},
	{"id": "lpfv_small", "sources": [
		{"label": "Small House 01", "path": "res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_01.glb"},
		{"label": "Small House 02", "path": "res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_02.glb"},
		{"label": "Small House 03", "path": "res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_03.glb"},
		{"label": "Small House 04", "path": "res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_04.glb"},
		{"label": "Small House 05", "path": "res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_05.glb"},
		{"label": "Small House 06", "path": "res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_06.glb"},
		{"label": "Small House 07", "path": "res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_07.glb"},
		{"label": "Small House 08", "path": "res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_08.glb"},
	]},
	{"id": "towers_workshop", "sources": [
		{"label": "Village Tower", "path": "res://assets/LowPolyFantasyVillage/Models/Props/Tower.glb"},
		{"label": "Battle Tower", "path": "res://assets/BattlePackFBX/FBX/Battle Props/Tower001/SFBP_Tower_001.fbx"},
		{"label": "Wall Tower", "path": "res://assets/BattlePackFBX/FBX/Wooden Walls/Tower/SFBP_WWall_Tower_001.fbx"},
		{"label": "Forge Workshop", "path": "res://assets/CraftingFBX/FBX/Workstations/SFWC_Forge_Workshop_001.fbx"},
	]},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("a6b4bd")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.75
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 50.0
	world.add_child(camera)
	for group: Dictionary in GROUPS:
		var sources := group.sources as Array
		var columns := mini(4, sources.size())
		var rows := ceili(float(sources.size()) / float(columns))
		var spacing := 28.0
		var group_nodes: Array[Node] = []
		for index in sources.size():
			var source := sources[index] as Dictionary
			var scene := load(String(source.path)) as PackedScene
			assert(scene != null)
			var instance := scene.instantiate() as Node3D
			instance.position = Vector3(
				(float(index % columns) - float(columns - 1) * 0.5) * spacing,
				0.0,
				(float(index / columns) - float(rows - 1) * 0.5) * spacing)
			world.add_child(instance)
			group_nodes.append(instance)
			var label := Label3D.new()
			label.text = String(source.label)
			label.font_size = 64
			label.outline_size = 10
			label.position = instance.position + Vector3(0.0, 17.0, 0.0)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			world.add_child(label)
			group_nodes.append(label)
		camera.position = Vector3(float(columns) * spacing * 0.75,
			maxf(25.0, float(rows) * spacing * 0.75),
			float(rows) * spacing * 1.1)
		camera.look_at(Vector3(0.0, 5.0, 0.0))
		for unused in 10:
			await process_frame
		RenderingServer.force_draw()
		await process_frame
		var capture_path := "/tmp/warren-complete-buildings-%s.png" \
			% String(group.id)
		var image := root.get_texture().get_image()
		assert(image != null and image.save_png(capture_path) == OK)
		print("[complete_house_lineup] captured %s" % capture_path)
		for node: Node in group_nodes:
			node.queue_free()
		await process_frame
		# The lineup is useful for silhouette comparison, but it is too distant to
		# qualify authored doors, balconies, foundations, and backs.  Capture every
		# admitted Low Poly Fantasy Village source on its own from opposite oblique
		# angles so an asset with a second unserved exterior door cannot hide behind
		# the generator's one declared entrance.
		if String(group.id) == "lpfv":
			for index in sources.size():
				var source := sources[index] as Dictionary
				var scene := load(String(source.path)) as PackedScene
				assert(scene != null)
				var instance := scene.instantiate() as Node3D
				world.add_child(instance)
				await process_frame
				var bounds := _visual_bounds(instance)
				assert(bounds.has_volume())
				var target := bounds.get_center()
				var radius := maxf(maxf(bounds.size.x, bounds.size.z),
					bounds.size.y) * 1.8
				for view: Dictionary in [
					{"id": "se", "direction": Vector3(1.0, 0.62, 1.0)},
					{"id": "sw", "direction": Vector3(-1.0, 0.62, 1.0)},
					{"id": "nw", "direction": Vector3(-1.0, 0.62, -1.0)},
					{"id": "ne", "direction": Vector3(1.0, 0.62, -1.0)},
				]:
					camera.position = target + (view.direction as Vector3).normalized() \
						* maxf(radius, 8.0)
					camera.look_at(target)
					for unused in 4:
						await process_frame
					RenderingServer.force_draw()
					await process_frame
					var detail_path := "/tmp/warren-complete-building-lpfv-%02d-%s.png" % [
						index, String(view.id)]
					var detail_image := root.get_texture().get_image()
					assert(detail_image != null \
						and detail_image.save_png(detail_path) == OK)
					print("[complete_house_lineup] captured %s" % detail_path)
				instance.queue_free()
				await process_frame
	quit()


func _visual_bounds(instance: Node3D) -> AABB:
	var points: Array[Vector3] = []
	_collect_visual_points(instance, instance.global_transform.affine_inverse(), points)
	if points.is_empty():
		return AABB()
	var bounds := AABB(points[0], Vector3.ZERO)
	for index in range(1, points.size()):
		bounds = bounds.expand(points[index])
	return bounds


func _collect_visual_points(node: Node, inverse_root: Transform3D,
		points: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var bounds := mesh_instance.mesh.get_aabb()
			var transform := inverse_root * mesh_instance.global_transform
			for x in 2:
				for y in 2:
					for z in 2:
						points.append(transform * Vector3(
							bounds.end.x if x else bounds.position.x,
							bounds.end.y if y else bounds.position.y,
							bounds.end.z if z else bounds.position.z))
	for child: Node in node.get_children():
		_collect_visual_points(child, inverse_root, points)
