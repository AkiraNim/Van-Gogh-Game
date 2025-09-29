# Nome do arquivo: camera_segue.gd
extends Camera3D

# Arraste o nó 'Patrulheiro' para este campo no Inspetor.
@export var alvo: Node3D

# A distância e altura que a câmera manterá do alvo.
@export var offset: Vector3 = Vector3(0, 5, 8)

# A velocidade de suavização.
@export var suavidade: float = 5.0

func _process(delta: float) -> void:
	if not alvo:
		return
	
	# Calcula a posição ideal para a câmera (posição do alvo + distância).
	var posicao_desejada = alvo.global_position + offset
	
	# Usa lerp para mover a câmera suavemente para a posição desejada.
	global_position = global_position.lerp(posicao_desejada, suavidade * delta)
	
	# Faz a câmera sempre olhar para a posição do alvo.
	look_at(alvo.global_position)
