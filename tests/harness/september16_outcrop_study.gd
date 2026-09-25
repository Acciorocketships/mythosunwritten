extends "res://tests/harness/september16_material_review.gd"
## Frozen geometry art iteration. Physics samples root the same production forms.
## Fresh production captures separately verify field ownership and clearance.
func _capture_views(world:Node3D)->void:
 var rocks=preload("res://scripts/terrain/field/CliffRockDressing.gd");rocks.prepare()
 var old_ids:Array[StringName]=[&"cliff.rock.bush"]
 for form:int in [1,2,4,7,10,11,12,13,14,15,16,17]:old_ids.append(StringName("cliff.rock.moss_%d"%form))
 var cache:=EnvironmentRenderCache.new(EnvironmentCatalog.load_default());cache.prepare(old_ids)
 var old_meshes:=[]
 for id:StringName in old_ids:
  for piece:EnvironmentVisualPiece in cache.visual(id).pieces:old_meshes.append(piece.mesh)
 for id:StringName in rocks._visuals:
  if id in rocks.PLANTS:continue
  for piece:EnvironmentVisualPiece in rocks._visuals[id].pieces:old_meshes.append(piece.mesh)
 var walls:=[]
 var native:Mesh=CliffDressing._pieces.wall[0]
 for node:MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
  var mesh:=node.multimesh.mesh
  for old:Mesh in old_meshes:
   if mesh.get_aabb().is_equal_approx(old.get_aabb()) and mesh.get_faces().size()==old.get_faces().size():node.visible=false
  if mesh.get_aabb().is_equal_approx(native.get_aabb()) and mesh.get_faces().size()==native.get_faces().size():
   for i in node.multimesh.instance_count:walls.append(node.global_transform*node.multimesh.get_instance_transform(i))
 for shape:CollisionShape3D in world.find_children("*","CollisionShape3D",true,false):
  if shape.name==&"CliffRocks":shape.disabled=true
 await get_tree().physics_frame
 var space:=_camera.get_world_3d().direct_space_state
 var placements:Array[Dictionary]=[]
 if not "--bare-old" in OS.get_cmdline_user_args():placements=rocks.formations(walls,WORLD_SEED)
 for p:Dictionary in placements:
  var floor_y:float=p.base
  for v:Vector3 in rocks._definitions[p.asset].feet:
   var point:Vector3=p.transform*v
   var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*130,point-Vector3.UP*130);query.exclude=[_character.get_rid()]
   var hit:=space.intersect_ray(query)
   if not hit.is_empty():floor_y=minf(floor_y,hit.position.y-.15)
  var transform:Transform3D=p.transform
  transform.origin.y=floor_y;transform.basis.y*=(p.top-floor_y)/(p.top-p.base)
  p.transform=transform;p.bounds=transform*rocks._definitions[p.asset].bounds
 var foliage:=rocks.plants(placements,null,WORLD_SEED,null,null,placements)
 var accepted:=[]
 for p:Dictionary in foliage:
  var point:Vector3=p.transform.origin+Vector3.UP*.1
  var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*130,point+Vector3.UP*.15);query.exclude=[_character.get_rid()]
  if space.intersect_ray(query).is_empty():accepted.append(p)
 placements.append_array(accepted)
 world.add_child(rocks.build({"placements":placements},WORLD_SEED))
 print("OUTCROP_ART_STUDY rocks=",placements.size()," shrubs=",accepted.size())
 await super._capture_views(world)
