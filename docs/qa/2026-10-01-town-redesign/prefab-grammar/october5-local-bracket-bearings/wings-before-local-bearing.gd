extends RefCounted
## Lower an end or corner of a repeated stack into an inhabited roofed wing.
## All construction stays inside the original reservation. Door rooms, carried
## external construction and walked surfaces are immutable.
static func shape(mass: BuildingMass, covered: Callable, walked: Callable) -> bool:
	if mass.storeys.size()<2: return false
	var top: Dictionary = mass.storeys.back()
	var rect := BuildingDesigner._bounds(top.cells)
	var rectangular: bool = top.cells.size()==rect.size.x*rect.size.y
	var axis := 0 if rect.size.x>=rect.size.y else 1
	if rect.size[axis]<4 or rect.size[1-axis]<2: return false
	var rng := RandomNumberGenerator.new()
	rng.seed=hash([mass.seed,&"stepped.wing"])
	var width := mini(3,rect.size[axis]/2)
	var sides: Array[int] = [0,1]
	if rng.randf()>=0.5: sides.reverse()
	# The lower wing always retains at least one inhabited storey.
	var cut_levels := mini(2,mass.storeys.size()-1) if rng.randf()<0.5 else 1
	var candidates: Array[Rect2i] = []
	# Broad stacks can retain an L-shaped upper house around a lower corner
	# pavilion. Both arms remain at least two modules wide for native roofs.
	if mini(rect.size.x,rect.size.y)>=4:
		var corner_size := Vector2i(mini(3,rect.size.x-2),mini(3,rect.size.y-2))
		var corners: Array[Vector2i] = [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]
		var start := rng.randi_range(0,3)
		for offset in 4:
			var corner := corners[(start+offset)%4]
			candidates.append(Rect2i(rect.position+corner*(rect.size-corner_size),corner_size))
	for side: int in sides:
		var end := rect
		end.size[axis]=width
		if side==1: end.position[axis]=rect.end[axis]-width
		candidates.append(end)
	if not rectangular:
		# Compound crowns already have native roofable ranges. Try a complete
		# range as a lower wing; never cut through a one-module throat.
		for part: Rect2i in BuildingDesigner.decompose(top.cells):
			if mini(part.size.x,part.size.y)>=2 and part.get_area()<top.cells.size():
				candidates.append(part)
	# The sampled depth is a preference, not an all-or-nothing admission.
	# A middle-floor balcony can rule out a two-storey cut while a complete
	# roofed wing one storey below the crown remains valid. Keep every bearing,
	# door and public-floor proof for the shallower candidate as well.
	var depths: Array[int] = [cut_levels]
	if cut_levels > 1: depths.append(1)
	for depth: int in depths:
		for wing: Rect2i in candidates:
			var cut := BuildingMass.rect_cells(wing)
			var remaining: Dictionary = top.cells.duplicate()
			var contained := true
			for cell: Vector2i in cut:
				if not remaining.has(cell): contained=false
				remaining.erase(cell)
			if not contained or remaining.is_empty(): continue
			if not preload("res://scripts/terrain/features/villages/kit/KitLoggias.gd")._connected(remaining): continue
			var roofable := true
			for part: Rect2i in BuildingDesigner.decompose(remaining):
				if mini(part.size.x,part.size.y)<2: roofable=false
			if not roofable: continue
			var first := mass.storeys.size()-depth
			var lower: Dictionary = mass.storeys[first-1]
			var valid := true
			for cell: Vector2i in cut:
				if not lower.cells.has(cell): valid=false
			for index in range(first,mass.storeys.size()):
				var storey: Dictionary = mass.storeys[index]
				if int(storey.floor_band)!=int(lower.floor_band)+2*(index-first+1): valid=false
				if storey.cells!=top.cells or bool(storey.get("abutted",false)) \
						or bool(storey.get("bears_balcony",false)): valid=false
				for cell: Vector2i in cut:
					for band in range(int(storey.floor_band),int(storey.floor_band)+3):
						if covered.is_valid() and bool(covered.call(cell,band)): valid=false
						if walked.is_valid() and bool(walked.call(cell,band)): valid=false
				for edge: Vector3i in storey.openings:
					if cut.has(Vector2i(edge.x,edge.y)): valid=false
			if not valid: continue
			for index in range(first,mass.storeys.size()):
				var storey: Dictionary = mass.storeys[index]
				# Storeys can share the original footprint dictionary.
				storey.cells=storey.cells.duplicate()
				for cell: Vector2i in cut: storey.cells.erase(cell)
				storey["stepped_wing"]=true
			var roofed: Dictionary = lower.get("roofed",{}).duplicate()
			roofed.merge(cut)
			lower["roofed"]=roofed
			var parts: Array = lower.get("crown_parts",[]).duplicate()
			parts.append(cut)
			lower["crown_parts"]=parts
			return true
	return false
