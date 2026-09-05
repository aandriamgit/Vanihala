extends Camera3D
# RTS diorama camera (Tiny Glade style).
#
# Fixes over the previous version:
#  - FIXED eye distance: the camera never moves closer/farther when zooming,
#    so the near plane can never slice geometry (the old `size * 1.2`
#    coupling caused near-plane clipping at close zoom).
#  - near/far planes are wide and always valid for an orthographic camera
#    (linear depth => no precision cost).
#  - Multiplicative wheel zoom (constant *feel* at every zoom level),
#    exponentially smoothed, frame-rate independent.
#  - Zoom without the wheel: hold +/− (numpad too) for continuous zoom, or
#    hold RMB and drag vertically (drag up = zoom in).
#  - Zoom-to-cursor: the world point under the mouse stays put while zooming.
#  - Camera transform is re-applied EVERY frame (zoom, rotate and move all
#    stay in sync, and depth stays valid for the tilt-shift effect).
#  - MMB drag pans by raycasting the ground each event (no stale "start ray").
#  - Mouse-delta rotation no longer scales with delta time.
#  - Auto-focuses the PostProcessTiltShift effect: the focus plane tracks the
#    orbit center and the blur bands track the ortho size, so the diorama
#    stays in focus while moving/zooming.

@export_category("Movement")
@export var camera_speed: float = 20.0
@export_range(0.1, 50.0) var movement_smoothing: float = 10.0
@export var boost_multiplier: float = 2.5

@export_category("Zoom")
@export var zoom_min: float = 6.0
@export var zoom_max: float = 150.0
@export_range(1.01, 2.0) var zoom_factor: float = 1.18
@export_range(0.1, 50.0) var zoom_smoothing: float = 8.0
@export var zoom_to_cursor: bool = true
## Hold +/− (or numpad +/-) for continuous multiplicative zoom.
@export var zoom_keyboard_enabled: bool = true
## zoom_factor steps applied per second while the key is held.
@export_range(0.5, 30.0) var keyboard_zoom_speed: float = 6.0
## Hold RMB and drag vertically to zoom (drag up = zoom in).
@export var zoom_rmb_drag_enabled: bool = true
## zoom_factor steps applied per 100 px of vertical drag.
@export_range(0.1, 5.0) var drag_zoom_steps_per_100px: float = 1.0

@export_category("Edge scrolling")
@export var edge_scroll_enabled: bool = true
@export var edge_scroll_margin: float = 24.0
@export var edge_scroll_speed: float = 18.0

@export_category("Rotation")
@export_range(0.01, 2.0) var yaw_deg_per_px: float = 0.3
@export var keyboard_yaw_speed: float = 120.0
@export_range(5.0, 89.0) var pitch_min_deg: float = 30.0
@export_range(5.0, 89.0) var pitch_max_deg: float = 65.0
@export_range(5.0, 89.0) var initial_pitch_deg: float = 50.0
@export var capture_mouse_on_mmb: bool = false

@export_category("Rig")
## Distance from the camera to the orbit center. CONSTANT while zooming —
## only `size` changes. This is what prevents near-plane clipping.
@export_range(10.0, 200.0) var eye_distance: float = 60.0

@export_category("Tilt-shift auto focus")
## Push focus_distance / blur bands / near-far planes into the
## PostProcessTiltShift effect every frame so the effect tracks the camera.
@export var auto_focus_tilt_shift: bool = true
## In-focus half-width on the view axis = size * this.
@export_range(0.1, 2.0) var focus_band_scale: float = 0.5
## Blur falloff width on the view axis = size * this.
@export_range(0.1, 4.0) var blur_ramp_scale: float = 1.2

var _center := Vector3.ZERO
var _target_center := Vector3.ZERO
var _target_size := 25.0
var _yaw := 0.0
var _pitch := 0.0
var _vel := Vector3.ZERO
var _is_mmb_rotating := false
var _is_mmb_panning := false
var _is_rmb_zooming := false
var _last_mouse := Vector2.ZERO
var _tilt_shift: CompositorEffect = null

const _NO_HIT := Vector3(INF, INF, INF)
const _UP := Vector3.UP


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	# Ortho depth is linear: a wide near..far range costs no precision.
	near = 0.5
	far = eye_distance + 300.0
	_target_size = clampf(size if size > 0.0 else 25.0, zoom_min, zoom_max)
	size = _target_size
	_pitch = clampf(deg_to_rad(initial_pitch_deg), deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))
	_yaw = 0.0
	_find_tilt_shift()
	_apply_transform()


func _exp_blend(rate: float, delta: float) -> float:
	# Frame-rate independent exponential smoothing factor.
	return 1.0 - exp(-rate * delta)


func _process(delta: float) -> void:
	var movement := Vector3.ZERO

	if Input.is_action_pressed("ui_right"):
		movement.x += 1
	if Input.is_action_pressed("ui_left"):
		movement.x -= 1
	if Input.is_action_pressed("ui_up"):
		movement.z -= 1
	if Input.is_action_pressed("ui_down"):
		movement.z += 1

	if edge_scroll_enabled and not (_is_mmb_rotating or _is_mmb_panning) \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		var vp := get_viewport().get_visible_rect().size
		var mouse_pos := get_viewport().get_mouse_position()
		if mouse_pos.x >= 0.0 and mouse_pos.y >= 0.0 and mouse_pos.x <= vp.x and mouse_pos.y <= vp.y:
			if mouse_pos.x < edge_scroll_margin:
				movement.x -= 1
			elif mouse_pos.x > vp.x - edge_scroll_margin:
				movement.x += 1
			if mouse_pos.y < edge_scroll_margin:
				movement.z -= 1
			elif mouse_pos.y > vp.y - edge_scroll_margin:
				movement.z += 1

	var boost := boost_multiplier if Input.is_action_pressed("ui_shift") else 1.0

	var target_vel := Vector3.ZERO
	if movement.length_squared() > 0.0:
		target_vel = movement.normalized().rotated(_UP, _yaw) * camera_speed * boost

	_vel = _vel.lerp(target_vel, _exp_blend(movement_smoothing, delta))
	if _vel.length_squared() > 0.0001:
		_target_center += _vel * delta

	if Input.is_key_pressed(KEY_Q):
		_yaw += deg_to_rad(keyboard_yaw_speed) * delta
	if Input.is_key_pressed(KEY_E):
		_yaw -= deg_to_rad(keyboard_yaw_speed) * delta

	if zoom_keyboard_enabled:
		# zoom_dir: +1 = zoom in (smaller size), −1 = zoom out.
		var zoom_dir := 0.0
		if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD):
			zoom_dir += 1.0
		if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
			zoom_dir -= 1.0
		if zoom_dir != 0.0:
			_zoom_step(pow(zoom_factor, -zoom_dir * keyboard_zoom_speed * delta))

	# Smooth both the orbit center and the ortho size (frame-rate independent).
	_center = _center.lerp(_target_center, _exp_blend(movement_smoothing, delta))
	if not is_equal_approx(size, _target_size):
		size = lerpf(size, _target_size, _exp_blend(zoom_smoothing, delta))
		if absf(size - _target_size) < 0.002:
			size = _target_size

	_apply_transform()
	_update_tilt_shift()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_step(1.0 / zoom_factor)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_step(zoom_factor)
			MOUSE_BUTTON_MIDDLE:
				if Input.is_key_pressed(KEY_SHIFT):
					_is_mmb_panning = true
					_last_mouse = get_viewport().get_mouse_position()
				else:
					_is_mmb_rotating = true
				if capture_mouse_on_mmb:
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			MOUSE_BUTTON_RIGHT:
				if zoom_rmb_drag_enabled:
					_is_rmb_zooming = true
	elif event is InputEventMouseButton and not event.pressed:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				_is_mmb_panning = false
				_is_mmb_rotating = false
				if capture_mouse_on_mmb:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			MOUSE_BUTTON_RIGHT:
				_is_rmb_zooming = false

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _is_mmb_panning:
			# Raycast ground plane (at current center height) for the previous
			# and current mouse positions; drag the world with the cursor.
			var mouse := get_viewport().get_mouse_position()
			var prev_hit := _screen_to_ground(_last_mouse)
			var cur_hit := _screen_to_ground(mouse)
			_last_mouse = mouse
			if prev_hit != _NO_HIT and cur_hit != _NO_HIT:
				var d := cur_hit - prev_hit
				_target_center -= d
				_center -= d # instant: no rubber-band while dragging
				_apply_transform()
		elif _is_mmb_rotating:
			# Mouse deltas are already per-event: NO delta-time scaling.
			var dx := -mm.relative.x * deg_to_rad(yaw_deg_per_px)
			_yaw += dx
			var pitch_step := mm.relative.y * deg_to_rad(yaw_deg_per_px)
			_pitch = clampf(_pitch + pitch_step, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))
			_apply_transform()
		elif _is_rmb_zooming:
			# Drag up = zoom in, drag down = zoom out (same direction as the
			# wheel). Routes through _zoom_step, so smoothing and cursor
			# anchoring behave exactly like the wheel.
			var steps := mm.relative.y * drag_zoom_steps_per_100px * 0.01
			_zoom_step(pow(zoom_factor, steps))


func _zoom_step(factor: float) -> void:
	var s0 := _target_size
	var s1 := clampf(s0 * factor, zoom_min, zoom_max)
	if is_equal_approx(s0, s1):
		return
	_target_size = s1
	if zoom_to_cursor:
		var anchor := _screen_to_ground(get_viewport().get_mouse_position())
		if anchor != _NO_HIT:
			# Orthographic exact zoom-to-cursor: for an ortho projection the
			# image depends only on the eye's LATERAL position, orientation and
			# size — so to keep the world point under the cursor pinned, shift
			# the eye (and thus the center) by (1 - k) * perpendicular offset
			# from the eye to that point (k = size ratio).
			var view_dir := (position - _center).normalized()
			var off := anchor - position
			var perp := off - view_dir * off.dot(view_dir)
			var d := (1.0 - s1 / s0) * perp
			_target_center += d
			_center += d # instant: no drift while zooming
			_apply_transform()


func _screen_to_ground(screen_pos: Vector2) -> Vector3:
	var dir := project_ray_normal(screen_pos)
	if dir == Vector3.ZERO:
		return _NO_HIT
	var denom := dir.dot(_UP)
	if absf(denom) < 1e-5:
		return _NO_HIT
	var t := (_center.y - project_ray_origin(screen_pos).y) / denom
	if t <= 0.0:
		return _NO_HIT
	return project_ray_origin(screen_pos) + dir * t


func _apply_transform() -> void:
	var dir := Vector3(
		sin(_yaw) * cos(_pitch),
		sin(_pitch),
		cos(_yaw) * cos(_pitch)
	).normalized()
	position = _center + dir * eye_distance
	look_at(_center, _UP)


func _find_tilt_shift() -> void:
	_tilt_shift = null
	var comp := compositor
	if comp == null:
		return
	for eff in comp.compositor_effects:
		if eff is PostProcessTiltShift:
			_tilt_shift = eff
			return


func _update_tilt_shift() -> void:
	if not auto_focus_tilt_shift or _tilt_shift == null:
		return
	# Ground at the screen center is exactly `eye_distance` deep on the view
	# axis. In-focus band scales with the ortho size so the diorama stays
	# sharp at every zoom level, and the blur ramps scale with it too.
	# Cap band+ramp below eye_distance so near_start never crosses 0 and the
	# effect's export ranges are never clamped at extreme zoom-out.
	var band := clampf(size * focus_band_scale, 1.0, eye_distance * 0.45)
	var ramp := minf(size * blur_ramp_scale, eye_distance * 0.5)
	_tilt_shift.focus_distance = eye_distance
	_tilt_shift.near_end = eye_distance - band
	_tilt_shift.near_start = eye_distance - band - ramp
	_tilt_shift.far_start = eye_distance + band
	_tilt_shift.far_end = eye_distance + band + ramp
	# Keep depth linearization exact: always report the real near/far.
	_tilt_shift.near_plane = near
	_tilt_shift.far_plane = far
