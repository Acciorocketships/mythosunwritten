class_name BiomeAtmosphereField
extends RefCounted

## CPU-only, world-aligned samples. Adjacent chunks own identical edge values.
const CHUNK := 192.0
const GRID := 13
const STEP := CHUNK / float(GRID - 1)

static func compute(chunk: Vector2i, region, world_seed: int, water: WaterFieldContext = null) -> Dictionary:
	var origin := Vector3(chunk.x * CHUNK, 0.0, chunk.y * CHUNK)
	var fog := PackedColorArray()
	var ground := PackedFloat32Array()
	var lo := INF
	var hi := -INF
	for z in GRID:
		for x in GRID:
			var pos := origin + Vector3(x * STEP, 0, z * STEP)
			var height := TerrainSurfaceField.surface_y(region, pos.x, pos.z)
			fog.append(BiomeRegistry.local_atmosphere(pos, world_seed))
			ground.append(height)
			lo = minf(lo, height)
			hi = maxf(hi, height)
	var points: Dictionary = {}
	var orbs: Array[Vector3] = []
	# Grounded particle anchors on a canonical 24m lattice, qualified separately.
	# They neither fill a chunk's bounding height band nor switch at its centre.
	for z in 8:
		for x in 8:
			var cx := chunk.x * 8 + x
			var cz := chunk.y * 8 + z
			var px := (x + lerpf(0.2, 0.8, Helper._cell_hash01(world_seed + 710, cx, cz))) * 24.0
			var pz := (z + lerpf(0.2, 0.8, Helper._cell_hash01(world_seed + 711, cx, cz))) * 24.0
			var pos := origin + Vector3(px, 0, pz)
			pos.y = TerrainSurfaceField.surface_y(region, pos.x, pos.z) + 2.5
			if water != null:
				var point := Vector2(pos.x, pos.z)
				var level := water.level_at(point)
				if is_finite(level):
					pos.y = maxf(pos.y, level + 2.5)
					var east := water.level_at(point + Vector2(3, 0))
					var north := water.level_at(point + Vector2(0, 3))
					if (is_finite(east) and absf(east - level) > 0.65) or (is_finite(north) and absf(north - level) > 0.65):
						if not points.has(&"spray"):
							points[&"spray"] = PackedVector3Array()
						points[&"spray"].append(Vector3(px, level + 0.4, pz))
			var weights := Helper.biome_weights5(pos, world_seed)
			var recipes: Dictionary = {}
			for id: StringName in weights:
				for recipe: StringName in BiomeRegistry.profile(id).particles:
					recipes[recipe] = float(recipes.get(recipe, 0.0)) + weights[id] * float(BiomeRegistry.profile(id).particles[recipe])
			for recipe: StringName in recipes:
				var roll := Helper._cell_hash01(world_seed + 730 + int(String(recipe).hash()), cx, cz)
				if roll > float(recipes[recipe]) * (0.12 if recipe == &"orbs" else 0.8):
					continue
				var local := pos - origin
				if recipe == &"orbs":
					if orbs.size() < 4:
						orbs.append(local)
				else:
					if not points.has(recipe):
						points[recipe] = PackedVector3Array()
					points[recipe].append(local)
	return {"origin": origin, "fog": fog, "ground": ground,
		"lo": lo, "hi": hi, "points": points, "orbs": orbs}
