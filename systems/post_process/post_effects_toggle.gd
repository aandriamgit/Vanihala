class_name PostEffectsToggle extends Node

@export var tilt_shift: PostProcessTiltShift

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_T:
				if tilt_shift:
					tilt_shift.enabled = not tilt_shift.enabled
			KEY_F:
				# Bigger band = blur line lower on screen.
				if tilt_shift:
					tilt_shift.band = clampf(tilt_shift.band + 0.05, 0.0, 0.5)
			KEY_H:
				# Smaller band = blur line higher (toward center).
				if tilt_shift:
					tilt_shift.band = clampf(tilt_shift.band - 0.05, 0.0, 0.5)
