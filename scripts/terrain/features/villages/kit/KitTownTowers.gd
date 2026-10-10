extends RefCounted
## Native attached-tower proposals for complete town buildings. Planning is
## read-only; callers apply the host edits only after the whole envelope fits.
const TOWER := preload("res://scripts/terrain/features/villages/kit/KitTowerAssembly.gd")
const HOST := preload("res://scripts/terrain/features/villages/kit/KitTowerHostFit.gd")
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
## Fitting already excludes most crowded gables. Give almost every eligible
## multi-storey house a chance before the geometric admission checks; a
## separate low selection rate compounded those constraints into empty skylines.
const PROPOSAL_SHARE := 0.9

static func propose(masses: Array[BuildingMass], kits: Dictionary,
		default_kit: BuildingKit, catalog: EnvironmentCatalog,
		public_air: Array[Dictionary], blocked: Callable, audit: Dictionary = {}, bearing: Callable = Callable()) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var envelopes: Array[Dictionary] = []
	for mass: BuildingMass in masses:
		var own := StringName(String(mass.stable_id).trim_prefix("kit."))
		var kit: BuildingKit = kits.get(own, default_kit)
		var pieces := BuildingKitAssembler.new(kit).assemble(mass)
		for part: Dictionary in pieces:
			var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
			envelopes.append({"host": mass.stable_id, "bounds": box,"role":part.role})
	for mass: BuildingMass in masses:
		var own := StringName(String(mass.stable_id).trim_prefix("kit."))
		if not kits.has(own): continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([mass.seed, "attached.tower"])
		if not has_tower_storeys(mass): continue
		if rng.randf() >= PROPOSAL_SHARE: continue
		var kit: BuildingKit = kits.get(own, default_kit)
		var corner := preload("res://scripts/terrain/features/villages/kit/KitCornerTowers.gd").propose(
			mass,kit,catalog,public_air,envelopes,out,
			func(cell:Vector2i,band:int)->bool:return blocked.is_valid() and bool(blocked.call(own,cell,band)),
			func(cell:Vector2i,band:int)->bool:return bearing.is_valid() and bool(bearing.call(own,cell,band)),audit)
		if corner.is_empty():
			corner = preload("res://scripts/terrain/features/villages/kit/KitCornerTowers.gd").propose(
				mass,kit,catalog,public_air,envelopes,out,
				func(cell:Vector2i,band:int)->bool:return blocked.is_valid() and bool(blocked.call(own,cell,band)),
				Callable(),audit,true)
		if not corner.is_empty():
			out.append(corner)
			continue
		var accepted := false
		for roof: Dictionary in mass.roofs:
			if accepted: break
			var rect: Rect2i = roof.rect
			# Prefer an eave-side attachment near a corner. The source prefab
			# seats its tower cap at eave - ROOF_LAP, below the taller gable.
			var faces: Array[int] = [1-int(roof.axis),int(roof.axis)]
			for axis: int in faces:
				if accepted: break
				var floor_band := int(roof.eave_band)
				var ends := [0, 1] if rng.randf() < 0.5 else [1, 0]
				for end: int in ends:
					if axis == int(roof.axis) and bool(roof.get("open_min" if end == 0 else "open_max", false)): continue
					# Broad gables can carry an off-centre turret, as in the native
					# prefab assemblies. Try corner-adjacent module or half-module
					# offsets and the centre; complete measured fitting still owns admission.
					var offsets: Array[float] = [0.0]
					if rect.size[1-axis] >= 4: offsets = [-1.0,1.0,0.0]
					elif rect.size[1-axis] == 3: offsets.append_array([-0.5,0.5])
					for offset: float in offsets:
						var centre := Vector2(rect.position) + Vector2(rect.size) * 0.5
						centre[1-axis] += offset
						centre[axis] = rect.position[axis] if end == 0 else rect.end[axis]
						var direction := Vector2i.ZERO
						direction[axis] = -1 if end == 0 else 1
						var dir := BuildingMass.DIRS.find(direction)
						# House_16c uses a shaft tied into the lower wing. Do not
						# degrade a blocked shaft to a single attic ornament: that
						# reads as a cone glued to the gable, not an inhabited tower.
						for courses: int in [3, 2]:
							# Source House_16c: the cap overlaps the adjoining eave
							# by half a metre; the shaft belongs to the storeys below.
							var base := floor_band - courses * 2
							var pose := Transform3D(Basis(Vector3.UP, BuildingKitAssembler.yaw_for_dir(dir)),
								Vector3(centre.x * kit.module_width, base * kit.band_height(), centre.y * kit.module_width))
							for form: int in [TOWER.Form.GROUNDED_HALF,TOWER.Form.CORBELLED_HALF]:
								# A suspended cylinder on a flat eave-side facade failed
								# visual review. This new junction needs a real base until
								# a lower inhabited wing is planned to carry its corbel.
								if axis != int(roof.axis) and form == TOWER.Form.CORBELLED_HALF: continue
								var candidate := TOWER.fit(mass, kit, catalog, pose, courses,
									form, func(cell: Vector2i, band: int) -> bool:
										return blocked.is_valid() and bool(blocked.call(own,cell,band)),
									func(cell: Vector2i,band: int) -> bool:
										return bearing.is_valid() and bool(bearing.call(own,cell,band)))
								audit["attempts"] = int(audit.get("attempts",0)) + 1
								if candidate.is_empty(): continue
								audit["supported"] = int(audit.get("supported",0)) + 1
								candidate["attachment"] = &"eave" if axis != int(roof.axis) else &"gable"
								var plan := HOST.prepare(mass,kit,catalog,candidate)
								if plan.is_empty(): continue
								audit["host_fit"] = int(audit.get("host_fit",0)) + 1
								var box: AABB = candidate.bounds
								var clear := true
								for volume: Dictionary in public_air:
									if box.intersects(volume.bounds): clear = false; break
								if not clear: continue
								audit["public_clear"] = int(audit.get("public_clear",0)) + 1
								for item: Dictionary in envelopes:
									if item.host == mass.stable_id: continue
									if box.intersects(item.bounds): clear = false; break
								if not clear: continue
								audit["neighbor_clear"] = int(audit.get("neighbor_clear",0)) + 1
								for previous: Dictionary in out:
									if box.intersects(previous.bounds): clear = false; break
								if not clear: continue
								for index in mass.roofs.size():
									if plan.wings.has(index): continue
									if box.intersects(UNION.roof_volume(mass.roofs[index],kit).bounds): clear = false; break
								if not clear: continue
								candidate["host"] = mass
								candidate["kit"] = kit
								candidate["host_plan"] = plan
								out.append(candidate)
								accepted = true
								break
							if accepted: break
						if accepted: break
					if accepted: break
	for candidate: Dictionary in out:
		preload("res://scripts/terrain/features/villages/kit/KitTowerPalette.gd").apply(candidate)
	return out


## A turret belongs to a vertically stacked house, not a one-storey cottage
## or two neighboring single-storey wings at different ground elevations.
static func has_tower_storeys(mass: BuildingMass) -> bool:
	for storey: Dictionary in mass.storeys:
		var below := mass.cells_at_band(int(storey.floor_band)-1)
		for cell: Vector2i in storey.cells:
			if below.has(cell): return true
	return false
