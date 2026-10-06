extends RefCounted
## Ground street paint derives from the public cell union, never the town bounds.
## Round both exterior tips and interior bends. Shared edges retain full width;
## concave fillets use the same polygon in analytic paint and visible ground.
const CORNER_FRACTION := 0.45
const CORNERS: Array[Vector2i] = [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)]

static func rounded_corners(cell: Vector3i, occupied: Dictionary) -> Array[bool]:
	var out: Array[bool] = []
	for corner: Vector2i in CORNERS:
		out.append(not occupied.has(cell+Vector3i(corner.x,0,0))
			and not occupied.has(cell+Vector3i(0,0,corner.y)))
	return out

static func shapes(cells: Array[Vector3i], frame: Transform3D,
		owner: StringName) -> Array[FeatureGroundShape]:
	var out: Array[FeatureGroundShape] = []
	var occupied := {}
	for cell: Vector3i in cells: occupied[cell] = true
	var scale := VillageWorldScale.scale_of(frame)
	var half := FabricRecipe.CELL_SIZE * scale * 0.5
	var radius := half * 2.0 * CORNER_FRACTION
	var yaw := atan2(frame.basis.x.z, frame.basis.x.x)
	for cell: Vector3i in cells:
		var p := frame * (Vector3(cell) * FabricRecipe.CELL_SIZE)
		var centre := Vector2(p.x,p.z)
		var id := StringName("%s.ground.%d.%d" % [owner,cell.x,cell.z])
		var rounded := rounded_corners(cell,occupied)
		if not rounded.has(true):
			out.append(_rect(centre,Vector2.ONE*half,yaw,id))
			continue
		out.append(_rect(centre,Vector2(half,half-radius),yaw,StringName("%s.x" % id)))
		out.append(_rect(centre,Vector2(half-radius,half),yaw,StringName("%s.z" % id)))
		for i in 4:
			var sign_value := Vector2(CORNERS[i])
			var corner_id := StringName("%s.corner%d" % [id,i])
			if rounded[i]:
				out.append(FeatureGroundShape.circle(centre+(sign_value*(half-radius)).rotated(yaw),
					radius,FeatureGroundField.WORN_PATH,VillagePlan.SURFACE_PRIORITY,corner_id))
			else:
				out.append(_rect(centre+(sign_value*(half-radius*0.5)).rotated(yaw),
					Vector2.ONE*radius*0.5,yaw,corner_id))
	for polygon: PackedVector2Array in inner_fillets(cells):
		var world := PackedVector2Array()
		for point: Vector2 in polygon:
			var p := frame * Vector3(point.x,0,point.y)
			world.append(Vector2(p.x,p.z))
		out.append(FeatureGroundShape.polygon(world,FeatureGroundField.WORN_PATH,
			VillagePlan.SURFACE_PRIORITY,StringName("%s.fillet.%d" % [owner,out.size()])))
	return out

## Exactly three occupied quadrants identify one concave union corner. The
## fourth receives a small tangent arc, without rounding any shared street edge.
static func inner_fillets(cells: Array[Vector3i]) -> Array[PackedVector2Array]:
	var occupied := {}
	for cell: Vector3i in cells: occupied[cell] = true
	var out: Array[PackedVector2Array] = []
	var half := FabricRecipe.CELL_SIZE*0.5
	var radius := FabricRecipe.CELL_SIZE*CORNER_FRACTION
	for cell: Vector3i in cells:
		for sign_value: Vector2i in CORNERS:
			if not occupied.has(cell+Vector3i(sign_value.x,0,0)) or not occupied.has(cell+Vector3i(0,0,sign_value.y)):
				continue
			if occupied.has(cell+Vector3i(sign_value.x,0,sign_value.y)): continue
			var corner := Vector2(cell.x,cell.z)*FabricRecipe.CELL_SIZE+Vector2(sign_value)*half
			var polygon := PackedVector2Array([corner])
			for step in 9:
				var angle := PI+float(step)*PI/16.0
				polygon.append(corner+Vector2(sign_value)*(Vector2.ONE*radius+Vector2.from_angle(angle)*radius))
			if sign_value.x*sign_value.y < 0: polygon.reverse()
			out.append(polygon)
	return out

static func _rect(centre: Vector2, half: Vector2, yaw: float,
		id: StringName) -> FeatureGroundShape:
	return FeatureGroundShape.oriented_rect(centre,half,yaw,
		FeatureGroundField.WORN_PATH,VillagePlan.SURFACE_PRIORITY,id)

## Review/retained-ground skin of the same boundary. Production natural terrain
## reads the analytic shapes above; the public collision union stays unchanged.
static func mesh(cells: Array[Vector3i]) -> Dictionary:
	var occupied := {}
	for cell: Vector3i in cells: occupied[cell] = true
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var half := FabricRecipe.CELL_SIZE*0.5
	var radius := half*2.0*CORNER_FRACTION
	for cell: Vector3i in cells:
		var centre := Vector3(cell)*FabricRecipe.CELL_SIZE+Vector3.UP*0.025
		var polygon := PackedVector2Array()
		var rounded := rounded_corners(cell,occupied)
		for i in 4:
			var sign_value := Vector2(CORNERS[i])
			if not rounded[i]:
				polygon.append(sign_value*half)
				continue
			for step in 9:
				var angle := PI+float(i)*PI*0.5+float(step)*PI/16.0
				polygon.append(sign_value*(half-radius)+Vector2.from_angle(angle)*radius)
		var base := vertices.size()
		vertices.append(centre)
		normals.append(Vector3.UP)
		uvs.append(Vector2(centre.x,centre.z)/3.0)
		for point: Vector2 in polygon:
			var p := centre+Vector3(point.x,0,point.y)
			vertices.append(p)
			normals.append(Vector3.UP)
			uvs.append(Vector2(p.x,p.z)/3.0)
		for i in polygon.size():
			indices.append_array(PackedInt32Array([base,base+1+i,base+1+(i+1)%polygon.size()]))
	var levels := {}
	for cell: Vector3i in cells:
		if not levels.has(cell.y): levels[cell.y] = [] as Array[Vector3i]
		levels[cell.y].append(cell)
	for level: int in levels:
		for polygon: PackedVector2Array in inner_fillets(levels[level]):
			var base := vertices.size()
			for point: Vector2 in polygon:
				vertices.append(Vector3(point.x,level*FabricRecipe.CELL_SIZE+0.025,point.y))
				normals.append(Vector3.UP)
				uvs.append(point/3.0)
			var triangles := Geometry2D.triangulate_polygon(polygon)
			for index: int in triangles: indices.append(base+index)
	return {"vertices":vertices,"normals":normals,"uvs":uvs,"indices":indices}
