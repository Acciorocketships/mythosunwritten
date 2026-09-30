extends RefCounted

## A continuous family of town envelopes: a Gaussian mixture of massifs with
## open clearings, sampled BEFORE any street is bored. Every town draws from
## the same distribution; the size budget only scales it.
##
## * Massifs: a crown lobe near (not at) the centre and a ring of 1-5
##   anisotropic satellites, each with its own height and size.
## * Clearings: 0-3 open areas, sometimes the town centre (massifs ringing an
##   open square), otherwise in the gaps between satellites. They cut massifs
##   down to open ground and read as squares and greens.
## * Shoulders: low narrow ridges along the minimum spanning tree of the lobe
##   centres keep the route domain connected; clearings do not cut them.
## * Only the largest connected piece is kept, so the massif is one component.
## Missing columns are deliberate air (open ground).
const SHOULDER_BANDS := 3.4
## How much faster the clearing-proof crown core falls off than the crown.
const CROWN_CORE := 2.0
const CARDINALS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP,
	Vector2i.DOWN]


static func sample(seed_value: int, profile: WarrenVillageScaleProfile) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, &"town-field"])
	var radius := float(profile.radius_cells)
	var spread := rng.randf_range(0.7, 1.5)
	var density := rng.randf_range(0.45, 1.05)
	var core := rng.randf_range(profile.core_target_band_range.x,
		profile.core_target_band_range.y)
	# A crown lobe near the centre and a ring of 1-5 satellites. The crown
	# stays whole: the spine climbs it.
	var phase := rng.randf() * TAU
	var crown_width := Vector2(radius * rng.randf_range(0.65, 0.9),
		radius * rng.randf_range(0.65, 0.9))
	var crown := Vector2.from_angle(rng.randf() * TAU) * radius * 0.25 * sqrt(rng.randf())
	var lobes: Array[Dictionary] = [{"centre": crown, "width": crown_width,
		"height": core, "angle": rng.randf() * TAU}]
	var count: int = [1, 2, 2, 3, 3, 4, 4, 5][rng.randi_range(0, 7)]
	for i in count:
		var angle := phase + TAU * (float(i) + rng.randf_range(-0.2, 0.2)) / float(count)
		var size := maxf(3.0, radius * density * rng.randf_range(0.45, 0.8))
		lobes.append({"centre": Vector2.from_angle(angle) * radius * spread * rng.randf_range(0.75, 1.2),
			"width": Vector2(size, maxf(2.5, size * rng.randf_range(0.55, 0.9))),
			"height": rng.randf_range(maxf(5.0, core * 0.45), core),
			"angle": angle + rng.randf_range(-0.8, 0.8)})
	# Clearings: sometimes a square right beside the crown (the middle of the
	# town opens up), and 0-2 greens in the gaps between satellites. None
	# lands on the crown itself.
	var clearings: Array[Dictionary] = []
	var reach := crown_width.x
	if rng.randf() < 0.6:
		clearings.append({"centre": crown + Vector2.from_angle(rng.randf() * TAU) * reach * rng.randf_range(1.0, 1.25),
			"radius": radius * rng.randf_range(0.3, 0.5), "strength": rng.randf_range(0.85, 1.0)})
	for i: int in [1, 1, 2, 2, 3][rng.randi_range(0, 4)]:
		var gap := phase + TAU * (float(rng.randi_range(0, count - 1)) + 0.5) / float(count)
		var centre := Vector2.from_angle(gap) * radius * spread * rng.randf_range(0.55, 0.95)
		if centre.distance_to(crown) >= reach:
			clearings.append({"centre": centre, "radius": radius * rng.randf_range(0.2, 0.4),
				"strength": rng.randf_range(0.7, 1.0)})
	var openness := 0.0
	for clearing: Dictionary in clearings:
		openness = maxf(openness, float(clearing.strength))
	var tree := _spanning_tree(lobes)
	var raw_at: Dictionary = {}
	var extent := ceili(radius * 2.5)
	for z in range(-extent, extent + 1):
		for x in range(-extent, extent + 1):
			var p := Vector2(x, z)
			var raw := 0.0
			for lobe: Dictionary in lobes:
				raw = maxf(raw, _lobe_height(lobe, p))
			for clearing: Dictionary in clearings:
				var d := p.distance_to(clearing.centre as Vector2) / float(clearing.radius)
				raw *= 1.0 - float(clearing.strength) * exp(-pow(d, 4.0))
			# Clearings may open the crown's flanks, never its core: the spine
			# climbs it.
			raw = maxf(raw, _lobe_height(lobes[0], p, CROWN_CORE))
			for edge: Array in tree:
				var a := lobes[edge[0]].centre as Vector2
				var ab := (lobes[edge[1]].centre as Vector2) - a
				var along := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
				var distance := p.distance_to(a + ab * along)
				raw = maxf(raw, SHOULDER_BANDS * exp(-distance * distance / 2.25))
			# Gentle coherent boundary roughness, shared by every height layer.
			var noise := WarrenMassifBuilder._value_noise(seed_value, 0x51A, Vector2i(x, z), 4)
			raw *= lerpf(0.82, 1.18, noise)
			if raw >= WarrenMassifBuilder.MIN_COLUMN_BANDS:
				raw_at[Vector2i(x, z)] = raw
	var solid := _largest_component(raw_at)
	var air := {}
	for z in range(-extent, extent + 1):
		for x in range(-extent, extent + 1):
			if not solid.has(Vector2i(x, z)):
				air[Vector2i(x, z)] = true
	# The raised district (a separate roll, so towns without one are unchanged).
	var platform := WarrenTownPlatform.sample(seed_value, lobes[0], solid)
	return {"solid": solid, "air": air, "lobes": lobes, "clearings": clearings,
		"spread": spread, "density": density, "openness": openness,
		"platform": platform}


static func _lobe_height(lobe: Dictionary, p: Vector2, sharpness := 1.0) -> float:
	var q := (p - (lobe.centre as Vector2)).rotated(-float(lobe.angle)) \
		/ (lobe.width as Vector2)
	return float(lobe.height) * exp(-q.length_squared() * 1.4 * sharpness)


static func _spanning_tree(lobes: Array[Dictionary]) -> Array:
	## Prim's minimum spanning tree over the lobe centres.
	var edges: Array = []
	var joined: Array[int] = [0]
	while joined.size() < lobes.size():
		var best := []
		var best_distance := INF
		for i: int in joined:
			for j in lobes.size():
				if joined.has(j):
					continue
				var d := (lobes[i].centre as Vector2).distance_squared_to(lobes[j].centre)
				if d < best_distance:
					best_distance = d
					best = [i, j]
		edges.append(best)
		joined.append(best[1])
	return edges


static func _largest_component(cells: Dictionary) -> Dictionary:
	var seen: Dictionary = {}
	var best: Array[Vector2i] = []
	var order: Array = cells.keys()
	order.sort()
	for start: Vector2i in order:
		if seen.has(start):
			continue
		var members: Array[Vector2i] = [start]
		seen[start] = true
		var index := 0
		while index < members.size():
			var cell := members[index]
			index += 1
			for direction: Vector2i in CARDINALS:
				var next := cell + direction
				if cells.has(next) and not seen.has(next):
					seen[next] = true
					members.append(next)
		if members.size() > best.size():
			best = members
	var out: Dictionary = {}
	for cell: Vector2i in best:
		out[cell] = cells[cell]
	return out
