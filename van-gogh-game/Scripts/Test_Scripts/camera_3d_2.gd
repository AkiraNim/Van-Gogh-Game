extends Camera3D

# As duas rotações que você pode definir no Inspector
@export var rotation_a: Vector3 = Vector3(0, 0, 0)
@export var rotation_b: Vector3 = Vector3(0, -45, 0)

# A velocidade da suavização
@export var smoothness: float = 2.0

# Variável interna para guardar a rotação alvo atual
var _target_rotation: Vector3

func _ready() -> void:
	# A câmera começa na 'rotation_a'
	rotation_degrees = rotation_a
	_target_rotation = rotation_a

func _process(delta: float):
	# Interpola suavemente em direção ao alvo atual a cada frame
	rotation_degrees = rotation_degrees.slerp(_target_rotation, delta * smoothness)

func _input(event: InputEvent) -> void:
	# Usa a tecla de espaço ("ui_accept") para alternar o alvo
	if event.is_action_pressed("ui_accept"):
		if _target_rotation == rotation_a:
			_target_rotation = rotation_b
			print("Movendo para a rotação B")
		else:
			_target_rotation = rotation_a
			print("Movendo para a rotação A")
