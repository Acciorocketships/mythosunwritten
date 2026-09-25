extends SceneTree

class ProfilePath extends PathPlan:
	func _compute_node(cell: Vector2i) -> Dictionary:
		print("PATH_NODE_BEGIN ",cell)
		var result := super._compute_node(cell)
		print("PATH_NODE_END ",cell," ",result)
		return result
	func _compute_route(a: Dictionary,b: Dictionary,key: String) -> Dictionary:
		print("PATH_ROUTE_BEGIN ",key)
		var result := super._compute_route(a,b,key)
		print("PATH_ROUTE_END ",key)
		return result
	func _profile_bridge(site: Dictionary) -> Dictionary:
		print("PATH_BRIDGE_BEGIN ",site)
		var result := super._profile_bridge(site)
		print("PATH_BRIDGE_END")
		return result

class ProfileFields extends WorldFieldBlockCache:
	func water_at(point: Vector2) -> WaterFieldContext:
		var start := Time.get_ticks_msec()
		print("WATER_QUERY ",point)
		var result := super.water_at(point)
		print("WATER_DONE ",point," ms=",Time.get_ticks_msec()-start)
		return result

func _init() -> void:
	WaterField.profile_source_cost = true
	var snapshot_path := OS.get_environment("WATER_FINE_SNAPSHOT")
	if not snapshot_path.is_empty():
		WaterField.profile_fine_input=func(data: Dictionary)->void:
			if not FileAccess.file_exists(snapshot_path):
				FileAccess.open(snapshot_path,FileAccess.WRITE).store_var(data)
	var seed_value := 2697992464
	var water := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value,water)
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var fields := ProfileFields.new(heightfield,water,program.query_margin,program.shore_distance_limit,program.field_cache_cap)
	var paths := ProfilePath.new(seed_value,water,fields,program.paths,program.query_margin,SettlementPlan.new(seed_value,water),program.surface_priorities)
	var context := paths.context_for(Vector2i(-4,0))
	print("PATH_DONE ",context.coverage()," ",paths.stats())
	quit()
