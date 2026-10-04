extends RefCounted
## Coverage of a chunk's feature context (its road masks) against the chunk.
func run(review:Node3D)->void:
 for chunk:Vector2i in review._inputs:
  var features:FeatureContext=review._inputs[chunk].features
  var core:=Rect2(Vector2(chunk)*192.0,Vector2.ONE*192.0)
  var cells:=Rect2()
  var first:=true
  for cell:Vector2i in features.connection_masks:
   var r:=Rect2(Vector2(cell)*24.0-Vector2(12,12),Vector2(24,24))
   cells=r if first else cells.merge(r);first=false
  print("[oct1_coverage] chunk=%s coverage=%s core=%s masks=%d mask_extent=%s" % [chunk,features._coverage,core,features.connection_masks.size(),cells])
 print("[oct1_coverage] done")
