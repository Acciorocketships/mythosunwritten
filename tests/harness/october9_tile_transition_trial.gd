extends SceneTree
## Diagnostic only: construct rounded crossings inside the tile, without a
## separate raised cliff sheet. Never installed in the game or native kernel.
func _init() -> void:
	var saved: Dictionary = FileAccess.open("res://tests/fixtures/october8/dents-lattice.var", FileAccess.READ).get_var()
	var region := HeightfieldRegion.new(saved.storeys, saved.levels)
	var rows: Array = []
	for width in [0.4, 0.7, 1.0]:
		var source := preload("res://tests/harness/october9_tile_transition_kernel.gd").make(width)
		var base: Dictionary = FileAccess.open("/tmp/oct9-dent-baseline.var", FileAccess.READ).get_var()
		var surface: PackedFloat64Array = base.surface.duplicate()
		var params: Dictionary = {}
		var plain_error := 0.0
		for idx in surface.size():
			var p: Vector2 = base.origin + Vector2(idx % base.w, idx / base.w) * 0.5
			var tile := Vector2i((p / 12.0).floor())
			if not params.has(tile): params[tile] = TerrainTileField.tile_params(region, tile)
			var local := p / 12.0 - Vector2(tile)
			surface[idx] = source.eval_params(params[tile], local.x, local.y)
			if params[tile][4] + params[tile][5] + params[tile][6] + params[tile][7] == 0:
				plain_error = maxf(plain_error, absf(surface[idx] - TerrainTileField.eval_params(params[tile], local.x, local.y)))
		base.surface = surface
		var mode := "tile_%d" % roundi(width * 10)
		FileAccess.open("/tmp/oct9-dent-" + mode + ".var", FileAccess.WRITE).store_var(base)
		var worst := 0.0; var count := 0; var location := Vector2.ZERO
		for z in range(2676, 2716):
			for x in range(-658, -594):
				var p := Vector2(x, z) * 0.5
				var at := Vector2i(((p - base.origin) / 0.5).round())
				var idx: int = at.y * base.w + at.x
				for stride: int in [4, 4 * base.w]:
					var original_dip: float = maxf(0, minf(base.ground[idx-stride], base.ground[idx+stride]) - base.ground[idx])
					var dip := minf(surface[idx-stride], surface[idx+stride]) - surface[idx] - original_dip
					if dip > 0.04: count += 1
					if dip > worst: worst = dip; location = p
		var row := {"mode": mode, "plain_slope_error": plain_error, "worst_added_dip": worst, "sections_over_4cm": count, "position": str(location)}
		rows.append(row); print("TILE_TRANSITION ", JSON.stringify(row))
	FileAccess.open("/tmp/oct9-tile-transition.json", FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	quit()
