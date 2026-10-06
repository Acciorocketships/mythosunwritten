extends SceneTree
## Worker-side opening envelopes measured from glazing and window materials.
func _init() -> void:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var kits: Array[BuildingKit] = [SuntailBuildingKit.create(),preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").create()]
	kits.append(preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").create(1))
	kits.append(preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").roof_study())
	var assets := {}
	for kit in kits:
		for role: StringName in kit.roles:
			if not ((String(role).begins_with("wall.") and String(role).ends_with(".window")) or String(role).begins_with("bay.") or String(role).ends_with("dormer")): continue
			for id: StringName in kit.roles[role]: assets[id] = true
	var out := {}
	var frames := {}
	for id: StringName in KitVillageBuildings.sorted_ids(assets.keys()):
		var visual := cache.visual(id)
		var bounds := AABB()
		var first := true
		var connected_wood: Array[AABB] = []
		for piece in visual.pieces:
			for si in piece.mesh.get_surface_count():
				var material := piece.mesh.surface_get_material(si)
				if String(id).begins_with("pure_village.wall.plaster.window") and material.resource_name in ["Wood_1","Wood_2"]:
					var wood := piece.mesh.surface_get_arrays(si)
					for component: AABB in preload("res://tests/harness/suntail/window_frame_components.gd").bounds(wood[Mesh.ARRAY_VERTEX],wood[Mesh.ARRAY_INDEX]):
						# The continuous panel foot beam is not a window surround.
						if component.end.y < 0.1: continue
						if not frames.has(id): frames[id] = []
						frames[id].append(piece.local_transform * component)
				if ((String(id).begins_with("suntail.") or String(id).begins_with("pure_village.bay.frame_")) and material.resource_name == "Wooden_Planks") \
						or (id == &"pure_village.wall.stone.window" and material.resource_name in ["Wood_1","Wood_2"]):
					var wood := piece.mesh.surface_get_arrays(si)
					for component: AABB in preload("res://tests/harness/suntail/window_frame_components.gd").bounds(wood[Mesh.ARRAY_VERTEX],wood[Mesh.ARRAY_INDEX]):
						connected_wood.append(piece.local_transform * component)
				if material.resource_name != "Glass_Out" and not String(material.resource_name).begins_with("Window"): continue
				var arrays := piece.mesh.surface_get_arrays(si)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				if indices.is_empty():
					for i in vertices.size(): indices.append(i)
				for i in indices:
					var p: Vector3 = piece.local_transform * vertices[i]
					bounds = AABB(p,Vector3.ZERO) if first else bounds.expand(p)
					first = false
		assert(not first,"No glazing found: " + String(id))
		if not connected_wood.is_empty():
			frames[id] = preload("res://tests/harness/suntail/window_frame_components.gd").touching_opening(connected_wood,bounds)
			print("CONNECTED_FRAME ",id," ",frames[id])
		out[id] = bounds
		print("WINDOW_OPENING ",id," ",bounds)
	FileAccess.open("res://terrain/environment/geometry/window_openings.bin",FileAccess.WRITE).store_var(out)
	FileAccess.open("res://terrain/environment/geometry/window_frames.bin",FileAccess.WRITE).store_var(frames)
	quit()
