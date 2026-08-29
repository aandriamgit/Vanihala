extends Camera3D

@export_category("Camera movement")
@export var camera_speed: float = 20.0
@export var movement_smoothing: float = 8.0
@export var camera_zoom_speed: float = 2.0 
@export var camera_zoom_min: float = 5.0
@export var camera_zoom_max: float = 100.0
@export var zoom_smoothing: float = 10.0   

@export_category("Edge scrolling")
@export var edge_scroll_margin: float = 20.0
@export var edge_scroll_speed: float = 15.0 

@export_category("Rotation")
@export var yaw_sensitivity: float = 0.50
@export var pitch_sensitivity: float = 0.18
@export var max_step_deg: float = 3.0
@export var pitch_min_deg: float = 35.0
@export var pitch_max_deg: float = 60.0
@export var capture_mouse_on_mmb: bool = false

var orbit_center: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var target_size: float = 25.0

var _is_mmb_rotating := false
var _is_mmb_panning := false
var _pan_start_mouse: Vector2
var _pan_start_center: Vector3
var _yaw: float = 0.0
var _pitch: float = 0.8              

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = target_size
	var pmin := deg_to_rad(pitch_min_deg)
	var pmax := deg_to_rad(pitch_max_deg)
	_pitch = clamp(_pitch, pmin, pmax)
	_yaw = 0.0
	_update_camera_position()

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

	var mouse_pos := get_viewport().get_mouse_position()
	var viewport_size = get_viewport().size
	if mouse_pos.x < edge_scroll_margin:
		movement.x -= 1
	elif mouse_pos.x > viewport_size.x - edge_scroll_margin:
		movement.x += 1
	if mouse_pos.y < edge_scroll_margin:
		movement.z -= 1
	elif mouse_pos.y > viewport_size.y - edge_scroll_margin:
		movement.z += 1

	var speed_multiplier := 2.0 if Input.is_action_pressed("ui_shift") else 1.0
	var position_changed := false

	var target_velocity := Vector3.ZERO
	if movement.length() > 0.0:
		target_velocity = movement.normalized().rotated(Vector3.UP, _yaw) * camera_speed * speed_multiplier
		
	velocity = velocity.lerp(target_velocity, movement_smoothing * delta)

	if velocity.length_squared() > 0.001:
		orbit_center += velocity * delta
		position_changed = true

	if not is_equal_approx(size, target_size):
		size = lerp(size, target_size, zoom_smoothing * delta)
		
	if position_changed:
		_update_camera_position()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_size = max(camera_zoom_min, target_size - camera_zoom_speed)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_size = min(camera_zoom_max, target_size + camera_zoom_speed)
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				if Input.is_key_pressed(KEY_SHIFT):
					_is_mmb_panning = true
					_pan_start_mouse = get_viewport().get_mouse_position()
					_pan_start_center = orbit_center
					if capture_mouse_on_mmb:
						Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				else:
					_is_mmb_rotating = true
					if capture_mouse_on_mmb:
						Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				_is_mmb_panning = false
				_is_mmb_rotating = false
				if capture_mouse_on_mmb:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	elif event is InputEventMouseMotion:
		if _is_mmb_panning:
			var start_ray = _screen_to_world_ray(_pan_start_mouse)
			var current_ray = _screen_to_world_ray(get_viewport().get_mouse_position())
			var start_hit = _ray_plane_intersect(start_ray, Vector3.UP, 0.0)
			var current_hit = _ray_plane_intersect(current_ray, Vector3.UP, 0.0)
			if start_hit != Vector3(0, 0, 0) and current_hit != Vector3(0, 0, 0):
				orbit_center = _pan_start_center + (start_hit - current_hit)
				_update_camera_position()

		elif _is_mmb_rotating and not Input.is_key_pressed(KEY_SHIFT):
			var vp = get_viewport().size
			var vmin := float(min(vp.x, vp.y))
			var dt := get_process_delta_time()
			var sixty_fps := 60.0 * dt

			var dx = (event.relative.x / vmin) * yaw_sensitivity * TAU * sixty_fps
			var dy = (event.relative.y / vmin) * pitch_sensitivity * TAU * sixty_fps

			var max_step := deg_to_rad(max_step_deg)
			dx = clamp(dx, -max_step, max_step)
			dy = clamp(dy, -max_step, max_step)

			_yaw   -= dx
			_pitch += dy

			var pmin := deg_to_rad(pitch_min_deg)
			var pmax := deg_to_rad(pitch_max_deg)
			_pitch = clamp(_pitch, pmin, pmax)

			_update_camera_position()

func _screen_to_world_ray(screen_pos: Vector2) -> Dictionary:
	var origin = project_ray_origin(screen_pos)
	var direction = project_ray_normal(screen_pos)
	return {"origin": origin, "direction": direction}

func _ray_plane_intersect(ray: Dictionary, plane_normal: Vector3, plane_d: float) -> Vector3:
	var denom = ray.direction.dot(plane_normal)
	if abs(denom) < 1e-6:
		return Vector3(0, 0, 0)
	var t = (plane_d - ray.origin.dot(plane_normal)) / denom
	if t < 0:
		return Vector3(0, 0, 0)
	return ray.origin + ray.direction * t

func _update_camera_position() -> void:
	var dir := Vector3(
		sin(_yaw) * cos(_pitch),
		sin(_pitch),
		cos(_yaw) * cos(_pitch)
	).normalized()

	var cam_distance = size * 1.2
	position = orbit_center + dir * cam_distance
	look_at(orbit_center, Vector3.UP)
