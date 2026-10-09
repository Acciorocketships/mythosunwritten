extends RefCounted

# Compare both independently solved fields on every loaded shared chunk edge.
func run(review: Node) -> void:
	var rows: Array = []
	for chunk: Vector2i in review._inputs:
		for axis: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			var other := chunk + axis
			if not review._inputs.has(other): continue
			var a: WaterFieldContext = review._inputs[chunk].water
			var b: WaterFieldContext = review._inputs[other].water
			var origin := Vector2(other) * 192.0
			var tangent := Vector2(0, 1) if axis.x else Vector2(1, 0)
			var mismatch := 0
			var worst := 0.0
			var worst_at := Vector2.ZERO
			var wet := 0
			for i in 385:
				var p := origin + tangent * (float(i) * 0.5)
				var ya := a.level_at(p)
				var yb := b.level_at(p)
				if not is_finite(ya) and not is_finite(yb): continue
				wet += 1
				if is_finite(ya) != is_finite(yb): mismatch += 1
				elif absf(ya - yb) > worst:
					worst = absf(ya - yb)
					worst_at = p
			rows.append({"a":str(chunk),"b":str(other),"wet":wet,"wet_mismatch":mismatch,"height_difference":worst,"at":str(worst_at)})
	print("WATER_SEAMS ", JSON.stringify(rows))
	FileAccess.open(review._output_dir + "/water-seams.json", FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
