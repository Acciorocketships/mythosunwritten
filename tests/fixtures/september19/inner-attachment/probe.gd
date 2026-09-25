extends SceneTree
func _init():
 var c=load('res://scripts/terrain/field/CliffCornerCrags.gd');c.prepare();c.CRAGS.prepare()
 var mesh:Mesh=load('res://terrain/environment/meshes/kaykit/kaykit_cliff_inner_wall_piece_00.res')
 print('INNER_BOUND ',mesh.get_aabb())
 for y:float in [.1,1,2,3]:
  for u:float in [-1.001,-.999,.999,1.001]:print('JOIN ',y,' ',u,' ',c._inner_native(u,y,Transform3D(Basis.IDENTITY,Vector3(-445.5,32,-301.5))))
 quit()
