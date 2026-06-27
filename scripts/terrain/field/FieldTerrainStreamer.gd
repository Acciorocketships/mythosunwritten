# scripts/terrain/field/FieldTerrainStreamer.gd
# Slim per-chunk streaming driver: builds field chunks within a radius of the player,
# evicts beyond a keep radius, frame-budgeted. Replaces the catalog/socket engine.
class_name FieldTerrainStreamer
extends Node3D

const CHUNK_WORLD := 192.0   # TerrainChunkMesher.CHUNK_WORLD

@export var player: Node3D
@export var terrain_parent: Node
@export var CHUNK_RADIUS: int = 3
@export var KEEP_RADIUS: int = 4
@export var MAX_BUILD_PER_FRAME: int = 1
@export var HEIGHTFIELD_AMPLITUDE: float = 56.0
@export var HEIGHTFIELD_MAX_STOREYS: int = 12
## Max storey difference between adjacent cells. 1 = all walkable slopes (SP1);
## 3 = cliffs up to 3 storeys (12m) form where the field steps down steeply.
@export var MAX_CLIFF_STEP: int = 3

var _plan: HeightfieldPlan
var _mesher: TerrainChunkMesher
var _built: Dictionary = {}        # Vector2i -> Node3D
var world_seed: int = 0

static func chunk_of(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x / CHUNK_WORLD)), int(floor(pos.z / CHUNK_WORLD)))

func desired_chunks(centre: Vector2i, radius: int) -> Array:
	var out: Array = []
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			out.append(centre + Vector2i(dx, dz))
	return out

func _ready() -> void:
	if terrain_parent == null:
		return   # bare instance (unit test)
	world_seed = randi()
	_plan = HeightfieldPlan.new(world_seed, HEIGHTFIELD_AMPLITUDE, HEIGHTFIELD_MAX_STOREYS, "mean", MAX_CLIFF_STEP)
	_mesher = TerrainChunkMesher.new()
	_mesher.set_seed(world_seed)
	# Build the chunk under the spawn point before the first physics frame, so the
	# player lands on real collision instead of falling through unbuilt space.
	if player != null:
		_ensure_chunk(chunk_of(player.global_position))

# Build chunk `c` immediately if it isn't built yet. Returns true if it built one.
func _ensure_chunk(c: Vector2i) -> bool:
	if _built.has(c):
		return false
	var node := _mesher.build_chunk(_plan, c)
	terrain_parent.add_child(node)
	_built[c] = node
	return true

func _process(_delta: float) -> void:
	if _plan == null or player == null:
		return
	var centre := chunk_of(player.global_position)
	# Always guarantee the player's own chunk exists (unbudgeted) so the player never
	# falls through when spawning or crossing into a not-yet-streamed chunk.
	_ensure_chunk(centre)
	# Build the remaining missing chunks within radius (budgeted).
	var built_this_frame := 0
	for c: Vector2i in desired_chunks(centre, CHUNK_RADIUS):
		if _ensure_chunk(c):
			built_this_frame += 1
			if built_this_frame >= MAX_BUILD_PER_FRAME:
				break
	# Evict chunks beyond keep radius (Chebyshev).
	for c: Vector2i in _built.keys():
		if maxi(absi(c.x - centre.x), absi(c.y - centre.y)) > KEEP_RADIUS:
			_built[c].queue_free()
			_built.erase(c)
