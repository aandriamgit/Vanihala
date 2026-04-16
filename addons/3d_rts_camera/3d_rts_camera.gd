extends PixelPerfectCamera3D

# =========================
# Camera movement settings
# =========================
@export_category("Camera movement")
@export var camera_speed: float = 20.0
@export var movement_smoothing: float = 8.0 # Higher = stops faster, Lower = feels like it's on ice
@export var camera_zoom_speed: float = 2.0 
@export var camera_zoom_min: float = 10.0
@export var camera_zoom_max: float = 50.0
@export var zoom_smoothing: float = 10.0   

# =========================
# Edge scrolling settings
# =========================
@export_category("Edge scrolling")
@export var edge_scroll_margin: float = 20.0
@export var edge_scroll_speed: float = 15.0 

# =========================
# Rotation (MMB) settings
# =========================
@export_category("Rotation")
@export var yaw_sensitivity: float = 0.50
@export var pitch_sensitivity: float = 0.18
@export var max_step_deg: float = 3.0
@export var pitch_min_deg: float = 10.0
@export var pitch_max_deg: float = 80.0
@export var capture_mouse_on_mmb: bool = false

# =========================
# Runtime state
# =========================
var orbit_center: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO         # NEW: Tracks current panning speed
var orbit_distance: float = 25.0
var target_orbit_distance: float = 25.0 
var current_height: float = 20.0     
var orbit_radius: float = 20.0       

var _is_mmb_rotating := false
var _yaw: float = 0.0
var _pitch: float = 0.8              

func _ready() -> void:
	super()
	orbit_distance = default_ortho_size
	target_orbit_distance = orbit_distance
	var pmin := deg_to_rad(pitch_min_deg)
	var pmax := deg_to_rad(pitch_max_deg)
	_pitch = clamp(_pitch, pmin, pmax)
	_update_camera_position()

func _process(delta: float) -> void:
	super(delta)

func _physics_process(delta: float) -> void:
	var movement := Vector3.ZERO

	# Keyboard movement
	if Input.is_action_pressed("ui_right"):
		movement.x += 1
	if Input.is_action_pressed("ui_left"):
		movement.x -= 1
	if Input.is_action_pressed("ui_up"):
		movement.z -= 1
	if Input.is_action_pressed("ui_down"):
		movement.z += 1

	# Edge scrolling
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

	# Calculate desired velocity
	var target_velocity := Vector3.ZERO
	if movement.length() > 0.0:
		target_velocity = movement.normalized().rotated(Vector3.UP, _yaw) * camera_speed * speed_multiplier
		
	# Smoothly interpolate current velocity towards target velocity
	velocity = velocity.lerp(target_velocity, movement_smoothing * delta)

	# Apply velocity to orbit center (only if we are moving)
	if velocity.length_squared() > 0.001:
		orbit_center += velocity * delta
		position_changed = true

	# Smooth Zoom Interpolation
	if not is_equal_approx(orbit_distance, target_orbit_distance):
		orbit_distance = lerp(orbit_distance, target_orbit_distance, zoom_smoothing * delta)
		default_ortho_size = orbit_distance 
		position_changed = true
		
	# Only update transform if something actually changed
	if position_changed:
		_update_camera_position()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_orbit_distance = max(camera_zoom_min, target_orbit_distance - camera_zoom_speed)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_orbit_distance = min(camera_zoom_max, target_orbit_distance + camera_zoom_speed)

		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_mmb_rotating = event.pressed
			if capture_mouse_on_mmb:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE)

	elif event is InputEventMouseMotion and _is_mmb_rotating:
		var vp = get_viewport().size
		var vmin := float(min(vp.x, vp.y))          
		var dt := get_process_delta_time()
		var sixty_fps := 60.0 * dt                   

		var dx = (event.relative.x / vmin) * yaw_sensitivity   * TAU * sixty_fps
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

# =========================
# Helpers
# =========================
func _update_camera_position() -> void:
	var dir := Vector3(
		sin(_yaw) * cos(_pitch),
		sin(_pitch),
		cos(_yaw) * cos(_pitch)
	).normalized()

	position = orbit_center + dir * 25.0
	look_at(orbit_center, Vector3.UP)

	current_height = orbit_distance * sin(_pitch)
	orbit_radius   = orbit_distance * cos(_pitch)
