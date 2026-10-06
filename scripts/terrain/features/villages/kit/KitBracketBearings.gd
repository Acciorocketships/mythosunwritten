extends RefCounted
## Wall contacts of the actual generated balcony brackets, in module/band units.
## A vertex can belong to four room cells; preserve every touching room so a
## later shape change cannot strand a bracket on the removed side of a joint.
static func cells(masses: Array[BuildingMass]) -> Dictionary:
	var contacts: Dictionary = {}
	for mass: BuildingMass in masses:
		for part: Dictionary in mass.decor:
			if part.kind != &"raker" or not part.has("from"): continue
			var point: Vector3 = part.from
			for dx in [-.001,.001]:
				for dz in [-.001,.001]:
					contacts[Vector3i(floori(point.x+dx),floori(point.y),floori(point.z+dz))]=true
	return contacts
