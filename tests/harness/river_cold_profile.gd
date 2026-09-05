extends SceneTree
func _initialize() -> void:
	var start := Time.get_ticks_msec()
	var water := WaterPlan.new(991177, 22.0, 8)
	var region := water._region_for(Vector2i.ZERO)
	print("COLD water region ms=", Time.get_ticks_msec() - start, " sources=", water._has_source_cache.size(), " traces=", water._trace_cache.size(), " local=", region.rivers.size())
	quit()
