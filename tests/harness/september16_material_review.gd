extends "res://tests/harness/september16_cliffs.gd"
## Replay the production vine material/instance bindings over unchanged saved
## geometry. This avoids rerunning the unrelated cold water/feature solver.
func _capture_views(world:Node3D)->void:
 var green=preload("res://scripts/terrain/field/CliffVegetation.gd");green.prepare()
 var replaced:=0
 for node:MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
  var mesh:=node.multimesh.mesh
  for asset:StringName in green._visuals:
   for piece:EnvironmentVisualPiece in green._visuals[asset].pieces:
    if not mesh.get_aabb().is_equal_approx(piece.mesh.get_aabb()) or mesh.get_faces().size()!=piece.mesh.get_faces().size():continue
    var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=piece.mesh;mm.instance_count=node.multimesh.instance_count
    for i in mm.instance_count:
     var pose:Transform3D=node.multimesh.get_instance_transform(i)
     mm.set_instance_transform(i,pose)
     mm.set_instance_color(i,BiomeRegistry.blended_foliage_tint(Helper.biome_weights5((node.global_transform*pose).origin,WORLD_SEED),"bush"))
    node.multimesh=mm;node.material_override=piece.material_override;replaced+=1
 print("VINE_MATERIAL_REPLAY batches=",replaced)
 await super._capture_views(world)
