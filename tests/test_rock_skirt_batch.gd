extends GutTest
## RockSkirt samples its terrain in one batched kernel call per skirt
## (prefetch_corners); the skirt must be exactly the per-sample one.

const K := preload("res://scripts/native/NativeTileKernel.gd")
const Tile := preload("res://scripts/terrain/field/TerrainTileField.gd")

func _regions() -> Array:
	var water := TerrainWorldTuning.make_water(2697992464)
	var plan := TerrainWorldTuning.make_heightfield(2697992464, water)
	var region := plan.compute_region(16, 16, 12)
	var grade := TerrainGradePatch.new(&"t", {Vector2i(12, 12): 30.0, Vector2i(13, 12): 30.0}, Vector2(180, 180), 3.0)
	var listed := HeightfieldRegion.new(region._storeys, region._levels, region._carved, region.plan)
	listed.terrain_grades.append(grade)
	return [region, region.with_terrain_grades([grade]), listed]

func _centres() -> PackedVector2Array:
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var out := PackedVector2Array([Vector2(186.0, 180.0), Vector2(174.0, 186.0)])
	for k in 30:
		out.append(Vector2(rng.randf_range(110.0, 270.0), rng.randf_range(110.0, 270.0)))
	return out

func test_prefetched_corners_are_the_per_sample_kernel() -> void:
	K.setup()
	var step := TerrainChunkMesher.STEP
	for region: HeightfieldRegion in _regions():
		var points := _centres()
		var corners := {}
		RockSkirt.prefetch_corners(region, corners, points)
		var same := true
		for p: Vector2 in points:
			var owner := Vector2i(Tile.point_of(p.x, region), Tile.point_of(p.y, region))
			var x0 := floorf(p.x / step) * step
			var z0 := floorf(p.y / step) * step
			var c: PackedFloat64Array = corners[p]
			for k in 4:
				var x := x0 + (step if k & 1 else 0.0)
				var z := z0 + (step if k & 2 else 0.0)
				same = same and c[k] == Tile.surface_y_on_side(region, x, z, owner)
		assert_true(same, "each prefetched corner == surface_y_on_side on the owner's side")

func test_batched_skirt_equals_the_per_sample_skirt() -> void:
	K.setup()
	var walls := 0
	for region: HeightfieldRegion in _regions():
		for centre: Vector2 in _centres():
			var batched := RockSkirt.terrain_surface(region, 2697992464)
			var single := RockSkirt.terrain_surface(region, 2697992464)
			single.erase("prefetch")
			var radii := RockSkirt.ellipse_radii(Vector2(2.6, 1.7), Vector2(0.8, 0.6))
			var a := RockSkirt.build("a", centre, radii, 1.3, batched)
			var b := RockSkirt.build("a", centre, radii, 1.3, single)
			for key: String in ["anchor", "top", "vertices", "normals", "colors",
					"indices", "sheet_indices", "on_sheet", "collision_faces"]:
				assert_eq(a[key], b[key], "%s at %s" % [key, centre])
			var heights := PackedFloat32Array()
			for v: Vector3 in a.vertices:
				heights.append(v.y)
			if heights.size() > 0 and Array(heights).max() - Array(heights).min() > 6.0:
				walls += 1
	assert_gt(walls, 0, "some skirts straddle a storey change (owner-side sampling exercised)")

## The tint reads the 24 m lattice corners once each per skirt surface (it
## used to call ground_tint_at four times per vertex), with identical colours.
func test_skirt_tints_read_each_lattice_corner_once() -> void:
	K.setup()
	var region: HeightfieldRegion = _regions()[0]
	var tile := TerrainChunkMesher.CELL
	var calls := [0]
	var counting := func(pos: Vector3, world_seed: int) -> Color:
		calls[0] += 1
		return BiomeRegistry.ground_tint_at(pos, world_seed)
	var radii := RockSkirt.ellipse_radii(Vector2(9.0, 7.0), Vector2(0.8, 0.6))
	var centre := Vector2(190.0, 182.0)
	var surface := RockSkirt.terrain_surface(region, 2697992464, counting)
	var skirt := RockSkirt.build("a", centre, radii, 1.3, surface)
	var touched := {}
	for v: Vector3 in skirt.vertices:
		var gx := floorf(v.x / tile)
		var gz := floorf(v.z / tile)
		for c in 4:
			touched[Vector2(gx + (c & 1), gz + (c >> 1))] = true
	assert_gt(touched.size(), 4, "the skirt spans several tint cells")
	assert_lte(calls[0], touched.size(), "one ground_tint_at per lattice corner touched")
	var plain := RockSkirt.build("a", centre, radii, 1.3, RockSkirt.terrain_surface(region, 2697992464))
	assert_eq(skirt.colors, plain.colors, "memoized tints are the per-vertex ones")
