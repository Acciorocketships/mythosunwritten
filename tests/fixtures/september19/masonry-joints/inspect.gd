extends SceneTree
func _init():
 for id:String in ['sfv.fabric.wall.rock.retaining.001','sfv.foundation.rock.001','sfv.fabric.chimney.001']:
  var catalog:=EnvironmentCatalog.load_default();var cache:=EnvironmentRenderCache.new(catalog);cache.prepare([StringName(id)])
  var visual:=cache.visual(StringName(id))
  print('NATIVE ',id,' ',catalog.descriptor(StringName(id)).measured_aabb)
  for piece:EnvironmentVisualPiece in visual.pieces:
   for section in piece.mesh.get_surface_count():
    var mat:StandardMaterial3D=piece.mesh.surface_get_material(section)
    print('MATERIAL ',mat.resource_path,' ',mat.albedo_texture.resource_path if mat.albedo_texture!=null else '<none>',' ',mat.albedo_color)
 quit()
