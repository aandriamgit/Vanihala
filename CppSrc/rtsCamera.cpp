#include "./rtsCamera.hpp"
#include "godot_cpp/classes/engine.hpp"
#include "godot_cpp/classes/input.hpp"
#include "godot_cpp/classes/input_event.hpp"
#include "godot_cpp/classes/input_event_mouse_motion.hpp"
#include "godot_cpp/classes/ref.hpp"
#include "godot_cpp/core/math.hpp"
#include "godot_cpp/core/memory.hpp"
#include "godot_cpp/variant/vector2.hpp"
#include "godot_cpp/variant/vector3.hpp"

void rtsCamera::_bind_methods()
{
}

rtsCamera::rtsCamera() : _moveSpeed(0.5), _rotateKeySpeed(1.5), _zoomSpeed(1.0),
	_minZoom(-6), _maxZoom(66), _mouseSensitivity(0.3)
{
}

void rtsCamera::_ready()
{
	if (Engine::get_singleton()->is_editor_hint())
		return;
	_rotateX = memnew(Node3D);
	add_child(_rotateX);
	_pivot = memnew(Node3D);
	_rotateX->add_child(_pivot);
	_camera3d = memnew(Camera3D);
	_pivot->add_child(_camera3d);
	_moveTarget = get_position();
	_rotateKeyTarget = get_rotation_degrees().y;
	_camera3d->set_position(_camera3d->get_position().lerp(Vector3(0, 0, 100),
			0.01));
	_camera3d->set_rotation_degrees(_camera3d->get_rotation_degrees().lerp(Vector3(-500,
				0, 0), 0.01));
	_zoomTarget = _camera3d->get_position().z;
}

void rtsCamera::_process(float delta)
{
	Vector2	inputDir;
	Vector3	movementDir;
	Vector3	tmp;
	float	rotateKey;
	int		zoomDir;
	float	yaw;
	Basis	yaw_basis;

	yaw = get_rotation_degrees().y;
	yaw_basis = Basis(Vector3(0, 1, 0), Math::deg_to_rad(yaw));
	inputDir = Input::get_singleton()->get_vector("ui_left", "ui_right",
			"ui_up", "ui_down");
	movementDir = (yaw_basis.xform(Vector3(inputDir.x, 0,
					inputDir.y))).normalized();
	rotateKey = Input::get_singleton()->get_axis("rotate_left", "rotate_right");
	zoomDir = (((int)(Input::get_singleton()->is_action_just_released("zoom_out")))
			- ((int)(Input::get_singleton()->is_action_just_released("zoom_in"))));
	_moveTarget += _moveSpeed * movementDir;
	_rotateKeyTarget += rotateKey * _rotateKeySpeed;
	_zoomTarget += zoomDir * _zoomSpeed;
	_zoomTarget = CLAMP(_zoomTarget, _minZoom, _maxZoom);
	set_position(get_position().lerp(_moveTarget, 0.08));
	tmp = get_rotation_degrees();
	tmp.y = _rotateKeyTarget;
	set_rotation_degrees(get_rotation_degrees().lerp(Vector3(tmp), 0.1));
	_camera3d->set_position(_camera3d->get_position().lerp(Vector3(0,
				_zoomTarget, _zoomTarget / 2), 0.06));
}

void rtsCamera::_unhandled_input(const Ref<InputEvent> &event)
{
	Vector3	current_rot;

	Ref<InputEventMouseMotion> motion = event;
	if (motion.is_valid()
		&& Input::get_singleton()->is_action_pressed("rotate"))
	{
		if (Input::get_singleton()->is_action_pressed("rotate"))
			Input::get_singleton()->set_mouse_mode(Input::get_singleton()->MOUSE_MODE_CAPTURED);
		_rotateKeyTarget -= motion->get_relative().x * _mouseSensitivity;
		current_rot = get_rotation_degrees();
		current_rot.x -= motion->get_relative().y * _mouseSensitivity;
		current_rot.x = CLAMP(current_rot.x, -60, 70);
		current_rot.y = _rotateKeyTarget;
		set_rotation_degrees(get_rotation_degrees().lerp(current_rot, 0.3));
	}
	if (event->is_action_released("rotate"))
		Input::get_singleton()->set_mouse_mode(Input::get_singleton()->MOUSE_MODE_VISIBLE);
}
