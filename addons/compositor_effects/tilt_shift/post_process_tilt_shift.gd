@tool
extends CompositorEffect
class_name PostProcessTiltShift

@export_group("Settings")

@export_range(0.0, 64.0, 0.5) var blur_amount: float = 4.0:
	set(v):
		mutex.lock()
		blur_amount = v
		mutex.unlock()

@export_range(0.0, 2.0, 0.01) var strength: float = 0.7:
	set(v):
		mutex.lock()
		strength = v
		mutex.unlock()

@export_group("Focus Plane")

@export_range(0.0, 500.0, 0.1) var focus_distance: float = 35.0:
	set(v):
		mutex.lock()
		focus_distance = v
		mutex.unlock()

@export_range(0.0, 100.0, 0.1) var near_start: float = 40.0:
	set(v):
		mutex.lock()
		near_start = v
		mutex.unlock()

@export_range(0.0, 100.0, 0.1) var near_end: float = 47.0:
	set(v):
		mutex.lock()
		near_end = v
		mutex.unlock()

@export_range(0.0, 100.0, 0.1) var far_start: float = 50.0:
	set(v):
		mutex.lock()
		far_start = v
		mutex.unlock()

@export_range(0.0, 500.0, 0.1) var far_end: float = 100.0:
	set(v):
		mutex.lock()
		far_end = v
		mutex.unlock()

@export_group("Advanced Settings")

@export_subgroup("Bokeh")

@export_range(0.0, 10.0, 0.1) var highlight_boost: float = 0.0:
	set(v):
		mutex.lock()
		highlight_boost = v
		mutex.unlock()

@export_range(0.0, 1.0, 0.01) var highlight_threshold: float = 0.8:
	set(v):
		mutex.lock()
		highlight_threshold = v
		mutex.unlock()

@export_subgroup("Looks")

@export_range(1.0, 3.0, 0.01) var saturation_boost: float = 1.3:
	set(v):
		mutex.lock()
		saturation_boost = v
		mutex.unlock()

@export_range(0.0, 20.0, 0.1) var sigma: float = 2.0:
	set(v):
		mutex.lock()
		sigma = v
		mutex.unlock()

@export_subgroup("Camera")

@export_range(0.01, 10.0, 0.01) var near_plane: float = 1.0:
	set(v):
		mutex.lock()
		near_plane = v
		mutex.unlock()

@export_range(10.0, 10000.0, 10.0) var far_plane: float = 500.0:
	set(v):
		mutex.lock()
		far_plane = v
		mutex.unlock()

@export var is_orthographic: bool = true:
	set(v):
		mutex.lock()
		is_orthographic = v
		mutex.unlock()

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var _shader_copy: RID
var _pipe_copy: RID
var _nearest_sampler: RID

var mutex: Mutex = Mutex.new()
var _intermediate: RID
var _intermediate_b: RID
var _last_size: Vector2i = Vector2i()


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_depth = true
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		return
	_create_pipeline()


func _create_pipeline() -> void:
	var shader_file: RDShaderFile = load("res://addons/compositor_effects/tilt_shift/tilt_shift.glsl")
	if shader_file == null:
		return

	var spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(spirv)
	if not shader.is_valid():
		return

	pipeline = rd.compute_pipeline_create(shader)

	var copy_file: RDShaderFile = load("res://addons/compositor_effects/shared/copy.glsl")
	if copy_file != null:
		_shader_copy = rd.shader_create_from_spirv(copy_file.get_spirv())
		if _shader_copy.is_valid():
			_pipe_copy = rd.compute_pipeline_create(_shader_copy)

	var sampler_state := RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_nearest_sampler = rd.sampler_create(sampler_state)


func _render_callback(
	p_effect_callback_type: EffectCallbackType,
	p_render_data: RenderData
) -> void:
	if rd == null:
		return
	if not shader.is_valid() or not pipeline.is_valid():
		return

	var render_scene_buffers: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
	if render_scene_buffers == null:
		return

	var size: Vector2i = render_scene_buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return

	if size != _last_size or not _intermediate.is_valid() or not _intermediate_b.is_valid():
		if _intermediate.is_valid():
			rd.free_rid(_intermediate)
		if _intermediate_b.is_valid():
			rd.free_rid(_intermediate_b)
		var fmt := RDTextureFormat.new()
		fmt.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
		fmt.width = size.x
		fmt.height = size.y
		fmt.usage_bits = (
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT |
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT |
			RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		)
		_intermediate = rd.texture_create(fmt, RDTextureView.new())
		_intermediate_b = rd.texture_create(fmt, RDTextureView.new())
		_last_size = size

	mutex.lock()
	var _fd: float = focus_distance
	var _ns: float = near_start
	var _ne: float = near_end
	var _fs: float = far_start
	var _fe: float = far_end
	var _ba: float = blur_amount
	var _si: float = sigma
	var _sb: float = saturation_boost
	var _hb: float = highlight_boost
	var _ht: float = highlight_threshold
	var _st: float = strength
	var _np: float = near_plane
	var _fp: float = far_plane
	var _iso: float = 1.0 if is_orthographic else 0.0
	mutex.unlock()

	var push_h: PackedFloat32Array = PackedFloat32Array([
		_fd, _ns, _ne, _fs,
		_fe, _ba, _si, _sb,
		_hb, _ht, _st, 1.0,
		0.0, _np, _fp, _iso,
		0.0, 0.0, 0.0, 0.0
	])
	var push_v: PackedFloat32Array = PackedFloat32Array([
		_fd, _ns, _ne, _fs,
		_fe, _ba, _si, _sb,
		_hb, _ht, _st, 0.0,
		1.0, _np, _fp, _iso,
		0.0, 0.0, 0.0, 0.0
	])

	var x_groups: int = (size.x + 15) / 16
	var y_groups: int = (size.y + 15) / 16

	for view: int in render_scene_buffers.get_view_count():
		var color_image: RID = render_scene_buffers.get_color_layer(view)
		var depth_image: RID = render_scene_buffers.get_depth_layer(view)

		if not color_image.is_valid() or not depth_image.is_valid():
			continue
		if not _intermediate.is_valid() or not _intermediate_b.is_valid():
			continue
		if not _nearest_sampler.is_valid():
			continue

		if _pipe_copy.is_valid():
			var u_cp_src: RDUniform = RDUniform.new()
			u_cp_src.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
			u_cp_src.binding = 0
			u_cp_src.add_id(color_image)
			var set_cp_src: RID = UniformSetCacheRD.get_cache(_shader_copy, 0, [u_cp_src])

			var u_cp_dst: RDUniform = RDUniform.new()
			u_cp_dst.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
			u_cp_dst.binding = 0
			u_cp_dst.add_id(_intermediate)
			var set_cp_dst: RID = UniformSetCacheRD.get_cache(_shader_copy, 1, [u_cp_dst])

			var cl_copy: int = rd.compute_list_begin()
			rd.compute_list_bind_compute_pipeline(cl_copy, _pipe_copy)
			rd.compute_list_bind_uniform_set(cl_copy, set_cp_src, 0)
			rd.compute_list_bind_uniform_set(cl_copy, set_cp_dst, 1)
			rd.compute_list_dispatch(cl_copy, x_groups, y_groups, 1)
			rd.compute_list_end()

		var u_src_h: RDUniform = RDUniform.new()
		u_src_h.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		u_src_h.binding = 0
		u_src_h.add_id(_intermediate)
		var set_src_h: RID = UniformSetCacheRD.get_cache(shader, 0, [u_src_h])

		var u_dst_h: RDUniform = RDUniform.new()
		u_dst_h.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		u_dst_h.binding = 0
		u_dst_h.add_id(_intermediate_b)
		var set_dst_h: RID = UniformSetCacheRD.get_cache(shader, 1, [u_dst_h])

		var u_depth_h: RDUniform = RDUniform.new()
		u_depth_h.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		u_depth_h.binding = 0
		u_depth_h.add_id(_nearest_sampler)
		u_depth_h.add_id(depth_image)
		var set_depth_h: RID = UniformSetCacheRD.get_cache(shader, 2, [u_depth_h])

		var cl_h: int = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(cl_h, pipeline)
		rd.compute_list_bind_uniform_set(cl_h, set_src_h, 0)
		rd.compute_list_bind_uniform_set(cl_h, set_dst_h, 1)
		rd.compute_list_bind_uniform_set(cl_h, set_depth_h, 2)
		rd.compute_list_set_push_constant(cl_h, push_h.to_byte_array(), 80)
		rd.compute_list_dispatch(cl_h, x_groups, y_groups, 1)
		rd.compute_list_end()

		var u_src_v: RDUniform = RDUniform.new()
		u_src_v.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		u_src_v.binding = 0
		u_src_v.add_id(_intermediate_b)
		var set_src_v: RID = UniformSetCacheRD.get_cache(shader, 0, [u_src_v])

		var u_dst_v: RDUniform = RDUniform.new()
		u_dst_v.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		u_dst_v.binding = 0
		u_dst_v.add_id(color_image)
		var set_dst_v: RID = UniformSetCacheRD.get_cache(shader, 1, [u_dst_v])

		var u_depth_v: RDUniform = RDUniform.new()
		u_depth_v.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		u_depth_v.binding = 0
		u_depth_v.add_id(_nearest_sampler)
		u_depth_v.add_id(depth_image)
		var set_depth_v: RID = UniformSetCacheRD.get_cache(shader, 2, [u_depth_v])

		var cl_v: int = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(cl_v, pipeline)
		rd.compute_list_bind_uniform_set(cl_v, set_src_v, 0)
		rd.compute_list_bind_uniform_set(cl_v, set_dst_v, 1)
		rd.compute_list_bind_uniform_set(cl_v, set_depth_v, 2)
		rd.compute_list_set_push_constant(cl_v, push_v.to_byte_array(), 80)
		rd.compute_list_dispatch(cl_v, x_groups, y_groups, 1)
		rd.compute_list_end()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup()


func _cleanup() -> void:
	if rd == null:
		return
	if _pipe_copy.is_valid():
		rd.free_rid(_pipe_copy)
		_pipe_copy = RID()
	if _shader_copy.is_valid():
		rd.free_rid(_shader_copy)
		_shader_copy = RID()
	if pipeline.is_valid():
		rd.free_rid(pipeline)
		pipeline = RID()
	if shader.is_valid():
		rd.free_rid(shader)
		shader = RID()
	if _intermediate.is_valid():
		rd.free_rid(_intermediate)
		_intermediate = RID()
	if _intermediate_b.is_valid():
		rd.free_rid(_intermediate_b)
		_intermediate_b = RID()
	if _nearest_sampler.is_valid():
		rd.free_rid(_nearest_sampler)
		_nearest_sampler = RID()
