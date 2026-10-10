extends SceneTree
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var baseline := preload("res://tests/harness/fixtures/retained_point_index.gd")
	var digests := []
	for kind in ["before","after"]:
		var water: WaterPlan = baseline.new(2697992464,TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE,TerrainWorldTuning.HEIGHTFIELD_MAX_STOREYS) if kind == "before" else TerrainWorldTuning.make_water(2697992464)
		var start := Performance.get_monitor(Performance.MEMORY_STATIC)
		var timer := Time.get_ticks_usec()
		var point_entries := 0
		var segment_entries := 0
		var digest := PackedFloat64Array()
		for rc in [Vector2i(0,1),Vector2i(0,2),Vector2i(1,2)]:
			var region := water._region_for(rc)
			for bucket: Array in region.get("buckets",{}).values(): point_entries += bucket.size()
			for flat: Array in region.segments.values(): segment_entries += flat.size()/2
			for z in range(0,768,24):
				for x in range(0,768,24):
					var p := Vector2(rc)*768.0+Vector2(x,z)
					digest.append(water._carve_region(region,p.x,p.y))
		digests.append(digest)
		print("CARVE_MEMORY ",JSON.stringify({"kind":kind,"mb":(Performance.get_monitor(Performance.MEMORY_STATIC)-start)/1048576.0,"point_entries":point_entries,"segments":segment_entries,"seconds":(Time.get_ticks_usec()-timer)/1000000.0}))
		water = null
	assert(digests[0] == digests[1],"exact same carve samples")
	print("CARVE_MEMORY identical=",digests[0].size())
	quit()
