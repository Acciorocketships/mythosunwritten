extends GutTest


class Indexed:
	extends "res://scripts/terrain/field/CliffSlopeField.gd"

	func _find_rocks() -> void:
		pass


class FullScan:
	extends Indexed

	func _continued(s: Dictionary, point: Vector2, end: int) -> bool:
		var outward: Vector2 = (s.t as Vector2) * (-1.0 if end == 0 else 1.0)
		for o: Dictionary in _primitives:
			if o == s or absf(float(o.base) - float(s.base)) > .5:
				continue
			if o.arc:
				# The arc starts where the arm ends.
				for n: Vector2 in [o.n1, o.n2]:
					if ((o.c as Vector2) + n * float(o.r)).distance_to(point) < .3:
						return true
				continue
			var along := (point - (o.a as Vector2)).dot(o.t)
			var across := absf((point - (o.a as Vector2)).dot(o.n))
			if across > .3:
				continue
			var parallel := absf((o.t as Vector2).dot(s.t)) > .99
			if parallel:
				# A collinear run continuing past this end.
				var beyond := point + outward * .3
				var b := (beyond - (o.a as Vector2)).dot(o.t)
				if b >= -.01 and b <= float(o.length) + .01:
					return true
			elif along >= -.3 and along <= float(o.length) + .3:
				return true
		return false


func test_spatial_end_detection_matches_full_scan() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 261009
	var errors := []
	var checked := 0
	for trial in 8:
		var walls: Array = []
		for k in 80:
			var p := Vector2(rng.randi_range(-8, 8), rng.randi_range(-8, 8)) * 6.0
			var tangent := Vector2.RIGHT if k % 2 == 0 else Vector2.DOWN
			var normal := Vector2(tangent.y, -tangent.x)
			var base := float(k % 4) * .25
			var wall := Indexed.straight_wall(
				p, p + tangent * float(rng.randi_range(1, 4)) * 6.0, normal, base + 4.0, base
			)
			wall.top.y += rng.randf_range(-2, 2)
			walls.append(wall)
		var reference := FullScan.new(walls, trial)
		var indexed := Indexed.new(walls, trial)
		for index in reference._primitives.size():
			for key in ["free_a", "free_b"]:
				checked += 1
				if reference._primitives[index].get(key) != indexed._primitives[index].get(key):
					errors.append([trial, index, key])
	assert_eq(errors, [], "every open/continued endpoint agrees with the original exhaustive scan")
	assert_gt(checked, 4000)
