extends RefCounted
## Whole native round shafts tied into two exterior walls at a building corner.
## Original full base/window/cap stock; no roof-perched fallback.
const TOWER := preload("res://scripts/terrain/features/villages/kit/KitTowerAssembly.gd")
const CAP_CORE := "res://terrain/environment/geometry/pure_village_corner_cap_core.bin"
const HOST := preload("res://scripts/terrain/features/villages/kit/KitTowerHostFit.gd")


static func propose(
	host: BuildingMass,
	kit: BuildingKit,
	catalog: EnvironmentCatalog,
	public_air: Array[Dictionary],
	envelopes: Array[Dictionary],
	previous: Array[Dictionary],
	blocked: Callable,
	bearing: Callable,
	audit: Dictionary = {}
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([host.seed, "corner.tower"])
	var tried := {}
	for roof: Dictionary in host.roofs:
		for base: int in base_bands(host, int(roof.eave_band)):
			var height := int(roof.eave_band) - base
			var rect: Rect2i = roof.rect
			var corners: Array[Vector2i] = [
				rect.position,
				Vector2i(rect.end.x, rect.position.y),
				rect.end,
				Vector2i(rect.position.x, rect.end.y)
			]
			var first := rng.randi_range(0, 3)
			for offset in 4:
				var corner := corners[(offset + first) % 4]
				var key := str(corner, ":", roof.eave_band, ":", base)
				if tried.has(key):
					continue
				tried[key] = true
				audit["corner_attempts"] = int(audit.get("corner_attempts", 0)) + 1
				var outward := Vector2(corner) - (Vector2(rect.position) + Vector2(rect.size) * 0.5)
				var pose := Transform3D(
					Basis(Vector3.UP, atan2(outward.x, outward.y)),
					Vector3(
						corner.x * kit.module_width,
						base * kit.band_height(),
						corner.y * kit.module_width
					)
				)
				var candidate := TOWER.fit(
					host,
					kit,
					catalog,
					pose,
					height / 2,
					TOWER.Form.ROUND,
					blocked,
					bearing,
					narrow_parts(height / 2),
					audit
				)
				if candidate.is_empty():
					audit["corner_no_bearing_or_space"] = (
						int(audit.get("corner_no_bearing_or_space", 0)) + 1
					)
					continue
				candidate["attachment"] = &"corner"
				candidate["opening_reach"] = 1.8  # Adjacent opening panel plus the narrow shaft.
				candidate["cap_core_path"] = CAP_CORE
				var plan := HOST.prepare(host, kit, catalog, candidate, audit)
				if plan.is_empty():
					audit["corner_no_host_join"] = int(audit.get("corner_no_host_join", 0)) + 1
					continue
				audit["corner_supported"] = int(audit.get("corner_supported", 0)) + 1
				var box: AABB = candidate.bounds
				var clear := true
				for air: Dictionary in public_air:
					if box.intersects(air.bounds):
						audit["corner_public_blocked"] = (
							int(audit.get("corner_public_blocked", 0)) + 1
						)
						clear = false
						break
				if not clear:
					continue
				for item: Dictionary in envelopes:
					if not box.intersects(item.bounds):
						continue
					if (
						item.host != host.stable_id
						or String(item.role).begins_with("chimney.")
						or String(item.role).contains("dormer")
					):
						audit["corner_asset_blocked"] = (
							int(audit.get("corner_asset_blocked", 0)) + 1
						)
						clear = false
						break
				if not clear:
					continue
				for other: Dictionary in previous:
					if box.intersects(other.bounds):
						clear = false
						break
				if not clear:
					continue
				candidate["host"] = host
				candidate["kit"] = kit
				candidate["host_plan"] = plan
				audit["corner_accepted"] = int(audit.get("corner_accepted", 0)) + 1
				return candidate
	return {}


static func narrow_parts(storeys: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index in storeys:
		var suffix := "middle" if index == 0 and storeys > 1 else "window"
		out.append(
			{
				"asset_id": StringName("pure_village.roof_turret." + suffix),
				"role": StringName("tower." + suffix),
				"transform": Transform3D(Basis.IDENTITY, Vector3.UP * (index * TOWER.COURSE))
			}
		)
	out.append(
		{
			"asset_id": &"pure_village.roof_turret.roof",
			"role": &"tower.roof",
			"transform": Transform3D(Basis.IDENTITY, Vector3.UP * (storeys * TOWER.COURSE - 0.25))
		}
	)
	return out


## A compound house may stand on multiple terrace datums. Try real floors,
## never arbitrary shaft heights; geometric fitting still proves continuous
## corner walls, a complete bearing footprint and the entire public envelope.
static func base_bands(host: BuildingMass, eave: int) -> Array[int]:
	var out: Array[int] = []
	var height := eave - host.ground_band
	if height >= 2 and height <= 8 and height % 2 == 0:
		out.append(host.ground_band)
	var floors: Array[int] = []
	for storey: Dictionary in host.storeys:
		var base := int(storey.floor_band)
		var rise := eave - base
		if rise < 4 or rise > 8 or rise % 2 != 0 or out.has(base) or floors.has(base):
			continue
		floors.append(base)
	floors.sort()
	out.append_array(floors)
	return out
