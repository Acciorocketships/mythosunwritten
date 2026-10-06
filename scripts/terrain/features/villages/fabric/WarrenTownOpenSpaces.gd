extends RefCounted
## Pre-bore reservations. Circles fit between the crown and the connecting
## shoulders, so opening a green cannot sever the massif's route backbone.
## The record survives downstream for ground cover and contextual dressing.
const MIN_OPEN_CELLS := 4
const PURPOSES: Array[StringName] = [&"green", &"grove", &"courtyard", &"market", &"workyard"]

static func sample(seed_value: int, radius: float, lobes: Array[Dictionary],
		tree: Array, domain: Dictionary, platform: Dictionary,
		heights: WarrenMassif) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "town.open_spaces"])
	var out: Array[Dictionary] = []
	# Some tightly urban towns keep only their existing streets/squares.
	if rng.randf() < 0.12: return out
	var count := rng.randi_range(1, 3)
	var crown: Vector2 = lobes[0].centre
	var crown_width: Vector2 = lobes[0].width
	var protected_radius := minf(crown_width.x, crown_width.y) * 0.48
	var phase := rng.randf() * TAU
	for i in 96:
		if out.size() >= count: break
		var centre := crown + Vector2.from_angle(phase + float(i) * 2.39996323) \
			* radius * rng.randf_range(0.45, 1.10)
		var fit := minf(radius * rng.randf_range(0.40, 0.65),
			centre.distance_to(crown) - protected_radius)
		for edge: Array in tree:
			var a: Vector2 = lobes[edge[0]].centre
			var b: Vector2 = lobes[edge[1]].centre
			var ab := b - a
			var t := clampf((centre - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			fit = minf(fit, centre.distance_to(a + ab * t) - 1.2)
		for other: Dictionary in out:
			fit = minf(fit, centre.distance_to(other.centre) - float(other.radius) - 0.5)
		for cell: Vector2i in platform.get("columns", {}):
			fit = minf(fit, centre.distance_to(Vector2(cell)) - 2.0)
		# Search for a real gathering/grove space before accepting leftover
		# pockets. Connectivity and crown protection remain the hard limits.
		if fit < (1.6 if i < 72 else 0.85): continue
		var cells: Dictionary = {}
		for z in range(floori(centre.y - fit), ceili(centre.y + fit) + 1):
			for x in range(floori(centre.x - fit), ceili(centre.x + fit) + 1):
				if Vector2(x, z).distance_to(centre) <= fit and domain.has(Vector2i(x, z)):
					cells[Vector2i(x, z)] = true
		if cells.size() < MIN_OPEN_CELLS: continue
		# Give the first green a chance to open the town's interior. If no
		# safe site fits, the second half of the search admits edge greens.
		if out.is_empty() and i < 48:
			var interior := 0
			for cell: Vector2i in cells:
				if heights.ring_depth(cell) >= 2: interior += 1
			if interior < MIN_OPEN_CELLS: continue
		# A green needs descending frontage, but must not shave the high
		# massif that the spine climbs. Test the proposed local descent
		# against the crown before reserving any ground.
		var preserves_crown := true
		var peak := 0
		for column: Vector2i in heights.columns:
			peak = maxi(peak, heights.layer_at(column))
		for column: Vector2i in heights.columns:
			if heights.layer_at(column) < peak * 0.8: continue
			for cell: Vector2i in cells:
				var distance := absi(column.x - cell.x) + absi(column.y - cell.y)
				if heights.layer_at(column) > distance * WarrenMassifBuilder.MAX_NEIGHBOR_STEP_BANDS:
					preserves_crown = false
		if not preserves_crown: continue
		out.append({"id": StringName("open.%d" % out.size()), "centre": centre,
			"radius": fit, "cells": cells, "purpose": PURPOSES[rng.randi_range(0, PURPOSES.size() - 1)]})
	return out


## Keep a usable planting island before routes are bored. The surrounding
## reservation stays available for access; narrow pockets keep their current
## circulation rather than acquiring an unusable one-cell planting strip.
static func planting_core(space: Dictionary) -> Dictionary:
	var cells: Dictionary = space.cells
	if not String(space.id).begins_with("open.") or cells.size()<8: return {}
	var centre: Vector2 = space.centre
	var ordered := cells.keys()
	ordered.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
		return a.x<b.x if a.x!=b.x else a.y<b.y)
	for side in [5,4,3,2]:
		if side*side>cells.size()*0.6: continue
		var best := {}
		var distance := INF
		for anchor: Vector2i in ordered:
			var block := {}
			for z in side:
				for x in side:
					var column := anchor+Vector2i(x,z)
					if cells.has(column): block[column] = true
			if block.size()!=side*side: continue
			var d := (Vector2(anchor)+Vector2.ONE*float(side-1)*0.5).distance_squared_to(centre)
			if d<distance:
				best=block
				distance=d
		if not best.is_empty(): return best
	return {}
