@tool
extends SceneTree

## Read-only Phase-0 inventory for representative village structure families.
## This intentionally lives beside the bake tool: runtime code never loads source
## packs, and the measured output is used to choose corrections and hard gates.
const SOURCES := {
	&"house_blue_001": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Blue_001.fbx",
	&"house_blue_002": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Blue_002.fbx",
	&"house_blue_003": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Blue_003.fbx",
	&"house_blue_004": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Blue_004.fbx",
	&"house_blue_005": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Blue_005.fbx",
	&"house_blue_006": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Blue_006.fbx",
	&"house_orange_001": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Orange_001.fbx",
	&"house_orange_002": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Orange_002.fbx",
	&"house_orange_003": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Orange_003.fbx",
	&"house_orange_004": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Orange_004.fbx",
	&"house_orange_005": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Orange_005.fbx",
	&"house_orange_006": "res://assets/FantasyVillageFBX/FBX/Buildings/Buildings/SFV_Building_Interior_Orange_006.fbx",
	&"tavern": "res://assets/TavernandKitchenFBX/FBX/Building/SFT_Building_001.fbx",
	&"tavern_002": "res://assets/TavernandKitchenFBX/FBX/Building/SFT_Building_002.fbx",
	&"tavern_003": "res://assets/TavernandKitchenFBX/FBX/Building/SFT_Building_003.fbx",
	&"tavern_004": "res://assets/TavernandKitchenFBX/FBX/Building/SFT_Building_004.fbx",
	&"tavern_005": "res://assets/TavernandKitchenFBX/FBX/Building/SFT_Building_005.fbx",
	&"tavern_006": "res://assets/TavernandKitchenFBX/FBX/Building/SFT_Building_006.fbx",
	&"tavern_007": "res://assets/TavernandKitchenFBX/FBX/Building/SFT_Building_007.fbx",
	&"forge": "res://assets/ForgeFBX/FBX/Forge Building/SFFA_Building_001.fbx",
	&"alchemy": "res://assets/AlchemyPackFBX/FBX/Building and Attachables/AWS_Building_003.fbx",
	&"alchemy_001": "res://assets/AlchemyPackFBX/FBX/Building and Attachables/AWS_Building_001.fbx",
	&"alchemy_002": "res://assets/AlchemyPackFBX/FBX/Building and Attachables/AWS_Building_002.fbx",
	&"walk_in_tent": "res://assets/BattlePackFBX/FBX/Tents/Empty Tents/SFBP_Tent1_001.fbx",
	&"empty_tent_002": "res://assets/BattlePackFBX/FBX/Tents/Empty Tents/SFBP_Tent2_001.fbx",
	&"empty_tent_003": "res://assets/BattlePackFBX/FBX/Tents/Empty Tents/SFBP_Tent3_001.fbx",
	&"empty_tent_004": "res://assets/BattlePackFBX/FBX/Tents/Empty Tents/SFBP_Tent4_001.fbx",
	&"empty_tent_005": "res://assets/BattlePackFBX/FBX/Tents/Empty Tents/SFBP_Tent5_001.fbx",
	&"empty_tent_006": "res://assets/BattlePackFBX/FBX/Tents/Empty Tents/SFBP_Tent6_001.fbx",
	&"themed_tent_armory": "res://assets/BattlePackFBX/FBX/Tents/Themed Tents/SFBP_Tent_Armory_001.fbx",
	&"themed_tent_deposit": "res://assets/BattlePackFBX/FBX/Tents/Themed Tents/SFBP_Tent_Deposit_001.fbx",
	&"themed_tent_dormitory_1": "res://assets/BattlePackFBX/FBX/Tents/Themed Tents/SFBP_Tent_Dormitory1_001.fbx",
	&"themed_tent_dormitory_2": "res://assets/BattlePackFBX/FBX/Tents/Themed Tents/SFBP_Tent_Dormitory2_001.fbx",
	&"themed_tent_forge": "res://assets/BattlePackFBX/FBX/Tents/Themed Tents/SFBP_Tent_Forge_001.fbx",
	&"market_stall": "res://assets/FantasyMarketFBX/FBX/Stall Color Variations/SFM_Stall_006.fbx",
	&"market_alchemy_001": "res://assets/FantasyMarketFBX/FBX/Alchemy Stall/Stall/SFM_Alchemy_Stall_001.fbx",
	&"market_alchemy_002": "res://assets/FantasyMarketFBX/FBX/Alchemy Stall/Stall/SFM_Alchemy_Stall_002.fbx",
	&"market_armory_001": "res://assets/FantasyMarketFBX/FBX/Armory Stall/Stall/SFM_Armory_Stall_001.fbx",
	&"market_armory_002": "res://assets/FantasyMarketFBX/FBX/Armory Stall/Stall/SFM_Armory_Stall_002.fbx",
	&"market_bakery_001": "res://assets/FantasyMarketFBX/FBX/Bakery Stall/Stall/SFM_Bakery_Stall_001.fbx",
	&"market_bakery_002": "res://assets/FantasyMarketFBX/FBX/Bakery Stall/Stall/SFM_Bakery_Stall_002.fbx",
	&"market_butcher_001": "res://assets/FantasyMarketFBX/FBX/Butcher Stall/Stall/SFM_Butcher_Stall_001.fbx",
	&"market_butcher_002": "res://assets/FantasyMarketFBX/FBX/Butcher Stall/Stall/SFM_Butcher_Stall_002.fbx",
	&"market_butcher_003": "res://assets/FantasyMarketFBX/FBX/Butcher Stall/Stall/SFM_Butcher_Stall_003.fbx",
	&"market_fabric_001": "res://assets/FantasyMarketFBX/FBX/Fabric Stall/Stall/SFM_Fabric_Stall_001.001.fbx",
	&"market_fabric_002": "res://assets/FantasyMarketFBX/FBX/Fabric Stall/Stall/SFM_Fabric_Stall_002.fbx",
	&"market_fish_001": "res://assets/FantasyMarketFBX/FBX/Fishmonger Stall/Stall/SFM_Fishmonger_Stall_001.fbx",
	&"market_fish_002": "res://assets/FantasyMarketFBX/FBX/Fishmonger Stall/Stall/SFM_Fishmonger_Stall_002.fbx",
	&"market_forge_001": "res://assets/FantasyMarketFBX/FBX/Forge Stall/Stall/SFM_Forge_Stall_001.fbx",
	&"market_forge_002": "res://assets/FantasyMarketFBX/FBX/Forge Stall/Stall/SFM_Forge_Stall_002.fbx",
	&"market_forge_003": "res://assets/FantasyMarketFBX/FBX/Forge Stall/Stall/SFM_Forge_Stall_003.fbx",
	&"market_veg_001": "res://assets/FantasyMarketFBX/FBX/Fruits Stall/Stall/SFM_Veg_Stall_001.fbx",
	&"market_veg_002": "res://assets/FantasyMarketFBX/FBX/Fruits Stall/Stall/SFM_Veg_Stall_002.fbx",
	&"market_veg_003": "res://assets/FantasyMarketFBX/FBX/Fruits Stall/Stall/SFM_Veg_Stall_003.fbx",
	&"market_veg_004": "res://assets/FantasyMarketFBX/FBX/Fruits Stall/Stall/SFM_Veg_Stall_004.fbx",
	&"market_tavern_001": "res://assets/FantasyMarketFBX/FBX/Tavern Stall/Stall/SFM_Tavern_Stall_001.fbx",
	&"market_tavern_002": "res://assets/FantasyMarketFBX/FBX/Tavern Stall/Stall/SFM_Tavern_Stall_002.fbx",
	&"market_tavern_003": "res://assets/FantasyMarketFBX/FBX/Tavern Stall/Stall/SFM_Tavern_Stall_003.fbx",
	&"market_table": "res://assets/FantasyMarketFBX/FBX/Fishmonger Stall/Table/SFM_Table_001.fbx",
	&"well": "res://assets/FantasyVillageFBX/FBX/Exterior Props/Water Well/SFV_Well_001.fbx",
	&"quest_board": "res://assets/FantasyVillageFBX/FBX/Exterior Props/Quest Board/SFV_Quest_Board_001.fbx",
	&"fence": "res://assets/FantasyVillageFBX/FBX/Exterior Props/Fence/SFV_Fence_001.fbx",
	&"campfire": "res://assets/BattlePackFBX/FBX/General Props/Campfire/SFBP_Campfire_001.fbx",
	&"deck": "res://assets/BattlePackFBX/FBX/Wooden Walls/Floor/SFBP_WWall_Floor_001.fbx",
	&"support_s": "res://assets/BattlePackFBX/FBX/Wooden Walls/Floor/SFBP_WWall_Floor_Support_S_001.fbx",
	&"support_m": "res://assets/BattlePackFBX/FBX/Wooden Walls/Floor/SFBP_WWall_Floor_Support_M_001.fbx",
	&"stair": "res://assets/FantasyVillageFBX/FBX/Stairs/Stair Parts/SFV_Stair_S_001.fbx",
	&"stair_m": "res://assets/FantasyVillageFBX/FBX/Stairs/Stair Parts/SFV_Stair_M_001.fbx",
	&"stair_landing": "res://assets/FantasyVillageFBX/FBX/Stairs/Stair Parts/SFV_Stair_Floor_M_001.fbx",
	&"stair_handrail": "res://assets/FantasyVillageFBX/FBX/Stairs/Stair Parts/SFV_Stairs_Handrail_001.fbx",
	&"wood_pillar": "res://assets/FantasyVillageFBX/FBX/Pillars and Floor/Pillars/SFV_Wall_Pillar_001.fbx",
	&"rock_foundation": "res://assets/FantasyVillageFBX/FBX/Walls/Rock/Walls/SFV_Wall_Rock_001.fbx",
}

func _init() -> void:
	if OS.get_cmdline_user_args().has("--stall-colors"):
		print(JSON.stringify(_stall_color_report(), "" \
			if OS.get_cmdline_user_args().has("--compact") else "  "))
		quit()
		return
	var requested_family := _requested_family()
	var report: Array[Dictionary] = []
	var family_names: Array[StringName] = []
	family_names.assign(SOURCES.keys())
	family_names.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for family: StringName in family_names:
		if not requested_family.is_empty() and family != requested_family:
			continue
		var measured := _measure(family, SOURCES[family])
		report.append(_summary(measured) \
			if OS.get_cmdline_user_args().has("--summary") else measured)
	print(JSON.stringify(report, "" if OS.get_cmdline_user_args().has(
		"--compact") else "  "))
	quit()


static func _summary(measured: Dictionary) -> Dictionary:
	return {
		"family": measured.family,
		"source": measured.source,
		"aabb_min": measured.aabb_min,
		"aabb_size": measured.aabb_size,
		"ground_contact_025": measured.ground_contact_025,
		"door_named_bounds": measured.door_named_bounds,
		"source_pieces": measured.source_pieces,
		"visual_triangles": measured.visual_triangles,
	}


static func _stall_color_report() -> Array[Dictionary]:
	var report: Array[Dictionary] = []
	for index in range(1, 18):
		var source_path := "res://assets/FantasyMarketFBX/FBX/Stall Color Variations/SFM_Stall_%03d.fbx" % index
		if not ResourceLoader.exists(source_path):
			continue
		var packed := load(source_path) as PackedScene
		assert(packed != null, "Missing imported stall source: %s" % source_path)
		var root := packed.instantiate()
		var merged := EnvironmentBakeGeometry.merge_pieces(root,
			Transform3D.IDENTITY)
		assert(merged != null)
		var materials: Array[Dictionary] = []
		var seen: Dictionary = {}
		for instance: MeshInstance3D in _mesh_instances(root):
			for surface_index in instance.mesh.get_surface_count():
				var material := instance.get_active_material(surface_index)
				var key := material.get_instance_id() if material != null else 0
				if seen.has(key):
					continue
				seen[key] = true
				materials.append(_material_summary(material))
		report.append({
			"variant": index,
			"source": source_path,
			"materials": materials,
			"aabb_min": _v3(merged.get_aabb().position),
			"aabb_size": _v3(merged.get_aabb().size),
			"visual_triangles": EnvironmentBakeGeometry.triangle_faces(
				merged).size() / 3,
		})
		root.free()
	return report


static func _material_summary(material: Material) -> Dictionary:
	if material == null:
		return {"type": "none"}
	var result := {
		"type": material.get_class(),
		"path": material.resource_path,
	}
	var base := material as BaseMaterial3D
	if base != null:
		result["albedo"] = [base.albedo_color.r, base.albedo_color.g,
			base.albedo_color.b, base.albedo_color.a]
		result["albedo_texture"] = base.albedo_texture.resource_path \
			if base.albedo_texture != null else ""
	return result


static func _requested_family() -> StringName:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--family" and index + 1 < args.size():
			var family := StringName(args[index + 1])
			assert(SOURCES.has(family), "Unknown structural-probe family: %s" % family)
			return family
	return &""

static func _measure(family: StringName, source_path: String) -> Dictionary:
	var packed := load(source_path) as PackedScene
	assert(packed != null, "Missing imported source scene: %s" % source_path)
	var root := packed.instantiate()
	var source_pieces := _mesh_instances(root)
	var merged := EnvironmentBakeGeometry.merge_pieces(root,
		Transform3D.IDENTITY)
	assert(merged != null, "Source contains no mergeable mesh: %s" % source_path)
	var faces := EnvironmentBakeGeometry.triangle_faces(merged)
	var bounds := merged.get_aabb()
	var material_paths: Array[String] = []
	for surface_index in merged.get_surface_count():
		var material := merged.surface_get_material(surface_index)
		material_paths.append(material.resource_path if material != null else "")
	material_paths.sort()
	var result := {
		"family": String(family),
		"source": source_path,
		"source_pieces": source_pieces.size(),
		"merged_surfaces": merged.get_surface_count(),
		"visual_triangles": faces.size() / 3,
		"aabb_min": _v3(bounds.position),
		"aabb_max": _v3(bounds.end),
		"aabb_size": _v3(bounds.size),
		# Whole-prefab AABBs include roofs/eaves and are unsuitable as support
		# contacts. These low bands expose the authored ground-bearing envelope
		# that VillageAssetSpec must review independently from lot clearance.
		"ground_contact_025": _low_band_bounds(faces, bounds.position.y + 0.25),
		"ground_contact_050": _low_band_bounds(faces, bounds.position.y + 0.50),
		"ground_contact_100": _low_band_bounds(faces, bounds.position.y + 1.00),
		"material_paths": material_paths,
		"door_named_bounds": _named_mesh_bounds(root, "door"),
		"front_ground_pieces": _front_ground_pieces(root, bounds),
	}
	root.free()
	return result

static func _low_band_bounds(vertices: PackedVector3Array,
		maximum_y: float) -> Dictionary:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var count := 0
	for vertex: Vector3 in vertices:
		if vertex.y > maximum_y:
			continue
		minimum = minimum.min(vertex)
		maximum = maximum.max(vertex)
		count += 1
	if count == 0:
		return {}
	return {
		"min": _v3(minimum),
		"max": _v3(maximum),
		"size": _v3(maximum - minimum),
		"vertices": count,
	}

static func _mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var mesh_instance := node as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null:
			out.append(mesh_instance)
		for child: Node in node.get_children():
			stack.append(child)
	return out

static func _named_mesh_bounds(root: Node, needle: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for instance: MeshInstance3D in _mesh_instances(root):
		var node_path := String(root.get_path_to(instance))
		if not node_path.to_lower().contains(needle):
			continue
		var bounds := EnvironmentBakeGeometry.relative_transform(instance, root) \
			* instance.mesh.get_aabb()
		out.append({
			"node": node_path,
			"min": _v3(bounds.position),
			"max": _v3(bounds.end),
			"size": _v3(bounds.size),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.node) < String(b.node))
	return out

static func _front_ground_pieces(root: Node, merged_bounds: AABB) \
		-> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# Roof eaves often extend well beyond the actual facade. Keep a deep enough
	# band to include jambs and door leaves while retaining the low-height gate.
	var front_min := merged_bounds.end.z - 3.5
	for instance: MeshInstance3D in _mesh_instances(root):
		var bounds := EnvironmentBakeGeometry.relative_transform(instance, root) \
			* instance.mesh.get_aabb()
		if bounds.position.y > merged_bounds.position.y + 3.0 \
				or bounds.end.z < front_min:
			continue
		out.append({
			"node": String(root.get_path_to(instance)),
			"min": _v3(bounds.position),
			"max": _v3(bounds.end),
			"size": _v3(bounds.size),
			"triangles": EnvironmentBakeGeometry.triangle_faces(
				instance.mesh).size() / 3,
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.node) < String(b.node))
	return out

static func _v3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
