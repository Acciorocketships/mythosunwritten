class_name ProximityTagRules
extends Resource

# Boost tag probabilities if nearby tiles match the tag.
#
# Notes:
# - Only tags already present in the incoming Distribution are considered.
# - Uses TerrainIndex.query_box() for a broad-phase query, then refines per-rule by XZ distance.
# - For combined tags like "[left]path", we ignore the socket prefix and match only "path".

### Rule "library" (like TerrainModuleLibrary) ###

@export var rules: Array[ProximityTagRule] = []

# Query box half-height (Y). Keep modest; most modules are near y=0.
@export var y_half_extent: float = 8.0

# If enabled, prints proximity adjustments per placement attempt.
@export var debug_prints: bool = false

func _init() -> void:
	load_rules()

func load_rules() -> void:
	rules.clear()
	rules.append(_rule_grass())

func _rule_grass() -> ProximityTagRule:
	return ProximityTagRule.init_rule("grass", 48.0, 0.25, -0.03)

func augment_distribution(
	dist_in: Distribution,
	origin_world: Vector3,
	terrain_index: TerrainIndex,
	_adjacent: Dictionary[String, TerrainModuleSocket] = {}
) -> Distribution:
	var res: Dictionary = augment_distribution_with_factor(dist_in, origin_world, terrain_index)
	return res["dist"] as Distribution

func augment_distribution_with_factor(
	dist_in: Distribution,
	origin_world: Vector3,
	terrain_index: TerrainIndex
) -> Dictionary:
	# Returns:
	# - "dist": Distribution (normalised)
	# - "factor": float (sum before normalise; 1.0 means no net change)
	var out: Distribution = dist_in.copy()
	if out.dist.is_empty() or rules.is_empty():
		return {"dist": out, "factor": 1.0}

	if debug_prints:
		print("[ProximityTagRules] incoming dist=", out.dist)

	# Only evaluate rules for tags already present in the distribution.
	var applicable: Array[ProximityTagRule] = []
	var max_radius: float = 0.0
	for r: ProximityTagRule in rules:
		if r == null or r.tag == "":
			continue
		if out.prob(r.tag) <= 0.0:
			continue
		if r.radius <= 0.0:
			continue
		applicable.append(r)
		if r.radius > max_radius:
			max_radius = r.radius

	if applicable.is_empty():
		if debug_prints:
			print("[ProximityTagRules] no applicable rules (no matching tags in dist)")
		return {"dist": out, "factor": 1.0}

	# Broad-phase: one query using max radius, then per-rule refinement.
	var he: float = max(y_half_extent, 0.0)
	var query_box: AABB = AABB(
		origin_world - Vector3(max_radius, he, max_radius),
		Vector3(max_radius * 2.0, he * 2.0, max_radius * 2.0)
	)

	var nearby: Array = terrain_index.query_box(query_box)
	if nearby.is_empty():
		if debug_prints:
			print("[ProximityTagRules] query_box returned 0 candidates, box=", query_box)
		return {"dist": out, "factor": 1.0}

	if debug_prints:
		print(
			"[ProximityTagRules] origin=",
			origin_world,
			" candidates=",
			nearby.size(),
			" rules=",
			applicable.size()
		)

	var counts: Dictionary[String, int] = {}
	for r: ProximityTagRule in applicable:
		counts[r.tag] = 0

	# Debug: how many candidates even have the rule tags?
	var candidates_with_tag: Dictionary[String, int] = {}
	if debug_prints:
		for r: ProximityTagRule in applicable:
			candidates_with_tag[r.tag] = 0
		var shown: int = 0
		for m in nearby:
			var inst0: TerrainModuleInstance = m as TerrainModuleInstance
			if inst0 == null or inst0.def == null or inst0.def.tags == null:
				continue
			for r: ProximityTagRule in applicable:
				if inst0.def.tags.has(r.tag):
					candidates_with_tag[r.tag] = int(candidates_with_tag[r.tag]) + 1
			if shown < 5:
				print(
					"[ProximityTagRules] candidate tags=",
					inst0.def.tags.tags,
					" aabb.size=",
					inst0.aabb.size
				)
				shown += 1
		print("[ProximityTagRules] candidates_with_tag=", candidates_with_tag)

	for m in nearby:
		var inst: TerrainModuleInstance = m as TerrainModuleInstance
		if inst == null:
			continue

		var center: Vector3 = inst.aabb.position + inst.aabb.size * 0.5
		var dx: float = center.x - origin_world.x
		var dz: float = center.z - origin_world.z
		var d2: float = dx * dx + dz * dz

		for r: ProximityTagRule in applicable:
			if d2 > r.radius * r.radius:
				continue
			if _instance_matches_tag(inst, r.tag):
				counts[r.tag] = int(counts[r.tag]) + 1

	if debug_prints:
		print("[ProximityTagRules] match_counts_in_radius=", counts)

	# Apply multipliers.
	const MIN_MUL: float = 1e-3
	var any_change: bool = false
	for r: ProximityTagRule in applicable:
		var c: int = int(counts[r.tag])
		if c <= 0:
			continue
		var before: float = out.prob(r.tag)
		var mul: float = 1.0 + r.boost + r.per_count * float(c)
		mul = max(mul, MIN_MUL)
		out.set_prob(r.tag, before * mul)
		any_change = true
		if debug_prints:
			print(
				"[ProximityTagRules] tag=",
				r.tag,
				" count=",
				c,
				" mul=",
				mul,
				" prob ",
				before,
				" -> ",
				out.prob(r.tag)
			)

	if not any_change:
		if debug_prints:
			print("[ProximityTagRules] no matches in radius; factor stays 1.0")
		return {"dist": out, "factor": 1.0}

	var sum_before_norm: float = 0.0
	for k: String in out.dist.keys():
		sum_before_norm += float(out.dist[k])

	if sum_before_norm <= 0.0:
		# Degenerate; fall back to original distribution.
		return {"dist": dist_in.copy(), "factor": 1.0}

	out.normalise()
	if debug_prints:
		print("[ProximityTagRules] factor=", sum_before_norm, " normalised dist=", out.dist)
	return {"dist": out, "factor": sum_before_norm}

static func _instance_matches_tag(inst: TerrainModuleInstance, tag: String) -> bool:
	if inst == null or inst.def == null:
		return false

	# If tag is socket-qualified (e.g. "[left]path"), ignore the socket part for rules.
	if tag.begins_with("["):
		var close_i: int = tag.find("]")
		if close_i > 1:
			tag = tag.substr(close_i + 1)

	var def: TerrainModule = inst.def
	if def.tags != null and def.tags.has(tag):
		return true

	return false

