class_name KitRoofJunctions
extends RefCounted
## Reconcile roof wings, within one house and across house ownership.
##
## Collinear equal-profile neighbours merge into one roof. A narrower wing
## whose end meets a host roof of the same eave becomes a BRANCH: its gable is
## withdrawn and its pieces run into the host until the host buries the whole
## end section. A perpendicular branch runs to the host's ridge line and is
## clipped there (`clip_min` / `clip_max`, module units), so an equal-depth
## branch meets the ridge instead of poking out of the far slope; a parallel
## (stepped) branch runs half a module past the host's gable wall. Gaps of one
## module are short roofed lanes; a caller checks all newly covered air
## against the sealed public grid.
static func join(masses: Array[BuildingMass], clear: Callable = Callable()) -> int:
	var joins := _merge_collinear(masses, clear)
	var roofs: Array[Dictionary] = []
	for mass: BuildingMass in masses: roofs.append_array(mass.roofs)
	for branch: Dictionary in roofs:
		for end in 2:
			if bool(branch["open_" + _key(end)]): continue
			var best: Dictionary = {}
			var best_gap := 2
			for host: Dictionary in roofs:
				if is_same(branch, host) or host.eave_band != branch.eave_band: continue
				var gap := host_gap(branch, end, host)
				if gap < 0 or gap >= best_gap: continue
				if not _gap_clear(branch, end, gap, clear): continue
				best = host
				best_gap = gap
			if best.is_empty(): continue
			open_into(branch, end, best, best_gap)
			joins += 1
	# Dormers at a new valley would expose a half-window after trimming.
	# Keep full dormers on free slopes, use plain roof modules at junctions.
	for roof: Dictionary in roofs:
		var r: Rect2i = roof.rect
		var axis := int(roof.axis)
		for key: Vector2i in roof.dormers.keys():
			var point := Vector2.ZERO
			point[axis] = key.y
			point[1 - axis] = r.end[1 - axis] if key.x == 0 else r.position[1 - axis]
			for other: Dictionary in roofs:
				if is_same(roof, other) or other.eave_band != roof.eave_band: continue
				if Rect2(other.rect).grow(1.0).has_point(point):
					roof.dormers.erase(key)
					break
	return joins


static func _key(end: int) -> String:
	return "min" if end == 0 else "max"


## Adjacent short parallel piles can be one range. Reorient the ridge along
## the united footprint instead of merely welding the overlapping eaves.
## The caller must prove the ENTIRE new envelope: unlike a collinear join,
## this changes slope heights even inside the old roof footprints.
static func combine_parallel(masses: Array[BuildingMass], fits: Callable) -> int:
	if not fits.is_valid(): return 0
	var count := 0
	var changed := true
	while changed:
		changed = false
		for ai in masses.size():
			for a: Dictionary in masses[ai].roofs:
				for bi in range(ai, masses.size()):
					for b: Dictionary in masses[bi].roofs.duplicate():
						if is_same(a,b) or a.axis != b.axis or a.eave_band != b.eave_band: continue
						if a.open_min or a.open_max or b.open_min or b.open_max: continue
						var ar: Rect2i = a.rect
						var br: Rect2i = b.rect
						var axis := int(a.axis)
						var side := 1-axis
						if ar.size[axis] > 3 or br.size[axis] > 3: continue
						if ar.position[axis] != br.position[axis] or ar.end[axis] != br.end[axis]: continue
						if ar.end[side] != br.position[side] and br.end[side] != ar.position[side]: continue
						var united := ar.merge(br)
						var ridge := 0 if united.size.x >= united.size.y else 1
						if united.size[1-ridge] > BuildingDesigner.MAX_ROOF_DEPTH: continue
						if not bool(fits.call(masses[ai],masses[bi],united,ridge,int(a.eave_band))): continue
						a.rect = united
						a.axis = ridge
						# Slot coordinates belonged to the old slopes. Retaining them
						# would place dormers on a valley or past the new gable.
						a.dormers = {}
						a.chimney = bool(a.get("chimney",false)) or bool(b.get("chimney",false))
						a.ridge_peaks = bool(a.get("ridge_peaks",false)) or bool(b.get("ridge_peaks",false))
						masses[bi].roofs.erase(b)
						count += 1
						changed = true
						break
					if changed: break
				if changed: break
			if changed: break
	return count + _combine_same_house_ranges(masses, fits)


## A raised public walk beside a closed gable owns the space outside its
## facade. Shorten the entire verge, not just a head-height bite out of it.
## Street-level walks beneath a high eave keep the ordinary overhang.
## Run after joining: open branch ends must still reach their host roof.
static func fit_public_verges(masses: Array[BuildingMass],
		walk_cells: Array[Vector3i], kit: BuildingKit) -> void:
	var columns: Dictionary = {}
	for cell: Vector3i in walk_cells:
		var column := Vector2i(cell.x, cell.z)
		if not columns.has(column): columns[column] = []
		(columns[column] as Array).append(cell.y)
	for mass: BuildingMass in masses:
		for roof: Dictionary in mass.roofs:
			var rect: Rect2i = roof.rect
			var axis := int(roof.axis)
			var side := 1 - axis
			var top := float(roof.eave_band) + float(kit.roof_profile(rect.size[side]).height) / kit.band_height()
			for end in 2:
				var key := _key(end)
				if bool(roof["open_" + key]): continue
				for v in range(rect.position[side], rect.end[side]):
					var cell := Vector2i.ZERO
					cell[axis] = rect.position[axis] - 1 if end == 0 else rect.end[axis]
					cell[side] = v
					for band: int in columns.get(cell, []):
						if band >= int(roof.eave_band) and float(band) <= top:
							roof["verge_" + key] = kit.wall_face


## Modules between `branch`'s `end` and a host that can bury it, or -1. The
## host spans the branch's whole width and is at least as deep (a
## perpendicular host) or strictly deeper and flanking it on both sides (a
## parallel host), so the host's section contains the branch's.
static func host_gap(branch: Dictionary, end: int, host: Dictionary) -> int:
	var r: Rect2i = branch.rect
	var h: Rect2i = host.rect
	var axis := int(branch.axis)
	var side := 1 - axis
	var depth := r.size[side]
	if r.position[side] < h.position[side] or r.end[side] > h.end[side]: return -1
	if int(host.axis) != axis:
		if h.size[axis] < depth: return -1
	elif h.size[side] <= depth:
		return -1
	return r.position[axis] - h.end[axis] if end == 0 else h.position[axis] - r.end[axis]


static func _gap_clear(branch: Dictionary, end: int, gap: int, clear: Callable) -> bool:
	if gap == 0 or not clear.is_valid(): return true
	var r: Rect2i = branch.rect
	var axis := int(branch.axis)
	var bridge := r
	bridge.position[axis] = r.position[axis] - gap if end == 0 else r.end[axis]
	bridge.size[axis] = gap
	for cell: Vector2i in BuildingMass.rect_cells(bridge):
		# Both slope and gable need this air; the check deliberately includes
		# the highest possible ridge band.
		for band in range(int(branch.eave_band), int(branch.eave_band) + r.size[1 - axis] + 1):
			if not bool(clear.call(cell, band)): return false
	return true


## Opens `branch`'s `end` into `host` (see the class comment).
static func open_into(branch: Dictionary, end: int, host: Dictionary, gap: int) -> void:
	var r: Rect2i = branch.rect
	var h: Rect2i = host.rect
	var axis := int(branch.axis)
	var key := _key(end)
	var extend := gap
	if int(host.axis) != axis:
		var ridge := float(h.position[axis]) + float(h.size[axis]) * 0.5
		var reach := ridge - float(r.end[axis]) if end == 1 else float(r.position[axis]) - ridge
		extend = maxi(0, ceili(reach - 0.5))
		if float(extend) + 0.5 > reach + 0.001:
			branch["clip_" + key] = ridge
	branch["open_" + key] = true
	branch["extend_" + key] = extend
	branch.colour = host.colour


static func _merge_collinear(masses: Array[BuildingMass], clear: Callable) -> int:
	var joins := 0
	var changed := true
	while changed:
		changed = false
		for ai in masses.size():
			for a: Dictionary in masses[ai].roofs:
				for bi in range(ai, masses.size()):
					for b: Dictionary in masses[bi].roofs.duplicate():
						if is_same(a, b) or a.axis != b.axis or a.eave_band != b.eave_band: continue
						var ar: Rect2i = a.rect
						var br: Rect2i = b.rect
						var axis := int(a.axis)
						var side := 1 - axis
						if ar.position[side] != br.position[side] or ar.size[side] != br.size[side]: continue
						var gap := maxi(ar.position[axis], br.position[axis]) - mini(ar.end[axis], br.end[axis])
						if gap > 1: continue
						var united := ar.merge(br)
						var allowed := true
						if clear.is_valid():
							for cell: Vector2i in BuildingMass.rect_cells(united):
								if ar.has_point(cell) or br.has_point(cell): continue
								for band in range(int(a.eave_band), int(a.eave_band) + united.size[side] + 1):
									allowed = allowed and bool(clear.call(cell, band))
						if not allowed: continue
						var lower: Dictionary = a if ar.position[axis] <= br.position[axis] else b
						var upper: Dictionary = a if ar.end[axis] >= br.end[axis] else b
						for key: String in ["open_min", "extend_min", "clip_min"]:
							_copy_end(a, lower, key)
						for key: String in ["open_max", "extend_max", "clip_max"]:
							_copy_end(a, upper, key)
						a.rect = united
						for key: Vector2i in b.dormers: a.dormers[key] = true
						masses[bi].roofs.erase(b)
						joins += 1
						changed = true
						break
					if changed: break
				if changed: break
			if changed: break
	return joins


static func _copy_end(into: Dictionary, from: Dictionary, key: String) -> void:
	if from.has(key): into[key] = from[key]
	else: into.erase(key)


## Join the overlapping span of unequal ranges without filling their notches.
## Remaining ends must still have room for complete native roof courses.
static func _combine_same_house_ranges(masses:Array[BuildingMass],fits:Callable)->int:
	var count:=0
	if not fits.is_valid():return count
	for mass:BuildingMass in masses:
		var changed:=true
		while changed:
			changed=false
			for a:Dictionary in mass.roofs.duplicate():
				for b:Dictionary in mass.roofs.duplicate():
					if is_same(a,b) or a.axis!=b.axis or a.eave_band!=b.eave_band or a.colour!=b.colour:continue
					if a.open_min or a.open_max or b.open_min or b.open_max:continue
					var ar:Rect2i=a.rect
					var br:Rect2i=b.rect
					var axis:=int(a.axis)
					var side:=1-axis
					if ar.end[side]!=br.position[side] and br.end[side]!=ar.position[side]:continue
					var lo:=maxi(ar.position[axis],br.position[axis])
					var hi:=mini(ar.end[axis],br.end[axis])
					if hi-lo<2:continue
					var core:=ar.merge(br)
					core.position[axis]=lo
					core.size[axis]=hi-lo
					var ridge:=0 if core.size.x>=core.size.y else 1
					if core.size[1-ridge]>BuildingDesigner.MAX_ROOF_DEPTH:continue
					var remnants:Array[Dictionary]=[]
					var valid:=true
					for original:Dictionary in [a,b]:
						var rect:Rect2i=original.rect
						for span:Vector2i in [Vector2i(rect.position[axis],lo),Vector2i(hi,rect.end[axis])]:
							if span.x>=span.y:continue
							if span.y-span.x<2:valid=false;break
							var rem:=original.duplicate(true)
							var rr:=rect
							rr.position[axis]=span.x
							rr.size[axis]=span.y-span.x
							rem.rect=rr
							rem.dormers={}
							rem.chimney=false
							remnants.append(rem)
					if not valid or not fits.call(mass,mass,core,ridge,int(a.eave_band)):continue
					var joined:=a.duplicate(true)
					joined.rect=core
					joined.axis=ridge
					joined.dormers={}
					joined.ridge_peaks=bool(a.get("ridge_peaks",false)) or bool(b.get("ridge_peaks",false))
					joined.chimney=bool(a.get('chimney',false)) or bool(b.get('chimney',false))
					mass.roofs.erase(a)
					mass.roofs.erase(b)
					mass.roofs.append(joined)
					mass.roofs.append_array(remnants)
					changed=true
					count+=1
					break
				if changed:break
	return count


## Conservative height over one footprint column, including authored ridge
## ornaments only in the columns touched by the ridge. A ridge-height prism
## over the whole footprint incorrectly rejects rooms above the low eaves.
static func column_clearance_height(kit: BuildingKit, depth: int, row: int,
		ridge_head: float) -> float:
	var profile := kit.roof_profile(depth)
	var height := float(profile.height)
	var head := maxf(0.0,kit.roof_clearance_height(depth)-height)
	var bound := minf(height,float(mini(row+1,depth-row))*kit.roof_row_rise)+head
	if float(row)<=float(depth)*0.5 and float(row+1)>=float(depth)*0.5:
		var lift := kit.roof_ridge_lift.y if bool(profile.top) else kit.roof_ridge_lift.x
		bound = maxf(bound,height+maxf(0.0,lift+ridge_head))
	return bound


static func ridge_clearance_head(kit: BuildingKit, catalog: EnvironmentCatalog) -> float:
	var head := kit.roof_ridge_head
	for id: StringName in kit.roles.get(&"trim.ridge_peak",[]):
		var box: AABB = kit.anchor(&"trim.ridge_peak")*kit.asset_anchor(id) \
			* catalog.descriptor(id).measured_aabb
		head = maxf(head,box.end.y)
	return head
