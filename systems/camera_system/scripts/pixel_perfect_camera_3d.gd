class_name PixelPerfectCamera3D extends Camera3D

@export var snap: bool = true
@export var snap_objects: bool = true
@export var default_ortho_size: float = 10.0:
	set(v):
		default_ortho_size = v
		if is_inside_tree(): size = v

const _TARGET_FOV: float = deg_to_rad(10.0)
const _FOV_FLOOR: float = deg_to_rad(1.0)
const _PIVOT_Z: float = 20.0
const _DEPTH: float = 50.0

var texel_error: Vector2 = Vector2.ZERO
var _current_fov: float = 0.0
var _persp_active: bool = false
var _anim: Tween = null

var _px_size: float = 0.0
var _tracked: Array[Node]
var _origins: Array[Vector3]

@onready var _last_rot: Vector3 = global_rotation
@onready var _grid: Transform3D = global_transform

func _ready() -> void:
	default_ortho_size = default_ortho_size
	RenderingServer.frame_post_draw.connect(_restore_tracked)
	_enter_ortho()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_P:
		if _persp_active: _leave_persp()
		else: _enter_persp()

func _enter_ortho() -> void:
	_current_fov = 0.0
	_persp_active = false
	projection = PROJECTION_ORTHOGONAL
	position.z = _PIVOT_Z
	near = 0.0
	far = _DEPTH
	size = default_ortho_size

func _enter_persp() -> void:
	if _anim: _anim.kill()
	_current_fov = _FOV_FLOOR
	_flip_projection_deferred(true)
	_anim = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_anim.tween_property(self, "_current_fov", _TARGET_FOV, 0.3)

func _leave_persp() -> void:
	if _anim: _anim.kill()
	_anim = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_anim.tween_property(self, "_current_fov", _FOV_FLOOR, 0.3)
	_anim.chain().tween_callback(func(): _flip_projection_deferred(false))

func _flip_projection_deferred(going_persp: bool) -> void:
	for sig in [_commit_persp, _commit_ortho]:
		if RenderingServer.frame_post_draw.is_connected(sig):
			RenderingServer.frame_post_draw.disconnect(sig)
	var target := _commit_persp if going_persp else _commit_ortho
	RenderingServer.frame_post_draw.connect(target, CONNECT_ONE_SHOT)

func _commit_persp() -> void:
	_persp_active = true
	projection = PROJECTION_PERSPECTIVE
	_refresh_persp()

func _commit_ortho() -> void:
	_enter_ortho()

func _refresh_persp() -> void:
	var pullback: float = (default_ortho_size * 0.5) / tan(_current_fov * 0.5)
	fov = rad_to_deg(_current_fov)
	position.z = _PIVOT_Z + pullback
	near = pullback
	far = pullback + _DEPTH

func _process(_dt: float) -> void:
	if _persp_active:
		_refresh_persp()
		texel_error = Vector2.ZERO
		return

	if global_rotation != _last_rot:
		_last_rot = global_rotation
		_grid = global_transform

	_px_size = size / float((get_viewport() as SubViewport).size.y)
	var local_pos: Vector3 = global_position * _grid
	var aligned: Vector3 = local_pos.snapped(Vector3.ONE * _px_size)
	var drift: Vector3 = aligned - local_pos

	if snap:
		h_offset = drift.x
		v_offset = drift.y
		texel_error = Vector2(drift.x, -drift.y) / _px_size
		if snap_objects: _move_tracked.call_deferred()
	else:
		texel_error = Vector2.ZERO

func _move_tracked() -> void:
	_tracked = get_tree().get_nodes_in_group("snap")
	_origins.resize(_tracked.size())
	for i in _tracked.size():
		var obj = _tracked[i] as Node3D
		_origins[i] = obj.global_position
		var in_grid: Vector3 = obj.global_position * _grid
		var nudged: Vector3 = in_grid.snapped(Vector3(_px_size, _px_size, 0.0))
		obj.global_position = nudged * _grid.affine_inverse()

func _restore_tracked() -> void:
	for i in _tracked.size():
		(_tracked[i] as Node3D).global_position = _origins[i]
	_tracked.clear()
