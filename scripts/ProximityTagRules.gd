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
	# Example default: if there's at least one nearby grass, aim for a 50% overall chance
	# to place grass at this socket (baseline is typically ~5% on top sockets).
	return ProximityTagRule.init_rule("grass", 24.0, 0.5, 8)

func augment_distribution(
	dist_in: Distribution,
	origin_world: Vector3,
	terrain_index: TerrainIndex,
	fill_prob_base: float,
	_adjacent: Dictionary[String, TerrainModuleSocket] = {}
) -> Distribution:
	var res: Dictionary = augment_distribution_with_factor(
		dist_in,
		origin_world,
		terrain_index,
		fill_prob_base
	)
	return res["dist"] as Distribution

func augment_distribution_with_factor(
	dist_in: Distribution,
	origin_world: Vector3,
	terrain_index: TerrainIndex,
	fill_prob_base: float
) -> Dictionary:
	# Returns:
	# - "dist": Distribution (normalised)
	# - "factor": float (sum ratio vs original; 1.0 means no net change)
	var out: Distribution = dist_in.copy()
	var factor: float = 1.0
	var done: bool = false

	if not done and (out.dist.is_empty() or rules.is_empty()):
		done = true

	if not done and debug_prints:
		print("[ProximityTagRules] incoming dist=", out.dist)

	# Only evaluate rules for tags already present in the distribution.
	var applicable: Array[ProximityTagRule] = []
	var max_radius: float = 0.0
	if not done:
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

	if not done and applicable.is_empty():
		if debug_prints:
			print("[ProximityTagRules] no applicable rules (no matching tags in dist)")
		done = true

	# Broad-phase: one query using max radius, then per-rule refinement.
	var he: float = max(y_half_extent, 0.0)
	var query_box: AABB = AABB(
		origin_world - Vector3(max_radius, he, max_radius),
		Vector3(max_radius * 2.0, he * 2.0, max_radius * 2.0)
	)

	var nearby: Array = []
	if not done:
		nearby = terrain_index.query_box(query_box)
		if nearby.is_empty():
			if debug_prints:
				print("[ProximityTagRules] query_box returned 0 candidates, box=", query_box)
			done = true

	if not done and debug_prints:
		print(
			"[ProximityTagRules] origin=",
			origin_world,
			" candidates=",
			nearby.size(),
			" rules=",
			applicable.size()
		)

	var counts: Dictionary[String, int] = {}
	if not done:
		for r: ProximityTagRule in applicable:
			counts[r.tag] = 0

	# Debug: how many candidates even have the rule tags?
	var candidates_with_tag: Dictionary[String, int] = {}
	if not done and debug_prints:
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

	if not done:
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

	if not done and debug_prints:
		print("[ProximityTagRules] match_counts_in_radius=", counts)

	# Apply rule weights using the match counts.
	#
	# Key identity (why this can drive fill_prob too):
	# - We adjust raw tag weights, then normalise.
	# - We also scale fill_prob by factor = (new_sum / old_sum).
	# Then:
	#   P(place tag t) = fill_prob_base * (w'_t / old_sum)
	# so we can directly target an *overall* probability by choosing w'_t accordingly.
	var old_sum: float = 0.0 # expected ~1.0 (incoming dist should be normalised)
	if not done:
		for k0: String in dist_in.dist.keys():
			old_sum += float(dist_in.dist[k0])
		assert(
			is_equal_approx(old_sum, 1.0),
			"dist_in must be normalised: sum=%s dist=%s" % [str(old_sum), str(dist_in.dist)]
		)
		if old_sum <= 0.0 or fill_prob_base <= 0.0:
			done = true

	var any_change: bool = false
	if not done:
		for r: ProximityTagRule in applicable:
			var c: int = int(counts[r.tag])
			if c <= 0:
				continue
			var base_weight: float = dist_in.prob(r.tag)
			var base_overall: float = fill_prob_base * (base_weight / old_sum)

			var target_overall: float = clampf(r.prob_if_any, 0.0, 1.0)
			if target_overall <= 0.0:
				continue

			var desired_overall: float = target_overall
			var n: float = r.n_to_return
			if n > 0.0:
				var delta_per_extra: float = (target_overall - base_overall) / n
				desired_overall = target_overall - float(c - 1) * delta_per_extra
				# After n extra matches, we're back at base.
				if float(c - 1) >= n:
					desired_overall = base_overall

			# Keep within the [base_overall, target_overall] range (in either direction).
			var lo: float = min(base_overall, target_overall)
			var hi: float = max(base_overall, target_overall)
			desired_overall = clampf(desired_overall, lo, hi)

			# Convert desired overall probability into the raw weight needed.
			var new_weight: float = (desired_overall / fill_prob_base) * old_sum
			out.set_prob(r.tag, max(new_weight, 0.0))
			any_change = true
			if debug_prints:
				print(
					"[ProximityTagRules] tag=",
					r.tag,
					" count=",
					c,
					" base_overall=",
					base_overall,
					" target_overall=",
					target_overall,
					" n_to_return=",
					n,
					" desired_overall=",
					desired_overall,
					" new_weight=",
					new_weight
				)

	if not done and any_change:
		var sum_before_norm: float = 0.0
		for k: String in out.dist.keys():
			sum_before_norm += float(out.dist[k])
		if sum_before_norm > 0.0:
			factor = sum_before_norm / old_sum
			out.normalise()
			if debug_prints:
				print(
					"[ProximityTagRules] factor=",
					factor,
					" normalised dist=",
					out.dist
				)
		else:
			out = dist_in.copy()
			factor = 1.0

	if not done and not any_change and debug_prints:
		print("[ProximityTagRules] no matches in radius; factor stays 1.0")

	return {"dist": out, "factor": factor}

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
