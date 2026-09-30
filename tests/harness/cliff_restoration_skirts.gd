extends RefCounted
## Replay the monotone production skirt filter on the settled original arrays.
## Existing old-filtered arrays are valid input: the new predicate only removes
## additional buried triangles. Terrain, slope surfaces and collision stay put.
func run(review:Node3D)->void:
 var script:=load("res://scripts/terrain/field/CliffSlopeEnvelope.gd") as GDScript
 script.source_code=FileAccess.get_file_as_string("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
 assert(script.reload()==OK)
 var rows:=[]
 var cells:=TerrainChunkMesher.CELLS_PER_CHUNK
 for chunk:Vector2i in review._inputs:
  var root:Node3D=review._streamer._built.get(chunk)
  if root==null:continue
  var node:=root.get_node_or_null("CliffFaces") as MeshInstance3D
  if node==null or node.mesh==null:continue
  var input:Dictionary=review._inputs[chunk]
  var owned:=Rect2(Vector2(chunk*cells)*24.0-Vector2(12,12),Vector2.ONE*cells*24.0)
  var field=load("res://scripts/terrain/field/CliffSlopeField.gd").new([],2697992464,input.region,owned,input.features,input.water)
  var env=field.envelope()
  env.replacement_columns=field._columns(owned.grow(4.0))
  var old:Array=node.mesh.surface_get_arrays(0)
  var after:Array=env.uncovered_faces(old)
  var before_count:int=old[Mesh.ARRAY_INDEX].size()/3 if old[Mesh.ARRAY_INDEX]!=null else old[Mesh.ARRAY_VERTEX].size()/3
  var after_count:=0
  if after.is_empty():node.visible=false
  else:
   after_count=after[Mesh.ARRAY_INDEX].size()/3
   var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,after)
   mesh.surface_set_material(0,node.mesh.surface_get_material(0));node.mesh=mesh
  rows.append({"chunk":str(chunk),"before":before_count,"after":after_count})
  await review.get_tree().process_frame
 FileAccess.open(review._output_dir+"/skirt-replay.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 if review._output_dir.ends_with("south"):
  var player:=Vector3(503.3,36,951.5);var hit:=Vector3(507,36,955.3)
  var pivot:=player+Vector3.UP*CameraMouseView.PIVOT_HEIGHT;var delta:=hit-pivot
  var pitch:=atan2(-delta.y,Vector2(delta.x,delta.z).length());var boom:=CameraMouseView.BOOM_LENGTH
  review._views.append({"id":"p03","player":player,"target":pivot,"fov":75.0,"position":ReviewCam.solve_cam(player,hit,boom*cos(pitch),CameraMouseView.PIVOT_HEIGHT+boom*sin(pitch),CameraMouseView.PIVOT_HEIGHT)})
 await review._capture_all(90)
 print("[skirt_replay] ",JSON.stringify(rows))
