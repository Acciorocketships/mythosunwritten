extends Node3D
## A fixed art-direction study, deliberately separate from production world streaming.
## Source models are loaded here only for authoring/review. Runtime uses baked catalog IDs.
const SOURCE := "res://assets/StylizedNatureQuaternius/glTF/"
var _cache: Dictionary = {}
var _batches: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _camera: Camera3D
var _view: SubViewport
var _stage: Node3D
var _rock: ShaderMaterial
var _output := "res://docs/qa/2026-09-15-mountain-study/v1"
var _bare := false
var _interactive := false
var _revision := 1
var _counts: Dictionary = {}
var _forms: Array[Dictionary] = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _output=arg.trim_prefix("--output=")
		if arg.begins_with("--revision="): _revision=int(arg.trim_prefix("--revision="))
		if arg=="--bare": _bare=true
		if arg=="--interactive": _interactive=true
	_rng.seed=15092026
	DirAccess.make_dir_recursive_absolute(_output)
	_view=SubViewport.new()
	_view.size=Vector2i(1600,1000)
	_view.own_world_3d=true
	_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	_view.msaa_3d=Viewport.MSAA_4X
	add_child(_view)
	_stage=Node3D.new()
	_view.add_child(_stage)
	_lighting()
	_rock=ShaderMaterial.new()
	_rock.shader=load("res://tools/mountain_art/limestone.gdshader")
	_ground()
	_composition()
	if not _bare:
		_vegetation()
	_flush()
	var mage:Node3D=load("res://characters/models/mage.tscn").instantiate()
	_stage.add_child(mage)
	mage.position=Vector3(3,_height(3,19),19)
	mage.rotation.y=PI
	var anim:AnimationPlayer=mage.find_child("AnimationPlayer",true,false)
	if anim:
		for key in anim.get_animation_list():
			if "Idle" in key: anim.play(key);break
	_camera=Camera3D.new()
	_stage.add_child(_camera)
	_camera.current=true
	_camera.far=900
	_camera.near=.15
	var shots: Array=[
		["wide",Vector3(65,32,93),Vector3(-2,26,-42),58.0],
		["gameplay",Vector3(9,8,32),Vector3(-3,20,-38),65.0],
		["left",Vector3(-55,19,35),Vector3(-4,25,-38),62.0],
		["right",Vector3(62,16,12),Vector3(-12,26,-41),62.0],
		["close",Vector3(-17,7,3),Vector3(-25,20,-25),65.0],
		["overlook",Vector3(-38,46,-22),Vector3(8,21,-45),68.0]]
	for shot in shots:
		_camera.position=shot[1];_camera.look_at(shot[2]);_camera.fov=shot[3]
		for frame in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_view.get_texture().get_image().save_png(_output.path_join(shot[0]+".png"))
		print("MOUNTAIN_STUDY_CAPTURE ",shot[0])
	FileAccess.open(_output.path_join("scene-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"revision":_revision,"seed":15092026,"assets":_counts,"formations":_forms.size(),"bare":_bare,"poses":str(shots)},"  "))
	if _interactive:
		_camera.position=shots[0][1];_camera.look_at(shots[0][2]);_camera.fov=58
		var container:=SubViewportContainer.new()
		container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		container.stretch=true
		add_child(container)
		_view.reparent(container)
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	else: get_tree().quit()

func _process(delta:float) -> void:
	if not _interactive or not is_instance_valid(_camera):return
	var axis:=Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	_camera.position+=_camera.basis*axis*delta*(35 if Input.is_physical_key_pressed(KEY_SHIFT) else 12)

func _input(event:InputEvent) -> void:
	if not _interactive:return
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		_camera.rotation.y-=event.relative.x*.002
		_camera.rotation.x=clampf(_camera.rotation.x-event.relative.y*.002,-1.4,1.4)

func _lighting() -> void:
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	var e:=env.environment
	e.background_mode=Environment.BG_SKY
	e.sky=Sky.new()
	var sky:=ShaderMaterial.new()
	sky.shader=load("res://tools/mountain_art/study_sky.gdshader")
	e.sky.sky_material=sky
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color=Color("a3beca")
	e.ambient_light_energy=.45
	e.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure=.95
	e.ssao_enabled=true;e.ssao_radius=2.8;e.ssao_intensity=1.6;e.ssao_power=1.25
	e.glow_enabled=true;e.glow_intensity=.3;e.glow_bloom=.02
	e.fog_enabled=true;e.fog_density=.0007;e.fog_light_color=Color("adc8c5")
	e.fog_sun_scatter=.1;e.fog_aerial_perspective=.06
	_stage.add_child(env)
	var sun:=DirectionalLight3D.new()
	sun.light_color=Color("fff0cf");sun.light_energy=1.25
	sun.rotation_degrees=Vector3(-43,-32,0)
	sun.shadow_enabled=true;sun.directional_shadow_max_distance=240
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.light_angular_distance=1.7
	_stage.add_child(sun)

func _height(x:float,z:float) -> float:
	var valley:=1.5*sin(x*.035+z*.019)+.7*sin(z*.07-x*.03)+3.0*exp(-pow((x+32)/22,2)-pow((z-5)/29,2))
	return valley+smoothstep(45,110,absf(x))*(15+9*sin(z*.025+x*.019))+smoothstep(145,240,-z)*12

func _ground() -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-260,121,3):
		for x in range(-160,161,3):
			var a:=Vector3(x,_height(x,z),z);var b:=Vector3(x+3,_height(x+3,z),z)
			var c:=Vector3(x,_height(x,z+3),z+3);var d:=Vector3(x+3,_height(x+3,z+3),z+3)
			for p in [a,b,c,b,d,c]:
				st.set_uv(Vector2(p.x,p.z)*.12)
				var noise:=.5+.5*sin(p.x*.11+sin(p.z*.045)*3)*cos(p.z*.08)
				st.set_color(Color("557032").lerp(Color("809446"),noise*.65).srgb_to_linear())
				st.add_vertex(p)
	st.generate_normals()
	var mesh:=MeshInstance3D.new();mesh.mesh=st.commit()
	var mat:=ShaderMaterial.new();mat.shader=load("res://tools/mountain_art/meadow.gdshader")
	mesh.material_override=mat;_stage.add_child(mesh)
	mesh.create_trimesh_collision()

func _composition() -> void:
	# Connected wall masses frame a broad valley; the narrow crowns vary independently.
	for data in [
		["buttress_wide",Vector3(-65,0,-100),1.5,.1],
		["buttress_wide",Vector3(65,0,-93),1.5,-.4],
		["buttress_wide",Vector3(-48,0,-28),1.45,.1],
		["buttress_tall",Vector3(-29,0,-40),1.4,-.2],
		["pillar_crown",Vector3(-48,0,-66),1.5,.4],
		["pillar_split",Vector3(-25,0,-83),1.2,-.3],
		["buttress_wide",Vector3(-67,0,-70),1.5,.1],
		["buttress_wide",Vector3(48,0,-46),1.7,-.8],
		["buttress_tall",Vector3(35,0,-75),1.25,-.5],
		["pillar_slender",Vector3(23,0,-113),1.3,.2],
		["pillar_split",Vector3(-8,0,-126),1.35,-.3],
		["pillar_crown",Vector3(57,0,-123),1.4,.5],
		["pillar_slender",Vector3(-38,0,-160),1.15,-.5],
		["pillar_split",Vector3(6,0,-188),1.25,.3],
		["pillar_crown",Vector3(57,0,-199),1.3,.5]]:
		var p:Vector3=data[1];p.y=_height(p.x,p.z)-.6
		var tr:=Transform3D(Basis(Vector3.UP,data[3]).scaled(Vector3.ONE*data[2]),p)
		_asset("res://assets/MythosMountains/"+data[0]+".glb",tr,"stone")
		_forms.append({"name":data[0],"transform":tr})
	# Embedded shelves attach to each foreground face, not to free-floating centres.
	for data in [[Vector3(-43,11,-22),1.15,.06],[Vector3(-28,24,-36),.8,-.15],[Vector3(42,16,-39),1.05,-.5]]:
		_asset("res://assets/MythosMountains/shelf_long.glb",Transform3D(Basis(Vector3.UP,data[2]).scaled(Vector3.ONE*data[1]),data[0]),"stone")

func _vegetation() -> void:
	# Groundcover varies continuously and leaves a winding open floor through the valley.
	for i in 72000:
		var x:=_rng.randf_range(-80,80);var z:=_rng.randf_range(-170,62)
		var lane:=5*sin(z*.038)+5
		if _rng.randf()>smoothstep(2.0,4.0+sin(z*.37)*.35,absf(x-lane)):continue
		if _inside_rock(Vector3(x,0,z),-.5):continue
		if _rng.randf()<.22+.2*sin(x*.09+z*.03):continue
		var p:=Vector3(x,_height(x,z)-.025,z)
		_asset(SOURCE+"Grass_Common_Short.gltf",_pose(p,_rng.randf_range(.4,.65)),"grass")
	for i in 220:
		var x:=_rng.randf_range(-76,76);var z:=_rng.randf_range(-150,38)
		if absf(x-(5*sin(z*.038)+5))<6 or _inside_rock(Vector3(x,0,z),1.3):continue
		_asset(SOURCE+"Fern_1.gltf",_pose(Vector3(x,_height(x,z),z),_rng.randf_range(.55,1.3)),"fern")
	for i in 130:
		var x:=_rng.randf_range(-76,76);var z:=_rng.randf_range(-170,22)
		if absf(x)<13 or _inside_rock(Vector3(x,0,z),1):continue
		_asset(SOURCE+"Bush_Common.gltf",_pose(Vector3(x,_height(x,z)-.08,z),_rng.randf_range(1.0,2.4)),"leaf")
	# Deliberate understory groups knit the trail shoulders and rock feet together.
	for centre:Vector2 in [Vector2(-9,12),Vector2(16,3),Vector2(-20,-11),Vector2(25,-22),Vector2(-15,-54),Vector2(13,-73)]:
		for i in 16:
			var p:=centre+Vector2(_rng.randf_range(-4,4),_rng.randf_range(-4,4))
			_asset(SOURCE+"Fern_1.gltf",_pose(Vector3(p.x,_height(p.x,p.y),p.y),_rng.randf_range(.75,1.65)),"fern")
		for i in 4:
			var p:=centre+Vector2(_rng.randf_range(-4,4),_rng.randf_range(-4,4))
			_asset(SOURCE+"Bush_Common.gltf",_pose(Vector3(p.x,_height(p.x,p.y)-.15,p.y),_rng.randf_range(1.2,2.1)),"leaf")
	# Tall canopy stays out of the central sightline and repeats in uneven groups.
	for p in [Vector3(-16,0,8),Vector3(-62,0,12),Vector3(34,0,14),Vector3(58,0,3),Vector3(-15,0,-47),Vector3(29,0,-44),Vector3(49,0,-102),Vector3(-52,0,-108),Vector3(4,0,-98)]:
		p.y=_height(p.x,p.z)
		_asset(SOURCE+"TwistedTree_%d.gltf"%_rng.randi_range(1,5),_pose(p,_rng.randf_range(.65,1.0)),"tree")
	for i in 95:
		var x:=_rng.randf_range(-80,80);var z:=_rng.randf_range(-175,38)
		if absf(x)<12 or _inside_rock(Vector3(x,0,z),0):continue
		_asset(SOURCE+"Rock_Medium_%d.gltf"%_rng.randi_range(1,3),_pose(Vector3(x,_height(x,z)-.2,z),_rng.randf_range(.5,1.6)),"native")
	# Use actual triangle ray intersections to root every crown plant and face vine.
	for form in _forms:
		var tr:Transform3D=form.transform
		for i in 150:
			var local:=Vector3(_rng.randf_range(-9,9),85,_rng.randf_range(-6,6))
			var origin:Vector3=tr*local
			var hit:=_ray_form(form,origin,Vector3.DOWN)
			if hit.is_empty() or hit.normal.y<.5:continue
			var p:Vector3=hit.position
			if i%27==0:
				_asset(SOURCE+"TwistedTree_%d.gltf"%_rng.randi_range(1,5),_pose(p,_rng.randf_range(.35,.55)),"tree")
			elif i%3==0:_asset(SOURCE+"Fern_1.gltf",_pose(p,_rng.randf_range(1.0,1.8)),"fern")
			else:_asset(SOURCE+"Bush_Common.gltf",_pose(p-Vector3(0,.15,0),_rng.randf_range(1.4,3.0)),"leaf")
		for i in 45:
			var origin:=tr*Vector3(_rng.randf_range(-9,9),_rng.randf_range(6,38),18)
			var direction:Vector3=-tr.basis.z.normalized()
			var hit:=_ray_form(form,origin,direction)
			if hit.is_empty():continue
			var p:Vector3=hit.position
			var vine_basis:=Basis.looking_at(-hit.normal,Vector3.UP)
			_asset("res://assets/Medieval Village MegaKit/glTF/Prop_Vine%d.gltf"%[1,2,4,5,6,9][i%6],Transform3D(vine_basis.scaled(Vector3.ONE*_rng.randf_range(1.6,3.2)),p+hit.normal*.03),"vine")

func _pose(p:Vector3,s:float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,_rng.randf_range(0,TAU)).scaled(Vector3.ONE*s),p)

func _inside_rock(p:Vector3,margin:float) -> bool:
	for form in _forms:
		var b:AABB=_cache["res://assets/MythosMountains/"+form.name+".glb"].bounds
		var local:Vector3=form.transform.affine_inverse()*p
		if local.x>b.position.x-margin and local.x<b.end.x+margin and local.z>b.position.z-margin and local.z<b.end.z+margin:return true
	return false

func _ray_form(form:Dictionary,origin:Vector3,direction:Vector3) -> Dictionary:
	var best:=INF;var point:=Vector3.ZERO;var normal:=Vector3.ZERO
	var inverse:Transform3D=form.transform.affine_inverse()
	var o:=inverse*origin;var d:=inverse.basis*direction
	for piece in _cache["res://assets/MythosMountains/"+form.name+".glb"].pieces:
		var faces:PackedVector3Array=piece.faces
		for j in range(0,faces.size(),3):
			var hit=Geometry3D.ray_intersects_triangle(o,d,faces[j],faces[j+1],faces[j+2])
			if hit==null:continue
			var distance:float=o.distance_squared_to(hit)
			if distance>=best:continue
			best=distance;point=hit
			normal=(faces[j+2]-faces[j]).cross(faces[j+1]-faces[j]).normalized()
	if best==INF:return {}
	return {"position":form.transform*point,"normal":(form.transform.basis*normal).normalized()}

func _asset(path:String,tr:Transform3D,kind:String) -> void:
	if not _cache.has(path):_load_source(path,kind)
	_counts[path]=int(_counts.get(path,0))+1
	for i in _cache[path].pieces.size():
		var key:=path+"#"+str(i)
		if not _batches.has(key):_batches[key]={"piece":_cache[path].pieces[i],"poses":[],"kind":kind}
		_batches[key].poses.append(tr*_cache[path].pieces[i].transform)

func _load_source(path:String,kind:String) -> void:
	var doc:=GLTFDocument.new();var state:=GLTFState.new()
	assert(doc.append_from_file(path,state)==OK,path)
	var scene:Node3D=doc.generate_scene(state)
	var pieces:=[];var bounds:=AABB();var first:=true
	for node:MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
		var tr:=node.transform;var parent:=node.get_parent()
		while parent!=scene and parent is Node3D:tr=parent.transform*tr;parent=parent.get_parent()
		for s in node.mesh.get_surface_count():
			var mesh:=ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,node.mesh.surface_get_arrays(s))
			var mat:Material=node.get_active_material(s)
			if kind=="stone":mat=_rock
			elif mat is StandardMaterial3D:
				mat=mat.duplicate()
				if "Leaves_TwistedTree" in mat.resource_name:
					var texture:Texture2D=mat.albedo_texture
					var sm:=ShaderMaterial.new();var shader:=Shader.new()
					shader.code="shader_type spatial;render_mode cull_disabled;uniform sampler2D leaf_tex:source_color,filter_linear_mipmap_anisotropic; void fragment(){vec4 t=texture(leaf_tex,UV);ALBEDO=vec3(.07,.16,.021)*(.55+.65*t.r);ROUGHNESS=.9;ALPHA=t.a;ALPHA_SCISSOR_THRESHOLD=.45;BACKLIGHT=vec3(.04,.08,.009);}"
					sm.shader=shader;sm.set_shader_parameter("leaf_tex",texture);mat=sm
				elif kind=="grass":
					var sm:=ShaderMaterial.new();sm.shader=load("res://tools/mountain_art/meadow.gdshader")
					sm.set_shader_parameter("blades",true);mat=sm
			mesh.surface_set_material(0,mat)
			var faces:=mesh.get_faces()
			for j in faces.size():faces[j]=tr*faces[j]
			pieces.append({"mesh":mesh,"transform":tr,"faces":faces})
			var b:AABB=tr*mesh.get_aabb();bounds=b if first else bounds.merge(b);first=false
	_cache[path]={"pieces":pieces,"bounds":bounds}
	scene.free()

func _flush() -> void:
	for key in _batches:
		var data:Dictionary=_batches[key]
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=data.piece.mesh;mm.instance_count=data.poses.size()
		for i in data.poses.size():mm.set_instance_transform(i,data.poses[i])
		var node:=MultiMeshInstance3D.new();node.multimesh=mm;_stage.add_child(node)
		if data.kind in ["grass","fern"]:node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if data.kind=="stone":
			for tr:Transform3D in data.poses:
				var body:=StaticBody3D.new();body.transform=tr;_stage.add_child(body)
				var shape:=CollisionShape3D.new();shape.shape=data.piece.mesh.create_trimesh_shape();body.add_child(shape)
