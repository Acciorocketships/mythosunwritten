extends RefCounted
## Whole native corbel courses articulate retained faces without implying rooms in earth.
const ASSET := &"pure_village.stone.retaining_corbel"
static func fit(masses: Array[BuildingMass], placements: Array[Dictionary], kit: BuildingKit,
		catalog: EnvironmentCatalog, air: Array[Dictionary], towers: Array[Dictionary]) -> Array[Dictionary]:
	var descriptor := catalog.descriptor(ASSET)
	if descriptor == null: return []
	var obstacles: Array[Dictionary] = []
	for part: Dictionary in placements:
		obstacles.append({"id":"" if part.get("retaining_recess",false) or part.get("role",&"") in [&"retaining.corbel",&"retaining.window"] else String(part.stable_id),"bounds":part.transform*catalog.descriptor(part.asset_id).measured_aabb,"role":part.get("role",&"")})
	var out: Array[Dictionary] = []
	for mass: BuildingMass in masses:
		if mass.stable_id not in [&"kit.retained", &"kit.tunnel-ceilings"]: continue
		for storey: Dictionary in mass.storeys:
			var top := int(storey.floor_band)+int(storey.get("bands",2))
			if not storey.get("retaining",false) or int(storey.get("bands",2))<2: continue
			for slot: Dictionary in BuildingKitAssembler.wall_slots(storey.cells,false):
				if int(slot.count)<3 or int(slot.index)==0 or int(slot.index)==int(slot.count)-1: continue
				if posmod(int(slot.index),2)==0: continue
				# A tall earth-backed face needs intermediate relief too. The whole
				# native cap is backed by masonry; public air still vetoes projections.
				var centre: Vector2 = slot.centre*kit.module_width
				var pose := Transform3D(Basis(Vector3.UP,BuildingKitAssembler.yaw_for_dir(slot.dir)),Vector3(centre.x,float(top)*kit.band_height()-descriptor.measured_aabb.end.y-0.05,centre.y))
				var box: AABB = pose*descriptor.measured_aabb
				# Native deck undersides lie slightly below the nominal floor datum.
				# Seat the complete cap beneath them, then recheck all obstacles/air.
				# Never relocate a corbel around a floor cutting through its body.
				var cap := box.end.y
				for obstacle: Dictionary in obstacles:
					if obstacle.role != &"deck.board" or not box.intersects(obstacle.bounds): continue
					if obstacle.bounds.position.y < box.end.y - 0.1: continue
					cap = minf(cap,obstacle.bounds.position.y - 0.001)
				pose.origin.y += cap - box.end.y
				box = pose*descriptor.measured_aabb
				var blocked := not preload("res://scripts/terrain/features/villages/kit/KitTownFacadeBays.gd").clear_of(box,air)
				for obstacle: Dictionary in obstacles:
					if not obstacle.id.begins_with(String(mass.stable_id)+"/") and box.intersects(obstacle.bounds): blocked=true; break
				for tower: Dictionary in towers:
					if box.intersects(tower.bounds): blocked=true
				for part: Dictionary in out:
					if box.intersects(part.bounds): blocked=true
				if blocked: continue
				out.append({"asset_id":ASSET,"transform":pose,"bounds":box,"role":&"retaining.corbel","stable_id":StringName("%s/relief.%d" % [mass.stable_id,out.size()]),"collision":true})
	return out
