extends RefCounted
## Fit supported native projecting windows to long upper facades after the
## town's real public headroom is known. Whole pieces compete for space;
## neither a route nor a neighboring building is cut to make a bay fit.
static func fit(masses: Array[BuildingMass], kits: Dictionary, base: BuildingKit,
		catalog: EnvironmentCatalog, air: Array[Dictionary], towers: Array[Dictionary],
		blocked: Callable) -> Array[Dictionary]:
	var obstacles: Array[Dictionary] = []
	for mass: BuildingMass in masses:
		var own := StringName(String(mass.stable_id).trim_prefix("kit."))
		for part: Dictionary in BuildingKitAssembler.new(kits.get(own,base)).assemble(mass):
			obstacles.append({"owner":&"" if String(part.role).begins_with("bay.") else mass.stable_id,
				"bounds":part.transform*catalog.descriptor(part.asset_id).measured_aabb})
	for tower: Dictionary in towers:
		obstacles.append({"owner":&"", "bounds":tower.bounds})
	var out: Array[Dictionary] = []
	for mass: BuildingMass in masses:
		var own := StringName(String(mass.stable_id).trim_prefix("kit."))
		if not kits.has(own): continue
		var kit: BuildingKit = kits[own]
		for index in range(1,mass.storeys.size()):
			var storey: Dictionary = mass.storeys[index]
			if storey.material != BuildingMass.MATERIAL_TIMBER or (storey.get("projections",[]) as Array).any(
					func(p: Dictionary) -> bool: return not bool(p.get("growth",false))): continue
			var band := int(storey.floor_band)
			var slots := BuildingDesigner.new(kit).slots_of(mass,storey)
			for slot: Dictionary in slots:
				if (storey.get("growth",{}) as Dictionary).has(int(slot.dir)): continue
				if int(slot.count) < 4 or int(slot.index) in [0,int(slot.count)-1]: continue
				var phase := posmod(hash([mass.seed,band,slot.dir,"facade.relief"]),3)
				if posmod(int(slot.index)-1,3) != phase: continue
				if storey.openings.get(slot.edge,storey.default_opening) not in [BuildingMass.OPENING_WINDOW,BuildingMass.OPENING_PLAIN]: continue
				var close := false
				for other: Dictionary in slots:
					if storey.openings.get(other.edge,storey.default_opening) == BuildingMass.OPENING_BAY \
							and (other.centre as Vector2).distance_to(slot.centre) < 1.5: close = true
				if close: continue
				var role := StringName("bay.%s" % storey.get("bay_colour",&"red"))
				if not kit.has_role(role): continue
				var id := kit.asset(role)
				var centre: Vector2 = slot.centre*kit.module_width
				var pose := Transform3D(Basis(Vector3.UP,BuildingKitAssembler.yaw_for_dir(slot.dir)),
					Vector3(centre.x,band*kit.band_height()+kit.storey_height/3.0,centre.y))*kit.anchor(role)*kit.asset_anchor(id)
				var box: AABB = pose*catalog.descriptor(id).measured_aabb
				if not clear_of(box,air): continue
				for obstacle: Dictionary in obstacles:
					if obstacle.owner != mass.stable_id and box.intersects(obstacle.bounds): close = true; break
				if close: continue
				for x in range(floori(box.position.x/kit.module_width),ceili(box.end.x/kit.module_width)):
					for z in range(floori(box.position.z/kit.module_width),ceili(box.end.z/kit.module_width)):
						for b in range(floori(box.position.y/kit.band_height()),ceili(box.end.y/kit.band_height())):
							if mass.cells_at_band(b).has(Vector2i(x,z)): continue
							if blocked.is_valid() and bool(blocked.call(own,Vector2i(x,z),b)): close = true
				if close: continue
				storey.openings[slot.edge] = BuildingMass.OPENING_BAY
				# The native bay includes its own window, canopy and supports.
				for d in range(mass.decor.size()-1,-1,-1):
					var item: Dictionary = mass.decor[d]
					if item.kind==&"window_box" and int(item.dir)==int(slot.dir) \
							and (item.centre as Vector2).distance_to(slot.centre)<0.01 \
							and absf(float(item.get("y",0))-band*kit.band_height())<0.01:
						mass.decor.remove_at(d)
				obstacles.append({"owner":&"", "bounds":box})
				out.append({"host":mass.stable_id,"bounds":box,"pose":pose,"asset_id":id,"band":band,"edge":slot.edge})
	return out

static func clear_of(box: AABB, air: Array[Dictionary]) -> bool:
	for volume: Dictionary in air:
		if box.intersects(volume.bounds): return false
	return true
