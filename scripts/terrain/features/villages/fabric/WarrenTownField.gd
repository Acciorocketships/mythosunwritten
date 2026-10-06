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


const MAX_CROWN_OFFSET := 0.25
const MAX_CROWN_WIDTH := 0.9
const MAX_GREEN_REACH := 1.45
const BASE_EXTENT := 2.5
const MAX_DENSITY := 1.05
const MAX_SATELLITE_WIDTH := 0.8
const MIN_SATELLITE_WIDTH := 3.0

## The same limits used below bound the sampling box, including a green
## whose centre and satellite both move away from the original crown.
static func maximum_sample_extent(radius: float) -> int:
	var width := maxf(radius * MAX_CROWN_WIDTH,
		maxf(MIN_SATELLITE_WIDTH,radius * MAX_DENSITY * MAX_SATELLITE_WIDTH))
	return ceili(maxf(radius * BASE_EXTENT,
		radius * (MAX_CROWN_OFFSET + 2.0 * MAX_GREEN_REACH) + sqrt(2.0) * width))


static func sample(seed_value: int, profile: WarrenVillageScaleProfile) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, &"town-field"])
	var radius := float(profile.radius_cells)
	var spread := rng.randf_range(0.7, 1.5)
	var density := rng.randf_range(0.45, MAX_DENSITY)
	var core := rng.randf_range(profile.core_target_band_range.x,
		profile.core_target_band_range.y)
	# A crown lobe near the centre and a ring of 1-5 satellites. The crown
	# stays whole: the spine climbs it.
	var phase := rng.randf() * TAU
	var crown_width := Vector2(radius * rng.randf_range(0.65, MAX_CROWN_WIDTH),
		radius * rng.randf_range(0.65, MAX_CROWN_WIDTH))
	var crown := Vector2.from_angle(rng.randf() * TAU) * radius * MAX_CROWN_OFFSET * sqrt(rng.randf())
	var lobes: Array[Dictionary] = [{"centre": crown, "width": crown_width,
		"height": core, "angle": rng.randf() * TAU}]
	var count: int = [1, 2, 2, 3, 3, 4, 4, 5][rng.randi_range(0, 7)]
	for i in count:
		var angle := phase + TAU * (float(i) + rng.randf_range(-0.2, 0.2)) / float(count)
		var size := maxf(MIN_SATELLITE_WIDTH, radius * density * rng.randf_range(0.45, MAX_SATELLITE_WIDTH))
		lobes.append({"centre": Vector2.from_angle(angle) * radius * spread * rng.randf_range(0.75, 1.2),
			"width": Vector2(size, maxf(2.5, size * rng.randf_range(0.55, 0.9))),
			"height": rng.randf_range(maxf(5.0, core * 0.45), core),
			"angle": angle + rng.randf_range(-0.8, 0.8)})
	# Classify the sampled masses before spacing the districts around a
	# green. Moving an inhabited cluster must not demote it to one cottage.
	_classify_lobes(lobes)
	# Occasionally the sampled masses surround a green instead of converging
	# on it. Keep the original crown and mass budget: only existing satellites
	# move, and towns with too few masses retain their ordinary layout.
	var green_rng := RandomNumberGenerator.new()
	green_rng.seed = hash([seed_value, "town.central_green"])
	var central_green := green_rng.randf() < 0.3 and lobes.size() >= 4
	var green_centre := Vector2.ZERO
	if central_green:
		var crown_reach := radius * green_rng.randf_range(1.25,MAX_GREEN_REACH)
		green_centre = crown - Vector2.from_angle(phase)*crown_reach
		for index in range(1,lobes.size()):
			var angle := phase + TAU * float(index)/float(lobes.size())
			lobes[index].centre = green_centre + Vector2.from_angle(angle) * radius * green_rng.randf_range(1.25,MAX_GREEN_REACH)
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
	if central_green:
		clearings = [{"centre":green_centre,"radius":radius*0.6,"strength":1.0}]
	var openness := 0.0
	for clearing: Dictionary in clearings:
		openness = maxf(openness, float(clearing.strength))
	var tree := _spanning_tree(lobes)
	var raw_at: Dictionary = {}
	var house_columns: Dictionary = {}
	var extent := ceili(radius * BASE_EXTENT)
	if central_green:
		for lobe: Dictionary in lobes:
			var lobe_reach: float = (lobe.centre as Vector2).length() + (lobe.width as Vector2).length()
			extent = maxi(extent,ceili(lobe_reach))
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
				var strongest := -1.0
				var owner := 0
				for index in lobes.size():
					var influence := _lobe_height(lobes[index], p)
					if influence > strongest:
						strongest = influence
						owner = index
				if lobes[owner].get("kind", &"massif") == &"house":
					house_columns[Vector2i(x,z)] = {"lobe": owner, "storeys": lobes[owner].storeys}
	var solid := _largest_component(raw_at)
	var height_domain := solid.duplicate()
	# Fit explicit courts to the field's already planned crown, shoulders,
	# outer margin and optional fortification, before any boring or partition.
	var platform := WarrenTownPlatform.sample(seed_value, lobes[0], solid)
	# Fortified districts and their approaches own this ground before small
	# house sites are selected. A house cap must never erase the upper town.
	for column: Vector2i in house_columns.keys():
		for raised: Vector2i in platform.get("columns",{}):
			if maxi(absi(column.x-raised.x),absi(column.y-raised.y)) <= 2:
				house_columns.erase(column)
				break

	var height_preview := WarrenMassifBuilder._terraced_massif(seed_value, height_domain, {})
	var peak := 0
	for column: Vector2i in height_preview.columns:
		peak = maxi(peak,height_preview.layer_at(column))
	var open_spaces := preload("res://scripts/terrain/features/villages/fabric/WarrenTownOpenSpaces.gd").sample(
		seed_value, radius, lobes, tree, solid, platform,
		height_preview)
	for space: Dictionary in open_spaces:
		for cell: Vector2i in space.cells: solid.erase(cell)
	var house_sites := _house_sites(lobes, house_columns, solid)
	var admitted_sites: Array[Dictionary] = []
	for site: Dictionary in house_sites:
		var garden := {}
		for column: Vector2i in house_columns:
			if int(house_columns[column].lobe) != int(site.lobe): continue
			if site.cells.has(column): continue
			var preserves_crown := true
			for high: Vector2i in height_preview.columns:
				if height_preview.layer_at(high) < peak*0.8: continue
				var distance := absi(column.x-high.x)+absi(column.y-high.y)
				if height_preview.layer_at(high) > distance*WarrenMassifBuilder.MAX_NEIGHBOR_STEP_BANDS:
					preserves_crown = false
			if preserves_crown and solid.has(column): garden[column] = true
		if garden.size() < 4: continue
		admitted_sites.append(site)
		open_spaces.append({"id":StringName("house.garden.%d" % int(site.lobe)),
			"centre":site.centre,"kind":&"garden","cells":garden,"purpose":&"grove"})
		for column: Vector2i in garden: solid.erase(column)

	house_sites = admitted_sites
	if central_green:
		# The enclosed clearing is open ground, not outside the town's route
		# domain. Keep it unbuildable while allowing streets between districts.
		# Previously only thin spanning-tree shoulders were walkable, forcing
		# approaches to follow the outer ring even across an empty green.
		var points := PackedVector2Array()
		for lobe: Dictionary in lobes: points.append(lobe.centre)
		var hull := Geometry2D.convex_hull(points)
		var ground := {}
		for z in range(-extent,extent+1):
			for x in range(-extent,extent+1):
				var column := Vector2i(x,z)
				if height_domain.has(column): continue
				if not Geometry2D.is_point_in_polygon(Vector2(column),hull): continue
				height_domain[column] = float(WarrenMassifBuilder.MIN_COLUMN_BANDS)
				ground[column] = true
		if not ground.is_empty():
			open_spaces.append({"id":&"open.central_ground","centre":green_centre,
				"radius":float(clearings[0].radius),"cells":ground,"purpose":&"green"})
	var air := {}
	for z in range(-extent, extent + 1):
		for x in range(-extent, extent + 1):
			if not solid.has(Vector2i(x, z)):
				air[Vector2i(x, z)] = true
	# The raised district (a separate roll, so towns without one are unchanged).
	return {"central_green":central_green,"green_centre":green_centre,"solid": solid, "air": air, "lobes": lobes, "clearings": clearings,
		"height_domain": height_domain, "house_columns": house_columns, "house_sites": house_sites,
		"open_spaces": open_spaces,
		"spread": spread, "density": density, "openness": openness,
		"platform": platform}


static func _house_sites(lobes: Array[Dictionary], columns: Dictionary,
		solid: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index in range(1,lobes.size()):
		if lobes[index].get("kind",&"massif") != &"house": continue
		var centre: Vector2 = lobes[index].centre
		var best := {}
		var score := INF
		for anchor: Vector2i in columns:
			if int(columns[anchor].lobe) != index: continue
			var cells := {}
			for delta: Vector2i in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]:
				var cell := anchor+delta
				if solid.has(cell) and columns.has(cell) and int(columns[cell].lobe) == index:
					cells[cell] = true
			if cells.size() != 4: continue
			var distance := (Vector2(anchor)+Vector2.ONE*0.5).distance_squared_to(centre)
			if distance < score:
				score = distance
				best = cells
		if not best.is_empty(): out.append({"lobe":index,"centre":centre,"cells":best})
	return out


static func _classify_lobes(lobes: Array[Dictionary]) -> void:
	# Independent small bumps become house sites. Overlapping bumps remain
	# massifs. Read the original mixture so lowering one never changes how
	# its neighbours are classified.
	var original := lobes.duplicate(true)
	var crown_width: Vector2 = original[0].width
	var crown_area := crown_width.x * crown_width.y
	for index in lobes.size():
		lobes[index]["kind"] = &"massif"
		if index == 0: continue
		var lobe: Dictionary = original[index]
		var width: Vector2 = lobe.width
		if width.x * width.y > crown_area * 0.55: continue
		var merged := false
		for other in original.size():
			if other == index: continue
			if _lobe_height(original[other], lobe.centre) > float(lobe.height) * 0.3:
				merged = true
		if merged: continue
		var storeys := 1 if width.x * width.y < 12.0 else 2
		lobes[index]["kind"] = &"house"
		lobes[index]["storeys"] = storeys


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
