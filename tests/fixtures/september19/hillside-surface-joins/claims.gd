extends SceneTree
## Compare seed ownership on frozen native profiles; this is a diagnosis only.
const OUT := "res://docs/qa/2026-09-19-manual/114-hillside-surface-joins/"
func _initialize() -> void:
	var segments: Array = FileAccess.open(OUT+"segments.bin",FileAccess.READ).get_var()
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"diagnosis.json"))
	var rows: Array[Dictionary] = []
	for group: String in ["samples","lattice"]:
		for sample: Dictionary in report[group]:
			var p := Vector2(sample.point[0],sample.point[1])
			var claims: Array[Dictionary] = []
			for s: Dictionary in segments:
				var ab: Vector2 = s.b-s.a
				var t := clampf((p-s.a).dot(ab)/maxf(ab.length_squared(),.000001),0,1)
				var width := lerpf(s.wa,s.wb,t)
				var distance := p.distance_to(s.a+ab*t)
				if distance>width: continue
				claims.append({"source":s.source,"station":s.station,"dense":s.dense,"distance":distance,"width":width,"margin":distance-width,"fraction":distance/maxf(width,.001),"level":lerpf(s.la,s.lb,t),"a":[s.a.x,s.a.y],"b":[s.b.x,s.b.y]})
			var row := sample.duplicate()
			row.erase("claimants")
			row["group"] = group
			for metric: String in ["margin","fraction","distance"]:
				claims.sort_custom(func(a,b): return a[metric]<b[metric] if absf(a[metric]-b[metric])>.0001 else a.level<b.level)
				row[metric]=claims.slice(0,4)
			rows.append(row)
	FileAccess.open(OUT+"claims.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print("FROZEN_CLAIMS ",rows.size()," samples")
	quit()
