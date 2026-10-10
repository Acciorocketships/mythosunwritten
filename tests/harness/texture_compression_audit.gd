extends SceneTree
## Offline, non-destructive: GPU-compressed candidates and sampled error metrics.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var manifest := "/tmp/oct9-village-compression-sample.json"
	var out := "/tmp/oct9-village-compression"
	for i in args.size()-1:
		if args[i] == "--manifest": manifest = args[i+1]
		if args[i] == "--out": out = args[i+1]
	DirAccess.make_dir_recursive_absolute(out)
	var rows: Array = []
	for entry: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(manifest)):
		var source := load(entry.path) as Texture2D
		var pixels := source.get_image()
		assert(pixels != null and not pixels.is_compressed())
		var normal: bool = entry.roles == ["normal_texture"]
		var candidate := PortableCompressedTexture2D.new()
		candidate.keep_compressed_buffer = true
		var started := Time.get_ticks_msec()
		candidate.create_from_image(pixels, PortableCompressedTexture2D.COMPRESSION_MODE_BPTC, normal)
		var packed := candidate.get_image()
		assert(packed != null and packed.is_compressed())
		var output := out.path_join(String(entry.path).get_file())
		assert(ResourceSaver.save(candidate,output) == OK)
		var decoded := packed.duplicate() as Image
		assert(decoded.decompress() == OK)
		var total := 0.0
		var maximum := 0.0
		var alpha_max := 0.0
		var count := 0
		for y in range(3,pixels.get_height(),8):
			for x in range(5,pixels.get_width(),8):
				var a := pixels.get_pixel(x,y)
				var b := decoded.get_pixel(x,y)
				var error: float
				if normal:
					var av := Vector3(a.r*2-1,a.g*2-1,0)
					var bv := Vector3(b.r*2-1,b.g*2-1,0)
					av.z = sqrt(maxf(0,1-av.length_squared()))
					bv.z = sqrt(maxf(0,1-bv.length_squared()))
					error = rad_to_deg(av.normalized().angle_to(bv.normalized()))
				else:
					error = maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))) * 255
				alpha_max = maxf(alpha_max,absf(a.a-b.a)*255)
				total += error
				maximum = maxf(maximum,error)
				count += 1
		var row := {"path":entry.path,"roles":entry.roles,"source_bytes":pixels.get_data().size(),
			"packed_bytes":packed.get_data().size(),"format":packed.get_format(),"mips":packed.has_mipmaps(),
			"width":pixels.get_width(),"height":pixels.get_height(),"samples":count,
			"error_unit":"normal_degrees" if normal else "maximum_rgb_byte_error",
			"mean_error":total/maxi(1,count),"max_error":maximum,"max_alpha_byte_error":alpha_max,
			"elapsed_ms":Time.get_ticks_msec()-started,"output":output}
		rows.append(row)
		print("COMPRESSION_AUDIT ",JSON.stringify(row))
	FileAccess.open(out.path_join("audit.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()
