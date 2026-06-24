class_name TerrainDensity
extends RefCounted

var _world_seed: int

func _init(world_seed: int) -> void:
	_world_seed = world_seed


# Re-weight a tag/size distribution by the biome multipliers at `pos`. Tags
# absent from the weights table keep their authored probability; the result is
# renormalised. Both the size roll and the tag roll for the same socket pass
# through this with the same weights, so they stay consistent (e.g. the
# "24x24x4" size entry and the "cliff-base-side" tag entry carry the same
# rocky-biome multiplier).
func biome_scaled_dist(dist: Distribution, pos: Vector3) -> Distribution:
	if dist == null or dist.is_empty() or dist.dist.size() < 2:
		return dist  # single-entry distributions renormalise to themselves
	var weights: Dictionary[String, float] = Helper.biome_weights(pos, _world_seed)
	# Contour cores pin the structure seed mix to cliffs: a level patch
	# seeded inside the mesa footprint would just be eaten by it later
	# (visible appear-then-disappear churn). Zeroing the level entries makes
	# multi-entry topcenter distributions sample cliffs exclusively; the
	# single-entry lateral dists (which share the "24x24x0.5" size tag) are
	# untouched because single-entry distributions skip scaling entirely.
	if in_cliff_core(pos):
		var boost: float = TerrainSpawnConfig.CLIFF_CORE_SEED_MIX_BOOST
		weights[TerrainSpawnConfig.SEED_TAG_CLIFF_BASE] = weights.get(TerrainSpawnConfig.SEED_TAG_CLIFF_BASE, 1.0) * boost
		weights[TerrainSpawnConfig.SEED_SIZE_CLIFF] = weights.get(TerrainSpawnConfig.SEED_SIZE_CLIFF, 1.0) * boost
		# Drop (not zero) the level/flat-ground entries: a level seeded inside
		# a mesa footprint is eaten by it later (visible churn). Zeroing leaves
		# a 0-weight key that sample_from_modules can strand — if the surviving
		# cliff tag filters to no modules it removes it and is left with the
		# unsamplable zero key (Distribution.sample asserts). Erasing avoids
		# that entirely.
		weights[TerrainSpawnConfig.SEED_TAG_LEVEL_GROUND] = 0.0
		weights[TerrainSpawnConfig.SEED_SIZE_LEVEL] = 0.0
		# Hills are tall structures; one placed inside a core (on ground that
		# becomes cliff, or on a plateau that gains another storey) is eaten by
		# the rising mesa. Drop the hill SIZES from foliage/stacking rolls so
		# only point decorations (trees, grass, rocks — the intended mountain
		# vegetation) survive on plateau tops. "point" always remains in those
		# dists, so this never nulls them.
		for structure_size: String in TerrainSpawnConfig.STRUCTURE_SIZES:
			weights[structure_size] = 0.0
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


func get_socket_fill_prob(piece: TerrainModuleInstance, socket_name: String) -> float:
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


func is_socket_expandable(piece_socket: TerrainModuleSocket) -> bool:
	return get_socket_fill_prob(piece_socket.piece, piece_socket.socket_name) > 0.0


# Fill probability modulated by the macro density field: probabilistic sockets
# fire more in dense regions (mountain ranges, groves) and rarely in open
# meadows, so features form coherent bounded clusters. The curve concentrates
# the field into rare strong cores (~m^5): features grow aggressively inside a
# core and die out quickly past its edge, which is what bounds cluster size.
# Structural sockets (fill >= 1.0, e.g. ground lateral expansion) ignore the
# field — ground must always fill for the world to be infinite.
func effective_fill_prob(piece: TerrainModuleInstance, socket_name: String, pos: Vector3) -> float:
	if is_structural_socket(piece, socket_name):
		return 0.0
	return route_fill_prob(piece, socket_name, pos, get_socket_fill_prob(piece, socket_name))


## Returns true when the socket is listed in the module's structural_socket_names
## metadata. Structural sockets (lateral expansion and topcenter seeding on
## ground-plain, level, and cliff tiles) are suppressed here so the heightfield
## plan remains the sole structural source.
func is_structural_socket(piece: TerrainModuleInstance, socket_name: String) -> bool:
	return socket_name in piece.def.structural_socket_names


# Scale a raw probability the way the given socket's actual verdict is
# computed. Shared by the enqueue roll (effective_fill_prob) and the
# suppression roll (suppressor_roll_passes) so suppression always mirrors the
# suppressor socket's real verdict — a mismatch either suppresses foliage that
# nothing will ever displace, or lets foliage spawn where a structure is
# coming (visible pop-out).
func route_fill_prob(
	piece: TerrainModuleInstance, socket_name: String, pos: Vector3, fill: float
) -> float:
	if fill <= 0.0:
		return 0.0
	if fill < 1.0:
		# Decoration-capable sockets follow the biome flora density (forests
		# dense, meadows open) on EVERY walkable surface — ground, level, and
		# cliff tops share the same deco spawn rules. Checked before the
		# density-profile match so level foliage doesn't fall into the
		# structural curve below. Decorations (and stacked hills) on a surface
		# that does NOT grow inside cliff contour cores are doomed — the mesa
		# rises over the base ground/hill and visibly displaces them — so they
		# never spawn; the mesa's own plateau foliage replaces them. Cliff
		# plateau tops are exempt (grows_in_cliff_core = true), so foliage
		# still decorates mountains.
		if socket_can_spawn_point(piece, socket_name):
			if in_cliff_core(pos) and not piece.def.grows_in_cliff_core:
				return 0.0
			return clampf(fill * Helper.biome_foliage_density(pos, _world_seed), 0.0, 1.0)
		# Dispatch on density_profile metadata instead of tag inspection.
		# "level"  — flat curve for level-family lateral growth, core-suppressed.
		# "gentle" — legacy gentler curve for ground topcenter seeding, with
		#            cliff-core eager-seed boost (so every core grows its mountain).
		# default  — high-contrast macro curve for cliffs and everything else.
		match piece.def.density_profile:
			"level":
				# Level growth into a contour core is doomed for the same reason
				# as deco (the mesa eats the patch), so suppress it early.
				if in_cliff_core(pos):
					return 0.0
				return _level_scaled_fill(fill, pos)
			"gentle":
				var seed_fill: float = _gentle_scaled_fill(fill, pos)
				# Inside a contour core, seed eagerly so the core reliably
				# grows its mountain (mesa fill is idempotent — extra seeds merge).
				if in_cliff_core(pos):
					return maxf(seed_fill, TerrainSpawnConfig.CLIFF_CORE_SEED_FILL_PROB)
				return seed_fill
	return _macro_scaled_fill(fill, pos)


# The original macro curve: moderate contrast, alive at mid densities. Used
# for level patches and ground-topcenter seeds; cliff plateau growth uses the
# contour test and everything else the high-contrast _macro_scaled_fill.
func _gentle_scaled_fill(fill: float, pos: Vector3) -> float:
	var macro: float = Helper.macro_density01(pos, _world_seed)
	return clampf(fill * (0.25 + 2.2 * pow(macro, 3.0)), 0.0, 1.0)


# Flatter curve for level GROWTH (laterals + stacking on existing levels):
# levels are a common mid-altitude terrace feature and should populate the
# meadows the player crosses, not only mid-density bands. A generous floor
# (0.5) lets a seeded level patch spread even where macro is low, while the
# 0.33 authored lateral stays subcritical so patches still bound themselves.
# Only applied once a level exists (the ground topcenter seed keeps the gentle
# curve, so lone meadow cliffs stay rare).
func _level_scaled_fill(fill: float, pos: Vector3) -> float:
	var macro: float = Helper.macro_density01(pos, _world_seed)
	return clampf(fill * (0.5 + 0.9 * macro), 0.0, 1.0)


func in_cliff_core(pos: Vector3) -> bool:
	return (
		Helper.macro_density01(pos, _world_seed)
		>= TerrainSpawnConfig.CLIFF_CONTOUR_BASE
	)


# Cliff origins sit on the storey top plane (base tier y = 4.0: ground
# topcenter at y = 0 plus one 4u storey), so the storey index falls out of
# the origin height.
func _cliff_storey_threshold(piece: TerrainModuleInstance) -> float:
	var storey: float = maxf(0.0, (piece.transform.origin.y - 4.0) / 4.0)
	return (
		TerrainSpawnConfig.CLIFF_CONTOUR_BASE
		+ TerrainSpawnConfig.CLIFF_CONTOUR_STEP * storey
	)


# Foliage on a cliff tile is pointless when the tile is destined to become a
# plateau interior: the next storey lands on it and displaces the foliage
# (visible pop-out). Interior-ness is deterministic for contour-carved mesas —
# the tile and all 8 neighbours inside this storey's contour — so cliff
# foliage is suppressed geometrically instead of by probability roll.
func cliff_foliage_covered_by_stack(
	piece: TerrainModuleInstance, socket_name: String
) -> bool:
	if not piece.def.covered_by_storey_above:
		return false
	if not socket_can_spawn_point(piece, socket_name):
		return false
	var threshold: float = _cliff_storey_threshold(piece)
	var origin: Vector3 = piece.transform.origin
	for dx in [-24.0, 0.0, 24.0]:
		for dz in [-24.0, 0.0, 24.0]:
			var neighbor: Vector3 = origin + Vector3(dx, 0.0, dz)
			if Helper.macro_density01(neighbor, _world_seed) < threshold:
				return false
	return true


func _macro_scaled_fill(fill: float, pos: Vector3) -> float:
	if fill >= 1.0:
		return fill
	var macro: float = Helper.macro_density01(pos, _world_seed)
	# High-contrast curve: lateral cluster growth (cliff 0.42, level 0.3) must
	# cross criticality (~1/3 effective) only INSIDE range cores. Cores then
	# fill into solid mesas — whose interior tiles enable vertical stacking —
	# while mid-density terrain stays subcritical instead of sprawling into
	# single-storey snake mazes.
	var factor: float = 0.15 + 3.2 * pow(macro, 3.2)
	return clampf(fill * factor, 0.0, 1.0)


func is_socket_blocking(piece_socket: TerrainModuleSocket) -> bool:
	if piece_socket == null or piece_socket.piece == null or piece_socket.piece.def == null:
		return false
	var socket_name: String = piece_socket.socket_name
	var fill_probs: Dictionary = piece_socket.piece.def.socket_fill_prob
	if not fill_probs.has(socket_name):
		return false
	var fill_prob: Variant = fill_probs[socket_name]
	if fill_prob == null:
		return false
	return get_socket_fill_prob(piece_socket.piece, socket_name) <= 0.0


func socket_can_spawn_point(piece: TerrainModuleInstance, socket_name: String) -> bool:
	var size_dist: Distribution = piece.def.socket_size.get(socket_name, null)
	if size_dist == null:
		return true  # sockets without a size dist default to "point"
	return size_dist.dist.has("point")


# Whether a suppression entry ({"socket": name, "prob": float}) fires: the
# suppressor socket's deterministic position roll passes at the authored
# probability, scaled exactly the way that socket's own enqueue verdict would
# be (route_fill_prob) — same position hash, same curve — so suppression
# fires precisely where the suppressor socket actually fires.
func suppressor_roll_passes(piece: TerrainModuleInstance, entry: Variant) -> bool:
	if not (entry is Dictionary):
		return false
	var suppressor_name: String = String(entry.get("socket", ""))
	var socket: Marker3D = piece.sockets.get(suppressor_name, null)
	if socket == null:
		return false
	var pos := Helper.socket_world_pos(piece.transform, socket, piece.root)
	var prob: float = float(entry.get("prob", 0.0))
	return Helper.position_hash01(pos, _world_seed) <= route_fill_prob(piece, suppressor_name, pos, prob)
