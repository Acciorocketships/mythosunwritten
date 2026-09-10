class_name WarrenMassifBuilder
extends RefCounted

## One deterministic inhabited terrain field. The warped Gaussian owns the
## connected footprint; coherent noise authors its terrace heights. A monotone
## riser clamp and finite region allocation keep those heights within the
## construction vocabulary before any massif columns are emitted. Each small
## region is coalesced once, preserving the complete height ladder.
## No seed phases, completed-field rejection, fallback, or regeneration occurs.
## Shape and connectivity inspection belongs to tests.
const RADIUS_CELLS := 12
const MIN_LAYER_BANDS := 2
const MAX_LAYER_BANDS := WarrenMassif.BUILDABLE_LAYER_BANDS
const MIN_TERRACE_LEVELS := 5
const MIN_COLUMN_BANDS := 2
const MAX_NEIGHBOR_STEP_BANDS := 4
const TERRACE_BANDS := WarrenBuildingParcel.STOREY_BANDS
const MIN_TERRACES := MIN_LAYER_BANDS / TERRACE_BANDS
const MAX_TERRACES := MAX_LAYER_BANDS / TERRACE_BANDS
const MAX_STEP_TERRACES := MAX_NEIGHBOR_STEP_BANDS / TERRACE_BANDS
const RIM_TERRACES := 2
const CLUSTER_PERIOD_CELLS := 5
const DETAIL_PERIOD_CELLS := 2
const DETAIL_OCTAVE_WEIGHT := 0.35
const CLUSTER_RELIEF_TERRACES := 0.75
const MIN_CLUSTER_CELLS := 3
const MAZE_MAX_PLATEAU_CELLS := 16
const MAZE_PLATEAU_COLUMN_SHARE := 6

const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT,
	Vector2i.UP, Vector2i.DOWN]

static var last_failure := ""


static func build(world_seed: int, ground_bands: Dictionary = {},
		scale_profile: WarrenVillageScaleProfile = null) -> WarrenMassif:
	last_failure = ""
	var profile := scale_profile if scale_profile != null \
		else WarrenVillageScaleProfile.review_fixture()
	if not profile.validate():
		last_failure = "invalid village scale profile"
		return null
	var radius_cells := profile.radius_cells
	var footprint_core := profile.core_target_band_range.x \
		+ posmod(_hash(world_seed, 5, 0, 0),
			profile.core_target_band_range.y \
				- profile.core_target_band_range.x + 1)
	var warp_phase := float(posmod(_hash(world_seed, 7, 0, 0), 1000)) \
		/ 1000.0 * TAU
	var warp_strength := 0.22 + float(posmod(_hash(world_seed, 11, 0, 0),
		100)) / 100.0 * 0.18

	var raw_at: Dictionary = {}
	for z in range(-radius_cells, radius_cells + 1):
		for x in range(-radius_cells, radius_cells + 1):
			var radius := Vector2(float(x), float(z)).length()
			var angle := atan2(float(z), float(x))
			var warped := radius * (1.0 + warp_strength \
				* sin(angle * 3.0 + warp_phase))
			var gaussian := exp(-pow(warped / float(radius_cells) * 1.9,
				2.0))
			var raw := float(footprint_core) * gaussian
			if raw < float(MIN_COLUMN_BANDS):
				continue
			raw_at[Vector2i(x, z)] = raw

	var massif := _terraced_massif(world_seed, raw_at, ground_bands)
	massif.core_top_bands = 0
	for column: Vector2i in massif.columns:
		massif.core_top_bands = maxi(massif.core_top_bands,
			massif.layer_at(column))
	massif.finish_construction()
	return massif


static func _terraced_massif(world_seed: int, raw_at: Dictionary,
		ground_bands: Dictionary) -> WarrenMassif:
	var order := _column_order(raw_at)
	var depths := _depths(raw_at)
	var ceilings := _terrace_ceilings(depths)
	var terraces := _terrace_field(order, ceilings, world_seed, raw_at)
	var massif := WarrenMassif.new(world_seed)
	for column: Vector2i in order:
		var base := int(ground_bands.get(column, 0))
		var layer: int = int(terraces[column]) * TERRACE_BANDS
		massif.columns[column] = {"base": base, "top": base + layer, "terrace": layer}
	return massif


static func plateau_cap(column_count: int) -> int:
	return maxi(MAZE_MAX_PLATEAU_CELLS,
		column_count / MAZE_PLATEAU_COLUMN_SHARE)


static func _column_order(raw_at: Dictionary) -> Array[Vector2i]:
	var order: Array[Vector2i] = []
	order.assign(raw_at.keys())
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	return order


static func _depths(raw_at: Dictionary) -> Dictionary:
	var distance: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for column: Vector2i in _column_order(raw_at):
		for direction: Vector2i in DIRECTIONS:
			if raw_at.has(column + direction):
				continue
			distance[column] = 1
			frontier.append(column)
			break
	var index := 0
	while index < frontier.size():
		var column: Vector2i = frontier[index]
		index += 1
		var next_distance: int = int(distance[column]) + 1
		for direction: Vector2i in DIRECTIONS:
			var neighbor := column + direction
			if not raw_at.has(neighbor) or distance.has(neighbor):
				continue
			distance[neighbor] = next_distance
			frontier.append(neighbor)
	return distance


static func _terrace_ceilings(depths: Dictionary) -> Dictionary:
	var ceilings: Dictionary = {}
	for column: Vector2i in depths:
		ceilings[column] = mini(MAX_TERRACES,
			RIM_TERRACES + (int(depths[column]) - 1) * MAX_STEP_TERRACES)
	return ceilings


static func _terrace_field(order: Array[Vector2i], ceilings: Dictionary,
		world_seed: int, raw_at: Dictionary) -> Dictionary:
	var field: Dictionary = {}
	for column: Vector2i in order:
		var ramp := float(raw_at[column]) / float(TERRACE_BANDS)
		var wobble := (_field_noise(world_seed, column) * 2.0 - 1.0) \
			* CLUSTER_RELIEF_TERRACES
		field[column] = ramp + wobble

	var terraces: Dictionary = {}
	for column: Vector2i in order:
		terraces[column] = clampi(int(round(float(field[column]))),
			MIN_TERRACES, int(ceilings.get(column, MAX_TERRACES)))
	_clamp_risers(terraces, ceilings, order)
	_partition_terrace_regions(terraces, ceilings, order)
	_coalesce_regions(terraces, ceilings, order)

	return terraces


static func _field_noise(world_seed: int, column: Vector2i) -> float:
	var coarse := _value_noise(world_seed, 41, column, CLUSTER_PERIOD_CELLS)
	var detail := _value_noise(world_seed, 43, column, DETAIL_PERIOD_CELLS)
	return (coarse + DETAIL_OCTAVE_WEIGHT * detail) \
		/ (1.0 + DETAIL_OCTAVE_WEIGHT)


static func _value_noise(world_seed: int, salt: int, column: Vector2i,
		period: int) -> float:
	var px := float(column.x) / float(period)
	var pz := float(column.y) / float(period)
	var gx := floori(px)
	var gz := floori(pz)
	var fx := px - float(gx)
	var fz := pz - float(gz)
	var sx := fx * fx * (3.0 - 2.0 * fx)
	var sz := fz * fz * (3.0 - 2.0 * fz)
	return lerpf(
		lerpf(_lattice_value(world_seed, salt, gx, gz),
			_lattice_value(world_seed, salt, gx + 1, gz), sx),
		lerpf(_lattice_value(world_seed, salt, gx, gz + 1),
			_lattice_value(world_seed, salt, gx + 1, gz + 1), sx),
		sz)


static func _lattice_value(world_seed: int, salt: int, gx: int,
		gz: int) -> float:
	return float(WarrenPassageLatticeRules.hash_key(world_seed, salt,
		Vector3i(gx, 0, gz))) / 2147483646.0


static func _cluster_ids(terraces: Dictionary,
		order: Array[Vector2i]) -> Array:
	var id_of: Dictionary = {}
	var cells_of: Array = []
	for start: Vector2i in order:
		if id_of.has(start):
			continue
		var level := int(terraces[start])
		var id := cells_of.size()
		var members: Array[Vector2i] = [start]
		id_of[start] = id
		var index := 0
		while index < members.size():
			var cell: Vector2i = members[index]
			index += 1
			for direction: Vector2i in DIRECTIONS:
				var neighbor := cell + direction
				if id_of.has(neighbor) or not terraces.has(neighbor) \
						or int(terraces[neighbor]) != level:
					continue
				id_of[neighbor] = id
				members.append(neighbor)
		cells_of.append(members)
	return [id_of, cells_of]


static func _clamp_risers(terraces: Dictionary, ceilings: Dictionary,
		order: Array[Vector2i]) -> void:
	var changed := true
	while changed:
		changed = false
		for cell: Vector2i in order:
			var cap := int(ceilings.get(cell, MAX_TERRACES))
			for direction: Vector2i in DIRECTIONS:
				var neighbor := cell + direction
				if not terraces.has(neighbor):
					cap = mini(cap, RIM_TERRACES)
					continue
				cap = mini(cap, int(terraces[neighbor]) + MAX_STEP_TERRACES)
			if int(terraces[cell]) > cap:
				terraces[cell] = maxi(MIN_TERRACES, cap)
				changed = true


static func _worst_neighbor_step(massif: WarrenMassif) -> int:
	var worst := 0
	for column: Vector2i in massif.columns:
		for direction: Vector2i in DIRECTIONS:
			var neighbor := column + direction
			if not massif.has_column(neighbor):
				worst = maxi(worst, massif.layer_at(column))
				continue
			worst = maxi(worst, absi(massif.layer_at(column)
				- massif.layer_at(neighbor)))
	return worst


static func _hash(world_seed: int, salt: int, x: int, z: int) -> int:
	var value := world_seed * 73856093 ^ salt * 19349663 \
		^ x * 83492791 ^ z * 2971215073
	value = posmod(value, 2147483647)
	return value


static func _coalesce_regions(terraces: Dictionary, ceilings: Dictionary,
		order: Array[Vector2i]) -> void:
	var cap := plateau_cap(order.size())
	var partition := _cluster_ids(terraces, order)
	var id_of: Dictionary = partition[0]
	var cells_of: Array = partition[1]
	var level_counts: Dictionary = {}
	for cell: Vector2i in order:
		var level := int(terraces[cell])
		level_counts[level] = int(level_counts.get(level, 0)) + 1
	for id in cells_of.size():
		var members: Array = cells_of[id]
		if members.is_empty() or members.size() >= MIN_CLUSTER_CELLS:
			continue
		var old_level := int(terraces[members[0]])
		if int(level_counts[old_level]) == members.size():
			continue
		var low := MIN_TERRACES
		var high := MAX_TERRACES
		var contacts: Dictionary = {}
		var owners_by_level: Dictionary = {}
		for cell: Vector2i in members:
			high = mini(high, int(ceilings[cell]))
			for direction: Vector2i in DIRECTIONS:
				var neighbor := cell + direction
				if not terraces.has(neighbor) or int(id_of[neighbor]) == id:
					continue
				var level := int(terraces[neighbor])
				low = maxi(low, level - MAX_STEP_TERRACES)
				high = mini(high, level + MAX_STEP_TERRACES)
				contacts[level] = int(contacts.get(level, 0)) + 1
				var owners: Dictionary = owners_by_level.get(level, {})
				owners[int(id_of[neighbor])] = true
				owners_by_level[level] = owners
		var selected := old_level
		var weight := 0
		for level: int in contacts:
			if level < low or level > high:
				continue
			var size := members.size()
			for owner: int in owners_by_level[level]:
				size += (cells_of[owner] as Array).size()
			if size <= cap and int(contacts[level]) > weight:
				selected = level
				weight = int(contacts[level])
		if selected == old_level:
			continue
		var union: Array = members.duplicate()
		for owner: int in owners_by_level[selected]:
			union.append_array(cells_of[owner])
			cells_of[owner] = []
		cells_of[id] = union
		level_counts[old_level] = int(level_counts[old_level]) - members.size()
		level_counts[selected] = int(level_counts.get(selected, 0)) + members.size()
		for cell: Vector2i in union:
			id_of[cell] = id
			terraces[cell] = selected


static func _partition_terrace_regions(terraces: Dictionary, ceilings: Dictionary,
		order: Array[Vector2i]) -> void:
	var cap := plateau_cap(order.size())
	var initial := _cluster_ids(terraces, order)
	for original: Array in initial[1]:
		if original.size() <= cap: continue
		var partition := _cluster_ids(terraces, order)
		var owners: Dictionary = partition[0]
		var regions: Array = partition[1]
		var old_level := int(terraces[original[0]])
		var moved := 0
		for cell: Vector2i in original:
			if original.size() - moved <= cap: break
			var low := MIN_TERRACES
			var high := int(ceilings[cell])
			var neighbors: Dictionary = {}
			for direction: Vector2i in DIRECTIONS:
				var next := cell + direction
				if not terraces.has(next): continue
				var level := int(terraces[next])
				low = maxi(low, level - MAX_STEP_TERRACES)
				high = mini(high, level + MAX_STEP_TERRACES)
				var ids: Dictionary = neighbors.get(level,{})
				ids[int(owners[next])] = true
				neighbors[level] = ids
			var selected := old_level
			for level in range(low, high + 1):
				if level == old_level: continue
				var size := 1
				for id: int in neighbors.get(level,{}): size += (regions[id] as Array).size()
				if size <= cap:
					selected = level
					break
			if selected == old_level: continue
			terraces[cell] = selected
			moved += 1
			partition = _cluster_ids(terraces, order)
			owners = partition[0]
			regions = partition[1]
