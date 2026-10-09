extends RefCounted
func run(review:Node)->void:
	var materials:Dictionary={}
	_gather(review._streamer,materials)
	var saved:Dictionary={}
	for id:int in materials:
		var m:ShaderMaterial=materials[id]
		saved[id]={"moss_shade":m.get_shader_parameter("moss_shade"),"moss_detail_strength":m.get_shader_parameter("moss_detail_strength"),"moss_secondary":m.get_shader_parameter("moss_secondary")}
	var plain:bool=review._plain
	review._plain=true
	for variant:String in ["neutral","lighter"]:
		for id:int in materials:
			var m:ShaderMaterial=materials[id]
			m.set_shader_parameter("moss_shade",Vector3.ONE if variant=="neutral" else Vector3(.68,.78,.69))
			m.set_shader_parameter("moss_detail_strength",0.0 if variant=="neutral" else .45)
			m.set_shader_parameter("moss_secondary",0.0 if variant=="neutral" else .5)
		await review._capture_all(10 if variant=="neutral" else 11)
	for id:int in materials:
		for key:String in saved[id]:materials[id].set_shader_parameter(key,saved[id][key])
	review._plain=plain
	print("CLIFF_SHADING_TRIAL materials=",materials.size())

func _gather(node:Node,found:Dictionary)->void:
	if node is MeshInstance3D:
		for i in node.get_surface_override_material_count():_keep(node.get_active_material(i),found)
	elif node is MultiMeshInstance3D and node.multimesh!=null and node.multimesh.mesh!=null:
		_keep(node.material_override,found)
		for i in node.multimesh.mesh.get_surface_count():_keep(node.multimesh.mesh.surface_get_material(i),found)
	for child:Node in node.get_children():_gather(child,found)

func _keep(m:Material,found:Dictionary)->void:
	if not m is ShaderMaterial or m.shader==null:return
	if m.shader.resource_path not in ["res://terrain/materials/ground_surface.gdshader","res://terrain/materials/cliff_crag.gdshader"]:return
	found[m.get_instance_id()]=m
