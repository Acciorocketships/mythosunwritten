extends SceneTree
const EIGHT = preload("res://tests/fixtures/september19/hillside-fill-stages/eight_field.gd")
const OUT := "res://docs/qa/2026-09-19-manual/115-hillside-fill-stages/"
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var d: Dictionary = FileAccess.open(OUT+"smooth.bin",FileAccess.READ).get_var()
	var water := TerrainWorldTuning.make_water(2697992464)
	var plan := TerrainWorldTuning.make_heightfield(2697992464,water)
	var first := Vector2i((d.base/24.0).floor())-Vector2i.ONE*2
	var last := Vector2i(((d.base+Vector2(d.size-1,d.rows-1)*6.0)/24.0).ceil())+Vector2i.ONE*2
	var region := plan.compute_rect_region(Rect2i(first,last-first+Vector2i.ONE))
	var points: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-19-manual/114-hillside-surface-joins/candidate-samples.json"))
	var reports: Array[Dictionary] = []
	for field in [WaterField,EIGHT]:
		var variant := "four" if field==WaterField else "eight"
		var levels: PackedFloat32Array = d.levels.duplicate()
		field._reconcile_connected_surface(levels,d.ground,d.size,6.0)
		field._support_wet_cliff_crests(region,d.base,levels,d.ground,d.size,6.0)
		var dry_banks: PackedFloat32Array = d.rivers.duplicate()
		for i in levels.size():
			if is_finite(levels[i]):dry_banks[i]=-INF
		var fine: Dictionary = field._build_sub_lattice_rescue(region,d.base,levels,dry_banks,d.size)
		FileAccess.open(OUT+variant+"-fine.bin",FileAccess.WRITE).store_var(fine)
		FileAccess.open(OUT+variant+"-coarse.bin",FileAccess.WRITE).store_var(levels)
		# Project the frozen full-source arrays to the ordinary chunk window.
		var base := Vector2(-6,-4)*192.0-Vector2.ONE*WaterField.FILL_MARGIN*6.0
		var n := WaterField.FILL_M+1
		var sn := WaterField.FILL_SUB_M+1
		var full_sn: int = (d.size-1)*2+1
		var offset := Vector2i(((base-d.base)/6.0).round())
		var local := PackedFloat32Array();local.resize(n*n)
		var sub := PackedFloat32Array();sub.resize(sn*sn)
		var ground := PackedFloat32Array();ground.resize(sn*sn)
		for z in n:
			for x in n:local[z*n+x]=levels[(z+offset.y)*int(d.size)+x+offset.x]
		for z in sn:
			for x in sn:
				var index: int = (z+offset.y*2)*full_sn+x+offset.x*2
				sub[z*sn+x]=fine.levels[index]
				ground[z*sn+x]=fine.ground[index]
		var c := {"fill_base":base,"fill":{"levels":local,"sub_levels":sub,"sub_ground":ground},"region":region}
		var rows: Array[Dictionary] = []
		for row: Dictionary in points:
			var p := Vector2(row.point[0],row.point[1])
			rows.append({"index":row.index,"point":row.point,"level":field.level_at(c,p),"coarse":field._fill_bilinear_coarse(c,p)})
		reports.append({"variant":variant,"samples":rows})
		print("FROZEN_FILL_REPLAY ",variant)
	FileAccess.open(OUT+"replay.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	quit()
