class_name PostEffectsToggle extends Node

@export var tilt_shift: PostProcessTiltShift

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_T:
				if tilt_shift:
					tilt_shift.enabled = not tilt_shift.enabled
			KEY_F:
				if tilt_shift:
					tilt_shift.focus_center = clampf(tilt_shift.focus_center - 0.05, 0.0, 1.0)
			KEY_H:
				if tilt_shift:
					tilt_shift.focus_center = clampf(tilt_shift.focus_center + 0.05, 0.0, 1.0)
