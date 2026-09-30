extends RefCounted
## Review probe (September 27, issue D): which feature owns the dead-end path,
## and whether its route edge is walkable on the natural and graded regions.
func run(review:Node3D)->void:
 var player:Vector3=review._views[0].player
 var chunk:=FieldTerrainStreamer.chunk_of(player)
 var input:Dictionary=review._inputs[chunk]
 var ground:FeatureGroundField=input.features.ground_field()
 var out:=[]
 out.append("node cells near: %s"%str(ground._node_cells.keys().filter(func(c):return (c-Vector2i(48,22)).length()<6)))
 for cx in range(44,54):
  for cz in range(19,26):
   var m:int=ground._connection_masks.get(Vector2i(cx,cz),0)
   if m!=0:out.append("mask %s = %d"%[Vector2i(cx,cz),m])
 for x in range(1185,1135,-3):
  var q:=Vector2(x,527.4)
  var ids:=[]
  for shape:FeatureGroundShape in ground._surface_buckets.get(ground._bucket_of(q),[]):
   if shape.contains(q):ids.append("%s(s%d p%d)"%[shape.stable_id,shape.surface_id,shape.priority])
  out.append("x %d lattice %s shapes %s"%[x,ground._path_at_cell(q,Vector2i(roundi(q.x/24.0),roundi(q.y/24.0))),ids])
 var natural:HeightfieldRegion=review._streamer._fields.region(chunk)
 var graded:HeightfieldRegion=input.region
 # Route cells are 24 m (cell c = lattice point 2c); storeys are read per point.
 for pair in [[Vector2i(49,22),Vector2i.LEFT],[Vector2i(48,22),Vector2i.LEFT],[Vector2i(50,22),Vector2i.LEFT]]:
  var p0:Vector2i=pair[0]*PathProgram.POINTS_PER_ROUTE_CELL
  var p1:Vector2i=(pair[0]+pair[1])*PathProgram.POINTS_PER_ROUTE_CELL
  var w0:=Vector2(pair[0])*PathProgram.ROUTE_CELL
  var w1:=Vector2(pair[0]+pair[1])*PathProgram.ROUTE_CELL
  out.append("edge %s %s natural point storeys %d->%d walkable(natural)=%s walkable(graded)=%s natural_y %.2f/%.2f graded_y %.2f/%.2f"%[pair[0],pair[1],natural.storey_at(p0.x,p0.y),natural.storey_at(p1.x,p1.y),
   PathProgram.is_route_edge_walkable(natural,pair[0],pair[1]),PathProgram.is_route_edge_walkable(graded,pair[0],pair[1]),
   TerrainTileField.surface_y(natural,w0.x,w0.y),TerrainTileField.surface_y(natural,w1.x,w1.y),
   TerrainTileField.surface_y(graded,w0.x,w0.y),TerrainTileField.surface_y(graded,w1.x,w1.y)])
 out.append("grades %d native controls %d"%[graded.terrain_grades.size(),graded.native_control_heights.size()])
 for x in range(1180,1140,-2):
  out.append("x %d natural %.2f graded %.2f"%[x,TerrainTileField.surface_y(natural,x,527.4),TerrainTileField.surface_y(graded,x,527.4)])
 FileAccess.open(review._output_dir+"/dead-end-owner.txt",FileAccess.WRITE).store_string("\n".join(out))
 print("[dead_end_owner] done")
