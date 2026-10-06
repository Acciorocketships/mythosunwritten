extends RefCounted
## Closed native decorative window panels on solid retaining masonry.
## These do not reserve rooms or remove the structural backing.
const ASSET := &"pure_village.stone.retaining_window"
static func fit(masses: Array[BuildingMass], placements: Array[Dictionary], kit: BuildingKit,
		catalog: EnvironmentCatalog, air: Array[Dictionary], towers: Array[Dictionary], context: Dictionary = {}) -> Array[Dictionary]:
	var descriptor := catalog.descriptor(ASSET)
	if descriptor == null: return []
	var out: Array[Dictionary] = []
	for mass: BuildingMass in masses:
		if mass.stable_id not in [&"kit.retained", &"kit.tunnel-ceilings"]: continue
		for storey: Dictionary in mass.storeys:
			if not storey.get("retaining",false) or int(storey.get("bands",2))<2: continue
			for slot: Dictionary in BuildingKitAssembler.wall_slots(storey.cells,false):
				# Two-module tunnel piers still have enough native wall width
				# for one complete panel. The backing/clearance proofs below
				# decide whether it fits; the old run-length gate left them blank.
				if int(slot.count) == 2:
					if int(slot.index) != posmod(int(storey.floor_band) / 2, 2): continue
				else:
					if slot.count<3 or slot.index==0 or slot.index==slot.count-1: continue
					if posmod(int(slot.index)+int(storey.floor_band)/2,3)!=1: continue
				var centre: Vector2 = slot.centre*kit.module_width
				var basis := Basis(Vector3.UP,BuildingKitAssembler.yaw_for_dir(slot.dir))
				var y := (float(storey.floor_band)+1.0)*kit.band_height()-descriptor.measured_aabb.get_center().y
				var pose := Transform3D(basis,Vector3(centre.x,y,centre.y)+basis.z*(kit.wall_face-descriptor.measured_aabb.position.z+0.01))
				var box: AABB = pose*descriptor.measured_aabb
				var backed := false
				var backing_wall := {}
				var local_window: AABB = descriptor.measured_aabb
				for wall: Dictionary in placements:
					if wall.get("role",&"")!=&"wall.stone.retaining": continue
					var relative: Transform3D = pose.affine_inverse()*wall.transform
					if relative.basis.z.normalized().dot(Vector3.BACK)<0.99: continue
					var backing: AABB = relative*catalog.descriptor(wall.asset_id).measured_aabb
					if backing.position.x>local_window.position.x or backing.end.x<local_window.end.x: continue
					if backing.position.y>local_window.position.y or backing.end.y<local_window.end.y: continue
					var seated := bool(wall.get("retaining_flight_joint",false))
					if absf(backing.end.z-local_window.position.z)>(0.5 if seated else 0.15): continue
					if wall.get("retaining_ceiling",INF)<pose.origin.y+local_window.end.y: continue
					if seated:
						# Follow the actual masonry face when its landing joint
						# seats the complete panel farther inside the massif.
						pose.origin += pose.basis.z*(backing.end.z-local_window.position.z+0.01)
						box = pose*descriptor.measured_aabb
					backing_wall = wall
					backed = true
					break
				if not backed: continue
				if not preload("res://scripts/terrain/features/villages/kit/KitTownFacadeBays.gd").clear_of(box,air):
					preload("res://scripts/terrain/features/villages/kit/KitRetainingRecesses.gd").replace(backing_wall,catalog,air,context)
					continue
				var blocked := false
				for part: Dictionary in placements:
					if String(part.stable_id).begins_with(String(mass.stable_id)+"/") and part.get("role",&"") not in [&"retaining.corbel",&"retaining.window"]: continue
					if box.intersects(part.transform*catalog.descriptor(part.asset_id).measured_aabb): blocked=true; break
				for tower: Dictionary in towers:
					if box.intersects(tower.bounds): blocked=true
				for part: Dictionary in out:
					if box.intersects(part.bounds): blocked=true
				if blocked: continue
				out.append({"asset_id":ASSET,"role":&"retaining.window","transform":pose,"bounds":box,"collision":true,
					"stable_id":StringName("%s/window.%d" % [mass.stable_id,out.size()])})
	return out
