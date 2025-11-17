extends Node
class_name LightingService

@export var world_environment: WorldEnvironment
@export var directional_light: DirectionalLight3D

var _color_tween: Tween
var _rot_tween: Tween

func transition(target_color: Color, target_rotation: Vector3, duration: float = 1.5):
	_color_transition(target_color, duration)
	_rotation_transition(target_rotation, duration)

func _color_transition(target_color: Color, duration: float):
	if _color_tween and _color_tween.is_running():
		_color_tween.kill()
	_color_tween = create_tween()
	if world_environment:
		_color_tween.tween_property(
			world_environment.environment, 
			"ambient_light_color", 
			target_color, duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _rotation_transition(target_rotation: Vector3, duration: float):
	if not directional_light:
		return
	if _rot_tween and _rot_tween.is_running():
		_rot_tween.kill()
	_rot_tween = create_tween()
	_rot_tween.tween_property(
		directional_light, 
		"rotation_degrees", 
		target_rotation, duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
