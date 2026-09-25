extends SceneTree
const OUT := "res://docs/qa/2026-09-19-manual/117-loading-frontier"
func _init() -> void: run.call_deferred()
func box(pos:Vector3,size:Vector3,color:Color) -> MeshInstance3D:
	var n:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=size
	n.mesh=mesh; n.position=pos
	var mat:=StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.albedo_color=color
	n.material_override=mat; root.add_child(n)
	return n
func shot(name:String) -> Image:
	for i in 3: await process_frame
	RenderingServer.force_draw(false)
	var im:=root.get_texture().get_image(); im.save_png(OUT.path_join(name+".png")); return im
func run() -> void:
	Engine.max_fps=30; root.size=Vector2i(800,600)
	var camera:=Camera3D.new(); root.add_child(camera); camera.position=Vector3(96,120,300); camera.look_at(Vector3(96,0,20)); camera.current=true
	var env:=WorldEnvironment.new(); env.environment=Environment.new(); env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color("c9ced4"); root.add_child(env)
	box(Vector3(96,-2,50),Vector3(500,4,800),Color("42704b"))
	box(Vector3(96,15,-80),Vector3(35,30,35),Color.MAGENTA)
	var border_box:=box(Vector3(140,15,-17.5),Vector3(25,30,35),Color.MAGENTA)
	box(Vector3(96,5,160),Vector3(20,10,20),Color.RED)
	var baseline:Image=await shot("gpu-before")
	var fog:=preload("res://scripts/terrain/diagnostics/LoadingFrontierFog.gd").new(); root.add_child(fog)
	var coverage:={Vector2i.ZERO:true,Vector2i(0,1):true}
	fog.update_view(camera,coverage,Color("b4c9d1"))
	var after:Image=await shot("gpu-fog")
	var near_pixel:=Vector2i(camera.unproject_position(Vector3(96,5,169)))
	var far_pixel:=Vector2i(camera.unproject_position(Vector3(96,15,-62)))
	var near_before:=baseline.get_pixelv(near_pixel);var near_after:=after.get_pixelv(near_pixel)
	var far_before:=baseline.get_pixelv(far_pixel);var far_after:=after.get_pixelv(far_pixel)
	assert((Vector3(near_before.r,near_before.g,near_before.b)-Vector3(near_after.r,near_after.g,near_after.b)).length()<.02,"finished nearby object changed")
	assert(far_after.g>far_before.g+.3,"unloaded distant object remains visible")
	var border_pixel:=Vector2i(camera.unproject_position(Vector3(140,15,0)))
	border_box.material_override.albedo_color=Color.BLUE
	var recolored:Image=await shot("gpu-border-opaque")
	assert(recolored.get_pixelv(border_pixel).is_equal_approx(after.get_pixelv(border_pixel)),"boundary is translucent: changing the hidden object must not alter the fog")
	border_box.material_override.albedo_color=Color.MAGENTA
	coverage[Vector2i(0,-1)]=true
	fog.update_view(camera,coverage,Color("b4c9d1"))
	var revealed:Image=await shot("gpu-revealed")
	var returned:=revealed.get_pixelv(far_pixel)
	assert(absf(returned.g-far_before.g)<.02,"newly loaded object not revealed")
	# Near a boundary, the actor-sized foreground object still retains its
	# colour; the fade compresses into the last part of the available ground.
	camera.position=Vector3(96,12,20); camera.look_at(Vector3(96,0,0))
	box(Vector3(96,2,12),Vector3(2,4,2),Color.RED)
	fog.clear()
	var close_before:Image=await shot("gpu-close-before")
	fog.update_view(camera,{Vector2i.ZERO:true},Color("b4c9d1"))
	var close_after:Image=await shot("gpu-close-fog")
	var close_pixel:=Vector2i(camera.unproject_position(Vector3(96,3,13)))
	assert(close_before.get_pixelv(close_pixel).is_equal_approx(close_after.get_pixelv(close_pixel)),"near-boundary actor footing washed out")
	FileAccess.open(OUT.path_join("gpu.json"),FileAccess.WRITE).store_string(JSON.stringify({"near_before":near_before,"near_after":near_after,"far_before":far_before,"far_after":far_after,"revealed":returned},"  "))
	print("FRONTIER_GPU five pixel controls passed")
	quit()
