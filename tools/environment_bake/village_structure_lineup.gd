extends Node3D

## Bake-side visual inventory for complete building and tent families. Source
## packs stay confined to tooling; production code consumes only accepted,
## self-contained catalog assets.
const HOUSE_FORMAT := "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Blue_%03d.fbx"
const TENT_SOURCES: Array[Dictionary] = [
	{"label": "plain 1", "path": "res://assets/BattlePackFBX/FBX/Tents/Empty Tents/SFBP_Tent1_001.fbx"},
	{"label": "plain 2", "path": "res://assets/BattlePackFBX/FBX/Tents/Empty Tents/SFBP_Tent2_001.fbx"},
	{"label": "plain 3", "path": "res://assets/BattlePackFBX/FBX/Tents/Empty Tents/SFBP_Tent3_001.fbx"},
	{"label": "plain 4", "path": "res://assets/BattlePackFBX/FBX/Tents/Empty Tents/SFBP_Tent4_001.fbx"},
	{"label": "plain 5", "path": "res://assets/BattlePackFBX/FBX/Tents/Empty Tents/SFBP_Tent5_001.fbx"},
	{"label": "plain 6", "path": "res://assets/BattlePackFBX/FBX/Tents/Empty Tents/SFBP_Tent6_001.fbx"},
	{"label": "armory", "path": "res://assets/BattlePackFBX/FBX/Tents/Themed Tents/SFBP_Tent_Armory_001.fbx"},
	{"label": "deposit", "path": "res://assets/BattlePackFBX/FBX/Tents/Themed Tents/SFBP_Tent_Deposit_001.fbx"},
	{"label": "dormitory 1", "path": "res://assets/BattlePackFBX/FBX/Tents/Themed Tents/SFBP_Tent_Dormitory1_001.fbx"},
	{"label": "dormitory 2", "path": "res://assets/BattlePackFBX/FBX/Tents/Themed Tents/SFBP_Tent_Dormitory2_001.fbx"},
	{"label": "forge", "path": "res://assets/BattlePackFBX/FBX/Tents/Themed Tents/SFBP_Tent_Forge_001.fbx"},
]
const MARKET_SOURCES: Array[Dictionary] = [
	{"label": "alchemy 1", "path": "res://assets/FantasyMarketFBX/FBX/Alchemy Stall/Stall/SFM_Alchemy_Stall_001.fbx"},
	{"label": "alchemy 2", "path": "res://assets/FantasyMarketFBX/FBX/Alchemy Stall/Stall/SFM_Alchemy_Stall_002.fbx"},
	{"label": "forge 1", "path": "res://assets/FantasyMarketFBX/FBX/Forge Stall/Stall/SFM_Forge_Stall_001.fbx"},
	{"label": "forge 2", "path": "res://assets/FantasyMarketFBX/FBX/Forge Stall/Stall/SFM_Forge_Stall_002.fbx"},
	{"label": "forge 3", "path": "res://assets/FantasyMarketFBX/FBX/Forge Stall/Stall/SFM_Forge_Stall_003.fbx"},
	{"label": "fish 1", "path": "res://assets/FantasyMarketFBX/FBX/Fishmonger Stall/Stall/SFM_Fishmonger_Stall_001.fbx"},
	{"label": "fish 2", "path": "res://assets/FantasyMarketFBX/FBX/Fishmonger Stall/Stall/SFM_Fishmonger_Stall_002.fbx"},
	{"label": "tavern 1", "path": "res://assets/FantasyMarketFBX/FBX/Tavern Stall/Stall/SFM_Tavern_Stall_001.fbx"},
	{"label": "tavern 2", "path": "res://assets/FantasyMarketFBX/FBX/Tavern Stall/Stall/SFM_Tavern_Stall_002.fbx"},
	{"label": "tavern 3", "path": "res://assets/FantasyMarketFBX/FBX/Tavern Stall/Stall/SFM_Tavern_Stall_003.fbx"},
	{"label": "butcher 1", "path": "res://assets/FantasyMarketFBX/FBX/Butcher Stall/Stall/SFM_Butcher_Stall_001.fbx"},
	{"label": "butcher 2", "path": "res://assets/FantasyMarketFBX/FBX/Butcher Stall/Stall/SFM_Butcher_Stall_002.fbx"},
	{"label": "butcher 3", "path": "res://assets/FantasyMarketFBX/FBX/Butcher Stall/Stall/SFM_Butcher_Stall_003.fbx"},
	{"label": "butcher attach", "path": "res://assets/FantasyMarketFBX/FBX/Butcher Stall/Stall/SFM_Butcher_Stall_Attachable_001.fbx"},
]
const FENCE_SOURCES: Array[Dictionary] = [
	{"label": "fence 001", "path": "res://assets/FantasyVillageFBX/FBX/Exterior Props/Fence/SFV_Fence_001.fbx"},
	{"label": "fence 002", "path": "res://assets/FantasyVillageFBX/FBX/Exterior Props/Fence/SFV_Fence_002.fbx"},
	{"label": "fence 003", "path": "res://assets/FantasyVillageFBX/FBX/Exterior Props/Fence/SFV_Fence_003.fbx"},
	{"label": "handrail 001", "path": "res://assets/FantasyVillageFBX/FBX/Stairs/Stair Parts/SFV_Stairs_Handrail_001.fbx"},
	{"label": "handrail 002", "path": "res://assets/FantasyVillageFBX/FBX/Stairs/Stair Parts/SFV_Stairs_Handrail_002.fbx"},
	{"label": "handrail 003", "path": "res://assets/FantasyVillageFBX/FBX/Stairs/Stair Parts/SFV_Stairs_Handrail_003.fbx"},
	{"label": "handrail base 001", "path": "res://assets/FantasyVillageFBX/FBX/Stairs/Stair Parts/SFV_Stairs_Handrail_Base_001.fbx"},
	{"label": "handrail base 002", "path": "res://assets/FantasyVillageFBX/FBX/Stairs/Stair Parts/SFV_Stairs_Handrail_Base_002.fbx"},
]


func _ready() -> void:
	var family := _argument("--family", "houses")
	var layout := _house_layout() if family == "houses" \
		else _market_layout() if family == "markets" \
		else _fence_layout() if family == "fences" else _tent_layout()
	_build_environment(layout)
	_build_lineup(layout.items, int(layout.columns), layout.spacing)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output_path := _argument("--output",
		"/tmp/mythos-village-%s-lineup.png" % family)
	var error := get_viewport().get_texture().get_image().save_png(output_path)
	print("[village_structure_lineup] family=%s output=%s error=%d" % [
		family, output_path, error])
	get_tree().quit(0 if error == OK else 1)


static func _house_layout() -> Dictionary:
	var items: Array[Dictionary] = []
	for index in range(1, 7):
		items.append({"label": "house %03d" % index,
			"path": HOUSE_FORMAT % index})
	return {"items": items, "columns": 3, "spacing": Vector2(26.0, 25.0),
		"ground_size": Vector2(82.0, 58.0), "camera_size": 60.0,
		"camera_position": Vector3(0.0, 55.0, 64.0),
		"camera_target": Vector3(0.0, 6.0, 0.0)}


static func _tent_layout() -> Dictionary:
	return {"items": TENT_SOURCES, "columns": 4,
		"spacing": Vector2(13.0, 12.0),
		"ground_size": Vector2(56.0, 43.0), "camera_size": 45.0,
		"camera_position": Vector3(0.0, 38.0, 44.0),
		"camera_target": Vector3(0.0, 2.0, 0.0)}


static func _market_layout() -> Dictionary:
	return {"items": MARKET_SOURCES, "columns": 4,
		"spacing": Vector2(12.0, 11.0),
		"ground_size": Vector2(54.0, 49.0), "camera_size": 53.0,
		"camera_position": Vector3(0.0, 44.0, 54.0),
		"camera_target": Vector3(0.0, 1.5, 0.0)}


static func _fence_layout() -> Dictionary:
	return {"items": FENCE_SOURCES, "columns": 4,
		"spacing": Vector2(5.0, 5.0),
		"ground_size": Vector2(23.0, 18.0), "camera_size": 19.0,
		"camera_position": Vector3(0.0, 10.0, 15.0),
		"camera_target": Vector3(0.0, 0.7, 0.0)}


func _build_environment(layout: Dictionary) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.58, 0.78, 0.91)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.7
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = layout.ground_size
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.32, 0.58, 0.24)
	material.roughness = 1.0
	plane.material = material
	ground.mesh = plane
	add_child(ground)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = float(layout.camera_size)
	camera.look_at_from_position(layout.camera_position, layout.camera_target)
	camera.current = true
	add_child(camera)


func _build_lineup(items: Array, columns: int, spacing: Vector2) -> void:
	var rows := ceili(float(items.size()) / float(columns))
	for item_index in items.size():
		var item := items[item_index] as Dictionary
		var packed := load(String(item.path)) as PackedScene
		assert(packed != null, "Missing source structure: %s" % item.path)
		var column := item_index % columns
		var row := item_index / columns
		var x := (float(column) - float(columns - 1) * 0.5) * spacing.x
		var z := (float(row) - float(rows - 1) * 0.5) * spacing.y
		var structure := packed.instantiate() as Node3D
		structure.position = Vector3(x, 0.0, z)
		add_child(structure)
		var label := Label3D.new()
		label.text = String(item.label)
		label.font_size = 72
		label.pixel_size = 0.009
		label.outline_size = 10
		label.position = Vector3(x, 0.35, z + spacing.y * 0.35)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		add_child(label)


static func _argument(name: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == name and index + 1 < args.size():
			return args[index + 1]
	return fallback
