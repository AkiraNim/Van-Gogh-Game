extends Node
class_name DialogCameraService

signal dialogo_finalizado # Emitido quando o zoom de saída termina.

@export var camera: Camera3D

## NOVO: Alvo para a câmera seguir durante o gameplay.
@export var gameplay_target: Node3D
@export var gameplay_follow_speed: float = 5.0

# Níveis de zoom
@export var zoom_padrao: float = 5.0
@export var zoom_inicial: float = 3.0
@export var zoom_final: float = 2.5

# Configurações de Animação
@export var duracao_zoom_in: float = 0.8
@export var duracao_zoom_out: float = 0.5
@export var velocidade_foco: float = 0.5
## ALTERADO: O Offset agora controla a distância (Z) também.
## X: Deslocamento lateral | Y: Altura | Z: Distância
@export var offset_camera: Vector3 = Vector3(0, 4, 6)

var camera_tween: Tween
## NOVO: Uma "chave" para saber se estamos em diálogo.
var is_in_dialogue: bool = false


func _ready() -> void:
	if camera:
		camera.size = zoom_padrao
		print("🎥 Serviço de Câmera iniciado. Zoom padrão:", camera.size)
	else:
		push_warning("Nenhuma câmera foi atribuída ao DialogCameraService.")
		set_physics_process(false)


## NOVO: Loop para seguir o jogador durante o gameplay.
func _physics_process(delta: float) -> void:
	# Se estivermos em diálogo OU se não houver um alvo de gameplay, esta função para aqui.
	# É aqui que o foco do diálogo "sobrepõe" o foco do gameplay.
	if is_in_dialogue or not is_instance_valid(gameplay_target):
		return

	# Se não estivermos em diálogo, a câmera segue suavemente o jogador.
	var pos_alvo = calcular_posicao_foco(gameplay_target)
	camera.global_position = camera.global_position.lerp(pos_alvo, delta * gameplay_follow_speed)


# -------------------------------------------------
# PASSO 1 — início do diálogo
# -------------------------------------------------
func iniciar_dialogo(personagem_alvo: Node3D) -> void:
	if not camera: return
	
	## NOVO: Avisa ao script que o diálogo começou, pausando o foco no jogador.
	is_in_dialogue = true
	
	print("🎬 PASSO 1: Iniciando diálogo com zoom e foco.")
	_iniciar_tween_foco_e_zoom(personagem_alvo, zoom_inicial, duracao_zoom_in)


# -------------------------------------------------
# PASSO 2 — troca de falante (foco)
# -------------------------------------------------
func focar_personagem(novo_alvo: Node3D) -> void:
	if not camera or not novo_alvo: return
	
	print("🎯 PASSO 2: Trocando foco para:", novo_alvo.name)
	# O zoom atual é mantido, apenas a posição é alterada.
	_iniciar_tween_foco_e_zoom(novo_alvo, camera.size, velocidade_foco)


# -------------------------------------------------
# PASSO 3 — fim do diálogo (zoom out)
# -------------------------------------------------
func finalizar_dialogo() -> void:
	if not camera: return
	
	print("🏁 PASSO 3: Finalizando diálogo com zoom out.")
	
	if camera_tween and camera_tween.is_running():
		camera_tween.kill()
		
	camera_tween = create_tween()
	camera_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	camera_tween.tween_property(camera, "size", zoom_padrao, duracao_zoom_out)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	camera_tween.finished.connect(func():
		dialogo_finalizado.emit()
		## NOVO: Avisa que o diálogo acabou, devolvendo o controle da câmera para o gameplay.
		is_in_dialogue = false
		print("✅ Câmera retornou ao modo de gameplay.")
	)


# -------------------------------------------------
# Função auxiliar combinada de foco e zoom
# -------------------------------------------------
func _iniciar_tween_foco_e_zoom(alvo: Node3D, novo_zoom: float, duracao: float) -> void:
	if camera_tween and camera_tween.is_running():
		camera_tween.kill()

	var pos_alvo := calcular_posicao_foco(alvo)
	camera_tween = create_tween()
	camera_tween.set_parallel()
	camera_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	camera_tween.tween_property(camera, "global_position", pos_alvo, velocidade_foco)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	camera_tween.tween_property(camera, "size", novo_zoom, duracao)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# -------------------------------------------------
# Função utilitária
# -------------------------------------------------
func calcular_posicao_foco(alvo: Node3D) -> Vector3:
	## ALTERADO: A trava do eixo Z foi removida.
	# A posição alvo é simplesmente a posição do alvo + o offset completo (X, Y e Z).
	var pos_alvo := alvo.global_position + offset_camera
	return pos_alvo
