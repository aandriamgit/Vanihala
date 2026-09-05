extends Camera3D
# RTS diorama camera (Tiny Glade style) — the project's camera rig.
#
# Design notes (why it is built this way):
#  - Orthographic diorama view. The eye sits at a base distance and is
#    pushed back ALONG the view axis just enough that the near plane can
#    never intersect the ground inside the view. For an ortho camera that
#    push is visually invisible (framing depends only on size, orientation
#    and LATERAL eye position) but it kills bottom-of-screen ground
#    clipping when zoomed out.
#  - Multiplicative zoom with exponential smoothing, frame-rate
#    independent. Anchored zoom-to-cursor is applied PER FRAME while the
#    size glides, so the point under the cursor stays pixel-stable through
#    the whole zoom animation (not just at the endpoints).
#  - The orbit center is PINNED to an absolute ground plane
#    (`ground_height`): pan/zoom anchors raycast against that fixed plane,
#    never against the live center height, so repeated zoom steps can
#    never float the center into the sky (unstable feedback loop).
#  - Pan uses ONE smoothing stage (filtered velocity, direct integration):
#    responsive start, smooth stop, no double-filter input lag. Keyboard,
#    edge scroll and boost feed the same filter; speed scales with the
#    view size (fast glides zoomed out, precise control zoomed in).
#  - Zoom-adaptive pitch limits (based on the CURRENT size): zoomed out the
#    camera eases toward a top-down map view; zoomed in the full diorama
#    angle range is free. Never snaps.
#  - Auto-focuses the PostProcessTiltShift effect: focus plane tracks the
#    orbit center, blur bands track the ortho size, and the effect fades
#    out with zoom (hard-disabled — zero GPU cost — once fully faded).

@export_category("Movement")
@export var camera_speed: float = 20.0
## Separate speed for screen-edge scrolling.
@export var edge_scroll_speed: float = 18.0
@export_range(0.1, 50.0) var movement_smoothing: float = 10.0
@export var boost_multiplier: float = 2.5
## Pan speed scales with the current view size: fast glides zoomed out,
## precise control zoomed in. Scales keyboard, edge scroll and boost alike.
@export var speed_scale_with_zoom: bool = true
## View size at which pan speed is 1:1 with camera_speed.
@export_range(1.0, 200.0) var speed_ref_size: float = 25.0
@export_range(0.05, 10.0) var speed_min_scale: float = 0.3
@export_range(0.05, 10.0) var speed_max_scale: float = 5.0

@export_category("Zoom")
@export var zoom_min: float = 6.0
@export var zoom_max: float = 150.0
@export_range(1.01, 2.0) var zoom_factor: float = 1.18
@export_range(0.1, 50.0) var zoom_smoothing: float = 8.0
## Keep the world point under the cursor pinned while zooming (guarded:
## anchors far outside the view are ignored).
@export var zoom_to_cursor: bool = true
## Tilt-shift fades out as you zoom out and fades back in when you zoom in.
@export var tilt_shift_fade_with_zoom: bool = true
## View size at/below which the effect is at full strength.
@export_range(6.0, 300.0) var tilt_shift_full_size: float = 45.0
## View size at/above which the effect is fully disabled (zero GPU cost).
@export_range(6.0, 300.0) var tilt_shift_off_size: float = 90.0
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

@export_category("Rotation")
@export_range(0.01, 2.0) var yaw_deg_per_px: float = 0.3
@export var keyboard_yaw_speed: float = 120.0
@export_range(5.0, 89.0) var pitch_min_deg: float = 30.0
@export_range(5.0, 89.0) var pitch_max_deg: float = 65.0
@export_range(5.0, 89.0) var initial_pitch_deg: float = 50.0
@export var capture_mouse_on_mmb: bool = false

## Pitch limits widen toward a top-down map view when zoomed out (the camera
## gently eases into the allowed band — never a snap).
@export var adaptive_pitch: bool = true
## Zoomed-out pitch limits (view size >= pitch_anchor_out_size).
@export_range(5.0, 89.0) var pitch_out_min_deg: float = 55.0
@export_range(5.0, 89.0) var pitch_out_max_deg: float = 80.0
## Ortho size anchors between the close-zoom and zoomed-out pitch limits.
@export_range(1.0, 300.0) var pitch_anchor_in_size: float = 25.0
@export_range(1.0, 300.0) var pitch_anchor_out_size: float = 110.0

@export_category("Rig")
## Base distance from the camera to the orbit center. The eye may be pushed
## farther back along the view axis to keep the near plane clear of the
## ground (see _apply_transform); framing is unaffected either way.
@export_range(10.0, 200.0) var eye_distance: float = 60.0
## World height of the orbit plane. Pan/zoom anchors raycast against THIS
## absolute plane (never the live center height) so the orbit center can
## never drift off the ground through repeated zoom anchoring.
@export_range(-100.0, 100.0) var ground_height: float = 0.0

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
var _ts_base_strength := -1.0
# Actual eye distance (>= eye_distance base): grows with view size / pitch
# so the near plane never clips the ground at the bottom of the view.
var _eye_dist := 60.0
# Zoom anchoring: the world point to keep pinned while the size glides
# toward _target_size.
var _zoom_anchor := Vector3(INF, INF, INF)

const _NO_HIT := Vector3(INF, INF, INF)
const _UP := Vector3.UP


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	# Ortho depth is linear: a wide near..far range costs no precision.
	near = 0.5
	_eye_dist = eye_distance
	far = _eye_dist + 300.0
	_target_size = clampf(size if size > 0.0 else 25.0, zoom_min, zoom_max)
	size = _target_size
	_center.y = ground_height
	_target_center.y = ground_height
	var lim := _pitch_limits()
	_pitch = clampf(deg_to_rad(initial_pitch_deg), lim.x, lim.y)
	_yaw = 0.0
	_find_tilt_shift()
	_apply_transform()


func _exp_blend(rate: float, delta: float) -> float:
	# Frame-rate independent exponential smoothing factor.
	return 1.0 - exp(-rate * delta)


func _pitch_limits() -> Vector2:
	# Pitch band as (min, max) radians, interpolating from the close-zoom
	# limits to the zoomed-out map-view limits between the two size anchors.
	# Uses the CURRENT size (not the zoom target): while a zoom is still
	# gliding, the limits must match what is actually on screen.
	if not adaptive_pitch:
		return Vector2(deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))
	var t := smoothstep(pitch_anchor_in_size, pitch_anchor_out_size, size)
	return Vector2(
		deg_to_rad(lerpf(pitch_min_deg, pitch_out_min_deg, t)),
		deg_to_rad(lerpf(pitch_max_deg, pitch_out_max_deg, t))
	)


func _process(delta: float) -> void:
	var move_kb := Vector3.ZERO

	if Input.is_action_pressed("ui_right"):
		move_kb.x += 1
	if Input.is_action_pressed("ui_left"):
		move_kb.x -= 1
	if Input.is_action_pressed("ui_up"):
		move_kb.z -= 1
	if Input.is_action_pressed("ui_down"):
		move_kb.z += 1

	var move_edge := Vector3.ZERO
	if edge_scroll_enabled and not (_is_mmb_rotating or _is_mmb_panning) \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		var vp := get_viewport().get_visible_rect().size
		var mouse_pos := get_viewport().get_mouse_position()
		if mouse_pos.x >= 0.0 and mouse_pos.y >= 0.0 and mouse_pos.x <= vp.x and mouse_pos.y <= vp.y:
			if mouse_pos.x < edge_scroll_margin:
				move_edge.x -= 1
			elif mouse_pos.x > vp.x - edge_scroll_margin:
				move_edge.x += 1
			if mouse_pos.y < edge_scroll_margin:
				move_edge.z -= 1
			elif mouse_pos.y > vp.y - edge_scroll_margin:
				move_edge.z += 1

	var boost := boost_multiplier if Input.is_action_pressed("ui_shift") else 1.0

	# Zoom-adaptive pan speed: fast glides when zoomed out, precise control
	# when zoomed in. Applies to keyboard and edge scroll alike.
	var speed_scale := 1.0
	if speed_scale_with_zoom:
		speed_scale = clampf(size / speed_ref_size, speed_min_scale, speed_max_scale)

	var target_vel := Vector3.ZERO
	if move_kb.length_squared() > 0.0:
		target_vel += move_kb.normalized().rotated(_UP, _yaw) * camera_speed
	if move_edge.length_squared() > 0.0:
		target_vel += move_edge.normalized().rotated(_UP, _yaw) * edge_scroll_speed
	target_vel *= boost * speed_scale

	# ONE smoothing stage: filter the input velocity, integrate it directly
	# into the center. (Filtering velocity AND chasing a separate target
	# cascades two exponential filters — sluggish start, mushy lag on stop.)
	_vel = _vel.lerp(target_vel, _exp_blend(movement_smoothing, delta))
	if _vel.length_squared() > 0.0001:
		_center += _vel * delta
		_target_center = _center

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

	# Zoom-adaptive pitch limits: when the band moves (zooming out/in) the
	# camera gently eases toward it — never a snap.
	var limits := _pitch_limits()
	var pitch_clamped := clampf(_pitch, limits.x, limits.y)
	if not is_equal_approx(pitch_clamped, _pitch):
		_pitch = lerp_angle(_pitch, pitch_clamped, _exp_blend(3.0, delta))

	# Smooth the ortho size (frame-rate independent). The zoom rate adapts:
	# glides longer when zoomed out (notches cover more ground there),
	# snappier when zoomed in.
	var size_prev := size
	if not is_equal_approx(size, _target_size):
		var zoom_rate := zoom_smoothing * clampf(30.0 / maxf(_target_size, 1.0), 0.45, 1.5)
		size = lerpf(size, _target_size, _exp_blend(zoom_rate, delta))
		if absf(size - _target_size) < 0.002:
			size = _target_size

	_apply_zoom_anchor(size_prev, size)
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
			# Raycast the absolute ground plane for the previous and current
			# mouse positions; drag the world with the cursor.
			var mouse := get_viewport().get_mouse_position()
			var prev_hit := _screen_to_ground(_last_mouse)
			var cur_hit := _screen_to_ground(mouse)
			_last_mouse = mouse
			if prev_hit != _NO_HIT and cur_hit != _NO_HIT:
				var d := cur_hit - prev_hit
				_center -= d
				_target_center = _center
				_apply_transform()
		elif _is_mmb_rotating:
			# Mouse deltas are already per-event: NO delta-time scaling.
			var dx := -mm.relative.x * deg_to_rad(yaw_deg_per_px)
			_yaw += dx
			var pitch_step := mm.relative.y * deg_to_rad(yaw_deg_per_px)
			var limits := _pitch_limits()
			_pitch = clampf(_pitch + pitch_step, limits.x, limits.y)
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
	# Capture the anchor NOW; the center correction is applied per frame
	# while the size glides (see _apply_zoom_anchor), so the point under
	# the cursor stays pinned through the whole zoom animation instead of
	# snapping to its final offset at event time.
	_zoom_anchor = _NO_HIT
	if zoom_to_cursor:
		var anchor := _screen_to_ground(get_viewport().get_mouse_position())
		# Guard: only anchor when the cursor points at the ground NEAR the
		# world. A cursor over the sky hits the ground plane hundreds of
		# meters away, which would drag the view (the diorama slides out of
		# frame — looks like the world is clipped at the screen bottom).
		if anchor != _NO_HIT and _center.distance_to(anchor) <= size * 1.5 + 10.0:
			_zoom_anchor = anchor


func _apply_zoom_anchor(size_prev: float, size_now: float) -> void:
	if _zoom_anchor == _NO_HIT or is_equal_approx(size_prev, size_now):
		return
	# Orthographic exact zoom-to-cursor: the image depends only on the
	# eye's LATERAL position, orientation and size — so to keep the anchor
	# point pinned, shift the eye (and thus the center) each frame by
	# (1 - size_ratio) * perpendicular offset from the eye to the anchor.
	# Integrating these per-frame shifts telescopes to the exact total
	# correction, with no mid-glide skew.
	var view_dir := (position - _center).normalized()
	var off := _zoom_anchor - position
	var perp := off - view_dir * off.dot(view_dir)
	var d := (1.0 - size_now / size_prev) * perp
	_center += d
	_target_center = _center
	# Re-pin the orbit center to the absolute ground plane: exact pinning
	# on a pitched view has an inherent vertical component, and letting it
	# accumulate floats the center into the sky.
	_center.y = ground_height
	_target_center.y = ground_height
	# Done once the glide has settled.
	if is_equal_approx(size_now, _target_size):
		_zoom_anchor = _NO_HIT


func _screen_to_ground(screen_pos: Vector2) -> Vector3:
	var dir := project_ray_normal(screen_pos)
	if dir == Vector3.ZERO:
		return _NO_HIT
	var denom := dir.dot(_UP)
	if absf(denom) < 1e-5:
		return _NO_HIT
	# Intersect the ABSOLUTE ground plane (ground_height), never a plane at
	# the live center height: anchoring against a self-referential plane
	# lets the orbit center drift/float through repeated zoom steps.
	var t := (ground_height - project_ray_origin(screen_pos).y) / denom
	if t <= 0.0:
		return _NO_HIT
	return project_ray_origin(screen_pos) + dir * t


func _apply_transform() -> void:
	var dir := Vector3(
		sin(_yaw) * cos(_pitch),
		sin(_pitch),
		cos(_yaw) * cos(_pitch)
	).normalized()
	# Push the eye back along the view axis until the near plane clears the
	# ground at the bottom edge of the view. The ground crosses the near
	# plane at view offset s = (eye_y - near*sin(pitch)) / cos(pitch);
	# requiring s >= size/2 gives the minimum distance below. Ortho framing
	# depends only on size, orientation and LATERAL eye position, so this is
	# visually invisible — it only moves the near/far window.
	var need := size * 0.5 / maxf(tan(_pitch), 0.1) + near + 2.0
	_eye_dist = maxf(eye_distance, need)
	far = _eye_dist + 300.0
	position = _center + dir * _eye_dist
	look_at(_center, _UP)


func _find_tilt_shift() -> void:
	_tilt_shift = null
	var comp := compositor
	if comp == null:
		return
	for eff in comp.compositor_effects:
		if eff is PostProcessTiltShift:
			_tilt_shift = eff
			_ts_base_strength = _tilt_shift.strength
			return


func _update_tilt_shift() -> void:
	if not auto_focus_tilt_shift or _tilt_shift == null:
		return

	# Zoom fade: full strength up close, gradual falloff zooming out, and a
	# hard disable (the effect then costs nothing) once fully faded. Zooming
	# back in re-enables it and fades it in again. While auto-focus owns the
	# effect, `strength` is driven from the value captured at discovery.
	var fade := 1.0
	if tilt_shift_fade_with_zoom:
		fade = 1.0 - smoothstep(tilt_shift_full_size, tilt_shift_off_size, size)
	if fade <= 0.001:
		_tilt_shift.enabled = false
		return
	_tilt_shift.enabled = true
	if _ts_base_strength >= 0.0:
		_tilt_shift.strength = _ts_base_strength * fade

	# Ground at the screen center is exactly `_eye_dist` deep on the view
	# axis. In-focus band scales with the ortho size so the diorama stays
	# sharp at every zoom level, and the blur ramps scale with it too.
	# Cap band+ramp below _eye_dist so near_start never crosses 0 and the
	# effect's export ranges are never clamped at extreme zoom-out.
	var band := clampf(size * focus_band_scale, 1.0, _eye_dist * 0.45)
	var ramp := minf(size * blur_ramp_scale, _eye_dist * 0.5)
	_tilt_shift.focus_distance = _eye_dist
	_tilt_shift.near_end = _eye_dist - band
	_tilt_shift.near_start = _eye_dist - band - ramp
	_tilt_shift.far_start = _eye_dist + band
	_tilt_shift.far_end = _eye_dist + band + ramp
	# Keep depth linearization exact: always report the real near/far.
	_tilt_shift.near_plane = near
	_tilt_shift.far_plane = far
