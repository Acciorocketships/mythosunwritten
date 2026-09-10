extends SceneTree
func _init() -> void:
 var result: Dictionary = {}
 for id: StringName in [&"lpfv.fabric.prop.lantern.table.01",&"lpfv.fabric.prop.lantern.post.02"]:
  var visual := load(EnvironmentCatalog.load_default().descriptor(id).visual_path) as EnvironmentVisual
  var groups: Dictionary = {}
  for piece in visual.pieces:
   for surface in piece.mesh.get_surface_count():
    var material := piece.mesh.surface_get_material(surface) as StandardMaterial3D
    var texture := material.albedo_texture.get_image()
    texture.decompress()
    var arrays := piece.mesh.surface_get_arrays(surface)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
    for i in vertices.size():
     var uv := uvs[i]
     var color := texture.get_pixel(clampi(int(uv.x*texture.get_width()),0,texture.get_width()-1),clampi(int(uv.y*texture.get_height()),0,texture.get_height()-1))
     var key := color.to_html()
     var point := piece.local_transform*vertices[i]
     if not groups.has(key): groups[key]={"count":0,"bounds":AABB(point,Vector3.ZERO),"uv":uv}
     groups[key].count+=1
     groups[key].bounds=groups[key].bounds.expand(point)
  result[id]=groups
 FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 quit()
