extends Camera3D

@export var rotation_a: Vector3 = Vector3(0, 0, 0)
@export var rotation_b: Vector3 = Vector3(0, -45, 0)

@export var smoothness: float = 2.0

var _target_rotation: Vector3

func _ready() -> void:
	rotation_degrees = rotation_a
	_target_rotation = rotation_a

func _process(delta: float):
	rotation_degrees = rotation_degrees.slerp(_target_rotation, delta * smoothness)

func rotacionar() -> void:
	if _target_rotation == rotation_a:
		_target_rotation = rotation_b
