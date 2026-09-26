extends SceneTree
const ROCKS=preload("res://scripts/terrain/field/CliffSlopeRocks.gd")
func _initialize()->void:
 _bake_textures()
 ROCKS.prepare()
 DirAccess.make_dir_recursive_absolute("res://terrain/environment/visuals/meadow")
 for i in range(1,13):
  var key:="angry_%02d"%i;var source:Array=ROCKS._pieces[key]
  var visual:=EnvironmentVisual.new();var piece:=EnvironmentVisualPiece.new()
  piece.mesh=source[0].duplicate();
  for surface in piece.mesh.get_surface_count():piece.mesh.surface_set_material(surface,null)
  piece.local_transform=source[1];piece.material_override=source[2].duplicate();piece.use_instance_color=true
  piece.material_override.set_shader_parameter("slope_attachment",false)
  # Ground pivot: authored base touches the placement datum.
  var box:AABB=piece.local_transform*piece.mesh.get_aabb()
  piece.local_transform.origin.y-=box.position.y
  visual.pieces.append(piece)
  var collision:=EnvironmentCollisionPiece.new();collision.shape=piece.mesh.create_convex_shape(true,true);collision.local_transform=piece.local_transform;visual.collisions.append(collision)
  var path:="res://terrain/environment/visuals/meadow/rock_%02d.res"%i
  assert(ResourceSaver.save(visual,path)==OK)
  var descriptor:=EnvironmentAssetDescriptor.new();descriptor.id=StringName("meadow.rock.%02d"%i);descriptor.visual_path=path;descriptor.tags.assign([&"nature",&"rock"])
  descriptor.measured_aabb=piece.local_transform*piece.mesh.get_aabb();descriptor.collision_piece_count=1;descriptor.tint_group=&"ground";descriptor.supports_instance_color=true;descriptor.provenance_id=StringName("angry_mesh:P_Rock_%02d_Summer"%i)
  assert(ResourceSaver.save(descriptor,"res://terrain/environment/catalog/descriptors/meadow_rock_%02d.tres"%i)==OK)
  print("BAKED ",descriptor.id," ",descriptor.measured_aabb)
 quit()

func _bake_textures()->void:
 const SOURCE="res://assets/ANGRY MESH/Textures/Stylized_Pack_-_Meadow_Environment/"
 const TARGET="res://terrain/environment/textures/meadow/"
 DirAccess.make_dir_recursive_absolute(TARGET)
 var paths:Array[String]=[]
 for i in range(1,7):
  for suffix:String in ["A","N","SMA"]:paths.append("Rocks/T_Rock_%02d_%s.png"%[i,suffix])
 for suffix:String in ["A","N"]:paths.append("Terrain/T_Terrain_Grass_01_%s.png"%suffix)
 for path:String in paths:
  var out:=TARGET+path.get_file().get_basename()+".res"
  if FileAccess.file_exists(out):continue
  var source:=load(SOURCE+path) as Texture2D
  var image:=source.get_image().duplicate() as Image
  if image.is_compressed():image.decompress()
  image.convert(Image.FORMAT_RGBA8);image.generate_mipmaps()
  var texture:=PortableCompressedTexture2D.new();texture.keep_compressed_buffer=true
  texture.create_from_image(image,PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
  assert(ResourceSaver.save(texture,out)==OK)
  print("TEXTURE ",out)
