extends SceneTree
func _init():
 var texture:Texture2D=load('res://terrain/environment/textures/fantasy_village_fabric/6b8ecd33a34708110ecc.res')
 var img:=texture.get_image();img.decompress();img.save_png('res://docs/qa/2026-09-19-manual/91-masonry-joints/palette.png')
 var mesh:Mesh=load('res://terrain/environment/meshes/fantasy_village_fabric/sfv_fabric_wall_rock_retaining_001_piece_00.res')
 var a:=mesh.surface_get_arrays(0);var vertices:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var uv:PackedVector2Array=a[Mesh.ARRAY_TEX_UV]
 var samples:Dictionary={}
 for i in vertices.size():
  var p:Vector3=vertices[i];var pixel:=Vector2i(clampi(int(uv[i].x*img.get_width()),0,img.get_width()-1),clampi(int(uv[i].y*img.get_height()),0,img.get_height()-1))
  var key:=[uv[i],img.get_pixelv(pixel)]
  if not samples.has(key):samples[key]=[]
  if samples[key].size()<3:samples[key].append(p)
 print('UV_PALETTE ',samples)
 quit()
