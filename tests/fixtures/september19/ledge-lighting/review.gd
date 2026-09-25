extends "res://tests/harness/september15_reported_qa.gd"
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
func _spots()->Array:
 var result:Array=[]
 for entry:Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-16-manual/photo-poses.json")):
  if entry.crosshair==null:continue
  result.append([entry.id,entry.source,Vector3(entry.player[0],entry.player[1],entry.player[2]),Vector3(entry.crosshair[0],entry.crosshair[1],entry.crosshair[2])])
 return result
func _capture_views(world:Node3D)->void:
 var original_output:=_output_dir
 var nodes:Array=[];var before:Array=[];var after:Array=[];var altered:=0
 for node:MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
  if not node.has_meta("relief_faces") or node.multimesh.mesh.get_surface_count()<2:continue
  var mesh:ArrayMesh=node.multimesh.mesh
  var replacement:ArrayMesh=mesh.duplicate()
  assert(mesh.get_surface_count()==2)
  replacement.surface_remove(1)
  var arrays:=mesh.surface_get_arrays(1)
  var normals:=CRAGS._connected_normals(arrays[Mesh.ARRAY_VERTEX])
  var old:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  for i in normals.size():
   if normals[i].distance_to(old[i])>.00001:altered+=1
  arrays[Mesh.ARRAY_NORMAL]=normals
  # Tangents are renderer-generated from the new normals, as in production.
  arrays[Mesh.ARRAY_TANGENT]=null
  replacement.add_surface_from_arrays(mesh.surface_get_primitive_type(1),arrays)
  replacement.surface_set_material(1,mesh.surface_get_material(1))
  assert(mesh.surface_get_arrays(0)==replacement.surface_get_arrays(0))
  var source:=mesh.surface_get_arrays(1);var current:=replacement.surface_get_arrays(1)
  for key in Mesh.ARRAY_MAX:
   if key not in [Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT]:assert(source[key]==current[key])
  node.multimesh=node.multimesh.duplicate()
  nodes.append(node);before.append(mesh);after.append(replacement)
 print("TREAD_REPLAY meshes=",nodes.size()," altered_normals=",altered," geometry_uv_stone_unchanged=true")
 for phase in 2:
  for i in nodes.size():nodes[i].multimesh.mesh=before[i] if phase==0 else after[i]
  _output_dir=original_output.path_join("before" if phase==0 else "after")
  DirAccess.make_dir_recursive_absolute(_output_dir)
  _character.visible=true
  _capture_view.size=Vector2i(1920,1080)
  await super._capture_views(world)
  _character.visible=false
  _capture_view.size=Vector2i(1600,1000)
  for view:Array in [
   ["inner_front",Vector3(-434,38,-291),Vector3(-444,35,-300)],
   ["inner_above",Vector3(-437,44,-294),Vector3(-443,34,-299)],
   ["outer_oblique",Vector3(-437,41,-242),Vector3(-445,35,-252)],
   ["lower_inner_front",Vector3(-434,35,-266),Vector3(-445,30,-277)],
   ["lower_inner_above",Vector3(-435,43,-267),Vector3(-444,29,-276)],
   ["short_inner",Vector3(-409,35,-338),Vector3(-421,30,-349)]]:
   _camera.global_position=view[1];_camera.look_at(view[2]);_camera.fov=65
   await _shot(view[0])
 _output_dir=original_output
