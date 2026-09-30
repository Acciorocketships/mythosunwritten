extends RefCounted
func run(review:Node3D)->void:
 var shader:Shader=load("res://terrain/materials/cliff_crag.gdshader")
 var original:=shader.code
 var view:Dictionary=review._views.filter(func(v:Dictionary)->bool:return v.id=="ledges-front-exterior")[0]
 review._camera.fov=view.fov;review._camera.look_at_from_position(view.position,view.target,Vector3.UP)
 shader.code=original.replace("shader_type spatial;","shader_type spatial;\nrender_mode cull_disabled;")
 for i in 10:await review.get_tree().process_frame
 RenderingServer.force_draw();await review.get_tree().process_frame
 review.get_viewport().get_texture().get_image().save_png(review._output_dir+"/cull-disabled.png")
 shader.code=original
 print("[cull_probe] done")
