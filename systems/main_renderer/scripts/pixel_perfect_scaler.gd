class_name PixelPerfectScaler extends Control

@onready var container: SubViewportContainer = %SubViewportContainer
@export var target_viewport: SubViewport

var snap_pixels: bool = true

func _process(_dt: float) -> void:
	var win: Vector2 = Vector2(get_window().size)
	var inner: Vector2 = Vector2(target_viewport.size - Vector2i(2, 2))

	var ratio: Vector2 = win / inner
	var uniform: float = minf(ratio.x, ratio.y)

	container.scale = Vector2(uniform, uniform)

	var fitted: Vector2 = inner * uniform
	var origin: Vector2 = (win - fitted) / 2.0
	var target_pos: Vector2 = origin - Vector2.ONE * uniform
	var snapped_pos: Vector2 = target_pos.round()

	var pixel_drift: Vector2 = snapped_pos - target_pos
	var uv_drift: Vector2 = pixel_drift / uniform

	if not snap_pixels:
		container.position = snapped_pos
		return

	var mat: ShaderMaterial = container.material as ShaderMaterial
	var cam: PixelPerfectCamera3D = target_viewport.get_camera_3d() as PixelPerfectCamera3D

	if not mat:
		container.position = snapped_pos
		return

	# var whole_scale: bool = ratio == ratio.floor()
	# var skip_sub: bool = whole_scale
	var whole_scale_x: bool = is_equal_approx(ratio.x, floor(ratio.x))
	var whole_scale_y: bool = is_equal_approx(ratio.y, floor(ratio.y))
	var skip_sub: bool = whole_scale_x and whole_scale_y

	if cam == null:
		mat.set_shader_parameter("texel_offset", Vector2.ZERO)
	else:
		var final_drift: Vector2 = Vector2.ZERO if skip_sub else uv_drift
		mat.set_shader_parameter("texel_offset", cam.texel_error - final_drift)

	container.position = snapped_pos
