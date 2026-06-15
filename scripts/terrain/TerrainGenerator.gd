extends Node3D

## Player feet rest at y=0.5 (top of ground tile). Tiles whose top exceeds
## feet_y + max_step are unclimbable and must not spawn at the player origin.
const PLAYER_FEET_Y: float = 0.5
const PLAYER_MAX_STEP_HEIGHT: float = 0.5

# Generation reaches RENDER_RANGE; the visible world is RENDER_RANGE -
# REVEAL_MARGIN (the outer band generates hidden, then reveals settled).
@export var RENDER_RANGE: int = 260
@export var MAX_LOAD_PER_STEP: int = 8
## Queue-priority penalty (in distance units) for decoration-capable sockets.
const DECO_PRIORITY_PENALTY: float = 48.0

@export var player: Node3D
@export var terrain_parent: Node

var generation_rules: TerrainGenerationRuleLibrary
var library: TerrainModuleLibrary
var test_pieces_library: TerrainModuleLibrary
# Seed for deterministic per-position probability rolls (see add_piece_to_queue).
# Drawn in _ready() so a seed() call before setup yields a reproducible world.
var world_seed: int = 0
var terrain_index: TerrainIndex
var socket_index: PositionIndex
var queue: PriorityQueue
var queued_socket_keys: Dictionary = {}
var _tracked_queue_ref: PriorityQueue = null
var _deferred_sockets: Array = []
var _deferred_socket_keys: Dictionary = {}
var _last_player_pos: Vector3 = Vector3(INF, INF, INF)
var _pending_rule_rechecks: Array = []
var _pending_recheck_ids: Dictionary = {}
# Set by add_piece when a placement was rejected because the player stands in
# its footprint; _process_socket re-defers such sockets instead of consuming.
var _blocked_by_player: bool = false
# Set by _defer_if_out_of_range so load_terrain can exclude near-free deferral
# pops from its placement-attempt budget.
var _last_pop_deferred: bool = false
# Cooldown (frame number) before re-attempting sockets whose placement was
# rejected because the player stood in the footprint.
var _player_blocked_retry_at: Dictionary = {}


func _ready() -> void:
	world_seed = randi()
	library = TerrainModuleLibrary.new()
	library.init()

	test_pieces_library = TerrainModuleLibrary.new()
	test_pieces_library.init_test_pieces()

	socket_index = PositionIndex.new()
	terrain_index = TerrainIndex.new()
	generation_rules = TerrainGenerationRuleLibrary.new()

	var start_tile := load_start_tile()
	queue = PriorityQueue.new()
	queued_socket_keys.clear()
	_tracked_queue_ref = queue
	# Register the start tile in indices so collision checks work and adjacency can be detected
	# Sockets are indexed so they can act as adjacency barriers.
	register_piece(start_tile, "")
	add_piece_to_queue(start_tile)

func _process(_delta: float) -> void:
	load_terrain()

func load_terrain() -> void:
	_ensure_queue_tracking_current()
	# Orphan cleanup runs unconditionally — even in the early-return path below.
	# Removals can happen *after* the last queue-processing frame (e.g. a cliff
	# placement near the edge removes level tiles whose stacks then need to
	# cascade-cleanup over several frames). If we only purged when there was
	# in-range queue work, orphaned towers would persist visually forever once
	# the local terrain finished generating. Cost is O(stacks), small in
	# practice and capped by RENDER_RANGE.
	_purge_orphaned_stacks()
	# Reveal frontier tiles that have settled (frontier advanced past them) so
	# the player never sees edge tiles retiling/morphing in the distance.
	_reveal_settled_pieces()
	# A teleported (or void-stranded) player may sit beyond the frontier with
	# no socket in range at all — generation must re-seed beneath them.
	_ensure_seed_under_player()
	# Queue priorities are distances at ENQUEUE time, so they go stale: a
	# socket enqueued when the player was near keeps its small priority after
	# the player leaves, sits on top of the heap out of range, and starves
	# in-range work behind it (pending decorations around a player who just
	# stopped — they were enqueued at ~frontier distance, priority ~300, and
	# lose to every fresh frontier socket while running). When the player is
	# stationary, spend the frame's pop budget repairing stale tops: re-enqueue
	# each at its actual distance until an in-range socket surfaces (fall
	# through to the normal pass) or the top's PRIORITY already exceeds the
	# worst-case in-range value (then nothing can be in range — the cheap idle
	# exit, now trustworthy because priorities are honest).
	var current_player_pos: Vector3 = player.global_position if player != null else Vector3.ZERO
	if current_player_pos == _last_player_pos and not queue.is_empty():
		var repairs: int = 0
		while not queue.is_empty():
			var top_priority: float = float(queue.heap[0].get("priority", INF))
			if top_priority > RENDER_RANGE + DECO_PRIORITY_PENALTY:
				return  # honest priorities say nothing is in range
			var top_item: Variant = queue.peek()
			if not (top_item is TerrainModuleSocket):
				break
			var top_socket: TerrainModuleSocket = top_item
			var top_dist: float = get_dist_from_player(top_socket.piece, top_socket.socket_name)
			if top_dist <= RENDER_RANGE:
				break  # real in-range work — run the normal pass below
			queue.pop()
			_mark_socket_dequeued(top_socket)
			if _socket_can_spawn_point(top_socket.piece, top_socket.socket_name):
				top_dist += DECO_PRIORITY_PENALTY
			_enqueue_socket(top_socket, top_dist)
			repairs += 1
			if repairs >= MAX_LOAD_PER_STEP * 4:
				return
	_last_player_pos = current_player_pos
	var num_added: int = 0
	var num_attempts: int = 0
	var num_pops: int = 0
	_deferred_sockets.clear()
	_deferred_socket_keys.clear()

	# Placements are capped at MAX_LOAD_PER_STEP; real placement attempts get
	# a wider budget; out-of-range deferrals are nearly free (a distance check
	# and a re-stage) and get a generous separate cap. Deferrals must NOT
	# consume the attempt budget — when the heap's lowest priorities are stale
	# out-of-range entries, counting them starves placement entirely for many
	# frames and the pending work then lands all at once (a visible lag spike
	# with everything popping in together).
	while (
		num_added < MAX_LOAD_PER_STEP
		and num_attempts < MAX_LOAD_PER_STEP * 4
		and num_pops < MAX_LOAD_PER_STEP * 8
		and !queue.is_empty()
	):
		var piece_socket = queue.pop()
		if piece_socket == null:
			break
		_mark_socket_dequeued(piece_socket)
		var piece: TerrainModuleInstance = piece_socket.piece
		var socket_name: String = piece_socket.socket_name
		var distance := get_dist_from_player(piece, socket_name)

		num_pops += 1
		_last_pop_deferred = false

		var added: bool = _process_socket(piece_socket, distance)
		if added:
			num_added += 1
		if not _last_pop_deferred:
			num_attempts += 1
	_flush_deferred_sockets()


## Generation grows as a contiguous wavefront from the start tile, so a
## player teleported (or otherwise displaced) beyond frontier+RENDER_RANGE
## has no queued socket in range and would hang over the void forever. When
## no base tile exists under the player, seed a fresh ground tile at their
## grid position — it expands like the start tile and merges seamlessly with
## the main wavefront (same 24-grid), and the rules pipeline swaps it for
## water if the field says so.
func _ensure_seed_under_player() -> void:
	if player == null or library == null:
		return
	var p: Vector3 = player.global_position
	var center: Vector3 = Vector3(snappedf(p.x, 24.0), 0.0, snappedf(p.z, 24.0))
	# Any piece occupying the cell means terrain reached here — only seed
	# into genuine void.
	var probe: AABB = AABB(center + Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 3.0, 2.0))
	for hit in terrain_index.query_box(probe):
		if hit is TerrainModuleInstance:
			return
	var ground_modules: TerrainModuleList = library.get_by_tags(TagList.new(["ground-plain"]))
	if ground_modules.is_empty():
		return
	var seed_tile: TerrainModuleInstance = ground_modules.library[0].spawn()
	seed_tile.set_transform(Transform3D(Basis.IDENTITY, center))
	seed_tile.create()
	terrain_parent.add_child(seed_tile.root)
	register_piece(seed_tile, "")
	add_piece_to_queue(seed_tile)
	# Run the rules so a seed on a water-field position becomes water, banks
	# pre-tile, etc. — same treatment as any placed base tile.
	_run_rules_for_existing_piece(seed_tile)
	_process_rule_rechecks()


## Delete any stack tile (level-stack or cliff-stack) whose support tile
## (directly below) no longer satisfies its support invariant:
##   - level-stack: support must be a level-center tile (full interior: all
##     cardinals AND diagonals — a stack on an inner-corner support would
##     overhang its notch).
##   - cliff-stack: support must be a cliff-interior tile.
## Runs once per load_terrain() call so stacks whose support changed between
## rule evaluations are cleaned up even when no rule trigger fires nearby.
func _purge_orphaned_stacks() -> void:
	var to_remove: Array[TerrainModuleInstance] = []
	for module in terrain_index.all_modules.keys():
		if not (module is TerrainModuleInstance):
			continue
		var piece: TerrainModuleInstance = module
		if piece.def.tags.has("level-stack"):
			# 0.6u window = one level tier (0.5 thick + epsilon). Any wider and
			# a stack with the tier directly below missing would find the next
			# tier down as "support" — that's the cantilever bug.
			if not _has_valid_stack_support(piece, "level", 0.6, "level-center"):
				to_remove.append(piece)
		elif piece.def.tags.has("cliff-stack"):
			if not _has_valid_stack_support(piece, "cliff", 5.0, "cliff-interior"):
				to_remove.append(piece)
	# Hills and decorations whose surface vanished (e.g. the base of a hill
	# stack removed by a bank conversion, leaving the upper hills and their
	# grass floating) have no rule that re-checks them — probe their support
	# directly. The probe is a spatial query per piece, so it runs as a
	# rotating slice (a batch-every-N version was a one-frame hitch).
	if _support_sweep_pieces.is_empty():
		_support_sweep_pieces = terrain_index.all_modules.keys()
	var sweep_budget: int = 64
	while sweep_budget > 0 and not _support_sweep_pieces.is_empty():
		sweep_budget -= 1
		var swept: Variant = _support_sweep_pieces.pop_back()
		if not (swept is TerrainModuleInstance):
			continue
		var swept_piece: TerrainModuleInstance = swept
		if not terrain_index.all_modules.has(swept_piece):
			continue  # removed since the slice was snapshotted
		if not (swept_piece.def.tags.has("hill") or swept_piece.def.displaceable):
			continue
		if not _has_surface_support(swept_piece):
			to_remove.append(swept_piece)
	for piece in to_remove:
		_recheck_neighbors_after_removal(piece)
		remove_piece(piece)
	if not to_remove.is_empty():
		_process_rule_rechecks()


var _support_sweep_pieces: Array = []


# Whether anything solid sits directly under this piece's origin: a piece
# whose AABB intersects a thin probe just below the origin. Hills and
# decorations attach their bottom socket to the support's top surface, so the
# support's AABB always reaches the origin plane.
func _has_surface_support(piece: TerrainModuleInstance) -> bool:
	# Probe a thin slab spanning the piece's footprint from just below its
	# AABB bottom (where it rests) down a tile-ish depth. A fixed offset from
	# the ORIGIN was wrong for pieces whose origin sits well above their base
	# (e.g. an 8x8x2 hill origin is ~1.5u above the ground it stands on), and
	# falsely reported those as unsupported the frame they spawned.
	var aabb: AABB = piece.aabb
	var bottom_y: float = aabb.position.y
	var cx: float = aabb.position.x + aabb.size.x * 0.5
	var cz: float = aabb.position.z + aabb.size.z * 0.5
	var probe: AABB = AABB(
		Vector3(cx - 0.4, bottom_y - 1.0, cz - 0.4),
		Vector3(0.8, 1.1, 0.8)
	)
	for hit in terrain_index.query_box(probe):
		if hit is TerrainModuleInstance and hit != piece and not hit.def.displaceable:
			return true
	return false


# Returns true if `piece` has a valid stack support directly below: a
# `family_tag`-tagged tile within `search_dy` units down that also carries
# `support_tag` ("level-center" / "cliff-interior"). The variant tags encode
# the support's neighbourhood, and the rules keep them consistent, so a tag
# check is the full support invariant.
func _has_valid_stack_support(
	piece: TerrainModuleInstance,
	family_tag: String,
	search_dy: float,
	support_tag: String
) -> bool:
	var piece_y: float = piece.transform.origin.y
	var query_box: AABB = AABB(
		Vector3(
			piece.transform.origin.x - 0.5,
			piece_y - search_dy,
			piece.transform.origin.z - 0.5,
		),
		Vector3(1.0, search_dy - 0.1, 1.0)
	)
	for c in terrain_index.query_box(query_box):
		if not (c is TerrainModuleInstance):
			continue
		var other: TerrainModuleInstance = c
		if other == piece:
			continue
		if not other.def.tags.has(family_tag):
			continue
		if not other.def.tags.has(support_tag):
			continue
		var dy: float = piece_y - other.transform.origin.y
		if dy <= 0.1:
			continue
		return true
	return false


func _process_socket(piece_socket: TerrainModuleSocket, distance: float) -> bool:
	if piece_socket.piece.root == null or piece_socket.piece.sockets.is_empty():
		return false
	if _is_socket_connected(piece_socket):
		return false
	if _defer_if_out_of_range(piece_socket, distance):
		return false
	if not _is_socket_expandable(piece_socket):
		return false

	# Sockets recently rejected because the player stood in their footprint
	# wait out a cooldown before re-attempting: every attempt instantiates a
	# candidate scene just to destroy it on failure, so retrying each frame
	# while the player stands still burns the whole frame budget.
	var blocked_key: String = _socket_queue_key(piece_socket)
	if _player_blocked_retry_at.get(blocked_key, 0) > Engine.get_process_frames():
		_stage_deferred_socket(piece_socket, distance)
		_last_pop_deferred = true
		return false

	var size: String = _sample_socket_size(piece_socket.piece, piece_socket.socket_name)
	var placement_context: Dictionary = _resolve_placement_context(piece_socket, size)
	var placed: bool = _try_place_with_rules(piece_socket, placement_context)
	if not placed and _blocked_by_player:
		# The player is standing where this piece would land. Retry once they
		# have moved instead of permanently consuming the socket (which would
		# leave a bare patch everywhere the player happened to stand).
		_player_blocked_retry_at[blocked_key] = Engine.get_process_frames() + 90
		_stage_deferred_socket(piece_socket, distance)
	elif _player_blocked_retry_at.has(blocked_key):
		_player_blocked_retry_at.erase(blocked_key)
	return placed


func _is_socket_connected(piece_socket: TerrainModuleSocket) -> bool:
	var existing_sockets: Array[TerrainModuleSocket] = socket_index.query_others(
		piece_socket.get_socket_position(),
		piece_socket.piece
	)
	for existing_socket in existing_sockets:
		if _is_socket_expandable(existing_socket):
			return true
	return false


func _defer_if_out_of_range(piece_socket: TerrainModuleSocket, distance: float) -> bool:
	if distance <= RENDER_RANGE:
		return false
	_stage_deferred_socket(piece_socket, distance)
	_last_pop_deferred = true
	return true


func _sample_socket_size(piece: TerrainModuleInstance, socket_name: String) -> String:
	if not piece.def.socket_size.has(socket_name):
		return "point"
	var size_prob_dist: Distribution = piece.def.socket_size[socket_name]
	var socket: Marker3D = piece.sockets.get(socket_name, null)
	if socket != null and piece.root != null:
		var pos: Vector3 = Helper.socket_world_pos(piece.transform, socket, piece.root)
		size_prob_dist = _biome_scaled_dist(size_prob_dist, pos)
	return size_prob_dist.sample()


# Re-weight a tag/size distribution by the biome multipliers at `pos`. Tags
# absent from the weights table keep their authored probability; the result is
# renormalised. Both the size roll and the tag roll for the same socket pass
# through this with the same weights, so they stay consistent (e.g. the
# "24x24x4" size entry and the "cliff-base-side" tag entry carry the same
# rocky-biome multiplier).
func _biome_scaled_dist(dist: Distribution, pos: Vector3) -> Distribution:
	if dist == null or dist.is_empty() or dist.dist.size() < 2:
		return dist  # single-entry distributions renormalise to themselves
	var weights: Dictionary[String, float] = Helper.biome_weights(pos, world_seed)
	# Contour cores pin the structure seed mix to cliffs: a level patch
	# seeded inside the mesa footprint would just be eaten by it later
	# (visible appear-then-disappear churn). Zeroing the level entries makes
	# multi-entry topcenter distributions sample cliffs exclusively; the
	# single-entry lateral dists (which share the "24x24x0.5" size tag) are
	# untouched because single-entry distributions skip scaling entirely.
	if _in_cliff_core(pos):
		var boost: float = TerrainModuleDefinitions.CLIFF_CORE_SEED_MIX_BOOST
		weights["cliff-base-side"] = weights.get("cliff-base-side", 1.0) * boost
		weights["24x24x4"] = weights.get("24x24x4", 1.0) * boost
		# Drop (not zero) the level/flat-ground entries: a level seeded inside
		# a mesa footprint is eaten by it later (visible churn). Zeroing leaves
		# a 0-weight key that sample_from_modules can strand — if the surviving
		# cliff tag filters to no modules it removes it and is left with the
		# unsamplable zero key (Distribution.sample asserts). Erasing avoids
		# that entirely.
		weights["level-ground-center"] = 0.0
		weights["24x24x0.5"] = 0.0
		# Hills are tall structures; one placed inside a core (on ground that
		# becomes cliff, or on a plateau that gains another storey) is eaten by
		# the rising mesa. Drop the hill SIZES from foliage/stacking rolls so
		# only point decorations (trees, grass, rocks — the intended mountain
		# vegetation) survive on plateau tops. "point" always remains in those
		# dists, so this never nulls them.
		weights["8x8x2"] = 0.0
		weights["12x12x2"] = 0.0
		weights["4x4x4"] = 0.0
	var scaled: Distribution = dist.copy()
	var changed: bool = false
	for tag in scaled.dist.keys():
		if not weights.has(tag):
			continue
		changed = true
		var w: float = weights[tag]
		if w <= 0.0:
			scaled.dist.erase(tag)
		else:
			scaled.dist[tag] *= w
	if not changed:
		return dist
	# Scaling must never null a distribution (sample() asserts on an empty or
	# zero-sum dist). A dist consisting only of fully-suppressed tags has
	# nothing else to pick, so honour the original weights rather than crash.
	if scaled.dist.is_empty():
		return dist
	scaled.normalise()
	return scaled


func _get_socket_fill_prob(piece: TerrainModuleInstance, socket_name: String) -> float:
	if not piece.def.socket_fill_prob.has(socket_name):
		return 0.0
	var fill_prob: Variant = piece.def.socket_fill_prob[socket_name]
	if fill_prob == null:
		return 0.0
	if fill_prob is float:
		return fill_prob
	if fill_prob is int:
		return fill_prob
	return 0.0


func _is_socket_expandable(piece_socket: TerrainModuleSocket) -> bool:
	return _get_socket_fill_prob(piece_socket.piece, piece_socket.socket_name) > 0.0


# Fill probability modulated by the macro density field: probabilistic sockets
# fire more in dense regions (mountain ranges, groves) and rarely in open
# meadows, so features form coherent bounded clusters. The curve concentrates
# the field into rare strong cores (~m^5): features grow aggressively inside a
# core and die out quickly past its edge, which is what bounds cluster size.
# Structural sockets (fill >= 1.0, e.g. ground lateral expansion) ignore the
# field — ground must always fill for the world to be infinite.
func _effective_fill_prob(piece: TerrainModuleInstance, socket_name: String, pos: Vector3) -> float:
	return _route_fill_prob(piece, socket_name, pos, _get_socket_fill_prob(piece, socket_name))


# Scale a raw probability the way the given socket's actual verdict is
# computed. Shared by the enqueue roll (_effective_fill_prob) and the
# suppression roll (_suppressor_roll_passes) so suppression always mirrors the
# suppressor socket's real verdict — a mismatch either suppresses foliage that
# nothing will ever displace, or lets foliage spawn where a structure is
# coming (visible pop-out).
func _route_fill_prob(
	piece: TerrainModuleInstance, socket_name: String, pos: Vector3, fill: float
) -> float:
	if fill <= 0.0:
		return 0.0
	if fill < 1.0:
		# Cliff plateaus are carved from the macro field as contour lines
		# (solid mesas, per-storey taper) — see CLIFF_CONTOUR_BASE.
		if _is_cliff_lateral(piece, socket_name):
			return _cliff_contour_fill(piece, pos)
		# Decoration-capable sockets follow the biome flora density (forests
		# dense, meadows open) on EVERY walkable surface — ground, level, and
		# cliff tops share the same deco spawn rules. Checked before the
		# level branch so level foliage doesn't fall into the structural
		# curve below. Decorations (and stacked hills) on a NON-cliff surface
		# inside a cliff contour core are doomed — the mesa rises over the
		# base ground/hill and visibly displaces them — so they never spawn;
		# the mesa's own plateau foliage replaces them. Cliff plateau tops are
		# exempt (the final surface, not something the mesa eats), so foliage
		# still decorates mountains.
		if _socket_can_spawn_point(piece, socket_name):
			if _in_cliff_core(pos) and not piece.def.tags.has("cliff"):
				return 0.0
			return clampf(fill * Helper.biome_foliage_density(pos, world_seed), 0.0, 1.0)
		# Level patches are the mid-altitude feature: the high-contrast macro
		# curve that keeps cliffs out of the lowlands would crush their
		# growth at the mid densities where they live, so level-family
		# sockets and the ground topcenter seed keep the gentler legacy
		# curve (lone cliff crags seeded outside cores are bounded anyway —
		# the contour test stops their lateral growth immediately). Level
		# growth into a contour core is doomed for the same reason as deco.
		if piece.def.tags.has("level"):
			if _in_cliff_core(pos):
				return 0.0
			return _level_scaled_fill(fill, pos)
		if socket_name == "topcenter" and piece.def.tags.has("ground-plain"):
			var seed_fill: float = _gentle_scaled_fill(fill, pos)
			# Inside a contour core, seed eagerly so the core reliably grows
			# its mountain (mesa fill is idempotent — extra seeds merge).
			if _in_cliff_core(pos):
				return maxf(seed_fill, TerrainModuleDefinitions.CLIFF_CORE_SEED_FILL_PROB)
			return seed_fill
	return _macro_scaled_fill(fill, pos)


# The original macro curve: moderate contrast, alive at mid densities. Used
# for level patches and ground-topcenter seeds; cliff plateau growth uses the
# contour test and everything else the high-contrast _macro_scaled_fill.
func _gentle_scaled_fill(fill: float, pos: Vector3) -> float:
	var macro: float = Helper.macro_density01(pos, world_seed)
	return clampf(fill * (0.25 + 2.2 * pow(macro, 3.0)), 0.0, 1.0)


# Flatter curve for level GROWTH (laterals + stacking on existing levels):
# levels are a common mid-altitude terrace feature and should populate the
# meadows the player crosses, not only mid-density bands. A generous floor
# (0.5) lets a seeded level patch spread even where macro is low, while the
# 0.33 authored lateral stays subcritical so patches still bound themselves.
# Only applied once a level exists (the ground topcenter seed keeps the gentle
# curve, so lone meadow cliffs stay rare).
func _level_scaled_fill(fill: float, pos: Vector3) -> float:
	var macro: float = Helper.macro_density01(pos, world_seed)
	return clampf(fill * (0.5 + 0.9 * macro), 0.0, 1.0)


func _in_cliff_core(pos: Vector3) -> bool:
	return (
		Helper.macro_density01(pos, world_seed)
		>= TerrainModuleDefinitions.CLIFF_CONTOUR_BASE
	)


func _is_cliff_lateral(piece: TerrainModuleInstance, socket_name: String) -> bool:
	if not (socket_name == "front" or socket_name == "back"
			or socket_name == "left" or socket_name == "right"):
		return false
	return piece.def.tags.has("cliff")


# Contour test for cliff plateau growth: expand iff the macro density at the
# target position clears this storey's threshold.
func _cliff_contour_fill(piece: TerrainModuleInstance, pos: Vector3) -> float:
	if Helper.macro_density01(pos, world_seed) >= _cliff_storey_threshold(piece):
		return 1.0
	return 0.0


# Cliff origins sit on the storey top plane (base tier y = 4.0: ground
# topcenter at y = 0 plus one 4u storey), so the storey index falls out of
# the origin height.
func _cliff_storey_threshold(piece: TerrainModuleInstance) -> float:
	var storey: float = maxf(0.0, (piece.transform.origin.y - 4.0) / 4.0)
	return (
		TerrainModuleDefinitions.CLIFF_CONTOUR_BASE
		+ TerrainModuleDefinitions.CLIFF_CONTOUR_STEP * storey
	)


# Foliage on a cliff tile is pointless when the tile is destined to become a
# plateau interior: the next storey lands on it and displaces the foliage
# (visible pop-out). Interior-ness is deterministic for contour-carved mesas —
# the tile and all 8 neighbours inside this storey's contour — so cliff
# foliage is suppressed geometrically instead of by probability roll.
func _cliff_foliage_covered_by_stack(
	piece: TerrainModuleInstance, socket_name: String
) -> bool:
	if not piece.def.tags.has("cliff"):
		return false
	if not _socket_can_spawn_point(piece, socket_name):
		return false
	var threshold: float = _cliff_storey_threshold(piece)
	var origin: Vector3 = piece.transform.origin
	for dx in [-24.0, 0.0, 24.0]:
		for dz in [-24.0, 0.0, 24.0]:
			var neighbor: Vector3 = origin + Vector3(dx, 0.0, dz)
			if Helper.macro_density01(neighbor, world_seed) < threshold:
				return false
	return true


func _macro_scaled_fill(fill: float, pos: Vector3) -> float:
	if fill >= 1.0:
		return fill
	var macro: float = Helper.macro_density01(pos, world_seed)
	# High-contrast curve: lateral cluster growth (cliff 0.42, level 0.3) must
	# cross criticality (~1/3 effective) only INSIDE range cores. Cores then
	# fill into solid mesas — whose interior tiles enable vertical stacking —
	# while mid-density terrain stays subcritical instead of sprawling into
	# single-storey snake mazes.
	var factor: float = 0.15 + 3.2 * pow(macro, 3.2)
	return clampf(fill * factor, 0.0, 1.0)


func _is_socket_blocking(piece_socket: TerrainModuleSocket) -> bool:
	if piece_socket == null or piece_socket.piece == null or piece_socket.piece.def == null:
		return false
	var socket_name: String = piece_socket.socket_name
	var fill_probs: Dictionary = piece_socket.piece.def.socket_fill_prob
	if not fill_probs.has(socket_name):
		return false
	var fill_prob: Variant = fill_probs[socket_name]
	if fill_prob == null:
		return false
	return _get_socket_fill_prob(piece_socket.piece, socket_name) <= 0.0


func _resolve_placement_context(piece_socket: TerrainModuleSocket, size: String) -> Dictionary:
	var socket_name: String = piece_socket.socket_name
	var adjacent: Dictionary[String, TerrainModuleSocket] = get_adjacent_from_size(piece_socket, size)
	var attachment_socket_name: String = Helper.get_attachment_socket_name(socket_name)
	var origin_world: Vector3 = piece_socket.get_socket_position()

	if _has_forbidden_adjacency(adjacent):
		return _empty_placement_context(size, adjacent, attachment_socket_name, origin_world)

	# `socket_required` entries are unprefixed raw tags, so rotating the adjacency
	# would yield identical `required_tags` on every iteration. One pass is enough.
	var required_tags: TagList = library.get_required_tags(adjacent)
	required_tags.append(size)
	var filtered: TerrainModuleList = library.get_by_tags(required_tags)
	if filtered.is_empty():
		return _empty_placement_context(size, adjacent, attachment_socket_name, origin_world)

	return {
		"size": size,
		"adjacent": adjacent,
		"attachment_socket_name": attachment_socket_name,
		"required_tags": required_tags,
		"filtered": filtered,
		"dist": _biome_scaled_dist(library.get_combined_distribution(adjacent).copy(), origin_world),
		"origin_world": origin_world
	}


func _empty_placement_context(
	size: String,
	adjacent: Dictionary[String, TerrainModuleSocket],
	attachment_socket_name: String,
	origin_world: Vector3
) -> Dictionary:
	return {
		"size": size,
		"adjacent": adjacent,
		"attachment_socket_name": attachment_socket_name,
		"required_tags": TagList.new(),
		"filtered": TerrainModuleList.new(),
		"dist": Distribution.new(),
		"origin_world": origin_world
	}


func _has_forbidden_adjacency(adjacent: Dictionary[String, TerrainModuleSocket]) -> bool:
	for hit in adjacent.values():
		if hit == null:
			continue
		if _is_socket_blocking(hit):
			return true
	return false


func _try_place_with_rules(orig_piece_socket: TerrainModuleSocket, placement_context: Dictionary) -> bool:
	var filtered: TerrainModuleList = placement_context.get("filtered", TerrainModuleList.new())
	var dist: Distribution = placement_context.get("dist", Distribution.new())
	var attachment_socket_name: String = placement_context.get("attachment_socket_name", "bottom")
	if filtered.is_empty():
		return false
	var chosen_template: TerrainModule = library.sample_from_modules(filtered, dist)
	var chosen: TerrainModuleInstance = chosen_template.spawn()
	chosen.create()
	var new_piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(chosen, attachment_socket_name)
	if add_piece(new_piece_socket, orig_piece_socket):
		_apply_rules_after_placement(chosen, orig_piece_socket, placement_context, filtered)
		return true
	chosen.destroy()
	return false


func _build_rule_context(
	orig_piece_socket: TerrainModuleSocket,
	placement_context: Dictionary,
	chosen_piece: TerrainModuleInstance,
	filtered: TerrainModuleList
) -> Dictionary:
	return {
		"size": placement_context.get("size", "point"),
		"required_tags": placement_context.get("required_tags", TagList.new()),
		"socket_name": orig_piece_socket.socket_name,
		"adjacent": placement_context.get("adjacent", {}),
		"chosen_piece": chosen_piece,
		"filtered": filtered,
		"origin_world": placement_context.get("origin_world", orig_piece_socket.get_socket_position()),
		"terrain_index": terrain_index,
		"socket_index": socket_index,
		"queue": queue,
		"library": library,
		"rules_instance": generation_rules,
		"world_seed": world_seed
	}


func _apply_rules_after_placement(
	placed_piece: TerrainModuleInstance,
	orig_piece_socket: TerrainModuleSocket,
	placement_context: Dictionary,
	filtered: TerrainModuleList
) -> void:
	var context: Dictionary = _build_rule_context(orig_piece_socket, placement_context, placed_piece, filtered)
	_run_rules_on_piece(placed_piece, context)
	_process_rule_rechecks()


func _run_rules_on_piece(piece: TerrainModuleInstance, context: Dictionary) -> void:
	var current_piece: TerrainModuleInstance = piece
	context["adjacent"] = get_adjacent(current_piece)
	for rule in generation_rules.rules:
		context["chosen_piece"] = current_piece
		if not rule.matches(context):
			continue
		var step_result: Dictionary = rule.apply(context)
		if step_result.get("skip", false):
			return
		var updated_piece: Variant = step_result.get("chosen_piece", current_piece)
		var step_updates: Dictionary = step_result.get("piece_updates", {})
		if updated_piece == null:
			# Rule decided the placement is invalid (e.g. an unsupported level
			# stack, or a stuck cliff). Apply any sibling updates, remove the
			# piece, and stop running further rules for this placement.
			_apply_piece_updates_after_placement(step_updates, null)
			_recheck_neighbors_after_removal(current_piece)
			remove_piece(current_piece)
			return
		if updated_piece is TerrainModuleInstance and updated_piece != current_piece:
			_replace_piece(current_piece, updated_piece)
			current_piece = updated_piece
			context["adjacent"] = get_adjacent(current_piece)
		_apply_piece_updates_after_placement(step_updates, current_piece)
		for socket_to_queue in step_result.get("sockets_for_queue", []):
			var socket_dist: float = get_dist_from_player(
				socket_to_queue.piece, socket_to_queue.socket_name
			)
			_enqueue_socket(socket_to_queue, socket_dist)


## Re-run the rule pipeline for a piece that is already part of the terrain.
## Used after removals that bypass placement (replace_existing, orphan purges)
## so neighbouring tiles' edge variants stay consistent with the new occupancy.
func _run_rules_for_existing_piece(piece: TerrainModuleInstance) -> void:
	if piece == null or piece.root == null or piece.root.get_parent() != terrain_parent:
		return
	var context: Dictionary = {
		"size": "",
		"required_tags": TagList.new(),
		"socket_name": "",
		"adjacent": {},
		"chosen_piece": piece,
		"filtered": TerrainModuleList.new(),
		"origin_world": piece.transform.origin,
		"terrain_index": terrain_index,
		"socket_index": socket_index,
		"queue": queue,
		"library": library,
		"rules_instance": generation_rules,
		"world_seed": world_seed
	}
	_run_rules_on_piece(piece, context)


## Schedule every piece adjacent to a removed piece for a rule re-run. The
## variants of edge tiles encode neighbour occupancy, so any removal that
## happens outside the placement pipeline must trigger a reclassification of
## its neighbourhood or stale variants (and stale interiors) persist forever.
func _recheck_neighbors_after_removal(piece: TerrainModuleInstance) -> void:
	if piece == null or piece.def == null or piece.def.displaceable:
		return
	for hit in terrain_index.query_box(piece.aabb.grow(1.0)):
		if not (hit is TerrainModuleInstance) or hit == piece:
			continue
		var hit_id: int = hit.get_instance_id()
		if _pending_recheck_ids.has(hit_id):
			continue
		_pending_recheck_ids[hit_id] = true
		_pending_rule_rechecks.append(hit)


func _process_rule_rechecks() -> void:
	while not _pending_rule_rechecks.is_empty():
		var piece: TerrainModuleInstance = _pending_rule_rechecks.pop_front()
		_pending_recheck_ids.erase(piece.get_instance_id())
		_run_rules_for_existing_piece(piece)


func _apply_piece_updates_after_placement(piece_updates: Dictionary, placed_piece: TerrainModuleInstance) -> void:
	for from_piece in piece_updates.keys():
		var to_piece: Variant = piece_updates[from_piece]
		if from_piece == placed_piece:
			continue
		if not (from_piece is TerrainModuleInstance):
			continue
		var existing_piece: TerrainModuleInstance = from_piece
		var is_registered_piece: bool = existing_piece.root != null and existing_piece.root.get_parent() == terrain_parent
		if not is_registered_piece:
			# The target was already removed/replaced in this pass; destroy the
			# orphan replacement or its instantiated scene (physics bodies and
			# all) leaks.
			if to_piece is TerrainModuleInstance and to_piece != from_piece:
				to_piece.destroy()
			continue
		if to_piece == from_piece:
			continue
		if to_piece == null:
			_recheck_neighbors_after_removal(existing_piece)
			remove_piece(existing_piece)
			continue
		if not (to_piece is TerrainModuleInstance):
			continue
		_replace_piece(existing_piece, to_piece)


func _replace_piece(old_piece: TerrainModuleInstance, new_piece: TerrainModuleInstance) -> void:
	if old_piece == null or new_piece == null:
		return
	remove_piece(old_piece)
	terrain_parent.add_child(new_piece.root)
	register_piece(new_piece, "")
	add_piece_to_queue(new_piece)


func get_dist_from_player(piece: TerrainModuleInstance, socket_name: String) -> float:
	var socket: Marker3D = piece.sockets.get(socket_name, null)
	if socket == null or piece.root == null:
		return INF
	var socket_world_pos := Helper.socket_world_pos(piece.transform, socket, piece.root)
	var player_pos := player.global_position
	player_pos[1] = -1.0
	return (socket_world_pos - player_pos).length()


func add_piece_to_queue(piece: TerrainModuleInstance) -> void:
	_ensure_queue_tracking_current()
	for socket_name: String in piece.sockets.keys():
		var current_socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
		if not _is_socket_expandable(current_socket):
			continue
		var socket: Marker3D = piece.sockets[socket_name]
		var pos := Helper.socket_world_pos(piece.transform, socket, piece.root)
		# Sparsity roll happens at enqueue time, so the queue only ever holds
		# sockets that will actually expand once in range. The roll is a
		# deterministic hash of the socket's world position: piece retiles
		# (rule replacements) re-derive the same verdict instead of getting a
		# fresh roll, otherwise frontier sockets would be re-rolled on every
		# neighbour retile and any fill probability would ratchet toward 1.
		if Helper.position_hash01(pos, world_seed) > _effective_fill_prob(piece, socket_name, pos):
			continue
		# Suppression: don't enqueue a socket whose suppressor (e.g. topcenter
		# seeding a structure on this tile) is going to fire — its placement
		# would visibly displace whatever this socket spawns.
		if _suppressor_roll_passes(piece, piece.def.socket_suppressed_by.get(socket_name)):
			continue
		# Cliff foliage is suppressed geometrically: a tile whose whole
		# neighbourhood is inside this storey's contour will retile to
		# interior and be covered by the next storey.
		if _cliff_foliage_covered_by_stack(piece, socket_name):
			continue
		var existing_socket: TerrainModuleSocket = socket_index.query_other(pos, piece)
		if existing_socket != null and _is_socket_expandable(existing_socket):
			continue
		var dist := get_dist_from_player(piece, socket_name)
		# Decoration-capable sockets (size dist includes "point") are processed
		# a couple of tiles later than structural work at the same distance, so
		# decorations don't appear and then get displaced moments later by
		# lateral growth arriving from a neighbouring tile.
		if _socket_can_spawn_point(piece, socket_name):
			dist += DECO_PRIORITY_PENALTY
		_enqueue_socket(current_socket, dist)


func _socket_can_spawn_point(piece: TerrainModuleInstance, socket_name: String) -> bool:
	var size_dist: Distribution = piece.def.socket_size.get(socket_name, null)
	if size_dist == null:
		return true  # sockets without a size dist default to "point"
	return size_dist.dist.has("point")


# Whether a suppression entry ({"socket": name, "prob": float}) fires: the
# suppressor socket's deterministic position roll passes at the authored
# probability, scaled exactly the way that socket's own enqueue verdict would
# be (_route_fill_prob) — same position hash, same curve — so suppression
# fires precisely where the suppressor socket actually fires.
func _suppressor_roll_passes(piece: TerrainModuleInstance, entry: Variant) -> bool:
	if not (entry is Dictionary):
		return false
	var suppressor_name: String = String(entry.get("socket", ""))
	var socket: Marker3D = piece.sockets.get(suppressor_name, null)
	if socket == null:
		return false
	var pos := Helper.socket_world_pos(piece.transform, socket, piece.root)
	var prob: float = float(entry.get("prob", 0.0))
	return Helper.position_hash01(pos, world_seed) <= _route_fill_prob(piece, suppressor_name, pos, prob)


func register_piece(piece: TerrainModuleInstance, _attachment_socket_name: String) -> void:
	# Index every socket. The attachment socket must be indexed too — otherwise a query
	# from the parent piece's matching socket position finds only its own socket and
	# falsely concludes the side has no neighbor, which causes LevelEdgeRule to choose
	# the wrong variant for the parent (treating an attached neighbor as missing).
	for socket_name: String in piece.sockets.keys():
		var piece_other_socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, socket_name)
		socket_index.insert(piece_other_socket)
	terrain_index.insert(piece)
	_apply_initial_visibility(piece)


# Edge tiles retile (swap variant) as their neighbours fill in — visible
# "appearing and disappearing in the distance" if shown while still settling.
# A tile is "done" once the frontier has advanced ~REVEAL_MARGIN past it (all
# immediate neighbours placed, so its variant is final). So pieces placed in
# the actively-generating band near RENDER_RANGE start hidden and are revealed
# — already settled, no morph — once the player is close enough.
const REVEAL_MARGIN: float = 88.0

func _reveal_radius() -> float:
	return float(RENDER_RANGE) - REVEAL_MARGIN

func _apply_initial_visibility(piece: TerrainModuleInstance) -> void:
	if piece == null or piece.root == null:
		return
	if _player_xz_distance(piece) > _reveal_radius():
		piece.root.visible = false
		if not _hidden_set.has(piece):
			_hidden_set[piece] = true
			_hidden_pieces.append(piece)

func _player_xz_distance(piece: TerrainModuleInstance) -> float:
	var pp: Vector3 = player.global_position if player != null else Vector3.ZERO
	var o: Vector3 = piece.transform.origin
	return Vector2(o.x - pp.x, o.z - pp.z).length()

func _reveal_settled_pieces() -> void:
	if _hidden_pieces.is_empty():
		return
	var radius: float = _reveal_radius()
	var still_hidden: Array = []
	for piece in _hidden_pieces:
		if piece == null or piece.root == null or not is_instance_valid(piece.root):
			continue  # removed/replaced while hidden — drop it
		if _player_xz_distance(piece) <= radius:
			piece.root.visible = true
		else:
			still_hidden.append(piece)
	_hidden_pieces = still_hidden
	_hidden_set.clear()
	for piece in _hidden_pieces:
		_hidden_set[piece] = true

var _hidden_pieces: Array = []
var _hidden_set: Dictionary = {}


func can_place(new_piece: TerrainModuleInstance, parent_piece: TerrainModuleInstance) -> bool:
	assert(new_piece.def != null)
	if new_piece.def.tags.has("ground"):
		return true
	if new_piece.def.replace_existing:
		return true
	var other_pieces: Array = terrain_index.query_box(new_piece.aabb)
	if parent_piece != null:
		other_pieces.erase(parent_piece)

	# Displaceable decorations never block structure (they get removed on
	# placement instead), but they DO block other decorations — otherwise a
	# retiled tile re-enqueues its foliage sockets and stacks duplicate
	# decorations at the same spot.
	var new_is_displaceable: bool = new_piece.def.displaceable
	other_pieces = other_pieces.filter(
		func(p): return not p.def.tags.has("ground") 			and not (p.def.displaceable and not new_is_displaceable)
	)

	if new_piece.def.tags.has("level") and parent_piece != null and parent_piece.def.tags.has("level"):
		# Only filter out level tiles that are strictly *below* the new piece (the support layer).
		# Using parent_y with `<=` here was wrong for lateral expansion (where new.y == parent.y):
		# it also removed same-y level tiles from the blocker set, allowing the new tile to overlap
		# an existing level tile at the same x/y/z when LEVEL_REPLACE_EXISTING is false.
		var new_y: float = new_piece.transform.origin.y
		other_pieces = other_pieces.filter(func(p):
			return not (p.def.tags.has("level") and p.transform.origin.y < new_y - 0.1)
		)

	return other_pieces.is_empty()


## Collect all pieces stacked above `piece` via topcenter socket-links, recursively.
## A piece P is "on top of" Q when P has a socket at Q's topcenter world position
## AND P's origin.y is strictly above Q's origin.y. Populates `out_set` (keyed by
## instance_id) and returns `out_list` in bottom-up removal order.
func _collect_stacked_above(
	piece: TerrainModuleInstance,
	out_set: Dictionary,
	out_list: Array
) -> void:
	if not piece.sockets.has("topcenter"):
		return
	var topcenter_socket: TerrainModuleSocket = TerrainModuleSocket.new(piece, "topcenter")
	var topcenter_pos: Vector3 = topcenter_socket.get_socket_position()
	var piece_y: float = piece.transform.origin.y
	var candidates: Array[TerrainModuleSocket] = socket_index.query_others(topcenter_pos, piece)
	for candidate_socket in candidates:
		if candidate_socket == null or candidate_socket.piece == null:
			continue
		var stacked: TerrainModuleInstance = candidate_socket.piece
		# Only remove pieces strictly above (structural dependency, not coincidental same-level).
		if stacked.transform.origin.y <= piece_y:
			continue
		var stacked_id: int = stacked.get_instance_id()
		if out_set.has(stacked_id):
			continue
		out_set[stacked_id] = true
		# Recurse depth-first so the deepest dependent is queued for removal first.
		_collect_stacked_above(stacked, out_set, out_list)
		out_list.append(stacked)


func remove_piece(piece: TerrainModuleInstance) -> void:
	_ensure_queue_tracking_current()
	var piece_deferred_keys: Dictionary = {}
	for socket_name in piece.sockets.keys():
		var deferred_key: String = _socket_queue_key_from_parts(piece, socket_name)
		piece_deferred_keys[deferred_key] = true
	var kept_deferred: Array = []
	for entry in _deferred_sockets:
		var deferred_socket: TerrainModuleSocket = entry.get("socket", null)
		var deferred_key: String = _socket_queue_key(deferred_socket)
		if piece_deferred_keys.has(deferred_key):
			continue
		kept_deferred.append(entry)
	_deferred_sockets = kept_deferred
	for deferred_key in piece_deferred_keys.keys():
		if _deferred_socket_keys.has(deferred_key):
			_deferred_socket_keys.erase(deferred_key)
	terrain_index.remove(piece)
	socket_index.remove_piece(piece)
	queue.remove_where(func(item): return item is TerrainModuleSocket and item.piece == piece)
	for socket_name in piece.sockets.keys():
		var queued_key: String = _socket_queue_key_from_parts(piece, socket_name)
		if queued_socket_keys.has(queued_key):
			queued_socket_keys.erase(queued_key)
	if piece.root and piece.root.get_parent() == terrain_parent:
		terrain_parent.remove_child(piece.root)
		piece.root.queue_free()


func get_adjacent(piece: TerrainModuleInstance) -> Dictionary[String, TerrainModuleSocket]:
	if piece.root == null:
		return {}

	var out: Dictionary[String, TerrainModuleSocket] = {}
	for socket_name: String in piece.sockets.keys():
		var s: Marker3D = piece.sockets[socket_name]
		var pos := Helper.socket_world_pos(piece.transform, s, piece.root)

		var hit := socket_index.query_other(pos, piece)
		if hit != null:
			out[socket_name] = hit
	return out


func get_adjacent_from_size(
	orig_piece_socket: TerrainModuleSocket,
	size: String
) -> Dictionary[String, TerrainModuleSocket]:
	if size == "point":
		return {"bottom": orig_piece_socket}

	var orig_piece: TerrainModuleInstance = orig_piece_socket.piece
	var orig_sock: Marker3D = orig_piece_socket.socket
	assert(orig_piece.root != null)
	assert(orig_sock != null)

	# Get test piece for this size
	var test_pieces: TerrainModuleList = test_pieces_library.get_by_tags(TagList.new([size]))
	if test_pieces.is_empty():
		push_error("No test piece found for size: " + size)
		return {}

	var test_piece_template: TerrainModule = test_pieces_library.get_random(test_pieces, true)
	var test_piece: TerrainModuleInstance = test_piece_template.spawn()
	assert(test_piece != null)
	test_piece.create()

	# Determine which socket on the test piece should attach
	var attachment_socket_name: String = Helper.get_attachment_socket_name(orig_piece_socket.socket_name)
	var attachment_socket: Marker3D = test_piece.sockets.get(attachment_socket_name, null)
	if attachment_socket == null:
		push_error("Test piece does not have attachment socket: " + attachment_socket_name)
		test_piece.destroy()
		return {}

	# Position the test piece with the same direction-aware transform used for
	# real placement. A plain offset would assume the source piece is unrotated;
	# rotated pieces (e.g. level variants aligned by LevelEdgeRule) would get a
	# misplaced test piece and garbage adjacency.
	var test_piece_socket: TerrainModuleSocket = TerrainModuleSocket.new(test_piece, attachment_socket_name)
	transform_to_socket(test_piece_socket, orig_piece_socket)

	# Get initial adjacency
	var adjacency: Dictionary[String, TerrainModuleSocket] = {attachment_socket_name: orig_piece_socket}

	for socket_name: String in test_piece.sockets.keys():
		if socket_name == attachment_socket_name:
			continue

		var s: Marker3D = test_piece.sockets[socket_name]
		var pos := Helper.socket_world_pos(test_piece.transform, s, test_piece.root)
		var hit := socket_index.query_other(pos, test_piece)
		if hit != null:
			var is_hit_ground = hit.piece.def.tags.has("ground")
			if orig_piece.def.tags.has("ground") and not is_hit_ground:
				var from_top_socket: bool = orig_piece_socket.socket_name.begins_with("top")
				# Ground top sockets may spawn elevated pieces that should connect to existing non-ground tiles.
				# Keep legacy behavior for non-top ground sockets.
				if not from_top_socket:
					continue

			adjacency[socket_name] = hit

	test_piece.destroy()
	return adjacency


func transform_to_socket(new_ps: TerrainModuleSocket, orig_ps: TerrainModuleSocket) -> void:
	var orig_socket_pos: Vector3 = orig_ps.get_socket_position()
	var new_socket_pos: Vector3 = new_ps.get_socket_position()
	var orig_piece_pos: Vector3 = orig_ps.get_piece_position()
	var new_piece_pos: Vector3 = new_ps.get_piece_position()

	var new_piece: TerrainModuleInstance = new_ps.piece

	# Align in XZ only (prevent tilting) by using the actual socket direction:
	# d = (piece_center -> socket_pos) projected to XZ.
	#
	# This is more robust than choosing a face normal from an AABB, especially when sockets sit
	# on edges/corners (e.g. y=0 plane), where "nearest face" is ambiguous.
	var target2 := Vector2(orig_socket_pos.x - orig_piece_pos.x, orig_socket_pos.z - orig_piece_pos.z)
	var current2 := Vector2(new_socket_pos.x - new_piece_pos.x, new_socket_pos.z - new_piece_pos.z)

	if target2.length() > 1e-6 and current2.length() > 1e-6:
		# We want the new socket to be on the opposite side of the shared point, so the two pieces
		# sit adjacent rather than overlapping.
		var desired2 := (-target2).normalized()
		current2 = current2.normalized()
		var ang_desired := atan2(desired2.y, desired2.x)
		var ang_current := atan2(current2.y, current2.x)
		# Godot's yaw sign in XZ is opposite our atan2 convention here.
		# Flipping the sign makes +X rotate toward the intended XZ direction.
		var yaw := ang_current - ang_desired
		var rot_y := Basis(Vector3.UP, yaw)
		new_piece.set_basis(rot_y * new_piece.transform.basis)

	# Recompute socket pos after rotation
	var rotated_socket_pos := new_ps.get_socket_position()

	# Translate so sockets coincide
	var new_position: Vector3 = new_piece_pos + (orig_socket_pos - rotated_socket_pos)

	new_piece.set_position(Helper.snap_vec3(new_position))

func add_piece(
	new_piece_socket: TerrainModuleSocket,
	orig_piece_socket: TerrainModuleSocket
) -> bool:
	transform_to_socket(new_piece_socket, orig_piece_socket)

	var new_piece: TerrainModuleInstance = new_piece_socket.piece
	# Reject any non-ground piece that would overlap the player body —
	# without this check, hills / levels / cliffs / collision-bearing foliage
	# can spawn on the player and trap them. No origin-height exemption: hill
	# and level origins sit at ground height and used to slip through. The
	# footprint follows the player's height so the check also holds on
	# plateaus. Runs before replace_existing removal because can_place()
	# unconditionally allows replace_existing tiles. Rejected sockets are
	# re-deferred by _process_socket (the spawn retries after the player
	# moves away) — see _blocked_by_player.
	_blocked_by_player = false
	if player != null and not new_piece.def.tags.has("ground"):
		var player_footprint: AABB = AABB(
			Vector3(
				player.global_position.x - 0.5,
				player.global_position.y - 0.6,
				player.global_position.z - 0.5
			),
			Vector3(1.0, 3.0, 1.0)
		)
		if new_piece.aabb.intersects(player_footprint):
			_blocked_by_player = true
			return false
	if new_piece.def.replace_existing:
		# Logical AABBs (def.size) make genuine overlaps exact: a cliff covers
		# the levels in its footprint, while tiles that merely share a face
		# (e.g. the supporting storey below a cliff-stack) touch exclusively
		# and must NOT be eaten.
		var overlapping_pieces: Array = terrain_index.query_box(new_piece.aabb)
		if orig_piece_socket.piece != null:
			overlapping_pieces.erase(orig_piece_socket.piece)
		overlapping_pieces = overlapping_pieces.filter(func(p): return not p.def.tags.has("ground"))
		# Collect pieces stacked above each overlapping piece (e.g. a hill or grass on a
		# ground tile's topcenter that sits above the new piece's AABB and would be missed
		# by the query_box call). Gathered before any removal so the socket index is intact.
		var stacked_set: Dictionary = {}
		var stacked_to_remove: Array = []
		for piece in overlapping_pieces:
			stacked_set[piece.get_instance_id()] = true
		for piece in overlapping_pieces:
			_collect_stacked_above(piece, stacked_set, stacked_to_remove)
		for piece in overlapping_pieces:
			_recheck_neighbors_after_removal(piece)
			remove_piece(piece)
		for piece in stacked_to_remove:
			_recheck_neighbors_after_removal(piece)
			remove_piece(piece)

	var can_place_result := can_place(new_piece, orig_piece_socket.piece)

	if not can_place_result:
		return false

	# Decorations yield to structure: remove any displaceable piece this piece
	# now covers (can_place ignored them as blockers).
	if not new_piece.def.displaceable:
		for piece in terrain_index.query_box(new_piece.aabb):
			if piece is TerrainModuleInstance and piece.def.displaceable:
				remove_piece(piece)

	terrain_parent.add_child(new_piece.root)

	register_piece(new_piece, new_piece_socket.socket_name)
	add_piece_to_queue(new_piece)

	# Remove sockets that are now linked into from the queue
	remove_linked_sockets_from_queue(new_piece_socket)

	return true


func remove_linked_sockets_from_queue(new_piece_socket: TerrainModuleSocket) -> void:
	_ensure_queue_tracking_current()
	# Remove sockets that were linked into by the new piece from the queue
	# These are the sockets that the new piece connected to

	var new_piece: TerrainModuleInstance = new_piece_socket.piece
	var linked_sockets: Array[TerrainModuleSocket] = []
	var linked_socket_keys: Dictionary = {}

	# Find all sockets on other pieces that are at the same positions as our new piece's sockets
	for socket_name in new_piece.sockets.keys():
		var socket: Marker3D = new_piece.sockets[socket_name]
		var socket_pos := Helper.socket_world_pos(new_piece.transform, socket, new_piece.root)

		# Find any existing socket at this position (not belonging to our new piece)
		var existing_socket := socket_index.query_other(socket_pos, new_piece)
		if existing_socket != null:
			if _is_socket_expandable(existing_socket):
				linked_sockets.append(existing_socket)
				linked_socket_keys[_socket_queue_key(existing_socket)] = true

	# Remove these linked sockets from the queue
	if linked_sockets.is_empty():
		return
	queue.remove_where(
		func(item):
			if not (item is TerrainModuleSocket):
				return false
			var item_socket: TerrainModuleSocket = item
			return linked_socket_keys.has(_socket_queue_key(item_socket))
	)
	for linked_socket_key in linked_socket_keys.keys():
		if queued_socket_keys.has(linked_socket_key):
			queued_socket_keys.erase(linked_socket_key)


func load_start_tile() -> TerrainModuleInstance:
	var def : TerrainModule = TerrainModuleDefinitions.load_ground_tile()
	var initial_tile := def.spawn()
	initial_tile.set_transform(Transform3D.IDENTITY)
	var root := initial_tile.create()
	terrain_parent.add_child(root)
	return initial_tile


func _socket_queue_key(piece_socket: TerrainModuleSocket) -> String:
	if piece_socket == null:
		return ""
	return _socket_queue_key_from_parts(piece_socket.piece, piece_socket.socket_name)


func _socket_queue_key_from_parts(piece: TerrainModuleInstance, socket_name: String) -> String:
	if piece == null:
		return ""
	return str(piece.get_instance_id()) + ":" + socket_name


func _ensure_queue_tracking_current() -> void:
	if queue == null:
		queued_socket_keys.clear()
		_tracked_queue_ref = null
		return
	if queue == _tracked_queue_ref:
		return
	queued_socket_keys.clear()
	for entry in queue.heap:
		if not (entry is Dictionary):
			continue
		if not entry.has("item"):
			continue
		var item: Variant = entry["item"]
		if not (item is TerrainModuleSocket):
			continue
		var key: String = _socket_queue_key(item)
		if key == "":
			continue
		queued_socket_keys[key] = true
	_tracked_queue_ref = queue


func _mark_socket_dequeued(piece_socket: TerrainModuleSocket) -> void:
	var queue_key: String = _socket_queue_key(piece_socket)
	if queue_key == "":
		return
	if queued_socket_keys.has(queue_key):
		queued_socket_keys.erase(queue_key)


func _enqueue_socket(piece_socket: TerrainModuleSocket, distance: float) -> bool:
	_ensure_queue_tracking_current()
	var queue_key: String = _socket_queue_key(piece_socket)
	if queue_key == "":
		return false
	if queued_socket_keys.has(queue_key):
		return false
	queue.push(piece_socket, distance)
	queued_socket_keys[queue_key] = true
	return true


func _stage_deferred_socket(piece_socket: TerrainModuleSocket, distance: float) -> void:
	var queue_key: String = _socket_queue_key(piece_socket)
	if queue_key == "":
		return
	if _deferred_socket_keys.has(queue_key):
		return
	_deferred_socket_keys[queue_key] = true
	_deferred_sockets.append({"socket": piece_socket, "distance": distance})


func _flush_deferred_sockets() -> void:
	for entry in _deferred_sockets:
		var piece_socket: TerrainModuleSocket = entry.get("socket", null)
		var distance: float = float(entry.get("distance", 0.0))
		_enqueue_socket(piece_socket, distance)
	_deferred_sockets.clear()
	_deferred_socket_keys.clear()
