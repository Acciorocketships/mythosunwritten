extends RefCounted
## Town taste knobs task 2: on the FINAL fabric, every lawn cell standing on a
## court edge must face, at the court's walk plane, either a walk surface (with
## no rail between it and the lawn) or something no one can fall past: built
## mass at the walk band, or level ground (retained mass, built solid or terrain
## one band down). A lawn edge with none of these is an unguarded drop.


static func audit(spatial: WarrenSpatialPlan, fabric: SettlementFabricPlan) -> Dictionary:
	var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
	var solid := fabric.transformed_cells(&"solid")
	var inhabited := fabric.transformed_cells(&"inhabited")
	var retained := fabric.retained_terrace_cells
	var surface := fabric.surface_plan
	var rails := {}
	for segment: Dictionary in surface.guard_segments:
		rails[String(segment.stable_key)] = true
	var edge_lawn := 0
	var on_walk := 0
	var unguarded: Array[String] = []
	var railed: Array[String] = []
	for support: Vector3i in fabric.planned_plaza_planting_cells:
		for step: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			if fabric.planned_plaza_cells.has(support + step):
				continue
			edge_lawn += 1
			var floor := support + Vector3i.UP + step
			if surface.has_cell(floor):
				on_walk += 1
				var key := "%d:%d:%d:%d:%d" % [floor.x, floor.y, floor.z, -step.x, -step.z]
				if rails.has(key):
					railed.append("%s->%s" % [support, step])
				continue
			if solid.has(floor) or inhabited.has(floor) or retained.has(floor):
				continue
			var below := support + step
			if solid.has(below) or retained.has(below):
				continue
			var column := Vector2i(floori(below.x / 2.0), floori(below.z / 2.0))
			if source != null and source.massif != null and source.massif.has_column(column) \
					and below.y < source.massif.base_at(column):
				continue
			unguarded.append("%s->%s" % [support, step])
	return {"edge_lawn_faces": edge_lawn, "edge_lawn_on_walk": on_walk,
		"unguarded": unguarded, "railed_walk": railed}
