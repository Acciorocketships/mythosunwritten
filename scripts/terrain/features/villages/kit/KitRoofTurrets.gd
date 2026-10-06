extends RefCounted
## House_11c's roof-emergent round turret. Unlike a half-tower, this has a
## complete shaft inside the upper room and attic, not an open-backed applique.
## All visible geometry is the original, unscaled Pure Village architecture.
const TOWER := preload("res://scripts/terrain/features/villages/kit/KitTowerAssembly.gd")
const CORE := "res://terrain/environment/geometry/pure_village_roof_turret_core.bin"
const PREFIX := "pure_village.roof_turret."
const CAP_LAP := 0.25 # House_11c: cap 18.5 above the window origin 15.75.
const SHARE := 0.45

static func parts(plain_courses: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index in plain_courses + 1:
		var suffix := "window" if index == plain_courses else "middle"
		out.append({"asset_id":StringName(PREFIX+suffix),"role":StringName("tower."+suffix),
			"transform":Transform3D(Basis.IDENTITY,Vector3(0,index*TOWER.COURSE,0))})
	out.append({"asset_id":StringName(PREFIX+"roof"),"role":&"tower.roof",
		"transform":Transform3D(Basis.IDENTITY,Vector3(0,(plain_courses+1)*TOWER.COURSE-CAP_LAP,0))})
	return out

static func cutters(candidate: Dictionary) -> Array[Dictionary]:
	var core: Array = FileAccess.open(CORE,FileAccess.READ).get_var()
	var out: Array[Dictionary] = []
	# Reconstruct from present courses. Never exempt a stale clipping request
	# after its enclosing shaft has been removed (also used by roof audits).
	for part: Dictionary in candidate.parts:
		if part.asset_id == StringName(PREFIX+"middle"):
			out.append_array(TOWER.placed_cutters(core,candidate.pose*part.transform))
	return out

static func propose(host: BuildingMass, kit: BuildingKit, catalog: EnvironmentCatalog,
		public_air: Array[Dictionary], envelopes: Array[Dictionary], previous: Array[Dictionary],
		blocked: Callable, audit: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([host.seed,"roof.emergent.turret"])
	if rng.randf() >= SHARE: return {}
	for roof: Dictionary in host.roofs:
		if int(roof.eave_band) != host.top_band(): continue
		var rect: Rect2i = roof.rect
		if mini(rect.size.x,rect.size.y)<2: continue
		var axis := int(roof.axis)
		var centres: Array[Vector2] = []
		var middle := Vector2(rect.position)+Vector2(rect.size)*0.5
		# One module inside a gable gives the narrow complete cap room without
		# hanging it off the facade. Try both ends in a stable seeded order.
		for end: int in ([0,1] if rng.randf()<0.5 else [1,0]):
			var point := middle
			point[axis] = rect.position[axis]+1 if end==0 else rect.end[axis]-1
			if not centres.has(point): centres.append(point)
		for centre: Vector2 in centres:
			audit["roof_attempts"]=int(audit.get("roof_attempts",0))+1
			var eave := int(roof.eave_band)*kit.band_height()
			var base := eave-TOWER.COURSE
			var height := float(kit.roof_profile(rect.size[1-axis]).height)
			var plain := ceili((height+TOWER.COURSE)/TOWER.COURSE)
			if plain>3: continue # A very broad roof needs a designed belfry, not a needle.
			var assembly := parts(plain)
			var pose := Transform3D(Basis(Vector3.UP,float(rng.randi_range(0,3))*PI*0.5),
				Vector3(centre.x*kit.module_width,base,centre.y*kit.module_width))
			var foot: AABB = pose*assembly[0].transform*catalog.descriptor(assembly[0].asset_id).measured_aabb
			# The complete shaft rises from the host's occupied top-room floor.
			# Never use a deck, loggia, roof skin, or a neighbour as its bearing.
			foot.position.y=base+0.01
			foot.size.y=TOWER.COURSE-0.02
			var clear := true
			for cell: Vector3i in TOWER._cells(foot,kit):
				if not host.cells_at_band(cell.y).has(Vector2i(cell.x,cell.z)): clear=false;break
			if not clear: continue
			audit["roof_borne"]=int(audit.get("roof_borne",0))+1
			var box: AABB = pose*TOWER.bounds(assembly,catalog)
			for cell: Vector3i in TOWER._cells(box,kit):
				if host.cells_at_band(cell.y).has(Vector2i(cell.x,cell.z)): continue
				if blocked.is_valid() and bool(blocked.call(Vector2i(cell.x,cell.z),cell.y)): clear=false;break
			if not clear: continue
			audit["roof_reserved_clear"]=int(audit.get("roof_reserved_clear",0))+1
			for air: Dictionary in public_air:
				if box.intersects(air.bounds): clear=false;break
			if not clear: continue
			audit["roof_air_clear"]=int(audit.get("roof_air_clear",0))+1
			# The window course has a solid foot below its opening. The roof's
			# native ridge trim may overlap that foot, as in House_11c.
			# Measured indexed source primitives: ornamental sill starts at
			# y=0.881, lattice at 0.940, glass at 0.969. Keep 3 cm below them.
			var window_bottom := base+plain*TOWER.COURSE+0.85
			var piece_boxes: Array[AABB] = []
			for part: Dictionary in assembly:
				piece_boxes.append(pose*part.transform*catalog.descriptor(part.asset_id).measured_aabb)
			for item: Dictionary in envelopes:
				if not box.intersects(item.bounds): continue
				if not piece_boxes.any(func(b:AABB)->bool:return b.intersects(item.bounds)):continue
				if item.host != host.stable_id:
					audit["roof_neighbor_block"]=int(audit.get("roof_neighbor_block",0))+1
					audit["roof_neighbor_example"]=str(host.stable_id," / ",item.host," / ",item.role," / ",item.bounds)
					clear=false;break
				var role := String(item.role)
				if role.begins_with("chimney."): clear=false;break
				# Only buried room/attic structure may intersect. The window
				# opening must emerge above every crossed native roof skin.
				if (item.bounds as AABB).end.y>=window_bottom:
					audit["roof_host_block_"+role]=int(audit.get("roof_host_block_"+role,0))+1
					audit["roof_host_example"]=str(host.stable_id," / ",role," / ",item.bounds," / window ",window_bottom)
					clear=false;break
			if not clear: continue
			for other: Dictionary in previous:
				if box.intersects(other.bounds): clear=false;break
			if not clear: continue
			return {"host":host,"kit":kit,"parts":assembly,"pose":pose,"bounds":box,
				"storeys":plain+1,"form":TOWER.Form.ROUND,"attachment":&"roof",
				"host_plan":{"wings":{},"reach":0.0,"openings":[]}}
	return {}
