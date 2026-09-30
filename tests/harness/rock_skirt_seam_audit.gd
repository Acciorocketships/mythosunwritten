extends SceneTree
## Compares every slope-rock skirt vertex with the surface it covers, on the
## native inputs of chunk (1,4) (seed 2697992464): whether the rendered slope
## solid or the terrain is the visible surface there, and for sheet-covered
## vertices the solid's own normal, rock exposure and moss grade at the nearest
## solid vertex. Rim vertices must match exactly (no outline, no seam).
##   Godot --headless --path . -s res://tests/harness/rock_skirt_seam_audit.gd
const SEED := 2697992464
const STYLE = preload("res://scripts/terrain/field/CliffRockStyle.gd")
const ROCK_DRESSING = preload("res://scripts/terrain/field/CliffRockDressing.gd")
const SLOPE_FIELD = preload("res://scripts/terrain/field/CliffSlopeField.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	STYLE.apply("sheet_bedrock")
	var water_plan := TerrainWorldTuning.make_water(SEED)
	var plan := TerrainWorldTuning.make_heightfield(SEED, water_plan)
	var fields := WorldFieldBlockCache.new(plan, water_plan, 26.0, 4.0)
	var chunk := Vector2i(1, 4)
	var region := fields.region(chunk)
	var water := fields.water(chunk)
	ROCK_DRESSING.prepare()
	# Rebuild the same slope field CliffRockDressing.compute builds.
	var owned: Rect2 = ROCK_DRESSING.owned_rect(chunk)
	var walls := TerrainTileField.wall_segments(region, owned.grow(ROCK_DRESSING.WALL_HALO))
	var slope = SLOPE_FIELD.new(walls, SEED, region, owned, null, water)
	var solid: Dictionary = slope.solid(owned)[0]
	var plain_roots: Dictionary = solid.native_roots.duplicate()
	var plain_top: float = solid.top
	var stats_top_same := false
	var cells := {}
	for p: Vector3 in plain_roots:
		var key := Vector2i(floori(p.x / .5), floori(p.z / .5))
		cells[key] = cells.get(key, []) + [p]
	slope.add_skirts(solid, owned)
	stats_top_same = is_equal_approx(plain_top, solid.top)
	var stats := {"rim_sheet": 0, "rim_terrain": 0, "rim_sheet_no_solid": 0, "normal_err_max": 0.0,
		"grade_err_max": 0.0, "exposure_err_max": 0.0, "rim_solid_gap_max": 0.0}
	var errors: Array[float] = []
	for rock: Dictionary in slope.skirts():
		if not owned.has_point(rock.bunch):
			continue
		var sk: Dictionary = slope.skirts()[rock]
		var vertices: PackedVector3Array = sk.vertices
		var sheet_vertices := {}
		for i: int in sk.sheet_indices:
			sheet_vertices[i] = true
		for i in range(vertices.size() - RockSkirt.SIDES, vertices.size()):
			if not sheet_vertices.has(i):
				stats.rim_terrain += 1
				continue
			var v := vertices[i]
			if not owned.grow(-1.0).has_point(Vector2(v.x, v.z)):
				continue
			stats.rim_sheet += 1
			var best := Vector3.INF
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					for p: Vector3 in cells.get(Vector2i(floori(v.x / .5) + dx, floori(v.z / .5) + dz), []):
						if (plain_roots[p][0] as Vector3).y > 0.3 and p.distance_to(v) < best.distance_to(v):
							best = p
			if best == Vector3.INF or best.distance_to(v) > 0.6:
				stats.rim_sheet_no_solid += 1
				continue
			var root: Array = plain_roots[best]
			var mine: Array = solid.native_roots[v]
			var err := rad_to_deg((root[0] as Vector3).angle_to(mine[0]))
			stats.normal_err_max = maxf(stats.normal_err_max, err)
			errors.append(err)
			var solid_grade := maxf(1.0 - (root[0] as Vector3).y, float(root[2]) if root.size() > 2 else 0.0)
			var my_grade := maxf(1.0 - (mine[0] as Vector3).y, float(mine[2]))
			stats.grade_err_max = maxf(stats.grade_err_max, absf(solid_grade - my_grade))
			stats.exposure_err_max = maxf(stats.exposure_err_max, absf(float(root[1]) - float(mine[1])))
			stats.rim_solid_gap_max = maxf(stats.rim_solid_gap_max, absf(best.y - v.y))
	stats["moss_scale_top_shared"] = stats_top_same
	errors.sort()
	if not errors.is_empty():
		stats["normal_err_p50"] = errors[errors.size() / 2]
		stats["normal_err_p90"] = errors[errors.size() * 9 / 10]
	print("[skirt_seam] ", JSON.stringify(stats))
	quit()
