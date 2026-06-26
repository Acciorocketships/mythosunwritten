# scripts/terrain/field/DecorationScatter.gd
# Pure deterministic per-cell foliage scatter. No scene access — returns data only.
class_name DecorationScatter
extends RefCounted

const TILE := 24.0
const HALF := 12.0
const MAX_CANDIDATES := 9
# Per-candidate base spawn probability, scaled by biome density. Tuned for a sparse,
# natural scatter (~1 decoration per cell at typical density ~1.0) rather than the
# dense thicket a higher value produces.
const FILL_PER_CANDIDATE := 0.09
# Mirrors TerrainSpawnConfig.FOLIAGE_TAG_WEIGHTS minus the socket-only "hill".
const TAG_WEIGHTS := {"grass": 0.3, "rock": 0.2, "bush": 0.2, "tree": 0.25}

static func cell_decorations(cell: Vector2i, world_seed: int, surface_y: float) -> Array:
	var out: Array = []
	var world := Vector3(float(cell.x) * TILE, 0.0, float(cell.y) * TILE)
	var density: float = Helper.biome_foliage_density(world, world_seed)   # ~0.7..2.x
	for i in MAX_CANDIDATES:
		var h: float = Helper._cell_hash01(world_seed + 1000 + i, cell.x, cell.y)
		# Probability this candidate exists scales with biome density.
		if h > clampf(density * FILL_PER_CANDIDATE, 0.0, 1.0):
			continue
		var hx: float = Helper._cell_hash01(world_seed + 2000 + i, cell.x, cell.y)
		var hz: float = Helper._cell_hash01(world_seed + 3000 + i, cell.x, cell.y)
		var hy: float = Helper._cell_hash01(world_seed + 4000 + i, cell.x, cell.y)
		var ht: float = Helper._cell_hash01(world_seed + 5000 + i, cell.x, cell.y)
		var raw_x := world.x + (hx - 0.5) * TILE * 0.9
		var raw_z := world.z + (hz - 0.5) * TILE * 0.9
		var pos := Vector3(
			clampf(raw_x - world.x, -HALF, HALF) + world.x,
			surface_y,
			clampf(raw_z - world.z, -HALF, HALF) + world.z
		)
		out.append({
			"tag": _pick_tag(ht),
			"pos": pos,
			"yaw": hy * TAU,
		})
	return out

static func _pick_tag(roll: float) -> String:
	var total := 0.0
	for w: float in TAG_WEIGHTS.values():
		total += w
	var acc := 0.0
	for tag: String in TAG_WEIGHTS:
		acc += TAG_WEIGHTS[tag] / total
		if roll <= acc:
			return tag
	return "grass"
