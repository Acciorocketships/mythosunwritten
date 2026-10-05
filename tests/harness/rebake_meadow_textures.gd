# tests/harness/rebake_meadow_textures.gd
# Rebakes the Meadow rock/grass textures (terrain/environment/textures/meadow)
# from 4096^2 lossless RGBA8 (~89 MB of VRAM each with mips, ~0.5 s to
# decode) to MAX_SIZE with GPU block compression (BC7; normal maps in their
# normal-map mode). Run with the editor build (it owns the compressors):
#   Godot --headless --path . -s res://tests/harness/rebake_meadow_textures.gd \
#     [-- --max=2048]
# The files are rewritten in place, so every material keeps its references.
extends SceneTree

const DIR := "res://terrain/environment/textures/meadow/"

func _init() -> void:
	var max_size := 2048
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--max="): max_size = int(arg.trim_prefix("--max="))
	for file: String in DirAccess.get_files_at(DIR):
		if not file.ends_with(".res"):
			continue
		var path := DIR + file
		var source := load(path) as Texture2D
		var image := source.get_image().duplicate() as Image
		if image.is_compressed():
			image.decompress()
		var before := image.get_size()
		image.clear_mipmaps()
		if image.get_width() > max_size or image.get_height() > max_size:
			var scale := float(max_size) / float(maxi(image.get_width(), image.get_height()))
			image.resize(roundi(image.get_width() * scale), roundi(image.get_height() * scale),
				Image.INTERPOLATE_LANCZOS)
		var normal := file.get_basename().ends_with("_N")
		image.generate_mipmaps(normal)
		var texture := PortableCompressedTexture2D.new()
		texture.keep_compressed_buffer = true
		texture.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_BPTC, normal)
		source = null
		var err := ResourceSaver.save(texture, path)
		print("REBAKED %s %s -> %s normal=%s err=%d" % [file, before, image.get_size(), normal, err])
	quit()
