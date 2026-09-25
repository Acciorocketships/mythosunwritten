extends CompositorEffect
## Read-only diagnostic: classify the HDR scene every rendered frame, before
## tonemapping. Small asynchronous results do not wait for full image readback.
const GRID := Vector2i(128,72)
const GROUPS := 144
const HEADER_BYTES := GROUPS*16
const BUFFER_BYTES := HEADER_BYTES+128*72*4
const CODE := """
#version 450
layout(local_size_x=8,local_size_y=8,local_size_z=1) in;
layout(rgba16f,set=0,binding=0) uniform readonly image2D scene_color;
layout(set=0,binding=1,std430) buffer Result { uint values[]; } result;
layout(push_constant,std430) uniform Parameters { vec2 size; vec2 unused; } params;
shared uint blacks;
shared uint invalids;
shared uint invalid_rgb;
void main() {
    uint local_id=gl_LocalInvocationIndex;
    if(local_id==0u) { blacks=0u; invalids=0u; invalid_rgb=0u; }
    barrier();
    uvec2 sample_id=gl_GlobalInvocationID.xy;
    ivec2 pixel=ivec2((vec2(sample_id)+vec2(0.5))*params.size/vec2(128.0,72.0));
    vec4 color=imageLoad(scene_color,pixel);
    bool invalid=any(isnan(color))||any(isinf(color));
    bool black=max(color.r,max(color.g,color.b))<=0.00001;
    if(invalid) atomicAdd(invalids,1u);
    if(any(isnan(color.rgb))||any(isinf(color.rgb))) atomicAdd(invalid_rgb,1u);
    if(black) atomicAdd(blacks,1u);
    vec3 preview=invalid ? vec3(1,0,1) : clamp(color.rgb/(vec3(1)+max(color.rgb,vec3(0))),vec3(0),vec3(1));
    result.values[576u+sample_id.y*128u+sample_id.x]=packUnorm4x8(vec4(preview,1));
    barrier();
    if(local_id==0u) {
        uint group=gl_WorkGroupID.y*16u+gl_WorkGroupID.x;
        result.values[group*4u]=blacks;
        result.values[group*4u+1u]=invalids;
        result.values[group*4u+2u]=64u;
        result.values[group*4u+3u]=invalid_rgb;
    }
}
"""
var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _buffer: RID
var _sequence := 0
var _mutex := Mutex.new()
var _completed: Array[Dictionary] = []
var preview_frames: Array[int] = []
var decode_marker := false

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true

func _render_callback(kind: int, data: RenderData) -> void:
	if kind != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT: return
	if _rd == null:
		_rd = RenderingServer.get_rendering_device()
		var source := RDShaderSource.new()
		source.source_compute = CODE
		var spirv := _rd.shader_compile_spirv_from_source(source)
		assert(spirv.compile_error_compute.is_empty(),spirv.compile_error_compute)
		_shader = _rd.shader_create_from_spirv(spirv)
		_pipeline = _rd.compute_pipeline_create(_shader)
		_buffer = _rd.storage_buffer_create(BUFFER_BYTES)
	var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
	var size := buffers.get_internal_size()
	if size.x <= 0 or size.y <= 0: return
	var color := RDUniform.new()
	color.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	color.binding = 0
	color.add_id(buffers.get_color_layer(0))
	var result := RDUniform.new()
	result.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	result.binding = 1
	result.add_id(_buffer)
	var uniforms := UniformSetCacheRD.get_cache(_shader,0,[color,result])
	var list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list,_pipeline)
	_rd.compute_list_bind_uniform_set(list,uniforms,0)
	_rd.compute_list_set_push_constant(list,PackedFloat32Array([size.x,size.y,0,0]).to_byte_array(),16)
	_rd.compute_list_dispatch(list,16,9,1)
	_rd.compute_list_end()
	var pose := data.get_render_scene_data().get_cam_transform()
	var error := _rd.buffer_get_data_async(_buffer,_receive.bind(_sequence,pose))
	assert(error == OK)
	_sequence += 1

func _receive(bytes: PackedByteArray, sequence: int, pose: Transform3D) -> void:
	var black := 0
	var invalid := 0
	var total := 0
	var rgb_invalid := 0
	for group in GROUPS:
		black += bytes.decode_u32(group*16)
		invalid += bytes.decode_u32(group*16+4)
		total += bytes.decode_u32(group*16+8)
		rgb_invalid += bytes.decode_u32(group*16+12)
	var row := {"frame":sequence,"black":black,"invalid":invalid,"samples":total,"camera":str(pose),
		"camera_origin": [pose.origin.x,pose.origin.y,pose.origin.z], "invalid_rgb":rgb_invalid}
	if decode_marker:
		var tag := 0
		for channel in 3:
			var value := float(bytes[HEADER_BYTES+channel])/255.0
			var part := roundi(value/maxf(1.0-value,.0001)*32.0)-1
			tag += part << (channel*5)
		row.rendered_tick = tag
	assert(total == 9216,"Incomplete GPU diagnostic readback")
	if black > 184 or invalid > 0 or sequence in preview_frames:
		row["preview"] = bytes.slice(HEADER_BYTES)
	_mutex.lock()
	_completed.append(row)
	_mutex.unlock()

func take_samples() -> Array[Dictionary]:
	_mutex.lock()
	var rows := _completed
	_completed = []
	_mutex.unlock()
	return rows

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd != null:
		if _shader.is_valid(): _rd.free_rid(_shader)
		if _buffer.is_valid(): _rd.free_rid(_buffer)
