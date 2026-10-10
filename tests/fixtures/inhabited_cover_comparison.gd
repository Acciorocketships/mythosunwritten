extends RefCounted
## Compare the same walked quarter-cells, not just town-wide coverage totals.
## Missing towns/walks are regressions too; a new cover elsewhere cannot replace
## an existing enclosed passage. Negative heights mean no inhabited ceiling.


static func compare(before: Dictionary, after: Dictionary, max_band: int = 4) -> Dictionary:
	var lost: Array[Dictionary] = []
	var checked := 0
	var cities := before.keys()
	cities.sort()
	for city: String in cities:
		var old_walks: Dictionary = before[city].get("walks", {})
		var new_walks: Dictionary = after.get(city, {}).get("walks", {})
		var walks := old_walks.keys()
		walks.sort()
		for walk: String in walks:
			var old: Array = old_walks[walk]
			var current: Array = new_walks.get(walk, [])
			for quarter in old.size():
				var ceiling := int(old[quarter])
				if ceiling <= 0 or ceiling > max_band:
					continue
				checked += 1
				var replacement := int(current[quarter]) if quarter < current.size() else -1
				if replacement <= 0 or replacement > ceiling:
					lost.append(
						{
							"city": city,
							"walk": walk,
							"quarter": quarter,
							"before_band": ceiling,
							"after_band": replacement
						}
					)
	return {
		"max_band": max_band,
		"checked_quarters": checked,
		"lost_quarters": lost.size(),
		"lost": lost
	}
