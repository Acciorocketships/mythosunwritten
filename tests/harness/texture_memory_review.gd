extends RefCounted

func run(review: Node) -> void:
	await review.get_tree().create_timer(2.0).timeout
	var frames: Array = []
	var last := Time.get_ticks_usec()
	while frames.size() < 300:
		await review.get_tree().process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now-last)/1000.0)
		last = now
	frames.sort()
	var result := {"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"buffer_bytes":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),
		"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"frame_p50_ms":frames[150],"frame_p95_ms":frames[285],"frame_max_ms":frames[-1]}
	FileAccess.open(review._output_dir+"/texture-memory.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("TEXTURE_MEMORY_REVIEW ", JSON.stringify(result))
