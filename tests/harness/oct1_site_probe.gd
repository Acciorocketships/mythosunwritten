extends RefCounted
## Run through cliff_site_review's `probe` command (October 1 owner review):
## per site, the 12 m point heights (storey/level), the walls nearby, and the
## rendered surface (physics ray) minus the tile kernel on a 2 m grid.
const SITES:={"A_path":Vector2(696.0,1143.0),"C_divot":Vector2(482.7,966.8),"D_lips":Vector2(319.0,995.0)}

func run(review:Node3D)->void:
 print("[oct1_site_probe] start")
 var space:=review.get_world_3d().direct_space_state
 var out:=FileAccess.open(review._output_dir+"/probe.txt",FileAccess.WRITE)
 for site:String in SITES:
  var c:Vector2=SITES[site]
  var chunk:=FieldTerrainStreamer.chunk_of(Vector3(c.x,0,c.y))
  if not review._inputs.has(chunk):
   out.store_line("%s: chunk %s not collected" % [site,chunk]);continue
  var region=review._inputs[chunk].region
  var p:=Vector2i(TerrainTileField.point_of(c.x),TerrainTileField.point_of(c.y))
  out.store_line("== %s centre point %s (rows z, cols x; storey.level)" % [site,p])
  for dz in range(-3,4):
   var row:=""
   for dx in range(-3,4):
    var q:=p+Vector2i(dx,dz)
    row+="%3d.%d " % [region.storey_at(q.x,q.y),int(region.surface_height(q.x,q.y))-4*int(region.storey_at(q.x,q.y))]
   out.store_line("z=%d  %s" % [p.y+dz,row])
  for wall:Dictionary in TerrainTileField.wall_segments(region,Rect2(c-Vector2(18,18),Vector2(36,36))):
   out.store_line("wall a=%s b=%s top=%s bottom=%s normal=%s" % [wall.a,wall.b,wall.top,wall.bottom,wall.normal])
  # Rendered minus kernel, 2 m grid over 40 m.
  out.store_line("rendered - kernel (m), x across, z down, 2 m grid from %s" % [c-Vector2(20,20)])
  for k in 21:
   var row:=""
   for i in 21:
    var x:=c.x-20+i*2.0;var z:=c.y-20+k*2.0
    var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,400,z),Vector3(x,-100,z)))
    if hit.is_empty():row+="  ?  ";continue
    var dev:float=hit.position.y-TerrainTileField.surface_y(region,x,z)
    row+="%5.1f" % dev
   out.store_line(row)
 out.close()
 print("[oct1_site_probe] done")
