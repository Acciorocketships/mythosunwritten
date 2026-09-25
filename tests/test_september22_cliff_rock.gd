extends GutTest
## Owner report (September 22): river and town cliffs stayed bare KayKit walls.
## A bank formation stands on the water surface instead of the channel bed.
const ROCKS:=preload("res://scripts/terrain/field/CliffRockDressing.gd")
const CORNER:=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
const SEED:=2697992464


class Channel extends WaterFieldContext:
	## Flat water level beyond z_front (outside the wall), dry behind it.
	var level := 0.0
	var z_front := 11.5
	func has_sources() -> bool: return true
	func covers(_point: Vector2) -> bool: return true
	func coverage() -> Rect2: return Rect2(Vector2(-1000, -1000), Vector2(2000, 2000))
	func level_at(point: Vector2) -> float: return level if point.y > z_front else NAN
	func is_wet(point: Vector2) -> bool: return point.y > z_front


func _walls(storeys: int) -> Array:
	var out := []
	for x in range(-4, 4):
		for y in storeys:
			out.append(Transform3D(Basis.IDENTITY, Vector3(x * 3 + 1.5, y * 4, 10.5)))
	return out


func test_river_wall_is_dressed_above_its_waterline() -> void:
	ROCKS.prepare()
	var water := Channel.new()
	water.level = 5.0
	var dry := ROCKS.formations(_walls(4), SEED)
	var bank := ROCKS.formations(_walls(4), SEED, null, null, water)
	assert_eq(bank.size(), dry.size(), "Every dry face is also dressed beside water")
	for rock: Dictionary in bank:
		assert_almost_eq(float(rock.transform.origin.y), water.level - ROCKS.WATERLINE_DEPTH, .001,
			"The formation stands on its waterline, not on the channel bed")
		assert_gt(float(rock.base), water.level - ROCKS.WATERLINE_DEPTH - .5)
		assert_false(ROCKS._wet_formation(rock, water), "Admitted bank rock never fills the channel")
		for i in range(0, rock.green.size(), 3):
			var lowest: float = (rock.transform * rock.green[i]).y
			assert_gt(lowest, water.level, "Turf never grows below the water surface")


func test_flooded_walls_stay_bare() -> void:
	ROCKS.prepare()
	var water := Channel.new()
	water.level = 14.5
	assert_eq(ROCKS.formations(_walls(4), SEED, null, null, water).size(), 0,
		"Less than a useful face above water receives no formation")


func test_bank_corners_stand_on_their_waterline() -> void:
	ROCKS.prepare()
	var water := Channel.new()
	water.level = 5.0
	water.z_front = -100.0
	for inner: bool in [false, true]:
		var forms := CORNER.formations([Transform3D.IDENTITY, Transform3D(Basis.IDENTITY, Vector3(0, 4, 0)),
			Transform3D(Basis.IDENTITY, Vector3(0, 8, 0))], SEED, null, null, inner, water)
		assert_eq(forms.size(), 1)
		if forms.is_empty():
			continue
		assert_almost_eq(float(forms[0].transform.origin.y), water.level - ROCKS.WATERLINE_DEPTH, .001)
		assert_false(ROCKS._wet_formation(forms[0], water))


const CRAGS:=preload("res://scripts/terrain/field/CliffRockCrags.gd")


func test_town_district_envelope_does_not_strip_cliff_rock() -> void:
	# Owner report: the cliff beside a town stayed bare. The warren's whole-town
	# bounding rectangle is a vegetation envelope, not construction.
	ROCKS.prepare()
	var walls := _walls(3)
	var envelope := FeatureGroundShape.axis_rect(Rect2(Vector2(-100, 11.5), Vector2(200, 100)))
	envelope.envelope = true
	var district := FeatureContext.new(Rect2(Vector2(-1000, -1000), Vector2(2000, 2000)),
		FeatureGroundField.new([], [envelope], 0.0), EnvironmentInstancePayload.new())
	assert_eq(ROCKS.formations(walls, SEED, null, district).size(), ROCKS.formations(walls, SEED).size())
	var lot := FeatureGroundShape.axis_rect(Rect2(Vector2(-100, 16.0), Vector2(200, 100)))
	var reserved := FeatureContext.new(Rect2(Vector2(-1000, -1000), Vector2(2000, 2000)),
		FeatureGroundField.new([], [lot], 0.0), EnvironmentInstancePayload.new())
	var fitted := ROCKS.formations(walls, SEED, null, reserved)
	assert_eq(fitted.size(), ROCKS.formations(walls, SEED).size(), "A lot in front shortens rock instead of removing it")
	for rock: Dictionary in fitted:
		assert_lt(float(rock.bounds.end.z), 16.0 - .3 + .01, "Fitted rock stays out of the reserved lot")


func test_terrace_sections_taper_into_the_wall() -> void:
	# Owner report (Amber Heath): ledges ended in sheer steps where a baked
	# Nature-rock section began at full depth within one sample column.
	CRAGS.prepare()
	for sections: Array in CRAGS._nature_fields:
		for section: PackedFloat32Array in sections:
			for i in section.size() - 1:
				assert_lte(absf(section[i + 1] - section[i]), CRAGS.SECTION_EDGE_SLOPE + .00001)


func test_reported_amber_ledges_have_no_lateral_step() -> void:
	CRAGS.prepare()
	var width := 21.0
	var form: Dictionary = CRAGS.make(Transform3D(Basis.IDENTITY, Vector3(-457.5, 32, -253.5)), width, 8, SEED, null, false, true)[0]
	var buckets := {}
	for i in range(0, form.faces.size(), 3):
		var p: Vector3 = form.faces[i]; var q: Vector3 = form.faces[i + 1]; var r: Vector3 = form.faces[i + 2]
		var x := (p.x + q.x + r.x) / 3.0
		if minf(p.z, minf(q.z, r.z)) < .3 or absf(x) > width * .5 - 2.6:
			continue
		var n := (r - p).cross(q - p)
		if n.length() < 1e-5 or absf(n.normalized().x) < .8:
			continue
		buckets[snappedf(x, .25)] = buckets.get(snappedf(x, .25), 0.0) + n.length() * .5
	var worst := 0.0
	for value: float in buckets.values():
		worst = maxf(worst, value)
	assert_lt(worst, .9, "A tread never ends in a sheer lateral step inside one formation")


func test_ledge_competition_is_independent_of_order() -> void:
	var cuts := [[1.0, 2.0, 1.0, .1], [1.4, .3, 2.0, .2], [2.1, 1.5, 3.0, 0.0], [5.0, 1.0, 1.0, .1]]
	var forward := cuts.duplicate(true)
	var reverse := cuts.duplicate(true); reverse.reverse()
	CRAGS._merge_close_ledges(forward)
	CRAGS._merge_close_ledges(reverse)
	reverse.reverse()
	for i in cuts.size():
		for property in 4:
			assert_almost_eq(float(forward[i][property]), float(reverse[i][property]), .00001,
				"Merging is independent of evaluation order")


func test_outer_corner_feet_do_not_pool() -> void:
	# Owner report: convex corners spread round "honey" feet. The arms carried
	# 6-9 m feet around a 3-4 m turn; both now stay near the turn's reach.
	for seed_value: int in [SEED, 17, 91]:
		var form: Dictionary = CORNER.make(Transform3D(Basis.IDENTITY, Vector3(-445.5, 20, 490.5)), 16, seed_value)
		var arm := 0.0
		for p: Vector3 in form.faces:
			if p.y > .6:
				continue
			if p.x < -1.5 and p.x > -4.5:
				arm = maxf(arm, p.z)
			if p.z < -1.5 and p.z > -4.5:
				arm = maxf(arm, p.x)
		assert_lt(arm, 5.5, "Corner arms keep a bounded foot")
