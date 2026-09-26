extends RefCounted

## Recess private upper rooms within their reserved envelope. Lower rooms carry
## each terrace; retained side piers and the back wall support a room above it.
## Entrances, party walls and public crowns are immutable.
static func recess(mass: BuildingMass, forbidden: Callable, walked: Callable) -> void:
	if mass.storeys.size() < 2: return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([mass.seed, &"loggias"])
	var preferred := rng.randi_range(0, 3)
	for index in range(1, mass.storeys.size()):
		# Alternating covered loggias and an open upper terrace, on changing faces.
		if index % 2 == 0 and index != mass.storeys.size() - 1: continue
		var storey: Dictionary = mass.storeys[index]
		var band := int(storey.floor_band)
		var lower := mass.cells_at_band(band - 1)
		if lower.is_empty(): continue
		var candidates: Array[Dictionary] = []
		for run: Dictionary in BuildingKitAssembler.boundary_runs(storey.cells):
			var length := int(run.end) - int(run.start)
			if length < 4: continue
			var dir := int(run.dir)
			var width := mini(3, length - 2)
			var start := int(run.start) + 1 + rng.randi_range(0, length - width - 2)
			if length >= 5 and index == mass.storeys.size() - 1 and rng.randf() < 0.5:
				start = int(run.start) if rng.randf() < 0.5 else int(run.end) - width
			var cut := {}
			var valid := true
			for along in range(start, start + width):
				var cell := BuildingKitAssembler._inside_cell(dir, int(run.line), along)
				var back := cell - BuildingMass.DIRS[dir]
				cut[cell] = true
				if not lower.has(cell) or not storey.cells.has(back): valid = false
				for b in range(band, band + 3):
					if forbidden.is_valid() and bool(forbidden.call(cell + BuildingMass.DIRS[dir], b)): valid = false
					if walked.is_valid() and bool(walked.call(cell, b)): valid = false
				for edge: Vector3i in storey.openings:
					if Vector2i(edge.x, edge.y) == cell: valid = false
			if not valid or cut.size() * 3 > storey.cells.size(): continue
			var remaining: Dictionary = storey.cells.duplicate()
			for cell: Vector2i in cut: remaining.erase(cell)
			if not _connected(remaining): continue
			candidates.append({"cells": remaining, "dir": dir,
				"score": length + (8 if dir == preferred else 0)})
		if candidates.is_empty(): continue
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
		storey.cells = candidates[0].cells
		storey["loggia"] = true
		preferred = (int(candidates[0].dir) + 1) % 4

static func _connected(cells: Dictionary) -> bool:
	if cells.is_empty(): return false
	var seen := {}
	var pending: Array = [cells.keys()[0]]
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		if seen.has(cell): continue
		seen[cell] = true
		for step: Vector2i in BuildingMass.DIRS:
			if cells.has(cell + step) and not seen.has(cell + step): pending.append(cell + step)
	return seen.size() == cells.size()
