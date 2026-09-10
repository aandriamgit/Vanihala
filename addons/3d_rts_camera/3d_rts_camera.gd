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
#  - The view angle DRIVES with zoom, smoothly, BOTH ways: a 3/4 diorama
#    angle up close, a top-down map view zoomed out, and the exact same
#    curve on the way back in. Manual MMB tilt is an offset on top of the
#    driven angle, so it survives zoom changes.
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
# Closest view — tuned so the diorama fills the frame comfortably without
# clipping into geometry (10 ortho units on a ~35 m test diorama).
@export var zoom_min: float = 10.0
# Zoomed-out limit. Keep in sync with pitch_out_size: the pitch transition
# must end EXACTLY at the max zoom (and start exactly at zoom_min), so the
# camera only ever stops zooming at its true limit — never early, at the
# moment the angle finishes moving.
@export var zoom_max: float = 200.0
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

@export_category("Edge scrolling")
@export var edge_scroll_enabled: bool = true
@export var edge_scroll_margin: float = 24.0

@export_category("Rotation")
@export_range(0.01, 2.0) var yaw_deg_per_px: float = 0.3
@export var keyboard_yaw_speed: float = 120.0
@export var capture_mouse_on_mmb: bool = false

## The view angle follows zoom smoothly in BOTH directions: a 3/4 diorama
## angle when zoomed in, easing to a top-down map view when zoomed out.
@export var adaptive_pitch: bool = true
## View angle when zoomed in (view size <= pitch_in_size).
@export_range(10.0, 89.0) var pitch_in_deg: float = 45.0
## View angle when zoomed out (view size >= pitch_out_size).
@export_range(10.0, 89.0) var pitch_out_deg: float = 70.0
## View size at/below which pitch_in_deg applies. Keep == zoom_min so the
## angle transition spans the WHOLE zoom range and finishes exactly at the
## max zoom-in (zooming in from the spawn size still moves the angle).
@export_range(1.0, 300.0) var pitch_in_size: float = 10.0
## View size at/above which pitch_out_deg applies. Keep == zoom_max so the
## angle finishes exactly when the camera reaches max zoom-out — no dead
## stretch of zoom after the pitch has already settled.
@export_range(1.0, 300.0) var pitch_out_size: float = 200.0
## Extra tilt the user may add on top via MMB vertical drag (persists
## across zoom changes).
@export_range(0.0, 30.0) var pitch_manual_max_deg: float = 20.0
## Easing rate for the manual MMB tilt (frame-rate independent).
@export_range(1.0, 30.0) var pitch_offset_easing: float = 6.0

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
## Push the screen-space blur band into the PostProcessTiltShift effect
## every frame (the effect is pure screen-space; no depth involved).
@export var auto_focus_tilt_shift: bool = true
## Sharp/blur split line position, LINEAR over the whole slider: 0.0 = line
## at dead center (bottom half blurs), 1.0 = line at the very bottom edge
## (nothing blurred). Screen fraction from bottom = (1 - value) * 50%.
## Raising the value moves the line DOWN; every step of the slider changes
## the image - no dead zones.
@export_range(0.0, 1.0) var focus_band_scale: float = 0.35
## Blur gradient width below the line, fraction of screen half-height:
## distance from the band edge to full blur. 0.02 = razor gradient, 1.0 =
## soft gradient spanning the whole lower half of the screen.
@export_range(0.02, 1.0) var blur_ramp_scale: float = 0.3
## Live on-screen readout of the tilt-shift state (band/ramp/fade/effect).
## Zero cost when off. Use it to verify tuning: the numbers MUST change
## when you edit the values in the RUNNING game (Remote tab) - if the
## numbers move but the image does not, the effect is not rendering.
@export var tilt_shift_debug: bool = false

var _center := Vector3.ZERO
var _target_center := Vector3.ZERO
var _target_size := 25.0
var _yaw := 0.0
var _pitch := 0.0
# Manual tilt offset (MMB vertical drag), eased on top of the driven angle.
var _pitch_offset := 0.0
var _pitch_offset_target := 0.0
var _vel := Vector3.ZERO
var _is_mmb_rotating := false
var _is_mmb_panning := false
var _last_mouse := Vector2.ZERO
var _tilt_shift: CompositorEffect = null
var _ts_base_strength := -1.0
# Actual eye distance (>= eye_distance base): grows with view size / pitch
# so the near plane never clips the ground at the bottom of the view.
var _eye_dist := 60.0
# Zoom anchoring: the world point to keep pinned while the size glides
# toward _target_size.
var _zoom_anchor := Vector3(INF, INF, INF)
var _ts_debug_label: Label = null

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
	_pitch = _driven_pitch()
	_yaw = 0.0
	_find_tilt_shift()
	_apply_transform()
	if tilt_shift_debug:
		var layer := CanvasLayer.new()
		layer.name = "TiltShiftDebugLayer"
		add_child(layer)
		_ts_debug_label = Label.new()
		_ts_debug_label.position = Vector2(12.0, 12.0)
		layer.add_child(_ts_debug_label)
		if _tilt_shift == null:
			_ts_debug_label.text = "tilt-shift: NO EFFECT FOUND (compositor missing?)"


func _exp_blend(rate: float, delta: float) -> float:
	# Frame-rate independent exponential smoothing factor.
	return 1.0 - exp(-rate * delta)


func _pitch_base_deg() -> float:
	# Zoom-driven view angle in degrees. The curve depends ONLY on the
	# current size, so zooming in and out traverse the exact same path —
	# the transition is smooth and symmetric by construction.
	if not adaptive_pitch:
		return pitch_in_deg
	var t := smoothstep(pitch_in_size, pitch_out_size, size)
	return lerpf(pitch_in_deg, pitch_out_deg, t)


func _driven_pitch() -> float:
	# Final pitch = zoom-driven base + manual offset, hard-clamped to a
	# safe absolute range so the view can never go under the horizon or
	# perfectly top-down (breaks pan raycasts).
	return clampf(
		deg_to_rad(_pitch_base_deg()) + _pitch_offset,
		deg_to_rad(10.0), deg_to_rad(85.0)
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

	# Manual tilt eases toward its target. The zoom-driven base is followed
	# EXACTLY (size is already exponentially smoothed), so the angle glides
	# symmetrically with zoom — in and out — with zero extra lag.
	_pitch_offset = lerpf(_pitch_offset, _pitch_offset_target,
			_exp_blend(pitch_offset_easing, delta))
	_pitch = _driven_pitch()

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
	elif event is InputEventMouseButton and not event.pressed:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				_is_mmb_panning = false
				_is_mmb_rotating = false
				if capture_mouse_on_mmb:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
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
			# Vertical drag nudges the tilt RELATIVE to the zoom-driven angle;
			# the offset persists when you zoom afterwards.
			_pitch_offset_target = clampf(
				_pitch_offset_target + mm.relative.y * deg_to_rad(yaw_deg_per_px),
				-deg_to_rad(pitch_manual_max_deg), deg_to_rad(pitch_manual_max_deg))
			_apply_transform()


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

	# Guard: writing properties on a freed CompositorEffect (freed with the
	# scene tree) crashes in the render server — re-validate every frame.
	if not is_instance_valid(_tilt_shift):
		_tilt_shift = null
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
		_ts_debug_set("fade 0 - effect DISABLED (zoomed out)")
		return
	_tilt_shift.enabled = true
	if _ts_base_strength >= 0.0:
		_tilt_shift.strength = _ts_base_strength * fade

	# Sliders pass through 1:1 as fractions of the visible screen: what the
	# inspector says is exactly what drives the blur. The shader wants
	# fractions of FULL screen height, hence *0.5 (band 0 = line at dead
	# center, 1 = line at the bottom edge).
	_tilt_shift.band = focus_band_scale * 0.5
	_tilt_shift.ramp = blur_ramp_scale * 0.5
	_ts_debug_set("band=%.2f  ramp=%.2f\nfade=%.2f  strength=%.2f  size=%.1f" % [
		focus_band_scale, blur_ramp_scale, fade, _tilt_shift.strength, size])


func _ts_debug_set(text: String) -> void:
	if _ts_debug_label != null:
		_ts_debug_label.text = text
