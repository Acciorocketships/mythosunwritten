extends RefCounted
## Fine (0.5 m) rendered-minus-kernel map around the C divot cliff end.
func run(review:Node3D)->void:
 var space:=review.get_world_3d().direct_space_state
 var out:=FileAccess.open(review._output_dir+"/divot.txt",FileAccess.WRITE)
 var chunk:=FieldTerrainStreamer.chunk_of(Vector3(484,0,966))
 var region=review._inputs[chunk].region
 out.store_line("rows z 958..974, cols x 476..492 step 0.5; each cell: rendered-kernel")
 for k in 33:
  var z:=958.0+k*0.5
  var row:="z=%6.1f " % z
  for i in 33:
   var x:=476.0+i*0.5
   var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,400,z),Vector3(x,-100,z)))
   row+=("  ?  " if hit.is_empty() else "%5.1f" % (hit.position.y-TerrainTileField.surface_y(region,x,z)))
  out.store_line(row)
 out.store_line("kernel heights")
 for k in 33:
  var z:=958.0+k*0.5
  var row:="z=%6.1f " % z
  for i in 33:
   row+="%5.1f" % TerrainTileField.surface_y(region,476.0+i*0.5,z)
  out.store_line(row)
 out.close()
 print("[oct1_divot_probe] done")
