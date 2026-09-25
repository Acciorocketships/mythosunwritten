extends SceneTree
const WIDTH=preload("res://tests/helpers/cliff_tread_width.gd")
func _init() -> void:
	var crags = load("res://scripts/terrain/field/CliffRockCrags.gd")
	var index := 0
	for entry: Array in FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin", FileAccess.READ).get_var():
		var rock: Dictionary = crags.make(entry[0], entry[1], entry[2], 2697992464, null, entry[3], entry[4])[0]
		var left := INF; var right := -INF
		for point: Vector3 in rock.faces: left = minf(left, point.x); right = maxf(right, point.x)
		var parents: Array[int] = []; var edges := {}; var broad := {}; var shared := {}; var pts := {}
		var widths := WIDTH.at_vertices(rock.green)
		for i in rock.green.size() / 3: parents.append(i)
		for i in parents.size():
			for j in 3:
				var a: Vector3 = rock.green[i * 3 + j]; var b: Vector3 = rock.green[i * 3 + (j + 1) % 3]
				var key: Array = [a, b] if a < b else [b, a]
				if edges.has(key): parents[_root(parents, i)] = _root(parents, edges[key])
				else: edges[key] = i
		for i in parents.size():
			var root := _root(parents, i)
			if WIDTH.triangle(rock.green, i * 3, widths) >= .55: broad[root] = true
			for point: Vector3 in [rock.green[i * 3], rock.green[i * 3 + 1], rock.green[i * 3 + 2]]:
				if absf(point.x - left) < .001 or absf(point.x - right) < .001: shared[root] = true
				if not pts.has(root): pts[root] = []
				pts[root].append(point)
		for root in pts:
			if not shared.has(root) and not broad.has(root):
				print("ISLAND form=%d entry=%s width=%s tris=%d pts=%s" % [index, entry[0].origin, entry[1], pts[root].size() / 3, pts[root].slice(0, 6)])
		index += 1
	quit()
func _root(parents: Array[int], i: int) -> int:
	while parents[i] != i: i = parents[i]
	return i
