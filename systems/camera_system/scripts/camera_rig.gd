class_name CameraRig extends Node3D

@export var move_speed : float = 5.0
@export var rotation_duration : float = 0.3 # seconds per 45° step

@onready var camera: PixelPerfectCamera3D = %Camera3D

var _target_rotation_y : float = 0.0
var _tween : Tween

func _ready() -> void:
	_target_rotation_y = rotation.y

func _process(delta: float) -> void:
	# WASD Movement relative to camera forward
	var input := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input.z += 1
	if Input.is_key_pressed(KEY_S):
		input.z -= 1
	if Input.is_key_pressed(KEY_A):
		input.x += 1
	if Input.is_key_pressed(KEY_D):
		input.x -= 1
	if input != Vector3.ZERO:
		var direction := input
		if camera:
			var cam_forward = camera.global_transform.basis.z * -1 # -Z is forward
			cam_forward.y = 0.0
			cam_forward = cam_forward.normalized()
			var cam_right = Vector3(cam_forward.z, 0.0, -cam_forward.x)
			direction = (cam_right * input.x + cam_forward * input.z).normalized()
		position += direction * move_speed * delta

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_rotate_step(deg_to_rad(45.0))
		elif event.keycode == KEY_Q:
			_rotate_step(deg_to_rad(-45.0))

func _rotate_step(amount: float) -> void:
	_target_rotation_y += amount
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self , "rotation:y", _target_rotation_y, rotation_duration) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_CUBIC)
